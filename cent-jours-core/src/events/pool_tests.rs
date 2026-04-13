use super::*;
use rand::rngs::StdRng;
use rand::SeedableRng;

const HISTORICAL_JSON: &str = include_str!("../../../src/data/events/historical.json");

// 事件测试统一使用英文函数名，中文说明保留在断言与分组注释中。
fn seeded_rng() -> StdRng {
    StdRng::seed_from_u64(42)
}

fn load_events() -> Vec<HistoricalEvent> {
    serde_json::from_str(HISTORICAL_JSON).expect("JSON解析失败")
}

fn contains_phrase_within(text: &str, start: &str, end: &str, max_gap_chars: usize) -> bool {
    let mut search_from = 0;
    while let Some(start_rel) = text[search_from..].find(start) {
        let start_idx = search_from + start_rel + start.len();
        let after_start = &text[start_idx..];
        if let Some(end_rel) = after_start.find(end) {
            let gap_chars = after_start[..end_rel].chars().count();
            if gap_chars <= max_gap_chars {
                return true;
            }
        }
        search_from = start_idx;
    }
    false
}

fn contains_banned_reframing(text: &str) -> bool {
    contains_phrase_within(text, "不是", "而是", 40)
        || contains_phrase_within(text, "不再是", "而是", 40)
        || contains_phrase_within(text, "与其说", "不如说", 40)
        || text.contains("真正的问题是")
        || text.contains("据说")
        || text.contains("众所周知")
}

fn ney_defection_context(day: u32) -> TriggerContext {
    TriggerContext {
        day,
        napoleon_reputation: 70.0,
        ney_loyalty: 65.0,
        ney_napoleon_relationship: 70.0,
        grouchy_loyalty: 72.0,
        fouche_loyalty: 45.0,
        rouge_noir_index: 10.0,
        legitimacy: 50.0,
        supply: 60.0,
        ..Default::default()
    }
}

// ── JSON 加载 ──────────────────────────────────────

#[test]
// JSON 加载成功且事件数量正确
fn json_load_success_and_event_count() {
    let pool = EventPool::from_json(HISTORICAL_JSON).expect("JSON解析失败");
    assert!(
        pool.len() >= 58,
        "应有至少58个历史事件，实际: {}",
        pool.len()
    );
}

#[test]
// JSON 解析失败应返回错误
fn json_parse_invalid_returns_error() {
    let result = EventPool::from_json("not valid json");
    assert!(result.is_err());
}

#[test]
fn all_event_ids_are_unique_and_notes_are_present() {
    let events = load_events();
    let mut ids = std::collections::HashSet::new();

    for event in &events {
        assert!(ids.insert(event.id.clone()), "事件ID重复: {}", event.id);
        assert!(
            !event.historical_note.trim().is_empty(),
            "historical_note 不应为空: {}",
            event.id
        );
    }
}

#[test]
fn negative_bonus_fields_are_not_used_for_clamped_stats() {
    let events = load_events();
    let invalid_security: Vec<&str> = events
        .iter()
        .filter(|event| event.effects.paris_security_bonus.unwrap_or(0.0) < 0.0)
        .map(|event| event.id.as_str())
        .collect();
    let invalid_stability: Vec<&str> = events
        .iter()
        .filter(|event| event.effects.political_stability_bonus.unwrap_or(0.0) < 0.0)
        .map(|event| event.id.as_str())
        .collect();

    assert!(
        invalid_security.is_empty(),
        "paris_security_bonus 不应为负，否则会被状态机下限吞掉: {:?}",
        invalid_security
    );
    assert!(
        invalid_stability.is_empty(),
        "political_stability_bonus 不应为负，否则会被状态机下限吞掉: {:?}",
        invalid_stability
    );
}

#[test]
fn event_tiers_match_adr_narrative_requirements() {
    let events = load_events();
    let minor_count = events
        .iter()
        .filter(|event| matches!(event.tier, EventTier::Minor))
        .count();
    assert!(
        minor_count >= 7,
        "minor 事件至少应有7条，实际: {}",
        minor_count
    );
    let late_minor_count = events
        .iter()
        .filter(|event| matches!(event.tier, EventTier::Minor) && event.day_range[1] >= 85)
        .count();
    assert!(
        late_minor_count >= 1,
        "Day 85+ 终盘至少应有1条 minor 事件，实际: {}",
        late_minor_count
    );

    for event in &events {
        let len = event.narratives.len();
        match event.tier {
            EventTier::Major => assert!(
                (3..=5).contains(&len),
                "major 事件叙事段数应为3-5段: {} => {}",
                event.id,
                len
            ),
            EventTier::Normal => assert!(
                (2..=3).contains(&len),
                "normal 事件叙事段数应为2-3段: {} => {}",
                event.id,
                len
            ),
            EventTier::Minor => assert!(
                (1..=2).contains(&len),
                "minor 事件叙事段数应为1-2段: {} => {}",
                event.id,
                len
            ),
        }
    }
}

#[test]
fn historical_event_copy_avoids_reframing_phrases() {
    let events = load_events();
    let mut violations = Vec::new();

    for event in &events {
        for (idx, narrative) in event.narratives.iter().enumerate() {
            if contains_banned_reframing(narrative) {
                violations.push(format!("{} narratives[{}]: {}", event.id, idx, narrative));
            }
        }
        if contains_banned_reframing(&event.historical_note) {
            violations.push(format!(
                "{} historical_note: {}",
                event.id, event.historical_note
            ));
        }
    }

    assert!(
        violations.is_empty(),
        "历史事件文案不应使用 ADR-008 禁止的 reframing / 填充句式: {:?}",
        violations
    );
}

// ── 触发条件 ──────────────────────────────────────

#[test]
// 内伊倒戈在 Day 5–7 触发
fn ney_defection_triggers_day5_to_7() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(6);
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(
        ids.contains(&"ney_defection"),
        "Day 6应能触发内伊倒戈: {:?}",
        ids
    );
}

#[test]
// 内伊倒戈不在 Day 1 触发
fn ney_defection_not_on_day1() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(1);
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(!ids.contains(&"ney_defection"), "Day 1不应触发内伊倒戈");
}

#[test]
// 内伊忠诚度过低不触发倒戈
fn ney_low_loyalty_no_defection() {
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
// 格鲁希任命在 Day 85 后触发
fn grouchy_assignment_after_day85() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 87,
        grouchy_loyalty: 72.0,
        napoleon_reputation: 65.0,
        ..Default::default()
    };
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(
        ids.contains(&"grouchy_assignment"),
        "Day 87应能触发格鲁希任命: {:?}",
        ids
    );
}

#[test]
// 富歇阴谋在极端 Noir 时触发
fn fouche_conspiracy_extreme_noir() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 40,
        fouche_loyalty: 45.0,    // ≤50
        rouge_noir_index: -30.0, // ≤-20
        ..Default::default()
    };
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(
        ids.contains(&"fouche_conspiracy"),
        "极端Noir+富歇低忠诚应触发阴谋: {:?}",
        ids
    );
}

#[test]
// 富歇高忠诚时阴谋不触发
fn fouche_high_loyalty_no_conspiracy() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 40,
        fouche_loyalty: 60.0, // >50，超过最大值
        rouge_noir_index: -30.0,
        ..Default::default()
    };
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(
        !ids.contains(&"fouche_conspiracy"),
        "富歇忠诚高于阈值不应触发阴谋"
    );
}

// ── 触发机制 ──────────────────────────────────────

#[test]
// 事件触发后不再重复触发
fn no_duplicate_trigger() {
    let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(6);
    let mut rng = seeded_rng();

    let first = pool.trigger_all(&ctx, &mut rng);
    let second = pool.trigger_all(&ctx, &mut rng);

    assert!(
        first.iter().any(|e| e.id == "ney_defection"),
        "第一次应触发内伊倒戈"
    );
    assert!(
        !second.iter().any(|e| e.id == "ney_defection"),
        "第二次不应重复触发"
    );
}

#[test]
// is_triggered 追踪已触发事件
fn is_triggered_tracks_fired_events() {
    let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    assert!(!pool.is_triggered("ney_defection"));

    let ctx = ney_defection_context(6);
    let mut rng = seeded_rng();
    pool.trigger_all(&ctx, &mut rng);

    assert!(pool.is_triggered("ney_defection"));
}

#[test]
// 触发后叙事文本非空
fn narrative_text_not_empty() {
    let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(6);
    let mut rng = seeded_rng();
    let triggered = pool.trigger_all(&ctx, &mut rng);
    let ney_event = triggered.iter().find(|e| e.id == "ney_defection");
    assert!(ney_event.is_some(), "内伊倒戈应被触发");
    assert!(!ney_event.unwrap().narrative.is_empty(), "叙事文本不应为空");
}

#[test]
fn triggered_events_keep_tier_and_historical_note() {
    let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(6);
    let mut rng = seeded_rng();
    let triggered = pool.trigger_all(&ctx, &mut rng);
    let ney_event = triggered.iter().find(|e| e.id == "ney_defection");

    assert!(ney_event.is_some(), "内伊倒戈应被触发");
    let ney_event = ney_event.unwrap();
    assert!(
        matches!(ney_event.tier, EventTier::Major),
        "tier 应随事件一并保留"
    );
    assert!(
        !ney_event.historical_note.is_empty(),
        "historical_note 不应在触发结果中丢失"
    );
}

// ── 效果数值 ──────────────────────────────────────

#[test]
// 内伊倒戈效果包含忠诚度提升
fn ney_defection_increases_loyalty() {
    let mut pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = ney_defection_context(6);
    let mut rng = seeded_rng();
    let triggered = pool.trigger_all(&ctx, &mut rng);
    let ney_event = triggered.iter().find(|e| e.id == "ney_defection").unwrap();
    // 新格式：loyalty_deltas["ney"] 替代 ney_loyalty_delta
    let delta = ney_event
        .effects
        .loyalty_deltas
        .get("ney")
        .copied()
        .unwrap_or(0.0);
    assert!(delta > 0.0, "内伊倒戈应提升忠诚度，实际delta={}", delta);
}

// ── 通用 loyalty_deltas + loyalty_min 数据驱动化 ──────

#[test]
// loyalty_deltas 通用字段支持任意将领
fn loyalty_deltas_supports_any_character() {
    let json = r#"[{
        "id": "test_event", "label": "测试", "day_range": [1, 100],
        "trigger": {},
        "effects": { "loyalty_deltas": {"davout": -20.0, "ney": 10.0} },
        "narratives": ["test"]
    }]"#;
    let pool = EventPool::from_json(json).unwrap();
    let ctx = TriggerContext {
        day: 50,
        ..Default::default()
    };
    let available = pool.available_events(&ctx);
    assert_eq!(available.len(), 1);
    assert_eq!(
        available[0].effects.loyalty_deltas.get("davout").copied(),
        Some(-20.0)
    );
    assert_eq!(
        available[0].effects.loyalty_deltas.get("ney").copied(),
        Some(10.0)
    );
}

#[test]
// loyalty_min 条件：将领忠诚不足时不触发
fn loyalty_min_insufficient_no_trigger() {
    let json = r#"[{
        "id": "test_event", "label": "测试", "day_range": [1, 100],
        "trigger": { "loyalty_min": {"davout": 75.0} },
        "effects": {}, "narratives": ["test"]
    }]"#;
    let pool = EventPool::from_json(json).unwrap();
    let ctx = TriggerContext {
        day: 50,
        loyalty_map: [("davout".to_string(), 60.0)].into_iter().collect(),
        ..Default::default()
    };
    assert!(
        pool.available_events(&ctx).is_empty(),
        "达武忠诚不足不应触发"
    );
}

#[test]
// loyalty_min 条件：将领忠诚足够时触发
fn loyalty_min_sufficient_triggers() {
    let json = r#"[{
        "id": "test_event", "label": "测试", "day_range": [1, 100],
        "trigger": { "loyalty_min": {"davout": 75.0} },
        "effects": {}, "narratives": ["test"]
    }]"#;
    let pool = EventPool::from_json(json).unwrap();
    let ctx = TriggerContext {
        day: 50,
        loyalty_map: [("davout".to_string(), 80.0)].into_iter().collect(),
        ..Default::default()
    };
    assert_eq!(pool.available_events(&ctx).len(), 1, "达武忠诚足够应触发");
}

#[test]
// 达武任命事件需要达武高忠诚
fn davout_assignment_requires_high_loyalty() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    // 达武忠诚不足 → 不触发
    let ctx_low = TriggerContext {
        day: 25,
        loyalty_map: [("davout".to_string(), 60.0)].into_iter().collect(),
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx_low)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        !ids.contains(&"davout_paris_assignment"),
        "达武忠诚不足不应触发任命"
    );
    // 达武忠诚足够 → 触发
    let ctx_high = TriggerContext {
        day: 25,
        loyalty_map: [("davout".to_string(), 80.0)].into_iter().collect(),
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx_high)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"davout_paris_assignment"),
        "达武忠诚足够应触发任命: {:?}",
        ids
    );
}

#[test]
// 反法同盟宣战在 Day 15–20 触发
fn allies_mobilization_day15_to_20() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 17,
        napoleon_reputation: 65.0,
        ..Default::default()
    };
    let available = pool.available_events(&ctx);
    let ids: Vec<&str> = available.iter().map(|e| e.id.as_str()).collect();
    assert!(
        ids.contains(&"allies_mobilization"),
        "Day 17应能触发同盟宣战: {:?}",
        ids
    );
}

// ── coalition_not_defeated 触发条件 ───────────────

#[test]
// coalition_not_defeated 为 true 时联军未败才触发
fn coalition_not_defeated_true_requires_active() {
    let json = r#"[{
        "id": "battle_event", "label": "决战", "day_range": [1, 100],
        "trigger": { "coalition_not_defeated": true },
        "effects": {}, "narratives": ["test"]
    }]"#;
    let pool = EventPool::from_json(json).unwrap();
    // 联军未被击败 → 应触发
    let ctx_active = TriggerContext {
        day: 50,
        coalition_defeated: false,
        ..Default::default()
    };
    assert_eq!(
        pool.available_events(&ctx_active).len(),
        1,
        "联军未败应触发"
    );
    // 联军已被击败 → 不应触发
    let ctx_defeated = TriggerContext {
        day: 50,
        coalition_defeated: true,
        ..Default::default()
    };
    assert!(
        pool.available_events(&ctx_defeated).is_empty(),
        "联军已败不应触发"
    );
}

#[test]
// coalition_not_defeated 未设置时不影响触发
fn coalition_not_defeated_none_always_triggers() {
    let json = r#"[{
        "id": "neutral_event", "label": "中性事件", "day_range": [1, 100],
        "trigger": {},
        "effects": {}, "narratives": ["test"]
    }]"#;
    let pool = EventPool::from_json(json).unwrap();
    // 无论联军状态均触发
    let ctx = TriggerContext {
        day: 50,
        coalition_defeated: true,
        ..Default::default()
    };
    assert_eq!(
        pool.available_events(&ctx).len(),
        1,
        "无coalition_not_defeated条件应始终触发"
    );
}

#[test]
// 威灵顿山脊事件需要联军未被击败
fn wellington_ridge_requires_active_coalition() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    // 正常游戏中联军未被击败
    let ctx_active = TriggerContext {
        day: 88,
        coalition_defeated: false,
        napoleon_reputation: 65.0,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx_active)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"wellington_ridge_position"),
        "联军未败时应触发威灵顿山脊: {:?}",
        ids
    );
    // 联军已败则不触发
    let ctx_defeated = TriggerContext {
        day: 88,
        coalition_defeated: true,
        napoleon_reputation: 65.0,
        ..Default::default()
    };
    let ids_d: Vec<&str> = pool
        .available_events(&ctx_defeated)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        !ids_d.contains(&"wellington_ridge_position"),
        "联军已败不应触发威灵顿山脊"
    );
}

// ── Day 13-19 新增事件覆盖测试 ───────────────────

#[test]
// 里昂入城在 Day 10–14 触发
fn lyon_entry_day10_to_14() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 12,
        napoleon_reputation: 55.0,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"lyon_artois_flees"),
        "Day 12应触发里昂入城: {:?}",
        ids
    );
}

#[test]
// 勃艮第民众浪潮在 Day 14–17 触发
fn burgundy_surge_day14_to_17() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 15,
        napoleon_reputation: 55.0,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"burgundy_popular_surge"),
        "Day 15应触发勃艮第民众浪潮: {:?}",
        ids
    );
}

#[test]
// 杜伊勒里宫前夜在 Day 17–19 触发（原 fontainebleau_eve，修正 id 后）
fn tuileries_eve_day17_to_19() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 18,
        napoleon_reputation: 60.0,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"tuileries_eve"),
        "Day 18应触发杜伊勒里宫前夜: {:?}",
        ids
    );
}

#[test]
fn late_campaign_events_follow_tightened_timeline() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let cases = [
        (
            "ligny_victory",
            TriggerContext {
                day: 85,
                napoleon_reputation: 55.0,
                ..Default::default()
            },
        ),
        (
            "quatre_bras_stalemate",
            TriggerContext {
                day: 85,
                ..Default::default()
            },
        ),
        (
            "grouchy_assignment",
            TriggerContext {
                day: 87,
                grouchy_loyalty: 72.0,
                napoleon_reputation: 65.0,
                ..Default::default()
            },
        ),
        (
            "prussian_regroup_wavre",
            TriggerContext {
                day: 87,
                ..Default::default()
            },
        ),
        (
            "wellington_ridge_position",
            TriggerContext {
                day: 87,
                coalition_defeated: false,
                ..Default::default()
            },
        ),
        (
            "waterloo_eve",
            TriggerContext {
                day: 90,
                coalition_defeated: false,
                ..Default::default()
            },
        ),
        (
            "old_guard_last_charge",
            TriggerContext {
                day: 92,
                napoleon_reputation: 45.0,
                ..Default::default()
            },
        ),
        (
            "abdication_pressure",
            TriggerContext {
                day: 93,
                rouge_noir_index: -5.0,
                ..Default::default()
            },
        ),
        (
            "paris_falls_to_allies",
            TriggerContext {
                day: 95,
                coalition_defeated: false,
                ..Default::default()
            },
        ),
    ];

    for (expected_id, ctx) in cases {
        let ids: Vec<&str> = pool
            .available_events(&ctx)
            .iter()
            .map(|e| e.id.as_str())
            .collect();
        assert!(
            ids.contains(&expected_id),
            "Day {} 应触发 {}: {:?}",
            ctx.day,
            expected_id,
            ids
        );
    }
}

#[test]
fn soult_as_chief_of_staff_triggers_on_day_22() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 22,
        loyalty_map: [("soult".to_string(), 60.0)].into_iter().collect(),
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"soult_chief_of_staff"),
        "Day 22应触发苏尔特参谋长: {:?}",
        ids
    );
}

#[test]
fn derlon_corps_lost_triggers_on_day_83() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 83,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"drouet_march_confusion"),
        "Day 83应触发德尔隆军团迷失: {:?}",
        ids
    );
}

#[test]
fn bluecher_promises_support_triggers_on_day_88() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 88,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"blucher_promises_support"),
        "Day 88应触发布吕歇尔承诺支援: {:?}",
        ids
    );
}

#[test]
fn wounded_wagons_from_ligny_triggers_on_day_89() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 89,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"wounded_wagons_from_ligny"),
        "Day 89应触发利尼伤兵车队: {:?}",
        ids
    );
}

#[test]
fn grouchy_hears_cannon_triggers_on_day_95() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 95,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"grouchy_hears_cannon"),
        "Day 95应触发格鲁希听见炮声: {:?}",
        ids
    );
}

#[test]
fn prussians_push_plancenoit_triggers_on_day_96() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 96,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"plancenoit_under_attack"),
        "Day 96应触发普军压向普朗斯努瓦: {:?}",
        ids
    );
}

#[test]
fn zieten_reaches_the_left_flank_on_day_97() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 97,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"zieten_left_flank_arrival"),
        "Day 97应触发齐滕军团接上左翼: {:?}",
        ids
    );
}

#[test]
fn ghent_exile_court_triggers_on_day_24() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 24,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"ghent_bourbon_court"),
        "Day 24应触发根特流亡宫廷: {:?}",
        ids
    );
}

#[test]
fn ghent_royalist_pamphlets_trigger_on_day_30() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 30,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"royalist_pamphlets_from_ghent"),
        "Day 30应触发根特保皇派传单: {:?}",
        ids
    );
}

#[test]
fn brussels_allied_staff_conference_triggers_on_day_56() {
    let pool = EventPool::from_json(HISTORICAL_JSON).unwrap();
    let ctx = TriggerContext {
        day: 56,
        coalition_defeated: false,
        ..Default::default()
    };
    let ids: Vec<&str> = pool
        .available_events(&ctx)
        .iter()
        .map(|e| e.id.as_str())
        .collect();
    assert!(
        ids.contains(&"brussels_allied_staff_conference"),
        "Day 56应触发布鲁塞尔联军参谋会议: {:?}",
        ids
    );
}
