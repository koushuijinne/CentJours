extends RefCounted
class_name MainMenuMapRenderController
## 地图渲染控制器：负责节点/边/标签的视觉创建与碰撞布局。
## 本文件是纯渲染层——只读取上下文数据，不修改任何交互状态。

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")

# ── 渲染上下文（rebuild 期间有效） ────────────────────────────
# 以下变量在每次 rebuild() 开始时从 context Dict 设置，
# 结束后清除。避免在所有内部函数间显式传递 12 个参数。
var _map_nodes: Array = []
var _map_edges: Array = []
var _map_node_index: Dictionary = {}
var _adjacency: Dictionary = {}
var _aabb_x_min: float = 0.0
var _aabb_x_max: float = 1.0
var _aabb_y_min: float = 0.0
var _aabb_y_max: float = 1.0
var _canvas: Control = null
var _canvas_size: Vector2 = Vector2.ZERO
var _inspector_panel: PanelContainer = null
var _napoleon_location_id: String = ""
var _hovered_node_id: String = ""
var _selected_node_id: String = ""
var _march_origin_id: String = ""
var _march_target_ids: Array[String] = []
var _forward_depot_location: String = ""
var _forward_depot_days: int = 0

# 渲染期间积累的缓存，rebuild 结束后作为返回值
var _points_by_id: Dictionary = {}
var _node_controls_by_id: Dictionary = {}
var _edge_lines_by_node: Dictionary = {}


## 重建地图全部视觉元素（边、节点圆点、标签）。
## context 参数契约:
##   map_nodes(Array)               — 节点元数据列表（每项见 _node_info_contract）
##   map_edges(Array)               — 边列表，每项 { from(String), to(String) }
##   map_node_index(Dictionary)     — id(String) → node_info(Dictionary) 快速查找
##   aabb(Dictionary)               — { x_min(float), x_max(float), y_min(float), y_max(float) }
##   canvas(Control)                — 绘制目标容器
##   canvas_size(Vector2)           — canvas 当前像素尺寸
##   inspector_panel(PanelContainer)— 面板碰撞排除区（可 null）
##   napoleon_location_id(String)   — 拿破仑当前位置节点 ID
##   hovered_node_id(String)        — 当前 hover 节点 ID（空串=无）
##   selected_node_id(String)       — 当前选中节点 ID（空串=无）
##   march_origin_id(String)        — 行军起点节点 ID（空串=无行军预览）
##   march_target_ids(Array[String])— 行军可达目标节点 ID 列表
##   forward_depot_location(String) — 前沿粮秣站所在节点 ID（空串=无）
##   forward_depot_days(int)        — 前沿粮秣站剩余天数
##   adjacency(Dictionary)          — id(String) → Array[String] 相邻节点
##
## 返回值契约:
##   points_by_id(Dictionary)        — id(String) → Vector2 屏幕坐标
##   node_controls_by_id(Dictionary) — id(String) → Control 热点控件（未绑定交互信号）
##   edge_lines_by_node(Dictionary)  — id(String) → Array[Line2D] 关联边线
func rebuild(context: Dictionary) -> Dictionary:
	_load_context(context)
	# 清除旧的子节点
	for child in _canvas.get_children():
		child.free()
	_points_by_id.clear()
	_node_controls_by_id.clear()
	_edge_lines_by_node.clear()

	# 阶段 1：计算节点屏幕坐标
	for node_info in _map_nodes:
		var node_id: String = String(node_info.get("id", ""))
		_points_by_id[node_id] = _map_to_canvas(
			float(node_info.get("x", 0)), float(node_info.get("y", 0))
		)
		_edge_lines_by_node[node_id] = []

	# 阶段 2：绘制边（路线）
	for edge in _map_edges:
		var from_id: String = String(edge.get("from", ""))
		var to_id: String = String(edge.get("to", ""))
		if _points_by_id.has(from_id) and _points_by_id.has(to_id):
			var line := _add_map_route(
				_points_by_id[from_id],
				_points_by_id[to_id],
				_route_highlight_state(from_id, to_id)
			)
			_edge_lines_by_node[from_id].append(line)
			_edge_lines_by_node[to_id].append(line)

	# 阶段 3：按圆点尺寸排序后绘制节点热点（小点先绘制，大点覆盖其上）
	var sorted_nodes := _map_nodes.duplicate()
	sorted_nodes.sort_custom(func(a, b):
		var sa: int = _get_node_dot_size(String(a.get("type", "")))
		var sb: int = _get_node_dot_size(String(b.get("type", "")))
		return sa < sb
	)
	for node_info in sorted_nodes:
		var node_id: String = String(node_info.get("id", ""))
		if _points_by_id.has(node_id):
			_add_map_node_hotspot(node_info, _points_by_id[node_id])

	# 阶段 4：标签碰撞布局
	var occupied_rects: Array = _build_reserved_label_rects()
	var label_candidates: Array = []
	for node_info in _map_nodes:
		var candidate := _build_label_candidate(node_info)
		if not candidate.is_empty():
			label_candidates.append(candidate)

	# 优先级降序：高优先级标签先抢占空间
	label_candidates.sort_custom(func(a, b):
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
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
		# 强制显示的标签（选中/hover/行军目标）：碰撞时强制 clamp 到 canvas 边界
		if not placed and bool(candidate.get("force_show", false)) and anchors.size() > 0:
			var forced_rect := _clamp_label_rect_to_canvas(
				_build_label_rect(candidate, String(anchors[0]))
			)
			_add_map_label(candidate, forced_rect)
			occupied_rects.append(forced_rect)

	var result := {
		"points_by_id": _points_by_id.duplicate(),
		"node_controls_by_id": _node_controls_by_id.duplicate(),
		"edge_lines_by_node": _edge_lines_by_node.duplicate()
	}
	_clear_context()
	return result


# ── 上下文管理 ────────────────────────────────────────────────

## 从 context Dict 加载渲染所需的全部状态
func _load_context(ctx: Dictionary) -> void:
	_map_nodes = ctx.get("map_nodes", [])
	_map_edges = ctx.get("map_edges", [])
	_map_node_index = ctx.get("map_node_index", {})
	_adjacency = ctx.get("adjacency", {})
	var aabb: Dictionary = ctx.get("aabb", {})
	_aabb_x_min = float(aabb.get("x_min", 0.0))
	_aabb_x_max = float(aabb.get("x_max", 1.0))
	_aabb_y_min = float(aabb.get("y_min", 0.0))
	_aabb_y_max = float(aabb.get("y_max", 1.0))
	_canvas = ctx.get("canvas", null)
	_canvas_size = ctx.get("canvas_size", Vector2.ZERO)
	_inspector_panel = ctx.get("inspector_panel", null)
	_napoleon_location_id = ctx.get("napoleon_location_id", "")
	_hovered_node_id = ctx.get("hovered_node_id", "")
	_selected_node_id = ctx.get("selected_node_id", "")
	_march_origin_id = ctx.get("march_origin_id", "")
	_march_target_ids = ctx.get("march_target_ids", [] as Array[String])
	_forward_depot_location = ctx.get("forward_depot_location", "")
	_forward_depot_days = int(ctx.get("forward_depot_days", 0))


## 渲染结束后清除上下文引用，避免持有 UI 节点引用导致泄漏
func _clear_context() -> void:
	_map_nodes = []
	_map_edges = []
	_map_node_index = {}
	_adjacency = {}
	_canvas = null
	_canvas_size = Vector2.ZERO
	_inspector_panel = null
	_points_by_id = {}
	_node_controls_by_id = {}
	_edge_lines_by_node = {}
	_forward_depot_location = ""
	_forward_depot_days = 0


# ── 坐标变换 ─────────────────────────────────────────────────

## 地图逻辑坐标 → canvas 屏幕像素坐标
func _map_to_canvas(raw_x: float, raw_y: float) -> Vector2:
	var range_x := _aabb_x_max - _aabb_x_min
	var range_y := _aabb_y_max - _aabb_y_min
	if range_x <= 0.0:
		range_x = 1.0
	if range_y <= 0.0:
		range_y = 1.0
	return Vector2(
		(raw_x - _aabb_x_min) / range_x * _canvas_size.x,
		(raw_y - _aabb_y_min) / range_y * _canvas_size.y
	)


# ── 边（路线）绘制 ───────────────────────────────────────────

## 获取节点类型对应的圆点半径
func _get_node_dot_size(node_type: String) -> int:
	var style: Dictionary = MainMenuConfigData.NODE_LABEL_POLICY.get(node_type, {"dot": 5})
	return int(style.get("dot", 5))


## 创建一条路线 Line2D，根据高亮等级设置粗细和透明度
## highlight_state: 0=默认, 1=hover 相邻, 2=选中相邻, 3=行军路线
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
	_canvas.add_child(line)
	return line


# ── 节点热点绘制 ─────────────────────────────────────────────

## 创建节点交互热点（container + ring + dot），不绑定交互信号。
## 信号绑定由 map_controller 在拿到 node_controls_by_id 后完成。
func _add_map_node_hotspot(node_info: Dictionary, point: Vector2) -> void:
	var node_id: String = String(node_info.get("id", ""))
	var style: Dictionary = _node_label_policy(node_info)
	var dot_size: int = int(style.get("dot", 5))
	var visual_state := _node_visual_state(node_id)
	var hotspot_size := maxf(dot_size + 12.0, MainMenuConfigData.MAP_HOTSPOT_MIN_SIZE)

	# 热点容器：鼠标可交互区域
	var container := Control.new()
	container.position = point - Vector2(hotspot_size * 0.5, hotspot_size * 0.5)
	container.size = Vector2.ONE * hotspot_size
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# 光环圆环（视觉反馈，不参与鼠标事件）
	var ring_size := dot_size + (10 if visual_state > 0 else 6)
	var ring := ColorRect.new()
	ring.position = (container.size - Vector2.ONE * ring_size) * 0.5
	ring.size = Vector2.ONE * ring_size
	ring.color = _node_ring_color(node_id, visual_state)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(ring)

	var logistics_ring_color := _node_logistics_ring_color(node_info, node_id)
	if logistics_ring_color.a > 0.0:
		var logistics_ring := ColorRect.new()
		var logistics_ring_size := ring_size + 6
		logistics_ring.position = (container.size - Vector2.ONE * logistics_ring_size) * 0.5
		logistics_ring.size = Vector2.ONE * logistics_ring_size
		logistics_ring.color = logistics_ring_color
		logistics_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(logistics_ring)
		container.move_child(logistics_ring, 0)

	# 核心圆点
	var dot := ColorRect.new()
	dot.position = (container.size - Vector2.ONE * dot_size) * 0.5
	dot.size = Vector2.ONE * dot_size
	dot.color = _node_dot_color(String(node_info.get("type", "small_town")), node_id, visual_state)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(dot)

	_canvas.add_child(container)
	_node_controls_by_id[node_id] = container


# ── 标签碰撞布局算法 ─────────────────────────────────────────

## 根据节点类型和 ui 覆盖，合并出标签显示策略。
## 返回值契约:
##   dot(int)              — 圆点像素尺寸
##   font(int)             — 标签字号
##   always_show(bool)     — 无论碰撞是否强制显示
##   default_visible(bool) — 默认是否显示
##   hover_only(bool)      — 是否仅 hover 时才显示
##   label_priority(int)   — 标签排序优先级基础分
##   preferred_anchor(String) — 首选锚点方向（"right_up"/"left_down" 等）
func _node_label_policy(node_info: Dictionary) -> Dictionary:
	var node_id: String = String(node_info.get("id", ""))
	var node_type: String = String(node_info.get("type", "small_town"))
	var policy: Dictionary = MainMenuConfigData.NODE_LABEL_POLICY.get(
		node_type,
		MainMenuConfigData.NODE_LABEL_POLICY["small_town"]
	).duplicate(true)
	# 合并节点级 ui 覆盖
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

	# 特殊节点：巴黎和拿破仑所在地始终显示
	if node_id == "paris" or node_id == _napoleon_location_id:
		policy["always_show"] = true
		policy["default_visible"] = true
		policy["hover_only"] = false
		policy["label_priority"] = max(int(policy.get("label_priority", 80)), 120)

	return policy


## 构建标签碰撞排除区域（顶部角落 + 详情面板）
func _build_reserved_label_rects() -> Array:
	var reserved: Array = []
	reserved.append(Rect2(Vector2.ZERO, MainMenuConfigData.MAP_RESERVED_TOP_LEFT))
	if _inspector_panel != null and _canvas != null:
		var inspector_origin := _inspector_panel.position - _canvas.position
		var inspector_size := _inspector_panel.size
		if inspector_size.x > 0.0 and inspector_size.y > 0.0:
			reserved.append(Rect2(inspector_origin - Vector2(8, 8), inspector_size + Vector2(16, 16)))
	return reserved


## 为节点生成标签候选，包含优先级和锚点尝试顺序。
## 返回值契约（非空时）:
##   id(String)               — 节点 ID
##   node_info(Dictionary)    — 节点元数据（见 JSON 结构契约）
##   point(Vector2)           — 屏幕坐标
##   dot_size(int)            — 圆点像素尺寸
##   font_size(int)           — 标签字号
##   label_size(Vector2)      — 估计的标签矩形尺寸
##   anchors(Array[String])   — 锚点尝试顺序 ["right_up", "right_down", ...]
##   priority(int)            — 排序优先级（基础分 + 状态加成）
##   force_show(bool)         — 碰撞时是否强制 clamp 后显示
##   is_focus(bool)           — 是否是拿破仑所在节点
##   is_selected(bool)        — 是否选中
##   is_hovered(bool)         — 是否 hover
##   is_march_target(bool)    — 是否行军目标
func _build_label_candidate(node_info: Dictionary) -> Dictionary:
	var node_id: String = String(node_info.get("id", ""))
	if not _points_by_id.has(node_id):
		return {}

	var policy := _node_label_policy(node_info)
	var is_selected := node_id == _selected_node_id
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
		"point": _points_by_id[node_id],
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


## 根据首选锚点排列尝试顺序（首选在前，其余按默认顺序）
func _label_anchor_order(policy: Dictionary) -> Array:
	var anchors: Array = []
	var preferred := String(policy.get("preferred_anchor", ""))
	if preferred != "" and MainMenuConfigData.MAP_LABEL_ANCHORS.has(preferred):
		anchors.append(preferred)
	for anchor in MainMenuConfigData.MAP_LABEL_ANCHORS:
		if not anchors.has(anchor):
			anchors.append(anchor)
	return anchors


## 计算标签排序优先级：基础分 + 焦点/选中/hover/行军加成
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


## 估算标签文本的渲染尺寸（基于字号和文本长度）
func _measure_label_size(display_name: String, font_size: int, is_focus: bool) -> Vector2:
	var width := maxf(54.0, display_name.length() * float(font_size) * 0.60 + MainMenuConfigData.MAP_LABEL_PADDING_X * 2.0)
	var height := float(font_size) + MainMenuConfigData.MAP_LABEL_PADDING_Y * 2.0
	if is_focus:
		width = maxf(width, 86.0)
		height += 12.0
	return Vector2(width, height)


## 根据锚点方向计算标签矩形在 canvas 上的位置
func _build_label_rect(candidate: Dictionary, anchor: String) -> Rect2:
	var point: Vector2 = candidate.get("point", Vector2.ZERO)
	var label_size: Vector2 = candidate.get("label_size", Vector2(60, 16))
	var dot_size: float = float(candidate.get("dot_size", 5))
	var dot_half := dot_size * 0.5
	# 默认锚点: right_up
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


## 碰撞检测：标签矩形是否与已占用区域或 canvas 边界冲突
func _can_use_label_rect(rect: Rect2, occupied_rects: Array) -> bool:
	if _canvas == null:
		return false
	# 2px 边距避免贴边
	if rect.position.x < 2.0 or rect.position.y < 2.0:
		return false
	if rect.end.x > _canvas_size.x - 2.0:
		return false
	if rect.end.y > _canvas_size.y - 2.0:
		return false
	# 已占用区域 grow(2.0) 增加 2px 间距
	for other in occupied_rects:
		if rect.intersects(other.grow(2.0)):
			return false
	return true


## 将标签矩形强制 clamp 到 canvas 可见范围内
func _clamp_label_rect_to_canvas(rect: Rect2) -> Rect2:
	if _canvas == null:
		return rect
	rect.position.x = clampf(rect.position.x, 2.0, maxf(2.0, _canvas_size.x - rect.size.x - 2.0))
	rect.position.y = clampf(rect.position.y, 2.0, maxf(2.0, _canvas_size.y - rect.size.y - 2.0))
	return rect


## 创建标签 Label 节点并添加到 canvas
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

	# 节点名称标签
	var name_label := Label.new()
	name_label.position = Vector2(MainMenuConfigData.MAP_LABEL_PADDING_X, MainMenuConfigData.MAP_LABEL_PADDING_Y - 1.0)
	name_label.text = _node_label_text(node_info)
	name_label.add_theme_font_size_override("font_size", int(candidate.get("font_size", 9)))
	name_label.add_theme_color_override("font_color", _node_label_color(is_focus, is_selected, is_hovered, is_march_target))
	label_box.add_child(name_label)

	# 拿破仑所在节点额外显示 "Napoléon" 状态文字
	if is_focus:
		var status := Label.new()
		status.position = Vector2(MainMenuConfigData.MAP_LABEL_PADDING_X, float(candidate.get("font_size", 9)) + 2.0)
		status.text = "Napoléon"
		status.add_theme_font_size_override("font_size", 8)
		status.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
		label_box.add_child(status)

	_canvas.add_child(label_box)


# ── 视觉状态计算 ─────────────────────────────────────────────

## 计算边高亮等级：0=默认, 1=hover 相邻, 2=选中相邻, 3=行军路线
func _route_highlight_state(from_id: String, to_id: String) -> int:
	if _selected_node_id != "":
		return 2 if from_id == _selected_node_id or to_id == _selected_node_id else 0
	if _hovered_node_id != "":
		return 1 if from_id == _hovered_node_id or to_id == _hovered_node_id else 0
	if _is_march_route(from_id, to_id):
		return 3
	return 0


## 计算节点视觉状态：0=默认, 1=hover, 2=选中, 3=行军目标
func _node_visual_state(node_id: String) -> int:
	if node_id == _selected_node_id:
		return 2
	if _selected_node_id == "" and node_id == _hovered_node_id:
		return 1
	if _is_march_target(node_id):
		return 3
	return 0


## 获取有效 hover 节点 ID（选中锁定时仅返回被锁定的节点）
func _effective_hovered_node_id() -> String:
	if _selected_node_id != "":
		return _hovered_node_id if _hovered_node_id == _selected_node_id else ""
	return _hovered_node_id


## 根据节点类型和视觉状态计算圆点颜色
func _node_dot_color(node_type: String, node_id: String, visual_state: int) -> Color:
	# 拿破仑所在地使用金色系
	if node_id == _napoleon_location_id:
		return CentJoursTheme.COLOR["gold_bright"] if visual_state > 0 else CentJoursTheme.COLOR["gold"]

	# 基础颜色按节点类型分级
	var base := Color(0.42, 0.54, 0.70, 0.65)
	if node_type == "capital":
		base = Color(0.85, 0.75, 0.50, 0.95)
	elif node_type in ["major_city", "fortress_city"]:
		base = Color(0.55, 0.65, 0.80, 0.90)
	elif node_type in ["regional_capital", "royal_palace"]:
		base = Color(0.49, 0.60, 0.78, 0.82)
	# 视觉状态叠加亮度调整
	if visual_state == 2:
		return Color(base.r + 0.12, base.g + 0.10, base.b, 1.0)
	if visual_state == 1:
		return Color(base.r + 0.08, base.g + 0.08, base.b, 0.95)
	if visual_state == 3:
		return Color(base.r + 0.18, base.g + 0.15, base.b + 0.02, 0.98)
	return base


## 根据节点视觉状态计算光环颜色（透明度变化）
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


func _node_logistics_ring_color(node_info: Dictionary, node_id: String) -> Color:
	if _forward_depot_days > 0 and node_id == _forward_depot_location:
		return Color(0.88, 0.78, 0.32, 0.18)
	var supply_capacity := int(node_info.get("supply_capacity", 0))
	if supply_capacity >= 10:
		return Color(0.62, 0.72, 0.58, 0.10)
	if supply_capacity <= 2:
		return Color(0.74, 0.42, 0.34, 0.10)
	if supply_capacity >= 6:
		return Color(0.58, 0.66, 0.76, 0.08)
	return Color(0, 0, 0, 0)


## 根据标签状态计算文字颜色
func _node_label_color(is_focus: bool, is_selected: bool, is_hovered: bool, is_march_target: bool) -> Color:
	if is_focus or is_selected:
		return CentJoursTheme.COLOR["gold_bright"]
	if is_hovered:
		return CentJoursTheme.COLOR["text_primary"]
	if is_march_target:
		return CentJoursTheme.COLOR["gold_dim"]
	return CentJoursTheme.COLOR["text_heading"]


# ── 辅助函数 ─────────────────────────────────────────────────

## 获取节点法文显示名称（优先 name_fr，回退到 name 和 id）
func _node_label_text(node_info: Dictionary) -> String:
	return String(node_info.get("name_fr", node_info.get("name", node_info.get("id", ""))))


## 检查节点是否为行军目标
func _is_march_target(node_id: String) -> bool:
	return _march_target_ids.has(node_id)


## 检查边是否为行军路线（连接起点与目标之一）
func _is_march_route(from_id: String, to_id: String) -> bool:
	if _march_origin_id == "" or _march_target_ids.is_empty():
		return false
	return (
		(from_id == _march_origin_id and _march_target_ids.has(to_id))
		or (to_id == _march_origin_id and _march_target_ids.has(from_id))
	)
