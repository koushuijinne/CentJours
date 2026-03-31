@warning_ignore_start("redundant_await")
extends GdUnitTestSuite

const __source = "res://src/ui/main_menu.gd"
const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"


func before_test() -> void:
	TurnManager.reset_engine()
	GameState.triggered_events.clear()


func after_test() -> void:
	TurnManager.reset_engine()


func test_main_menu_bootstraps_primary_controls() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var day_label := scene.find_child("DayLabel", true, false) as Label
	var tray_hint := scene.find_child("TrayHint", true, false) as Label
	var map_subtitle := scene.find_child("MapSubtitle", true, false) as Label
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var end_day_button := scene.find_child("EndDayButton", true, false) as Button
	var load_button := scene.find_child("LoadGameButton", true, false) as Button
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label

	assert_object(day_label).is_not_null()
	assert_object(tray_hint).is_not_null()
	assert_object(map_subtitle).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_object(end_day_button).is_not_null()
	assert_object(load_button).is_not_null()
	assert_object(narrative_body).is_not_null()

	assert_str(day_label.text).is_equal("第 1 天")
	assert_str(tray_hint.text).contains("今日节奏：")
	assert_str(tray_hint.text).contains("前10天教程：")
	assert_bool(map_subtitle.text != tray_hint.text).is_true()
	assert_bool(execute_button.disabled).is_false()
	assert_bool(end_day_button.disabled).is_false()
	assert_bool(load_button.disabled).is_true()
	assert_str(narrative_body.text).contains("第 1 天")


func test_tutorial_popup_keeps_readable_width_for_long_chinese_copy() -> void:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	var scene := runner.scene()
	var popup := scene.find_child("TutorialPopup", true, false) as PopupPanel
	var scroll := scene.find_child("TutorialPopupScroll", true, false) as ScrollContainer
	var body := scene.find_child("TutorialPopupBody", true, false) as Label

	assert_object(popup).is_not_null()
	assert_object(scroll).is_not_null()
	assert_object(body).is_not_null()
	assert_int(int(roundf(popup.size.x))).is_greater_equal(600)
	assert_int(int(roundf(scroll.size.x))).is_greater_equal(520)
	assert_int(int(roundf(body.size.x))).is_greater_equal(500)
	assert_str(body.text).contains("前10天教程")

	await _dismiss_tutorial_popup_if_present(scene, runner)


func test_policy_action_stays_in_same_day_until_end_day() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")

	assert_int(GameState.current_day).is_equal(1)
	assert_int(GameState.actions_remaining).is_equal(2)
	assert_bool(GameState.maneuver_available).is_true()

	tray_controller.select_policy("public_speech")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_int(GameState.actions_remaining).is_equal(1)
	assert_bool(GameState.maneuver_available).is_true()
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_str((scene.find_child("DayLabel", true, false) as Label).text).is_equal("第 1 天")

	await _end_day(scene, runner)
	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")


func test_narrative_panel_keeps_scroll_container_and_appends_entries() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var narrative_scroll := scene.find_child("NarrativeScroll", true, false) as ScrollContainer
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label

	assert_object(narrative_scroll).is_not_null()
	assert_object(narrative_body).is_not_null()
	assert_str(narrative_body.text).contains("第 1 天")

	scene.call("_on_action_resolution_logged", "policy", "测试结算描述", ["补给 +4", "士气 +2"])
	await runner.simulate_frames(2)
	scene.call("_on_micro_narrative", "policy", "测试微叙事")
	await runner.simulate_frames(2)

	assert_str(String(narrative_body.get_parent().name)).is_equal("NarrativeScroll")
	assert_str(narrative_body.text).contains("测试结算描述")
	assert_str(narrative_body.text).contains("测试微叙事")
	assert_str(narrative_body.text).contains("-----")


func test_situation_panel_includes_regional_task_context() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var situation_body := scene.find_child("SituationBody", true, false) as Label

	assert_object(situation_body).is_not_null()
	assert_bool(GameState.logistics_regional_task_title.strip_edges() != "").is_true()
	assert_bool(GameState.logistics_regional_task_progress_label.strip_edges() != "").is_true()
	assert_str(situation_body.text).contains("合法性")
	assert_str(situation_body.text).contains(GameState.logistics_regional_task_title)
	assert_str(situation_body.text).contains(GameState.logistics_regional_task_progress_label)


func test_rest_action_consumes_maneuver_until_end_day() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(execute_button).is_not_null()
	assert_int(GameState.current_day).is_equal(1)

	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(GameState.maneuver_available).is_false()
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_bool(execute_button.disabled).is_false()

	await _end_day(scene, runner)
	assert_int(GameState.current_day).is_equal(2)
	assert_bool(GameState.maneuver_available).is_true()


func test_policy_action_triggers_cooldown_after_end_day() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	assert_int(GameState.current_day).is_equal(1)

	tray_controller.select_policy("public_speech")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)
	await _end_day(scene, runner)

	assert_int(GameState.current_day).is_equal(2)
	var card := tray_controller.get_card("public_speech") as Node
	assert_object(card).is_not_null()
	assert_bool(card.on_cooldown).is_true()


func test_march_confirm_without_target_shows_selection_guidance() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label
	assert_object(execute_button).is_not_null()
	assert_object(narrative_body).is_not_null()

	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(2)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()
	assert_str(narrative_body.text).contains("请先在地图上选择一个与当前位置相邻的节点")


func test_invalid_march_target_shows_rejection_feedback() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var controller = runner.get_property("_map_controller")
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label
	assert_object(narrative_body).is_not_null()

	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	controller.select_node("paris")
	await runner.simulate_frames(4)

	assert_str(controller.get_pending_march_target()).is_equal("")
	assert_str(narrative_body.text).contains("无法在一天内抵达")


func test_valid_march_target_updates_location_before_end_day() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var controller = runner.get_property("_map_controller")
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label
	assert_bool(GameState.available_march_targets.size() > 0).is_true()
	assert_object(narrative_body).is_not_null()

	var target_node := String(GameState.available_march_targets[0])
	var target_label := String(controller.get_map_node(target_node).get("name_fr", target_node))

	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	controller.select_node(target_node)
	await runner.simulate_frames(4)

	assert_str(controller.get_pending_march_target()).is_equal(target_node)
	assert_str(narrative_body.text).contains(target_label)

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_str(GameState.napoleon_location).is_equal(target_node)
	assert_bool(GameState.maneuver_available).is_false()
	assert_str(controller.get_pending_march_target()).is_equal("")
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")

	await _end_day(scene, runner)
	assert_int(GameState.current_day).is_equal(2)


func test_switching_away_from_march_clears_pending_target() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var controller = runner.get_property("_map_controller")
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label
	assert_bool(GameState.available_march_targets.size() > 0).is_true()
	assert_object(narrative_body).is_not_null()

	var target_node := String(GameState.available_march_targets[0])
	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	controller.select_node(target_node)
	await runner.simulate_frames(4)
	assert_str(controller.get_pending_march_target()).is_equal(target_node)

	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)

	assert_str(controller.get_pending_march_target()).is_equal("")
	assert_str(narrative_body.text).contains("休整")


func test_strategy_goals_popup_opens_from_topbar() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var strategy_button := scene.find_child("StrategyGoalsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(strategy_button).is_not_null()
	assert_object(execute_button).is_not_null()

	strategy_button.pressed.emit()
	await runner.simulate_frames(2)

	var popup := scene.find_child("StrategyGoalsPopup", true, false) as PopupPanel
	var body := scene.find_child("StrategyGoalsPopupBody", true, false) as Label
	assert_object(popup).is_not_null()
	assert_object(body).is_not_null()
	assert_bool(execute_button.disabled).is_true()
	assert_str(body.text).contains("可达成结局")


func test_glossary_popup_opens_from_topbar() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var glossary_button := scene.find_child("GlossaryButton", true, false) as Button
	assert_object(glossary_button).is_not_null()

	glossary_button.pressed.emit()
	await runner.simulate_frames(2)

	var popup := scene.find_child("GlossaryPopup", true, false) as PopupPanel
	var body := scene.find_child("GlossaryPopupBody", true, false) as Label
	assert_object(popup).is_not_null()
	assert_object(body).is_not_null()
	assert_str(body.text).contains("红 / 黑指数")
	assert_str(body.text).contains("合法性")
	assert_str(body.text).contains("如何提高合法性")
	assert_str(body.text).contains("当前倾向")
	assert_str(body.text).contains("每天会多 1 个决策点")


func test_narrative_log_popup_replays_existing_entries() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var log_button := scene.find_child("NarrativeLogButton", true, false) as Button
	assert_object(log_button).is_not_null()

	scene.call("_on_action_resolution_logged", "policy", "测试结算描述", ["补给 +4"])
	await runner.simulate_frames(2)
	log_button.pressed.emit()
	await runner.simulate_frames(2)

	var popup := scene.find_child("NarrativeLogPopup", true, false) as PopupPanel
	var body := scene.find_child("NarrativeLogPopupBody", true, false) as Label
	assert_object(popup).is_not_null()
	assert_object(body).is_not_null()
	assert_str(body.text).contains("测试结算描述")


func test_exhausted_decision_points_disable_policy_cards_but_keep_maneuver_cards_live() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(execute_button).is_not_null()

	for policy_id in ["public_speech", "constitutional_promise"]:
		tray_controller.select_policy(policy_id)
		await runner.simulate_frames(2)
		runner.invoke("_on_confirm_pressed")
		await runner.simulate_frames(6)

	assert_int(GameState.actions_remaining).is_equal(0)
	assert_bool(GameState.maneuver_available).is_true()

	var speech_card := tray_controller.get_card("public_speech") as DecisionCard
	var promise_card := tray_controller.get_card("constitutional_promise") as DecisionCard
	var boost_card := tray_controller.get_card("boost_loyalty") as DecisionCard
	var march_card := tray_controller.get_card("march") as DecisionCard
	var battle_card := tray_controller.get_card("battle") as DecisionCard
	assert_object(speech_card).is_not_null()
	assert_object(promise_card).is_not_null()
	assert_object(boost_card).is_not_null()
	assert_object(march_card).is_not_null()
	assert_object(battle_card).is_not_null()
	assert_bool(speech_card.is_disabled).is_true()
	assert_bool(promise_card.is_disabled).is_true()
	assert_bool(boost_card.is_disabled).is_true()
	assert_bool(march_card.is_disabled).is_false()
	assert_bool(battle_card.is_disabled).is_false()

	tray_controller.select_policy("public_speech")
	await runner.simulate_frames(2)
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_bool(execute_button.disabled).is_false()


func test_two_consecutive_days_rest_then_march() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var controller = runner.get_property("_map_controller")
	assert_int(GameState.current_day).is_equal(1)

	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)
	await _end_day(scene, runner)
	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")

	assert_bool(GameState.available_march_targets.size() > 0).is_true()
	var target_node := String(GameState.available_march_targets[0])
	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	controller.select_node(target_node)
	await runner.simulate_frames(4)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.napoleon_location).is_equal(target_node)
	await _end_day(scene, runner)

	assert_int(GameState.current_day).is_equal(3)
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	await _dismiss_tutorial_popup_if_present(runner.scene(), runner)
	return runner


func _end_day(scene: Node, runner: GdUnitSceneRunner) -> void:
	await _dismiss_tutorial_popup_if_present(scene, runner)
	var end_day_button := scene.find_child("EndDayButton", true, false) as Button
	assert_object(end_day_button).is_not_null()
	end_day_button.pressed.emit()
	await runner.simulate_frames(8)
	await _dismiss_tutorial_popup_if_present(scene, runner)


func _dismiss_tutorial_popup_if_present(scene: Node, runner: GdUnitSceneRunner) -> void:
	var close_button := scene.find_child("TutorialPopupCloseButton", true, false) as Button
	if close_button == null:
		return
	close_button.pressed.emit()
	await runner.simulate_frames(2)
