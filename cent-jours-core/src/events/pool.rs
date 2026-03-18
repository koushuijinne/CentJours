//! 历史事件池 — `events::pool`
//!
//! 从 JSON 加载事件定义，根据游戏状态触发，返回叙事文本和效果。
//! TDD：测试先于实现。

use rand::Rng;
use serde::Deserialize;

// ── 事件数据结构（与 JSON 对应）────────────────────────

/// 触发条件（所有字段均为可选，未填写的条件默认满足）
#[derive(Debug, Clone, Deserialize, Default)]
pub struct EventTrigger {
    pub napoleon_reputation_min:         Option<f64>,
    pub ney_loyalty_min:                 Option<f64>,
    pub ney_napoleon_relationship_min:   Option<f64>,
    pub grouchy_loyalty_min:             Option<f64>,
    pub davout_loyalty_min:              Option<f64>,
    pub fouche_loyalty_max:              Option<f64>,
    pub rouge_noir_index_max:            Option<f64>,
    pub day_min:                         Option<u32>,
    pub coalition_not_defeated:          Option<bool>,
}

/// 事件效果（数值变化）
#[derive(Debug, Clone, Deserialize, Default)]
pub struct EventEffects {
    pub ney_loyalty_delta:              Option<f64>,
    pub military_support_delta:         Option<f64>,
    pub nobility_support_delta:         Option<f64>,
    pub populace_support_delta:         Option<f64>,
    pub liberals_support_delta:         Option<f64>,
    pub rouge_noir_delta:               Option<f64>,
    pub legitimacy_delta:               Option<f64>,
    pub fouche_loyalty_delta:           Option<f64>,
    pub paris_security_bonus:           Option<f64>,
    pub political_stability_bonus:      Option<f64>,
    pub military_available_troops_delta: Option<i64>,
    pub coalition_troops_bonus:         Option<i32>,  // 允许负值（削减联军）
    pub napoleon_morale_bonus:          Option<f64>,
}

/// 单个历史事件定义
#[derive(Debug, Clone, Deserialize)]
pub struct HistoricalEvent {
    pub id:              String,
    pub label:           String,
    pub day_range:       [u32; 2],
    pub trigger:         EventTrigger,
    pub effects:         EventEffects,
    pub narratives:      Vec<String>,
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
            if ctx.napoleon_reputation < min { return false; }
        }
        if let Some(min) = t.ney_loyalty_min {
            if ctx.ney_loyalty < min { return false; }
        }
        if let Some(min) = t.ney_napoleon_relationship_min {
            if ctx.ney_napoleon_relationship < min { return false; }
        }
        if let Some(min) = t.grouchy_loyalty_min {
            if ctx.grouchy_loyalty < min { return false; }
        }
        if let Some(max) = t.fouche_loyalty_max {
            if ctx.fouche_loyalty > max { return false; }
        }
        if let Some(max) = t.rouge_noir_index_max {
            if ctx.rouge_noir_index > max { return false; }
        }
        if let Some(min) = t.day_min {
            if ctx.day < min { return false; }
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
    pub day:                      u32,
    pub napoleon_reputation:      f64,
    pub ney_loyalty:              f64,
    pub ney_napoleon_relationship: f64,
    pub grouchy_loyalty:          f64,
    pub fouche_loyalty:           f64,
    pub rouge_noir_index:         f64,
}

// ── 事件池 ────────────────────────────────────────────

/// 已触发事件的记录（防止同一事件重复触发）
pub struct EventPool {
    events:          Vec<HistoricalEvent>,
    triggered_ids:   std::collections::HashSet<String>,
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
            events:        Vec::new(),
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
        let to_trigger: Vec<String> = self.events
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
                    id:        event.id.clone(),
                    label:     event.label.clone(),
                    narrative,
                    effects:   event.effects.clone(),
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
    pub id:        String,
    pub label:     String,
    pub narrative: String,
    pub effects:   EventEffects,
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rand::SeedableRng;
    use rand::rngs::StdRng;

    const HISTORICAL_JSON: &str = include_str!("../../../src/data/events/historical.json");

    fn seeded_rng() -> StdRng {
        StdRng::seed_from_u64(42)
    }

    fn ney_defection_context(day: u32) -> TriggerContext {
        TriggerContext {
            day,
            napoleon_reputation:       70.0,
            ney_loyalty:               65.0,
            ney_napoleon_relationship: 70.0,
            grouchy_loyalty:           72.0,
            fouche_loyalty:            45.0,
            rouge_noir_index:          10.0,
        }
    }

    // ── JSON 加载 ──────────────────────────────────────

    #[test]
    fn json加载成功且事件数量正确() {
        let pool = EventPool::from_json(HISTORICAL_JSON).expect("JSON解析失败");
        assert!(pool.len() >= 20, "应有至少20个历史事件，实际: {}", pool.len());
    }

    #[test]
    fn json解析失败返回错误() {
        let result = EventPool::from_json("not valid json");
        assert!(result.is_err());
    }

    // ── 触发条件 ──────────────────────────────────────

    #[test]
    fn 内伊倒戈在Day5到7触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = ney_defection_context(6);
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(ids.contains(&"ney_defection"), "Day 6应能触发内伊倒戈: {:?}", ids);
    }

    #[test]
    fn 内伊倒戈不在Day1触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = ney_defection_context(1);
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(!ids.contains(&"ney_defection"), "Day 1不应触发内伊倒戈");
    }

    #[test]
    fn 内伊忠诚度过低不触发倒戈() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = TriggerContext {
            day: 6,
            ney_loyalty: 40.0, // 低于阈值55
            ney_napoleon_relationship: 70.0,
            napoleon_reputation: 70.0,
            ..Default::default()
        };
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(!ids.contains(&"ney_defection"), "内伊忠诚过低不应触发倒戈");
    }

    #[test]
    fn 格鲁希任命在Day85后触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = TriggerContext {
            day: 87,
            grouchy_loyalty: 72.0,
            napoleon_reputation: 65.0,
            ..Default::default()
        };
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(ids.contains(&"grouchy_assignment"), "Day 87应能触发格鲁希任命: {:?}", ids);
    }

    #[test]
    fn 富歇阴谋在极端Noir时触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = TriggerContext {
            day: 40,
            fouche_loyalty: 45.0,   // ≤50
            rouge_noir_index: -30.0, // ≤-20
            ..Default::default()
        };
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(ids.contains(&"fouche_conspiracy"), "极端Noir+富歇低忠诚应触发阴谋: {:?}", ids);
    }

    #[test]
    fn 富歇阴谋在高忠诚时不触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = TriggerContext {
            day: 40,
            fouche_loyalty: 60.0,    // >50，超过最大值
            rouge_noir_index: -30.0,
            ..Default::default()
        };
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(!ids.contains(&"fouche_conspiracy"), "富歇忠诚高于阈值不应触发阴谋");
    }

    // ── 触发机制 ──────────────────────────────────────

    #[test]
    fn 触发后不再重复触发() {
        let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = ney_defection_context(6);
        let mut rng = seeded_rng();

        let first = pool.trigger_all(&ctx, &mut rng);
        let second = pool.trigger_all(&ctx, &mut rng);

        assert!(first.iter().any(|e| e.id == "ney_defection"), "第一次应触发内伊倒戈");
        assert!(!second.iter().any(|e| e.id == "ney_defection"), "第二次不应重复触发");
    }

    #[test]
    fn is_triggered追踪已触发事件() {
        let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        assert!(!pool.is_triggered("ney_defection"));

        let ctx = ney_defection_context(6);
        let mut rng = seeded_rng();
        pool.trigger_all(&ctx, &mut rng);

        assert!(pool.is_triggered("ney_defection"));
    }

    #[test]
    fn 叙事文本非空() {
        let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = ney_defection_context(6);
        let mut rng = seeded_rng();
        let triggered = pool.trigger_all(&ctx, &mut rng);
        let ney_event = triggered.iter().find(|e| e.id == "ney_defection");
        assert!(ney_event.is_some(), "内伊倒戈应被触发");
        assert!(!ney_event.unwrap().narrative.is_empty(), "叙事文本不应为空");
    }

    // ── 效果数值 ──────────────────────────────────────

    #[test]
    fn 内伊倒戈效果含忠诚度提升() {
        let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = ney_defection_context(6);
        let mut rng = seeded_rng();
        let triggered = pool.trigger_all(&ctx, &mut rng);
        let ney_event = triggered.iter().find(|e| e.id == "ney_defection").unwrap();
        let delta = ney_event.effects.ney_loyalty_delta.unwrap_or(0.0);
        assert!(delta > 0.0, "内伊倒戈应提升忠诚度，实际delta={}", delta);
    }

    #[test]
    fn 反法同盟宣战在Day15到20触发() {
        let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
        let ctx = TriggerContext {
            day: 17,
            napoleon_reputation: 65.0,
            ..Default::default()
        };
        let available = pool.available_events(&ctx);
        let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
        assert!(ids.contains(&"allies_mobilization"), "Day 17应能触发同盟宣战: {:?}", ids);
    }
}
