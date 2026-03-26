mod common;

use cent_jours_core::engine::{GameEngine, PlayerAction};
use proptest::prelude::*;
use serde_json::json;

use common::seeded_rng;

#[test]
fn 存档往返会保留前沿粮秣站与区域任务字段() {
    let mut engine = GameEngine::new();
    let mut rng = seeded_rng();

    engine.process_day(
        PlayerAction::EnactPolicy {
            policy_id: "establish_forward_depot",
        },
        &mut rng,
    );

    let saved = engine.save();
    assert_eq!(saved.version, 3, "当前存档版本应为 v3");
    assert_eq!(saved.forward_depot_location, "golfe_juan");
    assert!(saved.forward_depot_capacity_bonus > 0);

    let restored = GameEngine::from_json(&engine.to_json()).expect("存档往返应成功");
    let restored_saved = restored.save();

    assert_eq!(
        restored_saved.forward_depot_location,
        saved.forward_depot_location
    );
    assert_eq!(
        restored_saved.forward_depot_capacity_bonus,
        saved.forward_depot_capacity_bonus
    );
    assert_eq!(restored_saved.forward_depot_days, saved.forward_depot_days);
    assert_eq!(restored_saved.regional_task_id, saved.regional_task_id);
    assert_eq!(
        restored_saved.regional_task_progress,
        saved.regional_task_progress
    );
    assert_eq!(
        restored_saved.regional_task_completed,
        saved.regional_task_completed
    );
}

#[test]
fn v1_save_migrates_legacy_event_id_without_duplicates() {
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
            "ney_defection",
            "tuileries_eve"
        ],
        "outcome": null
    })
    .to_string();

    let restored = GameEngine::from_json(&json).expect("v1 存档应可加载");
    let triggered = restored.triggered_events();

    assert!(
        !triggered.iter().any(|id| id == "fontainebleau_eve"),
        "旧 ID 不应继续出现在触发列表中"
    );
    assert_eq!(
        triggered
            .iter()
            .filter(|id| id.as_str() == "tuileries_eve")
            .count(),
        1,
        "迁移后应只保留一个新 ID"
    );
}

proptest! {
    #[test]
    fn migrated_event_ids_never_keep_legacy_fontainebleau_id(
        ids in prop::collection::vec(
            prop_oneof![
                Just("fontainebleau_eve".to_string()),
                Just("tuileries_eve".to_string()),
                Just("ney_defection".to_string()),
                Just("waterloo_eve".to_string()),
            ],
            0..12
        )
    ) {
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
            "triggered_event_ids": ids,
            "outcome": null
        }).to_string();

        let restored = GameEngine::from_json(&json).expect("随机 v1 存档应可加载");
        let triggered = restored.triggered_events();

        prop_assert!(
            !triggered.iter().any(|id| id == "fontainebleau_eve"),
            "迁移后不应残留旧 ID"
        );
        prop_assert!(
            triggered
                .iter()
                .filter(|id| id.as_str() == "tuileries_eve")
                .count() <= 1,
            "迁移后新 ID 最多只保留一个"
        );
    }
}
