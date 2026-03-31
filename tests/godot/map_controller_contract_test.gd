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


func test_hover_preview_and_locked_detail_share_anchor_and_scroll_guards() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var hover_panel := scene.find_child("MapHoverPanel", true, false) as PanelContainer
	var hover_scroll := scene.find_child("MapHoverScroll", true, false) as ScrollContainer
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer
	var inspector_scroll := scene.find_child("MapInspectorScroll", true, false) as ScrollContainer

	controller.set_hovered_node_id("golfe_juan")
	await runner.simulate_frames(4)

	assert_object(hover_panel).is_not_null()
	assert_object(hover_scroll).is_not_null()
	assert_bool(hover_panel.visible).is_true()
	assert_int(hover_scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	assert_int(hover_scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)

	var hover_rect := hover_panel.get_global_rect()

	controller.select_node("golfe_juan")
	await runner.simulate_frames(4)

	assert_object(inspector_panel).is_not_null()
	assert_object(inspector_scroll).is_not_null()
	assert_bool(inspector_panel.visible).is_true()
	assert_int(inspector_scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	assert_int(inspector_scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)

	var inspector_rect := inspector_panel.get_global_rect()
	assert_bool(absf((hover_rect.position.x + hover_rect.size.x) - (inspector_rect.position.x + inspector_rect.size.x)) < 1.0).is_true()
	assert_bool(absf(hover_rect.position.y - inspector_rect.position.y) < 1.0).is_true()
	assert_bool(absf(hover_rect.size.y - inspector_rect.size.y) < 1.0).is_true()


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


func test_locked_selection_ignores_hover_from_other_node() -> void:
	var runner := await _load_main_menu()
	var controller = runner.get_property("_map_controller")

	controller.select_node("paris")
	await runner.simulate_frames(4)
	controller.set_hovered_node_id("lyon")
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("paris")
	assert_str(controller.get_hovered_node_id()).is_equal("paris")


func test_clicking_selected_node_again_clears_locked_detail() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer

	controller.select_node("paris")
	await runner.simulate_frames(4)
	assert_bool(inspector_panel.visible).is_true()

	var hotspot: Control = controller.get_map_node_controls_by_id().get("paris", null)
	assert_object(hotspot).is_not_null()
	controller.on_map_node_gui_input(_left_click_event(), "paris", hotspot)
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("")
	assert_str(controller.get_hovered_node_id()).is_equal("")
	assert_bool(inspector_panel.visible).is_false()


func test_clicking_empty_canvas_clears_interaction_state() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer
	var hover_panel := scene.find_child("MapHoverPanel", true, false) as PanelContainer

	controller.select_node("lyon")
	await runner.simulate_frames(4)
	assert_bool(inspector_panel.visible).is_true()

	controller.on_map_canvas_gui_input(_left_click_event())
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("")
	assert_str(controller.get_hovered_node_id()).is_equal("")
	assert_bool(inspector_panel.visible).is_false()
	assert_bool(hover_panel.visible).is_false()


func test_mouse_motion_after_canvas_clear_restores_hover_preview() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var hover_panel := scene.find_child("MapHoverPanel", true, false) as PanelContainer

	controller.select_node("lyon")
	await runner.simulate_frames(4)
	controller.on_map_canvas_gui_input(_left_click_event())
	await runner.simulate_frames(4)

	assert_str(controller.get_hovered_node_id()).is_equal("")
	assert_bool(hover_panel.visible).is_false()

	var hotspot: Control = controller.get_map_node_controls_by_id().get("chalon", null)
	assert_object(hotspot).is_not_null()
	controller.on_map_node_gui_input(_mouse_motion_event(), "chalon", hotspot)
	await runner.simulate_frames(2)

	assert_str(controller.get_hovered_node_id()).is_equal("chalon")
	assert_bool(hover_panel.visible).is_true()


func test_clicking_locked_inspector_background_clears_interaction_state() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer

	controller.select_node("lyon")
	await runner.simulate_frames(4)
	assert_bool(inspector_panel.visible).is_true()

	controller.on_map_inspector_gui_input(_left_click_event())
	await runner.simulate_frames(4)

	assert_str(controller.get_selected_node_id()).is_equal("")
	assert_str(controller.get_hovered_node_id()).is_equal("")
	assert_bool(inspector_panel.visible).is_false()


func test_right_click_zoom_reset_preserves_locked_selection() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var controller = runner.get_property("_map_controller")
	var inspector_panel := scene.find_child("MapInspectorPanel", true, false) as PanelContainer

	controller.set_map_zoom(1.8)
	controller.select_node("lyon")
	await runner.simulate_frames(4)

	controller.on_map_canvas_gui_input(_right_click_event())
	await runner.simulate_frames(4)

	assert_bool(absf(controller.get_map_zoom() - 1.0) < 0.01).is_true()
	assert_str(controller.get_selected_node_id()).is_equal("lyon")
	assert_bool(inspector_panel.visible).is_true()


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	var close_button := runner.scene().find_child("TutorialPopupCloseButton", true, false) as Button
	if close_button != null:
		close_button.pressed.emit()
		await runner.simulate_frames(2)
	return runner


func _left_click_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _right_click_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event


func _mouse_motion_event() -> InputEventMouseMotion:
	return InputEventMouseMotion.new()
