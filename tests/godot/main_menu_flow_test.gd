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
	var load_button := scene.find_child("LoadGameButton", true, false) as Button
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label

	assert_object(day_label).is_not_null()
	assert_object(tray_hint).is_not_null()
	assert_object(map_subtitle).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_object(load_button).is_not_null()
	assert_object(narrative_body).is_not_null()

	assert_str(day_label.text).is_equal("Jour 1")
	assert_bool(tray_hint.text.begins_with("前10天教程：")).is_true()
	assert_bool(map_subtitle.text != tray_hint.text).is_true()
	assert_bool(execute_button.disabled).is_false()
	assert_bool(load_button.disabled).is_true()
	assert_str(narrative_body.text).contains("Jour 1")


func test_execute_action_advances_day_and_returns_to_action_phase() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()
	assert_str((scene.find_child("DayLabel", true, false) as Label).text).is_equal("Jour 2")


func test_narrative_panel_keeps_scroll_container_and_appends_entries() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var narrative_scroll := scene.find_child("NarrativeScroll", true, false) as ScrollContainer
	var narrative_body := scene.find_child("NarrativeBody", true, false) as Label

	assert_object(narrative_scroll).is_not_null()
	assert_object(narrative_body).is_not_null()
	assert_str(narrative_body.text).contains("Jour 1")

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
	assert_str(situation_body.text).contains(GameState.logistics_regional_task_title)
	assert_str(situation_body.text).contains(GameState.logistics_regional_task_progress_label)


func test_rest_action_advances_day_without_popup() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(execute_button).is_not_null()
	assert_int(GameState.current_day).is_equal(1)

	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(10)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_bool(execute_button.disabled).is_false()


func test_policy_action_triggers_cooldown_on_next_day() -> void:
	var runner := await _load_main_menu()
	var tray_controller = runner.get_property("_tray_controller")
	assert_int(GameState.current_day).is_equal(1)

	tray_controller.select_policy("public_speech")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(10)

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


func test_valid_march_target_confirm_advances_day_and_updates_location() -> void:
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
	await runner.simulate_frames(10)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")
	assert_str(GameState.napoleon_location).is_equal(target_node)
	assert_str(controller.get_pending_march_target()).is_equal("")
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")


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


func test_two_consecutive_days_rest_then_march() -> void:
	var runner := await _load_main_menu()
	var tray_controller = runner.get_property("_tray_controller")
	var controller = runner.get_property("_map_controller")
	assert_int(GameState.current_day).is_equal(1)

	# Day 1: rest
	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(10)
	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")

	# Day 2: march to adjacent node
	assert_bool(GameState.available_march_targets.size() > 0).is_true()
	var target_node := String(GameState.available_march_targets[0])
	tray_controller.select_policy("march")
	await runner.simulate_frames(2)
	controller.select_node(target_node)
	await runner.simulate_frames(4)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(10)

	assert_int(GameState.current_day).is_equal(3)
	assert_str(GameState.napoleon_location).is_equal(target_node)
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	return runner
