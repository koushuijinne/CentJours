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

# 节点类型对应的圆点尺寸和标签字号
const NODE_SIZE_MAP := {
	"capital": {"dot": 16, "font": 13, "show_label": true},
	"major_city": {"dot": 12, "font": 11, "show_label": true},
	"fortress_city": {"dot": 10, "font": 10, "show_label": true},
	"regional_capital": {"dot": 8, "font": 9, "show_label": true},
	"fortress_town": {"dot": 7, "font": 9, "show_label": false},
	"fortress": {"dot": 7, "font": 9, "show_label": false},
	"small_town": {"dot": 5, "font": 8, "show_label": false},
	"village": {"dot": 5, "font": 9, "show_label": true},
	"crossroads": {"dot": 4, "font": 8, "show_label": true},
	"palace_town": {"dot": 6, "font": 9, "show_label": false},
	"royal_palace": {"dot": 8, "font": 10, "show_label": true},
	"coastal_landing": {"dot": 6, "font": 9, "show_label": true},
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

@onready var _top_bar: PanelContainer = $RootLayout/TopBar
@onready var _day_label: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/DayBlock/DayLabel
@onready var _phase_label: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/DayBlock/PhaseLabel
@onready var _rn_slot: Control = $RootLayout/TopBar/TopBarMargin/TopBarRow/RNBlock/RougeNoirSlot
@onready var _legitimacy_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/LegitimacyBlock/LegitimacyHeader/LegitimacyValue
@onready var _legitimacy_bar: ProgressBar = $RootLayout/TopBar/TopBarMargin/TopBarRow/LegitimacyBlock/LegitimacyBar
@onready var _troops_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/TroopsBlock/TroopsValue
@onready var _morale_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/MoraleBlock/MoraleValue
@onready var _fatigue_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/FatigueBlock/FatigueValue
@onready var _map_area: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea
@onready var _map_canvas: Control = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapCanvas
@onready var _sidebar: PanelContainer = $RootLayout/MainArea/Sidebar
@onready var _situation_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel
@onready var _situation_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox/SituationBody
@onready var _loyalty_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel
@onready var _loyalty_list: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel/LoyaltyMargin/LoyaltyBox/LoyaltyList
@onready var _narrative_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel
@onready var _narrative_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox/NarrativeBody
@onready var _decision_tray: PanelContainer = $RootLayout/MainArea/LeftColumn/DecisionTray
@onready var _tray_header: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader
@onready var _tray_hint: Label = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader/TrayHint
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
	_style_heading(_phase_label, 12, CentJoursTheme.COLOR["gold_dim"])
	_legitimacy_bar.show_percentage = false
	_legitimacy_bar.max_value = 100.0
	_situation_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_panel_styles() -> void:
	# 顶层面板统一采用深色帝国风；地图区单独加强层次感。
	_top_bar.add_theme_stylebox_override("panel",
		_make_panel_style(CentJoursTheme.COLOR["bg_panel_dark"], CentJoursTheme.COLOR["gold_dim"], 0.30))
	_sidebar.add_theme_stylebox_override("panel",
		_make_panel_style(CentJoursTheme.COLOR["bg_panel"], CentJoursTheme.COLOR["border_panel"], 0.24))
	_map_area.add_theme_stylebox_override("panel",
		_make_panel_style(Color("#111821"), CentJoursTheme.COLOR["gold_dim"], 0.34))
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
	_rn_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rn_slider.custom_minimum_size = Vector2(280, 36)
	_rn_slot.add_child(_rn_slider)

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

	# 按忠诚度降序，最多显示 8 位（ADR-004 补丁：侧栏无 ScrollContainer，15人会溢出）
	const MAX_VISIBLE: int = 8
	var all_ids: Array = GameState.characters.keys()
	all_ids.sort_custom(func(a, b): return GameState.get_loyalty(a) > GameState.get_loyalty(b))

	var visible_ids := all_ids.slice(0, MAX_VISIBLE)
	var hidden_count: int = all_ids.size() - visible_ids.size()

	for hero_id in visible_ids:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = _character_display_name(hero_id)
		name_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
		row.add_child(name_label)

		var loyalty := GameState.get_loyalty(hero_id)
		var value_label := Label.new()
		value_label.text = "%.0f · %s" % [loyalty, CentJoursTheme.get_loyalty_label(loyalty)]
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

	for child in _map_canvas.get_children():
		child.queue_free()

	# 从 JSON 数据构建节点坐标映射（归一化到画布尺寸）
	var points := {}
	for node_info in _map_nodes:
		var node_id: String = String(node_info.get("id", ""))
		points[node_id] = _map_to_canvas(float(node_info.get("x", 0)), float(node_info.get("y", 0)))

	# 绘制边（连接线）
	for edge in _map_edges:
		var from_id: String = String(edge.get("from", ""))
		var to_id: String = String(edge.get("to", ""))
		if from_id in points and to_id in points:
			_add_map_route(points[from_id], points[to_id])

	# 绘制节点（先画小节点，再画大节点，确保重要节点在上层）
	var sorted_nodes := _map_nodes.duplicate()
	sorted_nodes.sort_custom(func(a, b):
		var sa: int = _get_node_dot_size(String(a.get("type", "")))
		var sb: int = _get_node_dot_size(String(b.get("type", "")))
		return sa < sb)
	for node_info in sorted_nodes:
		var node_id: String = String(node_info.get("id", ""))
		if node_id in points:
			_add_map_node(node_info, points[node_id])

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
	var style: Dictionary = NODE_SIZE_MAP.get(node_type, {"dot": 5})
	return int(style.get("dot", 5))

func _add_map_route(start: Vector2, target: Vector2) -> void:
	# 用 Line2D 替代旋转 ColorRect，消除锯齿（ADR-004）
	var line := Line2D.new()
	line.add_point(start)
	line.add_point(target)
	line.width = 1.5
	line.default_color = Color(
		CentJoursTheme.COLOR["gold_dim"].r,
		CentJoursTheme.COLOR["gold_dim"].g,
		CentJoursTheme.COLOR["gold_dim"].b, 0.35)
	_map_canvas.add_child(line)

func _add_map_node(node_info: Dictionary, point: Vector2) -> void:
	var node_id: String = String(node_info.get("id", ""))
	var node_type: String = String(node_info.get("type", "small_town"))
	var style: Dictionary = NODE_SIZE_MAP.get(node_type, {"dot": 5, "font": 9, "show_label": false})
	var dot_size: int = int(style.get("dot", 5))
	var font_size: int = int(style.get("font", 9))
	var show_label: bool = bool(style.get("show_label", false))

	var is_focus := node_id == String(GameState.napoleon_location)
	# 拿破仑所在节点和关键战场始终显示标签
	if is_focus:
		show_label = true

	var container := Control.new()
	var half_dot := dot_size / 2.0
	container.position = point - Vector2(half_dot, half_dot)
	container.size = Vector2(140.0, 44.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 节点圆点
	var dot := ColorRect.new()
	dot.position = Vector2.ZERO
	dot.size = Vector2(dot_size, dot_size)
	if is_focus:
		dot.color = CentJoursTheme.COLOR["gold"]
	elif node_type == "capital":
		dot.color = Color(0.85, 0.75, 0.50, 0.95)
	elif node_type in ["major_city", "fortress_city"]:
		dot.color = Color(0.55, 0.65, 0.80, 0.90)
	else:
		dot.color = Color(0.42, 0.54, 0.70, 0.65)
	container.add_child(dot)

	# 拿破仑位置光环
	if is_focus:
		var ring := ColorRect.new()
		ring.position = Vector2(-4.0, -4.0)
		ring.size = Vector2(dot_size + 8, dot_size + 8)
		ring.color = Color(1, 0.85, 0.3, 0.12)
		container.add_child(ring)

	# 节点名称标签（用法语名 name_fr，回退到 name）
	if show_label:
		var display_name: String = String(node_info.get("name_fr", node_info.get("name", node_id)))
		var label := Label.new()
		label.position = Vector2(dot_size + 4.0, -2.0)
		label.text = display_name
		label.add_theme_color_override("font_color",
			CentJoursTheme.COLOR["gold_bright"] if is_focus else CentJoursTheme.COLOR["text_heading"])
		label.add_theme_font_size_override("font_size", font_size + 1 if is_focus else font_size)
		container.add_child(label)

	# 拿破仑位置标注
	if is_focus:
		var status := Label.new()
		status.position = Vector2(dot_size + 4.0, font_size + 2.0)
		status.text = "Napoléon"
		status.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
		status.add_theme_font_size_override("font_size", 8)
		container.add_child(status)

	_map_canvas.add_child(container)

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
