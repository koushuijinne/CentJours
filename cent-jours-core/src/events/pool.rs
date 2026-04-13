//! 历史事件池 — `events::pool`
//!
//! 从 JSON 加载事件定义，根据游戏状态触发，返回叙事文本和效果。
//! TDD：测试先于实现。

use rand::Rng;
use serde::Deserialize;
use std::collections::HashMap;

// ── 事件数据结构（与 JSON 对应）────────────────────────

/// 触发条件（所有字段均为可选，未填写的条件默认满足）
#[derive(Debug, Clone, Deserialize, Default)]
pub struct EventTrigger {
    pub napoleon_reputation_min: Option<f64>,
    pub ney_loyalty_min: Option<f64>,
    pub ney_napoleon_relationship_min: Option<f64>,
    pub grouchy_loyalty_min: Option<f64>,
    pub fouche_loyalty_max: Option<f64>,
    pub rouge_noir_index_max: Option<f64>,
    pub rouge_noir_index_min: Option<f64>,
    pub day_min: Option<u32>,
    pub coalition_not_defeated: Option<bool>,
    /// 合法性阈值
    pub legitimacy_min: Option<f64>,
    pub legitimacy_max: Option<f64>,
    /// 派系支持度下限：{ faction_id: min_support }
    #[serde(default)]
    pub faction_support_min: HashMap<String, f64>,
    /// 派系支持度上限：{ faction_id: max_support }
    #[serde(default)]
    pub faction_support_max: HashMap<String, f64>,
    /// 补给阈值
    pub supply_min: Option<f64>,
    pub supply_max: Option<f64>,
    /// 胜场阈值
    pub victories_min: Option<u32>,
    /// 通用将领忠诚度下限：{ character_id: min_loyalty }
    /// 替代原硬编码的 davout_loyalty_min 等字段，支持任意将领
    #[serde(default)]
    pub loyalty_min: HashMap<String, f64>,
    /// 通用将领忠诚度上限：{ character_id: max_loyalty }
    #[serde(default)]
    pub loyalty_max: HashMap<String, f64>,
}

/// 事件效果（数值变化）
#[derive(Debug, Clone, Deserialize, Default)]
pub struct EventEffects {
    /// 通用将领忠诚度变化：{ character_id: delta }
    /// 替代原硬编码的 ney_loyalty_delta / fouche_loyalty_delta
    #[serde(default)]
    pub loyalty_deltas: HashMap<String, f64>,
    pub military_support_delta: Option<f64>,
    pub nobility_support_delta: Option<f64>,
    pub populace_support_delta: Option<f64>,
    pub liberals_support_delta: Option<f64>,
    pub rouge_noir_delta: Option<f64>,
    pub legitimacy_delta: Option<f64>,
    pub paris_security_bonus: Option<f64>,
    pub political_stability_bonus: Option<f64>,
    pub military_available_troops_delta: Option<i64>,
    pub coalition_troops_bonus: Option<i32>,
    pub napoleon_morale_bonus: Option<f64>,
    /// 外交进度推进量（用于外交结局事件链）
    #[serde(default)]
    pub diplomatic_progress_delta: Option<u32>,
}

/// 事件级别（ADR-008 三级体系）
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum EventTier {
    /// 重大事件：3–5 段叙事，全屏演出
    Major,
    /// 普通事件：2–3 段叙事，侧边通知
    Normal,
    /// 微小事件：1–2 段叙事，日志滚动
    Minor,
}

impl Default for EventTier {
    /// 未标注级别的事件默认为 normal
    fn default() -> Self {
        Self::Normal
    }
}

impl EventTier {
    /// 导出稳定字符串值，供 GDExtension / UI 直接消费。
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Major => "major",
            Self::Normal => "normal",
            Self::Minor => "minor",
        }
    }
}

/// 单个历史事件定义
#[derive(Debug, Clone, Deserialize)]
pub struct HistoricalEvent {
    pub id: String,
    pub label: String,
    /// 事件级别（ADR-008），决定叙事段数和前端展示方式
    #[serde(default)]
    pub tier: EventTier,
    pub day_range: [u32; 2],
    pub trigger: EventTrigger,
    pub effects: EventEffects,
    pub narratives: Vec<String>,
    #[serde(default)]
    pub historical_note: String,
}

impl HistoricalEvent {
    /// 检查事件在当前游戏状态下是否满足触发条件
    pub fn can_trigger(&self, ctx: &TriggerContext) -> bool {
        let t = &self.trigger;

        // 日期范围检查
        if ctx.day < self.day_range[0] || ctx.day > self.day_range[1] {
            return false;
        }

        // 数值条件检查（None = 无此条件，默认满足）
        if let Some(min) = t.napoleon_reputation_min {
            if ctx.napoleon_reputation < min {
                return false;
            }
        }
        if let Some(min) = t.ney_loyalty_min {
            if ctx.ney_loyalty < min {
                return false;
            }
        }
        if let Some(min) = t.ney_napoleon_relationship_min {
            if ctx.ney_napoleon_relationship < min {
                return false;
            }
        }
        if let Some(min) = t.grouchy_loyalty_min {
            if ctx.grouchy_loyalty < min {
                return false;
            }
        }
        if let Some(max) = t.fouche_loyalty_max {
            if ctx.fouche_loyalty > max {
                return false;
            }
        }
        if let Some(max) = t.rouge_noir_index_max {
            if ctx.rouge_noir_index > max {
                return false;
            }
        }
        if let Some(min) = t.day_min {
            if ctx.day < min {
                return false;
            }
        }
        // 反法同盟状态条件
        if let Some(not_defeated) = t.coalition_not_defeated {
            if not_defeated && ctx.coalition_defeated {
                return false;
            }
        }
        // 红黑指数下限
        if let Some(min) = t.rouge_noir_index_min {
            if ctx.rouge_noir_index < min {
                return false;
            }
        }
        // 合法性条件
        if let Some(min) = t.legitimacy_min {
            if ctx.legitimacy < min {
                return false;
            }
        }
        if let Some(max) = t.legitimacy_max {
            if ctx.legitimacy > max {
                return false;
            }
        }
        // 补给条件
        if let Some(min) = t.supply_min {
            if ctx.supply < min {
                return false;
            }
        }
        if let Some(max) = t.supply_max {
            if ctx.supply > max {
                return false;
            }
        }
        // 胜场条件
        if let Some(min) = t.victories_min {
            if ctx.victories < min {
                return false;
            }
        }
        // 派系支持度条件
        for (id, &min) in &t.faction_support_min {
            if ctx.faction_support.get(id.as_str()).copied().unwrap_or(0.0) < min {
                return false;
            }
        }
        for (id, &max) in &t.faction_support_max {
            if ctx
                .faction_support
                .get(id.as_str())
                .copied()
                .unwrap_or(100.0)
                > max
            {
                return false;
            }
        }
        // 通用将领忠诚度条件（loyalty_min / loyalty_max）
        for (id, &min) in &t.loyalty_min {
            if ctx.loyalty_map.get(id.as_str()).copied().unwrap_or(0.0) < min {
                return false;
            }
        }
        for (id, &max) in &t.loyalty_max {
            if ctx.loyalty_map.get(id.as_str()).copied().unwrap_or(100.0) > max {
                return false;
            }
        }

        true
    }

    /// 从叙事文本池中随机选取一段
    pub fn pick_narrative<R: Rng>(&self, rng: &mut R) -> Option<&str> {
        if self.narratives.is_empty() {
            return None;
        }
        let idx = rng.gen_range(0..self.narratives.len());
        Some(&self.narratives[idx])
    }
}

// ── 触发上下文（游戏状态快照）────────────────────────

/// 事件触发时传入的游戏状态快照
#[derive(Debug, Clone, Default)]
pub struct TriggerContext {
    pub day: u32,
    pub napoleon_reputation: f64,
    pub ney_loyalty: f64,
    pub ney_napoleon_relationship: f64,
    pub grouchy_loyalty: f64,
    pub fouche_loyalty: f64,
    pub rouge_noir_index: f64,
    pub legitimacy: f64,
    pub supply: f64,
    pub victories: u32,
    /// 派系支持度快照：{ faction_id: support }
    pub faction_support: HashMap<String, f64>,
    /// 所有将领忠诚度快照（供 loyalty_min / loyalty_max 通用条件检查）
    /// key = character_id，与 characters.json 一致
    pub loyalty_map: HashMap<String, f64>,
    /// 反法同盟是否已被击败（对应 GameOutcome::NapoleonVictory）
    /// Default = false（游戏进行中，联军尚未被击败）
    pub coalition_defeated: bool,
}

// ── 事件池 ────────────────────────────────────────────

/// 已触发事件的记录（防止同一事件重复触发）
pub struct EventPool {
    events: Vec<HistoricalEvent>,
    triggered_ids: std::collections::HashSet<String>,
}

impl EventPool {
    /// 从 JSON 字符串构建事件池
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        let events: Vec<HistoricalEvent> = serde_json::from_str(json)?;
        Ok(Self {
            events,
            triggered_ids: Default::default(),
        })
    }

    /// 创建空事件池（用于测试）
    pub fn empty() -> Self {
        Self {
            events: Vec::new(),
            triggered_ids: Default::default(),
        }
    }

    /// 查询当前可触发的事件列表（不改变状态）
    pub fn available_events(&self, ctx: &TriggerContext) -> Vec<&HistoricalEvent> {
        self.events
            .iter()
            .filter(|e| !self.triggered_ids.contains(&e.id) && e.can_trigger(ctx))
            .collect()
    }

    /// 触发所有满足条件的事件，返回触发结果列表
    pub fn trigger_all<R: Rng>(
        &mut self,
        ctx: &TriggerContext,
        rng: &mut R,
    ) -> Vec<TriggeredEvent> {
        let to_trigger: Vec<String> = self
            .events
            .iter()
            .filter(|e| !self.triggered_ids.contains(&e.id) && e.can_trigger(ctx))
            .map(|e| e.id.clone())
            .collect();

        let mut results = Vec::new();
        for id in to_trigger {
            self.triggered_ids.insert(id.clone());
            if let Some(event) = self.events.iter().find(|e| e.id == id) {
                let narrative = event.pick_narrative(rng).unwrap_or("").to_string();
                results.push(TriggeredEvent {
                    id: event.id.clone(),
                    label: event.label.clone(),
                    tier: event.tier.clone(),
                    narrative,
                    historical_note: event.historical_note.clone(),
                    effects: event.effects.clone(),
                });
            }
        }
        results
    }

    /// 查询事件总数
    pub fn len(&self) -> usize {
        self.events.len()
    }

    /// 是否已触发指定事件
    pub fn is_triggered(&self, id: &str) -> bool {
        self.triggered_ids.contains(id)
    }

    /// 从存档恢复已触发事件集合（用于 Save/Load）
    pub fn restore_triggered(&mut self, ids: impl IntoIterator<Item = String>) {
        self.triggered_ids.clear();
        self.triggered_ids.extend(ids);
    }
}

// ── 触发结果 ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct TriggeredEvent {
    pub id: String,
    pub label: String,
    pub tier: EventTier,
    pub narrative: String,
    pub historical_note: String,
    pub effects: EventEffects,
}

// ── 单元测试 ──────────────────────────────────────────

// ── 单元测试（拆分到 pool_tests.rs，硬约束 #10）──────

#[cfg(test)]
#[allow(non_snake_case)]
#[path = "pool_tests.rs"]
mod tests;
