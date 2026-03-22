## MainMenu — Priority A 主场景控制脚本
## 仅负责 UI 骨架、占位数据展示与现有组件接入
## 不直接驱动 TurnManager 或 CentJoursEngine

extends Control

const PRIORITY_POLICY_IDS := [
	"conscription",
	"public_speech",
	"constitutional_promise",
	"increase_military_budget"
]

const POLICY_EMOJIS := {
	"conscription": "🪖",
	"public_speech": "📣",
	"constitutional_promise": "📜",
	"increase_military_budget": "💰"
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
	]
}

const MAP_NODE_LAYOUT := [
	{"id": "golfe_juan", "label": "Golfe-Juan", "x": 0.16, "y": 0.80},
	{"id": "lyon", "label": "Lyon", "x": 0.34, "y": 0.58},
	{"id": "paris", "label": "Paris", "x": 0.55, "y": 0.24},
	{"id": "ligny", "label": "Ligny", "x": 0.72, "y": 0.17},
	{"id": "waterloo", "label": "Waterloo", "x": 0.80, "y": 0.12},
	{"id": "brussels", "label": "Brussels", "x": 0.86, "y": 0.08}
]

const MAP_ROUTE_IDS := [
	["golfe_juan", "lyon"],
	["lyon", "paris"],
	["paris", "ligny"],
	["ligny", "waterloo"],
	["waterloo", "brussels"]
]

const FACTION_LABELS := {
	"military": "军方",
	"populace": "民众",
	"liberals": "自由派",
	"nobility": "旧贵族"
}

const LOYALTY_HEROES := ["davout", "ney", "fouche"]

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
var _selected_policy_id: String = ""
var _awaiting_action: bool = false  # 是否处于等待玩家操作的 Action Phase

func _ready() -> void:
	# 统一入口主题，保证占位骨架先具备正式视觉语言。
	theme = CentJoursTheme.create()
	_configure_static_ui()
	_apply_panel_styles()
	_build_rouge_noir_slider()
	_build_decision_cards()
	_build_confirm_button()
	_connect_signals()
	call_deferred("_refresh_ui")
	call_deferred("_rebuild_map_nodes")
	# 引导 TurnManager 进入第一回合，必须在所有节点就绪后执行。
	call_deferred("_start_game")

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
	# 托盘卡片直接绑定现有政策元数据，后续接 TurnManager 时无需重排布局。
	for child in _decision_row.get_children():
		child.queue_free()

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
	_refresh_narrative_panel()
	_update_card_selection()

func _refresh_situation_panel() -> void:
	var faction_summary := []
	for faction_id in ["military", "populace", "liberals", "nobility"]:
		var support := float(GameState.faction_support.get(faction_id, 0.0))
		faction_summary.append("%s %.0f" % [FACTION_LABELS.get(faction_id, faction_id), support])

	_situation_body.text = "Phase: %s\nLocation: %s\nLegitimacy: %.1f\n%s" % [
		_phase_display_name(GameState.current_phase),
		_napoleon_location_label(),
		GameState.legitimacy,
		" / ".join(faction_summary)
	]
	_situation_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])

func _refresh_loyalty_panel() -> void:
	for child in _loyalty_list.get_children():
		child.queue_free()

	for hero_id in LOYALTY_HEROES:
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

func _refresh_narrative_panel() -> void:
	var base_text := "主场景骨架已就位。\n这块面板后续承接司汤达日记、历史事件和行动后果。"
	if _selected_policy_id != "":
		var meta: Dictionary = PoliticalSystem.POLICY_META.get(_selected_policy_id, {})
		base_text = "已选政策: %s\n%s" % [
			String(meta.get("name", _selected_policy_id)),
			String(meta.get("summary", "等待接入真实结算与微叙事。"))
		]
	elif not GameState.triggered_events.is_empty():
		base_text = "已触发历史事件 %d 条。\n最近事件 ID: %s" % [
			GameState.triggered_events.size(),
			String(GameState.triggered_events.back())
		]

	_narrative_body.text = base_text
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])

func _update_card_selection() -> void:
	for child in _decision_row.get_children():
		if child is DecisionCard:
			child.set_selected(child.policy_id == _selected_policy_id)

func _rebuild_map_nodes() -> void:
	if _map_canvas.size.x <= 0.0 or _map_canvas.size.y <= 0.0:
		return

	for child in _map_canvas.get_children():
		child.queue_free()

	var points := {}
	for node_info in MAP_NODE_LAYOUT:
		points[node_info["id"]] = Vector2(
			_map_canvas.size.x * float(node_info["x"]),
			_map_canvas.size.y * float(node_info["y"])
		)

	for route in MAP_ROUTE_IDS:
		_add_map_route(points.get(route[0], Vector2.ZERO), points.get(route[1], Vector2.ZERO))

	for node_info in MAP_NODE_LAYOUT:
		_add_map_node(node_info, points[node_info["id"]])

func _add_map_route(start: Vector2, target: Vector2) -> void:
	var route := ColorRect.new()
	route.color = Color(CentJoursTheme.COLOR["gold_dim"].r,
		CentJoursTheme.COLOR["gold_dim"].g,
		CentJoursTheme.COLOR["gold_dim"].b, 0.28)
	route.position = start
	route.size = Vector2(start.distance_to(target), 2.0)
	route.pivot_offset = Vector2(0.0, 1.0)
	route.rotation = (target - start).angle()
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(route)

func _add_map_node(node_info: Dictionary, point: Vector2) -> void:
	var container := Control.new()
	container.position = point - Vector2(20.0, 20.0)
	container.size = Vector2(120.0, 44.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_focus := String(node_info.get("id", "")) == String(GameState.napoleon_location)

	var dot := ColorRect.new()
	dot.position = Vector2(0.0, 6.0)
	dot.size = Vector2(12.0, 12.0)
	dot.color = CentJoursTheme.COLOR["gold"] if is_focus else Color(0.42, 0.54, 0.70, 0.85)
	container.add_child(dot)

	var ring := ColorRect.new()
	ring.position = Vector2(-4.0, 2.0)
	ring.size = Vector2(20.0, 20.0)
	ring.color = Color(1, 1, 1, 0.05)
	ring.visible = is_focus
	container.add_child(ring)

	var label := Label.new()
	label.position = Vector2(18.0, 0.0)
	label.text = String(node_info.get("label", "Node"))
	label.add_theme_color_override("font_color",
		CentJoursTheme.COLOR["gold_bright"] if is_focus else CentJoursTheme.COLOR["text_heading"])
	label.add_theme_font_size_override("font_size", 11 if is_focus else 10)
	container.add_child(label)

	if is_focus:
		var status := Label.new()
		status.position = Vector2(18.0, 16.0)
		status.text = "Napoleon"
		status.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
		status.add_theme_font_size_override("font_size", 9)
		container.add_child(status)

	_map_canvas.add_child(container)

func _on_policy_selected(policy_id: String) -> void:
	# 仅在 Action Phase 允许切换选中政策
	if not _awaiting_action:
		return
	_selected_policy_id = policy_id
	_refresh_narrative_panel()
	_update_card_selection()

## 玩家点击"执行行动"：提交政策或休整，进入 Dusk 结算
func _on_confirm_pressed() -> void:
	if not _awaiting_action:
		return
	_set_tray_interactive(false)
	if _selected_policy_id != "":
		TurnManager.submit_action("policy", {"policy_id": _selected_policy_id})
	else:
		TurnManager.submit_action("rest", {})
	_selected_policy_id = ""
	_update_card_selection()

## 回合结束：刷新 UI，清空叙事暂存，启动下一回合的 Dawn + Action
func _on_turn_ended(_new_day: int) -> void:
	_refresh_ui()
	call_deferred("_begin_next_turn")

func _begin_next_turn() -> void:
	TurnManager.start_new_turn()
	TurnManager.begin_action_phase()
	_set_tray_interactive(true)

## 司汤达日记文本写入叙事面板
func _on_stendhal_entry(day: int, text: String) -> void:
	_narrative_body.text = "Jour %d — Stendhal\n\n%s" % [day, text]
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])

## 行动后果微叙事追加到叙事面板
func _on_micro_narrative(action_type: String, consequence: String) -> void:
	_narrative_body.text += "\n\n▸ [%s]\n%s" % [action_type, consequence]

## 游戏结束：禁用所有交互并显示结局
func _on_game_over(outcome: String) -> void:
	_set_tray_interactive(false)
	_narrative_body.text = "— Fin —\n\n结局: %s" % outcome
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])

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
	for node_info in MAP_NODE_LAYOUT:
		if String(node_info.get("id", "")) == String(GameState.napoleon_location):
			return String(node_info.get("label", "Unknown"))
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
