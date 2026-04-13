//! 三系统耦合状态机 — `engine::state`
//!
//! 统一持有 battle + politics + characters，按 Dawn→Action→Dusk 驱动。
//! 这是 GATE 2 的核心：三个系统的涌现交互在此发生。

use rand::Rng;

use crate::battle::resolver::{resolve_battle, BattleResult, ForceData, Terrain};
use crate::battle::{
    move_army, rest_army, supply_role_label, update_supply_with_capacity,
    ArmyState as MarchArmyState, MapEdge, MapGraph, MapNode, SUPPLY_OK_THRESHOLD,
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
    DiplomaticSettlement,
    MilitaryDominance,
    WaterlooHistorical,
    WaterlooDefeat,
    PoliticalCollapse,
    MilitaryAnnihilation,
}

impl GameOutcome {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::NapoleonVictory => "napoleon_victory",
            Self::DiplomaticSettlement => "diplomatic_settlement",
            Self::MilitaryDominance => "military_dominance",
            Self::WaterlooHistorical => "waterloo_historical",
            Self::WaterlooDefeat => "waterloo_defeat",
            Self::PoliticalCollapse => "political_collapse",
            Self::MilitaryAnnihilation => "military_annihilation",
        }
    }
}

// ── 难度 ──────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Difficulty {
    Elba,       // Easy
    Borodino,   // Normal (default)
    Austerlitz, // Hard
}

impl Difficulty {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Elba => "elba",
            Self::Borodino => "borodino",
            Self::Austerlitz => "austerlitz",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "elba" => Self::Elba,
            "austerlitz" => Self::Austerlitz,
            _ => Self::Borodino,
        }
    }

    /// Multiplier for enemy strength (lower = easier)
    pub fn enemy_strength_mult(&self) -> f64 {
        match self {
            Self::Elba => 0.75,
            Self::Borodino => 1.0,
            Self::Austerlitz => 1.3,
        }
    }

    /// Multiplier for political decay rate (lower = easier)
    pub fn political_decay_mult(&self) -> f64 {
        match self {
            Self::Elba => 0.7,
            Self::Borodino => 1.0,
            Self::Austerlitz => 1.4,
        }
    }

    /// Bonus to starting supply (higher = easier)
    pub fn supply_bonus(&self) -> f64 {
        match self {
            Self::Elba => 15.0,
            Self::Borodino => 0.0,
            Self::Austerlitz => -10.0,
        }
    }

    /// Bonus to starting legitimacy (higher = easier)
    pub fn legitimacy_bonus(&self) -> f64 {
        match self {
            Self::Elba => 10.0,
            Self::Borodino => 0.0,
            Self::Austerlitz => -5.0,
        }
    }
}

impl Default for Difficulty {
    fn default() -> Self {
        Self::Borodino
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
    /// 贝特朗当天的日记评论（基于玩家行动类型）
    pub bertrand: Option<String>,
    /// 普通人视角的后果片段（基于玩家行动类型）
    pub consequence: Option<String>,
}

/// Rust -> Godot 的扁平行军预判契约。
///
/// 这里故意保持扁平字段，而不是嵌套结构：
/// - `lib.rs` 会把它直接展开成 Dictionary
/// - `TurnManager` / `GameState` / 地图侧栏可以无损复用同一份字段
/// - 存量 GDScript 不需要理解 Rust 内部结构即可消费预判结果
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
    pub supply_capacity: u32,
    pub base_supply_capacity: u32,
    pub temporary_capacity_bonus: u32,
    pub supply_demand: f64,
    pub supply_available: f64,
    pub line_efficiency: f64,
    pub supply_role: String,
    pub supply_role_label: String,
    pub supply_hub_name: String,
    pub supply_hub_distance: u32,
    pub supply_runway_days: i32,
    pub follow_up_total_options: u32,
    pub follow_up_safe_options: u32,
    pub follow_up_risky_options: u32,
    pub follow_up_status_id: String,
    pub follow_up_status_label: String,
    pub follow_up_best_target: String,
    pub follow_up_best_target_label: String,
    pub follow_up_best_runway_days: i32,
}

/// 当前回合给 UI 的后勤建议快照。
///
/// 它不是额外规则状态，而是由当前军情、补给线和阶段目标推导出的只读摘要。
/// 设计上要求所有前端入口读取同一份结果，避免不同面板各自拼文案后再次漂移。
#[derive(Debug, Clone)]
pub struct LogisticsBrief {
    pub posture_id: String,
    pub posture_label: String,
    pub focus_title: String,
    pub focus_detail: String,
    pub focus_short: String,
    pub objective_id: String,
    pub objective_label: String,
    pub objective_target_role: String,
    pub objective_target_role_label: String,
    pub objective_detail: String,
    pub objective_short: String,
    pub action_plan_title: String,
    pub action_plan_detail: String,
    pub action_plan_short: String,
    pub primary_action_id: String,
    pub primary_action_label: String,
    pub primary_action_reason: String,
    pub primary_action_target: String,
    pub primary_action_target_label: String,
    pub secondary_action_id: String,
    pub secondary_action_label: String,
    pub secondary_action_reason: String,
    pub tempo_plan_title: String,
    pub tempo_plan_detail: String,
    pub tempo_plan_short: String,
    pub route_chain_title: String,
    pub route_chain_detail: String,
    pub route_chain_short: String,
    pub regional_pressure_id: String,
    pub regional_pressure_label: String,
    pub regional_pressure_title: String,
    pub regional_pressure_detail: String,
    pub regional_pressure_short: String,
    pub regional_task_id: String,
    pub regional_task_label: String,
    pub regional_task_title: String,
    pub regional_task_detail: String,
    pub regional_task_short: String,
    pub regional_task_progress_label: String,
    pub regional_task_reward_label: String,
}

#[derive(Debug, Clone)]
struct MarchStepProjection {
    target_node: String,
    fatigue_delta: f64,
    morale_delta: f64,
    supply_delta: f64,
    projected_fatigue: f64,
    projected_morale: f64,
    projected_supply: f64,
    supply_capacity: u32,
    base_supply_capacity: u32,
    temporary_capacity_bonus: u32,
    supply_demand: f64,
    supply_available: f64,
    line_efficiency: f64,
    supply_role: String,
    supply_role_label: String,
    supply_hub_name: String,
    supply_hub_distance: u32,
    supply_runway_days: i32,
    settled_army: MarchArmyState,
}

#[derive(Debug, Clone)]
struct FollowUpAssessment {
    total_options: u32,
    safe_options: u32,
    risky_options: u32,
    status_id: String,
    status_label: String,
    best_target: String,
    best_target_label: String,
    best_runway_days: i32,
}

#[derive(Debug, Clone)]
struct MarchTargetAdvice {
    target_node: String,
    target_label: String,
    projected_supply: f64,
    supply_capacity: u32,
    score: i32,
}

#[derive(Debug, Clone)]
struct ActionRecommendation {
    action_id: &'static str,
    action_label: String,
    action_reason: String,
    action_short: String,
    target_node: String,
    target_label: String,
}

#[derive(Debug, Clone)]
struct TempoPlan {
    title: String,
    detail: String,
    short: String,
}

#[derive(Debug, Clone)]
struct RouteChain {
    title: String,
    detail: String,
    short: String,
}

#[derive(Debug, Clone)]
struct RegionalPressure {
    id: String,
    label: String,
    title: String,
    detail: String,
    short: String,
}

#[derive(Debug, Clone)]
struct RegionalTask {
    id: String,
    label: String,
    title: String,
    detail: String,
    short: String,
    progress_label: String,
    reward_label: String,
}

#[derive(Debug, Clone)]
struct RegionalTaskPlan {
    id: &'static str,
    label: &'static str,
    title: String,
    detail: String,
    short: String,
    progress_target: u8,
    reward_label: String,
    condition_met: bool,
    completion_note: String,
    reset_note: String,
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

/// 可序列化的完整游戏存档快照。
///
/// `SaveState` 既是读写磁盘的格式，也是版本迁移的边界：
/// - 新字段必须通过 `serde(default)` 或显式迁移保证旧档可读
/// - UI 依赖的补给/区域运营状态也必须进存档，避免读档后前后端状态脱节
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveState {
    /// 存档格式版本（用于兼容性检查）
    pub version: u32,
    pub day: u32,
    #[serde(default)]
    pub day_started: bool,
    // 政治系统
    pub legitimacy: f64,
    pub rouge_noir: f64,
    pub factions: HashMap<String, f64>,
    pub actions_remaining: u32,
    #[serde(default)]
    pub decision_actions_start: u32,
    #[serde(default)]
    pub maneuver_used: bool,
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
    #[serde(default = "default_supply_line_bonus")]
    pub supply_line_bonus: f64,
    #[serde(default = "default_supply_line_bonus_days")]
    pub supply_line_bonus_days: u8,
    #[serde(default = "default_forward_depot_location")]
    pub forward_depot_location: String,
    #[serde(default = "default_forward_depot_capacity_bonus")]
    pub forward_depot_capacity_bonus: u32,
    #[serde(default = "default_forward_depot_days")]
    pub forward_depot_days: u8,
    #[serde(default = "default_regional_task_id")]
    pub regional_task_id: String,
    #[serde(default = "default_regional_task_progress")]
    pub regional_task_progress: u8,
    #[serde(default = "default_regional_task_completed")]
    pub regional_task_completed: bool,
    // 将领网络（当前忠诚度 + 关系强度）
    pub loyalty: HashMap<String, f64>,
    pub relationships: Vec<(String, String, f64)>,
    // 事件系统
    pub triggered_event_ids: Vec<String>,
    // 结局（in_progress 表示游戏进行中）
    pub outcome: Option<String>,
    // 难度设定（旧存档默认 borodino）
    #[serde(default = "default_difficulty")]
    pub difficulty: String,
    // 外交进度（旧存档默认 0）
    #[serde(default)]
    pub diplomatic_progress: u32,
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

fn default_supply_line_bonus() -> f64 {
    0.0
}

fn default_supply_line_bonus_days() -> u8 {
    0
}

fn default_forward_depot_location() -> String {
    String::new()
}

fn default_forward_depot_capacity_bonus() -> u32 {
    0
}

fn default_forward_depot_days() -> u8 {
    0
}

fn default_regional_task_id() -> String {
    String::new()
}

fn default_regional_task_progress() -> u8 {
    0
}

fn default_regional_task_completed() -> bool {
    false
}

fn default_difficulty() -> String {
    "borodino".to_string()
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
    day_started: bool,
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
    /// 临时补给线效率修正（由短期政策提供）
    supply_line_bonus: f64,
    /// 临时补给线修正剩余天数（包含当前结算）
    supply_line_bonus_days: u8,
    /// 前沿粮秣站所在节点（空串表示当前无部署）
    forward_depot_location: String,
    /// 前沿粮秣站提供的本地容量加成
    forward_depot_capacity_bonus: u32,
    /// 前沿粮秣站剩余天数（包含当前结算）
    forward_depot_days: u8,
    /// 当前区域任务 ID；空串表示尚未进入区域任务循环
    regional_task_id: String,
    /// 当前区域任务累计进度
    regional_task_progress: u8,
    /// 当前区域任务是否已在本阶段完成
    regional_task_completed: bool,
    pub history: Vec<DayEvent>,
    /// 游戏结局（Some = 游戏已结束）
    outcome: Option<GameOutcome>,
    /// 战役地图图结构（用于相邻移动与距离查询）
    map_graph: MapGraph,
    /// 内嵌事件池（Dawn 阶段自动触发）
    event_pool: EventPool,
    /// 已触发事件 ID 列表（按触发顺序）
    triggered_event_ids: Vec<String>,
    /// 叙事文本池（贝特朗日记 + 后果片段）
    narratives: NarrativePool,
    /// 最近一天的叙事报告（可供 UI 层读取）
    last_report: Option<DayReport>,
    /// 最近一次玩家行动的结算记录（不含 Dawn 历史事件）
    last_action_events: Vec<DayEvent>,
    /// 最近一次 Dawn 触发的历史事件详情（供 UI 在本回合立即展示）
    last_triggered_events: Vec<TriggeredEvent>,
    /// 难度设定
    difficulty: Difficulty,
    /// 外交进度（0-100，由外交事件链推进，达到阈值可触发外交结局）
    diplomatic_progress: u32,
    /// 当前日开始时可用的决策点数，用于计算日内消耗和保存中途进度。
    decision_actions_start: u8,
    /// 当前日是否已用掉机动槽（行军 / 战役 / 休整）。
    maneuver_used: bool,
}

impl Default for GameEngine {
    fn default() -> Self {
        const HISTORICAL_JSON: &str = include_str!("../../../src/data/events/historical.json");
        Self {
            day: 1,
            phase: TurnPhase::Dawn,
            day_started: false,
            politics: PoliticsState::default(),
            characters: historical_network_day1(),
            army: ArmyState::default(),
            napoleon_location: "golfe_juan".to_string(),
            coalition_troops_bonus: 0,
            paris_security_bonus: 0.0,
            political_stability_bonus: 0.0,
            supply_line_bonus: 0.0,
            supply_line_bonus_days: 0,
            forward_depot_location: String::new(),
            forward_depot_capacity_bonus: 0,
            forward_depot_days: 0,
            regional_task_id: String::new(),
            regional_task_progress: 0,
            regional_task_completed: false,
            history: Vec::new(),
            outcome: None,
            map_graph: default_campaign_map(),
            event_pool: EventPool::from_json(HISTORICAL_JSON).expect("historical.json parse error"),
            triggered_event_ids: Vec::new(),
            narratives: NarrativePool::new(),
            last_report: None,
            last_action_events: Vec::new(),
            last_triggered_events: Vec::new(),
            difficulty: Difficulty::default(),
            diplomatic_progress: 0,
            decision_actions_start: 0,
            maneuver_used: false,
        }
    }
}

impl GameEngine {
    pub fn new() -> Self {
        Self::default()
    }

    /// 指定难度创建新引擎
    pub fn new_with_difficulty(difficulty_str: &str) -> Self {
        let difficulty = Difficulty::from_str(difficulty_str);
        let mut engine = Self::default();
        engine.difficulty = difficulty;
        // Apply difficulty bonuses to initial state
        engine.army.supply = (engine.army.supply + difficulty.supply_bonus()).clamp(0.0, 100.0);
        engine.politics.legitimacy =
            (engine.politics.legitimacy + difficulty.legitimacy_bonus()).clamp(0.0, 100.0);
        engine
    }

    /// 当前难度
    pub fn difficulty(&self) -> Difficulty {
        self.difficulty
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

    pub fn maneuver_available(&self) -> bool {
        !self.maneuver_used
    }

    /// 当前日期
    pub fn current_day(&self) -> u32 {
        self.day
    }

    pub fn active_forward_depot(&self) -> Option<(&str, u32, u8)> {
        (self.forward_depot_days > 0
            && self.forward_depot_capacity_bonus > 0
            && !self.forward_depot_location.is_empty())
        .then_some((
            self.forward_depot_location.as_str(),
            self.forward_depot_capacity_bonus,
            self.forward_depot_days,
        ))
    }

    pub fn logistics_brief(&self) -> LogisticsBrief {
        let location = self.napoleon_location.as_str();
        let location_name = self.map_graph.node_name(location);
        let supply = self.army.supply;
        let fatigue = self.army.avg_fatigue;
        let capacity_bonus = self.forward_depot_capacity_bonus_for(location);
        let capacity = self.effective_supply_capacity_for(location);
        let (hub_name, hub_distance) = self.nearest_supply_hub(location);
        let role_label = self.map_graph.supply_role_label_of(location);
        let (posture_id, posture_label) = self.logistics_posture_for(
            location,
            supply,
            fatigue,
            capacity,
            capacity_bonus,
            hub_distance,
        );
        let (
            objective_id,
            objective_label,
            objective_target_role,
            objective_detail,
            objective_short,
        ) = self.operational_objective_for(
            location,
            posture_id,
            supply,
            fatigue,
            capacity,
            hub_distance,
        );
        let (primary_action, secondary_action) = self.logistics_action_plan_for(
            location,
            posture_id,
            objective_target_role,
            supply,
            fatigue,
            capacity,
            hub_distance,
        );
        let tempo_plan = self.logistics_tempo_plan_for(
            location,
            posture_id,
            supply,
            objective_target_role,
            &primary_action,
            &secondary_action,
        );
        let route_chain = self.logistics_route_chain_for(
            location,
            objective_target_role,
            &primary_action,
            &secondary_action,
        );
        let regional_pressure = self.logistics_regional_pressure_for(
            location,
            posture_id,
            objective_target_role,
            &primary_action,
        );
        let regional_task = self.regional_task_for(
            location,
            posture_id,
            objective_id,
            objective_label,
            objective_target_role,
            &regional_pressure,
        );
        let focus_title = self.campaign_focus_title().to_string();
        let focus_detail = match posture_id {
            "critical_recovery" => format!(
                "{} 当前补给 {:.0}、疲劳 {:.0}。先休整或补给，把库存和体力拉回安全线，再谈推进。",
                location_name, supply, fatigue
            ),
            "forward_staging" => format!(
                "{} 已是前沿粮秣站跳板，当前有效容量 {}，剩余 {} 天。趁窗口恢复补给和疲劳，再决定是否继续前推。",
                location_name, capacity, self.forward_depot_days
            ),
            "frontline_strain" => {
                let hub_text = if hub_distance != u32::MAX {
                    format!("距最近补给枢纽 {} 还有 {} 跳", hub_name, hub_distance)
                } else {
                    "附近没有稳定补给枢纽".to_string()
                };
                format!(
                    "{} 属于{}，当前有效容量 {}，{}。这里适合短暂停留，不适合连续硬顶。",
                    location_name, role_label, capacity, hub_text
                )
            }
            "overextended_line" => format!(
                "{} 是{}，离最近枢纽 {} 还有 {} 跳。若准备继续推进，先整顿运输线或在这里建立前沿粮秣站。",
                location_name, role_label, hub_name, hub_distance
            ),
            "advance_ready" => format!(
                "当前补给 {:.0}、疲劳 {:.0}，{} 的有效容量为 {}。眼下可以继续推进，但下一站若是低容量节点，仍要预留补给余量。",
                supply, fatigue, location_name, capacity
            ),
            _ => format!(
                "{} 当前有效容量 {}，补给 {:.0}、疲劳 {:.0}。这里适合先整补，再决定下一步。",
                location_name, capacity, supply, fatigue
            ),
        };
        let focus_short = match posture_id {
            "critical_recovery" => "止血整补：先休整或补给，不要继续硬顶。".to_string(),
            "forward_staging" => "前沿整补跳板：趁粮秣站窗口恢复后再推进。".to_string(),
            "frontline_strain" => "前线消耗区：不要连续站在低容量节点。".to_string(),
            "overextended_line" => "运输线拉长：先保线或铺站，再继续北上。".to_string(),
            "advance_ready" => "推进窗口已开：可以前推，但别连续走进低容量节点。".to_string(),
            _ => "整补筹备窗口：先把补给和疲劳拉回安全线。".to_string(),
        };
        let action_plan_title = "当日行动计划".to_string();
        let action_plan_detail = format!(
            "优先：{}。{}\n备选：{}。{}",
            primary_action.action_label,
            primary_action.action_reason,
            secondary_action.action_label,
            secondary_action.action_reason
        );

        LogisticsBrief {
            posture_id: posture_id.to_string(),
            posture_label: posture_label.to_string(),
            focus_title,
            focus_detail,
            focus_short,
            objective_id: objective_id.to_string(),
            objective_label: objective_label.to_string(),
            objective_target_role: objective_target_role.to_string(),
            objective_target_role_label: supply_role_label(objective_target_role).to_string(),
            objective_detail,
            objective_short,
            action_plan_title,
            action_plan_detail,
            action_plan_short: primary_action.action_short,
            primary_action_id: primary_action.action_id.to_string(),
            primary_action_label: primary_action.action_label,
            primary_action_reason: primary_action.action_reason,
            primary_action_target: primary_action.target_node,
            primary_action_target_label: primary_action.target_label,
            secondary_action_id: secondary_action.action_id.to_string(),
            secondary_action_label: secondary_action.action_label,
            secondary_action_reason: secondary_action.action_reason,
            tempo_plan_title: tempo_plan.title,
            tempo_plan_detail: tempo_plan.detail,
            tempo_plan_short: tempo_plan.short,
            route_chain_title: route_chain.title,
            route_chain_detail: route_chain.detail,
            route_chain_short: route_chain.short,
            regional_pressure_id: regional_pressure.id,
            regional_pressure_label: regional_pressure.label,
            regional_pressure_title: regional_pressure.title,
            regional_pressure_detail: regional_pressure.detail,
            regional_pressure_short: regional_pressure.short,
            regional_task_id: regional_task.id,
            regional_task_label: regional_task.label,
            regional_task_title: regional_task.title,
            regional_task_detail: regional_task.detail,
            regional_task_short: regional_task.short,
            regional_task_progress_label: regional_task.progress_label,
            regional_task_reward_label: regional_task.reward_label,
        }
    }

    pub fn current_supply_runway_days(&self) -> Option<u32> {
        self.supply_runway_days_for(&self.napoleon_location, self.army.supply)
    }

    pub fn current_supply_runway_label(&self) -> String {
        Self::supply_runway_label(self.current_supply_runway_days())
    }

    /// 当前可直接行军到的相邻节点列表。
    pub fn adjacent_nodes(&self) -> Vec<String> {
        self.map_graph.neighbors_of(&self.napoleon_location)
    }

    /// 预览一次普通行军的预计变化，不修改真实状态。
    pub fn preview_march(&self, target_node: &str) -> MarchPreview {
        let current = self.current_march_army_state();
        let Some(step) = self.project_march_step(&current, target_node) else {
            let move_result = move_army(&current, target_node, false, &self.map_graph);
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
                supply_capacity: 0,
                base_supply_capacity: 0,
                temporary_capacity_bonus: 0,
                supply_demand: 0.0,
                supply_available: 0.0,
                line_efficiency: 0.0,
                supply_role: String::new(),
                supply_role_label: String::new(),
                supply_hub_name: String::new(),
                supply_hub_distance: 0,
                supply_runway_days: -1,
                follow_up_total_options: 0,
                follow_up_safe_options: 0,
                follow_up_risky_options: 0,
                follow_up_status_id: String::new(),
                follow_up_status_label: String::new(),
                follow_up_best_target: String::new(),
                follow_up_best_target_label: String::new(),
                follow_up_best_runway_days: -1,
            };
        };
        let follow_up = self.follow_up_assessment(&step.settled_army, &current.location);

        MarchPreview {
            valid: true,
            reason: None,
            target_node: step.target_node,
            fatigue_delta: step.fatigue_delta,
            morale_delta: step.morale_delta,
            supply_delta: step.supply_delta,
            projected_fatigue: step.projected_fatigue,
            projected_morale: step.projected_morale,
            projected_supply: step.projected_supply,
            supply_capacity: step.supply_capacity,
            base_supply_capacity: step.base_supply_capacity,
            temporary_capacity_bonus: step.temporary_capacity_bonus,
            supply_demand: step.supply_demand,
            supply_available: step.supply_available,
            line_efficiency: step.line_efficiency,
            supply_role: step.supply_role,
            supply_role_label: step.supply_role_label,
            supply_hub_name: step.supply_hub_name,
            supply_hub_distance: step.supply_hub_distance,
            supply_runway_days: step.supply_runway_days,
            follow_up_total_options: follow_up.total_options,
            follow_up_safe_options: follow_up.safe_options,
            follow_up_risky_options: follow_up.risky_options,
            follow_up_status_id: follow_up.status_id,
            follow_up_status_label: follow_up.status_label,
            follow_up_best_target: follow_up.best_target,
            follow_up_best_target_label: follow_up.best_target_label,
            follow_up_best_runway_days: follow_up.best_runway_days,
        }
    }

    fn project_march_step(
        &self,
        current: &MarchArmyState,
        target_node: &str,
    ) -> Option<MarchStepProjection> {
        let move_result = move_army(current, target_node, false, &self.map_graph);
        if !move_result.success {
            return None;
        }

        let line_efficiency = self.supply_line_efficiency_for(&move_result.new_location);
        let base_capacity = self.map_graph.supply_capacity_of(&move_result.new_location);
        let temporary_capacity_bonus =
            self.forward_depot_capacity_bonus_for(&move_result.new_location);
        let effective_capacity = base_capacity + temporary_capacity_bonus;
        let projected_army = MarchArmyState {
            id: current.id.clone(),
            location: move_result.new_location.clone(),
            troops: self.army.total_troops,
            morale: move_result.new_morale,
            fatigue: move_result.new_fatigue,
            supply: current.supply,
        };
        let supply_result =
            update_supply_with_capacity(&projected_army, line_efficiency, effective_capacity);
        let (hub_name, hub_distance) = self.nearest_supply_hub(&projected_army.location);
        let supply_runway_days = self
            .supply_runway_days_for(&projected_army.location, supply_result.new_supply)
            .map(|days| days as i32)
            .unwrap_or(-1);
        let settled_army = MarchArmyState {
            supply: supply_result.new_supply,
            ..projected_army
        };

        Some(MarchStepProjection {
            target_node: move_result.new_location,
            fatigue_delta: move_result.fatigue_delta,
            morale_delta: move_result.morale_delta,
            supply_delta: supply_result.supply_delta,
            projected_fatigue: move_result.new_fatigue,
            projected_morale: move_result.new_morale,
            projected_supply: supply_result.new_supply,
            supply_capacity: effective_capacity,
            base_supply_capacity: base_capacity,
            temporary_capacity_bonus,
            supply_demand: supply_result.demand,
            supply_available: supply_result.available,
            line_efficiency: supply_result.line_efficiency,
            supply_role: self
                .map_graph
                .supply_role_of(&settled_army.location)
                .to_string(),
            supply_role_label: self
                .map_graph
                .supply_role_label_of(&settled_army.location)
                .to_string(),
            supply_hub_name: hub_name,
            supply_hub_distance: hub_distance,
            supply_runway_days,
            settled_army,
        })
    }

    fn follow_up_assessment(
        &self,
        projected_army: &MarchArmyState,
        previous_location: &str,
    ) -> FollowUpAssessment {
        let mut total_options = 0;
        let mut safe_options = 0;
        let mut risky_options = 0;
        let mut best_target = String::new();
        let mut best_target_label = String::new();
        let mut best_runway_days = -1;
        let mut best_runway_score = -1;
        let mut best_projected_supply = -1.0;

        for neighbor in self.map_graph.neighbors_of(&projected_army.location) {
            if neighbor == previous_location {
                continue;
            }
            total_options += 1;
            let Some(step) = self.project_march_step(projected_army, &neighbor) else {
                continue;
            };
            let runway_score = Self::runway_score(step.supply_runway_days);
            let is_safe = Self::is_safe_follow_up(&step);
            if is_safe {
                safe_options += 1;
            } else {
                risky_options += 1;
            }
            if runway_score > best_runway_score
                || (runway_score == best_runway_score
                    && step.projected_supply > best_projected_supply)
            {
                best_runway_score = runway_score;
                best_projected_supply = step.projected_supply;
                best_target = step.target_node.clone();
                best_target_label = self.map_graph.node_name(&step.target_node);
                best_runway_days = step.supply_runway_days;
            }
        }

        let (status_id, status_label) = if total_options == 0 {
            (
                "dead_end",
                "第二跳：这里之后没有继续前推空间，只能原地整补或回撤。",
            )
        } else if safe_options == 0 {
            (
                "frontline_trap",
                "第二跳：落点后的继续前推都贴着补给惩罚区，属于高风险压线推进。",
            )
        } else if safe_options == 1 {
            (
                "single_lane_push",
                "第二跳：只剩 1 条相对稳妥的继续推进路线，机动余地很窄。",
            )
        } else {
            (
                "flexible_push",
                "第二跳：落点后仍保留多条相对稳妥的推进路线。",
            )
        };

        FollowUpAssessment {
            total_options,
            safe_options,
            risky_options,
            status_id: status_id.to_string(),
            status_label: status_label.to_string(),
            best_target,
            best_target_label,
            best_runway_days,
        }
    }

    fn logistics_action_plan_for(
        &self,
        location: &str,
        posture_id: &str,
        objective_target_role: &str,
        supply: f64,
        fatigue: f64,
        capacity: u32,
        hub_distance: u32,
    ) -> (ActionRecommendation, ActionRecommendation) {
        let march_target = self.best_adjacent_target_for_objective(location, objective_target_role);
        match posture_id {
            "critical_recovery" if supply < SUPPLY_OK_THRESHOLD => (
                self.policy_recommendation(
                    "requisition_supplies",
                    "征用沿线仓储",
                    "库存已经跌进战斗惩罚区，先把补给拉回安全线，再谈下一步位置和战役。",
                    "先征用沿线仓储止血，再决定后续节奏。",
                ),
                self.rest_recommendation(
                    "止血后下一步优先休整，把疲劳和士气一起拉回安全区。",
                    "随后休整，别在危险区继续硬顶。",
                ),
            ),
            "critical_recovery" => (
                self.rest_recommendation(
                    "疲劳已经过高，当前更需要先恢复体力和士气，而不是继续追位置。",
                    "先休整，把体力和士气拉回安全线。",
                ),
                march_target
                    .as_ref()
                    .map(|target| {
                        self.march_recommendation(
                            target,
                            format!(
                                "休整后若要换位，优先转到 {}，那里更适合接回补给节奏。",
                                target.target_label
                            ),
                            format!("整补后再转到 {}。", target.target_label),
                        )
                    })
                    .unwrap_or_else(|| {
                        self.policy_recommendation(
                            "stabilize_supply_lines",
                            "整顿驿站运输",
                            "若不准备停留太久，至少先把运输线效率拉起来，避免恢复完又立刻掉回危险区。",
                            "若要很快再动，先整顿驿站运输。",
                        )
                    }),
            ),
            "overextended_line" => (
                self.policy_recommendation(
                    "secure_regional_corridor",
                    "巩固区域走廊",
                    "当前不只是运输线掉速，整段中继也在变脆。先把当前区域走廊一起加固，再谈后面两三步。",
                    "先巩固区域走廊，别让中继线继续发散。",
                ),
                march_target
                    .as_ref()
                    .map(|target| {
                        self.march_recommendation(
                            target,
                            format!(
                                "若不想原地等待，下一步优先接到 {}，先把中继仓储重新串起来。",
                                target.target_label
                            ),
                            format!("若继续移动，先接到 {}。", target.target_label),
                        )
                    })
                    .unwrap_or_else(|| {
                        self.policy_recommendation(
                            "stabilize_supply_lines",
                            "整顿驿站运输",
                            "若暂时还走不开，至少先把线效率顶住，别让整条走廊继续掉速。",
                            "若走不开，先整顿驿站运输。",
                        )
                    }),
            ),
            "frontline_strain" => {
                if let Some(target) = march_target.as_ref() {
                    (
                        self.march_recommendation(
                            target,
                            format!(
                                "{} 属于前线消耗区。下一步优先转到 {}，先把路线接出低容量节点。",
                                self.map_graph.node_name(location),
                                target.target_label
                            ),
                            format!("先转到 {}，别连续站在前线消耗点。", target.target_label),
                        ),
                        self.policy_recommendation(
                            "secure_regional_corridor",
                            "巩固区域走廊",
                            "如果准备把这段线真正站稳，而不是只从这里路过一次，就先把当前节点和沿线运输一起加固。",
                            "若要把这里做成中继，就先巩固区域走廊。",
                        ),
                    )
                } else {
                    (
                        self.policy_recommendation(
                            "secure_regional_corridor",
                            "巩固区域走廊",
                            "当前附近没有更稳的落点可立刻接上，先把这段区域走廊加固，至少别让补给线和本地仓储一起继续变差。",
                            "先巩固区域走廊，别在裸前线硬顶。",
                        ),
                        self.policy_recommendation(
                            "requisition_supplies",
                            "征用沿线仓储",
                            "若库存已经快见底，征用仓储会比继续赶路更直接。",
                            "库存再掉就先征用沿线仓储。",
                        ),
                    )
                }
            }
            "forward_staging" if supply < 65.0 || fatigue > 35.0 => (
                self.rest_recommendation(
                    "前沿粮秣站窗口已经打开，当前更该利用这两三天把补给和疲劳拉回安全线。",
                    "先休整，吃满粮秣站窗口。",
                ),
                march_target
                    .as_ref()
                    .map(|target| {
                        self.march_recommendation(
                            target,
                            format!("补满后若继续推进，优先去 {}。", target.target_label),
                            format!("补满后再去 {}。", target.target_label),
                        )
                    })
                    .unwrap_or_else(|| {
                        self.policy_recommendation(
                            "stabilize_supply_lines",
                            "整顿驿站运输",
                            "若想把这座跳板再延长两三天的价值，先把运输线也一起稳住。",
                            "若要继续北上，再整顿驿站运输。",
                        )
                    }),
            ),
            "advance_ready" => (
                march_target
                    .as_ref()
                    .map(|target| {
                        self.march_recommendation(
                            target,
                            format!(
                                "当前补给和疲劳都允许继续推进。下一步优先去 {}，把这段窗口兑现成位置优势。",
                                target.target_label
                            ),
                            format!("先去 {}，把推进窗口兑现掉。", target.target_label),
                        )
                    })
                    .unwrap_or_else(|| {
                        self.rest_recommendation(
                            "当前虽然能动，但附近没有更好的承接点，先稳住再看下一回合。",
                            "先稳住，再等更好的推进窗口。",
                        )
                    }),
                if hub_distance >= 3 {
                    self.policy_recommendation(
                        "stabilize_supply_lines",
                        "整顿驿站运输",
                        "若打算连续两三步都往前压，先把运输线效率顶上去会更稳。",
                        "若准备连走两三步，先整顿驿站运输。",
                    )
                } else {
                    self.policy_recommendation(
                        "establish_forward_depot",
                        "建立前沿粮秣站",
                        "若想把当前位置做成前线跳板，先铺站能让后续选择更宽。",
                        "若想把这里做跳板，就先铺前沿粮秣站。",
                    )
                },
            ),
            _ => (
                march_target
                    .as_ref()
                    .map(|target| {
                        self.march_recommendation(
                            target,
                            format!(
                                "当前更需要把路线接向 {}，让后面的补给节奏先稳下来。",
                                target.target_label
                            ),
                            format!("先把路线接到 {}。", target.target_label),
                        )
                    })
                    .unwrap_or_else(|| {
                        self.rest_recommendation(
                            "当前没有更稳的相邻落点，先整补比盲目前推更值。",
                            "先休整，再找下一段落点。",
                        )
                    }),
                if capacity <= 3 || fatigue > 45.0 {
                    self.rest_recommendation(
                        "库存或疲劳还没稳住前，不要把当前位置当成长期前线。",
                        "备选是先休整。",
                    )
                } else {
                    self.policy_recommendation(
                        "stabilize_supply_lines",
                        "整顿驿站运输",
                        "如果准备马上接第二步，这张牌能把当前窗口拉得更长。",
                        "备选是先整顿驿站运输。",
                    )
                },
            ),
        }
    }

    fn logistics_tempo_plan_for(
        &self,
        location: &str,
        posture_id: &str,
        supply: f64,
        objective_target_role: &str,
        primary_action: &ActionRecommendation,
        secondary_action: &ActionRecommendation,
    ) -> TempoPlan {
        let title = "三日后勤节奏".to_string();
        let objective_label = supply_role_label(objective_target_role);
        let today_line = format!("今天：{}", primary_action.action_label);

        let (tomorrow_line, day_three_line, short) = match primary_action.action_id {
            "march" if !primary_action.target_node.is_empty() => {
                let preview = self.preview_march(&primary_action.target_node);
                if !preview.valid {
                    (
                        format!("明天：{}。", secondary_action.action_label),
                        format!("后天：再按阶段目标寻找{}。", objective_label),
                        format!(
                            "先{}，若途中受阻就改走“{}”。",
                            primary_action.action_label, secondary_action.action_label
                        ),
                    )
                } else if preview.follow_up_safe_options == 0 {
                    (
                        format!(
                            "明天：{}，不要在 {} 后继续硬顶。",
                            secondary_action.action_label, primary_action.target_label
                        ),
                        format!(
                            "后天：库存回到安全线后，再按阶段目标接向{}。",
                            objective_label
                        ),
                        format!(
                            "先{}，次日立刻{}。",
                            primary_action.action_label, secondary_action.action_label
                        ),
                    )
                } else if !preview.follow_up_best_target_label.is_empty() {
                    (
                        format!(
                            "明天：若补给仍在安全线，继续接到 {}。",
                            preview.follow_up_best_target_label
                        ),
                        format!(
                            "后天：以 {} 为跳板，评估是否继续压向{}。",
                            preview.follow_up_best_target_label, objective_label
                        ),
                        format!(
                            "先{}，次日再接{}。",
                            primary_action.target_label, preview.follow_up_best_target_label
                        ),
                    )
                } else {
                    (
                        format!(
                            "明天：在 {} 先整补，不要急着连走。",
                            primary_action.target_label
                        ),
                        format!("后天：整补完后，再按阶段目标接向{}。", objective_label),
                        format!("先{}，次日优先整补。", primary_action.target_label),
                    )
                }
            }
            "rest" => {
                if let Some(target) =
                    self.best_adjacent_target_for_objective(location, objective_target_role)
                {
                    (
                        format!("明天：恢复后优先转到 {}。", target.target_label),
                        format!(
                            "后天：以 {} 为跳板，继续把路线接向{}。",
                            target.target_label, objective_label
                        ),
                        format!("先休整，明天再转到{}。", target.target_label),
                    )
                } else {
                    (
                        format!(
                            "明天：若状态回稳，再执行“{}”。",
                            secondary_action.action_label
                        ),
                        format!("后天：继续按阶段目标寻找{}。", objective_label),
                        format!("先休整，再按“{}”推进。", secondary_action.action_label),
                    )
                }
            }
            "requisition_supplies" => {
                if posture_id == "critical_recovery" || supply < SUPPLY_OK_THRESHOLD {
                    if let Some(target) =
                        self.best_adjacent_target_for_objective(location, objective_target_role)
                    {
                        (
                            "明天：休整，把刚补回来的库存和体力一起拉回安全线。".to_string(),
                            format!(
                                "后天：恢复后再转到 {}，把路线接向{}。",
                                target.target_label, objective_label
                            ),
                            format!(
                                "先征用沿线仓储止血，次日先休整，再转到{}。",
                                target.target_label
                            ),
                        )
                    } else {
                        (
                            "明天：休整，把库存和体力拉回安全线。".to_string(),
                            format!("后天：恢复后再按阶段目标寻找{}。", objective_label),
                            "先征用沿线仓储止血，次日先休整。".to_string(),
                        )
                    }
                } else if let Some(target) =
                    self.best_adjacent_target_for_objective(location, objective_target_role)
                {
                    (
                        format!(
                            "明天：止血后优先转到 {}，把库存换成更稳的落点。",
                            target.target_label
                        ),
                        format!(
                            "后天：在 {} 恢复或继续向{}铺路。",
                            target.target_label, objective_label
                        ),
                        format!("先征用沿线仓储止血，明天再转到{}。", target.target_label),
                    )
                } else {
                    (
                        "明天：补给回稳后优先休整，不要立刻继续硬顶。".to_string(),
                        format!("后天：恢复后再按阶段目标寻找{}。", objective_label),
                        "先征用沿线仓储止血，次日先休整。".to_string(),
                    )
                }
            }
            "stabilize_supply_lines" => {
                if let Some(target) =
                    self.best_adjacent_target_for_objective(location, objective_target_role)
                {
                    (
                        format!("明天：运输线稳住后，优先接到 {}。", target.target_label),
                        format!(
                            "后天：若窗口还在，从 {} 继续把路线接向{}。",
                            target.target_label, objective_label
                        ),
                        format!("先整顿驿站运输，明天接到{}。", target.target_label),
                    )
                } else {
                    (
                        format!("明天：保线后再执行“{}”。", secondary_action.action_label),
                        format!("后天：继续按阶段目标接向{}。", objective_label),
                        format!(
                            "先整顿驿站运输，再按“{}”推进。",
                            secondary_action.action_label
                        ),
                    )
                }
            }
            "establish_forward_depot" => (
                "明天：利用粮秣站窗口先恢复补给和疲劳，不要急着立刻连走。".to_string(),
                format!(
                    "后天：把当前节点当跳板，再决定是否压向{}。",
                    objective_label
                ),
                "先铺前沿粮秣站，接着吃满两天整补窗口。".to_string(),
            ),
            "secure_regional_corridor" => {
                if let Some(target) =
                    self.best_adjacent_target_for_objective(location, objective_target_role)
                {
                    (
                        format!("明天：走廊稳住后，优先接到 {}。", target.target_label),
                        format!(
                            "后天：以 {} 为中继，把路线继续压向{}。",
                            target.target_label, objective_label
                        ),
                        format!("先巩固区域走廊，明天再接到{}。", target.target_label),
                    )
                } else {
                    (
                        "明天：吃满走廊加固窗口，优先恢复补给和疲劳。".to_string(),
                        format!("后天：窗口还在时，再按阶段目标接向{}。", objective_label),
                        "先巩固区域走廊，再利用窗口恢复。".to_string(),
                    )
                }
            }
            _ => (
                format!("明天：执行“{}”。", secondary_action.action_label),
                format!("后天：继续按阶段目标接向{}。", objective_label),
                format!(
                    "先{}，再执行“{}”。",
                    primary_action.action_label, secondary_action.action_label
                ),
            ),
        };

        TempoPlan {
            title,
            detail: format!("{}\n{}\n{}", today_line, tomorrow_line, day_three_line),
            short,
        }
    }

    fn logistics_route_chain_for(
        &self,
        location: &str,
        objective_target_role: &str,
        primary_action: &ActionRecommendation,
        secondary_action: &ActionRecommendation,
    ) -> RouteChain {
        let title = "区域运营链路".to_string();
        let current_label = self.map_graph.node_name(location);
        let objective_label = supply_role_label(objective_target_role);

        let (detail, short) = if primary_action.action_id == "march"
            && !primary_action.target_node.is_empty()
        {
            let preview = self.preview_march(&primary_action.target_node);
            if preview.valid && !preview.follow_up_best_target_label.is_empty() {
                (
                    format!(
                        "推荐链路：{} -> {} -> {}。\n第 1 段先把当前位置接到更稳的承接点；第 2 段再以 {} 为跳板，继续靠近{}。",
                        current_label,
                        primary_action.target_label,
                        preview.follow_up_best_target_label,
                        preview.follow_up_best_target_label,
                        objective_label
                    ),
                    format!(
                        "推荐链路：{} -> {} -> {}。",
                        current_label,
                        primary_action.target_label,
                        preview.follow_up_best_target_label
                    ),
                )
            } else {
                (
                    format!(
                        "推荐链路：{} -> {}。\n先把路线接到 {}，再按阶段目标继续寻找{}。",
                        current_label,
                        primary_action.target_label,
                        primary_action.target_label,
                        objective_label
                    ),
                    format!(
                        "推荐链路：{} -> {}。",
                        current_label, primary_action.target_label
                    ),
                )
            }
        } else if let Some(target) =
            self.best_adjacent_target_for_objective(location, objective_target_role)
        {
            let preview = self.preview_march(&target.target_node);
            if preview.valid && !preview.follow_up_best_target_label.is_empty() {
                (
                    format!(
                        "推荐链路：{} -> {} -> {}。\n先执行“{}”，再把部队接到 {}，随后以 {} 为下一段跳板。",
                        current_label,
                        target.target_label,
                        preview.follow_up_best_target_label,
                        primary_action.action_label,
                        target.target_label,
                        preview.follow_up_best_target_label
                    ),
                    format!(
                        "先{}，再走 {} -> {}。",
                        primary_action.action_label,
                        target.target_label,
                        preview.follow_up_best_target_label
                    ),
                )
            } else {
                (
                    format!(
                        "推荐链路：{} -> {}。\n先执行“{}”，再把路线接到 {}，继续靠近{}。",
                        current_label,
                        target.target_label,
                        primary_action.action_label,
                        target.target_label,
                        objective_label
                    ),
                    format!(
                        "先{}，再走到{}。",
                        primary_action.action_label, target.target_label
                    ),
                )
            }
        } else {
            (
                format!(
                    "当前暂无稳定链路；先执行“{}”，再按阶段目标寻找{}。备选动作是“{}”。",
                    primary_action.action_label, objective_label, secondary_action.action_label
                ),
                format!(
                    "先{}，再寻找{}。",
                    primary_action.action_label, objective_label
                ),
            )
        };

        RouteChain {
            title,
            detail,
            short,
        }
    }

    fn logistics_regional_pressure_for(
        &self,
        location: &str,
        posture_id: &str,
        objective_target_role: &str,
        primary_action: &ActionRecommendation,
    ) -> RegionalPressure {
        let title = "区域运营压力".to_string();
        let current_label = self.map_graph.node_name(location);
        let objective_label = supply_role_label(objective_target_role);
        let capacity = self.effective_supply_capacity_for(location);
        let (_, hub_distance) = self.nearest_supply_hub(location);
        let active_depot_here =
            self.forward_depot_days > 0 && self.forward_depot_location == location;
        let active_line_bonus = self.supply_line_bonus_days > 0;
        let preview =
            if primary_action.action_id == "march" && !primary_action.target_node.is_empty() {
                let candidate = self.preview_march(&primary_action.target_node);
                candidate.valid.then_some(candidate)
            } else {
                None
            };

        let (id, label, detail, short) = match posture_id {
            "critical_recovery" => (
                "corridor_breaking",
                "区域走廊承压",
                format!(
                    "{} 这段区域走廊已经压到临界线。当前更需要先止血、保线，再谈是否继续压向{}。",
                    current_label, objective_label
                ),
                "区域走廊承压：先固线或止血，再谈继续前推。".to_string(),
            ),
            "overextended_line"
                if preview
                    .as_ref()
                    .map(|candidate| candidate.follow_up_safe_options <= 1)
                    .unwrap_or(true) =>
            (
                "corridor_fragile",
                "区域走廊脆弱",
                format!(
                    "{} 到下一段只剩很窄的安全承接。若不先补位，整条走廊会在第二跳处断开；更稳的做法是先用“巩固区域走廊”把中继线补强。",
                    current_label
                ),
                "区域走廊脆弱：先补位，再把整条线接完整。".to_string(),
            ),
            "frontline_strain"
                if preview
                    .as_ref()
                    .map(|candidate| candidate.follow_up_safe_options == 0)
                    .unwrap_or(true) =>
            (
                "corridor_fragile",
                "区域走廊脆弱",
                format!(
                    "{} 现在更像裸前线而不是稳定走廊。若还要继续向{}推进，先把这一段补成可持续中继再说。",
                    current_label, objective_label
                ),
                "区域走廊脆弱：别把裸前线当成长线中继。".to_string(),
            ),
            _ if active_depot_here || active_line_bonus => {
                let mut active_parts: Vec<String> = Vec::new();
                if active_line_bonus {
                    active_parts.push(format!("运输线加成还剩 {} 天", self.supply_line_bonus_days));
                }
                if active_depot_here {
                    active_parts.push(format!("当前驻地容量加成还剩 {} 天", self.forward_depot_days));
                }
                (
                    "corridor_stabilizing",
                    "区域走廊稳固中",
                    format!(
                        "{} 这段区域走廊正在被稳住：{}。窗口还在时，应把下一跳和中继一起接完整。",
                        current_label,
                        active_parts.join("，")
                    ),
                    "区域走廊稳固中：趁窗口把下一跳和中继一起接上。".to_string(),
                )
            }
            _ if hub_distance <= 1
                && capacity >= 6
                && preview
                    .as_ref()
                    .map(|candidate| candidate.follow_up_safe_options >= 2)
                    .unwrap_or(false) =>
            (
                "corridor_secure",
                "区域走廊可持续",
                format!(
                    "{} 周边还有多条稳妥承接线，最近枢纽也足够近。这段区域暂时可持续，适合把补给窗口换成位置优势。",
                    current_label
                ),
                "区域走廊可持续：可以把补给窗口换成位置优势。".to_string(),
            ),
            _ => (
                "corridor_contested",
                "区域走廊未站稳",
                format!(
                    "{} 这段线路还能走，但缓冲并不宽。若要继续靠近{}，最好先补强当前中继，再把第二跳接稳。",
                    current_label, objective_label
                ),
                "区域走廊未站稳：先补强中继，再继续北上。".to_string(),
            ),
        };

        RegionalPressure {
            id: id.to_string(),
            label: label.to_string(),
            title,
            detail,
            short,
        }
    }

    fn regional_task_for(
        &self,
        location: &str,
        posture_id: &str,
        objective_id: &str,
        objective_label: &str,
        objective_target_role: &str,
        regional_pressure: &RegionalPressure,
    ) -> RegionalTask {
        let plan = self.regional_task_plan_for(
            location,
            posture_id,
            objective_id,
            objective_label,
            objective_target_role,
            regional_pressure,
        );
        let current_progress = if self.regional_task_id == plan.id {
            self.regional_task_progress.min(plan.progress_target)
        } else {
            0
        };
        let completed = self.regional_task_id == plan.id && self.regional_task_completed;
        let progress_label = if completed {
            format!(
                "任务进度：已完成（{}/{}），等待阶段目标切换。",
                plan.progress_target, plan.progress_target
            )
        } else if plan.condition_met {
            format!(
                "任务进度：{}/{}。{}",
                current_progress, plan.progress_target, plan.completion_note
            )
        } else {
            format!(
                "任务进度：{}/{}。{}",
                current_progress, plan.progress_target, plan.reset_note
            )
        };
        let detail = format!("{}\n{}\n{}", plan.detail, progress_label, plan.reward_label);

        RegionalTask {
            id: plan.id.to_string(),
            label: plan.label.to_string(),
            title: plan.title,
            detail,
            short: if completed {
                format!("{} 已完成，等待下一阶段切换。", plan.label)
            } else {
                plan.short
            },
            progress_label,
            reward_label: plan.reward_label,
        }
    }

    fn regional_task_plan_for(
        &self,
        location: &str,
        posture_id: &str,
        objective_id: &str,
        objective_label: &str,
        objective_target_role: &str,
        regional_pressure: &RegionalPressure,
    ) -> RegionalTaskPlan {
        let location_name = self.map_graph.node_name(location);
        let current_role = self.map_graph.supply_role_of(location);
        let current_role_label = self.map_graph.supply_role_label_of(location);
        let current_role_tier = Self::supply_role_tier(current_role);
        let objective_tier = Self::supply_role_tier(objective_target_role);
        let active_depot_here =
            self.forward_depot_days > 0 && self.forward_depot_location == location;
        let corridor_stable = matches!(
            regional_pressure.id.as_str(),
            "corridor_stabilizing" | "corridor_secure"
        );

        if self.day >= 61 || objective_target_role == "frontline_outpost" {
            let condition_met = current_role_tier >= 2
                && self.army.supply >= 68.0
                && self.army.avg_fatigue <= 35.0
                && corridor_stable;
            return RegionalTaskPlan {
                id: "stage_decisive_push",
                label: "区域任务：准备终盘突击",
                title: "区域任务".to_string(),
                detail: format!(
                    "终盘前推之前，先把 {} 站成真正的出击位：补给至少 68、疲劳不高于 35，且当前走廊要保持稳固。这样最后几步才不是拿库存硬赌。",
                    location_name
                ),
                short: "区域任务：先把终盘出击位站稳，再压最后一段。".to_string(),
                progress_target: 2,
                reward_label: "完成奖励：士气 +6，军方支持 +3。".to_string(),
                condition_met,
                completion_note: "当前已经达到终盘前推条件；再稳住一天就能把突击奖励拿到手。"
                    .to_string(),
                reset_note:
                    "终盘前推前要先把库存、疲劳和走廊都压回安全线。".to_string(),
            };
        }

        if matches!(
            posture_id,
            "critical_recovery" | "overextended_line" | "frontline_strain"
        ) || matches!(
            regional_pressure.id.as_str(),
            "corridor_breaking" | "corridor_fragile" | "corridor_contested"
        ) {
            let condition_met =
                corridor_stable || self.supply_line_bonus_days > 0 || active_depot_here;
            return RegionalTaskPlan {
                id: "stabilize_regional_corridor",
                label: "区域任务：稳住区域走廊",
                title: "区域任务".to_string(),
                detail: format!(
                    "{} 这一段线还不算真正站稳。只打一张补给牌不够，得连续两天把走廊维持在“稳固中 / 可持续”状态，才算把区域运营链条补起来。",
                    location_name
                ),
                short: "区域任务：连续两天把当前走廊稳住。".to_string(),
                progress_target: 2,
                reward_label: "完成奖励：补给线效率 +12%（2天）。".to_string(),
                condition_met,
                completion_note: "当前状态已算稳住一天；还得再连续维持一天，走廊才真正成型。"
                    .to_string(),
                reset_note: "只打一张牌不够，必须连续两天把这段走廊维持住。".to_string(),
            };
        }

        if objective_tier >= 2
            && current_role_tier < objective_tier
            && matches!(
                objective_id,
                "secure_regional_depot"
                    | "connect_strategic_depot"
                    | "recover_at_regional_depot"
                    | "repair_depot_chain"
            )
        {
            let condition_met = current_role_tier >= objective_tier && self.army.supply >= 45.0;
            return RegionalTaskPlan {
                id: "capture_operational_anchor",
                label: "区域任务：抢占整补锚点",
                title: "区域任务".to_string(),
                detail: format!(
                    "当前阶段还没把路线真正接到 {}。先落到目标仓储层级，把这段推进锚在可回补的位置，再谈后面的两三步。",
                    objective_label
                ),
                short: format!("区域任务：先把路线接到 {}。", objective_label),
                progress_target: 1,
                reward_label: "完成奖励：补给 +6，疲劳 -5。".to_string(),
                condition_met,
                completion_note: format!("当前已经把路线接到 {}。", objective_label),
                reset_note: format!("当前还没真正站上 {}。", objective_label),
            };
        }

        RegionalTaskPlan {
            id: "build_jump_off_point",
            label: "区域任务：搭好前推跳板",
            title: "区域任务".to_string(),
            detail: format!(
                "{} 当前属于{}。接下来不是盲目前推，而是连续两天把这里站成稳定跳板：库存至少 60、疲劳不高于 45，确保下一段推进有余量可用。",
                location_name, current_role_label
            ),
            short: "区域任务：连续两天把当前节点站成稳定跳板。".to_string(),
            progress_target: 2,
            reward_label: "完成奖励：补给 +4，士气 +4。".to_string(),
            condition_met: current_role_tier >= 2
                && self.army.supply >= 60.0
                && self.army.avg_fatigue <= 45.0,
            completion_note: "当前跳板条件已经满足；再稳住一天，就能换到下一段运营余量。".to_string(),
            reset_note: format!(
                "当前还没把 {} 站成可持续跳板，补给或疲劳还不够稳。",
                current_role_label
            ),
        }
    }

    fn best_adjacent_target_for_objective(
        &self,
        location: &str,
        objective_target_role: &str,
    ) -> Option<MarchTargetAdvice> {
        let current = self.current_march_army_state();
        let objective_tier = Self::supply_role_tier(objective_target_role);
        let mut best_target: Option<MarchTargetAdvice> = None;

        for neighbor in self.map_graph.neighbors_of(location) {
            let Some(step) = self.project_march_step(&current, &neighbor) else {
                continue;
            };
            let target_role = self.map_graph.supply_role_of(&step.target_node);
            let target_tier = Self::supply_role_tier(target_role);
            let runway_score = if step.supply_runway_days < 0 {
                18
            } else {
                step.supply_runway_days.min(5) * 4
            };
            let role_score = Self::objective_alignment_score(target_tier, objective_tier);
            let safety_score = if step.projected_supply >= SUPPLY_OK_THRESHOLD {
                24
            } else {
                -40
            };
            let score = role_score
                + runway_score
                + safety_score
                + step.supply_capacity as i32
                + step.supply_delta.round() as i32;

            let advice = MarchTargetAdvice {
                target_node: step.target_node.clone(),
                target_label: self.map_graph.node_name(&step.target_node),
                projected_supply: step.projected_supply,
                supply_capacity: step.supply_capacity,
                score,
            };

            let is_better = best_target
                .as_ref()
                .map(|best| {
                    advice.score > best.score
                        || (advice.score == best.score
                            && advice.projected_supply > best.projected_supply)
                        || (advice.score == best.score
                            && (advice.projected_supply - best.projected_supply).abs() < 0.1
                            && advice.supply_capacity > best.supply_capacity)
                })
                .unwrap_or(true);
            if is_better {
                best_target = Some(advice);
            }
        }

        best_target
    }

    fn supply_role_tier(role: &str) -> i32 {
        match role {
            "frontline_outpost" => 0,
            "transit_stop" => 1,
            "regional_depot" => 2,
            "strategic_depot" => 3,
            _ => 0,
        }
    }

    fn objective_alignment_score(target_tier: i32, objective_tier: i32) -> i32 {
        if objective_tier <= 0 {
            return if target_tier == 0 {
                42
            } else {
                16 - target_tier * 4
            };
        }
        if target_tier >= objective_tier {
            52 + (target_tier - objective_tier) * 6
        } else {
            12 + target_tier * 14
        }
    }

    fn policy_recommendation(
        &self,
        action_id: &'static str,
        action_label: &'static str,
        reason: impl Into<String>,
        short: impl Into<String>,
    ) -> ActionRecommendation {
        let mut action_reason = reason.into();
        if let Some(days) = self.politics.cooldowns().get(action_id).copied() {
            action_reason.push_str(&format!(
                " 但这张牌当前还在冷却 {} 天，若眼下就要处理，先按备选方案执行。",
                days
            ));
        }
        ActionRecommendation {
            action_id,
            action_label: action_label.to_string(),
            action_reason,
            action_short: short.into(),
            target_node: String::new(),
            target_label: String::new(),
        }
    }

    fn rest_recommendation(
        &self,
        reason: impl Into<String>,
        short: impl Into<String>,
    ) -> ActionRecommendation {
        ActionRecommendation {
            action_id: "rest",
            action_label: "休整".to_string(),
            action_reason: reason.into(),
            action_short: short.into(),
            target_node: String::new(),
            target_label: String::new(),
        }
    }

    fn march_recommendation(
        &self,
        target: &MarchTargetAdvice,
        reason: impl Into<String>,
        short: impl Into<String>,
    ) -> ActionRecommendation {
        ActionRecommendation {
            action_id: "march",
            action_label: format!("行军到 {}", target.target_label),
            action_reason: reason.into(),
            action_short: short.into(),
            target_node: target.target_node.clone(),
            target_label: target.target_label.clone(),
        }
    }

    fn is_safe_follow_up(step: &MarchStepProjection) -> bool {
        step.projected_supply >= SUPPLY_OK_THRESHOLD
            && step.supply_delta > -8.0
            && (step.supply_runway_days < 0 || step.supply_runway_days >= 2)
    }

    fn runway_score(days: i32) -> i32 {
        if days < 0 {
            99
        } else {
            days
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

    /// 从外部恢复已触发事件列表（主要用于测试或状态同步）
    pub fn restore_triggered_events(&mut self, ids: Vec<String>) {
        let migrated = migrate_triggered_event_ids(ids);
        self.triggered_event_ids = migrated.clone();
        self.event_pool.restore_triggered(migrated);
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
            version: 4,
            day: self.day,
            day_started: self.day_started,
            legitimacy: self.politics.legitimacy,
            rouge_noir: self.politics.rouge_noir_index,
            factions: self.politics.faction_support.clone(),
            actions_remaining: self.politics.actions_remaining as u32,
            decision_actions_start: self.decision_actions_start as u32,
            maneuver_used: self.maneuver_used,
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
            supply_line_bonus: self.supply_line_bonus,
            supply_line_bonus_days: self.supply_line_bonus_days,
            forward_depot_location: self.forward_depot_location.clone(),
            forward_depot_capacity_bonus: self.forward_depot_capacity_bonus,
            forward_depot_days: self.forward_depot_days,
            regional_task_id: self.regional_task_id.clone(),
            regional_task_progress: self.regional_task_progress,
            regional_task_completed: self.regional_task_completed,
            loyalty: self.characters.loyalty.clone(),
            relationships,
            triggered_event_ids: self.triggered_event_ids.clone(),
            outcome: self.outcome.map(|o| o.as_str().to_string()),
            difficulty: self.difficulty.as_str().to_string(),
            diplomatic_progress: self.diplomatic_progress,
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
        engine.day_started = state.day_started;
        engine.politics.legitimacy = state.legitimacy;
        engine.politics.rouge_noir_index = state.rouge_noir;
        engine.politics.faction_support = state.factions;
        engine.politics.actions_remaining = state.actions_remaining as u8;
        engine.decision_actions_start = state.decision_actions_start as u8;
        engine.maneuver_used = state.maneuver_used;
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
        engine.supply_line_bonus = state.supply_line_bonus;
        engine.supply_line_bonus_days = state.supply_line_bonus_days;
        engine.forward_depot_location = state.forward_depot_location;
        engine.forward_depot_capacity_bonus = state.forward_depot_capacity_bonus;
        engine.forward_depot_days = state.forward_depot_days;
        engine.regional_task_id = state.regional_task_id;
        engine.regional_task_progress = state.regional_task_progress;
        engine.regional_task_completed = state.regional_task_completed;
        engine.characters.loyalty = state.loyalty;
        engine.characters.relationships = state
            .relationships
            .into_iter()
            .map(|(a, b, v)| ((a, b), v))
            .collect();
        // 事件 ID 的兼容迁移必须先于事件池 restore；否则旧存档会把废弃 ID 重新标记为已触发。
        let migrated_triggered_event_ids = migrate_triggered_event_ids(state.triggered_event_ids);
        engine.triggered_event_ids = migrated_triggered_event_ids.clone();
        engine
            .event_pool
            .restore_triggered(migrated_triggered_event_ids);
        engine.difficulty = Difficulty::from_str(&state.difficulty);
        engine.diplomatic_progress = state.diplomatic_progress;
        engine.outcome = state.outcome.as_deref().and_then(|s| match s {
            "napoleon_victory" => Some(GameOutcome::NapoleonVictory),
            "diplomatic_settlement" => Some(GameOutcome::DiplomaticSettlement),
            "military_dominance" => Some(GameOutcome::MilitaryDominance),
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

    /// 开始新的一天，只执行 Dawn 历史事件与日内预算初始化。
    pub fn begin_day<R: Rng>(&mut self, rng: &mut R) {
        if self.is_over() {
            return;
        }
        if self.day_started {
            self.phase = TurnPhase::Action;
            return;
        }

        self.phase = TurnPhase::Dawn;
        self.last_action_events.clear();
        self.last_triggered_events.clear();
        self.last_report = None;

        let ctx = self.build_trigger_ctx();
        let triggered = self.event_pool.trigger_all(&ctx, rng);
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

        self.day_started = true;
        self.maneuver_used = false;
        self.decision_actions_start = self.politics.actions_remaining;
        self.phase = TurnPhase::Action;
    }

    /// 在同一天内执行一次玩家动作，不推进日期，也不做 Dusk 结算。
    pub fn execute_day_action<R: Rng>(&mut self, action: PlayerAction, rng: &mut R) {
        if self.is_over() {
            return;
        }
        if !self.day_started {
            self.begin_day(rng);
        }

        let uses_maneuver_slot = matches!(
            action,
            PlayerAction::LaunchBattle { .. } | PlayerAction::March { .. } | PlayerAction::Rest
        );
        if uses_maneuver_slot && self.maneuver_used {
            let (event_type, description) = match action {
                PlayerAction::LaunchBattle { .. } => {
                    ("battle_failed", "今日机动已用完，不能再发动第二次战役。")
                }
                PlayerAction::March { .. } => {
                    ("march_failed", "今日机动已用完，不能再执行第二次行军。")
                }
                PlayerAction::Rest => ("rest_failed", "今日机动已用完，不能再额外休整。"),
                _ => ("action_failed", "今日机动已用完。"),
            };
            let events = vec![DayEvent {
                day: self.day,
                event_type,
                description: description.to_string(),
                effects: vec!["今日已执行过一次行军 / 战役 / 休整。".to_string()],
            }];
            self.last_action_events = events.clone();
            for event in events {
                self.history.push(event);
            }
            return;
        }

        self.phase = TurnPhase::Action;
        let (base_key, is_battle) = narrative_key_for_action(&action);
        let victories_before = self.army.victories;
        let defeats_before = self.army.defeats;
        let events = self.execute_action(action, rng);
        if uses_maneuver_slot {
            self.maneuver_used = true;
        }
        self.last_action_events = events.clone();
        for event in events {
            self.history.push(event);
        }

        let narrative_key = if is_battle {
            if self.army.victories > victories_before {
                "battle_victory"
            } else if self.army.defeats > defeats_before {
                "battle_defeat"
            } else {
                ""
            }
        } else {
            base_key
        };
        self.last_report = Some(self.build_day_report(narrative_key, rng));
    }

    /// 结束当前一天：若机动槽未用则自动视为休整，再做 Dusk 结算并推进日期。
    pub fn end_day<R: Rng>(&mut self, rng: &mut R) {
        if self.is_over() {
            return;
        }
        if !self.day_started {
            self.begin_day(rng);
        }

        self.phase = TurnPhase::Dusk;
        let mut closing_events = Vec::new();
        if !self.maneuver_used {
            closing_events.extend(self.execute_action(PlayerAction::Rest, rng));
            self.maneuver_used = true;
            self.last_report = Some(self.build_day_report("rest", rng));
        }
        closing_events.extend(self.dusk_settlement(rng));
        self.last_action_events = closing_events.clone();
        for event in closing_events {
            self.history.push(event);
        }

        self.day += 1;
        self.day_started = false;
        self.maneuver_used = false;
        self.decision_actions_start = 0;
        self.phase = TurnPhase::Dawn;
        self.check_outcome();
    }

    /// 兼容旧接口：一口气跑完 Dawn → 单次动作 → Dusk。
    pub fn process_day<R: Rng>(&mut self, action: PlayerAction, rng: &mut R) {
        if self.is_over() {
            return;
        }
        self.begin_day(rng);
        self.execute_day_action(action, rng);
        let action_events = self.last_action_events.clone();
        let action_report = self.last_report.clone();
        self.end_day(rng);
        let mut combined_events = action_events;
        combined_events.extend(self.last_action_events.clone());
        self.last_action_events = combined_events;
        if let Some(report) = action_report {
            self.last_report = Some(report);
        }
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
                    if policy.supply_line_bonus_days > 0 && policy.supply_line_bonus.abs() > 0.01 {
                        self.supply_line_bonus =
                            self.supply_line_bonus.max(policy.supply_line_bonus);
                        self.supply_line_bonus_days = self
                            .supply_line_bonus_days
                            .max(policy.supply_line_bonus_days);
                    }
                    if policy.local_supply_capacity_bonus_days > 0
                        && policy.local_supply_capacity_bonus > 0
                    {
                        if self.forward_depot_location == self.napoleon_location {
                            self.forward_depot_capacity_bonus = self
                                .forward_depot_capacity_bonus
                                .max(policy.local_supply_capacity_bonus);
                            self.forward_depot_days = self
                                .forward_depot_days
                                .max(policy.local_supply_capacity_bonus_days);
                        } else {
                            self.forward_depot_location = self.napoleon_location.clone();
                            self.forward_depot_capacity_bonus = policy.local_supply_capacity_bonus;
                            self.forward_depot_days = policy.local_supply_capacity_bonus_days;
                        }
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
        if policy.supply_line_bonus_days > 0 && policy.supply_line_bonus.abs() > 0.01 {
            effects.push(format!(
                "补给线效率 +{:.0}%（{} 天）",
                policy.supply_line_bonus * 100.0,
                policy.supply_line_bonus_days
            ));
        }
        if policy.local_supply_capacity_bonus_days > 0 && policy.local_supply_capacity_bonus > 0 {
            effects.push(format!(
                "当前驻地容量 +{}（{} 天）",
                policy.local_supply_capacity_bonus, policy.local_supply_capacity_bonus_days
            ));
        }
        if policy.cooldown_days > 0 {
            effects.push(format!("进入冷却 {} 天", policy.cooldown_days));
        }
        effects
    }

    /// 强化忠诚度处理（消耗合法性）
    fn process_boost_loyalty(&mut self, general_id: &str) -> Vec<DayEvent> {
        let general_name = self.characters.display_name(general_id);
        if self.politics.actions_remaining == 0 {
            return vec![DayEvent {
                day: self.day,
                event_type: "boost_failed",
                description: format!("今日决策点已用完，无法再接见 {}", general_name),
                effects: vec!["需要保留至少 1 点决策点。".to_string()],
            }];
        }
        if self.politics.legitimacy < 10.0 {
            return vec![DayEvent {
                day: self.day,
                event_type: "boost_failed",
                description: format!("合法性不足，无法安抚 {}", general_name),
                effects: vec![],
            }];
        }
        self.politics.actions_remaining = self.politics.actions_remaining.saturating_sub(1);
        self.politics.legitimacy -= 5.0;
        self.characters
            .modify_loyalty(general_id, 8.0, self.day, "personal_attention");

        vec![DayEvent {
            day: self.day,
            event_type: "boost_loyalty",
            description: format!("亲自接见 {}，试图稳住军心", general_name),
            effects: vec![
                "行动点 -1".to_string(),
                "合法性 -5.0".to_string(),
                format!("{} 忠诚 +8.0", general_name),
            ],
        }]
    }

    /// Dusk结算：政治每日tick、关系衰减、叛逃检查、连锁效果
    fn dusk_settlement<R: Rng>(&mut self, rng: &mut R) -> Vec<DayEvent> {
        let mut dusk_events = Vec::new();
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
        if self.supply_line_bonus_days > 0 {
            self.supply_line_bonus_days = self.supply_line_bonus_days.saturating_sub(1);
            if self.supply_line_bonus_days == 0 {
                self.supply_line_bonus = 0.0;
            }
        }
        if self.forward_depot_days > 0 {
            self.forward_depot_days = self.forward_depot_days.saturating_sub(1);
            if self.forward_depot_days == 0 {
                self.forward_depot_capacity_bonus = 0;
                self.forward_depot_location.clear();
            }
        }
        dusk_events.extend(self.resolve_regional_task_progress());

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

        dusk_events
    }

    fn resolve_regional_task_progress(&mut self) -> Vec<DayEvent> {
        let location = self.napoleon_location.clone();
        let supply = self.army.supply;
        let fatigue = self.army.avg_fatigue;
        let capacity_bonus = self.forward_depot_capacity_bonus_for(&location);
        let capacity = self.effective_supply_capacity_for(&location);
        let (_, hub_distance) = self.nearest_supply_hub(&location);
        let (posture_id, _) = self.logistics_posture_for(
            &location,
            supply,
            fatigue,
            capacity,
            capacity_bonus,
            hub_distance,
        );
        let (
            objective_id,
            objective_label,
            objective_target_role,
            _objective_detail,
            _objective_short,
        ) = self.operational_objective_for(
            &location,
            posture_id,
            supply,
            fatigue,
            capacity,
            hub_distance,
        );
        let (primary_action, _secondary_action) = self.logistics_action_plan_for(
            &location,
            posture_id,
            objective_target_role,
            supply,
            fatigue,
            capacity,
            hub_distance,
        );
        let regional_pressure = self.logistics_regional_pressure_for(
            &location,
            posture_id,
            objective_target_role,
            &primary_action,
        );
        let plan = self.regional_task_plan_for(
            &location,
            posture_id,
            objective_id,
            objective_label,
            objective_target_role,
            &regional_pressure,
        );
        let mut events = Vec::new();

        if self.regional_task_id != plan.id {
            self.regional_task_id = plan.id.to_string();
            self.regional_task_progress = 0;
            self.regional_task_completed = false;
        }

        if self.regional_task_completed {
            return events;
        }

        if plan.condition_met {
            if self.regional_task_progress < plan.progress_target {
                self.regional_task_progress = self.regional_task_progress.saturating_add(1);
            }

            if self.regional_task_progress >= plan.progress_target {
                self.regional_task_progress = plan.progress_target;
                self.regional_task_completed = true;
                let reward_effects = self.apply_regional_task_reward(plan.id);
                let mut effects = vec![
                    format!("任务进度 {}/{}", plan.progress_target, plan.progress_target),
                    plan.completion_note.clone(),
                ];
                effects.extend(reward_effects);
                events.push(DayEvent {
                    day: self.day,
                    event_type: "regional_task_reward",
                    description: format!("区域任务完成：{}", plan.label),
                    effects,
                });
            } else {
                events.push(DayEvent {
                    day: self.day,
                    event_type: "regional_task",
                    description: format!("区域任务推进：{}", plan.label),
                    effects: vec![
                        format!(
                            "任务进度 {}/{}",
                            self.regional_task_progress, plan.progress_target
                        ),
                        plan.completion_note.clone(),
                        plan.reward_label.clone(),
                    ],
                });
            }
        } else if self.regional_task_progress > 0 {
            self.regional_task_progress = 0;
            events.push(DayEvent {
                day: self.day,
                event_type: "regional_task_setback",
                description: format!("区域任务中断：{}", plan.label),
                effects: vec!["任务进度归零".to_string(), plan.reset_note.clone()],
            });
        }

        events
    }

    fn apply_regional_task_reward(&mut self, task_id: &str) -> Vec<String> {
        match task_id {
            "capture_operational_anchor" => {
                self.army.supply = (self.army.supply + 6.0).min(100.0);
                self.army.avg_fatigue = (self.army.avg_fatigue - 5.0).max(0.0);
                vec!["补给 +6".to_string(), "疲劳 -5".to_string()]
            }
            "stabilize_regional_corridor" => {
                self.supply_line_bonus = self.supply_line_bonus.max(0.12);
                self.supply_line_bonus_days = self.supply_line_bonus_days.max(2);
                vec![
                    "补给线效率 +12%".to_string(),
                    "补给线窗口延长 2 天".to_string(),
                ]
            }
            "stage_decisive_push" => {
                self.army.avg_morale = (self.army.avg_morale + 6.0).min(100.0);
                self.politics.modify_faction("military", 3.0);
                vec!["士气 +6".to_string(), "军方支持 +3".to_string()]
            }
            "build_jump_off_point" => {
                self.army.supply = (self.army.supply + 4.0).min(100.0);
                self.army.avg_morale = (self.army.avg_morale + 4.0).min(100.0);
                vec!["补给 +4".to_string(), "士气 +4".to_string()]
            }
            _ => Vec::new(),
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
    ///
    /// 判定顺序：
    /// 1. 即时失败（政治崩溃、军事覆灭）
    /// 2. 提前胜利（外交解决）
    /// 3. 百日终局（军事碾压 → 均衡胜利 → 惜败 → 惨败）
    fn check_outcome(&mut self) {
        // 政治崩溃（即时）
        if self.politics.is_collapsed() {
            self.outcome = Some(GameOutcome::PoliticalCollapse);
            return;
        }
        // 军事覆灭（即时）
        if self.army.total_troops < 5_000 {
            self.outcome = Some(GameOutcome::MilitaryAnnihilation);
            return;
        }
        // 外交解决（Day 60+ 可提前结束，需高合法性 + 外交事件链完成）
        if self.day >= 60 && self.politics.legitimacy > 65.0 && self.diplomatic_progress >= 100 {
            self.outcome = Some(GameOutcome::DiplomaticSettlement);
            return;
        }
        // 百日终局
        if self.day > 100 {
            let legitimacy = self.politics.legitimacy;
            let victories = self.army.victories;
            self.outcome = Some(if legitimacy > 50.0 && victories >= 3 {
                // 均衡胜利：政治+军事双达标（最佳结局）
                GameOutcome::NapoleonVictory
            } else if victories >= 5 && legitimacy > 20.0 {
                // 军事碾压：低合法性但靠碾压胜利续命
                GameOutcome::MilitaryDominance
            } else if legitimacy > 30.0 {
                GameOutcome::WaterlooHistorical
            } else {
                GameOutcome::WaterlooDefeat
            });
        }
    }

    /// 推进外交进度（由外交事件链的 effects 调用）
    pub fn advance_diplomatic_progress(&mut self, amount: u32) {
        self.diplomatic_progress = (self.diplomatic_progress + amount).min(100);
    }

    /// 查询当前外交进度
    pub fn diplomatic_progress(&self) -> u32 {
        self.diplomatic_progress
    }

    // ── 叙事系统 ──────────────────────────────────────

    /// 根据行动类型和战斗结果构建当日叙事报告
    fn build_day_report<R: Rng>(&self, narrative_key: &str, rng: &mut R) -> DayReport {
        if narrative_key.is_empty() {
            return DayReport {
                day: self.day,
                bertrand: None,
                consequence: None,
            };
        }
        DayReport {
            day: self.day,
            bertrand: self.narratives.pick_bertrand(narrative_key, rng),
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
            legitimacy: self.politics.legitimacy,
            supply: self.army.supply,
            victories: self.army.victories,
            faction_support: self.politics.faction_support.clone(),
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
        if let Some(delta) = effects.diplomatic_progress_delta {
            self.advance_diplomatic_progress(delta);
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

    fn nearest_supply_hub(&self, location: &str) -> (String, u32) {
        const SUPPLY_HUBS: [&str; 6] = [
            "golfe_juan",
            "grenoble",
            "lyon",
            "paris",
            "lille",
            "maubeuge",
        ];

        SUPPLY_HUBS
            .iter()
            .filter_map(|hub| {
                let distance = self.map_graph.node_distance(location, hub);
                (distance != u32::MAX).then_some((self.map_graph.node_name(hub), distance))
            })
            .min_by_key(|(_, distance)| *distance)
            .unwrap_or_else(|| ("未知补给点".to_string(), u32::MAX))
    }

    fn forward_depot_capacity_bonus_for(&self, location: &str) -> u32 {
        if self.forward_depot_days > 0 && self.forward_depot_location == location {
            self.forward_depot_capacity_bonus
        } else {
            0
        }
    }

    fn effective_supply_capacity_for(&self, location: &str) -> u32 {
        self.map_graph.supply_capacity_of(location)
            + self.forward_depot_capacity_bonus_for(location)
    }

    fn supply_line_efficiency_for(&self, location: &str) -> f64 {
        let (_, nearest_distance) = self.nearest_supply_hub(location);

        let base = match nearest_distance {
            0 => 1.15,
            1 => 1.0,
            2 => 0.85,
            3 => 0.7,
            4 => 0.55,
            u32::MAX => 0.25,
            _ => 0.4,
        };
        let bonus = if self.supply_line_bonus_days > 0 {
            self.supply_line_bonus
        } else {
            0.0
        };
        (base + bonus).clamp(0.2, 1.2)
    }

    fn refresh_supply_after_action(&mut self, action_type: &'static str) -> DayEvent {
        let location_id = self.napoleon_location.clone();
        let supply_result = update_supply_with_capacity(
            &self.current_march_army_state(),
            self.supply_line_efficiency(),
            self.effective_supply_capacity_for(&location_id),
        );
        self.army.supply = supply_result.new_supply;

        let location_name = self.map_graph.node_name(&location_id);
        let base_capacity = self.map_graph.supply_capacity_of(&location_id);
        let capacity_bonus = self.forward_depot_capacity_bonus_for(&location_id);
        let capacity = base_capacity + capacity_bonus;
        let (hub_name, hub_distance) = self.nearest_supply_hub(&location_id);
        let role_label = self.map_graph.supply_role_label_of(&location_id);
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
        effects.push(format!("补给角色 {}", role_label));
        effects.push(format!("节点容量 {}", capacity));
        if capacity_bonus > 0 {
            effects.push(format!(
                "前沿粮秣站 +{}（剩余 {} 天）",
                capacity_bonus, self.forward_depot_days
            ));
        }
        if hub_distance != u32::MAX {
            effects.push(format!("最近补给枢纽 {}（{} 跳）", hub_name, hub_distance));
        }
        effects.push(Self::supply_guidance(
            action_type,
            capacity,
            capacity_bonus,
            role_label,
            hub_distance,
            supply_result.line_efficiency,
            supply_result.demand,
            supply_result.available,
            supply_result.supply_delta,
            supply_result.supply_ok,
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

    fn supply_guidance(
        action_type: &'static str,
        capacity: u32,
        capacity_bonus: u32,
        role_label: &str,
        hub_distance: u32,
        line_efficiency: f64,
        demand: f64,
        available: f64,
        supply_delta: f64,
        supply_ok: bool,
    ) -> String {
        if !supply_ok {
            if capacity <= 2 || line_efficiency < 0.55 {
                return "建议：这里更适合作为短暂停留点而非持续前推；优先回高容量节点整补，或立刻用补给政策止血。"
                    .to_string();
            }
            if capacity_bonus > 0 {
                return "建议：前沿粮秣站已经在支撑当前驻地，但库存仍跌进危险区；下一回合优先休整或征用仓储，不要继续硬顶。"
                    .to_string();
            }
            return "建议：当前补给已经跌到战斗惩罚区，下一回合优先休整或补给，不要继续硬顶。"
                .to_string();
        }

        if available + 0.5 < demand {
            return "建议：当前可得量低于部队需求，继续推进会越走越亏，先补再打。".to_string();
        }

        if action_type == "march" && supply_delta < 0.0 {
            return "建议：这一步主要是在用位置换补给，若没有决定性战机，下一回合先整补。"
                .to_string();
        }

        if capacity_bonus > 0 && capacity >= 6 {
            return "建议：这里已有前沿粮秣站，适合作为短期跳板；趁加成还在，把补给和疲劳拉回安全线再继续前推。"
                .to_string();
        }

        if supply_delta >= 4.0 && capacity >= 8 {
            return "建议：这里适合作为整补落点，可以先恢复补给和疲劳，再继续推进。".to_string();
        }

        if hub_distance >= 3 && role_label == "沿线转运点" {
            return "建议：这里是沿线转运点，离后方枢纽已经不算近；若准备连续推进，先考虑建立前沿粮秣站。"
                .to_string();
        }

        "建议：当前补给还能维持，但应提前看下一站仓储，避免连续走进低容量节点。".to_string()
    }

    fn logistics_posture_for(
        &self,
        location: &str,
        supply: f64,
        fatigue: f64,
        capacity: u32,
        capacity_bonus: u32,
        hub_distance: u32,
    ) -> (&'static str, &'static str) {
        if supply < 42.0 || fatigue >= 72.0 {
            return ("critical_recovery", "止血整补");
        }
        if capacity_bonus > 0 && capacity >= 6 {
            return ("forward_staging", "前沿整补跳板");
        }
        if self.map_graph.supply_role_of(location) == "frontline_outpost" || capacity <= 2 {
            return ("frontline_strain", "前线消耗区");
        }
        if hub_distance >= 3 && self.map_graph.supply_role_of(location) == "transit_stop" {
            return ("overextended_line", "运输线拉长");
        }
        if supply >= 65.0 && fatigue <= 35.0 {
            return ("advance_ready", "可继续推进");
        }
        ("staging_window", "整补筹备窗口")
    }

    fn campaign_focus_title(&self) -> &'static str {
        match self.day {
            0..=10 => "前10天目标：先建立北上跳板",
            11..=20 => "巴黎阶段目标：让回补线跟得上位置",
            21..=60 => "中盘目标：把推进放在可持续补给上",
            61..=85 => "决战前目标：保留补给余量和整补节点",
            _ => "终盘目标：只为决定性位置支付补给代价",
        }
    }

    fn operational_objective_for(
        &self,
        location: &str,
        posture_id: &str,
        supply: f64,
        fatigue: f64,
        capacity: u32,
        hub_distance: u32,
    ) -> (&'static str, &'static str, &'static str, String, String) {
        let location_name = self.map_graph.node_name(location);
        let current_role = self.map_graph.supply_role_of(location);

        match self.day {
            0..=10 if posture_id == "critical_recovery" || capacity <= 2 => (
                "secure_regional_depot",
                "阶段运营目标：先抢区域整补点",
                "regional_depot",
                format!(
                    "{} 还只是前线消耗点。下一段优先落到区域整补点或战略大仓，先把回补线接稳。",
                    location_name
                ),
                "下一段目标：先抢区域整补点，不要继续连走前线点。".to_string(),
            ),
            0..=10 => (
                "connect_strategic_depot",
                "阶段运营目标：把跳板接到战略大仓",
                "strategic_depot",
                format!(
                    "{} 已能做短暂停留，但还不算真正的大后方。下一段应尽量接上战略大仓，为北上留更厚的补给余量。",
                    location_name
                ),
                "下一段目标：把跳板接到战略大仓。".to_string(),
            ),
            11..=60 if posture_id == "overextended_line" || hub_distance >= 3 => (
                "repair_depot_chain",
                "阶段运营目标：补上线中继仓储",
                "regional_depot",
                format!(
                    "{} 离后方枢纽已经偏远。中盘不要只盯前线点，先把区域整补点串起来，再谈持续推进。",
                    location_name
                ),
                "阶段运营目标：先补上线中继仓储，再继续前推。".to_string(),
            ),
            11..=60 if supply < 55.0 || fatigue > 45.0 => (
                "recover_at_regional_depot",
                "阶段运营目标：回到区域整补点整补",
                "regional_depot",
                format!(
                    "当前补给 {:.0}、疲劳 {:.0}，还不适合继续透支前线。下一段优先找区域整补点恢复库存和体力。",
                    supply, fatigue
                ),
                "阶段运营目标：先回区域整补点整补。".to_string(),
            ),
            11..=85 => (
                "stage_from_regional_depot",
                "阶段运营目标：以区域整补点做跳板",
                "regional_depot",
                format!(
                    "{} 现在更适合当跳板，而不是终点。把区域整补点握在手里，才能把后续推进维持成可持续节奏。",
                    location_name
                ),
                "阶段运营目标：以区域整补点做跳板推进。".to_string(),
            ),
            _ if posture_id == "advance_ready" && supply >= 65.0 && fatigue <= 35.0 => (
                "pay_for_decisive_frontline",
                "阶段运营目标：只为决定性前线点付补给代价",
                "frontline_outpost",
                format!(
                    "{} 当前已具备前推条件。终盘只为真正决定性的前线点支付补给代价，不再为普通前沿消耗点透支库存。",
                    location_name
                ),
                "终盘目标：只为决定性前线点付补给代价。".to_string(),
            ),
            _ if current_role == "strategic_depot" => (
                "launch_from_strategic_depot",
                "阶段运营目标：从战略大仓发起最后一段推进",
                "regional_depot",
                format!(
                    "{} 已是战略大仓。终盘应从这里先接上区域整补点，再决定是否压向前线关键点。",
                    location_name
                ),
                "终盘目标：从战略大仓接区域整补点，再压前线。".to_string(),
            ),
            _ => (
                "reset_before_decisive_push",
                "阶段运营目标：先回区域整补点蓄力",
                "regional_depot",
                format!(
                    "{} 还不适合直接支付终盘前线代价。先回区域整补点蓄力，再决定最后几步怎么走。",
                    location_name
                ),
                "终盘目标：先回区域整补点蓄力。".to_string(),
            ),
        }
    }

    fn supply_runway_days_for(&self, location: &str, starting_supply: f64) -> Option<u32> {
        if starting_supply < SUPPLY_OK_THRESHOLD {
            return Some(0);
        }

        let line_efficiency = self.supply_line_efficiency_for(location);
        let capacity = self.effective_supply_capacity_for(location);
        let mut projected_supply = starting_supply;

        for day in 1..=7 {
            let result = update_supply_with_capacity(
                &MarchArmyState {
                    id: "napoleon_main_force".to_string(),
                    location: location.to_string(),
                    troops: self.army.total_troops,
                    morale: self.army.avg_morale,
                    fatigue: self.army.avg_fatigue,
                    supply: projected_supply,
                },
                line_efficiency,
                capacity,
            );

            if result.supply_delta >= 0.0 && result.new_supply >= projected_supply {
                return None;
            }

            projected_supply = result.new_supply;
            if projected_supply < SUPPLY_OK_THRESHOLD {
                return Some(day);
            }
        }

        Some(7)
    }

    fn supply_runway_label(days: Option<u32>) -> String {
        match days {
            None => "补给窗口：当前驻地可持续维持".to_string(),
            Some(0) => "补给窗口：已处于战斗惩罚区".to_string(),
            Some(1) => "补给窗口：再停 1 天就会跌进战斗惩罚区".to_string(),
            Some(day_count) => format!("补给窗口：约还能维持 {} 天", day_count),
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

// ── 单元测试（拆分到 state_tests.rs，硬约束 #10）──────

#[cfg(test)]
#[path = "state_tests.rs"]
mod tests;
