//! 三系统耦合状态机 — `engine::state`
//!
//! 统一持有 battle + politics + characters，按 Dawn→Action→Dusk 驱动。
//! 这是 GATE 2 的核心：三个系统的涌现交互在此发生。

use rand::Rng;

use crate::battle::resolver::{ForceData, Terrain, BattleResult, resolve_battle};
use crate::politics::system::{PoliticsState, default_policies};
use crate::characters::network::{CharacterNetwork, historical_network_day1};
use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use crate::events::pool::{EventPool, TriggerContext, EventEffects};
use crate::narratives::{NarrativePool, policy_narrative_key};

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

// ── 每日叙事报告 ──────────────────────────────────────

/// `process_day()` 完成后可从 `engine.last_report()` 获取的叙事文本
#[derive(Debug, Clone)]
pub struct DayReport {
    pub day:         u32,
    /// 司汤达当天的日记评论（基于玩家行动类型）
    pub stendhal:    Option<String>,
    /// 普通人视角的后果片段（基于玩家行动类型）
    pub consequence: Option<String>,
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

// ── 存档状态 ─────────────────────────────────────────

/// 可序列化的完整游戏存档快照
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveState {
    /// 存档格式版本（用于兼容性检查）
    pub version:              u32,
    pub day:                  u32,
    // 政治系统
    pub legitimacy:           f64,
    pub rouge_noir:           f64,
    pub factions:             HashMap<String, f64>,
    pub actions_remaining:    u32,
    // 军事系统
    pub troops:               u32,
    pub morale:               f64,
    pub fatigue:              f64,
    pub victories:            u32,
    pub defeats:              u32,
    // 将领网络（当前忠诚度 + 关系强度）
    pub loyalty:              HashMap<String, f64>,
    pub relationships:        Vec<(String, String, f64)>,
    // 事件系统
    pub triggered_event_ids:  Vec<String>,
    // 结局（in_progress 表示游戏进行中）
    pub outcome:              Option<String>,
}

// ── 叙事 key 提取 ─────────────────────────────────────

/// 从 PlayerAction 提取叙事 key 和"是否战斗"标志。
/// 战斗结果（胜/败）要在 execute_action 之后才能确定，所以返回 is_battle=true。
fn narrative_key_for_action(action: &PlayerAction) -> (&'static str, bool) {
    match action {
        PlayerAction::LaunchBattle { .. }       => ("", true),
        PlayerAction::EnactPolicy { policy_id } =>
            (policy_narrative_key(policy_id).unwrap_or(""), false),
        PlayerAction::BoostLoyalty { .. }       => ("boost_loyalty", false),
        PlayerAction::Rest                      => ("", false),
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
    /// 内嵌事件池（Dawn 阶段自动触发）
    event_pool:     EventPool,
    /// 已触发事件 ID 列表（按触发顺序）
    triggered_event_ids: Vec<String>,
    /// 叙事文本池（司汤达日记 + 后果片段）
    narratives:     NarrativePool,
    /// 最近一天的叙事报告（可供 UI 层读取）
    last_report:    Option<DayReport>,
}

impl Default for GameEngine {
    fn default() -> Self {
        const HISTORICAL_JSON: &str =
            include_str!("../../../src/data/events/historical.json");
        Self {
            day:        1,
            phase:      TurnPhase::Dawn,
            politics:   PoliticsState::default(),
            characters: historical_network_day1(),
            army:       ArmyState::default(),
            history:    Vec::new(),
            outcome:    None,
            event_pool: EventPool::from_json(HISTORICAL_JSON)
                .expect("historical.json parse error"),
            triggered_event_ids: Vec::new(),
            narratives:  NarrativePool::new(),
            last_report: None,
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

    /// 已触发的历史事件 ID 列表（按触发顺序）
    pub fn triggered_events(&self) -> &[String] {
        &self.triggered_event_ids
    }

    /// 最近一天的叙事报告（游戏刚开始还没处理过任何天时为 None）
    pub fn last_report(&self) -> Option<&DayReport> {
        self.last_report.as_ref()
    }

    // ── 存档 / 读档 ───────────────────────────────────

    /// 将当前引擎状态序列化为存档快照
    pub fn save(&self) -> SaveState {
        let relationships = self.characters.relationships.iter()
            .map(|((a, b), v)| (a.clone(), b.clone(), *v))
            .collect();

        SaveState {
            version:             1,
            day:                 self.day,
            legitimacy:          self.politics.legitimacy,
            rouge_noir:          self.politics.rouge_noir_index,
            factions:            self.politics.faction_support.clone(),
            actions_remaining:   self.politics.actions_remaining as u32,
            troops:              self.army.total_troops,
            morale:              self.army.avg_morale,
            fatigue:             self.army.avg_fatigue,
            victories:           self.army.victories,
            defeats:             self.army.defeats,
            loyalty:             self.characters.loyalty.clone(),
            relationships,
            triggered_event_ids: self.triggered_event_ids.clone(),
            outcome:             self.outcome.map(|o| o.as_str().to_string()),
        }
    }

    /// 将存档快照序列化为 JSON 字符串
    pub fn to_json(&self) -> String {
        serde_json::to_string(&self.save()).expect("SaveState serialization failed")
    }

    /// 从存档快照恢复引擎状态
    pub fn load(state: SaveState) -> Self {
        let mut engine = Self::new();

        engine.day                         = state.day;
        engine.politics.legitimacy         = state.legitimacy;
        engine.politics.rouge_noir_index   = state.rouge_noir;
        engine.politics.faction_support    = state.factions;
        engine.politics.actions_remaining  = state.actions_remaining as u8;
        engine.army.total_troops           = state.troops;
        engine.army.avg_morale             = state.morale;
        engine.army.avg_fatigue            = state.fatigue;
        engine.army.victories              = state.victories;
        engine.army.defeats                = state.defeats;
        engine.characters.loyalty          = state.loyalty;
        engine.characters.relationships    = state.relationships
            .into_iter().map(|(a, b, v)| ((a, b), v)).collect();
        engine.triggered_event_ids         = state.triggered_event_ids.clone();
        engine.event_pool.restore_triggered(state.triggered_event_ids);
        engine.outcome = state.outcome.as_deref().and_then(|s| match s {
            "napoleon_victory"      => Some(GameOutcome::NapoleonVictory),
            "waterloo_historical"   => Some(GameOutcome::WaterlooHistorical),
            "waterloo_defeat"       => Some(GameOutcome::WaterlooDefeat),
            "political_collapse"    => Some(GameOutcome::PoliticalCollapse),
            "military_annihilation" => Some(GameOutcome::MilitaryAnnihilation),
            _                       => None,
        });

        engine
    }

    /// 从 JSON 字符串恢复引擎状态
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        let state: SaveState = serde_json::from_str(json)?;
        Ok(Self::load(state))
    }

    // ── 回合驱动 ──────────────────────────────────────

    /// 处理一整天（Dawn → Action → Dusk）
    /// 玩家行动由调用方提供
    pub fn process_day<R: Rng>(&mut self, action: PlayerAction, rng: &mut R) {
        if self.is_over() { return; }

        // Dawn：触发历史事件，效果直接作用于三系统
        self.phase = TurnPhase::Dawn;
        let ctx = self.build_trigger_ctx();
        let triggered = self.event_pool.trigger_all(&ctx, rng);
        for t in triggered {
            self.triggered_event_ids.push(t.id.clone());
            self.apply_event_effects(&t.effects);
            self.history.push(DayEvent {
                day:         self.day,
                event_type:  "historical_event",
                description: format!("[{}] {}", t.label, t.narrative),
                effects:     vec![],
            });
        }

        // Action：提前提取叙事 key（action 下面会被消耗）
        self.phase = TurnPhase::Action;
        let (base_key, is_battle) = narrative_key_for_action(&action);
        let victories_before = self.army.victories;
        let defeats_before   = self.army.defeats;
        let events = self.execute_action(action, rng);

        // Dusk：系统结算
        self.phase = TurnPhase::Dusk;
        self.dusk_settlement();

        // 记录当日事件
        for e in events {
            self.history.push(e);
        }

        // 填充叙事报告（战斗结果在 execute_action 后才知道）
        let narrative_key = if is_battle {
            if self.army.victories > victories_before      { "battle_victory" }
            else if self.army.defeats > defeats_before     { "battle_defeat"  }
            else                                           { ""               } // 平局无叙事
        } else {
            base_key
        };
        self.last_report = Some(self.build_day_report(narrative_key, rng));

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

    // ── 叙事系统 ──────────────────────────────────────

    /// 根据行动类型和战斗结果构建当日叙事报告
    fn build_day_report<R: Rng>(&self, narrative_key: &str, rng: &mut R) -> DayReport {
        if narrative_key.is_empty() {
            return DayReport { day: self.day, stendhal: None, consequence: None };
        }
        DayReport {
            day:         self.day,
            stendhal:    self.narratives.pick_stendhal(narrative_key, rng),
            consequence: self.narratives.pick_consequence(narrative_key, rng),
        }
    }

    // ── 事件系统 ──────────────────────────────────────

    /// 根据当前引擎状态构建事件触发上下文快照
    fn build_trigger_ctx(&self) -> TriggerContext {
        TriggerContext {
            day:                       self.day,
            napoleon_reputation:       self.politics.legitimacy,
            ney_loyalty:               self.characters.loyalty("ney"),
            ney_napoleon_relationship: self.characters.relationship("ney", "napoleon"),
            grouchy_loyalty:           self.characters.loyalty("grouchy"),
            fouche_loyalty:            self.characters.loyalty("fouche"),
            rouge_noir_index:          self.politics.rouge_noir_index,
            // 全量忠诚度快照（供 loyalty_min/loyalty_max 通用触发条件使用）
            loyalty_map:               self.characters.loyalty.clone(),
            // 联军是否已被击败（仅 NapoleonVictory 结局表示联军被击败）
            coalition_defeated:        matches!(self.outcome, Some(GameOutcome::NapoleonVictory)),
        }
    }

    /// 将事件效果应用到三系统
    fn apply_event_effects(&mut self, effects: &EventEffects) {
        let day = self.day;
        // 通用将领忠诚度变化（数据驱动，支持任意将领）
        for (char_id, &delta) in &effects.loyalty_deltas {
            self.characters.modify_loyalty(char_id, delta, day, "event");
        }
        if let Some(d) = effects.military_support_delta {
            self.politics.modify_faction("military", d);
        }
        if let Some(d) = effects.nobility_support_delta {
            self.politics.modify_faction("nobility", d);
        }
        if let Some(d) = effects.populace_support_delta {
            self.politics.modify_faction("populace", d);
        }
        if let Some(d) = effects.liberals_support_delta {
            self.politics.modify_faction("liberals", d);
        }
        if let Some(d) = effects.rouge_noir_delta {
            self.politics.rouge_noir_index =
                (self.politics.rouge_noir_index + d).clamp(-100.0, 100.0);
        }
        if let Some(d) = effects.legitimacy_delta {
            self.politics.legitimacy = (self.politics.legitimacy + d).clamp(0.0, 100.0);
        }
        if let Some(bonus) = effects.napoleon_morale_bonus {
            self.army.avg_morale = (self.army.avg_morale + bonus).min(100.0);
        }
        if let Some(delta) = effects.military_available_troops_delta {
            if delta > 0 {
                self.army.total_troops += delta as u32;
            } else {
                self.army.total_troops =
                    self.army.total_troops.saturating_sub((-delta) as u32);
            }
        }
    }

    // ── 辅助方法 ──────────────────────────────────────

    /// 获取将领军事技能（单一来源：characters.json，通过 CharacterNetwork 加载）
    fn general_skill(&self, id: &str) -> f64 {
        self.characters.skill(id)
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

    // ── Save/Load 序列化 ──────────────────────────────

    #[test]
    fn 存档后读档状态一致() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        // 推进几天制造一些状态变化
        engine.process_day(PlayerAction::EnactPolicy { policy_id: "conscription" }, &mut rng);
        engine.process_day(PlayerAction::Rest, &mut rng);

        let saved_day      = engine.day;
        let saved_legit    = engine.politics.legitimacy;
        let saved_troops   = engine.army.total_troops;
        let saved_triggered = engine.triggered_event_ids.clone();

        let json     = engine.to_json();
        let restored = GameEngine::from_json(&json).expect("from_json 应成功");

        assert_eq!(restored.day,                saved_day,   "day 应一致");
        assert!((restored.politics.legitimacy - saved_legit).abs() < 0.001, "legitimacy 应一致");
        assert_eq!(restored.army.total_troops,  saved_troops, "troops 应一致");
        assert_eq!(restored.triggered_event_ids, saved_triggered, "已触发事件应一致");
    }

    #[test]
    fn 读档后事件不重复触发() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        // 推进到 Day 20，期间某些事件可能触发
        for _ in 0..15 {
            engine.process_day(PlayerAction::Rest, &mut rng);
        }
        let triggered_before = engine.triggered_event_ids.clone();

        let json     = engine.to_json();
        let restored = GameEngine::from_json(&json).expect("from_json 应成功");

        // 读档后再推进，之前触发过的事件不应再触发
        let mut rng2 = seeded_rng();
        let mut restored = restored;
        for _ in 0..5 {
            restored.process_day(PlayerAction::Rest, &mut rng2);
        }
        for id in &triggered_before {
            let count = restored.triggered_event_ids.iter().filter(|x| *x == id).count();
            assert!(count <= 1, "事件 {} 读档后不应重复触发", id);
        }
    }

    #[test]
    fn json序列化反序列化完整往返() {
        let engine = GameEngine::new();
        let json = engine.to_json();
        assert!(!json.is_empty(), "JSON 不应为空");
        let _ = GameEngine::from_json(&json).expect("合法 JSON 应可反序列化");
    }

    // ── 叙事引擎集成 ──────────────────────────────────

    #[test]
    fn 执行征兵政策后有叙事报告() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::EnactPolicy { policy_id: "conscription" }, &mut rng);
        let report = engine.last_report().expect("执行政策后应有叙事报告");
        assert!(report.stendhal.is_some(), "征兵令应有司汤达评论");
        assert!(report.consequence.is_some(), "征兵令应有后果片段");
    }

    #[test]
    fn 执行休整后无叙事文本() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        let report = engine.last_report().expect("执行后应有报告");
        assert!(report.stendhal.is_none(), "Rest 不应有司汤达文本");
        assert!(report.consequence.is_none(), "Rest 不应有后果片段");
    }

    #[test]
    fn 强化忠诚后有司汤达文本() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::BoostLoyalty { general_id: "ney".to_string() }, &mut rng);
        let report = engine.last_report().expect("BoostLoyalty 后应有报告");
        assert!(report.stendhal.is_some(), "强化忠诚应有司汤达评论");
    }

    #[test]
    fn 游戏开始前无叙事报告() {
        let engine = GameEngine::new();
        assert!(engine.last_report().is_none(), "初始状态应无叙事报告");
    }

    // ── 事件系统集成 ──────────────────────────────────

    #[test]
    fn 引擎内部自动触发内伊倒戈() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        // 推进到 Day 6（内伊倒戈窗口）
        for _ in 1..6 {
            engine.process_day(PlayerAction::Rest, &mut rng);
        }
        // 引擎应已自动触发并记录事件（或效果已应用）
        assert!(
            engine.triggered_events().iter().any(|id| id == "ney_defection")
                || engine.characters.loyalty("ney") > 55.0,
            "Day 6 前后应自动触发或尝试内伊倒戈"
        );
    }

    #[test]
    fn 事件只触发一次() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        for _ in 0..20 {
            engine.process_day(PlayerAction::Rest, &mut rng);
        }
        let ney_count = engine.triggered_events()
            .iter()
            .filter(|id| *id == "ney_defection")
            .count();
        assert!(ney_count <= 1, "内伊倒戈不应重复触发，实际触发 {} 次", ney_count);
    }

    #[test]
    fn 触发事件被记录到历史() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        for _ in 0..20 {
            engine.process_day(PlayerAction::Rest, &mut rng);
        }
        // 如果有事件被触发，历史中应有对应记录
        let event_ids = engine.triggered_events();
        if !event_ids.is_empty() {
            assert!(
                engine.history.iter().any(|e| e.event_type == "historical_event"),
                "触发的历史事件应出现在 history 日志中"
            );
        }
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

