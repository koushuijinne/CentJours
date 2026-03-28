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


func test_existing_save_slot_requires_overwrite_confirmation() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_on_save_pressed")
	await await_idle_frame()
	var save_popup := scene.find_child("SaveSlotPickerPopup", true, false) as PopupPanel
	var overwrite_button := scene.find_child("SaveSlotButton1", true, false) as Button
	assert_object(save_popup).is_not_null()
	assert_object(overwrite_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	overwrite_button.pressed.emit()
	await await_idle_frame()
	var confirm := scene.find_child("SaveOverwriteConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	confirm.confirmed.emit()
	await runner.simulate_frames(2)

	var meta := SaveManager.get_save_meta(1)
	assert_int(int(meta.get("day", 0))).is_equal(2)
	assert_object(scene.find_child("SaveSlotPickerPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_delete_save_from_load_picker_removes_slot() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var load_button := scene.find_child("LoadGameButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	assert_bool(SaveManager.has_save(1)).is_true()
	assert_bool(load_button.disabled).is_false()

	scene.call("_on_load_pressed")
	await await_idle_frame()
	var load_popup := scene.find_child("LoadSlotPickerPopup", true, false) as PopupPanel
	var delete_button := scene.find_child("LoadDeleteSlotButton1", true, false) as Button
	assert_object(load_popup).is_not_null()
	assert_object(delete_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	delete_button.pressed.emit()
	await await_idle_frame()
	var confirm := scene.find_child("DeleteSaveConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	confirm.confirmed.emit()
	await runner.simulate_frames(2)

	assert_bool(SaveManager.has_save(1)).is_false()
	assert_bool(load_button.disabled).is_true()
	assert_object(scene.find_child("LoadSlotPickerPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_delete_save_from_save_picker_removes_slot() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var load_button := scene.find_child("LoadGameButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	assert_bool(SaveManager.has_save(1)).is_true()
	assert_bool(load_button.disabled).is_false()

	scene.call("_on_save_pressed")
	await await_idle_frame()

	var save_popup := scene.find_child("SaveSlotPickerPopup", true, false) as PopupPanel
	var delete_button := scene.find_child("SaveDeleteSlotButton1", true, false) as Button
	assert_object(save_popup).is_not_null()
	assert_object(delete_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	delete_button.pressed.emit()
	await await_idle_frame()
	var confirm := scene.find_child("DeleteSaveConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	confirm.confirmed.emit()
	await runner.simulate_frames(2)

	assert_bool(SaveManager.has_save(1)).is_false()
	assert_bool(load_button.disabled).is_true()
	assert_object(scene.find_child("SaveSlotPickerPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_save_overwrite_cancel_keeps_picker_open() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	scene.call("_on_save_pressed")
	await await_idle_frame()

	var overwrite_button := scene.find_child("SaveSlotButton1", true, false) as Button
	assert_object(overwrite_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	overwrite_button.pressed.emit()
	await await_idle_frame()
	var confirm := scene.find_child("SaveOverwriteConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()

	_press_dialog_cancel(confirm)
	await runner.simulate_frames(2)

	assert_object(scene.find_child("SaveOverwriteConfirmDialog", true, false)).is_null()
	assert_object(scene.find_child("SaveSlotPickerPopup", true, false)).is_not_null()
	assert_bool(execute_button.disabled).is_true()


func test_delete_save_cancel_keeps_load_picker_open() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	scene.call("_on_load_pressed")
	await await_idle_frame()

	var delete_button := scene.find_child("LoadDeleteSlotButton1", true, false) as Button
	assert_object(delete_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	delete_button.pressed.emit()
	await await_idle_frame()
	var confirm := scene.find_child("DeleteSaveConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()

	_press_dialog_cancel(confirm)
	await runner.simulate_frames(2)

	assert_object(scene.find_child("DeleteSaveConfirmDialog", true, false)).is_null()
	assert_object(scene.find_child("LoadSlotPickerPopup", true, false)).is_not_null()
	assert_bool(execute_button.disabled).is_true()


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


func test_loading_save_clears_locked_map_selection() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer
	assert_object(inspector_panel).is_not_null()

	controller.select_node("paris")
	await runner.simulate_frames(4)
	assert_str(controller.get_selected_node_id()).is_equal("paris")
	assert_bool(inspector_panel.visible).is_true()

	scene.call("_save_to_slot", 1, null)
	await await_idle_frame()
	scene.call("_load_from_slot", 1, null)
	await await_idle_frame()

	var confirm := scene.find_child("LoadConfirmDialog", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	confirm.confirmed.emit()
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("")
	assert_str(controller.get_hovered_node_id()).is_equal("")
	assert_bool(inspector_panel.visible).is_false()


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
