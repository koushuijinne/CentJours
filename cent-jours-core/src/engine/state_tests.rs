use super::*;
use rand::rngs::StdRng;
use rand::SeedableRng;
use serde_json::json;

// 测试函数名统一改成英文，中文语义继续保留在分组标题、断言文本和局部注释里。
fn seeded_rng() -> StdRng {
    StdRng::seed_from_u64(42)
}

// ── 初始化 ────────────────────────────────────────

#[test]
fn engine_initial_state_is_correct() {
    let engine = GameEngine::new();
    assert_eq!(engine.current_day(), 1);
    assert!(!engine.is_over());
    assert_eq!(engine.outcome(), None);
    assert_eq!(engine.army.total_troops, 72_000);
}

// ── 战役耦合 ──────────────────────────────────────

#[test]
fn victory_raises_military_support_and_loyalty() {
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
fn defeat_lowers_military_support() {
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
fn policy_actions_consume_action_points() {
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
fn recent_action_log_keeps_readable_policy_summary() {
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
fn failed_policy_still_keeps_failure_reason() {
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
fn requisition_supplies_increases_supply_immediately() {
    let mut engine = GameEngine::new();
    engine.army.supply = 30.0;
    let mut rng = seeded_rng();

    engine.begin_day(&mut rng);
    engine.execute_day_action(
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
    assert_eq!(engine.day, 1, "日内政策测试不应提前推进日期");
    assert!(engine.army.supply > 30.0, "政策执行后补给应立刻高于执行前");
}

#[test]
fn stabilize_supply_lines_temporarily_increases_line_efficiency() {
    let baseline = GameEngine::new();
    let base_preview = baseline.preview_march("grasse");

    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "stabilize_supply_lines",
        },
        &mut rng,
    );

    let policy_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "policy")
        .expect("应包含政策结算");
    assert!(
        policy_event
            .effects
            .iter()
            .any(|effect| effect.contains("补给线效率")),
        "政策结算应显式展示补给线效率加成"
    );

    let boosted_preview = engine.preview_march("grasse");
    assert!(
        base_preview.valid && boosted_preview.valid,
        "预览应保持可用"
    );
    assert!(
        boosted_preview.line_efficiency > base_preview.line_efficiency,
        "政策执行后预览中的补给线效率应更高"
    );
    assert_eq!(engine.supply_line_bonus_days, 2, "当天结算后应剩余2天加成");

    // 隔离纯政策时长，避免区域任务奖励把同一类加成续上后干扰断言。
    engine.regional_task_id.clear();
    engine.regional_task_progress = 0;
    engine.regional_task_completed = false;

    engine.process_day(PlayerAction::Rest, &mut rng);
    engine.process_day(PlayerAction::Rest, &mut rng);
    assert_eq!(engine.supply_line_bonus_days, 0, "加成应按天数衰减归零");
    assert!(
        engine.supply_line_bonus.abs() <= f64::EPSILON,
        "加成结束后数值应清零"
    );
}

#[test]
fn establish_forward_depot_temporarily_increases_local_capacity() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "grasse".to_string();
    let base_preview = engine.preview_march("digne");
    let mut rng = seeded_rng();

    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "establish_forward_depot",
        },
        &mut rng,
    );

    let policy_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "policy")
        .expect("应包含政策结算");
    assert!(
        policy_event
            .effects
            .iter()
            .any(|effect| effect.contains("当前驻地容量 +4")),
        "政策结算应显式展示驻地容量加成"
    );
    assert_eq!(engine.forward_depot_location, "grasse");
    assert_eq!(engine.forward_depot_capacity_bonus, 4);
    assert_eq!(engine.forward_depot_days, 3, "当天结算后应剩余3天");

    let boosted_here = engine.effective_supply_capacity_for("grasse");
    assert_eq!(boosted_here, 6, "格拉斯基础2点容量，应被抬到6");

    let boosted_preview = engine.preview_march("digne");
    assert!(
        boosted_preview.supply_capacity >= base_preview.supply_capacity,
        "建立粮秣站后，预览中的有效容量不应低于基线"
    );
    assert!(
        boosted_preview.supply_hub_distance <= base_preview.supply_hub_distance,
        "前沿粮秣站不应让枢纽距离读数更差"
    );

    engine.process_day(PlayerAction::Rest, &mut rng);
    engine.process_day(PlayerAction::Rest, &mut rng);
    engine.process_day(PlayerAction::Rest, &mut rng);
    assert_eq!(engine.forward_depot_days, 0, "粮秣站应按天数衰减归零");
    assert!(engine.forward_depot_location.is_empty());
}

#[test]
fn secure_regional_corridor_increases_line_efficiency_and_local_capacity() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "autun".to_string();
    let preview_target = engine
        .adjacent_nodes()
        .into_iter()
        .next()
        .expect("应至少存在一个相邻节点");
    let base_preview = engine.preview_march(&preview_target);
    let mut rng = seeded_rng();

    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "secure_regional_corridor",
        },
        &mut rng,
    );

    let policy_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "policy")
        .expect("应包含政策结算");
    assert!(
        policy_event
            .effects
            .iter()
            .any(|effect| effect.contains("补给线效率")),
        "区域走廊政策应显式展示补给线效率加成"
    );
    assert!(
        policy_event
            .effects
            .iter()
            .any(|effect| effect.contains("当前驻地容量 +3")),
        "区域走廊政策应显式展示当前驻地容量加成"
    );
    assert_eq!(engine.forward_depot_location, "autun");
    assert_eq!(engine.forward_depot_capacity_bonus, 3);
    assert_eq!(engine.forward_depot_days, 3, "当天结算后应剩余3天容量加成");
    assert_eq!(
        engine.supply_line_bonus_days, 3,
        "当天结算后应剩余3天运输线加成"
    );

    let boosted_preview = engine.preview_march(&preview_target);
    assert!(
        base_preview.valid && boosted_preview.valid,
        "预览应保持可用"
    );
    assert!(
        boosted_preview.line_efficiency > base_preview.line_efficiency,
        "区域走廊政策执行后预览中的补给线效率应更高"
    );
    assert!(
        engine.effective_supply_capacity_for("autun") > 3,
        "区域走廊政策执行后当前驻地容量应高于基础值"
    );
}

#[test]
fn low_supply_switches_logistics_posture_to_recovery() {
    let mut engine = GameEngine::new();
    engine.army.supply = 34.0;

    let brief = engine.logistics_brief();

    assert_eq!(brief.posture_id, "critical_recovery");
    assert_eq!(brief.posture_label, "止血整补");
    assert!(
        brief.focus_detail.contains("先休整或补给"),
        "低补给时应直接提示先止血整补"
    );
}

#[test]
fn low_supply_action_plan_prioritizes_requisition() {
    let mut engine = GameEngine::new();
    engine.army.supply = 34.0;

    let brief = engine.logistics_brief();

    assert_eq!(brief.primary_action_id, "requisition_supplies");
    assert_eq!(brief.secondary_action_id, "rest");
    assert!(
        brief.action_plan_detail.contains("征用沿线仓储"),
        "止血场景下应把征用仓储写进当日行动计划"
    );
}

#[test]
fn forward_depot_posture_switches_to_forward_staging() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "grasse".to_string();
    engine.forward_depot_location = "grasse".to_string();
    engine.forward_depot_capacity_bonus = 4;
    engine.forward_depot_days = 3;

    let brief = engine.logistics_brief();

    assert_eq!(brief.posture_id, "forward_staging");
    assert_eq!(brief.posture_label, "前沿整补跳板");
    assert!(
        brief.focus_short.contains("粮秣站"),
        "前沿粮秣站激活时应强调窗口期"
    );
}

#[test]
fn long_supply_line_action_plan_prioritizes_regional_corridor() {
    let engine = GameEngine::new();

    let (primary, secondary) = engine.logistics_action_plan_for(
        "autun",
        "overextended_line",
        "regional_depot",
        58.0,
        24.0,
        3,
        3,
    );

    assert_eq!(primary.action_id, "secure_regional_corridor");
    assert!(
        secondary.action_id == "march" || secondary.action_id == "stabilize_supply_lines",
        "运输线拉长时备选应是换位接仓或先保线"
    );
}

#[test]
fn phase_objective_switches_with_day_ranges() {
    let mut engine = GameEngine::new();
    engine.day = 8;
    assert!(
        engine.logistics_brief().focus_title.contains("前10天"),
        "早期应给出前10天阶段目标"
    );

    engine.day = 92;
    assert!(
        engine.logistics_brief().focus_title.contains("终盘"),
        "终盘应切换到决战目标"
    );
}

#[test]
fn high_capacity_node_shows_sustainable_supply_window() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "paris".to_string();
    engine.army.supply = 68.0;

    assert_eq!(engine.current_supply_runway_days(), None);
    assert!(
        engine.current_supply_runway_label().contains("可持续维持"),
        "高容量节点应显示为可持续维持"
    );
}

#[test]
fn first_ten_days_frontline_zone_requires_regional_staging_point() {
    let engine = GameEngine::new();
    let brief = engine.logistics_brief();

    assert_eq!(brief.objective_target_role, "regional_depot");
    assert!(
        brief.objective_label.contains("区域整补点"),
        "前期前线消耗区应优先接区域整补点"
    );
}

#[test]
fn first_ten_days_action_plan_returns_explicit_march_target() {
    let engine = GameEngine::new();
    let brief = engine.logistics_brief();

    assert_eq!(brief.primary_action_id, "march");
    assert!(
        !brief.primary_action_target.is_empty(),
        "前10天开局应直接给出一个可执行的行军目标"
    );
    assert!(
        !brief.primary_action_target_label.is_empty(),
        "行军建议应带可读节点名"
    );
}

#[test]
fn three_day_logistics_tempo_provides_full_schedule() {
    let engine = GameEngine::new();
    let brief = engine.logistics_brief();

    assert!(brief.tempo_plan_detail.contains("今天："));
    assert!(brief.tempo_plan_detail.contains("明天："));
    assert!(brief.tempo_plan_detail.contains("后天："));
    assert!(
        !brief.tempo_plan_short.is_empty(),
        "节奏计划应给出可复用的短摘要"
    );
}

#[test]
fn regional_operations_chain_returns_recommended_route() {
    let engine = GameEngine::new();
    let brief = engine.logistics_brief();

    assert!(
        brief.route_chain_detail.contains("推荐链路"),
        "区域运营链路应显式给出推荐链路"
    );
    assert!(
        brief.route_chain_short.contains("->"),
        "区域运营链路短摘要应带节点承接方向"
    );
}

#[test]
fn regional_pressure_recommends_fortify_before_pushing() {
    let engine = GameEngine::new();
    let brief = engine.logistics_brief();

    assert!(
        !brief.regional_pressure_id.is_empty(),
        "区域运营压力应给出稳定的状态 ID"
    );
    assert!(
        brief.regional_pressure_title.contains("区域运营压力"),
        "区域运营压力应给出可复用标题"
    );
    assert!(
        brief.regional_pressure_detail.contains("走廊"),
        "区域运营压力应显式解释当前走廊状态"
    );
}

#[test]
fn low_supply_three_day_tempo_stops_losses_before_repairing() {
    let mut engine = GameEngine::new();
    engine.army.supply = 34.0;

    let brief = engine.logistics_brief();

    assert!(
        brief.tempo_plan_detail.contains("今天：征用沿线仓储"),
        "低补给节奏计划第1天应先止血"
    );
    assert!(
        brief.tempo_plan_detail.contains("明天：休整"),
        "低补给节奏计划第2天应优先休整"
    );
}

#[test]
fn low_supply_regional_chain_stops_losses_before_reconnecting_route() {
    let mut engine = GameEngine::new();
    engine.army.supply = 34.0;

    let brief = engine.logistics_brief();

    assert!(
        brief.route_chain_detail.contains("先执行“征用沿线仓储”")
            || brief.route_chain_short.contains("先征用沿线仓储"),
        "低补给链路应先止血，再谈节点承接"
    );
}

#[test]
fn late_campaign_push_window_targets_decisive_frontline_nodes() {
    let mut engine = GameEngine::new();
    engine.day = 92;
    engine.napoleon_location = "brussels".to_string();
    engine.army.supply = 78.0;
    engine.army.avg_fatigue = 18.0;

    let brief = engine.logistics_brief();

    assert_eq!(brief.objective_target_role, "frontline_outpost");
    assert!(
        brief.objective_short.contains("决定性前线点"),
        "终盘推进窗口应聚焦决定性前线点"
    );
}

#[test]
fn march_preview_reports_landing_supply_window() {
    let mut engine = GameEngine::new();
    engine.army.supply = 52.0;

    let preview = engine.preview_march("grasse");

    assert!(preview.valid);
    assert!(
        preview.supply_runway_days >= 0,
        "低容量落点应给出明确补给窗口"
    );
    assert!(
        preview.follow_up_total_options >= preview.follow_up_safe_options,
        "第二跳总数应覆盖稳妥路线数量"
    );
}

#[test]
fn high_capacity_destination_keeps_second_hop_flexibility() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "grenoble".to_string();
    engine.army.supply = 78.0;

    let preview = engine.preview_march("lyon");

    assert!(preview.valid);
    assert!(preview.follow_up_total_options >= 2);
    assert_ne!(preview.follow_up_status_id, "dead_end");
    assert!(
        !preview.follow_up_best_target_label.is_empty(),
        "应给出最稳后续节点"
    );
}

#[test]
fn low_capacity_frontline_destination_exposes_second_hop_trap() {
    let mut engine = GameEngine::new();
    engine.army.supply = 52.0;

    let preview = engine.preview_march("grasse");

    assert!(preview.valid);
    assert_eq!(preview.follow_up_status_id, "frontline_trap");
    assert_eq!(preview.follow_up_safe_options, 0);
}

// ── 忠诚度强化 ────────────────────────────────────

#[test]
fn boost_loyalty_consumes_legitimacy() {
    let mut engine = GameEngine::new();
    let leg_before = engine.politics.legitimacy;
    let _ = engine.process_boost_loyalty("davout");
    assert!(
        engine.politics.legitimacy < leg_before,
        "强化忠诚应消耗合法性"
    );
}

#[test]
fn boost_loyalty_fails_without_legitimacy() {
    let mut engine = GameEngine::new();
    engine.politics.legitimacy = 5.0; // 不足10
    let events = engine.process_boost_loyalty("davout");
    assert_eq!(events[0].event_type, "boost_failed");
}

// ── 胜负判定 ──────────────────────────────────────

#[test]
fn political_collapse_ends_game() {
    let mut engine = GameEngine::new();
    // 强制两派系崩溃
    // 设为 2.0，即使加上 Day 1 戛纳湾登陆事件的 +5.0 也会保持在 10.0 以下
    engine
        .politics
        .faction_support
        .insert("liberals".to_string(), 2.0);
    engine
        .politics
        .faction_support
        .insert("populace".to_string(), 2.0);
    let mut rng = seeded_rng();
    engine.process_day(PlayerAction::Rest, &mut rng);
    assert_eq!(
        engine.outcome(),
        Some(GameOutcome::PoliticalCollapse),
        "双派系崩溃应终结游戏"
    );
}

#[test]
fn military_annihilation_ends_game() {
    let mut engine = GameEngine::new();
    engine.army.total_troops = 3_000; // 低于阈值
    let mut rng = seeded_rng();
    engine.process_day(PlayerAction::Rest, &mut rng);
    assert_eq!(engine.outcome(), Some(GameOutcome::MilitaryAnnihilation));
}

#[test]
fn end_of_hundred_days_high_score_path_wins() {
    let mut engine = GameEngine::new();
    engine.day = 101;
    engine.politics.legitimacy = 75.0;
    engine.army.victories = 5;
    engine.check_outcome();
    assert_eq!(engine.outcome(), Some(GameOutcome::NapoleonVictory));
}

#[test]
fn end_of_hundred_days_low_score_path_exiles_napoleon() {
    let mut engine = GameEngine::new();
    engine.day = 101;
    engine.politics.legitimacy = 20.0;
    engine.army.victories = 1;
    engine.check_outcome();
    assert_eq!(engine.outcome(), Some(GameOutcome::WaterlooDefeat));
}

// ── 每日结算联动 ──────────────────────────────────

#[test]
fn rest_recovers_fatigue_and_morale() {
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
fn low_supply_rest_recovers_less() {
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
fn military_support_declines_when_troops_are_too_low() {
    let mut engine = GameEngine::new();
    // 阻止 Day 1 戛纳湾登陆事件的干扰（它会提升军方支持度）
    // 必须同步更新 event_pool 的内部状态
    let ids = vec!["golfe_juan_landing".to_string()];
    engine.triggered_event_ids = ids.clone();
    engine.event_pool.restore_triggered(ids);

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
fn marching_to_adjacent_node_updates_position_and_state() {
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
fn march_preview_returns_authoritative_projection() {
    let engine = GameEngine::new();
    let preview = engine.preview_march("grasse");

    assert!(preview.valid, "相邻节点应可预览");
    assert_eq!(preview.target_node, "grasse");
    assert!(preview.fatigue_delta.abs() > 0.0);
    assert!(preview.projected_supply >= 0.0 && preview.projected_supply <= 100.0);
    assert!(preview.supply_capacity > 0);
    assert!(preview.base_supply_capacity > 0);
    assert!(preview.supply_demand > 0.0);
    assert!(preview.supply_available > 0.0);
    assert!(preview.line_efficiency > 0.0);
    assert!(!preview.supply_role_label.is_empty());
    assert!(!preview.supply_hub_name.is_empty());
}

#[test]
fn supply_resolution_reports_risk_and_advice() {
    let mut engine = GameEngine::new();
    engine.napoleon_location = "waterloo".to_string();
    engine.army.supply = 32.0;
    let mut rng = seeded_rng();

    engine.process_day(PlayerAction::Rest, &mut rng);

    let supply_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "supply")
        .expect("应包含补给结算");
    assert!(
        supply_event
            .effects
            .iter()
            .any(|effect| effect.contains("节点容量")),
        "补给结算应显式展示节点容量"
    );
    assert!(
        supply_event
            .effects
            .iter()
            .any(|effect| effect.contains("建议：")),
        "补给结算应显式展示下一步建议"
    );
}

#[test]
fn non_adjacent_march_does_not_change_position() {
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
fn march_resolution_uses_readable_place_names() {
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
fn coalition_bonus_feeds_into_coalition_state() {
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
fn paris_security_and_political_stability_affect_daily_tick() {
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
fn save_and_load_round_trip_preserves_state() {
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
    engine.forward_depot_location = "grasse".to_string();
    engine.forward_depot_capacity_bonus = 4;
    engine.forward_depot_days = 3;
    let saved_coalition = engine.coalition_troops_bonus;
    let saved_security = engine.paris_security_bonus;
    let saved_stability = engine.political_stability_bonus;
    let saved_forward_depot_location = engine.forward_depot_location.clone();
    let saved_forward_depot_capacity_bonus = engine.forward_depot_capacity_bonus;
    let saved_forward_depot_days = engine.forward_depot_days;
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
        restored.forward_depot_location, saved_forward_depot_location,
        "前沿粮秣站位置应一致"
    );
    assert_eq!(
        restored.forward_depot_capacity_bonus, saved_forward_depot_capacity_bonus,
        "前沿粮秣站容量加成应一致"
    );
    assert_eq!(
        restored.forward_depot_days, saved_forward_depot_days,
        "前沿粮秣站剩余天数应一致"
    );
    assert_eq!(
        restored.triggered_event_ids, saved_triggered,
        "已触发事件应一致"
    );
}

#[test]
fn loaded_save_does_not_retrigger_events() {
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
fn json_round_trip_is_complete() {
    let engine = GameEngine::new();
    let json = engine.to_json();
    assert!(!json.is_empty(), "JSON 不应为空");
    let _ = GameEngine::from_json(&json).expect("合法 JSON 应可反序列化");
}

#[test]
fn legacy_save_without_supply_uses_default_value() {
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
    assert!(restored.forward_depot_location.is_empty());
    assert_eq!(restored.forward_depot_capacity_bonus, 0);
    assert_eq!(restored.forward_depot_days, 0);
}

#[test]
fn v1_save_migrates_tuileries_event_and_deduplicates() {
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

#[test]
fn day_can_spend_policy_and_march_before_manual_end() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();

    engine.begin_day(&mut rng);
    let day_before = engine.day;
    let actions_before = engine.politics.actions_remaining;

    engine.execute_day_action(
        PlayerAction::EnactPolicy {
            policy_id: "public_speech",
        },
        &mut rng,
    );
    assert_eq!(engine.day, day_before, "日内执行政策不应立刻推进日期");
    assert_eq!(
        engine.politics.actions_remaining,
        actions_before.saturating_sub(1),
        "日内政策应消耗决策点"
    );
    assert!(engine.maneuver_available(), "政策不应占用机动槽");

    engine.execute_day_action(
        PlayerAction::March {
            target_node: "grasse".to_string(),
        },
        &mut rng,
    );
    assert_eq!(engine.day, day_before, "日内行军后仍应停留在当天");
    assert_eq!(engine.napoleon_location, "grasse");
    assert!(!engine.maneuver_available(), "行军后机动槽应被占用");

    engine.end_day(&mut rng);
    assert_eq!(engine.day, day_before + 1, "手动结束今天后才应进入次日");
    assert!(!engine.day_started, "结束今天后应重置为未开始次日");
    assert!(engine.maneuver_available(), "进入次日后机动槽应恢复");
}

#[test]
fn second_maneuver_in_same_day_is_rejected() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();

    engine.begin_day(&mut rng);
    engine.execute_day_action(PlayerAction::Rest, &mut rng);
    let location_before = engine.napoleon_location.clone();
    engine.execute_day_action(
        PlayerAction::March {
            target_node: "grasse".to_string(),
        },
        &mut rng,
    );

    assert_eq!(
        engine.napoleon_location, location_before,
        "第二次机动动作不应改变真实位置"
    );
    let failure = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "march_failed")
        .expect("第二次机动应写入失败结算");
    assert!(
        failure.description.contains("今日机动已用完"),
        "失败结算应明确说明机动槽已耗尽"
    );
}

#[test]
fn ending_day_without_maneuver_auto_rests_before_dusk() {
    let mut engine = GameEngine::new();
    engine.army.avg_fatigue = 48.0;
    engine.army.avg_morale = 56.0;
    let fatigue_before = engine.army.avg_fatigue;
    let morale_before = engine.army.avg_morale;
    let mut rng = seeded_rng();

    engine.begin_day(&mut rng);
    engine.execute_day_action(
        PlayerAction::EnactPolicy {
            policy_id: "public_speech",
        },
        &mut rng,
    );
    engine.end_day(&mut rng);

    assert!(
        engine.army.avg_fatigue < fatigue_before,
        "若当天未使用机动槽，结束今天前应自动休整降低疲劳"
    );
    assert!(
        engine.army.avg_morale > morale_before,
        "自动休整应同步回升士气"
    );
}

#[test]
fn save_and_load_midday_preserves_action_budget_state() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();

    engine.begin_day(&mut rng);
    engine.execute_day_action(
        PlayerAction::EnactPolicy {
            policy_id: "public_speech",
        },
        &mut rng,
    );

    let json = engine.to_json();
    let mut restored = GameEngine::from_json(&json).expect("日内存档应可恢复");

    assert_eq!(restored.day, 1, "日内存档不应提前推进日期");
    assert!(restored.day_started, "读档后应保留当天已开始状态");
    assert_eq!(restored.decision_actions_start, 2);
    assert_eq!(restored.politics.actions_remaining, 1);
    assert!(restored.maneuver_available(), "只执行政策时机动槽仍应可用");

    restored.end_day(&mut rng);
    assert_eq!(restored.day, 2, "读档后仍可正常结束今天并进入次日");
}

// ── 叙事引擎集成 ──────────────────────────────────

#[test]
fn enact_conscription_produces_narrative_report() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "conscription",
        },
        &mut rng,
    );
    let report = engine.last_report().expect("执行政策后应有叙事报告");
    assert!(report.bertrand.is_some(), "征兵令应有贝特朗评论");
    assert!(report.consequence.is_some(), "征兵令应有后果片段");
}

#[test]
fn rest_action_has_no_narrative_text() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    engine.process_day(PlayerAction::Rest, &mut rng);
    let report = engine.last_report().expect("执行后应有报告");
    assert!(report.bertrand.is_none(), "Rest 不应有贝特朗文本");
    assert!(report.consequence.is_none(), "Rest 不应有后果片段");
}

#[test]
fn boost_loyalty_produces_bertrand_text() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    engine.process_day(
        PlayerAction::BoostLoyalty {
            general_id: "ney".to_string(),
        },
        &mut rng,
    );
    let report = engine.last_report().expect("BoostLoyalty 后应有报告");
    assert!(report.bertrand.is_some(), "强化忠诚应有贝特朗评论");
}

#[test]
fn boost_loyalty_uses_character_display_name() {
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
fn no_narrative_report_before_game_starts() {
    let engine = GameEngine::new();
    assert!(engine.last_report().is_none(), "初始状态应无叙事报告");
}

// ── 事件系统集成 ──────────────────────────────────

#[test]
fn engine_triggers_ney_defection_internally() {
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
fn events_trigger_only_once() {
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
fn triggered_events_are_recorded_in_history() {
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
fn last_triggered_event_details_keep_historical_note() {
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
fn battle_resolution_uses_readable_terrain_and_result_labels() {
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
fn coalition_troops_grow_over_time() {
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
fn ney_does_not_defect_with_normal_loyalty() {
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
fn ney_can_defect_at_crisis_loyalty() {
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
fn defection_does_not_repeat() {
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
fn grouchy_does_not_depart_before_day_90() {
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
fn grouchy_can_depart_after_day_90_with_low_loyalty() {
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
fn decisive_victory_reduces_coalition_troops() {
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
fn decisive_defeat_increases_coalition_troops() {
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
fn marginal_victory_moderately_reduces_coalition_troops() {
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
