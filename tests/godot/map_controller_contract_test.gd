@warning_ignore_start("redundant_await")
extends GdUnitTestSuite

const __source = "res://src/ui/main_menu/map_controller.gd"
const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"


func before_test() -> void:
	TurnManager.reset_engine()
	GameState.triggered_events.clear()


func after_test() -> void:
	TurnManager.reset_engine()


func test_hover_preview_and_locked_detail_use_separate_panels() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var hover_panel := scene.find_child("MapHoverPanel", true, false) as PanelContainer
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer

	controller.set_hovered_node_id("lyon")
	await runner.simulate_frames(4)
	assert_bool(hover_panel.visible).is_true()
	assert_bool(inspector_panel.visible).is_false()

	controller.select_node("lyon")
	await runner.simulate_frames(4)
	assert_bool(hover_panel.visible).is_false()
	assert_bool(inspector_panel.visible).is_true()
	assert_str(controller.get_selected_node_id()).is_equal("lyon")


func test_map_zoom_can_expand_and_reset() -> void:
	var runner := await _load_main_menu()
	var controller = runner.get_property("_map_controller")

	controller.set_map_zoom(1.8)
	await runner.simulate_frames(4)
	assert_bool(absf(controller.get_map_zoom() - 1.8) < 0.01).is_true()

	var reset_event := InputEventMouseButton.new()
	reset_event.button_index = MOUSE_BUTTON_RIGHT
	reset_event.pressed = true
	controller.on_map_canvas_gui_input(reset_event)
	await runner.simulate_frames(4)

	assert_bool(absf(controller.get_map_zoom() - 1.0) < 0.01).is_true()


func test_selecting_node_populates_inspector_title() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_title := scene.find_child("MapInspectorTitle", true, false) as Label

	controller.select_node("paris")
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("paris")
	assert_str(inspector_title.text).contains("Paris")


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	return runner
