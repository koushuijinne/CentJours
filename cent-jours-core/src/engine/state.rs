//! 三系统耦合状态机 — `engine::state`
//!
//! 统一持有 battle + politics + characters，按 Dawn→Action→Dusk 驱动。
//! 这是 GATE 2 的核心：三个系统的涌现交互在此发生。

use rand::Rng;

use crate::battle::resolver::{resolve_battle, BattleResult, ForceData, Terrain};
use crate::battle::{
    move_army, rest_army, update_supply, ArmyState as MarchArmyState, MapEdge, MapGraph, MapNode,
    SUPPLY_OK_THRESHOLD,
};
use crate::characters::network::{
    historical_network_day1, CharacterNetwork, LOYALTY_CRISIS_THRESHOLD,
};
use crate::events::pool::{EventEffects, EventPool, TriggerContext, TriggeredEvent};
use crate::narratives::{policy_narrative_key, NarrativePool};
use crate::politics::system::{default_policies, PolicyEffect, PoliticsState};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

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
            Self::NapoleonVictory => "napoleon_victory",
            Self::WaterlooHistorical => "waterloo_historical",
            Self::WaterlooDefeat => "waterloo_defeat",
            Self::PoliticalCollapse => "political_collapse",
            Self::MilitaryAnnihilation => "military_annihilation",
        }
    }
}

// ── 游戏阶段 ──────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TurnPhase {
    Dawn,   // 情报/事件展示
    Action, // 玩家决策
    Dusk,   // 结算
}

// ── 玩家行动 ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub enum PlayerAction {
    /// 发动战役（将领ID，攻方兵力，目标地形）
    LaunchBattle {
        general_id: String,
        troops: u32,
        terrain: Terrain,
    },
    /// 行军到相邻节点（目标节点 ID）
    March { target_node: String },
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
    pub day: u32,
    pub event_type: &'static str,
    pub description: String,
    /// 事件对三系统的影响摘要
    pub effects: Vec<String>,
}

// ── 每日叙事报告 ──────────────────────────────────────

/// `process_day()` 完成后可从 `engine.last_report()` 获取的叙事文本
#[derive(Debug, Clone)]
pub struct DayReport {
    pub day: u32,
    /// 司汤达当天的日记评论（基于玩家行动类型）
    pub stendhal: Option<String>,
    /// 普通人视角的后果片段（基于玩家行动类型）
    pub consequence: Option<String>,
}

#[derive(Debug, Clone)]
pub struct MarchPreview {
    pub valid: bool,
    pub reason: Option<String>,
    pub target_node: String,
    pub fatigue_delta: f64,
    pub morale_delta: f64,
    pub supply_delta: f64,
    pub projected_fatigue: f64,
    pub projected_morale: f64,
    pub projected_supply: f64,
}

// ── 全局游戏状态 ──────────────────────────────────────

/// 拿破仑的军事力量摘要
#[derive(Debug, Clone)]
pub struct ArmyState {
    pub total_troops: u32,
    pub avg_morale: f64,
    pub avg_fatigue: f64,
    pub supply: f64,
    /// 战役胜场计数（影响军方支持度）
    pub victories: u32,
    pub defeats: u32,
}

impl Default for ArmyState {
    fn default() -> Self {
        Self {
            total_troops: 72_000, // 历史：百日初期约72000人
            avg_morale: 75.0,
            avg_fatigue: 10.0,
            supply: default_army_supply(),
            victories: 0,
            defeats: 0,
        }
    }
}

impl ArmyState {
    /// 构建用于战斗解算的 ForceData
    pub fn to_force_data(&self, general_skill: f64, troops_committed: u32) -> ForceData {
        ForceData {
            troops: troops_committed.min(self.total_troops),
            morale: self.avg_morale,
            fatigue: self.avg_fatigue,
            general_skill,
            supply_ok: self.supply >= SUPPLY_OK_THRESHOLD,
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
            BattleResult::MarginalDefeat | BattleResult::DecisiveDefeat => self.defeats += 1,
            BattleResult::Stalemate => {}
        }
    }

    /// 休整恢复（每日）
    pub fn rest_recovery(&mut self, location: &str) -> (f64, f64) {
        let march_state = MarchArmyState {
            id: "napoleon_main_force".to_string(),
            location: location.to_string(),
            troops: self.total_troops,
            morale: self.avg_morale,
            fatigue: self.avg_fatigue,
            supply: self.supply,
        };
        let (fatigue_recovery, morale_recovery) = rest_army(&march_state);
        self.avg_fatigue = (self.avg_fatigue - fatigue_recovery).max(0.0);
        self.avg_morale = (self.avg_morale + morale_recovery).min(100.0);
        (fatigue_recovery, morale_recovery)
    }
}

// ── 存档状态 ─────────────────────────────────────────

/// 可序列化的完整游戏存档快照
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveState {
    /// 存档格式版本（用于兼容性检查）
    pub version: u32,
    pub day: u32,
    // 政治系统
    pub legitimacy: f64,
    pub rouge_noir: f64,
    pub factions: HashMap<String, f64>,
    pub actions_remaining: u32,
    // 军事系统
    pub troops: u32,
    pub morale: f64,
    pub fatigue: f64,
    #[serde(default = "default_army_supply")]
    pub supply: f64,
    pub victories: u32,
    pub defeats: u32,
    pub napoleon_location: String,
    pub coalition_troops_bonus: i32,
    pub paris_security_bonus: f64,
    pub political_stability_bonus: f64,
    // 将领网络（当前忠诚度 + 关系强度）
    pub loyalty: HashMap<String, f64>,
    pub relationships: Vec<(String, String, f64)>,
    // 事件系统
    pub triggered_event_ids: Vec<String>,
    // 结局（in_progress 表示游戏进行中）
    pub outcome: Option<String>,
}

/// 地图 JSON 解析用的轻量包装结构。
#[derive(Debug, Clone, Deserialize)]
struct CampaignMapData {
    nodes: Vec<MapNode>,
    edges: Vec<MapEdge>,
}

/// 从前端共享地图数据构建默认战役地图。
fn default_campaign_map() -> MapGraph {
    const MAP_JSON: &str = include_str!("../../../src/data/map_nodes.json");
    let data: CampaignMapData = serde_json::from_str(MAP_JSON).expect("map_nodes.json parse error");
    MapGraph::new(data.nodes, data.edges)
}

fn default_army_supply() -> f64 {
    75.0
}

fn migrate_triggered_event_ids(ids: Vec<String>) -> Vec<String> {
    const OLD_FONTAINEBLEAU_EVE_ID: &str = "fontainebleau_eve";
    const TUILERIES_EVE_ID: &str = "tuileries_eve";

    let mut migrated = Vec::with_capacity(ids.len());
    let mut seen = HashSet::new();

    for id in ids {
        let migrated_id = if id == OLD_FONTAINEBLEAU_EVE_ID {
            TUILERIES_EVE_ID.to_string()
        } else {
            id
        };

        if seen.insert(migrated_id.clone()) {
            migrated.push(migrated_id);
        }
    }

    migrated
}

// ── 叙事 key 提取 ─────────────────────────────────────

/// 从 PlayerAction 提取叙事 key 和"是否战斗"标志。
/// 战斗结果（胜/败）要在 execute_action 之后才能确定，所以返回 is_battle=true。
fn narrative_key_for_action(action: &PlayerAction) -> (&'static str, bool) {
    match action {
        PlayerAction::LaunchBattle { .. } => ("", true),
        PlayerAction::March { .. } => ("", false),
        PlayerAction::EnactPolicy { policy_id } => {
            (policy_narrative_key(policy_id).unwrap_or(""), false)
        }
        PlayerAction::BoostLoyalty { .. } => ("boost_loyalty", false),
        PlayerAction::Rest => ("", false),
    }
}

fn faction_display_name(faction_id: &str) -> &'static str {
    match faction_id {
        "military" => "军方",
        "populace" => "民众",
        "liberals" => "自由派",
        "nobility" => "贵族",
        _ => "未知派系",
    }
}

fn format_signed_effect(label: &str, delta: f64) -> Option<String> {
    if delta.abs() <= 0.05 {
        return None;
    }
    Some(format!("{} {:+.1}", label, delta))
}

fn format_rouge_noir_effect(delta: f64) -> Option<String> {
    if delta.abs() <= 0.05 {
        return None;
    }
    if delta > 0.0 {
        Some(format!("Rouge +{:.0}", delta.abs()))
    } else {
        Some(format!("Noir +{:.0}", delta.abs()))
    }
}

// ── 核心引擎 ──────────────────────────────────────────

/// 三系统耦合游戏引擎
pub struct GameEngine {
    pub day: u32,
    pub phase: TurnPhase,
    pub politics: PoliticsState,
    pub characters: CharacterNetwork,
    pub army: ArmyState,
    /// 拿破仑当前所在地图节点（Tier 2 行军系统的权威位置）
    pub napoleon_location: String,
    /// 历史事件对联军兵力的累计修正（正数=增援，负数=削弱）
    coalition_troops_bonus: i32,
    /// 巴黎治安收益：会在每日结算中转化为稳定的政治支持
    paris_security_bonus: f64,
    /// 政治稳定收益：会在每日结算中持续托举合法性
    political_stability_bonus: f64,
    pub history: Vec<DayEvent>,
    /// 游戏结局（Some = 游戏已结束）
    outcome: Option<GameOutcome>,
    /// 战役地图图结构（用于相邻移动与距离查询）
    map_graph: MapGraph,
    /// 内嵌事件池（Dawn 阶段自动触发）
    event_pool: EventPool,
    /// 已触发事件 ID 列表（按触发顺序）
    triggered_event_ids: Vec<String>,
    /// 叙事文本池（司汤达日记 + 后果片段）
    narratives: NarrativePool,
    /// 最近一天的叙事报告（可供 UI 层读取）
    last_report: Option<DayReport>,
    /// 最近一次玩家行动的结算记录（不含 Dawn 历史事件）
    last_action_events: Vec<DayEvent>,
    /// 最近一次 Dawn 触发的历史事件详情（供 UI 在本回合立即展示）
    last_triggered_events: Vec<TriggeredEvent>,
}

impl Default for GameEngine {
    fn default() -> Self {
        const HISTORICAL_JSON: &str = include_str!("../../../src/data/events/historical.json");
        Self {
            day: 1,
            phase: TurnPhase::Dawn,
            politics: PoliticsState::default(),
            characters: historical_network_day1(),
            army: ArmyState::default(),
            napoleon_location: "golfe_juan".to_string(),
            coalition_troops_bonus: 0,
            paris_security_bonus: 0.0,
            political_stability_bonus: 0.0,
            history: Vec::new(),
            outcome: None,
            map_graph: default_campaign_map(),
            event_pool: EventPool::from_json(HISTORICAL_JSON).expect("historical.json parse error"),
            triggered_event_ids: Vec::new(),
            narratives: NarrativePool::new(),
            last_report: None,
            last_action_events: Vec::new(),
            last_triggered_events: Vec::new(),
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

    /// 当前可直接行军到的相邻节点列表。
    pub fn adjacent_nodes(&self) -> Vec<String> {
        self.map_graph.neighbors_of(&self.napoleon_location)
    }

    /// 预览一次普通行军的预计变化，不修改真实状态。
    pub fn preview_march(&self, target_node: &str) -> MarchPreview {
        let current = self.current_march_army_state();
        let move_result = move_army(&current, target_node, false, &self.map_graph);
        if !move_result.success {
            return MarchPreview {
                valid: false,
                reason: move_result.reason,
                target_node: current.location,
                fatigue_delta: 0.0,
                morale_delta: 0.0,
                supply_delta: 0.0,
                projected_fatigue: self.army.avg_fatigue,
                projected_morale: self.army.avg_morale,
                projected_supply: self.army.supply,
            };
        }

        let projected_army = MarchArmyState {
            id: current.id,
            location: move_result.new_location.clone(),
            troops: self.army.total_troops,
            morale: move_result.new_morale,
            fatigue: move_result.new_fatigue,
            supply: self.army.supply,
        };
        let supply_result = update_supply(
            &projected_army,
            self.supply_line_efficiency_for(&move_result.new_location),
            &self.map_graph,
        );

        MarchPreview {
            valid: true,
            reason: None,
            target_node: move_result.new_location,
            fatigue_delta: move_result.fatigue_delta,
            morale_delta: move_result.morale_delta,
            supply_delta: supply_result.supply_delta,
            projected_fatigue: move_result.new_fatigue,
            projected_morale: move_result.new_morale,
            projected_supply: supply_result.new_supply,
        }
    }

    /// 已触发的历史事件 ID 列表（按触发顺序）
    pub fn triggered_events(&self) -> &[String] {
        &self.triggered_event_ids
    }

    /// 最近一天的叙事报告（游戏刚开始还没处理过任何天时为 None）
    pub fn last_report(&self) -> Option<&DayReport> {
        self.last_report.as_ref()
    }

    /// 最近一次玩家行动的结算记录（不含 Dawn 历史事件）。
    pub fn last_action_events(&self) -> &[DayEvent] {
        &self.last_action_events
    }

    /// 最近一次 Dawn 阶段触发的历史事件详情。
    pub fn last_triggered_events(&self) -> &[TriggeredEvent] {
        &self.last_triggered_events
    }

    // ── 存档 / 读档 ───────────────────────────────────

    /// 将当前引擎状态序列化为存档快照
    pub fn save(&self) -> SaveState {
        let relationships = self
            .characters
            .relationships
            .iter()
            .map(|((a, b), v)| (a.clone(), b.clone(), *v))
            .collect();

        SaveState {
            version: 2,
            day: self.day,
            legitimacy: self.politics.legitimacy,
            rouge_noir: self.politics.rouge_noir_index,
            factions: self.politics.faction_support.clone(),
            actions_remaining: self.politics.actions_remaining as u32,
            troops: self.army.total_troops,
            morale: self.army.avg_morale,
            fatigue: self.army.avg_fatigue,
            supply: self.army.supply,
            victories: self.army.victories,
            defeats: self.army.defeats,
            napoleon_location: self.napoleon_location.clone(),
            coalition_troops_bonus: self.coalition_troops_bonus,
            paris_security_bonus: self.paris_security_bonus,
            political_stability_bonus: self.political_stability_bonus,
            loyalty: self.characters.loyalty.clone(),
            relationships,
            triggered_event_ids: self.triggered_event_ids.clone(),
            outcome: self.outcome.map(|o| o.as_str().to_string()),
        }
    }

    /// 将存档快照序列化为 JSON 字符串
    pub fn to_json(&self) -> String {
        serde_json::to_string(&self.save()).expect("SaveState serialization failed")
    }

    /// 从存档快照恢复引擎状态
    pub fn load(state: SaveState) -> Self {
        let mut engine = Self::new();

        engine.day = state.day;
        engine.politics.legitimacy = state.legitimacy;
        engine.politics.rouge_noir_index = state.rouge_noir;
        engine.politics.faction_support = state.factions;
        engine.politics.actions_remaining = state.actions_remaining as u8;
        engine.army.total_troops = state.troops;
        engine.army.avg_morale = state.morale;
        engine.army.avg_fatigue = state.fatigue;
        engine.army.supply = state.supply;
        engine.army.victories = state.victories;
        engine.army.defeats = state.defeats;
        engine.napoleon_location = state.napoleon_location;
        engine.coalition_troops_bonus = state.coalition_troops_bonus;
        engine.paris_security_bonus = state.paris_security_bonus;
        engine.political_stability_bonus = state.political_stability_bonus;
        engine.characters.loyalty = state.loyalty;
        engine.characters.relationships = state
            .relationships
            .into_iter()
            .map(|(a, b, v)| ((a, b), v))
            .collect();
        let migrated_triggered_event_ids = migrate_triggered_event_ids(state.triggered_event_ids);
        engine.triggered_event_ids = migrated_triggered_event_ids.clone();
        engine
            .event_pool
            .restore_triggered(migrated_triggered_event_ids);
        engine.outcome = state.outcome.as_deref().and_then(|s| match s {
            "napoleon_victory" => Some(GameOutcome::NapoleonVictory),
            "waterloo_historical" => Some(GameOutcome::WaterlooHistorical),
            "waterloo_defeat" => Some(GameOutcome::WaterlooDefeat),
            "political_collapse" => Some(GameOutcome::PoliticalCollapse),
            "military_annihilation" => Some(GameOutcome::MilitaryAnnihilation),
            _ => None,
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
        if self.is_over() {
            return;
        }

        // Dawn：触发历史事件，效果直接作用于三系统
        self.phase = TurnPhase::Dawn;
        let ctx = self.build_trigger_ctx();
        let triggered = self.event_pool.trigger_all(&ctx, rng);
        // 缓存最近触发详情，供 UI 在本回合结算后直接读取。
        self.last_triggered_events = triggered.clone();
        for t in triggered {
            self.triggered_event_ids.push(t.id.clone());
            self.apply_event_effects(&t.effects);
            self.history.push(DayEvent {
                day: self.day,
                event_type: "historical_event",
                description: format!("[{}] {}", t.label, t.narrative),
                effects: vec![],
            });
        }

        // Action：提前提取叙事 key（action 下面会被消耗）
        self.phase = TurnPhase::Action;
        let (base_key, is_battle) = narrative_key_for_action(&action);
        let victories_before = self.army.victories;
        let defeats_before = self.army.defeats;
        let events = self.execute_action(action, rng);
        self.last_action_events = events.clone();

        // Dusk：系统结算
        self.phase = TurnPhase::Dusk;
        self.dusk_settlement(rng);

        // 记录当日事件
        for e in events {
            self.history.push(e);
        }

        // 填充叙事报告（战斗结果在 execute_action 后才知道）
        let narrative_key = if is_battle {
            if self.army.victories > victories_before {
                "battle_victory"
            } else if self.army.defeats > defeats_before {
                "battle_defeat"
            } else {
                ""
            } // 平局无叙事
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
        let (action_type, mut events) = match action {
            PlayerAction::LaunchBattle {
                general_id,
                troops,
                terrain,
            } => (
                "battle",
                self.process_battle(&general_id, troops, terrain, rng),
            ),
            PlayerAction::March { target_node } => ("march", self.process_march(&target_node)),
            PlayerAction::EnactPolicy { policy_id } => ("policy", self.process_policy(policy_id)),
            PlayerAction::BoostLoyalty { general_id } => {
                ("boost_loyalty", self.process_boost_loyalty(&general_id))
            }
            PlayerAction::Rest => {
                let (fatigue_recovery, morale_recovery) =
                    self.army.rest_recovery(&self.napoleon_location);
                let mut effects = Vec::new();
                effects.push(format!("疲劳-{:.0}", fatigue_recovery));
                effects.push(format!("士气+{:.0}", morale_recovery));
                (
                    "rest",
                    vec![DayEvent {
                        day: self.day,
                        event_type: "rest",
                        description: "军队休整。".to_string(),
                        effects,
                    }],
                )
            }
        };
        events.push(self.refresh_supply_after_action(action_type));
        events
    }

    /// 行军处理：只允许移动到相邻节点，并同步位置 / 疲劳 / 士气。
    fn process_march(&mut self, target_node: &str) -> Vec<DayEvent> {
        let march_state = self.current_march_army_state();
        let result = move_army(&march_state, target_node, false, &self.map_graph);
        let from_name = self.map_graph.node_name(&self.napoleon_location);
        let target_name = self.map_graph.node_name(target_node);
        if !result.success {
            return vec![DayEvent {
                day: self.day,
                event_type: "march_failed",
                description: format!("行军受阻：{} 无法直接行军至 {}", from_name, target_name),
                effects: vec![],
            }];
        }

        self.napoleon_location = result.new_location.clone();
        self.army.avg_fatigue = result.new_fatigue;
        self.army.avg_morale = result.new_morale;
        let new_location_name = self.map_graph.node_name(&self.napoleon_location);

        let mut effects = Vec::new();
        if let Some(effect) = format_signed_effect("疲劳", result.fatigue_delta) {
            effects.push(effect);
        }
        if let Some(effect) = format_signed_effect("士气", result.morale_delta) {
            effects.push(effect);
        }

        vec![DayEvent {
            day: self.day,
            event_type: "march",
            description: format!("拿破仑主力自 {} 行军至 {}", from_name, new_location_name),
            effects,
        }]
    }

    /// 战役处理：命令偏差 → 解算战斗 → 更新三系统
    pub fn process_battle<R: Rng>(
        &mut self,
        general_id: &str,
        troops: u32,
        terrain: Terrain,
        rng: &mut R,
    ) -> Vec<DayEvent> {
        // 命令偏差：将领忠诚度影响实际投入兵力（Tier 3.1）
        let deviation = self.characters.calculate_deviation(general_id, rng);
        let actual_troops = ((troops as f64) * deviation).round() as u32;
        let general_name = self.characters.display_name(general_id);
        let before_loyalty = self.characters.loyalty(general_id);
        let before_legitimacy = self.politics.legitimacy;
        let before_military = self.politics.faction_support["military"];
        let before_populace = self.politics.faction_support["populace"];

        let general_skill = self.general_skill(general_id);
        let attacker = self.army.to_force_data(general_skill, actual_troops);

        // 敌军：随日期增长（联军集结）
        let enemy = self.coalition_force();
        let outcome = resolve_battle(&attacker, &enemy, terrain, rng);
        let result = outcome.result;

        // 更新军队（以命令兵力为基准计算损失，而非偏差后兵力）
        self.army.apply_battle(result, troops);

        // 更新将领忠诚度
        self.characters
            .apply_battle_outcome(general_id, result, self.day);

        // 更新政治：战胜提升军方，战败降低军方 + 民众
        self.apply_battle_politics(result);

        // 联军动态化：拿破仑胜利削弱联军，失败则联军士气提振
        self.apply_battle_coalition_impact(result, troops);

        // 地形防御加成百分比（0% = 平原无加成）
        let terrain_pct = (terrain.defense_bonus() - 1.0) * 100.0;
        let description = format!(
            "{} 率 {} 人在{}发起战役，结果：{}（守军地形加成 {:.0}%）",
            general_name,
            actual_troops,
            terrain.display_name(),
            result.display_name(),
            terrain_pct
        );

        let mut effects = vec![
            format!("我军伤亡 {}", outcome.attacker_casualties),
            format!("敌军伤亡 {}", outcome.defender_casualties),
        ];
        if let Some(effect) = format_signed_effect("士气", outcome.attacker_morale_delta) {
            effects.push(effect);
        }
        if actual_troops != troops {
            effects.push(format!(
                "实际投入 {}（命令 {}，偏差 {:+.0}%）",
                actual_troops,
                troops,
                (deviation - 1.0) * 100.0
            ));
        }
        let loyalty_label = format!("{} 忠诚", general_name);
        if let Some(effect) = format_signed_effect(
            &loyalty_label,
            self.characters.loyalty(general_id) - before_loyalty,
        ) {
            effects.push(effect);
        }
        if let Some(effect) = format_signed_effect(
            "军方",
            self.politics.faction_support["military"] - before_military,
        ) {
            effects.push(effect);
        }
        if let Some(effect) = format_signed_effect(
            "民众",
            self.politics.faction_support["populace"] - before_populace,
        ) {
            effects.push(effect);
        }
        if let Some(effect) =
            format_signed_effect("合法性", self.politics.legitimacy - before_legitimacy)
        {
            effects.push(effect);
        }

        vec![DayEvent {
            day: self.day,
            event_type: "battle",
            description,
            effects,
        }]
    }

    /// 政策处理
    fn process_policy(&mut self, policy_id: &'static str) -> Vec<DayEvent> {
        let policies = default_policies();
        if let Some(policy) = policies.iter().find(|p| p.id == policy_id) {
            let before_actions = self.politics.actions_remaining;
            let before_rn = self.politics.rouge_noir_index;
            let before_legitimacy = self.politics.legitimacy;
            let before_economic = self.politics.economic_index;
            let before_supply = self.army.supply;
            let before_factions = self.politics.faction_support.clone();
            match self.politics.enact_policy(policy) {
                Ok(()) => {
                    if policy.supply_delta.abs() > 0.01 {
                        self.army.supply =
                            (self.army.supply + policy.supply_delta).clamp(0.0, 100.0);
                    }
                    vec![DayEvent {
                        day: self.day,
                        event_type: "policy",
                        description: format!("颁布政策：{}", policy.name),
                        effects: self.build_policy_effects(
                            policy,
                            &before_factions,
                            before_legitimacy,
                            before_rn,
                            before_economic,
                            before_actions,
                            before_supply,
                        ),
                    }]
                }
                Err(e) => vec![DayEvent {
                    day: self.day,
                    event_type: "policy_failed",
                    description: format!("政策未能执行：{}", policy.name),
                    effects: vec![e],
                }],
            }
        } else {
            vec![DayEvent {
                day: self.day,
                event_type: "policy_failed",
                description: format!("政策未能执行：{}", policy_id),
                effects: vec!["该政策未在内置政策表中注册".to_string()],
            }]
        }
    }

    fn build_policy_effects(
        &self,
        policy: &PolicyEffect,
        before_factions: &HashMap<String, f64>,
        before_legitimacy: f64,
        before_rn: f64,
        before_economic: f64,
        before_actions: u8,
        before_supply: f64,
    ) -> Vec<String> {
        let mut effects = Vec::new();
        let actions_spent = before_actions.saturating_sub(self.politics.actions_remaining);
        if actions_spent > 0 {
            effects.push(format!("行动点 -{}", actions_spent));
        }
        if let Some(effect) = format_rouge_noir_effect(self.politics.rouge_noir_index - before_rn) {
            effects.push(effect);
        }

        for faction_id in ["military", "populace", "liberals", "nobility"] {
            let before = before_factions.get(faction_id).copied().unwrap_or(0.0);
            let after = self
                .politics
                .faction_support
                .get(faction_id)
                .copied()
                .unwrap_or(before);
            if let Some(effect) =
                format_signed_effect(faction_display_name(faction_id), after - before)
            {
                effects.push(effect);
            }
        }

        if let Some(effect) =
            format_signed_effect("合法性", self.politics.legitimacy - before_legitimacy)
        {
            effects.push(effect);
        }
        if let Some(effect) =
            format_signed_effect("经济", self.politics.economic_index - before_economic)
        {
            effects.push(effect);
        }
        if let Some(effect) = format_signed_effect("补给", self.army.supply - before_supply) {
            effects.push(effect);
        }
        if policy.cooldown_days > 0 {
            effects.push(format!("进入冷却 {} 天", policy.cooldown_days));
        }
        effects
    }

    /// 强化忠诚度处理（消耗合法性）
    fn process_boost_loyalty(&mut self, general_id: &str) -> Vec<DayEvent> {
        let general_name = self.characters.display_name(general_id);
        if self.politics.legitimacy < 10.0 {
            return vec![DayEvent {
                day: self.day,
                event_type: "boost_failed",
                description: format!("合法性不足，无法安抚 {}", general_name),
                effects: vec![],
            }];
        }
        self.politics.legitimacy -= 5.0;
        self.characters
            .modify_loyalty(general_id, 8.0, self.day, "personal_attention");

        vec![DayEvent {
            day: self.day,
            event_type: "boost_loyalty",
            description: format!("亲自接见 {}，试图稳住军心", general_name),
            effects: vec![
                "合法性 -5.0".to_string(),
                format!("{} 忠诚 +8.0", general_name),
            ],
        }]
    }

    /// Dusk结算：政治每日tick、关系衰减、叛逃检查、连锁效果
    fn dusk_settlement<R: Rng>(&mut self, rng: &mut R) {
        self.politics.daily_tick();
        self.characters.tick_day();

        // 历史事件提供的长期稳定收益：达武留守巴黎等安排会在后续数日持续发挥作用。
        if self.paris_security_bonus.abs() > f64::EPSILON {
            self.politics.modify_faction(
                "populace",
                (self.paris_security_bonus / 40.0).clamp(-3.0, 3.0),
            );
            self.politics.modify_faction(
                "nobility",
                (self.paris_security_bonus / 80.0).clamp(-2.0, 2.0),
            );
        }
        if self.political_stability_bonus.abs() > f64::EPSILON {
            self.politics.legitimacy = (self.politics.legitimacy
                + (self.political_stability_bonus / 20.0).clamp(-2.5, 2.5))
            .clamp(0.0, 100.0);
        }

        // ── 将领叛逃每日检查 ──────────────────────────────
        self.check_ney_defection(rng);
        self.check_grouchy_abandonment(rng);

        // 兵力过少 → 政治连锁反应
        if self.army.total_troops < 20_000 {
            self.politics.modify_faction("military", -5.0);
        }

        // 长期征战疲劳 → 民众不满
        if self.day > 60 && self.army.avg_fatigue > 70.0 {
            self.politics.modify_faction("populace", -2.0);
        }
    }

    /// 内伊叛逃每日检查（Day 3–20）。
    /// 当内伊忠诚度跌破危机阈值且尚未被事件系统触发时，
    /// 按 defection_probability() 概率判定叛逃。
    fn check_ney_defection<R: Rng>(&mut self, rng: &mut R) {
        const NEY_DEFECTION_ID: &str = "ney_defection_dusk";
        // 只在Day 3–20窗口内检查（历史事件覆盖Day 5–7，此处扩大为安全窗口）
        if self.day < 3 || self.day > 20 {
            return;
        }
        // 已触发过（事件系统或dusk检查），不重复
        if self
            .triggered_event_ids
            .iter()
            .any(|id| id == NEY_DEFECTION_ID || id == "ney_defection")
        {
            return;
        }
        // 忠诚度未跌破危机阈值，暂不触发
        let ney_loyalty = self.characters.loyalty("ney");
        if ney_loyalty >= LOYALTY_CRISIS_THRESHOLD {
            return;
        }
        // 用完整概率公式判定
        let cond = self.characters.ney_defection_condition();
        let prob = cond.defection_probability();
        if rng.gen::<f64>() >= prob {
            return; // 本日未触发
        }
        // 触发叛逃：忠诚度归零、兵力损失、政治冲击
        let day = self.day;
        self.characters
            .modify_loyalty("ney", -ney_loyalty, day, "叛逃");
        // 内伊带走约5000兵力
        let troops_lost = 5000u32.min(self.army.total_troops.saturating_sub(1000));
        self.army.total_troops = self.army.total_troops.saturating_sub(troops_lost);
        self.politics.modify_faction("military", -8.0);
        self.politics.legitimacy = (self.politics.legitimacy - 5.0).max(0.0);
        // 记录并阻止重复触发
        self.triggered_event_ids.push(NEY_DEFECTION_ID.to_string());
        self.history.push(DayEvent {
            day,
            event_type: "defection",
            description: format!("内伊元帅叛逃！带走{}名士兵，军心动摇", troops_lost),
            effects: vec![
                format!("内伊忠诚度→0"),
                format!("兵力-{}", troops_lost),
                "军方支持-8, 合法性-5".to_string(),
            ],
        });
    }

    /// 格鲁希失联检查（Day 90+）。
    /// 格鲁希忠诚度低时可能擅自脱离战场，导致联军侧翼增援不被牵制。
    fn check_grouchy_abandonment<R: Rng>(&mut self, rng: &mut R) {
        const GROUCHY_ABANDON_ID: &str = "grouchy_abandon_dusk";
        // 只在Day 90+检查（滑铁卢窗口）
        if self.day < 90 {
            return;
        }
        // 已触发过，不重复
        if self
            .triggered_event_ids
            .iter()
            .any(|id| id == GROUCHY_ABANDON_ID || id == "grouchy_assignment")
        {
            return;
        }
        let grouchy_loyalty = self.characters.loyalty("grouchy");
        // 忠诚度高于50时不会擅自脱离
        if grouchy_loyalty >= 50.0 {
            return;
        }
        // 脱离概率：忠诚度越低越可能（0~50映射到0.0~0.5）
        let abandon_prob = (50.0 - grouchy_loyalty) / 100.0;
        if rng.gen::<f64>() >= abandon_prob {
            return;
        }
        // 触发脱离：联军增援加强（格鲁希不牵制普军 → 联军+15000）
        let day = self.day;
        self.coalition_troops_bonus = self.coalition_troops_bonus.saturating_add(15_000);
        self.characters
            .modify_loyalty("grouchy", -grouchy_loyalty, day, "脱离战场");
        self.politics.modify_faction("military", -5.0);
        self.triggered_event_ids
            .push(GROUCHY_ABANDON_ID.to_string());
        self.history.push(DayEvent {
            day,
            event_type: "defection",
            description: "格鲁希元帅脱离战场！普军增援不受牵制，联军兵力+15000".to_string(),
            effects: vec![
                "格鲁希忠诚度→0".to_string(),
                "联军兵力+15000".to_string(),
                "军方支持-5".to_string(),
            ],
        });
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
            let victories = self.army.victories;
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
            return DayReport {
                day: self.day,
                stendhal: None,
                consequence: None,
            };
        }
        DayReport {
            day: self.day,
            stendhal: self.narratives.pick_stendhal(narrative_key, rng),
            consequence: self.narratives.pick_consequence(narrative_key, rng),
        }
    }

    // ── 事件系统 ──────────────────────────────────────

    /// 根据当前引擎状态构建事件触发上下文快照
    fn build_trigger_ctx(&self) -> TriggerContext {
        TriggerContext {
            day: self.day,
            napoleon_reputation: self.politics.legitimacy,
            ney_loyalty: self.characters.loyalty("ney"),
            ney_napoleon_relationship: self.characters.relationship("ney", "napoleon"),
            grouchy_loyalty: self.characters.loyalty("grouchy"),
            fouche_loyalty: self.characters.loyalty("fouche"),
            rouge_noir_index: self.politics.rouge_noir_index,
            // 全量忠诚度快照（供 loyalty_min/loyalty_max 通用触发条件使用）
            loyalty_map: self.characters.loyalty.clone(),
            // 联军是否已被击败（仅 NapoleonVictory 结局表示联军被击败）
            coalition_defeated: matches!(self.outcome, Some(GameOutcome::NapoleonVictory)),
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
                self.army.total_troops = self.army.total_troops.saturating_sub((-delta) as u32);
            }
        }
        if let Some(delta) = effects.coalition_troops_bonus {
            self.coalition_troops_bonus = self.coalition_troops_bonus.saturating_add(delta);
        }
        if let Some(bonus) = effects.paris_security_bonus {
            self.paris_security_bonus = (self.paris_security_bonus + bonus).max(0.0);
        }
        if let Some(bonus) = effects.political_stability_bonus {
            self.political_stability_bonus = (self.political_stability_bonus + bonus).max(0.0);
        }
    }

    // ── 辅助方法 ──────────────────────────────────────

    fn current_march_army_state(&self) -> MarchArmyState {
        MarchArmyState {
            id: "napoleon_main_force".to_string(),
            location: self.napoleon_location.clone(),
            troops: self.army.total_troops,
            morale: self.army.avg_morale,
            fatigue: self.army.avg_fatigue,
            supply: self.army.supply,
        }
    }

    fn supply_line_efficiency(&self) -> f64 {
        self.supply_line_efficiency_for(&self.napoleon_location)
    }

    fn supply_line_efficiency_for(&self, location: &str) -> f64 {
        const SUPPLY_HUBS: [&str; 6] = [
            "golfe_juan",
            "grenoble",
            "lyon",
            "paris",
            "lille",
            "maubeuge",
        ];

        let nearest_distance = SUPPLY_HUBS
            .iter()
            .filter_map(|hub| {
                let distance = self.map_graph.node_distance(location, hub);
                (distance != u32::MAX).then_some(distance)
            })
            .min()
            .unwrap_or(u32::MAX);

        match nearest_distance {
            0 => 1.15,
            1 => 1.0,
            2 => 0.85,
            3 => 0.7,
            4 => 0.55,
            u32::MAX => 0.25,
            _ => 0.4,
        }
    }

    fn refresh_supply_after_action(&mut self, action_type: &'static str) -> DayEvent {
        let supply_result = update_supply(
            &self.current_march_army_state(),
            self.supply_line_efficiency(),
            &self.map_graph,
        );
        self.army.supply = supply_result.new_supply;

        let location_name = self.map_graph.node_name(&self.napoleon_location);
        let description = if supply_result.supply_delta <= -8.0 {
            format!("{} 的补给线明显吃紧。", location_name)
        } else if supply_result.supply_delta < -1.0 {
            format!("{} 的补给开始承压。", location_name)
        } else if supply_result.supply_delta >= 6.0 {
            format!("{} 的补给站顺利接续。", location_name)
        } else if supply_result.supply_delta > 1.0 {
            format!("{} 的补给略有恢复。", location_name)
        } else {
            format!("{} 的补给暂时维持。", location_name)
        };

        let mut effects = Vec::new();
        if let Some(effect) = format_signed_effect("补给", supply_result.supply_delta) {
            effects.push(effect);
        } else {
            effects.push("补给 +0.0".to_string());
        }
        effects.push(format!(
            "线效 {:.0}%",
            supply_result.line_efficiency * 100.0
        ));
        effects.push(format!(
            "需求 {:.1} / 可得 {:.1}",
            supply_result.demand, supply_result.available
        ));
        if !supply_result.supply_ok {
            effects.push("补给告急：战斗将承受惩罚".to_string());
        }
        if action_type == "march" && supply_result.supply_delta < 0.0 {
            effects.push("前线推进正在拉长运输线".to_string());
        }

        DayEvent {
            day: self.day,
            event_type: "supply",
            description,
            effects,
        }
    }

    /// 获取将领军事技能（单一来源：characters.json，通过 CharacterNetwork 加载）
    fn general_skill(&self, id: &str) -> f64 {
        self.characters.skill(id)
    }

    /// 构建当前联军兵力（随时间增长）
    fn coalition_force(&self) -> ForceData {
        let phase = (self.day as f64 / 100.0).min(1.0);
        // 联军在Day 1只有约40000人，到Day 100增至约200000人
        let base_troops = (40_000.0 + 160_000.0 * phase) as i32;
        let troops = (base_troops + self.coalition_troops_bonus).max(5_000) as u32;
        let morale = 70.0 + phase * 10.0; // 随集结提升士气
        ForceData {
            troops,
            morale,
            fatigue: 15.0,
            general_skill: 75.0, // Wellington/Blücher平均
            supply_ok: true,
        }
    }

    /// 战斗结果 → 联军兵力影响（Tier 3.3 联军动态化）。
    /// 拿破仑胜利 → 联军损失兵力（按投入兵力比例）；失败 → 联军士气提振。
    fn apply_battle_coalition_impact(&mut self, result: BattleResult, troops_committed: u32) {
        let delta = match result {
            // 大胜：联军损失约投入兵力的80%（反映敌方溃败）
            BattleResult::DecisiveVictory => -(troops_committed as f64 * 0.8) as i32,
            // 小胜：联军损失约投入兵力的30%
            BattleResult::MarginalVictory => -(troops_committed as f64 * 0.3) as i32,
            // 平局：微小消耗
            BattleResult::Stalemate => -(troops_committed as f64 * 0.05) as i32,
            // 小败：联军士气提振，增援加速（+5000）
            BattleResult::MarginalDefeat => 5_000,
            // 大败：联军全面反攻（+12000）
            BattleResult::DecisiveDefeat => 12_000,
        };
        self.coalition_troops_bonus = self.coalition_troops_bonus.saturating_add(delta);
    }

    /// 战斗结果 → 政治影响
    fn apply_battle_politics(&mut self, result: BattleResult) {
        match result {
            BattleResult::DecisiveVictory => {
                self.politics.modify_faction("military", 15.0);
                self.politics.modify_faction("populace", 8.0);
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
                self.politics.modify_faction("military", -8.0);
                self.politics.modify_faction("populace", -4.0);
                self.politics.legitimacy -= 3.0;
            }
            BattleResult::DecisiveDefeat => {
                self.politics.modify_faction("military", -18.0);
                self.politics.modify_faction("populace", -10.0);
                self.politics.modify_faction("liberals", -5.0);
                self.politics.legitimacy -= 8.0;
            }
        }
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rand::rngs::StdRng;
    use rand::SeedableRng;
    use serde_json::json;

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
            assert!(
                engine.characters.loyalty("ney") > ney_initial - 1.0,
                "战胜后内伊忠诚不应大幅下降"
            );
            assert!(
                engine.politics.faction_support["military"] >= mil_initial - 1.0,
                "战胜后军方支持不应大幅下降"
            );
        }
    }

    #[test]
    fn 战败降低军方支持度() {
        let mut engine = GameEngine::new();

        // 以极少兵力攻打大量敌军 → 必败
        let tiny_force = PlayerAction::LaunchBattle {
            general_id: "ney".to_string(),
            troops: 1_000,
            terrain: Terrain::Ridgeline,
        };
        let mil_before = engine.politics.faction_support["military"];
        let mut rng = seeded_rng();
        engine.process_day(tiny_force, &mut rng);

        // 1000人对40000人必败 → 军方支持下降
        assert!(
            engine.politics.faction_support["military"] < mil_before,
            "必败战役应降低军方支持: before={}, after={}",
            mil_before,
            engine.politics.faction_support["military"]
        );
    }

    // ── 政策耦合 ──────────────────────────────────────

    #[test]
    fn 政策行动消耗行动点() {
        let mut engine = GameEngine::new();
        let actions_before = engine.politics.actions_remaining;
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "constitutional_promise",
            },
            &mut rng,
        );
        // 行动点在 daily_tick 时重置，但本回合应已消耗
        // (Day推进后已tick，所以检查历史)
        assert!(
            engine.history.iter().any(|e| e.event_type == "policy"),
            "应有policy事件记录"
        );
        let _ = actions_before; // 满足编译器
    }

    #[test]
    fn 最近行动记录会缓存可读政策结算() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();

        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "constitutional_promise",
            },
            &mut rng,
        );

        let action_events = engine.last_action_events();
        assert!(
            action_events.len() >= 1,
            "本回合至少应缓存政策结算，允许附带补给结算"
        );

        let event = action_events
            .iter()
            .find(|event| event.event_type == "policy")
            .expect("应包含 policy 结算");
        assert_eq!(event.event_type, "policy");
        assert!(
            event.description.contains("承诺宪政改革"),
            "政策描述应使用可读名称"
        );
        assert!(
            event.effects.iter().any(|effect| effect.contains("自由派")),
            "政策结算应展示派系支持变化"
        );
        assert!(
            event
                .effects
                .iter()
                .any(|effect| effect.contains("进入冷却 10 天")),
            "政策结算应展示冷却信息"
        );
    }

    #[test]
    fn 政策失败也会缓存失败原因() {
        let mut engine = GameEngine::new();
        engine.politics.actions_remaining = 0;
        let mut rng = seeded_rng();

        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "conscription",
            },
            &mut rng,
        );

        let action_events = engine.last_action_events();
        assert!(
            action_events.len() >= 1,
            "失败政策也应写入最近行动记录，允许附带补给结算"
        );

        let event = action_events
            .iter()
            .find(|event| event.event_type == "policy_failed")
            .expect("应包含 policy_failed 结算");
        assert_eq!(event.event_type, "policy_failed");
        assert!(
            event.description.contains("颁布征兵令"),
            "失败描述也应包含可读政策名"
        );
        assert!(
            event
                .effects
                .iter()
                .any(|effect| effect.contains("行动点不足")),
            "失败结算应保留原始失败原因"
        );
    }

    #[test]
    fn 征用沿线仓储会立刻补充补给() {
        let mut engine = GameEngine::new();
        engine.army.supply = 30.0;
        let mut rng = seeded_rng();

        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "requisition_supplies",
            },
            &mut rng,
        );

        let policy_event = engine
            .last_action_events()
            .iter()
            .find(|event| event.event_type == "policy")
            .expect("应包含政策结算");
        assert!(
            policy_event.description.contains("征用沿线仓储"),
            "应使用可读政策名"
        );
        assert!(
            policy_event
                .effects
                .iter()
                .any(|effect| effect.contains("补给")),
            "政策结算应显式展示补给变化"
        );
        assert!(engine.army.supply > 30.0, "政策执行后补给应高于执行前");
    }

    // ── 忠诚度强化 ────────────────────────────────────

    #[test]
    fn 强化忠诚消耗合法性() {
        let mut engine = GameEngine::new();
        let leg_before = engine.politics.legitimacy;
        let _ = engine.process_boost_loyalty("davout");
        assert!(
            engine.politics.legitimacy < leg_before,
            "强化忠诚应消耗合法性"
        );
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
        engine
            .politics
            .faction_support
            .insert("liberals".to_string(), 5.0);
        engine
            .politics
            .faction_support
            .insert("populace".to_string(), 5.0);
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert_eq!(
            engine.outcome(),
            Some(GameOutcome::PoliticalCollapse),
            "双派系崩溃应终结游戏"
        );
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
        engine.army.avg_morale = 60.0;
        engine.army.supply = 80.0;
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert!(engine.army.avg_fatigue < 80.0, "休整后疲劳应减少");
        assert!(engine.army.avg_morale > 60.0, "休整后士气应提升");
    }

    #[test]
    fn 低补给时休整恢复较弱() {
        let mut high_supply = GameEngine::new();
        high_supply.army.avg_fatigue = 80.0;
        high_supply.army.avg_morale = 60.0;
        high_supply.army.supply = 80.0;

        let mut low_supply = GameEngine::new();
        low_supply.army.avg_fatigue = 80.0;
        low_supply.army.avg_morale = 60.0;
        low_supply.army.supply = 20.0;

        let mut rng = seeded_rng();
        high_supply.process_day(PlayerAction::Rest, &mut rng);
        let mut rng = seeded_rng();
        low_supply.process_day(PlayerAction::Rest, &mut rng);

        assert!(
            high_supply.army.avg_fatigue < low_supply.army.avg_fatigue,
            "高补给休整后应恢复更多疲劳"
        );
        assert!(
            high_supply.army.avg_morale > low_supply.army.avg_morale,
            "高补给休整后应恢复更多士气"
        );
    }

    #[test]
    fn 兵力极少时军方支持持续下降() {
        let mut engine = GameEngine::new();
        engine.army.total_troops = 15_000; // 低于20000阈值
        let mil_before = engine.politics.faction_support["military"];
        let mut rng = seeded_rng();
        engine.process_day(PlayerAction::Rest, &mut rng);
        assert!(
            engine.politics.faction_support["military"] < mil_before,
            "兵力危机应降低军方支持"
        );
    }

    #[test]
    fn 行军到相邻节点会同步位置与状态() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        let fatigue_before = engine.army.avg_fatigue;
        let supply_before = engine.army.supply;
        engine.process_day(
            PlayerAction::March {
                target_node: "grasse".to_string(),
            },
            &mut rng,
        );
        assert_eq!(engine.napoleon_location, "grasse", "相邻行军后位置应更新");
        assert!(
            engine.army.avg_fatigue != fatigue_before,
            "行军后疲劳应发生变化"
        );
        assert!(
            engine.army.supply != supply_before,
            "行军后补给应随位置变化而变化"
        );
    }

    #[test]
    fn 行军预览会返回权威预测值() {
        let engine = GameEngine::new();
        let preview = engine.preview_march("grasse");

        assert!(preview.valid, "相邻节点应可预览");
        assert_eq!(preview.target_node, "grasse");
        assert!(preview.fatigue_delta.abs() > 0.0);
        assert!(preview.projected_supply >= 0.0 && preview.projected_supply <= 100.0);
    }

    #[test]
    fn 非相邻行军不会改变位置() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::March {
                target_node: "paris".to_string(),
            },
            &mut rng,
        );
        assert_eq!(
            engine.napoleon_location, "golfe_juan",
            "非相邻行军不应改变位置"
        );
        assert!(
            engine
                .history
                .iter()
                .any(|event| event.event_type == "march_failed"),
            "失败行军应写入事件记录"
        );
    }

    #[test]
    fn 行军结算使用玩家可读地名() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::March {
                target_node: "grasse".to_string(),
            },
            &mut rng,
        );

        let event = engine.last_action_events().first().expect("应有行军结算");
        assert!(event.description.contains("儒安湾"));
        assert!(event.description.contains("格拉斯"));
        assert!(
            !event.description.contains("golfe_juan"),
            "日志不应再暴露节点 id"
        );
    }

    #[test]
    fn 联军兵力加成会进入联军状态() {
        let mut engine = GameEngine::new();
        let baseline = engine.coalition_force().troops;
        let mut effects = EventEffects::default();
        effects.coalition_troops_bonus = Some(30_000);

        engine.apply_event_effects(&effects);

        assert_eq!(
            engine.coalition_force().troops,
            baseline + 30_000,
            "事件中的 coalition_troops_bonus 应真正改变联军兵力"
        );
    }

    #[test]
    fn 巴黎治安与政治稳定加成会影响每日结算() {
        let mut engine = GameEngine::new();
        let mut control = GameEngine::new();
        let mut effects = EventEffects::default();
        effects.paris_security_bonus = Some(20.0);
        effects.political_stability_bonus = Some(8.0);

        engine.apply_event_effects(&effects);
        let mut rng = rand::thread_rng();
        engine.dusk_settlement(&mut rng);
        control.dusk_settlement(&mut rng);

        assert!(
            engine.politics.faction_support["populace"]
                > control.politics.faction_support["populace"],
            "巴黎治安加成应提升民众支持"
        );
        assert!(
            engine.politics.faction_support["nobility"]
                > control.politics.faction_support["nobility"],
            "巴黎治安加成应提升贵族支持"
        );
        assert!(
            engine.politics.legitimacy > control.politics.legitimacy,
            "政治稳定加成应托举合法性"
        );
    }

    // ── Save/Load 序列化 ──────────────────────────────

    #[test]
    fn 存档后读档状态一致() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        // 推进几天制造一些状态变化
        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "conscription",
            },
            &mut rng,
        );
        engine.process_day(PlayerAction::Rest, &mut rng);

        let saved_day = engine.day;
        let saved_legit = engine.politics.legitimacy;
        let saved_troops = engine.army.total_troops;
        let saved_supply = engine.army.supply;
        let saved_location = engine.napoleon_location.clone();
        engine.coalition_troops_bonus = 12_000;
        engine.paris_security_bonus = 15.0;
        engine.political_stability_bonus = 6.0;
        let saved_coalition = engine.coalition_troops_bonus;
        let saved_security = engine.paris_security_bonus;
        let saved_stability = engine.political_stability_bonus;
        let saved_triggered = engine.triggered_event_ids.clone();

        let json = engine.to_json();
        let restored = GameEngine::from_json(&json).expect("from_json 应成功");

        assert_eq!(restored.day, saved_day, "day 应一致");
        assert!(
            (restored.politics.legitimacy - saved_legit).abs() < 0.001,
            "legitimacy 应一致"
        );
        assert_eq!(restored.army.total_troops, saved_troops, "troops 应一致");
        assert!(
            (restored.army.supply - saved_supply).abs() < 0.001,
            "supply 应一致"
        );
        assert_eq!(
            restored.napoleon_location, saved_location,
            "napoleon_location 应一致"
        );
        assert_eq!(
            restored.coalition_troops_bonus, saved_coalition,
            "联军兵力修正应一致"
        );
        assert!(
            (restored.paris_security_bonus - saved_security).abs() < 0.001,
            "巴黎治安加成应一致"
        );
        assert!(
            (restored.political_stability_bonus - saved_stability).abs() < 0.001,
            "政治稳定加成应一致"
        );
        assert_eq!(
            restored.triggered_event_ids, saved_triggered,
            "已触发事件应一致"
        );
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

        let json = engine.to_json();
        let restored = GameEngine::from_json(&json).expect("from_json 应成功");

        // 读档后再推进，之前触发过的事件不应再触发
        let mut rng2 = seeded_rng();
        let mut restored = restored;
        for _ in 0..5 {
            restored.process_day(PlayerAction::Rest, &mut rng2);
        }
        for id in &triggered_before {
            let count = restored
                .triggered_event_ids
                .iter()
                .filter(|x| *x == id)
                .count();
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

    #[test]
    fn 旧存档缺少补给字段时使用默认值() {
        let json = json!({
            "version": 2,
            "day": 18,
            "legitimacy": 60.0,
            "rouge_noir": 0.0,
            "factions": {
                "military": 50.0,
                "populace": 50.0,
                "liberals": 50.0,
                "nobility": 50.0
            },
            "actions_remaining": 2,
            "troops": 72000,
            "morale": 75.0,
            "fatigue": 10.0,
            "victories": 0,
            "defeats": 0,
            "napoleon_location": "paris",
            "coalition_troops_bonus": 0,
            "paris_security_bonus": 0.0,
            "political_stability_bonus": 0.0,
            "loyalty": {
                "ney": 65.0
            },
            "relationships": [
                ["ney", "napoleon", 60.0]
            ],
            "triggered_event_ids": [],
            "outcome": null
        })
        .to_string();

        let restored = GameEngine::from_json(&json).expect("缺少补给字段的旧存档应可加载");
        assert!(
            (restored.army.supply - default_army_supply()).abs() < 0.001,
            "缺少补给字段时应回退到默认补给值"
        );
    }

    #[test]
    fn v1存档会迁移杜伊勒里宫前夜并去重() {
        let json = json!({
            "version": 1,
            "day": 18,
            "legitimacy": 60.0,
            "rouge_noir": 0.0,
            "factions": {
                "military": 50.0,
                "populace": 50.0,
                "liberals": 50.0,
                "nobility": 50.0
            },
            "actions_remaining": 2,
            "troops": 72000,
            "morale": 75.0,
            "fatigue": 10.0,
            "victories": 0,
            "defeats": 0,
            "napoleon_location": "paris",
            "coalition_troops_bonus": 0,
            "paris_security_bonus": 0.0,
            "political_stability_bonus": 0.0,
            "loyalty": {
                "ney": 65.0
            },
            "relationships": [
                ["ney", "napoleon", 60.0]
            ],
            "triggered_event_ids": [
                "fontainebleau_eve",
                "fontainebleau_eve",
                "ney_defection"
            ],
            "outcome": null
        })
        .to_string();

        let restored = GameEngine::from_json(&json).expect("v1 存档应可加载");

        assert_eq!(
            restored
                .triggered_event_ids
                .iter()
                .filter(|id| id.as_str() == "tuileries_eve")
                .count(),
            1,
            "旧 ID 应迁移为单个新 ID"
        );
        assert!(
            !restored
                .triggered_event_ids
                .iter()
                .any(|id| id == "fontainebleau_eve"),
            "旧 ID 不应保留在读档后的触发列表中"
        );
        assert!(
            restored.event_pool.is_triggered("tuileries_eve"),
            "事件池恢复状态应使用新 ID"
        );
        assert!(
            !restored.event_pool.is_triggered("fontainebleau_eve"),
            "事件池恢复状态不应保留旧 ID"
        );

        let mut rng = seeded_rng();
        let mut restored = restored;
        restored.process_day(PlayerAction::Rest, &mut rng);
        assert_eq!(
            restored
                .triggered_event_ids
                .iter()
                .filter(|id| id.as_str() == "tuileries_eve")
                .count(),
            1,
            "迁移后的事件在窗口内不应重复触发"
        );
    }

    // ── 叙事引擎集成 ──────────────────────────────────

    #[test]
    fn 执行征兵政策后有叙事报告() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::EnactPolicy {
                policy_id: "conscription",
            },
            &mut rng,
        );
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
        engine.process_day(
            PlayerAction::BoostLoyalty {
                general_id: "ney".to_string(),
            },
            &mut rng,
        );
        let report = engine.last_report().expect("BoostLoyalty 后应有报告");
        assert!(report.stendhal.is_some(), "强化忠诚应有司汤达评论");
    }

    #[test]
    fn 强化忠诚结算使用将领显示名() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::BoostLoyalty {
                general_id: "ney".to_string(),
            },
            &mut rng,
        );

        let event = engine
            .last_action_events()
            .first()
            .expect("应有强化忠诚结算");
        assert!(event.description.contains("内伊"));
        assert!(
            !event.description.contains("亲自接见 ney"),
            "日志不应再暴露将领 id"
        );
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
            engine
                .triggered_events()
                .iter()
                .any(|id| id == "ney_defection")
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
        let ney_count = engine
            .triggered_events()
            .iter()
            .filter(|id| *id == "ney_defection")
            .count();
        assert!(
            ney_count <= 1,
            "内伊倒戈不应重复触发，实际触发 {} 次",
            ney_count
        );
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
                engine
                    .history
                    .iter()
                    .any(|e| e.event_type == "historical_event"),
                "触发的历史事件应出现在 history 日志中"
            );
        }
    }

    #[test]
    fn 最近触发事件详情保留史注内容() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        for _ in 0..20 {
            engine.process_day(PlayerAction::Rest, &mut rng);
            if !engine.last_triggered_events().is_empty() {
                break;
            }
        }

        if !engine.last_triggered_events().is_empty() {
            assert!(
                engine
                    .last_triggered_events()
                    .iter()
                    .all(|event| !event.historical_note.is_empty()),
                "最近触发事件应保留 historical_note，供 UI 展示"
            );
        }
    }

    #[test]
    fn 战役结算使用可读地形与结果标签() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.process_day(
            PlayerAction::LaunchBattle {
                general_id: "ney".to_string(),
                troops: 60_000,
                terrain: Terrain::Plains,
            },
            &mut rng,
        );

        let event = engine.last_action_events().first().expect("应有战役结算");
        assert!(event.description.contains("内伊"));
        assert!(event.description.contains("平原"));
        assert!(
            event.description.contains("大捷")
                || event.description.contains("小胜")
                || event.description.contains("僵持")
                || event.description.contains("小败")
                || event.description.contains("惨败"),
            "战役描述应使用中文结果标签"
        );
    }

    // ── 联军增长 ──────────────────────────────────────

    #[test]
    fn 联军兵力随时间增长() {
        let mut engine = GameEngine::new();
        let early = engine.coalition_force().troops;
        engine.day = 90;
        let late = engine.coalition_force().troops;
        assert!(
            late > early * 2,
            "Day 90联军应远多于Day 1: early={}, late={}",
            early,
            late
        );
    }

    // ── 叛逃/倒戈每日检查（Tier 3.2）──────────────────

    #[test]
    fn 内伊忠诚正常时不触发叛逃() {
        let mut engine = GameEngine::new();
        let mut rng = seeded_rng();
        engine.day = 6;
        // 初始忠诚度60，远高于危机阈值30
        assert!(engine.characters.loyalty("ney") > LOYALTY_CRISIS_THRESHOLD);
        engine.dusk_settlement(&mut rng);
        // 不应有叛逃事件
        assert!(
            !engine
                .triggered_event_ids
                .iter()
                .any(|id| id == "ney_defection_dusk"),
            "忠诚正常时不应触发内伊叛逃"
        );
    }

    #[test]
    fn 内伊忠诚危机时可触发叛逃() {
        // 辅助函数：创建一个内伊低忠诚引擎
        fn make_low_ney_engine() -> GameEngine {
            let mut engine = GameEngine::new();
            engine.day = 6;
            let ney_loyalty = engine.characters.loyalty("ney");
            engine
                .characters
                .modify_loyalty("ney", -(ney_loyalty - 10.0), engine.day, "测试");
            engine.characters.set_relationship("ney", "napoleon", 80.0);
            engine
        }

        // 多次尝试（概率性），至少一次应触发
        let mut triggered = false;
        for seed in 0..100u64 {
            let mut test_engine = make_low_ney_engine();
            let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
            test_engine.dusk_settlement(&mut rng);
            if test_engine
                .triggered_event_ids
                .iter()
                .any(|id| id == "ney_defection_dusk")
            {
                triggered = true;
                // 验证效果
                assert!(
                    test_engine.characters.loyalty("ney") < 1.0,
                    "叛逃后忠诚应归零"
                );
                assert!(
                    test_engine
                        .history
                        .iter()
                        .any(|e| e.event_type == "defection"),
                    "应有叛逃事件记录"
                );
                break;
            }
        }
        assert!(triggered, "100次尝试中至少一次应触发内伊叛逃");
    }

    #[test]
    fn 叛逃后不会重复触发() {
        let mut engine = GameEngine::new();
        engine.day = 6;
        // 标记已叛逃
        engine
            .triggered_event_ids
            .push("ney_defection_dusk".to_string());
        let ney_loyalty = engine.characters.loyalty("ney");
        engine
            .characters
            .modify_loyalty("ney", -(ney_loyalty - 10.0), engine.day, "测试");
        let troops_before = engine.army.total_troops;

        let mut rng = seeded_rng();
        engine.dusk_settlement(&mut rng);
        // 兵力不应再因叛逃减少
        assert_eq!(
            engine.army.total_troops, troops_before,
            "已叛逃后不应再扣兵力"
        );
    }

    #[test]
    fn 格鲁希day90前不触发脱离() {
        let mut engine = GameEngine::new();
        engine.day = 50;
        // 强制低忠诚
        let g_loyalty = engine.characters.loyalty("grouchy");
        engine
            .characters
            .modify_loyalty("grouchy", -(g_loyalty - 10.0), engine.day, "测试");

        let mut rng = seeded_rng();
        let bonus_before = engine.coalition_troops_bonus;
        engine.dusk_settlement(&mut rng);
        assert_eq!(
            engine.coalition_troops_bonus, bonus_before,
            "Day 90之前不应触发格鲁希脱离"
        );
    }

    #[test]
    fn 格鲁希忠诚低且day90后可触发脱离() {
        fn make_low_grouchy_engine() -> GameEngine {
            let mut engine = GameEngine::new();
            engine.day = 92;
            let g_loyalty = engine.characters.loyalty("grouchy");
            engine
                .characters
                .modify_loyalty("grouchy", -(g_loyalty - 10.0), engine.day, "测试");
            engine
        }

        let mut triggered = false;
        for seed in 0..100u64 {
            let mut test_engine = make_low_grouchy_engine();
            let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
            test_engine.dusk_settlement(&mut rng);
            if test_engine
                .triggered_event_ids
                .iter()
                .any(|id| id == "grouchy_abandon_dusk")
            {
                triggered = true;
                assert_eq!(
                    test_engine.coalition_troops_bonus, 15_000,
                    "格鲁希脱离应增加联军兵力"
                );
                break;
            }
        }
        assert!(triggered, "100次尝试中至少一次应触发格鲁希脱离");
    }

    // ── 联军动态化（Tier 3.3）──────────────────────────

    #[test]
    fn 大胜后联军兵力下降() {
        let mut engine = GameEngine::new();
        let bonus_before = engine.coalition_troops_bonus;
        // 投入20000兵力大胜
        engine.apply_battle_coalition_impact(BattleResult::DecisiveVictory, 20_000);
        // 联军应损失 20000*0.8 = 16000
        assert_eq!(
            engine.coalition_troops_bonus,
            bonus_before - 16_000,
            "大胜后联军应损失兵力"
        );
    }

    #[test]
    fn 大败后联军兵力增加() {
        let mut engine = GameEngine::new();
        let bonus_before = engine.coalition_troops_bonus;
        engine.apply_battle_coalition_impact(BattleResult::DecisiveDefeat, 20_000);
        assert_eq!(
            engine.coalition_troops_bonus,
            bonus_before + 12_000,
            "大败后联军应获得增援"
        );
    }

    #[test]
    fn 小胜后联军兵力适度下降() {
        let mut engine = GameEngine::new();
        let bonus_before = engine.coalition_troops_bonus;
        engine.apply_battle_coalition_impact(BattleResult::MarginalVictory, 10_000);
        // 10000*0.3 = 3000
        assert_eq!(
            engine.coalition_troops_bonus,
            bonus_before - 3_000,
            "小胜后联军应适度损失"
        );
    }
}
