@warning_ignore_start("redundant_await")
extends GdUnitTestSuite

const __source = "res://src/ui/main_menu.gd"
const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"


func before_test() -> void:
	_cleanup_saves()
	TurnManager.reset_engine()
	GameState.triggered_events.clear()


func after_test() -> void:
	_cleanup_saves()
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


func test_save_then_load_restores_day_one() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_on_save_pressed")
	await await_idle_frame()
	var save_popup := scene.find_child("SaveSlotPickerPopup", true, false) as PopupPanel
	assert_object(save_popup).is_not_null()

	scene.call("_save_to_slot", 1, save_popup)
	await await_idle_frame()
	assert_bool(SaveManager.has_save(1)).is_true()
	assert_bool((scene.find_child("LoadGameButton", true, false) as Button).disabled).is_false()

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_load_from_slot", 1, null)
	await await_idle_frame()
	var confirm := scene.find_child("LoadConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	confirm.confirmed.emit()
	await runner.simulate_frames(4)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_str((scene.find_child("DayLabel", true, false) as Label).text).is_equal("Jour 1")


func test_load_slot_picker_reflects_slot_availability() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_on_load_pressed")
	await await_idle_frame()
	var empty_popup := scene.find_child("LoadSlotPickerPopup", true, false) as PopupPanel
	assert_object(empty_popup).is_not_null()
	assert_bool((empty_popup.find_child("LoadSlotButton1", true, false) as Button).disabled).is_true()
	assert_bool((empty_popup.find_child("LoadSlotButton2", true, false) as Button).disabled).is_true()
	assert_bool((empty_popup.find_child("LoadSlotButton3", true, false) as Button).disabled).is_true()
	empty_popup.queue_free()
	await await_idle_frame()

	scene.call("_save_to_slot", 2, null)
	await await_idle_frame()
	assert_bool(SaveManager.has_save(2)).is_true()

	scene.call("_on_load_pressed")
	await await_idle_frame()
	var load_popup := scene.find_child("LoadSlotPickerPopup", true, false) as PopupPanel
	assert_object(load_popup).is_not_null()
	assert_bool((load_popup.find_child("LoadSlotButton1", true, false) as Button).disabled).is_true()
	assert_bool((load_popup.find_child("LoadSlotButton2", true, false) as Button).disabled).is_false()
	assert_bool((load_popup.find_child("LoadSlotButton3", true, false) as Button).disabled).is_true()


func test_new_game_dialog_restarts_after_confirmation() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_on_new_game_pressed")
	await await_idle_frame()
	var confirm := scene.find_child("NewGameConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	confirm.confirmed.emit()
	await runner.simulate_frames(4)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_str((scene.find_child("DayLabel", true, false) as Label).text).is_equal("Jour 1")


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


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	return runner


func _cleanup_saves() -> void:
	for slot_id in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_save(slot_id)
