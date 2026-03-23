extends Node
class_name MainMenuMapController

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")

const DEFAULT_MAP_NODES_PATH := "res://src/data/map_nodes.json"
const DEFAULT_MAP_TITLE := "THEATRE OF OPERATIONS"
const DEFAULT_INSPECTOR_TITLE := "Map Inspector"
const DEFAULT_INSPECTOR_HINT := "悬停查看节点，点击后锁定详情。"

signal map_data_loaded(success: bool)
signal map_rebuilt
signal hovered_node_changed(node_id: String)
signal selected_node_changed(node_id: String)
## 行军模式确认信号：玩家在地图上选定了合法目标并请求执行
signal march_confirmed(target_node: String)
## 行军模式反馈信号，用于更新侧边栏预览文本
## text(String)  — 要显示在侧边栏的反馈文本，空串表示恢复默认预览
## color(Color)  — 文本颜色
signal march_feedback(text: String, color: Color)

var _map_nodes_path: String = DEFAULT_MAP_NODES_PATH
var _map_region: String = ""
var _map_nodes: Array = []
var _map_edges: Array = []
var _map_x_min: float = 0.0
var _map_x_max: float = 1.0
var _map_y_min: float = 0.0
var _map_y_max: float = 1.0
var _map_node_index: Dictionary = {}
var _map_adjacency_by_node: Dictionary = {}

var _map_canvas: Control = null
var _map_title: Label = null
var _map_subtitle: Label = null
var _map_inspector_panel: PanelContainer = null
var _map_inspector_title: Label = null
var _map_inspector_meta: Label = null
var _map_inspector_stats: Label = null
var _map_inspector_history: Label = null

var _napoleon_location_id: String = ""
var _hovered_map_node_id: String = ""
var _selected_map_node_id: String = ""
var _map_points_by_id: Dictionary = {}
var _map_node_controls_by_id: Dictionary = {}
var _map_edge_lines_by_node: Dictionary = {}
var _map_rebuild_in_progress: bool = false
var _map_rebuild_pending: bool = false
var _march_origin_node_id: String = ""
var _march_target_node_ids: Array[String] = []
# 行军交互状态：是否处于行军选点模式
var _march_mode_active: bool = false
# 行军交互状态：玩家当前选中的待确认目标节点 ID
var _pending_march_target: String = ""


func configure(
	map_canvas: Control,
	map_title: Label = null,
	map_subtitle: Label = null,
	map_inspector_panel: PanelContainer = null,
	map_inspector_title: Label = null,
	map_inspector_meta: Label = null,
	map_inspector_stats: Label = null,
	map_inspector_history: Label = null,
	map_nodes_path: String = DEFAULT_MAP_NODES_PATH,
	napoleon_location_id: String = ""
) -> void:
	bind_nodes(map_canvas, map_title, map_subtitle, map_inspector_panel, map_inspector_title, map_inspector_meta, map_inspector_stats, map_inspector_history)
	set_map_nodes_path(map_nodes_path)
	set_napoleon_location(napoleon_location_id)
	load_map_data()


func bind_nodes(
	map_canvas: Control,
	map_title: Label = null,
	map_subtitle: Label = null,
	map_inspector_panel: PanelContainer = null,
	map_inspector_title: Label = null,
	map_inspector_meta: Label = null,
	map_inspector_stats: Label = null,
	map_inspector_history: Label = null
) -> void:
	_map_canvas = map_canvas
	_map_title = map_title
	_map_subtitle = map_subtitle
	_map_inspector_panel = map_inspector_panel
	_map_inspector_title = map_inspector_title
	_map_inspector_meta = map_inspector_meta
	_map_inspector_stats = map_inspector_stats
	_map_inspector_history = map_inspector_history
	if _map_canvas != null:
		_map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_map_header()
	refresh_map_inspector()
	if has_map_data():
		request_map_rebuild()


func unbind_nodes() -> void:
	_map_canvas = null
	_map_title = null
	_map_subtitle = null
	_map_inspector_panel = null
	_map_inspector_title = null
	_map_inspector_meta = null
	_map_inspector_stats = null
	_map_inspector_history = null


func set_map_nodes_path(path: String) -> void:
	if path.strip_edges() != "":
		_map_nodes_path = path


func get_map_nodes_path() -> String:
	return _map_nodes_path


func load_map_data(path: String = "") -> bool:
	if path.strip_edges() != "":
		_map_nodes_path = path

	var file := FileAccess.open(_map_nodes_path, FileAccess.READ)
	if file == null:
		push_warning("[MainMenuMap] 无法加载 map_nodes.json，地图将为空")
		_clear_loaded_map_data()
		map_data_loaded.emit(false)
		refresh_map_header()
		refresh_map_inspector()
		request_map_rebuild()
		return false

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[MainMenuMap] map_nodes.json 解析失败")
		_clear_loaded_map_data()
		map_data_loaded.emit(false)
		refresh_map_header()
		refresh_map_inspector()
		request_map_rebuild()
		return false

	var data: Dictionary = json.data
	_map_region = String(data.get("map_region", ""))
	_map_nodes = Array(data.get("nodes", []))
	_map_edges = Array(data.get("edges", []))
	_map_node_index.clear()
	_map_adjacency_by_node.clear()

	for node_info in _map_nodes:
		var node_id: String = String(node_info.get("id", ""))
		_map_node_index[node_id] = node_info
		_map_adjacency_by_node[node_id] = []

	for edge in _map_edges:
		var from_id: String = String(edge.get("from", ""))
		var to_id: String = String(edge.get("to", ""))
		if not _map_adjacency_by_node.has(from_id):
			_map_adjacency_by_node[from_id] = []
		if not _map_adjacency_by_node.has(to_id):
			_map_adjacency_by_node[to_id] = []
		_map_adjacency_by_node[from_id].append(to_id)
		_map_adjacency_by_node[to_id].append(from_id)

	if _map_nodes.size() > 0:
		_map_x_min = INF
		_map_x_max = -INF
		_map_y_min = INF
		_map_y_max = -INF
		for node in _map_nodes:
			var nx: float = float(node.get("x", 0))
			var ny: float = float(node.get("y", 0))
			_map_x_min = minf(_map_x_min, nx)
			_map_x_max = maxf(_map_x_max, nx)
			_map_y_min = minf(_map_y_min, ny)
			_map_y_max = maxf(_map_y_max, ny)
		var pad_x := (_map_x_max - _map_x_min) * 0.05
		var pad_y := (_map_y_max - _map_y_min) * 0.05
		_map_x_min -= pad_x
		_map_x_max += pad_x
		_map_y_min -= pad_y
		_map_y_max += pad_y
	else:
		_map_x_min = 0.0
		_map_x_max = 1.0
		_map_y_min = 0.0
		_map_y_max = 1.0

	refresh_map_header()
	refresh_map_inspector()
	map_data_loaded.emit(true)
	request_map_rebuild()
	return true


func has_map_data() -> bool:
	return not _map_nodes.is_empty()


func refresh_map_header(title_text: String = DEFAULT_MAP_TITLE, subtitle_text: String = "") -> void:
	if _map_title != null:
		_map_title.text = title_text
	if _map_subtitle != null:
		_map_subtitle.text = subtitle_text if subtitle_text.strip_edges() != "" else _map_region


func set_napoleon_location(node_id: String) -> void:
	if _napoleon_location_id == node_id:
		return
	_napoleon_location_id = node_id
	refresh_map_inspector()
	request_map_rebuild()


func get_napoleon_location() -> String:
	return _napoleon_location_id


func get_hovered_node_id() -> String:
	return _hovered_map_node_id


func get_selected_node_id() -> String:
	return _selected_map_node_id


func get_map_nodes() -> Array:
	return _map_nodes.duplicate(true)


func get_map_edges() -> Array:
	return _map_edges.duplicate(true)


## 获取某节点的直接相邻节点（供行军目标校验使用）
func get_adjacent_node_ids(node_id: String) -> Array:
	if not _map_adjacency_by_node.has(node_id):
		return []
	return Array(_map_adjacency_by_node[node_id]).duplicate()


## 设置行军预览：突出当前出发点通向的可达节点。
func set_march_preview(origin_node_id: String, target_node_ids: Array = []) -> void:
	var normalized_targets := _normalize_node_id_array(target_node_ids)
	if _march_origin_node_id == origin_node_id and _march_target_node_ids == normalized_targets:
		return
	_march_origin_node_id = origin_node_id
	_march_target_node_ids = normalized_targets
	request_map_rebuild()


func clear_march_preview() -> void:
	if _march_origin_node_id == "" and _march_target_node_ids.is_empty():
		return
	_march_origin_node_id = ""
	_march_target_node_ids.clear()
	request_map_rebuild()


func get_map_node(node_id: String) -> Dictionary:
	return _map_node_index.get(node_id, {})


func get_map_region() -> String:
	return _map_region


func get_map_node_index() -> Dictionary:
	return _map_node_index.duplicate(true)


func get_map_points_by_id() -> Dictionary:
	return _map_points_by_id.duplicate(true)


func get_map_node_controls_by_id() -> Dictionary:
	return _map_node_controls_by_id.duplicate(true)


func get_map_edge_lines_by_node() -> Dictionary:
	return _map_edge_lines_by_node.duplicate(true)


func clear_hover() -> void:
	if _hovered_map_node_id == "":
		return
	_hovered_map_node_id = ""
	hovered_node_changed.emit("")
	refresh_map_inspector()
	request_map_rebuild()


func clear_selection() -> void:
	if _selected_map_node_id == "":
		return
	_selected_map_node_id = ""
	selected_node_changed.emit("")
	refresh_map_inspector()
	request_map_rebuild()


func clear_interaction_state() -> void:
	var changed := _hovered_map_node_id != "" or _selected_map_node_id != ""
	_hovered_map_node_id = ""
	_selected_map_node_id = ""
	if changed:
		hovered_node_changed.emit("")
		selected_node_changed.emit("")
		refresh_map_inspector()
		request_map_rebuild()


func set_hovered_node_id(node_id: String) -> void:
	if _selected_map_node_id != "" and _selected_map_node_id != node_id:
		return
	if _hovered_map_node_id == node_id:
		return
	_hovered_map_node_id = node_id
	hovered_node_changed.emit(node_id)
	refresh_map_inspector()
	request_map_rebuild()


func set_selected_node_id(node_id: String) -> void:
	if _selected_map_node_id == node_id:
		return
	_selected_map_node_id = node_id
	selected_node_changed.emit(node_id)
	refresh_map_inspector()
	request_map_rebuild()


func select_node(node_id: String) -> void:
	if _selected_map_node_id == node_id and _hovered_map_node_id == node_id:
		return
	_selected_map_node_id = node_id
	_hovered_map_node_id = node_id
	hovered_node_changed.emit(node_id)
	selected_node_changed.emit(node_id)
	refresh_map_inspector()
	request_map_rebuild()


func request_map_rebuild() -> void:
	if _map_rebuild_pending:
		return
	_map_rebuild_pending = true
	call_deferred("_rebuild_map_nodes")


func rebuild_map_nodes() -> void:
	request_map_rebuild()


func on_map_node_mouse_entered(node_id: String) -> void:
	if _selected_map_node_id != "" and _selected_map_node_id != node_id:
		return
	set_hovered_node_id(node_id)


func on_map_node_mouse_exited(node_id: String) -> void:
	if _map_rebuild_in_progress:
		return
	if _hovered_map_node_id != node_id:
		return
	clear_hover()


func on_map_node_gui_input(event: InputEvent, node_id: String, hotspot: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hotspot != null:
			hotspot.accept_event()
		if _selected_map_node_id == node_id:
			clear_interaction_state()
		else:
			select_node(node_id)


func on_map_canvas_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and (_selected_map_node_id != "" or _hovered_map_node_id != ""):
		clear_interaction_state()


func refresh_map_inspector() -> void:
	var inspector_node_id := _selected_map_node_id if _selected_map_node_id != "" else _hovered_map_node_id
	var is_hover_preview := _selected_map_node_id == "" and inspector_node_id != ""
	if inspector_node_id == "" or not _map_node_index.has(inspector_node_id):
		if _map_inspector_title != null:
			_map_inspector_title.text = DEFAULT_INSPECTOR_TITLE
			_map_inspector_title.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
		if _map_inspector_meta != null:
			_map_inspector_meta.text = DEFAULT_INSPECTOR_HINT
			_map_inspector_meta.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		if _map_inspector_stats != null:
			_map_inspector_stats.text = ""
			_map_inspector_stats.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		if _map_inspector_history != null:
			_map_inspector_history.text = ""
			_map_inspector_history.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		return

	var node_info: Dictionary = _map_node_index.get(inspector_node_id, {})
	var fr_name := _node_label_text(node_info)
	var cn_name := String(node_info.get("name", fr_name))
	if _map_inspector_title != null:
		_map_inspector_title.text = fr_name
		_map_inspector_title.add_theme_color_override(
			"font_color",
			CentJoursTheme.COLOR["gold_bright"] if inspector_node_id == _napoleon_location_id else CentJoursTheme.COLOR["text_heading"]
		)
	if _map_inspector_meta != null:
		_map_inspector_meta.text = "%s%s\n类型：%s\n区域：%s · 地形：%s" % [
			"悬停预览\n" if is_hover_preview else "",
			cn_name,
			MainMenuFormattersLib.humanize_token(String(node_info.get("type", "unknown"))),
			MainMenuFormattersLib.humanize_token(String(node_info.get("region", "unknown"))),
			MainMenuFormattersLib.humanize_token(String(node_info.get("terrain", "unknown")))
		]
		_map_inspector_meta.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	if _map_inspector_stats != null:
		var marker := "Napoléon 当前所在\n" if inspector_node_id == _napoleon_location_id else ""
		_map_inspector_stats.text = "%s补给容量：%d\n防御加成：%.1f\n驻军：%d" % [
			marker,
			int(node_info.get("supply_capacity", 0)),
			float(node_info.get("defense_bonus", 0.0)),
			int(node_info.get("garrison", 0))
		]
		_map_inspector_stats.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
	if _map_inspector_history != null:
		_map_inspector_history.text = String(node_info.get("historical_significance", "暂无补充史实。"))
		_map_inspector_history.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])


func _clear_loaded_map_data() -> void:
	_map_region = ""
	_map_nodes.clear()
	_map_edges.clear()
	_map_node_index.clear()
	_map_adjacency_by_node.clear()
	_map_x_min = 0.0
	_map_x_max = 1.0
	_map_y_min = 0.0
	_map_y_max = 1.0


func _rebuild_map_nodes() -> void:
	_map_rebuild_pending = false
	if _map_canvas == null or _map_canvas.size.x <= 0.0 or _map_canvas.size.y <= 0.0:
		_finish_map_rebuild()
		return
	_map_rebuild_in_progress = true

	for child in _map_canvas.get_children():
		child.free()

	_map_points_by_id.clear()
	_map_node_controls_by_id.clear()
	_map_edge_lines_by_node.clear()

	for node_info in _map_nodes:
		var node_id: String = String(node_info.get("id", ""))
		_map_points_by_id[node_id] = _map_to_canvas(float(node_info.get("x", 0)), float(node_info.get("y", 0)))
		_map_edge_lines_by_node[node_id] = []

	for edge in _map_edges:
		var from_id: String = String(edge.get("from", ""))
		var to_id: String = String(edge.get("to", ""))
		if _map_points_by_id.has(from_id) and _map_points_by_id.has(to_id):
			var line := _add_map_route(
				_map_points_by_id[from_id],
				_map_points_by_id[to_id],
				_route_highlight_state(from_id, to_id)
			)
			_map_edge_lines_by_node[from_id].append(line)
			_map_edge_lines_by_node[to_id].append(line)

	var sorted_nodes := _map_nodes.duplicate()
	sorted_nodes.sort_custom(func(a, b):
		var sa: int = _get_node_dot_size(String(a.get("type", "")))
		var sb: int = _get_node_dot_size(String(b.get("type", "")))
		return sa < sb
	)
	for node_info in sorted_nodes:
		var node_id: String = String(node_info.get("id", ""))
		if _map_points_by_id.has(node_id):
			_add_map_node_hotspot(node_info, _map_points_by_id[node_id])

	var occupied_rects: Array = _build_reserved_label_rects()
	var label_candidates: Array = []
	for node_info in _map_nodes:
		var candidate := _build_label_candidate(node_info)
		if not candidate.is_empty():
			label_candidates.append(candidate)

	label_candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for candidate in label_candidates:
		var anchors: Array = candidate.get("anchors", [])
		var placed := false
		for anchor in anchors:
			var rect := _build_label_rect(candidate, String(anchor))
			if _can_use_label_rect(rect, occupied_rects):
				_add_map_label(candidate, rect)
				occupied_rects.append(rect)
				placed = true
				break
		if not placed and bool(candidate.get("force_show", false)) and anchors.size() > 0:
			var forced_rect := _clamp_label_rect_to_canvas(_build_label_rect(candidate, String(anchors[0])))
			_add_map_label(candidate, forced_rect)
			occupied_rects.append(forced_rect)

	call_deferred("_finish_map_rebuild")


func _finish_map_rebuild() -> void:
	_map_rebuild_in_progress = false
	map_rebuilt.emit()


func _map_to_canvas(raw_x: float, raw_y: float) -> Vector2:
	var range_x := _map_x_max - _map_x_min
	var range_y := _map_y_max - _map_y_min
	if range_x <= 0.0:
		range_x = 1.0
	if range_y <= 0.0:
		range_y = 1.0
	return Vector2(
		(raw_x - _map_x_min) / range_x * _map_canvas.size.x,
		(raw_y - _map_y_min) / range_y * _map_canvas.size.y
	)


func _get_node_dot_size(node_type: String) -> int:
	var style: Dictionary = MainMenuConfigData.NODE_LABEL_POLICY.get(node_type, {"dot": 5})
	return int(style.get("dot", 5))


func _add_map_route(start: Vector2, target: Vector2, highlight_state: int) -> Line2D:
	var line := Line2D.new()
	line.add_point(start)
	line.add_point(target)
	var base := CentJoursTheme.COLOR["gold_dim"]
	match highlight_state:
		3:
			line.width = 2.5
			line.default_color = Color(base.r, base.g, base.b, 0.78)
		2:
			line.width = 2.8
			line.default_color = Color(base.r, base.g, base.b, 0.90)
		1:
			line.width = 2.2
			line.default_color = Color(base.r, base.g, base.b, 0.68)
		_:
			line.width = 1.5
			line.default_color = Color(base.r, base.g, base.b, 0.35)
	_map_canvas.add_child(line)
	return line


func _add_map_node_hotspot(node_info: Dictionary, point: Vector2) -> void:
	var node_id: String = String(node_info.get("id", ""))
	var node_type: String = String(node_info.get("type", "small_town"))
	var style: Dictionary = _node_label_policy(node_info)
	var dot_size: int = int(style.get("dot", 5))
	var visual_state := _node_visual_state(node_id)
	var hotspot_size := maxf(dot_size + 12.0, MainMenuConfigData.MAP_HOTSPOT_MIN_SIZE)
	var container := Control.new()
	container.position = point - Vector2(hotspot_size * 0.5, hotspot_size * 0.5)
	container.size = Vector2.ONE * hotspot_size
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_entered.connect(on_map_node_mouse_entered.bind(node_id))
	container.mouse_exited.connect(on_map_node_mouse_exited.bind(node_id))
	container.gui_input.connect(on_map_node_gui_input.bind(node_id, container))

	var ring_size := dot_size + (10 if visual_state > 0 else 6)
	var ring := ColorRect.new()
	ring.position = (container.size - Vector2.ONE * ring_size) * 0.5
	ring.size = Vector2.ONE * ring_size
	ring.color = _node_ring_color(node_id, visual_state)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(ring)

	var dot := ColorRect.new()
	dot.position = (container.size - Vector2.ONE * dot_size) * 0.5
	dot.size = Vector2.ONE * dot_size
	dot.color = _node_dot_color(node_type, node_id, visual_state)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(dot)
	_map_canvas.add_child(container)
	_map_node_controls_by_id[node_id] = container


func _node_label_policy(node_info: Dictionary) -> Dictionary:
	var node_id: String = String(node_info.get("id", ""))
	var node_type: String = String(node_info.get("type", "small_town"))
	var policy: Dictionary = MainMenuConfigData.NODE_LABEL_POLICY.get(
		node_type,
		MainMenuConfigData.NODE_LABEL_POLICY["small_town"]
	).duplicate(true)
	var ui: Dictionary = node_info.get("ui", {})
	if not ui.is_empty():
		var always_show := bool(ui.get("always_show_label", false))
		if always_show:
			policy["always_show"] = true
			policy["default_visible"] = true
			policy["hover_only"] = false
		elif ui.has("label_priority"):
			policy["default_visible"] = true
			policy["hover_only"] = false
		else:
			policy["default_visible"] = false
			policy["hover_only"] = true
		if ui.has("label_priority"):
			policy["label_priority"] = int(ui.get("label_priority", policy.get("label_priority", 40)))
		if ui.has("preferred_anchor"):
			policy["preferred_anchor"] = String(ui.get("preferred_anchor", ""))

	if node_id == "paris" or node_id == _napoleon_location_id:
		policy["always_show"] = true
		policy["default_visible"] = true
		policy["hover_only"] = false
		policy["label_priority"] = max(int(policy.get("label_priority", 80)), 120)

	return policy


func _build_reserved_label_rects() -> Array:
	var reserved: Array = []
	reserved.append(Rect2(Vector2.ZERO, MainMenuConfigData.MAP_RESERVED_TOP_LEFT))
	if _map_inspector_panel != null and _map_canvas != null:
		var inspector_origin := _map_inspector_panel.position - _map_canvas.position
		var inspector_size := _map_inspector_panel.size
		if inspector_size.x > 0.0 and inspector_size.y > 0.0:
			reserved.append(Rect2(inspector_origin - Vector2(8, 8), inspector_size + Vector2(16, 16)))
	return reserved


func _build_label_candidate(node_info: Dictionary) -> Dictionary:
	var node_id: String = String(node_info.get("id", ""))
	if not _map_points_by_id.has(node_id):
		return {}

	var policy := _node_label_policy(node_info)
	var is_selected := node_id == _selected_map_node_id
	var is_hovered := node_id == _effective_hovered_node_id()
	var is_focus := node_id == _napoleon_location_id
	var is_march_target := _is_march_target(node_id)
	var should_show := (
		bool(policy.get("always_show", false))
		or bool(policy.get("default_visible", false))
		or is_hovered
		or is_selected
		or is_march_target
	)
	if not should_show:
		return {}

	var font_size := int(policy.get("font", 9)) + (1 if is_focus else 0)
	var label_size := _measure_label_size(_node_label_text(node_info), font_size, is_focus)
	return {
		"id": node_id,
		"node_info": node_info,
		"point": _map_points_by_id[node_id],
		"dot_size": int(policy.get("dot", 5)),
		"font_size": font_size,
		"label_size": label_size,
		"anchors": _label_anchor_order(policy),
		"priority": _node_label_priority(policy, is_focus, is_selected, is_hovered, is_march_target),
		"force_show": bool(policy.get("always_show", false)) or is_selected or is_hovered or is_march_target,
		"is_focus": is_focus,
		"is_selected": is_selected,
		"is_hovered": is_hovered,
		"is_march_target": is_march_target
	}


func _label_anchor_order(policy: Dictionary) -> Array:
	var anchors: Array = []
	var preferred := String(policy.get("preferred_anchor", ""))
	if preferred != "" and MainMenuConfigData.MAP_LABEL_ANCHORS.has(preferred):
		anchors.append(preferred)
	for anchor in MainMenuConfigData.MAP_LABEL_ANCHORS:
		if not anchors.has(anchor):
			anchors.append(anchor)
	return anchors


func _node_label_priority(
	policy: Dictionary,
	is_focus: bool,
	is_selected: bool,
	is_hovered: bool,
	is_march_target: bool
) -> int:
	var priority := int(policy.get("label_priority", 40))
	if is_focus:
		priority += 20
	if is_selected:
		priority += 12
	elif is_hovered:
		priority += 8
	elif is_march_target:
		priority += 4
	return priority


func _measure_label_size(display_name: String, font_size: int, is_focus: bool) -> Vector2:
	var width := maxf(54.0, display_name.length() * float(font_size) * 0.60 + MainMenuConfigData.MAP_LABEL_PADDING_X * 2.0)
	var height := float(font_size) + MainMenuConfigData.MAP_LABEL_PADDING_Y * 2.0
	if is_focus:
		width = maxf(width, 86.0)
		height += 12.0
	return Vector2(width, height)


func _build_label_rect(candidate: Dictionary, anchor: String) -> Rect2:
	var point: Vector2 = candidate.get("point", Vector2.ZERO)
	var label_size: Vector2 = candidate.get("label_size", Vector2(60, 16))
	var dot_size: float = float(candidate.get("dot_size", 5))
	var dot_half := dot_size * 0.5
	var x := point.x + dot_half + MainMenuConfigData.MAP_LABEL_GAP
	var y := point.y - label_size.y + 2.0
	match anchor:
		"right_down":
			y = point.y + 2.0
		"left_up":
			x = point.x - dot_half - MainMenuConfigData.MAP_LABEL_GAP - label_size.x
		"left_down":
			x = point.x - dot_half - MainMenuConfigData.MAP_LABEL_GAP - label_size.x
			y = point.y + 2.0
	return Rect2(Vector2(x, y), label_size)


func _can_use_label_rect(rect: Rect2, occupied_rects: Array) -> bool:
	if _map_canvas == null:
		return false
	if rect.position.x < 2.0 or rect.position.y < 2.0:
		return false
	if rect.end.x > _map_canvas.size.x - 2.0:
		return false
	if rect.end.y > _map_canvas.size.y - 2.0:
		return false
	for other in occupied_rects:
		if rect.intersects(other.grow(2.0)):
			return false
	return true


func _clamp_label_rect_to_canvas(rect: Rect2) -> Rect2:
	if _map_canvas == null:
		return rect
	rect.position.x = clampf(rect.position.x, 2.0, maxf(2.0, _map_canvas.size.x - rect.size.x - 2.0))
	rect.position.y = clampf(rect.position.y, 2.0, maxf(2.0, _map_canvas.size.y - rect.size.y - 2.0))
	return rect


func _add_map_label(candidate: Dictionary, rect: Rect2) -> void:
	var node_info: Dictionary = candidate.get("node_info", {})
	var is_focus: bool = bool(candidate.get("is_focus", false))
	var is_selected: bool = bool(candidate.get("is_selected", false))
	var is_hovered: bool = bool(candidate.get("is_hovered", false))
	var is_march_target: bool = bool(candidate.get("is_march_target", false))

	var label_box := Control.new()
	label_box.position = rect.position
	label_box.size = rect.size
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.position = Vector2(MainMenuConfigData.MAP_LABEL_PADDING_X, MainMenuConfigData.MAP_LABEL_PADDING_Y - 1.0)
	name_label.text = _node_label_text(node_info)
	name_label.add_theme_font_size_override("font_size", int(candidate.get("font_size", 9)))
	name_label.add_theme_color_override("font_color", _node_label_color(is_focus, is_selected, is_hovered, is_march_target))
	label_box.add_child(name_label)

	if is_focus:
		var status := Label.new()
		status.position = Vector2(MainMenuConfigData.MAP_LABEL_PADDING_X, float(candidate.get("font_size", 9)) + 2.0)
		status.text = "Napoléon"
		status.add_theme_font_size_override("font_size", 8)
		status.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
		label_box.add_child(status)

	_map_canvas.add_child(label_box)


func _route_highlight_state(from_id: String, to_id: String) -> int:
	if _selected_map_node_id != "":
		return 2 if from_id == _selected_map_node_id or to_id == _selected_map_node_id else 0
	if _hovered_map_node_id != "":
		return 1 if from_id == _hovered_map_node_id or to_id == _hovered_map_node_id else 0
	if _is_march_route(from_id, to_id):
		return 3
	return 0


func _node_visual_state(node_id: String) -> int:
	if node_id == _selected_map_node_id:
		return 2
	if _selected_map_node_id == "" and node_id == _hovered_map_node_id:
		return 1
	if _is_march_target(node_id):
		return 3
	return 0


func _effective_hovered_node_id() -> String:
	if _selected_map_node_id != "":
		return _hovered_map_node_id if _hovered_map_node_id == _selected_map_node_id else ""
	return _hovered_map_node_id


func _node_dot_color(node_type: String, node_id: String, visual_state: int) -> Color:
	if node_id == _napoleon_location_id:
		return CentJoursTheme.COLOR["gold_bright"] if visual_state > 0 else CentJoursTheme.COLOR["gold"]

	var base := Color(0.42, 0.54, 0.70, 0.65)
	if node_type == "capital":
		base = Color(0.85, 0.75, 0.50, 0.95)
	elif node_type in ["major_city", "fortress_city"]:
		base = Color(0.55, 0.65, 0.80, 0.90)
	elif node_type in ["regional_capital", "royal_palace"]:
		base = Color(0.49, 0.60, 0.78, 0.82)
	if visual_state == 2:
		return Color(base.r + 0.12, base.g + 0.10, base.b, 1.0)
	if visual_state == 1:
		return Color(base.r + 0.08, base.g + 0.08, base.b, 0.95)
	if visual_state == 3:
		return Color(base.r + 0.18, base.g + 0.15, base.b + 0.02, 0.98)
	return base


func _node_ring_color(node_id: String, visual_state: int) -> Color:
	if node_id == _napoleon_location_id:
		return Color(1.0, 0.85, 0.30, 0.20 if visual_state == 0 else 0.32)
	if visual_state == 2:
		return Color(CentJoursTheme.COLOR["gold"].r, CentJoursTheme.COLOR["gold"].g, CentJoursTheme.COLOR["gold"].b, 0.18)
	if visual_state == 1:
		return Color(CentJoursTheme.COLOR["gold_dim"].r, CentJoursTheme.COLOR["gold_dim"].g, CentJoursTheme.COLOR["gold_dim"].b, 0.14)
	if visual_state == 3:
		return Color(CentJoursTheme.COLOR["gold"].r, CentJoursTheme.COLOR["gold"].g, CentJoursTheme.COLOR["gold"].b, 0.16)
	return Color(0, 0, 0, 0)


func _node_label_color(is_focus: bool, is_selected: bool, is_hovered: bool, is_march_target: bool) -> Color:
	if is_focus or is_selected:
		return CentJoursTheme.COLOR["gold_bright"]
	if is_hovered:
		return CentJoursTheme.COLOR["text_primary"]
	if is_march_target:
		return CentJoursTheme.COLOR["gold_dim"]
	return CentJoursTheme.COLOR["text_heading"]


func _node_label_text(node_info: Dictionary) -> String:
	return String(node_info.get("name_fr", node_info.get("name", node_info.get("id", ""))))


func _is_march_target(node_id: String) -> bool:
	return _march_target_node_ids.has(node_id)


func _is_march_route(from_id: String, to_id: String) -> bool:
	if _march_origin_node_id == "" or _march_target_node_ids.is_empty():
		return false
	return (
		(from_id == _march_origin_node_id and _march_target_node_ids.has(to_id))
		or (to_id == _march_origin_node_id and _march_target_node_ids.has(from_id))
	)


func _normalize_node_id_array(target_node_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for node_id_variant in target_node_ids:
		var node_id := String(node_id_variant)
		if node_id == "" or normalized.has(node_id):
			continue
		normalized.append(node_id)
	return normalized


# ── 行军交互状态机 ──────────────────────────────────────────
# 以下方法管理行军选点模式的 UI 交互。
# 行军合法性预检只读 GameState.available_march_targets（Rust 权威数据的缓存），
# 不自行计算邻接关系——Rust move_army() 做最终校验。

## 开启/关闭行军选点模式，并同步地图高亮预览
func set_march_mode(enabled: bool) -> void:
	_march_mode_active = enabled
	if enabled:
		set_march_preview(GameState.napoleon_location, GameState.available_march_targets)
	else:
		_pending_march_target = ""
		clear_march_preview()


## 地图节点被选中时调用：在行军模式下将其作为候选行军目标
func on_node_selected_for_march(node_id: String) -> void:
	if not _march_mode_active:
		return
	_update_march_target(node_id)


## 玩家点击确认时调用：若有合法目标则发射 march_confirmed 信号
## 返回 true 表示行军命令已发出，false 表示需要先选目标
func try_confirm_march() -> bool:
	if _pending_march_target == "":
		march_feedback.emit(
			"行军部署\n\n请先在地图上选择一个与当前位置相邻的节点。",
			CentJoursTheme.COLOR["text_secondary"]
		)
		return false
	march_confirmed.emit(_pending_march_target)
	return true


## 清除行军交互状态（切换政策或回合结束时调用）
func clear_march_state() -> void:
	_pending_march_target = ""
	_march_mode_active = false
	clear_march_preview()


## 获取当前待确认的行军目标节点 ID（空串表示未选定）
func get_pending_march_target() -> String:
	return _pending_march_target


## 根据地图选中节点更新待确认行军目标，并通过 march_feedback 信号通知侧边栏
func _update_march_target(node_id: String) -> void:
	if node_id == "":
		_pending_march_target = ""
		# 空串通知编排器恢复默认行军预览
		march_feedback.emit("", Color.WHITE)
		return
	# 当前位置不可作为目标
	if node_id == GameState.napoleon_location:
		_pending_march_target = ""
		var location_label := MainMenuFormattersLib.napoleon_location_label(
			_map_nodes, GameState.napoleon_location
		)
		march_feedback.emit(
			"行军部署\n\n当前已驻扎在 %s，请选择一个相邻节点。" % location_label,
			CentJoursTheme.COLOR["text_secondary"]
		)
		return
	# UI 预检：只允许行军到 Rust 引擎提供的相邻节点列表
	if not GameState.available_march_targets.has(node_id):
		_pending_march_target = ""
		var node_info: Dictionary = get_map_node(node_id)
		var location_label := MainMenuFormattersLib.napoleon_location_label(
			_map_nodes, GameState.napoleon_location
		)
		march_feedback.emit(
			"行军部署\n\n%s 目前不与 %s 直接相邻，无法在一天内抵达。" % [
				String(node_info.get("name_fr", node_id)),
				location_label
			],
			CentJoursTheme.COLOR["text_secondary"]
		)
		return
	# 合法目标
	_pending_march_target = node_id
	var target_info: Dictionary = get_map_node(node_id)
	var location_label := MainMenuFormattersLib.napoleon_location_label(
		_map_nodes, GameState.napoleon_location
	)
	march_feedback.emit(
		"行军部署\n\n从 %s 行军至 %s。\n确认后将推进一天，并同步疲劳与士气。" % [
			location_label,
			String(target_info.get("name_fr", node_id))
		],
		CentJoursTheme.COLOR["text_secondary"]
	)
