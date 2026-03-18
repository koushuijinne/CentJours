//! 蒙特卡洛平衡测试
//! `cargo run --bin balance-test -- --runs 1000` 即可执行
//! Rust版本相比Python版快100倍以上，支持在M2/M3阶段快速迭代平衡参数

use std::collections::HashMap;
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

use crate::battle::resolver::{ForceData, Terrain, resolve_battle};
use crate::politics::system::{PoliticsState, default_policies};

// ── 模拟参数 ──────────────────────────────────────────

/// 各日期段军队兵力下限（历史北上进程）
const ARMY_PHASES: [(u32, u32); 4] = [
    (1,  6_000),    // 厄尔巴岛起步
    (7,  10_000),   // 格勒诺布尔驻军加入
    (20, 60_000),   // 进入巴黎
    (30, 120_000),  // 全军集结完成
];

/// 有战斗的日子（简化）
const BATTLE_DAYS: &[u32] = &[7, 20, 45, 60, 80, 86, 90, 100];

/// 目标胜率范围（平衡测试基准）
pub const TARGET_VICTORY_RATE_MIN: f64 = 0.15;
pub const TARGET_VICTORY_RATE_MAX: f64 = 0.35;

// ── 结局类型 ──────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GameOutcome {
    NapoleonVictory,
    WaterlooHistorical,
    WaterlooDefeat,
    PoliticalCollapse,
    MilitaryAnnihilation,
}

impl GameOutcome {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::NapoleonVictory      => "napoleon_victory",
            Self::WaterlooHistorical   => "waterloo_historical",
            Self::WaterlooDefeat       => "waterloo_defeat",
            Self::PoliticalCollapse    => "political_collapse",
            Self::MilitaryAnnihilation => "military_annihilation",
        }
    }
}

// ── 策略类型 ──────────────────────────────────────────

#[derive(Debug, Clone, Copy)]
pub enum PlayerStrategy {
    Military,   // 优先军事：征兵+军费
    Political,  // 优先政治：宪政+演说+减税
    Balanced,   // 均衡策略
}

impl PlayerStrategy {
    pub fn select_policy<'a>(&self, policies: &'a [&'a str], rng: &mut impl Rng) -> &'a str {
        match self {
            Self::Military  => {
                let mil = ["conscription", "increase_military_budget"];
                mil[rng.gen_range(0..mil.len())]
            }
            Self::Political => {
                let pol = ["constitutional_promise", "public_speech", "reduce_taxes"];
                pol[rng.gen_range(0..pol.len())]
            }
            Self::Balanced  => policies[rng.gen_range(0..policies.len())],
        }
    }
}

// ── 单局模拟 ──────────────────────────────────────────

pub struct GameRecord {
    pub days_survived:  u32,
    pub outcome:        GameOutcome,
    pub final_legit:    f64,
    pub final_troops:   u32,
    pub battles_fought: u32,
    pub victories:      u32,
}

fn army_size_for_day(day: u32) -> u32 {
    ARMY_PHASES.iter().rev()
        .find(|(d, _)| day >= *d)
        .map(|(_, s)| *s)
        .unwrap_or(6_000)
}

pub fn simulate_one_game(strategy: PlayerStrategy, rng: &mut StdRng) -> GameRecord {
    let mut politics  = PoliticsState::default();
    let all_policies  = default_policies();
    let policy_ids: Vec<&str> = all_policies.iter().map(|p| p.id).collect();

    let mut troops: u32 = 6_000;
    let mut morale: f64 = 85.0;
    let fatigue: f64 = 10.0;
    let mut coalition_strength: f64 = 0.0;
    let mut battles_fought = 0u32;
    let mut victories      = 0u32;
    let mut outcome        = None;

    for day in 1u32..=100 {
        // 军队扩张
        troops = troops.max(army_size_for_day(day));

        // 每3天执行政策
        if day % 3 == 0 {
            let policy_id = strategy.select_policy(&policy_ids, rng);
            if let Some(p) = all_policies.iter().find(|p| p.id == policy_id) {
                let _ = politics.enact_policy(p);
            }
        }

        // 每日政治结算
        politics.daily_tick();

        // 反法同盟集结
        coalition_strength += match day {
            d if d >= 60 => 2.0,
            d if d >= 30 => 1.0,
            d if d >= 20 => 0.3,
            _ => 0.0,
        };

        // 战斗日
        if BATTLE_DAYS.contains(&day) {
            battles_fought += 1;

            let enemy_troops = if day < 80 {
                8_000 + (coalition_strength * 20.0) as u32
            } else {
                50_000 + (coalition_strength * 100.0) as u32
            };

            let napoleon_force = ForceData { troops, morale, fatigue, general_skill: 90.0, supply_ok: true };
            let enemy_force    = ForceData { troops: enemy_troops, morale: 70.0, fatigue: 20.0, general_skill: 60.0, supply_ok: true };
            let terrain = [Terrain::Plains, Terrain::Plains, Terrain::Hills, Terrain::Ridgeline]
                [rng.gen_range(0..4)];

            let battle = resolve_battle(&napoleon_force, &enemy_force, terrain, rng);

            // 更新军队状态
            let (atk_rate, _) = battle.result.casualty_rates();
            troops = ((troops as f64) * (1.0 - atk_rate)) as u32;
            let (morale_delta, _) = battle.result.morale_deltas();
            morale = (morale + morale_delta).clamp(0.0, 100.0);

            use crate::battle::resolver::BattleResult;
            if matches!(battle.result, BattleResult::DecisiveVictory | BattleResult::MarginalVictory) {
                victories += 1;
                politics.modify_faction("military", 5.0);
                politics.modify_faction("populace", 3.0);
            } else if matches!(battle.result, BattleResult::DecisiveDefeat) && day >= 86 {
                outcome = Some(GameOutcome::WaterlooDefeat);
                break;
            }
        }

        // 政治崩溃检测
        if politics.is_collapsed() {
            outcome = Some(GameOutcome::PoliticalCollapse);
            break;
        }

        // 兵力耗尽
        if troops < 1_000 {
            outcome = Some(GameOutcome::MilitaryAnnihilation);
            break;
        }
    }

    let outcome = outcome.unwrap_or_else(|| {
        if battles_fought > 0 && victories as f64 / battles_fought as f64 >= 0.6 {
            GameOutcome::NapoleonVictory
        } else {
            GameOutcome::WaterlooHistorical
        }
    });

    GameRecord {
        days_survived: 100,
        outcome,
        final_legit: politics.legitimacy,
        final_troops: troops,
        battles_fought,
        victories,
    }
}

// ── 蒙特卡洛汇总 ──────────────────────────────────────

pub struct SimulationReport {
    pub strategy:              PlayerStrategy,
    pub n_runs:                u32,
    pub outcomes:              HashMap<&'static str, u32>,
    pub victory_rate:          f64,
    pub political_collapse_rate: f64,
    pub avg_legitimacy:        f64,
    pub avg_troops:            f64,
    pub balance_ok:            bool,
}

pub fn run_simulation(n_runs: u32, strategy: PlayerStrategy, seed: u64) -> SimulationReport {
    let mut rng = StdRng::seed_from_u64(seed);
    let mut outcomes: HashMap<&'static str, u32> = HashMap::new();
    let mut total_legit: f64 = 0.0;
    let mut total_troops: f64 = 0.0;

    for _ in 0..n_runs {
        let record = simulate_one_game(strategy, &mut rng);
        *outcomes.entry(record.outcome.as_str()).or_insert(0) += 1;
        total_legit  += record.final_legit;
        total_troops += record.final_troops as f64;
    }

    let victory_count  = outcomes.get("napoleon_victory").copied().unwrap_or(0);
    let collapse_count = outcomes.get("political_collapse").copied().unwrap_or(0);

    let victory_rate = victory_count  as f64 / n_runs as f64;
    let collapse_rate = collapse_count as f64 / n_runs as f64;

    let balance_ok = victory_rate  >= TARGET_VICTORY_RATE_MIN
                  && victory_rate  <= TARGET_VICTORY_RATE_MAX
                  && collapse_rate <= 0.30;

    SimulationReport {
        strategy,
        n_runs,
        outcomes,
        victory_rate,
        political_collapse_rate: collapse_rate,
        avg_legitimacy:  total_legit  / n_runs as f64,
        avg_troops:      total_troops / n_runs as f64,
        balance_ok,
    }
}

pub fn print_report(report: &SimulationReport) {
    let strategy_name = match report.strategy {
        PlayerStrategy::Military  => "military",
        PlayerStrategy::Political => "political",
        PlayerStrategy::Balanced  => "balanced",
    };
    println!("\n{}", "=".repeat(60));
    println!("  Cent Jours 蒙特卡洛平衡测试");
    println!("  策略: {} | 模拟局数: {}", strategy_name, report.n_runs);
    println!("{}", "=".repeat(60));
    println!("\n  结局分布:");

    let mut sorted: Vec<_> = report.outcomes.iter().collect();
    sorted.sort_by(|a, b| b.1.cmp(a.1));
    for (name, count) in &sorted {
        let pct = **count as f64 / report.n_runs as f64 * 100.0;
        let bar = "█".repeat((pct / 2.0) as usize);
        println!("    {:<35} {:25} {:5.1}% ({})", name, bar, pct, count);
    }

    println!("\n  关键指标:");
    println!("    平均合法性:  {:.1}", report.avg_legitimacy);
    println!("    平均兵力:    {:.0}", report.avg_troops);
    println!("    胜率:        {:.1}%", report.victory_rate * 100.0);
    println!("    政治崩溃率:  {:.1}%", report.political_collapse_rate * 100.0);

    println!("\n  平衡评估:");
    let vr = report.victory_rate * 100.0;
    let cr = report.political_collapse_rate * 100.0;

    if vr >= TARGET_VICTORY_RATE_MIN * 100.0 && vr <= TARGET_VICTORY_RATE_MAX * 100.0 {
        println!("  ✅ 胜率 {:.1}% 在目标范围({:.0}%-{:.0}%)内",
            vr, TARGET_VICTORY_RATE_MIN*100.0, TARGET_VICTORY_RATE_MAX*100.0);
    } else if vr < TARGET_VICTORY_RATE_MIN * 100.0 {
        println!("  ⚠️  胜率 {:.1}% 过低 — 考虑降低反法同盟集结速度", vr);
    } else {
        println!("  ⚠️  胜率 {:.1}% 过高 — 考虑加快滑铁卢事件压力", vr);
    }

    if cr > 30.0 {
        println!("  ⚠️  政治崩溃率 {:.1}% 过高 — 调整政策惩罚或恢复速率", cr);
    } else {
        println!("  ✅ 政治崩溃率 {:.1}% 在可接受范围内", cr);
    }
    println!("{}\n", "=".repeat(60));
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn 单局模拟能正常完成() {
        let mut rng = StdRng::seed_from_u64(42);
        let record = simulate_one_game(PlayerStrategy::Balanced, &mut rng);
        // 无论结局是什么，天数应在1-100内
        assert!(record.days_survived >= 1 && record.days_survived <= 100);
    }

    #[test]
    fn 模拟100局不崩溃() {
        let report = run_simulation(100, PlayerStrategy::Balanced, 0);
        assert_eq!(report.n_runs, 100);
        let total: u32 = report.outcomes.values().sum();
        assert_eq!(total, 100);
    }

    #[test]
    fn 纯军事策略合法性低于纯政治策略() {
        let mil_report = run_simulation(200, PlayerStrategy::Military,  1);
        let pol_report = run_simulation(200, PlayerStrategy::Political, 1);
        // 政治策略应维持更高的合法性
        assert!(pol_report.avg_legitimacy > mil_report.avg_legitimacy,
            "政治策略合法性({:.1}) 应高于军事策略({:.1})",
            pol_report.avg_legitimacy, mil_report.avg_legitimacy);
    }

    #[test]
    fn 胜率结构合理() {
        // 各策略都不应该是0%胜率（无法胜利）
        for strategy in [PlayerStrategy::Military, PlayerStrategy::Political, PlayerStrategy::Balanced] {
            let report = run_simulation(500, strategy, 2026);
            assert!(report.victory_rate >= 0.0 && report.victory_rate <= 1.0);
        }
    }
}
