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
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_on_save_pressed")
	await await_idle_frame()
	var save_popup := scene.find_child("SaveSlotPickerPopup", true, false) as PopupPanel
	assert_object(save_popup).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	scene.call("_save_to_slot", 1, save_popup)
	await await_idle_frame()
	assert_bool(SaveManager.has_save(1)).is_true()
	assert_bool((scene.find_child("LoadGameButton", true, false) as Button).disabled).is_false()
	assert_bool(execute_button.disabled).is_false()

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


func test_save_slot_labels_show_readable_outcome_text() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_save_to_slot", 2, null)
	await await_idle_frame()
	scene.call("_on_load_pressed")
	await await_idle_frame()

	var load_popup := scene.find_child("LoadSlotPickerPopup", true, false) as PopupPanel
	var slot_button := load_popup.find_child("LoadSlotButton2", true, false) as Button
	assert_object(load_popup).is_not_null()
	assert_object(slot_button).is_not_null()
	assert_str(slot_button.text).contains("Day 1")
	assert_str(slot_button.text).contains("进行中")
	assert_bool(slot_button.text.contains("in_progress")).is_false()


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


func test_new_game_dialog_cancel_keeps_progress() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_on_new_game_pressed")
	await await_idle_frame()
	var confirm := scene.find_child("NewGameConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()
	_press_dialog_cancel(confirm)
	await runner.simulate_frames(2)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_load_dialog_cancel_keeps_current_progress() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_load_from_slot", 1, null)
	await await_idle_frame()
	var confirm := scene.find_child("LoadConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()
	_press_dialog_cancel(confirm)
	await runner.simulate_frames(2)

	assert_int(GameState.current_day).is_equal(2)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_save_slot_picker_cancel_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_on_save_pressed")
	await await_idle_frame()

	var save_popup := scene.find_child("SaveSlotPickerPopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("SlotPickerCancelButton", true, false) as Button
	assert_object(save_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("SaveSlotPickerPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


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


func test_battle_popup_cancel_keeps_action_phase() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_show_battle_popup")
	await await_idle_frame()

	var battle_popup := scene.find_child("BattlePopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("BattleCancelButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(battle_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BattlePopup", true, false)).is_null()
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_boost_popup_disables_confirm_when_legitimacy_too_low() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	GameState.legitimacy = 5.0
	scene.call("_show_boost_popup")
	await await_idle_frame()

	var boost_popup := scene.find_child("BoostPopup", true, false) as PopupPanel
	var confirm_button := scene.find_child("BoostConfirmButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(boost_popup).is_not_null()
	assert_object(confirm_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(confirm_button.disabled).is_true()
	assert_bool(execute_button.disabled).is_true()


func test_boost_popup_cancel_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_show_boost_popup")
	await await_idle_frame()

	var boost_popup := scene.find_child("BoostPopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("BoostCancelButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(boost_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BoostPopup", true, false)).is_null()
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_game_over_overlay_disables_action_and_shows_restart() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(execute_button).is_not_null()

	scene.call("_on_game_over", "political_collapse")
	await runner.simulate_frames(2)

	var overlay := scene.find_child("GameOverOverlay", true, false) as ColorRect
	var restart_button := scene.find_child("GameOverRestartButton", true, false) as Button
	var title_label := scene.find_child("GameOverTitleLabel", true, false) as Label
	assert_object(overlay).is_not_null()
	assert_object(restart_button).is_not_null()
	assert_object(title_label).is_not_null()
	assert_bool(execute_button.disabled).is_true()
	assert_str(title_label.text.strip_edges()).is_not_equal("")


func test_game_over_restart_resets_day_and_clears_overlay() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_on_game_over", "political_collapse")
	await runner.simulate_frames(2)
	var restart_button := scene.find_child("GameOverRestartButton", true, false) as Button
	assert_object(restart_button).is_not_null()

	restart_button.pressed.emit()
	await runner.simulate_frames(4)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_object(scene.find_child("GameOverOverlay", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_game_over_stats_clamp_display_day_to_100() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var dialogs_controller := scene.find_child("DialogsController", true, false)
	assert_object(dialogs_controller).is_not_null()

	dialogs_controller.call(
		"show_game_over",
		"waterloo_historical",
		{
			"current_day": 128,
			"legitimacy": 12.0,
			"victories": 4,
			"total_troops": 21000,
			"avg_morale": 44.0,
			"supply": 21.0
		}
	)
	await runner.simulate_frames(2)

	var stats_label := scene.find_child("GameOverStatsLabel", true, false) as Label
	assert_object(stats_label).is_not_null()
	assert_str(stats_label.text).contains("天数: 100")


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	return runner


func _press_dialog_cancel(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return
	if dialog.has_method("get_cancel_button"):
		var cancel_button := dialog.get_cancel_button()
		if cancel_button != null:
			cancel_button.pressed.emit()
			return
	dialog.canceled.emit()
	dialog.hide()


func _cleanup_saves() -> void:
	for slot_id in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_save(slot_id)
