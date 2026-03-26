mod common;

use cent_jours_core::battle::{
    move_army, update_supply_with_capacity, ArmyState as MarchArmyState,
};
use cent_jours_core::engine::GameEngine;
use proptest::prelude::*;

use common::{adjacent_pairs, campaign_map};

#[test]
fn 非相邻节点的行军预判应返回无效原因() {
    let engine = GameEngine::new();
    let preview = engine.preview_march("paris");

    assert!(!preview.valid);
    assert!(
        preview
            .reason
            .as_deref()
            .unwrap_or_default()
            .contains("不相邻"),
        "非法落点应直接给出原因"
    );
}

#[test]
fn 合法落点的预判应返回后续风险拆解() {
    let engine = GameEngine::new();
    let preview = engine.preview_march("antibes");

    assert!(preview.valid);
    assert!(preview.follow_up_total_options >= preview.follow_up_safe_options);
    assert!(preview.follow_up_total_options >= preview.follow_up_risky_options);
    assert!(
        !preview.follow_up_status_id.is_empty(),
        "合法预判应带出第二跳风险状态"
    );
}

proptest! {
    #[test]
    fn 补给更新始终把结果钳制在合法范围内(
        troops in 1u32..200_000,
        morale in 0.0f64..100.0,
        fatigue in 0.0f64..100.0,
        supply in 0.0f64..100.0,
        line_efficiency in 0.0f64..2.0,
        supply_capacity in 1u32..16
    ) {
        let army = MarchArmyState {
            id: "prop".to_string(),
            location: "paris".to_string(),
            troops,
            morale,
            fatigue,
            supply,
        };

        let result = update_supply_with_capacity(&army, line_efficiency, supply_capacity);

        prop_assert!((0.0..=100.0).contains(&result.new_supply));
        prop_assert!(result.demand >= 0.0);
        prop_assert!(result.available >= 0.0);
        prop_assert_eq!(result.line_efficiency, line_efficiency);
    }
}

proptest! {
    #[test]
    fn 合法相邻行军不会把士气和疲劳推出边界(
        pair in prop::sample::select(adjacent_pairs()),
        forced in any::<bool>(),
        troops in 1u32..150_000,
        morale in 0.0f64..100.0,
        fatigue in 0.0f64..100.0,
        supply in 0.0f64..100.0
    ) {
        let map = campaign_map();
        let (from, to) = pair;
        let army = MarchArmyState {
            id: "prop".to_string(),
            location: from,
            troops,
            morale,
            fatigue,
            supply,
        };

        let result = move_army(&army, &to, forced, &map);

        prop_assert!(result.success);
        prop_assert_eq!(result.new_location, to);
        prop_assert!((0.0..=100.0).contains(&result.new_fatigue));
        prop_assert!((0.0..=100.0).contains(&result.new_morale));
        prop_assert_eq!(result.forced_march, forced);
    }
}
