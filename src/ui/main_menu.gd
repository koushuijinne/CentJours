## MainMenu — Priority A 主场景控制脚本
## 仅负责 UI 骨架、占位数据展示与现有组件接入
## 不直接驱动 TurnManager 或 CentJoursEngine

extends Control

## 全部 8 条政策 ID（与 Rust default_policies() 一致）
const PRIORITY_POLICY_IDS := [
	"conscription",
	"public_speech",
	"constitutional_promise",
	"increase_military_budget",
	"grant_titles",
	"reduce_taxes",
	"secret_diplomacy",
	"print_money"
]

## 政策卡片图标（UI 展示用）
const POLICY_EMOJIS := {
	"conscription": "🪖",
	"public_speech": "📣",
	"constitutional_promise": "📜",
	"increase_military_budget": "💰",
	"grant_titles": "👑",
	"reduce_taxes": "🪙",
	"secret_diplomacy": "🕵️",
	"print_money": "🏦"
}

const POLICY_EFFECTS := {
	"conscription": [
		{"label": "Troops", "value": 8, "type": "positive"},
		{"label": "Populace", "value": -3, "type": "negative"},
		{"label": "Rouge", "value": 5, "type": "rn"}
	],
	"public_speech": [
		{"label": "Populace", "value": 5, "type": "positive"},
		{"label": "Nobility", "value": -2, "type": "negative"},
		{"label": "Rouge", "value": 3, "type": "rn"}
	],
	"constitutional_promise": [
		{"label": "Liberals", "value": 7, "type": "positive"},
		{"label": "Nobility", "value": -3, "type": "negative"},
		{"label": "Noir", "value": -8, "type": "rn"}
	],
	"increase_military_budget": [
		{"label": "Military", "value": 6, "type": "positive"},
		{"label": "Economy", "value": -4, "type": "negative"},
		{"label": "Rouge", "value": 4, "type": "rn"}
	],
	## 数据来源：politics/system.rs grant_titles — 贵族+12, 自由派-5, 民众-3, Noir-5
	"grant_titles": [
		{"label": "Nobility", "value": 12, "type": "positive"},
		{"label": "Liberals", "value": -5, "type": "negative"},
		{"label": "Populace", "value": -3, "type": "negative"},
		{"label": "Noir", "value": -5, "type": "rn"}
	],
	## 数据来源：politics/system.rs reduce_taxes — 民众+10, 自由派+3, 经济-8
	"reduce_taxes": [
		{"label": "Populace", "value": 10, "type": "positive"},
		{"label": "Liberals", "value": 3, "type": "positive"},
		{"label": "Economy", "value": -8, "type": "negative"}
	],
	## 数据来源：politics/system.rs secret_diplomacy — 2行动点, Noir-3, CD15天
	"secret_diplomacy": [
		{"label": "Cost", "value": 2, "type": "negative"},
		{"label": "Noir", "value": -3, "type": "rn"}
	],
	## 数据来源：politics/system.rs print_money — 经济+15, 全派系负面, Rouge+8, CD20天
	"print_money": [
		{"label": "Economy", "value": 15, "type": "positive"},
		{"label": "Populace", "value": -5, "type": "negative"},
		{"label": "Liberals", "value": -8, "type": "negative"},
		{"label": "Nobility", "value": -5, "type": "negative"},
		{"label": "Rouge", "value": 8, "type": "rn"}
	]
}

## 战斗行动卡元数据（非政策，直接触发战斗参数弹窗）
const BATTLE_CARD_META := {
	"policy_id": "battle",
	"name": "发动战役",
	"emoji": "⚔️",
	"effects": [
		{"label": "Risk", "value": 0, "type": "negative"}
	]
}

## 忠诚度强化卡元数据（消耗5合法性→忠诚度+8）
const BOOST_CARD_META := {
	"policy_id": "boost_loyalty",
	"name": "亲自接见将领",
	"emoji": "🤝",
	"effects": [
		{"label": "Legitimacy", "value": -5, "type": "negative"},
		{"label": "Loyalty", "value": 8, "type": "positive"}
	]
}

## 结局 ID → 中文标题和描述（Rust GameOutcome.as_str() 返回值）
const OUTCOME_TEXT := {
	"napoleon_victory": {
		"title": "拿破仑的凯旋",
		"desc": "合法性与军事胜利兼得，帝国重建。历史被改写。"
	},
	"waterloo_historical": {
		"title": "滑铁卢 — 历史重演",
		"desc": "合法性尚存但胜场不足，百日王朝以滑铁卢告终。"
	},
	"waterloo_defeat": {
		"title": "彻底败亡",
		"desc": "合法性崩塌，军事失利。拿破仑被流放至圣赫勒拿岛。"
	},
	"political_collapse": {
		"title": "政治崩溃",
		"desc": "派系全面倒戈，帝国从内部瓦解。拿破仑被迫再次退位。"
	},
	"military_annihilation": {
		"title": "军事覆灭",
		"desc": "兵力耗尽，法军不复存在。反法联军长驱直入巴黎。"
	}
}

## 地形 ID → 显示名（与 lib.rs terrain match 一致）
const TERRAIN_OPTIONS := {
	"plains": "平原",
	"hills": "丘陵",
	"forest": "森林",
	"urban": "城镇",
	"river_crossing": "河口",
	"ridgeline": "山脊"
}

# 地图数据从 map_nodes.json 动态加载（替代硬编码占位）
var _map_nodes: Array = []    # JSON nodes[] 数组
var _map_edges: Array = []    # JSON edges[] 数组
# 坐标归一化范围（从 JSON 中动态计算）
var _map_x_min: float = 0.0
var _map_x_max: float = 1.0
var _map_y_min: float = 0.0
var _map_y_max: float = 1.0
var _map_node_index: Dictionary = {}
var _map_adjacency_by_node: Dictionary = {}

const MAP_LABEL_ANCHORS := ["right_up", "right_down", "left_up", "left_down"]
const MAP_LABEL_GAP := 6.0
const MAP_HOTSPOT_MIN_SIZE := 24.0
const MAP_LABEL_PADDING_X := 8.0
const MAP_LABEL_PADDING_Y := 4.0
const MAP_RESERVED_TOP_LEFT := Vector2(360.0, 42.0)

const NODE_LABEL_POLICY := {
	"capital": {
		"dot": 16, "font": 13,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 100
	},
	"major_city": {
		"dot": 12, "font": 11,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 90
	},
	"fortress_city": {
		"dot": 10, "font": 10,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 82
	},
	"regional_capital": {
		"dot": 8, "font": 9,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 72
	},
	"royal_palace": {
		"dot": 8, "font": 10,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 78
	},
	"coastal_landing": {
		"dot": 6, "font": 9,
		"always_show": false, "default_visible": true, "hover_only": false,
		"label_priority": 70
	},
	"fortress_town": {
		"dot": 7, "font": 9,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 58
	},
	"fortress": {
		"dot": 7, "font": 9,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 56
	},
	"small_town": {
		"dot": 5, "font": 8,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 36
	},
	"village": {
		"dot": 5, "font": 9,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 40
	},
	"crossroads": {
		"dot": 4, "font": 8,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 34
	},
	"palace_town": {
		"dot": 6, "font": 9,
		"always_show": false, "default_visible": false, "hover_only": true,
		"label_priority": 46
	}
}

const FACTION_LABELS := {
	"military": "军方",
	"populace": "民众",
	"liberals": "自由派",
	"nobility": "旧贵族"
}

# 休整卡元数据（固定出现在托盘最左侧）
const REST_CARD_META := {
	"policy_id": "rest",
	"name": "休整",
	"emoji": "🌙",
	"effects": [
		{"label": "Fatigue", "value": -10, "type": "positive"},
		{"label": "Morale",  "value":   3, "type": "positive"}
	]
}

# 叙事日志最大保留条数（超出后移除最旧条目）
const NARRATIVE_MAX_ENTRIES: int = 5

@onready var _root_layout: VBoxContainer = $RootLayout
@onready var _top_bar: PanelContainer = $RootLayout/TopBar
@onready var _top_bar_margin: MarginContainer = $RootLayout/TopBar/TopBarMargin
@onready var _top_bar_row: HBoxContainer = $RootLayout/TopBar/TopBarMargin/TopBarRow
@onready var _day_label: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/DayBlock/DayLabel
@onready var _phase_label: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/DayBlock/PhaseLabel
@onready var _rn_block: VBoxContainer = $RootLayout/TopBar/TopBarMargin/TopBarRow/RNBlock
@onready var _rn_slot: Control = $RootLayout/TopBar/TopBarMargin/TopBarRow/RNBlock/RougeNoirSlot
@onready var _legitimacy_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/LegitimacyBlock/LegitimacyHeader/LegitimacyValue
@onready var _legitimacy_bar: ProgressBar = $RootLayout/TopBar/TopBarMargin/TopBarRow/LegitimacyBlock/LegitimacyBar
@onready var _troops_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/TroopsBlock/TroopsValue
@onready var _morale_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/MoraleBlock/MoraleValue
@onready var _fatigue_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/FatigueBlock/FatigueValue
@onready var _main_area: HBoxContainer = $RootLayout/MainArea
@onready var _left_column: VBoxContainer = $RootLayout/MainArea/LeftColumn
@onready var _map_area: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea
@onready var _map_content: Control = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent
@onready var _map_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapTitle
@onready var _map_subtitle: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapSubtitle
@onready var _map_canvas: Control = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapCanvas
@onready var _map_inspector_panel: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel
@onready var _map_inspector_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorBox/MapInspectorTitle
@onready var _map_inspector_meta: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorBox/MapInspectorMeta
@onready var _map_inspector_stats: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorBox/MapInspectorStats
@onready var _map_inspector_history: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorBox/MapInspectorHistory
@onready var _sidebar: PanelContainer = $RootLayout/MainArea/Sidebar
@onready var _sidebar_margin: MarginContainer = $RootLayout/MainArea/Sidebar/SidebarMargin
@onready var _sidebar_content: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent
@onready var _situation_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel
@onready var _situation_box: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox
@onready var _situation_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox/SituationBody
@onready var _loyalty_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel
@onready var _loyalty_scroll: ScrollContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel/LoyaltyMargin/LoyaltyBox/LoyaltyScroll
@onready var _loyalty_list: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel/LoyaltyMargin/LoyaltyBox/LoyaltyScroll/LoyaltyList
@onready var _narrative_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel
@onready var _narrative_box: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox
@onready var _narrative_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox/NarrativeBody
@onready var _decision_tray: PanelContainer = $RootLayout/MainArea/LeftColumn/DecisionTray
@onready var _tray_margin: MarginContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin
@onready var _tray_content: VBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent
@onready var _tray_header: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader
@onready var _tray_hint: Label = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader/TrayHint
@onready var _decision_scroll: ScrollContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll
@onready var _decision_row: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll/DecisionRow

var _rn_slider: RougeNoirSlider
var _confirm_button: Button       # 执行行动确认按钮（动态创建）
var _rn_overlay: ColorRect        # 全屏 Rouge/Noir 氛围叠加层（极低 alpha）
var _battle_popup: PopupPanel = null   # 战斗参数选择弹窗
var _boost_popup: PopupPanel = null    # 忠诚度强化选择弹窗
var _selected_policy_id: String = ""
var _awaiting_action: bool = false  # 是否处于等待玩家操作的 Action Phase
var _narrative_log: Array = []    # 叙事日志，最新条目在前，最多 NARRATIVE_MAX_ENTRIES 条
# 上回合数值快照，用于派系趋势箭头和数值变化动效
var _prev_faction_support: Dictionary = {}
var _prev_legitimacy: float = 50.0
var _prev_troops: int = 0
var _prev_morale: float = 70.0
var _hovered_map_node_id: String = ""
var _selected_map_node_id: String = ""
var _map_points_by_id: Dictionary = {}
var _map_node_controls_by_id: Dictionary = {}
var _map_edge_lines_by_node: Dictionary = {}
var _map_rebuild_in_progress: bool = false

func _ready() -> void:
	# 统一入口主题，保证占位骨架先具备正式视觉语言。
	theme = CentJoursTheme.create()
	_load_map_data()
	_configure_static_ui()
	_apply_panel_styles()
	_build_rouge_noir_slider()
	_build_decision_cards()
	_build_confirm_button()
	_build_rn_overlay()
	_connect_signals()
	resized.connect(_on_main_menu_resized)
	call_deferred("_apply_responsive_layout")
	call_deferred("_refresh_ui")
	call_deferred("_rebuild_map_nodes")
	# 引导 TurnManager 进入第一回合，必须在所有节点就绪后执行。
	call_deferred("_start_game")

## 从 map_nodes.json 加载地图节点和边数据，计算坐标归一化范围
func _load_map_data() -> void:
	var file := FileAccess.open("res://src/data/map_nodes.json", FileAccess.READ)
	if file == null:
		push_warning("[MainMenu] 无法加载 map_nodes.json，地图将为空")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[MainMenu] map_nodes.json 解析失败")
		return
	var data: Dictionary = json.data
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

	# 计算坐标边界用于归一化（留 5% 内边距）
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
		# 加 5% 内边距防止节点贴边
		var pad_x := (_map_x_max - _map_x_min) * 0.05
		var pad_y := (_map_y_max - _map_y_min) * 0.05
		_map_x_min -= pad_x
		_map_x_max += pad_x
		_map_y_min -= pad_y
		_map_y_max += pad_y

func _configure_static_ui() -> void:
	# 文字层级先定住，避免占位版看起来像默认 Godot 控件。
	_style_heading(_day_label, 24, CentJoursTheme.COLOR["text_heading"])
	_style_heading(_phase_label, 11, CentJoursTheme.COLOR["gold_dim"])
	_style_heading(_map_inspector_title, 12, CentJoursTheme.COLOR["text_heading"])
	_legitimacy_bar.show_percentage = false
	_legitimacy_bar.max_value = 100.0
	_situation_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_inspector_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_inspector_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_inspector_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_map_inspector()

func _apply_panel_styles() -> void:
	# 顶层面板统一采用深色帝国风；地图区单独加强层次感。
	_top_bar.add_theme_stylebox_override("panel",
		_make_panel_style(CentJoursTheme.COLOR["bg_panel_dark"], CentJoursTheme.COLOR["gold_dim"], 0.30))
	_sidebar.add_theme_stylebox_override("panel",
		_make_panel_style(CentJoursTheme.COLOR["bg_panel"], CentJoursTheme.COLOR["border_panel"], 0.24))
	_map_area.add_theme_stylebox_override("panel",
		_make_panel_style(Color("#111821"), CentJoursTheme.COLOR["gold_dim"], 0.34))
	_map_inspector_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.09, 0.11, 0.18, 0.94), CentJoursTheme.COLOR["border_panel"], 0.20))
	_decision_tray.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.08, 0.09, 0.14, 0.96), CentJoursTheme.COLOR["border_panel"], 0.30))
	_situation_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.11, 0.12, 0.18, 0.96), CentJoursTheme.COLOR["border_panel"], 0.16))
	_loyalty_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.10, 0.11, 0.17, 0.96), CentJoursTheme.COLOR["border_panel"], 0.16))
	_narrative_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.09, 0.10, 0.16, 0.98), CentJoursTheme.COLOR["gold_dim"], 0.16))

func _build_rouge_noir_slider() -> void:
	_rn_slider = RougeNoirSlider.new()
	_rn_slider.show_labels = false
	_rn_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rn_slider.custom_minimum_size = Vector2(280, 24)
	_rn_slot.add_child(_rn_slider)

func _on_main_menu_resized() -> void:
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	var vertical_safe := int(clampf(roundf(viewport.y * 0.032), 22.0, 32.0))
	var horizontal_safe := int(clampf(roundf(viewport.x * 0.014), 16.0, 24.0))
	_root_layout.offset_left = horizontal_safe
	_root_layout.offset_top = vertical_safe
	_root_layout.offset_right = -horizontal_safe
	_root_layout.offset_bottom = -vertical_safe

	var root_sep := int(clampf(roundf(viewport.y * 0.013), 10.0, 14.0))
	_root_layout.add_theme_constant_override("separation", root_sep)
	_main_area.add_theme_constant_override("separation", root_sep)
	_left_column.add_theme_constant_override("separation", root_sep)

	var topbar_margin_top := int(clampf(roundf(viewport.y * 0.014), 10.0, 12.0))
	var topbar_margin_bottom := int(clampf(roundf(viewport.y * 0.010), 6.0, 8.0))
	_top_bar_margin.add_theme_constant_override("margin_top", topbar_margin_top)
	_top_bar_margin.add_theme_constant_override("margin_bottom", topbar_margin_bottom)
	_top_bar_margin.add_theme_constant_override("margin_left", int(clampf(roundf(viewport.x * 0.010), 14.0, 18.0)))
	_top_bar_margin.add_theme_constant_override("margin_right", int(clampf(roundf(viewport.x * 0.010), 14.0, 18.0)))
	_top_bar_row.add_theme_constant_override("separation", int(clampf(roundf(viewport.x * 0.010), 12.0, 18.0)))
	_rn_block.add_theme_constant_override("separation", 1)

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
	_tray_margin.add_theme_constant_override("margin_top", tray_margin)
	_tray_margin.add_theme_constant_override("margin_bottom", tray_margin)
	_tray_content.add_theme_constant_override("separation", int(clampf(roundf(viewport.y * 0.008), 6.0, 8.0)))
	_decision_row.add_theme_constant_override("separation", int(clampf(roundf(viewport.x * 0.006), 8.0, 12.0)))

	var sidebar_width := clampf(viewport.x * 0.27, 332.0, 372.0)
	_sidebar.custom_minimum_size.x = sidebar_width

	var card_size := Vector2(
		clampf(viewport.x * 0.102, 124.0, 140.0),
		clampf(viewport.y * 0.135, 96.0, 108.0)
	)
	_apply_decision_card_metrics(card_size)

	var scroll_height := card_size.y + float(tray_margin) + 6.0
	_decision_scroll.custom_minimum_size = Vector2(0.0, scroll_height)
	_decision_tray.size_flags_vertical = 0
	_decision_tray.custom_minimum_size.y = _compute_tray_min_height(scroll_height, tray_margin)

	_situation_panel.custom_minimum_size.y = _panel_min_height(_situation_box, 20.0, 100.0)
	_narrative_panel.custom_minimum_size.y = _panel_min_height(_narrative_box, 24.0, 148.0)
	_loyalty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loyalty_scroll.custom_minimum_size = Vector2.ZERO
	_loyalty_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loyalty_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loyalty_list.custom_minimum_size.x = _compute_loyalty_content_width(sidebar_width)

	_top_bar.custom_minimum_size.y = _compute_topbar_min_height(topbar_margin_top, topbar_margin_bottom)
	_top_bar.update_minimum_size()
	_decision_tray.update_minimum_size()
	_sidebar.update_minimum_size()

func _apply_decision_card_metrics(card_size: Vector2) -> void:
	for child in _decision_row.get_children():
		if child is DecisionCard:
			child.apply_layout_metrics(card_size)

func _compute_topbar_min_height(margin_top: int, margin_bottom: int) -> float:
	var row_min := _top_bar_row.get_combined_minimum_size().y
	return maxf(72.0, row_min + margin_top + margin_bottom + 4.0)

func _compute_tray_min_height(scroll_height: float, margin_vertical: int) -> float:
	var header_height := maxf(_tray_header.get_combined_minimum_size().y, _confirm_button.get_combined_minimum_size().y if _confirm_button != null else 28.0)
	var gap := float(_tray_content.get_theme_constant("separation"))
	return maxf(156.0, scroll_height + header_height + gap + margin_vertical * 2.0 + 4.0)

func _panel_min_height(content: Control, breathing_room: float, floor_value: float) -> float:
	return maxf(floor_value, content.get_combined_minimum_size().y + breathing_room)

func _compute_loyalty_content_width(sidebar_width: float) -> float:
	# LoyaltyScroll 的内容宽度必须显式绑定到侧栏可用宽度，否则 VBox 会按最小宽度收缩，
	# 导致名字列被压成 0，只剩右侧忠诚度文本可见。
	var scroll_width := _loyalty_scroll.size.x
	if scroll_width <= 0.0:
		scroll_width = sidebar_width - 52.0
	return maxf(scroll_width - 6.0, 240.0)

func _build_decision_cards() -> void:
	# 托盘卡片：先放固定"休整"卡，再放政策卡（ADR-004）
	for child in _decision_row.get_children():
		child.queue_free()

	# 休整卡固定在最左侧，始终可用
	var rest_card := DecisionCard.new()
	rest_card.policy_id       = REST_CARD_META["policy_id"]
	rest_card.policy_name     = REST_CARD_META["name"]
	rest_card.thumbnail_emoji = REST_CARD_META["emoji"]
	rest_card.cost_actions    = 1
	rest_card.effects         = REST_CARD_META["effects"]
	rest_card.card_selected.connect(_on_policy_selected)
	_decision_row.add_child(rest_card)

	for policy_id in PRIORITY_POLICY_IDS:
		var meta: Dictionary = PoliticalSystem.POLICY_META.get(policy_id, {})
		var card := DecisionCard.new()
		card.policy_id = policy_id
		card.policy_name = String(meta.get("name", policy_id))
		card.cost_actions = int(meta.get("cost", 1))
		card.thumbnail_emoji = String(POLICY_EMOJIS.get(policy_id, "📜"))
		card.effects = POLICY_EFFECTS.get(policy_id, [])
		card.card_selected.connect(_on_policy_selected)
		_decision_row.add_child(card)

	# 战斗行动卡（点击后弹出将领/兵力/地形选择弹窗）
	var battle_card := DecisionCard.new()
	battle_card.policy_id = BATTLE_CARD_META["policy_id"]
	battle_card.policy_name = BATTLE_CARD_META["name"]
	battle_card.thumbnail_emoji = BATTLE_CARD_META["emoji"]
	battle_card.cost_actions = 1
	battle_card.effects = BATTLE_CARD_META["effects"]
	battle_card.card_selected.connect(_on_policy_selected)
	_decision_row.add_child(battle_card)

	# 忠诚度强化卡（消耗5合法性，目标将领忠诚度+8）
	var boost_card := DecisionCard.new()
	boost_card.policy_id = BOOST_CARD_META["policy_id"]
	boost_card.policy_name = BOOST_CARD_META["name"]
	boost_card.thumbnail_emoji = BOOST_CARD_META["emoji"]
	boost_card.cost_actions = 1
	boost_card.effects = BOOST_CARD_META["effects"]
	boost_card.card_selected.connect(_on_policy_selected)
	_decision_row.add_child(boost_card)

## 全屏 Rouge/Noir 氛围叠加层，alpha 最大 0.15，不遮挡交互（ADR-004）
func _build_rn_overlay() -> void:
	_rn_overlay = ColorRect.new()
	_rn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rn_overlay.color = Color(0, 0, 0, 0)
	add_child(_rn_overlay)
	# 移到最顶层子节点确保叠加在所有面板之上
	move_child(_rn_overlay, get_child_count() - 1)

## 游戏开始时初始化叙事面板占位文本
func _init_narrative_panel() -> void:
	_narrative_log.clear()
	_narrative_body.text = "Jour 1 · 厄尔巴岛出发\n\n选择行动，历史将在此处展开。"
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])

## 向叙事日志追加一条新记录，最多保留 NARRATIVE_MAX_ENTRIES 条（ADR-004）
func _append_narrative(entry: String, color: Color) -> void:
	_narrative_log.push_front(entry)
	if _narrative_log.size() > NARRATIVE_MAX_ENTRIES:
		_narrative_log.pop_back()
	_narrative_body.text = "\n─────\n".join(_narrative_log)
	_narrative_body.add_theme_color_override("font_color", color)

## 在 TrayHeader 右侧动态创建"执行行动"确认按钮
func _build_confirm_button() -> void:
	_confirm_button = Button.new()
	_confirm_button.text = "执行行动 →"
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_confirm_button.custom_minimum_size = Vector2(120, 28)
	_confirm_button.disabled = true  # 初始禁用，等待 Action Phase
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_tray_header.add_child(_confirm_button)

## 引导第一回合：Dawn Phase 同步引擎真实状态，然后进入 Action Phase 等待玩家
func _start_game() -> void:
	TurnManager.start_new_turn()
	TurnManager.begin_action_phase()
	_awaiting_action = true
	_set_tray_interactive(true)
	_init_narrative_panel()

## 控制托盘卡片与确认按钮的可交互状态
func _set_tray_interactive(enabled: bool) -> void:
	_awaiting_action = enabled
	if _confirm_button != null:
		_confirm_button.disabled = not enabled
	if _tray_hint != null:
		_tray_hint.text = "选择一项政策或直接休整" if enabled else "结算中…"

func _connect_signals() -> void:
	# 接 UI 层信号：状态变化 → 刷新显示
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.legitimacy_changed.connect(_on_legitimacy_changed)
	EventBus.loyalty_changed.connect(_on_loyalty_changed)
	EventBus.historical_event_triggered.connect(_on_history_changed)
	# 接叙事信号：司汤达日记与行动后果文本
	EventBus.stendhal_diary_entry.connect(_on_stendhal_entry)
	EventBus.micro_narrative_shown.connect(_on_micro_narrative)
	# 接回合结束信号：驱动下一回合
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.game_over.connect(_on_game_over)
	_map_canvas.resized.connect(_rebuild_map_nodes)
	_map_canvas.gui_input.connect(_on_map_canvas_gui_input)

func _refresh_ui() -> void:
	_day_label.text = "Jour %d" % GameState.current_day
	_phase_label.text = _phase_display_name(GameState.current_phase)
	_legitimacy_value.text = "%.1f" % GameState.legitimacy
	_legitimacy_bar.value = GameState.legitimacy
	_troops_value.text = _format_number(GameState.total_troops)
	_morale_value.text = "%.0f" % GameState.avg_morale
	_fatigue_value.text = "%.0f" % GameState.avg_fatigue
	if _rn_slider != null:
		_rn_slider.set_value(GameState.rouge_noir_index)
	_refresh_situation_panel()
	_refresh_loyalty_panel()
	# 叙事面板有独立更新路径（_append_narrative / _on_policy_selected），不在此处刷新（ADR-004）
	_apply_rn_atmosphere()
	_update_card_selection()
	_refresh_card_cooldowns()
	# 数值变化闪烁动效（对比上回合快照）
	_flash_value_change(_legitimacy_value, GameState.legitimacy, _prev_legitimacy)
	_flash_value_change(_troops_value, float(GameState.total_troops), float(_prev_troops))
	_flash_value_change(_morale_value, GameState.avg_morale, _prev_morale)

## 数值变化时短暂闪烁颜色提示（增=绿 减=红），0.6秒后恢复原色
func _flash_value_change(label: Label, current: float, previous: float) -> void:
	var delta := current - previous
	if absf(delta) < 0.5:
		return
	var flash_color: Color
	if delta > 0:
		flash_color = Color(0.4, 0.9, 0.4)  # 绿色：数值增加
	else:
		flash_color = Color(0.9, 0.3, 0.2)  # 红色：数值减少
	var original_color: Color = CentJoursTheme.COLOR["text_heading"]
	label.add_theme_color_override("font_color", flash_color)
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func(): label.add_theme_color_override("font_color", original_color))

func _refresh_situation_panel() -> void:
	var faction_lines := []
	for faction_id in ["military", "populace", "liberals", "nobility"]:
		var support := float(GameState.faction_support.get(faction_id, 0.0))
		var prev := float(_prev_faction_support.get(faction_id, support))
		var arrow := _trend_arrow(support - prev)
		faction_lines.append("  %s %s %.0f %s" % [
			_faction_emoji(faction_id),
			FACTION_LABELS.get(faction_id, faction_id),
			support, arrow])

	_situation_body.text = "%s\n%s · Legitimacy %.1f\n\n%s" % [
		_phase_display_name(GameState.current_phase),
		_napoleon_location_label(),
		GameState.legitimacy,
		"\n".join(faction_lines)
	]
	_situation_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])

## 根据数值变化返回趋势箭头
func _trend_arrow(delta: float) -> String:
	if delta > 1.0: return "↑"
	elif delta < -1.0: return "↓"
	else: return "→"

## 派系对应的简短标识符号
func _faction_emoji(faction_id: String) -> String:
	match faction_id:
		"military": return "⚔"
		"populace": return "👥"
		"liberals": return "⚖"
		"nobility": return "👑"
		_: return "·"

func _refresh_loyalty_panel() -> void:
	for child in _loyalty_list.get_children():
		child.queue_free()

	# 按忠诚度降序，最多显示 6 位，给叙事面板留出稳定空间（ADR-006）
	const MAX_VISIBLE: int = 6
	var all_ids: Array = GameState.characters.keys()
	all_ids.sort_custom(func(a, b): return GameState.get_loyalty(a) > GameState.get_loyalty(b))

	var visible_ids := all_ids.slice(0, MAX_VISIBLE)
	var hidden_count: int = all_ids.size() - visible_ids.size()

	for hero_id in visible_ids:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.x = _loyalty_list.custom_minimum_size.x

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = maxf(row.custom_minimum_size.x - 132.0, 96.0)
		name_label.text = _character_display_name(hero_id)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
		row.add_child(name_label)

		var loyalty := GameState.get_loyalty(hero_id)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(126, 0)
		value_label.text = "%.0f · %s" % [loyalty, CentJoursTheme.get_loyalty_label(loyalty)]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_color_override("font_color", CentJoursTheme.get_loyalty_color(loyalty))
		row.add_child(value_label)

		_loyalty_list.add_child(row)

	# 溢出提示：告知玩家还有多少将领未展示
	if hidden_count > 0:
		var overflow := Label.new()
		overflow.text = "…另 %d 位将领" % hidden_count
		overflow.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		_loyalty_list.add_child(overflow)

## Rouge/Noir 氛围叠加：把 get_rn_tint() 的 bg_tint 写入全屏覆盖层（ADR-004）
func _apply_rn_atmosphere() -> void:
	if _rn_overlay == null:
		return
	var tint := CentJoursTheme.get_rn_tint(GameState.rouge_noir_index)
	_rn_overlay.color = tint["bg_tint"]

func _update_card_selection() -> void:
	for child in _decision_row.get_children():
		if child is DecisionCard:
			child.set_selected(child.policy_id == _selected_policy_id)

func _rebuild_map_nodes() -> void:
	if _map_canvas.size.x <= 0.0 or _map_canvas.size.y <= 0.0:
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
		return sa < sb)
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

## 将 JSON 中的原始坐标归一化到画布像素坐标
func _map_to_canvas(raw_x: float, raw_y: float) -> Vector2:
	var range_x := _map_x_max - _map_x_min
	var range_y := _map_y_max - _map_y_min
	if range_x <= 0.0: range_x = 1.0
	if range_y <= 0.0: range_y = 1.0
	return Vector2(
		(raw_x - _map_x_min) / range_x * _map_canvas.size.x,
		(raw_y - _map_y_min) / range_y * _map_canvas.size.y
	)

## 根据节点类型返回圆点像素尺寸
func _get_node_dot_size(node_type: String) -> int:
	var style: Dictionary = NODE_LABEL_POLICY.get(node_type, {"dot": 5})
	return int(style.get("dot", 5))

func _add_map_route(start: Vector2, target: Vector2, highlight_state: int) -> Line2D:
	# 用 Line2D 替代旋转 ColorRect，消除锯齿；hover/click 时提亮相邻路线。
	var line := Line2D.new()
	line.add_point(start)
	line.add_point(target)
	var base := CentJoursTheme.COLOR["gold_dim"]
	match highlight_state:
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
	var hotspot_size := maxf(dot_size + 12.0, MAP_HOTSPOT_MIN_SIZE)
	var container := Control.new()
	container.position = point - Vector2(hotspot_size * 0.5, hotspot_size * 0.5)
	container.size = Vector2.ONE * hotspot_size
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_entered.connect(_on_map_node_mouse_entered.bind(node_id))
	container.mouse_exited.connect(_on_map_node_mouse_exited.bind(node_id))
	container.gui_input.connect(_on_map_node_gui_input.bind(node_id, container))

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
	var policy: Dictionary = NODE_LABEL_POLICY.get(node_type, NODE_LABEL_POLICY["small_town"]).duplicate(true)
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

	if node_id == "paris" or node_id == String(GameState.napoleon_location):
		policy["always_show"] = true
		policy["default_visible"] = true
		policy["hover_only"] = false
		policy["label_priority"] = max(int(policy.get("label_priority", 80)), 120)

	return policy

func _build_reserved_label_rects() -> Array:
	var reserved: Array = []
	reserved.append(Rect2(Vector2.ZERO, MAP_RESERVED_TOP_LEFT))
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
	var is_focus := node_id == String(GameState.napoleon_location)
	var should_show := (
		bool(policy.get("always_show", false))
		or bool(policy.get("default_visible", false))
		or is_hovered
		or is_selected
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
		"priority": _node_label_priority(policy, is_focus, is_selected, is_hovered),
		"force_show": bool(policy.get("always_show", false)) or is_selected or is_hovered,
		"is_focus": is_focus,
		"is_selected": is_selected,
		"is_hovered": is_hovered
	}

func _label_anchor_order(policy: Dictionary) -> Array:
	var anchors: Array = []
	var preferred := String(policy.get("preferred_anchor", ""))
	if preferred != "" and MAP_LABEL_ANCHORS.has(preferred):
		anchors.append(preferred)
	for anchor in MAP_LABEL_ANCHORS:
		if not anchors.has(anchor):
			anchors.append(anchor)
	return anchors

func _node_label_priority(policy: Dictionary, is_focus: bool, is_selected: bool, is_hovered: bool) -> int:
	var priority := int(policy.get("label_priority", 40))
	if is_focus:
		priority += 20
	if is_selected:
		priority += 12
	elif is_hovered:
		priority += 8
	return priority

func _measure_label_size(display_name: String, font_size: int, is_focus: bool) -> Vector2:
	var width := maxf(54.0, display_name.length() * float(font_size) * 0.60 + MAP_LABEL_PADDING_X * 2.0)
	var height := float(font_size) + MAP_LABEL_PADDING_Y * 2.0
	if is_focus:
		width = maxf(width, 86.0)
		height += 12.0
	return Vector2(width, height)

func _build_label_rect(candidate: Dictionary, anchor: String) -> Rect2:
	var point: Vector2 = candidate.get("point", Vector2.ZERO)
	var label_size: Vector2 = candidate.get("label_size", Vector2(60, 16))
	var dot_size: float = float(candidate.get("dot_size", 5))
	var dot_half := dot_size * 0.5
	var x := point.x + dot_half + MAP_LABEL_GAP
	var y := point.y - label_size.y + 2.0
	match anchor:
		"right_down":
			y = point.y + 2.0
		"left_up":
			x = point.x - dot_half - MAP_LABEL_GAP - label_size.x
		"left_down":
			x = point.x - dot_half - MAP_LABEL_GAP - label_size.x
			y = point.y + 2.0
	return Rect2(Vector2(x, y), label_size)

func _can_use_label_rect(rect: Rect2, occupied_rects: Array) -> bool:
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
	rect.position.x = clampf(rect.position.x, 2.0, maxf(2.0, _map_canvas.size.x - rect.size.x - 2.0))
	rect.position.y = clampf(rect.position.y, 2.0, maxf(2.0, _map_canvas.size.y - rect.size.y - 2.0))
	return rect

func _add_map_label(candidate: Dictionary, rect: Rect2) -> void:
	var node_info: Dictionary = candidate.get("node_info", {})
	var is_focus: bool = bool(candidate.get("is_focus", false))
	var is_selected: bool = bool(candidate.get("is_selected", false))
	var is_hovered: bool = bool(candidate.get("is_hovered", false))

	var label_box := Control.new()
	label_box.position = rect.position
	label_box.size = rect.size
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.position = Vector2(MAP_LABEL_PADDING_X, MAP_LABEL_PADDING_Y - 1.0)
	name_label.text = _node_label_text(node_info)
	name_label.add_theme_font_size_override("font_size", int(candidate.get("font_size", 9)))
	name_label.add_theme_color_override("font_color", _node_label_color(is_focus, is_selected, is_hovered))
	label_box.add_child(name_label)

	if is_focus:
		var status := Label.new()
		status.position = Vector2(MAP_LABEL_PADDING_X, float(candidate.get("font_size", 9)) + 2.0)
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
	return 0

func _node_visual_state(node_id: String) -> int:
	if node_id == _selected_map_node_id:
		return 2
	if _selected_map_node_id == "" and node_id == _hovered_map_node_id:
		return 1
	return 0

func _effective_hovered_node_id() -> String:
	if _selected_map_node_id != "":
		return _hovered_map_node_id if _hovered_map_node_id == _selected_map_node_id else ""
	return _hovered_map_node_id

func _node_dot_color(node_type: String, node_id: String, visual_state: int) -> Color:
	if node_id == String(GameState.napoleon_location):
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
	return base

func _node_ring_color(node_id: String, visual_state: int) -> Color:
	if node_id == String(GameState.napoleon_location):
		return Color(1.0, 0.85, 0.30, 0.20 if visual_state == 0 else 0.32)
	if visual_state == 2:
		return Color(CentJoursTheme.COLOR["gold"].r, CentJoursTheme.COLOR["gold"].g, CentJoursTheme.COLOR["gold"].b, 0.18)
	if visual_state == 1:
		return Color(CentJoursTheme.COLOR["gold_dim"].r, CentJoursTheme.COLOR["gold_dim"].g, CentJoursTheme.COLOR["gold_dim"].b, 0.14)
	return Color(0, 0, 0, 0)

func _node_label_color(is_focus: bool, is_selected: bool, is_hovered: bool) -> Color:
	if is_focus or is_selected:
		return CentJoursTheme.COLOR["gold_bright"]
	if is_hovered:
		return CentJoursTheme.COLOR["text_primary"]
	return CentJoursTheme.COLOR["text_heading"]

func _node_label_text(node_info: Dictionary) -> String:
	return String(node_info.get("name_fr", node_info.get("name", node_info.get("id", ""))))

func _refresh_map_inspector() -> void:
	var inspector_node_id := _selected_map_node_id if _selected_map_node_id != "" else _hovered_map_node_id
	var is_hover_preview := _selected_map_node_id == "" and inspector_node_id != ""
	if inspector_node_id == "" or not _map_node_index.has(inspector_node_id):
		_map_inspector_title.text = "Map Inspector"
		_map_inspector_title.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
		_map_inspector_meta.text = "悬停查看节点，点击后锁定详情。"
		_map_inspector_stats.text = ""
		_map_inspector_history.text = ""
		_map_inspector_meta.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		_map_inspector_stats.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		_map_inspector_history.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		return

	var node_info: Dictionary = _map_node_index.get(inspector_node_id, {})
	var fr_name := _node_label_text(node_info)
	var cn_name := String(node_info.get("name", fr_name))
	_map_inspector_title.text = fr_name
	_map_inspector_title.add_theme_color_override(
		"font_color",
		CentJoursTheme.COLOR["gold_bright"] if inspector_node_id == String(GameState.napoleon_location) else CentJoursTheme.COLOR["text_heading"]
	)
	_map_inspector_meta.text = "%s%s\n类型：%s\n区域：%s · 地形：%s" % [
		"悬停预览\n" if is_hover_preview else "",
		cn_name,
		_humanize_token(String(node_info.get("type", "unknown"))),
		_humanize_token(String(node_info.get("region", "unknown"))),
		_humanize_token(String(node_info.get("terrain", "unknown")))
	]
	var marker := "Napoléon 当前所在\n" if inspector_node_id == String(GameState.napoleon_location) else ""
	_map_inspector_stats.text = "%s补给容量：%d\n防御加成：%.1f\n驻军：%d" % [
		marker,
		int(node_info.get("supply_capacity", 0)),
		float(node_info.get("defense_bonus", 0.0)),
		int(node_info.get("garrison", 0))
	]
	_map_inspector_history.text = String(node_info.get("historical_significance", "暂无补充史实。"))
	_map_inspector_meta.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	_map_inspector_stats.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
	_map_inspector_history.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])

func _on_map_node_mouse_entered(node_id: String) -> void:
	if _selected_map_node_id != "" and _selected_map_node_id != node_id:
		return
	if _hovered_map_node_id == node_id:
		return
	_hovered_map_node_id = node_id
	_refresh_map_inspector()
	call_deferred("_rebuild_map_nodes")

func _on_map_node_mouse_exited(node_id: String) -> void:
	if _map_rebuild_in_progress:
		return
	if _hovered_map_node_id != node_id:
		return
	_hovered_map_node_id = ""
	_refresh_map_inspector()
	call_deferred("_rebuild_map_nodes")

func _on_map_node_gui_input(event: InputEvent, node_id: String, hotspot: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hotspot.accept_event()
		if _selected_map_node_id == node_id:
			_selected_map_node_id = ""
		else:
			_selected_map_node_id = node_id
			_hovered_map_node_id = node_id
		_refresh_map_inspector()
		call_deferred("_rebuild_map_nodes")

func _on_map_canvas_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and (_selected_map_node_id != "" or _hovered_map_node_id != ""):
		_selected_map_node_id = ""
		_hovered_map_node_id = ""
		_refresh_map_inspector()
		call_deferred("_rebuild_map_nodes")

func _on_policy_selected(policy_id: String) -> void:
	# 仅在 Action Phase 允许切换选中政策
	if not _awaiting_action:
		return
	_selected_policy_id = policy_id
	_update_card_selection()
	# 叙事面板显示临时预览，不进入日志（ADR-004）
	if policy_id == "rest":
		_narrative_body.text = "休整 · 养精蓄锐\n\n让军队获得喘息之机，为下一步行动积蓄力量。"
	elif policy_id == "battle":
		_narrative_body.text = "发动战役\n\n选择将领和兵力，与反法联军决战。点击确认后选择参数。"
	elif policy_id == "boost_loyalty":
		_narrative_body.text = "亲自接见将领\n\n消耗 5 合法性，目标将领忠诚度 +8。需合法性 >= 10。"
	else:
		var meta: Dictionary = PoliticalSystem.POLICY_META.get(policy_id, {})
		_narrative_body.text = "▷ %s\n\n%s" % [
			String(meta.get("name", policy_id)),
			String(meta.get("summary", "等待结算…"))
		]
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])

## 玩家点击"执行行动"：分派到对应行动类型
func _on_confirm_pressed() -> void:
	if not _awaiting_action:
		return
	# 战斗和忠诚度强化需要弹窗选择参数，不直接提交
	if _selected_policy_id == "battle":
		_show_battle_popup()
		return
	if _selected_policy_id == "boost_loyalty":
		_show_boost_popup()
		return
	_set_tray_interactive(false)
	# "rest" policy_id 和空选均映射到 rest 行动（ADR-004）
	if _selected_policy_id != "" and _selected_policy_id != "rest":
		TurnManager.submit_action("policy", {"policy_id": _selected_policy_id})
	else:
		TurnManager.submit_action("rest", {})
	_selected_policy_id = ""
	_update_card_selection()

## 从 GameState.policy_cooldowns 刷新所有卡片的冷却状态（Rust 引擎权威数据）
## 跳过 rest/battle/boost_loyalty（它们不属于政策冷却系统）
func _refresh_card_cooldowns() -> void:
	for child in _decision_row.get_children():
		if child is DecisionCard and child.policy_id not in ["rest", "battle", "boost_loyalty"]:
			var cd: int = int(GameState.policy_cooldowns.get(child.policy_id, 0))
			child.on_cooldown = cd > 0
			child.cooldown_days = cd
			child.modulate = Color(1, 1, 1, 0.45) if cd > 0 else Color(1, 1, 1, 1.0)
			child._apply_current_style()

## 回合结束：保存旧数值快照 → 刷新 UI → 启动下一回合
func _on_turn_ended(_new_day: int) -> void:
	_snapshot_prev_values()
	_refresh_ui()
	call_deferred("_begin_next_turn")

## 保存当前数值作为下回合趋势对比基准
func _snapshot_prev_values() -> void:
	_prev_faction_support = GameState.faction_support.duplicate()
	_prev_legitimacy = GameState.legitimacy
	_prev_troops = GameState.total_troops
	_prev_morale = GameState.avg_morale

func _begin_next_turn() -> void:
	TurnManager.start_new_turn()
	TurnManager.begin_action_phase()
	_set_tray_interactive(true)

## 司汤达日记：进入滚动日志，金色调以区分于普通后果文本（ADR-004）
func _on_stendhal_entry(day: int, text: String) -> void:
	_append_narrative("Jour %d — Stendhal\n%s" % [day, text], CentJoursTheme.COLOR["gold_dim"])

## 行动后果微叙事：进入滚动日志（ADR-004）
func _on_micro_narrative(action_type: String, consequence: String) -> void:
	_append_narrative("▸ [%s]\n%s" % [action_type, consequence], CentJoursTheme.COLOR["text_primary"])

## 游戏结束：全屏遮罩 + 结局面板 + 统计 + 重启按钮
func _on_game_over(outcome: String) -> void:
	_set_tray_interactive(false)

	# 全屏半透明遮罩，阻断下层交互
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 居中结局面板
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 320)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = CentJoursTheme.COLOR["bg_primary"]
	style.border_color = CentJoursTheme.COLOR["gold_bright"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# 结局标题和描述
	var info: Dictionary = OUTCOME_TEXT.get(outcome, {"title": "— Fin —", "desc": outcome})
	var title_label := Label.new()
	title_label.text = info["title"]
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = info["desc"]
	desc_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 最终统计
	var stats := Label.new()
	stats.text = "\n最终统计\n天数: %d  |  合法性: %.0f\n胜场: %d  |  兵力: %d  |  士气: %.0f" % [
		GameState.current_day, GameState.legitimacy,
		GameState.victories, GameState.total_troops, GameState.avg_morale
	]
	stats.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	# 重新开始按钮
	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(140, 36)
	restart_btn.pressed.connect(_on_restart_pressed.bind(overlay))
	vbox.add_child(restart_btn)

	panel.add_child(vbox)
	overlay.add_child(panel)

## 重新开始游戏：销毁结局遮罩，重置引擎，重建 UI
func _on_restart_pressed(overlay: Control) -> void:
	overlay.queue_free()
	TurnManager.reset_engine()
	_build_decision_cards()
	_start_game()
	_refresh_ui()

# ── 战斗参数选择弹窗 ──────────────────────────────────────

## 弹出战斗参数面板：选择将领、兵力、地形后调用 TurnManager.submit_action("battle", ...)
func _show_battle_popup() -> void:
	if _battle_popup != null:
		_battle_popup.queue_free()
	_battle_popup = PopupPanel.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 300)

	# 标题
	var title := Label.new()
	title.text = "发动战役"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# 将领选择（筛选 role=marshal 的角色）
	var gen_label := Label.new()
	gen_label.text = "指挥将领："
	vbox.add_child(gen_label)
	var gen_option := OptionButton.new()
	for char_id in GameState.characters:
		var c: Dictionary = GameState.characters[char_id]
		if c.get("role", "") == "marshal":
			var loyalty: float = float(c.get("loyalty", 50))
			var skill: int = int(c.get("military_skill", 50))
			gen_option.add_item("%s (技能:%d 忠诚:%.0f)" % [c.get("name", char_id), skill, loyalty])
			gen_option.set_item_metadata(gen_option.item_count - 1, char_id)
	vbox.add_child(gen_option)

	# 兵力滑块
	var troop_label := Label.new()
	troop_label.text = "投入兵力："
	vbox.add_child(troop_label)
	var troop_slider := HSlider.new()
	troop_slider.min_value = 1000
	troop_slider.max_value = max(GameState.total_troops, 1000)
	troop_slider.step = 1000
	troop_slider.value = GameState.total_troops / 2
	vbox.add_child(troop_slider)
	var troop_value := Label.new()
	troop_value.text = "%d 人" % int(troop_slider.value)
	troop_slider.value_changed.connect(func(v: float): troop_value.text = "%d 人" % int(v))
	vbox.add_child(troop_value)

	# 地形选择（与 lib.rs terrain match 一致）
	var terrain_label := Label.new()
	terrain_label.text = "战场地形："
	vbox.add_child(terrain_label)
	var terrain_option := OptionButton.new()
	for tid in TERRAIN_OPTIONS:
		terrain_option.add_item(TERRAIN_OPTIONS[tid])
		terrain_option.set_item_metadata(terrain_option.item_count - 1, tid)
	vbox.add_child(terrain_option)

	# 按钮行
	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.text = "确认出战"
	confirm_btn.pressed.connect(_on_battle_confirmed.bind(gen_option, troop_slider, terrain_option))
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): _battle_popup.hide())
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_battle_popup.add_child(vbox)
	add_child(_battle_popup)
	_battle_popup.popup_centered()

## 战斗确认回调：提取参数并提交行动
func _on_battle_confirmed(gen_opt: OptionButton, troop_slider: HSlider, terrain_opt: OptionButton) -> void:
	var general_id: String = gen_opt.get_item_metadata(gen_opt.selected)
	var troops: int = int(troop_slider.value)
	var terrain: String = terrain_opt.get_item_metadata(terrain_opt.selected)
	_battle_popup.hide()
	_set_tray_interactive(false)
	# TurnManager "battle" 分支已实现（turn_manager.gd L77-82）
	TurnManager.submit_action("battle", {
		"general_id": general_id,
		"troops": troops,
		"terrain": terrain
	})
	_selected_policy_id = ""
	_update_card_selection()

# ── 忠诚度强化弹窗 ──────────────────────────────────────

## 弹出将领选择面板：选中后调用 TurnManager.submit_action("boost_loyalty", ...)
func _show_boost_popup() -> void:
	if _boost_popup != null:
		_boost_popup.queue_free()
	_boost_popup = PopupPanel.new()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 220)

	var title := Label.new()
	title.text = "亲自接见将领（-5 合法性 → +8 忠诚度）"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# 合法性不足警告
	if GameState.legitimacy < 10.0:
		var warn := Label.new()
		warn.text = "合法性不足（需 >= 10，当前 %.0f）" % GameState.legitimacy
		warn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		vbox.add_child(warn)

	# 将领列表（全部角色，按忠诚度排序更有参考价值）
	var gen_option := OptionButton.new()
	for char_id in GameState.characters:
		var c: Dictionary = GameState.characters[char_id]
		var loyalty: float = float(c.get("loyalty", 50))
		gen_option.add_item("%s (忠诚度: %.0f)" % [c.get("name", char_id), loyalty])
		gen_option.set_item_metadata(gen_option.item_count - 1, char_id)
	vbox.add_child(gen_option)

	# 按钮行
	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.text = "确认接见"
	confirm_btn.disabled = GameState.legitimacy < 10.0
	confirm_btn.pressed.connect(_on_boost_confirmed.bind(gen_option))
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): _boost_popup.hide())
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_boost_popup.add_child(vbox)
	add_child(_boost_popup)
	_boost_popup.popup_centered()

## 忠诚度强化确认回调：提取将领ID并提交行动
func _on_boost_confirmed(gen_opt: OptionButton) -> void:
	var general_id: String = gen_opt.get_item_metadata(gen_opt.selected)
	_boost_popup.hide()
	_set_tray_interactive(false)
	# TurnManager "boost_loyalty" 分支已实现（turn_manager.gd L87-88）
	TurnManager.submit_action("boost_loyalty", {"general_id": general_id})
	_selected_policy_id = ""
	_update_card_selection()

func _on_phase_changed(_phase: String) -> void:
	_refresh_ui()

func _on_legitimacy_changed(_old_value: float, _new_value: float) -> void:
	_refresh_ui()

func _on_loyalty_changed(_character_id: String, _old_value: float, _new_value: float) -> void:
	_refresh_ui()

func _on_history_changed(_event_id: String) -> void:
	_refresh_ui()

func _phase_display_name(phase_id: String) -> String:
	match phase_id:
		"dawn":
			return "Aube · 情报阶段"
		"action":
			return "Action · 决策阶段"
		"dusk":
			return "Crepuscule · 结算阶段"
		_:
			return phase_id.capitalize()

func _character_display_name(hero_id: String) -> String:
	var char_data: Dictionary = GameState.characters.get(hero_id, {})
	return String(char_data.get("name", hero_id.capitalize()))

func _napoleon_location_label() -> String:
	for node_info in _map_nodes:
		if String(node_info.get("id", "")) == String(GameState.napoleon_location):
			return String(node_info.get("name_fr", node_info.get("name", "Unknown")))
	return String(GameState.napoleon_location)

func _humanize_token(token: String) -> String:
	return token.replace("_", " ").capitalize()

func _format_number(value: int) -> String:
	var digits := str(value)
	var parts: Array[String] = []
	while digits.length() > 3:
		parts.push_front(digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.push_front(digits)
	return ",".join(parts)

func _style_heading(label: Label, font_size: int, font_color: Color) -> void:
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
