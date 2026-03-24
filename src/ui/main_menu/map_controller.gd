extends Node
class_name MainMenuMapController
## 地图控制器：管理数据模型、交互状态机和行军选点。
## 渲染逻辑已拆分至 MainMenuMapRenderController。

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")
const MAP_RENDER_CONTROLLER_PATH := "res://src/ui/main_menu/map_render_controller.gd"

const DEFAULT_MAP_NODES_PATH := "res://src/data/map_nodes.json"
const DEFAULT_MAP_TITLE := "THEATRE OF OPERATIONS"
const DEFAULT_INSPECTOR_TITLE := "Map Inspector"
const DEFAULT_INSPECTOR_HINT := "悬停查看节点，点击后锁定详情。"
const SUPPLY_WARNING_THRESHOLD := 45.0

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

# ── 数据模型 ──────────────────────────────────────────────────
## JSON 数据路径
var _map_nodes_path: String = DEFAULT_MAP_NODES_PATH
## 当前地图区域名称
var _map_region: String = ""
## 节点元数据列表（来自 JSON）
## node_info 契约: { id(String), name(String), name_fr(String), x(float), y(float),
##   type(String), region(String), terrain(String), ui(Dictionary),
##   supply_capacity(int), defense_bonus(float), garrison(int),
##   historical_significance(String) }
var _map_nodes: Array = []
## 边列表（来自 JSON），每项契约: { from(String), to(String) }
var _map_edges: Array = []
## 地图坐标 AABB（含 5% 边距）
var _map_x_min: float = 0.0
var _map_x_max: float = 1.0
var _map_y_min: float = 0.0
var _map_y_max: float = 1.0
## id(String) → node_info(Dictionary) 快速查找
var _map_node_index: Dictionary = {}
## id(String) → Array[String] 相邻节点 ID 列表
var _map_adjacency_by_node: Dictionary = {}

# ── UI 节点引用 ───────────────────────────────────────────────
var _map_canvas: Control = null
var _map_title: Label = null
var _map_subtitle: Label = null
var _map_inspector_panel: PanelContainer = null
var _map_inspector_title: Label = null
var _map_inspector_meta: Label = null
var _map_inspector_stats: Label = null
var _map_inspector_history: Label = null

# ── 交互状态 ──────────────────────────────────────────────────
var _napoleon_location_id: String = ""
var _hovered_map_node_id: String = ""
var _selected_map_node_id: String = ""
## id(String) → Vector2 屏幕坐标（渲染后的缓存）
var _map_points_by_id: Dictionary = {}
## id(String) → Control 热点控件（渲染后的缓存）
var _map_node_controls_by_id: Dictionary = {}
## id(String) → Array[Line2D] 关联边线（渲染后的缓存）
var _map_edge_lines_by_node: Dictionary = {}
var _map_rebuild_in_progress: bool = false
var _map_rebuild_pending: bool = false
## 行军预览：出发点节点 ID
var _march_origin_node_id: String = ""
## 行军预览：可达目标节点 ID 列表
var _march_target_node_ids: Array[String] = []
# 行军交互状态：是否处于行军选点模式
var _march_mode_active: bool = false
# 行军交互状态：玩家当前选中的待确认目标节点 ID
var _pending_march_target: String = ""

# ── 渲染器 ────────────────────────────────────────────────────
# 运行时加载渲染脚本，规避 preload 在当前解析链上的脚本类型报错。
var _renderer = load(MAP_RENDER_CONTROLLER_PATH).new()


# ── 初始化 / 生命周期 ────────────────────────────────────────

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


# ── 数据加载 ──────────────────────────────────────────────────

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

	## JSON 顶层契约: { map_region(String), nodes(Array), edges(Array) }
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

	# 计算 AABB 包围盒（含 5% 边距），供坐标变换使用
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


# ── 公共 Getter ──────────────────────────────────────────────

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


## 获取单个节点元数据（键名见 _map_nodes 变量注释）
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


# ── 交互状态机 ────────────────────────────────────────────────

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


# ── 渲染编排 ─────────────────────────────────────────────────

func request_map_rebuild() -> void:
	if _map_rebuild_pending:
		return
	_map_rebuild_pending = true
	call_deferred("_rebuild_map_nodes")


func rebuild_map_nodes() -> void:
	request_map_rebuild()


## 组装渲染上下文并委托给 _renderer，然后绑定热点信号
func _rebuild_map_nodes() -> void:
	_map_rebuild_pending = false
	if _map_canvas == null or _map_canvas.size.x <= 0.0 or _map_canvas.size.y <= 0.0:
		_finish_map_rebuild()
		return
	_map_rebuild_in_progress = true

	# 组装渲染上下文（键名见 MainMenuMapRenderController.rebuild 契约）
	var context := {
		"map_nodes": _map_nodes,
		"map_edges": _map_edges,
		"map_node_index": _map_node_index,
		"adjacency": _map_adjacency_by_node,
		"aabb": {
			"x_min": _map_x_min, "x_max": _map_x_max,
			"y_min": _map_y_min, "y_max": _map_y_max
		},
		"canvas": _map_canvas,
		"canvas_size": _map_canvas.size,
		"inspector_panel": _map_inspector_panel,
		"napoleon_location_id": _napoleon_location_id,
		"hovered_node_id": _hovered_map_node_id,
		"selected_node_id": _selected_map_node_id,
		"march_origin_id": _march_origin_node_id,
		"march_target_ids": _march_target_node_ids,
	}

	# 委托渲染器执行全量重绘
	var result: Dictionary = _renderer.rebuild(context)
	_map_points_by_id = result.get("points_by_id", {})
	_map_node_controls_by_id = result.get("node_controls_by_id", {})
	_map_edge_lines_by_node = result.get("edge_lines_by_node", {})

	# 渲染器创建热点控件但不绑定信号，此处统一绑定交互回调
	for node_id in _map_node_controls_by_id:
		var hotspot: Control = _map_node_controls_by_id[node_id]
		hotspot.mouse_entered.connect(on_map_node_mouse_entered.bind(node_id))
		hotspot.mouse_exited.connect(on_map_node_mouse_exited.bind(node_id))
		hotspot.gui_input.connect(on_map_node_gui_input.bind(node_id, hotspot))

	call_deferred("_finish_map_rebuild")


func _finish_map_rebuild() -> void:
	_map_rebuild_in_progress = false
	map_rebuilt.emit()


# ── 鼠标事件处理 ─────────────────────────────────────────────

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


# ── Inspector 面板 ────────────────────────────────────────────

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


# ── 辅助函数 ─────────────────────────────────────────────────

## 获取节点法文显示名称（优先 name_fr，回退到 name 和 id）
func _node_label_text(node_info: Dictionary) -> String:
	return String(node_info.get("name_fr", node_info.get("name", node_info.get("id", ""))))


## 去重并转换节点 ID 数组
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
	var march_preview := TurnManager.get_march_preview(node_id)
	var preview_text := ""
	var feedback_color := CentJoursTheme.COLOR["text_secondary"]
	if bool(march_preview.get("valid", false)):
		var supply_delta := float(march_preview.get("supply_delta", 0.0))
		var fatigue_delta := float(march_preview.get("fatigue_delta", 0.0))
		var morale_delta := float(march_preview.get("morale_delta", 0.0))
		var projected_supply := float(march_preview.get("projected_supply", GameState.supply))
		var supply_capacity := int(march_preview.get("supply_capacity", int(target_info.get("supply_capacity", 0))))
		var line_efficiency := float(march_preview.get("line_efficiency", 0.0))
		var supply_available := float(march_preview.get("supply_available", 0.0))
		var supply_demand := float(march_preview.get("supply_demand", 0.0))
		var pressure_label := _march_pressure_label(projected_supply, int(target_info.get("supply_capacity", 0)))
		preview_text = "预计补给：%s（%.0f，%+.1f）\n预计疲劳：%.0f（%+.1f）\n预计士气：%.0f（%+.1f）\n原因：%s\n建议：%s" % [
			pressure_label,
			projected_supply,
			supply_delta,
			float(march_preview.get("projected_fatigue", GameState.avg_fatigue)),
			fatigue_delta,
			float(march_preview.get("projected_morale", GameState.avg_morale)),
			morale_delta,
			_build_supply_reason_text(supply_capacity, line_efficiency, supply_available, supply_demand),
			_build_supply_recommendation(
				projected_supply,
				supply_delta,
				supply_capacity,
				line_efficiency,
				supply_available,
				supply_demand
			)
		]
		if projected_supply < SUPPLY_WARNING_THRESHOLD or supply_delta < -4.0:
			feedback_color = CentJoursTheme.COLOR["warning"]
	else:
		var supply_preview := _build_march_supply_preview(target_info)
		preview_text = String(supply_preview["text"])
		feedback_color = CentJoursTheme.COLOR["warning"] if supply_preview["is_warning"] else CentJoursTheme.COLOR["text_secondary"]
	march_feedback.emit(
		"行军部署\n\n从 %s 行军至 %s。\n确认后将推进一天，并同步疲劳与士气。\n%s" % [
			location_label,
			String(target_info.get("name_fr", node_id)),
			preview_text
		],
		feedback_color
	)


func _build_march_supply_preview(target_info: Dictionary) -> Dictionary:
	var supply_capacity := int(target_info.get("supply_capacity", 0))
	var current_supply := GameState.supply
	var pressure_label := "补给大致可维持"
	var risk_hint := "沿线仓储足够支撑短程推进。"
	var is_warning := false

	if supply_capacity <= 2:
		pressure_label = "补给压力很高"
		risk_hint = "这是低容量前线节点，推进后很容易继续掉补给。"
		is_warning = true
	elif supply_capacity <= 5:
		pressure_label = "补给压力偏高"
		risk_hint = "仓储容量有限，连续推进会明显拉长补给线。"
		is_warning = true
	elif supply_capacity >= 9:
		pressure_label = "补给有望回升"
		risk_hint = "这是高容量节点，适合作为下一段推进前的整补落点。"

	var stock_hint := "当前库存尚可。"
	if current_supply < SUPPLY_WARNING_THRESHOLD:
		stock_hint = "当前库存已经偏低，不宜连续赌前线节点。"
		is_warning = true
	elif current_supply >= 75.0 and supply_capacity >= 6:
		stock_hint = "当前库存较充足，可以承担一次正常推进。"

	return {
		"text": "预计补给：%s（容量 %d）\n%s\n%s" % [
			pressure_label,
			supply_capacity,
			risk_hint,
			stock_hint
		],
		"is_warning": is_warning
	}


func _march_pressure_label(projected_supply: float, supply_capacity: int) -> String:
	if projected_supply < SUPPLY_WARNING_THRESHOLD or supply_capacity <= 2:
		return "补给压力很高"
	if projected_supply < 60.0 or supply_capacity <= 5:
		return "补给压力偏高"
	if projected_supply >= 75.0 and supply_capacity >= 8:
		return "补给有望回升"
	return "补给大致可维持"


func _build_supply_reason_text(
	supply_capacity: int,
	line_efficiency: float,
	supply_available: float,
	supply_demand: float
) -> String:
	return "目标仓储容量 %d，补给线效率 %.0f%%，预计可得 %.1f，对应需求 %.1f。" % [
		supply_capacity,
		line_efficiency * 100.0,
		supply_available,
		supply_demand
	]


func _build_supply_recommendation(
	projected_supply: float,
	supply_delta: float,
	supply_capacity: int,
	line_efficiency: float,
	supply_available: float,
	supply_demand: float
) -> String:
	if projected_supply < SUPPLY_WARNING_THRESHOLD or supply_delta <= -6.0:
		if supply_capacity <= 2 or line_efficiency < 0.55:
			return "这是低容量前线节点。更稳的是先停在高容量节点整补；若必须前推，下一回合优先征用沿线仓储。"
		return "这一步会继续掉补给。若没有决定性战机，优先休整或回到高容量节点，再考虑推进。"
	if supply_available + 0.5 < supply_demand:
		return "沿线可得量低于部队需求，连续推进会把风险越积越高，下一步应优先补给而不是继续赶路。"
	if projected_supply >= 75.0 and supply_capacity >= 8:
		return "这里适合作为短暂整补落点，可以在下一步推进前先把疲劳和补给拉回安全区间。"
	return "当前推进还能维持，但不适合连续硬顶前线；继续东进前先确认下一站也有足够仓储。"
