extends Node
class_name MainMenuLayoutController

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")

var _tray_controller: MainMenuTrayController = null

var _root_layout: VBoxContainer = null
var _main_area: HBoxContainer = null
var _left_column: VBoxContainer = null
var _top_bar: PanelContainer = null
var _top_bar_margin: MarginContainer = null
var _top_bar_row: HBoxContainer = null
var _day_label: Label = null
var _phase_label: Label = null
var _rn_block: VBoxContainer = null
var _rn_slot: Control = null
var _legitimacy_bar: ProgressBar = null
var _situation_body: Label = null
var _narrative_body: Label = null
var _map_inspector_title: Label = null
var _map_inspector_meta: Label = null
var _map_inspector_stats: Label = null
var _map_inspector_history: Label = null
var _sidebar: PanelContainer = null
var _map_area: PanelContainer = null
var _map_inspector_panel: PanelContainer = null
var _situation_panel: PanelContainer = null
var _situation_box: VBoxContainer = null
var _loyalty_panel: PanelContainer = null
var _loyalty_scroll: ScrollContainer = null
var _loyalty_list: VBoxContainer = null
var _narrative_panel: PanelContainer = null
var _narrative_box: VBoxContainer = null
var _decision_tray: PanelContainer = null
var _tray_margin: MarginContainer = null
var _tray_content: VBoxContainer = null
var _tray_header: HBoxContainer = null
var _tray_hint: Label = null
var _decision_scroll: ScrollContainer = null
var _decision_scroll_content: MarginContainer = null
var _decision_row: HBoxContainer = null

var _rn_slider: RougeNoirSlider = null
var _rn_overlay: ColorRect = null


func bind_nodes(nodes: Dictionary, tray_controller: MainMenuTrayController = null) -> void:
	_tray_controller = tray_controller
	_root_layout = nodes.get("root_layout", _root_layout)
	_main_area = nodes.get("main_area", _main_area)
	_left_column = nodes.get("left_column", _left_column)
	_top_bar = nodes.get("top_bar", _top_bar)
	_top_bar_margin = nodes.get("top_bar_margin", _top_bar_margin)
	_top_bar_row = nodes.get("top_bar_row", _top_bar_row)
	_day_label = nodes.get("day_label", _day_label)
	_phase_label = nodes.get("phase_label", _phase_label)
	_rn_block = nodes.get("rn_block", _rn_block)
	_rn_slot = nodes.get("rn_slot", _rn_slot)
	_legitimacy_bar = nodes.get("legitimacy_bar", _legitimacy_bar)
	_situation_body = nodes.get("situation_body", _situation_body)
	_narrative_body = nodes.get("narrative_body", _narrative_body)
	_map_inspector_title = nodes.get("map_inspector_title", _map_inspector_title)
	_map_inspector_meta = nodes.get("map_inspector_meta", _map_inspector_meta)
	_map_inspector_stats = nodes.get("map_inspector_stats", _map_inspector_stats)
	_map_inspector_history = nodes.get("map_inspector_history", _map_inspector_history)
	_sidebar = nodes.get("sidebar", _sidebar)
	_map_area = nodes.get("map_area", _map_area)
	_map_inspector_panel = nodes.get("map_inspector_panel", _map_inspector_panel)
	_situation_panel = nodes.get("situation_panel", _situation_panel)
	_situation_box = nodes.get("situation_box", _situation_box)
	_loyalty_panel = nodes.get("loyalty_panel", _loyalty_panel)
	_loyalty_scroll = nodes.get("loyalty_scroll", _loyalty_scroll)
	_loyalty_list = nodes.get("loyalty_list", _loyalty_list)
	_narrative_panel = nodes.get("narrative_panel", _narrative_panel)
	_narrative_box = nodes.get("narrative_box", _narrative_box)
	_decision_tray = nodes.get("decision_tray", _decision_tray)
	_tray_margin = nodes.get("tray_margin", _tray_margin)
	_tray_content = nodes.get("tray_content", _tray_content)
	_tray_header = nodes.get("tray_header", _tray_header)
	_tray_hint = nodes.get("tray_hint", _tray_hint)
	_decision_scroll = nodes.get("decision_scroll", _decision_scroll)
	_decision_scroll_content = nodes.get("decision_scroll_content", _decision_scroll_content)
	_decision_row = nodes.get("decision_row", _decision_row)


func set_tray_controller(tray_controller: MainMenuTrayController) -> void:
	_tray_controller = tray_controller


func configure_static_ui() -> void:
	_style_heading(_day_label, 24, CentJoursTheme.COLOR["text_heading"])
	_style_heading(_phase_label, 11, CentJoursTheme.COLOR["gold_dim"])
	_style_heading(_map_inspector_title, 12, CentJoursTheme.COLOR["text_heading"])
	if _legitimacy_bar != null:
		_legitimacy_bar.show_percentage = false
		_legitimacy_bar.max_value = 100.0
	if _decision_scroll != null:
		_decision_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		_decision_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for label in [_situation_body, _narrative_body, _map_inspector_meta, _map_inspector_stats, _map_inspector_history]:
		if label != null:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func apply_panel_styles() -> void:
	if _top_bar != null:
		_top_bar.add_theme_stylebox_override(
			"panel",
			_make_panel_style(CentJoursTheme.COLOR["bg_panel_dark"], CentJoursTheme.COLOR["gold_dim"], 0.30)
		)
	if _sidebar != null:
		_sidebar.add_theme_stylebox_override(
			"panel",
			_make_panel_style(CentJoursTheme.COLOR["bg_panel"], CentJoursTheme.COLOR["border_panel"], 0.24)
		)
	if _map_area != null:
		_map_area.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color("#111821"), CentJoursTheme.COLOR["gold_dim"], 0.34)
		)
	if _map_inspector_panel != null:
		_map_inspector_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.09, 0.11, 0.18, 0.94), CentJoursTheme.COLOR["border_panel"], 0.20)
		)
	if _decision_tray != null:
		_decision_tray.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.08, 0.09, 0.14, 0.96), CentJoursTheme.COLOR["border_panel"], 0.30)
		)
	if _situation_panel != null:
		_situation_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.11, 0.12, 0.18, 0.96), CentJoursTheme.COLOR["border_panel"], 0.16)
		)
	if _loyalty_panel != null:
		_loyalty_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.10, 0.11, 0.17, 0.96), CentJoursTheme.COLOR["border_panel"], 0.16)
		)
	if _narrative_panel != null:
		_narrative_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.09, 0.10, 0.16, 0.98), CentJoursTheme.COLOR["gold_dim"], 0.16)
		)


func build_rouge_noir_slider(parent: Control = null) -> RougeNoirSlider:
	if _rn_slider != null and is_instance_valid(_rn_slider):
		return _rn_slider

	_rn_slider = RougeNoirSlider.new()
	_rn_slider.show_labels = false
	_rn_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rn_slider.custom_minimum_size = Vector2(280, 24)

	var target_parent := parent if parent != null else _rn_slot
	if target_parent != null:
		target_parent.add_child(_rn_slider)
	return _rn_slider


func build_rn_overlay(parent: Node = null) -> ColorRect:
	if _rn_overlay != null and is_instance_valid(_rn_overlay):
		return _rn_overlay

	_rn_overlay = ColorRect.new()
	_rn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rn_overlay.color = Color(0, 0, 0, 0)

	var target_parent := parent if parent != null else get_parent()
	if target_parent != null:
		target_parent.add_child(_rn_overlay)
		target_parent.move_child(_rn_overlay, target_parent.get_child_count() - 1)
	return _rn_overlay


func apply_responsive_layout(viewport_size: Vector2 = Vector2.ZERO) -> void:
	var viewport := viewport_size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		var vp := get_viewport()
		if vp != null:
			viewport = vp.get_visible_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	var vertical_safe := int(clampf(roundf(viewport.y * 0.032), 22.0, 32.0))
	var horizontal_safe := int(clampf(roundf(viewport.x * 0.014), 16.0, 24.0))
	if _root_layout != null:
		_root_layout.offset_left = horizontal_safe
		_root_layout.offset_top = vertical_safe
		_root_layout.offset_right = -horizontal_safe
		_root_layout.offset_bottom = -vertical_safe

	var root_sep := int(clampf(roundf(viewport.y * 0.013), 10.0, 14.0))
	_set_container_separation(_root_layout, root_sep)
	_set_container_separation(_main_area, root_sep)
	_set_container_separation(_left_column, root_sep)

	var topbar_margin_top := int(clampf(roundf(viewport.y * 0.014), 10.0, 12.0))
	var topbar_margin_bottom := int(clampf(roundf(viewport.y * 0.010), 6.0, 8.0))
	_set_margin(_top_bar_margin, "margin_top", topbar_margin_top)
	_set_margin(_top_bar_margin, "margin_bottom", topbar_margin_bottom)
	_set_margin(_top_bar_margin, "margin_left", int(clampf(roundf(viewport.x * 0.010), 14.0, 18.0)))
	_set_margin(_top_bar_margin, "margin_right", int(clampf(roundf(viewport.x * 0.010), 14.0, 18.0)))
	_set_container_separation(_top_bar_row, int(clampf(roundf(viewport.x * 0.010), 12.0, 18.0)))
	_set_container_separation(_rn_block, 1)

	var day_font := int(clampf(roundf(viewport.y * 0.027), 19.0, 22.0))
	var phase_font := int(clampf(roundf(viewport.y * 0.015), 10.0, 11.0))
	_style_heading(_day_label, day_font, CentJoursTheme.COLOR["text_heading"])
	_style_heading(_phase_label, phase_font, CentJoursTheme.COLOR["gold_dim"])

	if _rn_slider != null:
		_rn_slider.custom_minimum_size = Vector2(
			clampf(viewport.x * 0.19, 210.0, 290.0),
			clampf(viewport.y * 0.024, 18.0, 20.0)
		)

	var tray_margin := int(clampf(roundf(viewport.y * 0.011), 8.0, 10.0))
	_set_margin(_tray_margin, "margin_top", tray_margin)
	_set_margin(_tray_margin, "margin_bottom", tray_margin)
	_set_container_separation(_tray_content, int(clampf(roundf(viewport.y * 0.008), 6.0, 8.0)))
	_set_container_separation(_decision_row, int(clampf(roundf(viewport.x * 0.006), 8.0, 12.0)))

	var sidebar_width := clampf(viewport.x * 0.27, 332.0, 372.0)
	if _sidebar != null:
		_sidebar.custom_minimum_size.x = sidebar_width

	var card_size := Vector2(
		clampf(viewport.x * 0.102, 124.0, 140.0),
		clampf(viewport.y * 0.135, 96.0, 108.0)
	)
	apply_decision_card_metrics(card_size)

	var hover_padding := _compute_decision_hover_padding(card_size.y)
	var row_height := _compute_decision_row_height(card_size.y)
	var scroll_safe_bottom := _compute_decision_scroll_safe_bottom() + hover_padding
	_set_margin(_decision_scroll_content, "margin_top", int(roundf(hover_padding)))
	_set_margin(_decision_scroll_content, "margin_bottom", int(roundf(scroll_safe_bottom)))
	if _decision_scroll_content != null:
		_decision_scroll_content.custom_minimum_size.y = row_height + hover_padding + scroll_safe_bottom
	if _decision_row != null:
		_decision_row.custom_minimum_size.y = row_height
	var scroll_height := row_height + hover_padding + scroll_safe_bottom
	if _decision_scroll != null:
		_decision_scroll.custom_minimum_size = Vector2(0.0, scroll_height)
	if _decision_tray != null:
		_decision_tray.size_flags_vertical = 0
		_decision_tray.custom_minimum_size.y = _compute_tray_min_height(scroll_height, tray_margin)

	if _situation_panel != null and _situation_box != null:
		_situation_panel.custom_minimum_size.y = _panel_min_height(_situation_box, 20.0, 100.0)
	if _narrative_panel != null and _narrative_box != null:
		_narrative_panel.custom_minimum_size.y = _panel_min_height(_narrative_box, 24.0, 148.0)
	if _loyalty_panel != null:
		_loyalty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _loyalty_scroll != null:
		_loyalty_scroll.custom_minimum_size = Vector2.ZERO
		_loyalty_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _loyalty_list != null:
		_loyalty_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_loyalty_list.custom_minimum_size.x = _compute_loyalty_content_width(sidebar_width)

	if _top_bar != null:
		_top_bar.custom_minimum_size.y = _compute_topbar_min_height(topbar_margin_top, topbar_margin_bottom)
		_top_bar.update_minimum_size()
	if _decision_tray != null:
		_decision_tray.update_minimum_size()
	if _sidebar != null:
		_sidebar.update_minimum_size()


func apply_decision_card_metrics(card_size: Vector2) -> void:
	if _tray_controller != null:
		_tray_controller.apply_layout_metrics(card_size)


func set_rn_value(value: float) -> void:
	if _rn_slider != null:
		_rn_slider.set_value(value)


func _compute_topbar_min_height(margin_top: int, margin_bottom: int) -> float:
	if _top_bar_row == null:
		return 72.0
	var row_min := _top_bar_row.get_combined_minimum_size().y
	return maxf(72.0, row_min + margin_top + margin_bottom + 4.0)


func _compute_tray_min_height(scroll_height: float, margin_vertical: int) -> float:
	var header_height := 28.0
	if _tray_header != null:
		header_height = _tray_header.get_combined_minimum_size().y
	if _tray_hint != null:
		header_height = maxf(header_height, _tray_hint.get_combined_minimum_size().y)
	var gap := 0.0
	if _tray_content != null:
		gap = float(_tray_content.get_theme_constant("separation"))
	return maxf(156.0, scroll_height + header_height + gap + margin_vertical * 2.0 + 4.0)


func _compute_decision_scroll_safe_bottom() -> float:
	var fallback := 16.0
	if _decision_scroll == null:
		return fallback
	var h_scroll_bar := _decision_scroll.get_h_scroll_bar()
	if h_scroll_bar == null:
		return fallback
	return maxf(fallback, h_scroll_bar.get_combined_minimum_size().y + 4.0)


func _compute_decision_row_height(card_height: float) -> float:
	var row_height := card_height
	if _decision_row != null:
		row_height = maxf(row_height, _decision_row.get_combined_minimum_size().y)
	return row_height


func _compute_decision_hover_padding(card_height: float) -> float:
	return maxf(4.0, ceilf(card_height * 0.04))


func _panel_min_height(content: Control, breathing_room: float, floor_value: float) -> float:
	if content == null:
		return floor_value
	return maxf(floor_value, content.get_combined_minimum_size().y + breathing_room)


func _compute_loyalty_content_width(sidebar_width: float) -> float:
	var scroll_width := _loyalty_scroll.size.x if _loyalty_scroll != null else 0.0
	if scroll_width <= 0.0:
		scroll_width = sidebar_width - 52.0
	return maxf(scroll_width - 6.0, 240.0)


func _style_heading(label: Label, font_size: int, font_color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)


func _make_panel_style(bg_color: Color, border_color: Color, shadow_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, shadow_alpha)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _set_container_separation(container: Container, separation: int) -> void:
	if container != null:
		container.add_theme_constant_override("separation", separation)


func _set_margin(margin_container: MarginContainer, key: StringName, value: int) -> void:
	if margin_container != null:
		margin_container.add_theme_constant_override(key, value)
