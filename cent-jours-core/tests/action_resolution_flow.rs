mod common;

use approx::assert_abs_diff_eq;
use cent_jours_core::engine::{GameEngine, PlayerAction};

use common::seeded_rng;

#[test]
fn 政策行动会推进日期并产出政策结算() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    let before_day = engine.current_day();

    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "increase_military_budget",
        },
        &mut rng,
    );

    assert_eq!(engine.current_day(), before_day + 1);
    let policy_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "policy")
        .expect("应存在政策结算事件");
    assert!(policy_event.description.contains("增加军费"));
    assert!(
        policy_event
            .effects
            .iter()
            .any(|effect| effect.contains("军方")),
        "政策结算应暴露核心派系变化"
    );
}

#[test]
fn 未注册政策会返回失败事件而不是静默吞掉() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();
    let before_day = engine.current_day();

    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "missing_policy",
        },
        &mut rng,
    );

    assert_eq!(engine.current_day(), before_day + 1);
    let failed_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "policy_failed")
        .expect("未知政策应明确返回失败事件");
    assert!(failed_event.description.contains("missing_policy"));
    assert!(
        failed_event
            .effects
            .iter()
            .any(|effect| effect.contains("未在内置政策表中注册")),
        "失败原因应对外可见"
    );
}

#[test]
fn 行军结算会兑现预判落点与资源变化() {
    let mut engine = GameEngine::new();
    let preview = engine.preview_march("antibes");
    let mut rng = seeded_rng();
    let before_day = engine.current_day();

    assert!(preview.valid, "昂蒂布应是起始位置的合法目标");

    engine.process_day(
        PlayerAction::March {
            target_node: "antibes".to_string(),
        },
        &mut rng,
    );

    assert_eq!(engine.current_day(), before_day + 1);
    assert_eq!(engine.napoleon_location, preview.target_node);
    assert_abs_diff_eq!(
        engine.army.avg_fatigue,
        preview.projected_fatigue,
        epsilon = 0.001
    );
    assert_abs_diff_eq!(
        engine.army.avg_morale,
        preview.projected_morale,
        epsilon = 0.001
    );
    assert_abs_diff_eq!(
        engine.army.supply,
        preview.projected_supply,
        epsilon = 0.001
    );

    let march_event = engine
        .last_action_events()
        .iter()
        .find(|event| event.event_type == "march")
        .expect("行军后应有 march 事件");
    assert!(march_event.description.contains("行军"));
}
