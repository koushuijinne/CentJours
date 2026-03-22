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
var _selected_policy_id: String = ""
var _awaiting_action: bool = false  # 是否处于等待玩家操作的 Action Phase
var _narrative_log: Array = []    # 叙事日志，最新条目在前，最多 NARRATIVE_MAX_ENTRIES 条

func _ready() -> void:
	# 统一入口主题，保证占位骨架先具备正式视觉语言。
	theme = CentJoursTheme.create()
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

	# 按忠诚度降序显示全部将领，不再写死 3 人（ADR-004）
	var all_ids: Array = GameState.characters.keys()
	all_ids.sort_custom(func(a, b): return GameState.get_loyalty(a) > GameState.get_loyalty(b))

	for hero_id in all_ids:
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
	_update_card_selection()
	# 叙事面板显示临时预览，不进入日志（ADR-004）
	if policy_id == "rest":
		_narrative_body.text = "休整 · 养精蓄锐\n\n让军队获得喘息之机，为下一步行动积蓄力量。"
	else:
		var meta: Dictionary = PoliticalSystem.POLICY_META.get(policy_id, {})
		_narrative_body.text = "▷ %s\n\n%s" % [
			String(meta.get("name", policy_id)),
			String(meta.get("summary", "等待结算…"))
		]
	_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])

## 玩家点击"执行行动"：提交政策或休整，进入 Dusk 结算
func _on_confirm_pressed() -> void:
	if not _awaiting_action:
		return
	_set_tray_interactive(false)
	# "rest" policy_id 和空选均映射到 rest 行动（ADR-004）
	if _selected_policy_id != "" and _selected_policy_id != "rest":
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

## 司汤达日记：进入滚动日志，金色调以区分于普通后果文本（ADR-004）
func _on_stendhal_entry(day: int, text: String) -> void:
	_append_narrative("Jour %d — Stendhal\n%s" % [day, text], CentJoursTheme.COLOR["gold_dim"])

## 行动后果微叙事：进入滚动日志（ADR-004）
func _on_micro_narrative(action_type: String, consequence: String) -> void:
	_append_narrative("▸ [%s]\n%s" % [action_type, consequence], CentJoursTheme.COLOR["text_primary"])

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
