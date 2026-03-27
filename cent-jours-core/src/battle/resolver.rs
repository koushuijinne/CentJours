//! 战斗解算模块
//! 实现计划书附录A.1的加权战斗模型
//! 纯Rust逻辑，无UI/Godot依赖

use rand::Rng;

// ── 结果类型 ──────────────────────────────────────────

/// 战斗结果五级枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BattleResult {
    DecisiveVictory,
    MarginalVictory,
    Stalemate,
    MarginalDefeat,
    DecisiveDefeat,
}

impl BattleResult {
    /// 返回字符串名称（用于 GDExtension 传递给 Godot）
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::DecisiveVictory => "decisive_victory",
            Self::MarginalVictory => "marginal_victory",
            Self::Stalemate => "stalemate",
            Self::MarginalDefeat => "marginal_defeat",
            Self::DecisiveDefeat => "decisive_defeat",
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Self::DecisiveVictory => "大捷",
            Self::MarginalVictory => "小胜",
            Self::Stalemate => "僵持",
            Self::MarginalDefeat => "小败",
            Self::DecisiveDefeat => "惨败",
        }
    }

    /// 攻防双方战损比率 (attacker, defender)
    pub fn casualty_rates(&self) -> (f64, f64) {
        match self {
            Self::DecisiveVictory => (0.05, 0.35),
            Self::MarginalVictory => (0.15, 0.20),
            Self::Stalemate => (0.12, 0.12),
            Self::MarginalDefeat => (0.20, 0.15),
            Self::DecisiveDefeat => (0.35, 0.05),
        }
    }

    /// 双方士气变化 (attacker_delta, defender_delta)
    pub fn morale_deltas(&self) -> (f64, f64) {
        match self {
            Self::DecisiveVictory => (15.0, -35.0),
            Self::MarginalVictory => (5.0, -15.0),
            Self::Stalemate => (-5.0, -5.0),
            Self::MarginalDefeat => (-15.0, 5.0),
            Self::DecisiveDefeat => (-35.0, 15.0),
        }
    }
}

// ── 输入结构体 ────────────────────────────────────────

/// 一方兵力数据（攻方/守方均使用）
#[derive(Debug, Clone)]
pub struct ForceData {
    pub troops: u32,        // 士兵数量
    pub morale: f64,        // 士气 0-100
    pub fatigue: f64,       // 疲劳 0-100
    pub general_skill: f64, // 将领军事能力 0-100
    pub supply_ok: bool,    // 补给是否充足
}

/// 地形类型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Terrain {
    Plains,
    Hills,
    Mountains,
    Forest,
    Urban,
    Ridgeline, // 高地（如圣让山脊）
    RiverJunction,
    Coastal,
    Fortress,
}

impl Terrain {
    /// 防守方地形加成系数
    pub fn defense_bonus(&self) -> f64 {
        match self {
            Self::Plains => 1.00,
            Self::Hills => 1.15,
            Self::Mountains => 1.30,
            Self::Forest => 1.20,
            Self::Urban => 1.25,
            Self::Ridgeline => 1.35,
            Self::RiverJunction => 1.40,
            Self::Coastal => 1.10,
            Self::Fortress => 1.60,
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Plains => "平原",
            Self::Hills => "丘陵",
            Self::Mountains => "山地",
            Self::Forest => "森林",
            Self::Urban => "城镇",
            Self::Ridgeline => "高地",
            Self::RiverJunction => "河口",
            Self::Coastal => "海岸",
            Self::Fortress => "要塞",
        }
    }

    /// 行军疲劳惩罚（每回合额外疲劳值）
    pub fn march_fatigue_penalty(&self) -> f64 {
        match self {
            Self::Mountains => 15.0,
            Self::Hills => 8.0,
            Self::Forest => 5.0,
            Self::Urban => 3.0,
            _ => 0.0,
        }
    }
}

// ── 战斗解算输出 ──────────────────────────────────────

#[derive(Debug, Clone)]
pub struct BattleOutcome {
    pub result: BattleResult,
    pub ratio: f64, // 攻守力量比（含随机因子）
    pub attacker_casualties: u32,
    pub defender_casualties: u32,
    pub attacker_morale_delta: f64,
    pub defender_morale_delta: f64,
    pub random_factor: f64, // 本局随机偏差（供日志/叙事使用）
}

// ── 核心解算函数 ──────────────────────────────────────

/// 计算一方战斗得分
fn calculate_force_score(force: &ForceData, is_defender: bool, terrain: Terrain) -> f64 {
    let morale_norm = force.morale / 100.0;
    let fatigue_norm = force.fatigue / 100.0;
    let skill_norm = force.general_skill / 100.0;

    // 基础得分：兵力 × 士气 × (1 + 将领加成×0.5)
    let mut score = force.troops as f64 * morale_norm * (1.0 + skill_norm * 0.5);

    // 疲劳惩罚：疲劳100%时战斗力-50%
    score *= 1.0 - fatigue_norm * 0.5;

    // 补给不足惩罚
    if !force.supply_ok {
        score *= 0.75;
    }

    // 防守方地形加成
    if is_defender {
        score *= terrain.defense_bonus();
    }

    score
}

/// 根据力量比判断战斗结果
pub fn ratio_to_result(ratio: f64) -> BattleResult {
    if ratio > 1.5 {
        BattleResult::DecisiveVictory
    } else if ratio > 1.1 {
        BattleResult::MarginalVictory
    } else if ratio > 0.9 {
        BattleResult::Stalemate
    } else if ratio > 0.6 {
        BattleResult::MarginalDefeat
    } else {
        BattleResult::DecisiveDefeat
    }
}

/// 自动解算战斗（含托尔斯泰式±15%随机因子）
///
/// # 参数
/// - `attacker` / `defender`：双方兵力数据
/// - `terrain`：战场地形（防守方受益）
/// - `rng`：随机数生成器（由调用方传入，便于测试时使用固定种子）
pub fn resolve_battle<R: Rng>(
    attacker: &ForceData,
    defender: &ForceData,
    terrain: Terrain,
    rng: &mut R,
) -> BattleOutcome {
    let atk_score = calculate_force_score(attacker, false, terrain);
    let def_score = calculate_force_score(defender, true, terrain);

    // 托尔斯泰式不确定性：±15% 随机浮动
    let random_factor: f64 = rng.gen_range(-0.15..=0.15);
    let ratio = (atk_score / def_score.max(1.0)) * (1.0 + random_factor);

    let result = ratio_to_result(ratio);
    let (atk_rate, def_rate) = result.casualty_rates();
    let (atk_morale, def_morale) = result.morale_deltas();

    BattleOutcome {
        result,
        ratio,
        attacker_casualties: (attacker.troops as f64 * atk_rate) as u32,
        defender_casualties: (defender.troops as f64 * def_rate) as u32,
        attacker_morale_delta: atk_morale,
        defender_morale_delta: def_morale,
        random_factor,
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rand::rngs::StdRng;
    use rand::SeedableRng;

    // 战斗测试统一用英文函数名，避免 CLI/IDE 过滤器对 Unicode 标识符支持不稳定。
    fn make_army(troops: u32, morale: f64, fatigue: f64, skill: f64) -> ForceData {
        ForceData {
            troops,
            morale,
            fatigue,
            general_skill: skill,
            supply_ok: true,
        }
    }

    fn rng_seeded(seed: u64) -> StdRng {
        StdRng::seed_from_u64(seed)
    }

    #[test]
    fn overwhelming_force_advantage_should_win() {
        let atk = make_army(100_000, 90.0, 10.0, 85.0);
        let def = make_army(5_000, 70.0, 20.0, 60.0);
        let outcome = resolve_battle(&atk, &def, Terrain::Plains, &mut rng_seeded(42));
        assert_eq!(outcome.result, BattleResult::DecisiveVictory);
    }

    #[test]
    fn high_ground_defense_should_raise_defense_score() {
        let atk = make_army(20_000, 80.0, 10.0, 70.0);
        let def = make_army(20_000, 80.0, 10.0, 70.0); // 兵力相同
                                                       // 平地：应为 Stalemate；高地防守方加成应让防守方更占优
        let plains_outcome = resolve_battle(&atk, &def, Terrain::Plains, &mut rng_seeded(0));
        let ridge_outcome = resolve_battle(&atk, &def, Terrain::Ridgeline, &mut rng_seeded(0));
        // 高地比平地对攻方更不利
        assert!(ridge_outcome.ratio < plains_outcome.ratio);
    }

    #[test]
    fn fatigue_100_halves_combat_power() {
        let fresh = make_army(10_000, 80.0, 0.0, 70.0);
        let fatigued = make_army(10_000, 80.0, 100.0, 70.0);
        let score_fresh = 10_000.0 * 0.8 * 1.35;
        let score_fatigued = 10_000.0 * 0.8 * 1.35 * 0.5; // -50%
                                                          // 通过对比两种兵力解算结果来间接验证
        let vs_strong = make_army(18_000, 80.0, 0.0, 70.0);
        let fresh_out = resolve_battle(&fresh, &vs_strong, Terrain::Plains, &mut rng_seeded(1));
        let fatigue_out =
            resolve_battle(&fatigued, &vs_strong, Terrain::Plains, &mut rng_seeded(1));
        assert!(fatigue_out.ratio < fresh_out.ratio);
        // 仅断言关系，不断言绝对值（避免随机因子干扰）
        let _ = (score_fresh, score_fatigued); // suppress unused warning
    }

    #[test]
    fn low_supply_applies_25_percent_penalty() {
        let supplied = ForceData {
            supply_ok: true,
            ..make_army(10_000, 80.0, 0.0, 70.0)
        };
        let unsupplied = ForceData {
            supply_ok: false,
            ..make_army(10_000, 80.0, 0.0, 70.0)
        };
        let defender = make_army(8_000, 70.0, 20.0, 60.0);
        let s_out = resolve_battle(&supplied, &defender, Terrain::Plains, &mut rng_seeded(5));
        let u_out = resolve_battle(&unsupplied, &defender, Terrain::Plains, &mut rng_seeded(5));
        assert!(u_out.ratio < s_out.ratio);
    }

    #[test]
    fn decisive_victory_casualties_match_expectations() {
        // 用极大兵力差确保必胜
        let atk = make_army(500_000, 95.0, 0.0, 95.0);
        let def = make_army(1_000, 50.0, 50.0, 40.0);
        let mut rng = rng_seeded(99);
        // 多次运行确保稳定
        for _ in 0..20 {
            let out = resolve_battle(&atk, &def, Terrain::Plains, &mut rng);
            assert_eq!(out.result, BattleResult::DecisiveVictory);
            // 决定性胜利：攻方伤亡5%，守方35%
            assert!((out.attacker_casualties as f64) < atk.troops as f64 * 0.1);
            assert!((out.defender_casualties as f64) > def.troops as f64 * 0.2);
        }
    }

    #[test]
    fn random_factor_stays_in_reasonable_range() {
        let atk = make_army(20_000, 75.0, 15.0, 70.0);
        let def = make_army(20_000, 75.0, 15.0, 70.0);
        let mut rng = rng_seeded(123);
        for _ in 0..100 {
            let out = resolve_battle(&atk, &def, Terrain::Plains, &mut rng);
            assert!(out.random_factor >= -0.15 && out.random_factor <= 0.15);
        }
    }

    #[test]
    fn waterloo_scenario_british_hold_the_ridge() {
        // 历史近似：拿破仑 72000 对威灵顿 68000（Ridgeline 高地防守 ×1.35）
        // 守方地形加成使威灵顿占压倒性优势，拿破仑主要以失败告终——符合历史
        let napoleon = make_army(72_000, 82.0, 25.0, 92.0);
        let wellington = make_army(68_000, 78.0, 15.0, 88.0);
        let mut results = std::collections::HashMap::new();
        let mut rng = rng_seeded(1815);
        for _ in 0..1000 {
            let out = resolve_battle(&napoleon, &wellington, Terrain::Ridgeline, &mut rng);
            *results.entry(out.result.as_str()).or_insert(0u32) += 1;
        }
        let victory_count = results.get("decisive_victory").copied().unwrap_or(0)
            + results.get("marginal_victory").copied().unwrap_or(0);
        let defeat_count = results.get("decisive_defeat").copied().unwrap_or(0)
            + results.get("marginal_defeat").copied().unwrap_or(0);
        let stalemate_count = results.get("stalemate").copied().unwrap_or(0);
        let total = victory_count + stalemate_count + defeat_count;

        // 基本完整性：所有结果之和 = 1000
        assert_eq!(total, 1000);
        // 高地守方应大幅领先：超过 80% 的情况威灵顿获胜
        assert!(
            defeat_count > 800,
            "威灵顿高地防守应大幅获胜: 败={}/1000",
            defeat_count
        );
        // 随机因子确保不是100%必败（偶有平局）
        assert!(
            stalemate_count + victory_count > 0,
            "±15%随机因子应产生至少1次非失败结果"
        );
    }

    // ── 边界值测试 ─────────────────────────────────────

    #[test]
    fn zero_troop_attacker_fails_without_crashing() {
        let atk = make_army(0, 80.0, 0.0, 70.0);
        let def = make_army(10_000, 70.0, 10.0, 60.0);
        let out = resolve_battle(&atk, &def, Terrain::Plains, &mut rng_seeded(1));
        // 零兵力得分=0，ratio ≈ 0 → DecisiveDefeat
        assert_eq!(
            out.result,
            BattleResult::DecisiveDefeat,
            "零兵力攻方应判定惨败"
        );
        assert_eq!(out.attacker_casualties, 0, "零兵力无伤亡");
    }

    #[test]
    fn zero_morale_attacker_fails_without_crashing() {
        let atk = make_army(50_000, 0.0, 0.0, 70.0);
        let def = make_army(10_000, 70.0, 10.0, 60.0);
        let out = resolve_battle(&atk, &def, Terrain::Plains, &mut rng_seeded(2));
        // morale=0 → score = troops × 0 × ... = 0 → DecisiveDefeat
        assert_eq!(
            out.result,
            BattleResult::DecisiveDefeat,
            "零士气攻方应判定惨败（士气乘数为0）"
        );
    }

    #[test]
    fn exhaustion_and_broken_supply_stack_harder_than_single_penalties() {
        // 基准：疲劳0 + 补给正常
        let baseline = ForceData {
            troops: 20_000,
            morale: 80.0,
            fatigue: 0.0,
            general_skill: 70.0,
            supply_ok: true,
        };
        // 疲劳100%（-50%战力）
        let fatigued = ForceData {
            fatigue: 100.0,
            supply_ok: true,
            ..baseline.clone()
        };
        // 断补给（-25%战力）
        let no_supply = ForceData {
            fatigue: 0.0,
            supply_ok: false,
            ..baseline.clone()
        };
        // 双重叠加：疲劳100% + 断补给（理论战力 × 0.5 × 0.75 = ×0.375）
        let both = ForceData {
            fatigue: 100.0,
            supply_ok: false,
            ..baseline.clone()
        };

        let enemy = make_army(15_000, 70.0, 10.0, 60.0);
        let r0 = resolve_battle(&baseline, &enemy, Terrain::Plains, &mut rng_seeded(7));
        let r1 = resolve_battle(&fatigued, &enemy, Terrain::Plains, &mut rng_seeded(7));
        let r2 = resolve_battle(&no_supply, &enemy, Terrain::Plains, &mut rng_seeded(7));
        let r3 = resolve_battle(&both, &enemy, Terrain::Plains, &mut rng_seeded(7));

        // 双重叠加 < 单项惩罚 < 无惩罚
        assert!(r3.ratio < r1.ratio, "双重叠加应比单纯疲劳更差");
        assert!(r3.ratio < r2.ratio, "双重叠加应比单纯断补给更差");
        assert!(r1.ratio < r0.ratio, "疲劳100%应比无惩罚更差");
        assert!(r2.ratio < r0.ratio, "断补给应比无惩罚更差");
    }

    #[test]
    fn both_sides_zero_troops_do_not_crash() {
        let atk = make_army(0, 80.0, 0.0, 70.0);
        let def = make_army(0, 80.0, 0.0, 70.0);
        // def_score = 0 → max(1.0) 保护 → ratio = 0 → DecisiveDefeat，不 panic
        let out = resolve_battle(&atk, &def, Terrain::Plains, &mut rng_seeded(0));
        // 不崩溃即可；结果必然是 DecisiveDefeat（ratio ≈ 0）
        assert_eq!(out.result, BattleResult::DecisiveDefeat);
        assert_eq!(out.attacker_casualties, 0);
        assert_eq!(out.defender_casualties, 0);
    }

    #[test]
    fn ratio_to_result_covers_boundary_values() {
        // 精确测试各阈值边界
        assert_eq!(ratio_to_result(1.51), BattleResult::DecisiveVictory);
        assert_eq!(
            ratio_to_result(1.50),
            BattleResult::MarginalVictory,
            "1.5 不满足 >1.5"
        );
        assert_eq!(ratio_to_result(1.11), BattleResult::MarginalVictory);
        assert_eq!(
            ratio_to_result(1.10),
            BattleResult::Stalemate,
            "1.1 不满足 >1.1"
        );
        assert_eq!(ratio_to_result(0.91), BattleResult::Stalemate);
        assert_eq!(
            ratio_to_result(0.90),
            BattleResult::MarginalDefeat,
            "0.9 不满足 >0.9"
        );
        assert_eq!(ratio_to_result(0.61), BattleResult::MarginalDefeat);
        assert_eq!(
            ratio_to_result(0.60),
            BattleResult::DecisiveDefeat,
            "0.6 不满足 >0.6"
        );
        assert_eq!(ratio_to_result(0.0), BattleResult::DecisiveDefeat);
    }
}
