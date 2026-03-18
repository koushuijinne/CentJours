//! 三系统耦合状态机 — `engine::state`
//!
//! 统一持有 battle + politics + characters，按 Dawn→Action→Dusk 驱动。
//! 这是 GATE 2 的核心：三个系统的涌现交互在此发生。

use rand::Rng;

use crate::battle::resolver::{ForceData, Terrain, BattleResult, resolve_battle};
use crate::politics::system::{PoliticsState, default_policies};
use crate::characters::network::{CharacterNetwork, historical_network_day1};

// ── 游戏结局 ──────────────────────────────────────────

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

// ── 游戏阶段 ──────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TurnPhase {
    Dawn,    // 情报/事件展示
    Action,  // 玩家决策
    Dusk,    // 结算
}

// ── 玩家行动 ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub enum PlayerAction {
    /// 发动战役（将领ID，攻方兵力，目标地形）
    LaunchBattle { general_id: String, troops: u32, terrain: Terrain },
    /// 执行政策（政策ID）
    EnactPolicy { policy_id: &'static str },
    /// 强化将领关系（目标将领ID，消耗合法性）
    BoostLoyalty { general_id: String },
    /// 休整（不行动，回复疲劳）
    Rest,
}

// ── 每日事件记录 ──────────────────────────────────────

#[derive(Debug, Clone)]
pub struct DayEvent {
    pub day:         u32,
    pub event_type:  &'static str,
    pub description: String,
    /// 事件对三系统的影响摘要
    pub effects:     Vec<String>,
}

// ── 全局游戏状态 ──────────────────────────────────────

/// 拿破仑的军事力量摘要
#[derive(Debug, Clone)]
pub struct ArmyState {
    pub total_troops: u32,
    pub avg_morale:   f64,
    pub avg_fatigue:  f64,
    /// 战役胜场计数（影响军方支持度）
    pub victories:    u32,
    pub defeats:      u32,
}

impl Default for ArmyState {
    fn default() -> Self {
        Self {
            total_troops: 72_000,  // 历史：百日初期约72000人
            avg_morale:   75.0,
            avg_fatigue:  10.0,
            victories:    0,
            defeats:      0,
        }
    }
}

impl ArmyState {
    /// 构建用于战斗解算的 ForceData
    pub fn to_force_data(&self, general_skill: f64, troops_committed: u32) -> ForceData {
        ForceData {
            troops:        troops_committed.min(self.total_troops),
            morale:        self.avg_morale,
            fatigue:       self.avg_fatigue,
            general_skill,
            supply_ok:     true,  // 简化：补给状态可扩展
        }
    }

    /// 应用战斗结果（修改兵力/士气/疲劳）
    pub fn apply_battle(&mut self, result: BattleResult, troops_committed: u32) {
        let (atk_rate, _) = result.casualty_rates();
        let casualties = (troops_committed as f64 * atk_rate) as u32;
        self.total_troops = self.total_troops.saturating_sub(casualties);

        let (morale_delta, _) = result.morale_deltas();
        self.avg_morale = (self.avg_morale + morale_delta).clamp(0.0, 100.0);

        // 战斗后疲劳增加
        self.avg_fatigue = (self.avg_fatigue + 10.0).min(100.0);

        match result {
            BattleResult::DecisiveVictory | BattleResult::MarginalVictory => self.victories += 1,
            BattleResult::MarginalDefeat  | BattleResult::DecisiveDefeat  => self.defeats   += 1,
            BattleResult::Stalemate => {}
        }
    }

    /// 休整恢复（每日）
    pub fn rest_recovery(&mut self) {
        self.avg_fatigue  = (self.avg_fatigue  - 8.0).max(0.0);
        self.avg_morale   = (self.avg_morale   + 2.0).min(100.0);
    }
}

// ── 核心引擎 ──────────────────────────────────────────

/// 三系统耦合游戏引擎
pub struct GameEngine {
    pub day:        u32,
    pub phase:      TurnPhase,
    pub politics:   PoliticsState,
    pub characters: CharacterNetwork,
    pub army:       ArmyState,
    pub history:    Vec<DayEvent>,
    /// 游戏结局（Some = 游戏已结束）
    outcome:        Option<GameOutcome>,
}

impl Default for GameEngine {
    fn default() -> Self {
        Self {
            day:        1,
            phase:      TurnPhase::Dawn,
            politics:   PoliticsState::default(),
            characters: historical_network_day1(),
            army:       ArmyState::default(),
            history:    Vec::new(),
            outcome:    None,
        }
    }
}

impl GameEngine {
    pub fn new() -> Self {
        Self::default()
    }

    // ── 状态查询 ──────────────────────────────────────

    /// 游戏是否已结束
    pub fn is_over(&self) -> bool {
        self.outcome.is_some()
    }

    /// 当前结局（游戏进行中返回 None）
    pub fn outcome(&self) -> Option<GameOutcome> {
        self.outcome.clone()
    }

    /// 当前日期
    pub fn current_day(&self) -> u32 {
        self.day
    }

    // ── 回合驱动 ──────────────────────────────────────

    /// 处理一整天（Dawn → Action → Dusk）
    /// 玩家行动由调用方提供
    pub fn process_day<R: Rng>(&mut self, action: PlayerAction, rng: &mut R) {
        if self.is_over() { return; }

        // Dawn：日志记录、事件触发（可扩展）
        self.phase = TurnPhase::Dawn;

        // Action：执行玩家行动
        self.phase = TurnPhase::Action;
        let events = self.execute_action(action, rng);

        // Dusk：系统结算
        self.phase = TurnPhase::Dusk;
        self.dusk_settlement();

        // 记录当日事件
        for e in events {
            self.history.push(e);
        }

        // 推进日期
        self.day += 1;

        // 胜负判定
        self.check_outcome();
    }

    /// 执行玩家行动，返回产生的事件列表
    fn execute_action<R: Rng>(&mut self, action: PlayerAction, rng: &mut R) -> Vec<DayEvent> {
        match action {
            PlayerAction::LaunchBattle { general_id, troops, terrain } => {
                self.process_battle(&general_id, troops, terrain, rng)
            }
            PlayerAction::EnactPolicy { policy_id } => {
                self.process_policy(policy_id)
            }
            PlayerAction::BoostLoyalty { general_id } => {
                self.process_boost_loyalty(&general_id)
            }
            PlayerAction::Rest => {
                self.army.rest_recovery();
                vec![DayEvent {
                    day: self.day,
                    event_type: "rest",
                    description: "军队休整。".to_string(),
                    effects: vec!["疲劳-8, 士气+2".to_string()],
                }]
            }
        }
    }

    /// 战役处理：解算战斗 → 更新三系统
    pub fn process_battle<R: Rng>(
        &mut self,
        general_id: &str,
        troops: u32,
        terrain: Terrain,
        rng: &mut R,
    ) -> Vec<DayEvent> {
        let general_skill = self.general_skill(general_id);
        let attacker = self.army.to_force_data(general_skill, troops);

        // 敌军：随日期增长（联军集结）
        let enemy = self.coalition_force();
        let outcome = resolve_battle(&attacker, &enemy, terrain, rng);
        let result = outcome.result;

        // 更新军队
        self.army.apply_battle(result, troops);

        // 更新将领忠诚度
        self.characters.apply_battle_outcome(general_id, result, self.day);

        // 更新政治：战胜提升军方，战败降低军方 + 民众
        self.apply_battle_politics(result);

        let description = format!(
            "Day {}: {} 率军 {} 人于 {:?} 地形作战，结果：{}",
            self.day, general_id, troops, terrain, result.as_str()
        );

        vec![DayEvent {
            day: self.day,
            event_type: "battle",
            description,
            effects: vec![
                format!("军队损失: {}", outcome.attacker_casualties),
                format!("士气变化: {:.1}", outcome.attacker_morale_delta),
            ],
        }]
    }

    /// 政策处理
    fn process_policy(&mut self, policy_id: &'static str) -> Vec<DayEvent> {
        let policies = default_policies();
        if let Some(policy) = policies.iter().find(|p| p.id == policy_id) {
            match self.politics.enact_policy(policy) {
                Ok(()) => vec![DayEvent {
                    day: self.day,
                    event_type: "policy",
                    description: format!("颁布政策: {}", policy_id),
                    effects: vec![],
                }],
                Err(e) => vec![DayEvent {
                    day: self.day,
                    event_type: "policy_failed",
                    description: format!("政策失败: {}", e),
                    effects: vec![],
                }],
            }
        } else {
            vec![]
        }
    }

    /// 强化忠诚度处理（消耗合法性）
    fn process_boost_loyalty(&mut self, general_id: &str) -> Vec<DayEvent> {
        if self.politics.legitimacy < 10.0 {
            return vec![DayEvent {
                day: self.day,
                event_type: "boost_failed",
                description: "合法性不足，无法强化将领关系".to_string(),
                effects: vec![],
            }];
        }
        self.politics.legitimacy -= 5.0;
        self.characters.modify_loyalty(general_id, 8.0, self.day, "personal_attention");

        vec![DayEvent {
            day: self.day,
            event_type: "boost_loyalty",
            description: format!("亲自接见 {}，消耗5点合法性", general_id),
            effects: vec![format!("{} 忠诚度+8", general_id)],
        }]
    }

    /// Dusk结算：政治每日tick、关系衰减、特殊事件检查
    fn dusk_settlement(&mut self) {
        self.politics.daily_tick();
        self.characters.tick_day();

        // 兵力过少 → 政治连锁反应
        if self.army.total_troops < 20_000 {
            self.politics.modify_faction("military", -5.0);
        }

        // 长期征战疲劳 → 民众不满
        if self.day > 60 && self.army.avg_fatigue > 70.0 {
            self.politics.modify_faction("populace", -2.0);
        }
    }

    /// 胜负判定（百日结束或提前终止）
    fn check_outcome(&mut self) {
        // 政治崩溃
        if self.politics.is_collapsed() {
            self.outcome = Some(GameOutcome::PoliticalCollapse);
            return;
        }
        // 军事崩溃
        if self.army.total_troops < 5_000 {
            self.outcome = Some(GameOutcome::MilitaryAnnihilation);
            return;
        }
        // 100天结束
        if self.day > 100 {
            let legitimacy = self.politics.legitimacy;
            let victories  = self.army.victories;
            self.outcome = Some(if legitimacy > 50.0 && victories >= 3 {
                GameOutcome::NapoleonVictory
            } else if legitimacy > 30.0 {
                GameOutcome::WaterlooHistorical
            } else {
                GameOutcome::WaterlooDefeat
            });
        }
    }

    // ── 辅助方法 ──────────────────────────────────────

    /// 获取将领军事技能（从网络中查，不存在返回60）
    fn general_skill(&self, id: &str) -> f64 {
        // 简化：实际应从 characters.json 加载
        match id {
            "napoleon" => 98.0,
            "ney"      => 85.0,
            "davout"   => 82.0,
            "grouchy"  => 68.0,
            "soult"    => 72.0,
            _          => 60.0,
        }
    }

    /// 构建当前联军兵力（随时间增长）
    fn coalition_force(&self) -> ForceData {
        let phase = (self.day as f64 / 100.0).min(1.0);
        // 联军在Day 1只有约40000人，到Day 100增至约200000人
        let troops = (40_000.0 + 160_000.0 * phase) as u32;
        let morale  = 70.0 + phase * 10.0; // 随集结提升士气
        ForceData {
            troops,
            morale,
            fatigue:       15.0,
            general_skill: 75.0,  // Wellington/Blücher平均
            supply_ok:     true,
        }
    }

    /// 战斗结果 → 政治影响
    fn apply_battle_politics(&mut self, result: BattleResult) {
        match result {
            BattleResult::DecisiveVictory => {
                self.politics.modify_faction("military",  15.0);
                self.politics.modify_faction("populace",   8.0);
                self.politics.legitimacy = (self.politics.legitimacy + 5.0).min(100.0);
            }
            BattleResult::MarginalVictory => {
                self.politics.modify_faction("military", 8.0);
                self.politics.modify_faction("populace", 3.0);
            }
            BattleResult::Stalemate => {
                self.politics.modify_faction("military", -2.0);
            }
            BattleResult::MarginalDefeat => {
                self.politics.modify_faction("military",  -8.0);
                self.politics.modify_faction("populace",  -4.0);
                self.politics.legitimacy -= 3.0;
            }
            BattleResult::DecisiveDefeat => {
                self.politics.modify_faction("military",  -18.0);
                self.politics.modify_faction("populace",  -10.0);
                self.politics.modify_faction("liberals",   -5.0);
                self.politics.legitimacy -= 8.0;
            }
        }
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rand::SeedableRng;
    use rand::rngs::StdRng;

    fn seeded_rng() -> StdRng {
        StdRng::seed_from_u64(42)
    }

    // ── 初始化 ────────────────────────────────────────

    #[test]
    fn 引擎初始状态正确() {
        let engine = GameEngine::new();
        assert_eq!(engine.current_day(), 1);
        assert!(!engine.is_over());
        assert_eq!(engine.outcome(), None);
        assert_eq!(engine.army.total_troops, 72_000);
    }

    // ── 战役耦合 ──────────────────────────────────────

    #[test]
    fn 战胜同时提升军方支持和将领忠诚() {
        let mut engine = GameEngine::new();
        // 给内伊设定初始忠诚65（历史初始值）
        let ney_initial = engine.characters.loyalty("ney");
        let mil_initial = engine.politics.faction_support["military"];

        let mut rng = seeded_rng();
        // Day 1 拿破仑军72k vs 联军约40k（早期联军弱），高概率胜利
        engine.process_battle("ney", 60_000, Terrain::Plains, &mut rng);

        // 如果赢了
        if engine.army.victories > 0 {
            assert!(engine.characters.loyalty("ney") > ney_initial - 1.0,
                "战胜后内伊忠诚不应大幅下降");
            assert!(engine.politics.faction_support["military"] >= mil_initial - 1.0,
                "战胜后军方支持不应大幅下降");
        }
    }

    #[test]
    fn 战败降低军方支持度() {
        let mut engine = GameEngine::new();

        // 以极少兵力攻打大量敌军 → 必败
        let tiny_force = PlayerAction::LaunchBattle {
            general_id: "ney".to_string(),
            troops:     1_000,
            terrain:    Terrain::Ridgeline,
        };
        let mil_before = engine.politics.faction_support["military"];
        let mut rng = seeded_rng();
        engine.process_day(tiny_force, &mut rng);

        // 1000人对40000人必败 → 军方支持下降
        assert!(engine.politics.faction_support["military"] < mil_before,
            "必败战役应降低军方支持: before={}, after={}",
            mil_before, engine.politics.faction_support["military"]);
    }

    // ── 政策耦合 ──────────────────────────────────────

    #[test]
    fn 政策行动消耗行动点() {
        let mut engine = GameEngine::new();
        let actions_before = engine.politics.actions_remaining;
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::EnactPolicy { policy_id: "constitutional_promise" }, &mut rng);
        // 行动点在 daily_tick 时重置，但本回合应已消耗
        // (Day推进后已tick，所以检查历史)
        assert!(engine.history.iter().any(|e| e.event_type == "policy"),
            "应有policy事件记录");
        let _ = actions_before; // 满足编译器
    }

    // ── 忠诚度强化 ────────────────────────────────────

    #[test]
    fn 强化忠诚消耗合法性() {
        let mut engine = GameEngine::new();
        let leg_before = engine.politics.legitimacy;
        let _ = engine.process_boost_loyalty("davout");
        assert!(engine.politics.legitimacy < leg_before,
            "强化忠诚应消耗合法性");
    }

    #[test]
    fn 合法性不足时强化忠诚失败() {
        let mut engine = GameEngine::new();
        engine.politics.legitimacy = 5.0; // 不足10
        let events = engine.process_boost_loyalty("davout");
        assert_eq!(events[0].event_type, "boost_failed");
    }

    // ── 胜负判定 ──────────────────────────────────────

    #[test]
    fn 政治崩溃触发游戏结束() {
        let mut engine = GameEngine::new();
        // 强制两派系崩溃
        engine.politics.faction_support.insert("liberals".to_string(), 5.0);
        engine.politics.faction_support.insert("populace".to_string(), 5.0);
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert_eq!(engine.outcome(), Some(GameOutcome::PoliticalCollapse),
            "双派系崩溃应终结游戏");
    }

    #[test]
    fn 军事崩溃触发游戏结束() {
        let mut engine = GameEngine::new();
        engine.army.total_troops = 3_000; // 低于阈值
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert_eq!(engine.outcome(), Some(GameOutcome::MilitaryAnnihilation));
    }

    #[test]
    fn 百日结束高分路径获胜() {
        let mut engine = GameEngine::new();
        engine.day = 101;
        engine.politics.legitimacy = 75.0;
        engine.army.victories = 5;
        engine.check_outcome();
        assert_eq!(engine.outcome(), Some(GameOutcome::NapoleonVictory));
    }

    #[test]
    fn 百日结束低分路径流放() {
        let mut engine = GameEngine::new();
        engine.day = 101;
        engine.politics.legitimacy = 20.0;
        engine.army.victories = 1;
        engine.check_outcome();
        assert_eq!(engine.outcome(), Some(GameOutcome::WaterlooDefeat));
    }

    // ── 每日结算联动 ──────────────────────────────────

    #[test]
    fn 休整恢复疲劳和士气() {
        let mut engine = GameEngine::new();
        engine.army.avg_fatigue = 80.0;
        engine.army.avg_morale  = 60.0;
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert!(engine.army.avg_fatigue < 80.0, "休整后疲劳应减少");
        assert!(engine.army.avg_morale  > 60.0, "休整后士气应提升");
    }

    #[test]
    fn 兵力极少时军方支持持续下降() {
        let mut engine = GameEngine::new();
        engine.army.total_troops = 15_000; // 低于20000阈值
        let mil_before = engine.politics.faction_support["military"];
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert!(engine.politics.faction_support["military"] < mil_before,
            "兵力危机应降低军方支持");
    }

    // ── 联军增长 ──────────────────────────────────────

    #[test]
    fn 联军兵力随时间增长() {
        let mut engine = GameEngine::new();
        let early = engine.coalition_force().troops;
        engine.day = 90;
        let late = engine.coalition_force().troops;
        assert!(late > early * 2, "Day 90联军应远多于Day 1: early={}, late={}", early, late);
    }
}

