## MainMenu — Priority A 主场景控制脚本
## 仅负责 UI 骨架、占位数据展示与现有组件接入
## 不直接驱动 TurnManager 或 CentJoursEngine

extends Control

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")
const MainMenuLayoutControllerScript = preload("res://src/ui/main_menu/layout_controller.gd")
const MainMenuMapControllerScript = preload("res://src/ui/main_menu/map_controller.gd")
const MainMenuDialogsControllerScript = preload("res://src/ui/main_menu/dialogs_controller.gd")
const MainMenuSidebarControllerScript = preload("res://src/ui/main_menu/sidebar_controller.gd")
const MainMenuTrayControllerScript = preload("res://src/ui/main_menu/tray_controller.gd")

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
@onready var _supply_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/SupplyBlock/SupplyValue
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
@onready var _map_inspector_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorTitle
@onready var _map_inspector_meta: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorMeta
@onready var _map_inspector_stats: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorStats
@onready var _map_inspector_history: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorHistory
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
@onready var _decision_scroll_content: MarginContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll/DecisionScrollContent
@onready var _decision_row: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll/DecisionScrollContent/DecisionRow

var _confirm_button: Button       # 执行行动确认按钮（动态创建）
var _save_btn: Button             # 顶栏存档按钮（动态创建）
var _load_btn: Button             # 顶栏读档按钮（动态创建）
var _awaiting_action: bool = false  # 是否处于等待玩家操作的 Action Phase
# 上回合数值快照，用于派系趋势箭头和数值变化动效
var _prev_faction_support: Dictionary = {}
var _prev_legitimacy: float = 50.0
var _prev_troops: int = 0
var _prev_supply: float = 60.0
var _prev_morale: float = 70.0
var _layout_controller = MainMenuLayoutControllerScript.new()
var _map_controller = MainMenuMapControllerScript.new()
var _dialogs_controller = MainMenuDialogsControllerScript.new()
var _sidebar_controller = MainMenuSidebarControllerScript.new()
var _tray_controller = MainMenuTrayControllerScript.new()

func _ready() -> void:
	# 统一入口主题，保证占位骨架先具备正式视觉语言。
	theme = CentJoursTheme.create()
	add_child(_layout_controller)
	add_child(_map_controller)
	add_child(_dialogs_controller)
	add_child(_tray_controller)
	_configure_layout_controller()
	_configure_static_ui()
	_apply_panel_styles()
	_build_rouge_noir_slider()
	_configure_sidebar_controller()
	_build_confirm_button()
	_build_save_load_buttons()
	_configure_tray_controller()
	_configure_dialogs_controller()
	_build_decision_cards()
	_build_rn_overlay()
	_configure_map_controller()
	_connect_signals()
	resized.connect(_on_main_menu_resized)
	call_deferred("_apply_responsive_layout")
	call_deferred("_refresh_ui")
	# 引导 TurnManager 进入第一回合，必须在所有节点就绪后执行。
	call_deferred("_start_game")

func _configure_layout_controller() -> void:
	_layout_controller.bind_nodes({
		"root_layout": _root_layout,
		"main_area": _main_area,
		"left_column": _left_column,
		"top_bar": _top_bar,
		"top_bar_margin": _top_bar_margin,
		"top_bar_row": _top_bar_row,
		"day_label": _day_label,
		"phase_label": _phase_label,
		"rn_block": _rn_block,
		"rn_slot": _rn_slot,
		"legitimacy_bar": _legitimacy_bar,
		"situation_body": _situation_body,
		"narrative_body": _narrative_body,
		"map_inspector_title": _map_inspector_title,
		"map_inspector_meta": _map_inspector_meta,
		"map_inspector_stats": _map_inspector_stats,
		"map_inspector_history": _map_inspector_history,
		"sidebar": _sidebar,
		"map_area": _map_area,
		"map_inspector_panel": _map_inspector_panel,
		"situation_panel": _situation_panel,
		"situation_box": _situation_box,
		"loyalty_panel": _loyalty_panel,
		"loyalty_scroll": _loyalty_scroll,
		"loyalty_list": _loyalty_list,
		"narrative_panel": _narrative_panel,
		"narrative_box": _narrative_box,
		"decision_tray": _decision_tray,
		"tray_margin": _tray_margin,
		"tray_content": _tray_content,
		"tray_header": _tray_header,
		"tray_hint": _tray_hint,
		"decision_scroll": _decision_scroll,
		"decision_scroll_content": _decision_scroll_content,
		"decision_row": _decision_row,
	}, _tray_controller)

func _configure_map_controller() -> void:
	_map_controller.configure(
		_map_canvas,
		_map_title,
		_map_subtitle,
		_map_inspector_panel,
		_map_inspector_title,
		_map_inspector_meta,
		_map_inspector_stats,
		_map_inspector_history,
		"res://src/data/map_nodes.json",
		GameState.napoleon_location
	)

func _configure_dialogs_controller() -> void:
	_dialogs_controller.configure(self, {
		MainMenuDialogsControllerScript.CALLBACK_SET_TRAY_INTERACTIVE: Callable(self, "_set_tray_interactive"),
		MainMenuDialogsControllerScript.CALLBACK_RESET_ENGINE: Callable(TurnManager, "reset_engine"),
		MainMenuDialogsControllerScript.CALLBACK_REBUILD_DECISION_CARDS: Callable(self, "_build_decision_cards"),
		MainMenuDialogsControllerScript.CALLBACK_START_GAME: Callable(self, "_start_game"),
		MainMenuDialogsControllerScript.CALLBACK_REFRESH_UI: Callable(self, "_refresh_ui"),
		MainMenuDialogsControllerScript.CALLBACK_SUBMIT_ACTION: Callable(self, "_submit_modal_action"),
	})

func _configure_static_ui() -> void:
	_layout_controller.configure_static_ui()
	_map_controller.refresh_map_inspector()

func _apply_panel_styles() -> void:
	_layout_controller.apply_panel_styles()

func _build_rouge_noir_slider() -> void:
	_layout_controller.build_rouge_noir_slider(_rn_slot)

func _configure_sidebar_controller() -> void:
	_sidebar_controller.bind(_situation_body, _loyalty_list, _narrative_body)
	_sidebar_controller.set_loyalty_visible_limit(6)
	_sidebar_controller.set_loyalty_overflow_template("…另 %d 位将领")

func _configure_tray_controller() -> void:
	_tray_controller.bind_nodes(_decision_row, _tray_hint, _confirm_button)
	_tray_controller.set_tray_hint_texts("选择一项政策或直接休整", "结算中…")
	_tray_controller.set_confirm_button_text("执行行动 →")
	if not _tray_controller.policy_selected.is_connected(_on_policy_selected):
		_tray_controller.policy_selected.connect(_on_policy_selected)
	if not _tray_controller.confirm_requested.is_connected(_on_confirm_requested):
		_tray_controller.confirm_requested.connect(_on_confirm_requested)

func _on_main_menu_resized() -> void:
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	_layout_controller.apply_responsive_layout(get_viewport_rect().size)
	_map_controller.request_map_rebuild()

func _build_decision_cards() -> void:
	_tray_controller.clear_selection()
	_tray_controller.set_card_specs(_tray_controller.build_default_card_specs(
		MainMenuConfigData.REST_CARD_META,
		MainMenuConfigData.PRIORITY_POLICY_IDS,
		PoliticalSystem.POLICY_META,
		MainMenuConfigData.POLICY_EMOJIS,
		MainMenuConfigData.POLICY_EFFECTS,
		MainMenuConfigData.MARCH_CARD_META,
		MainMenuConfigData.BATTLE_CARD_META,
		MainMenuConfigData.BOOST_CARD_META
	))
	_clear_tray_selection()

## 全屏 Rouge/Noir 氛围叠加层，alpha 最大 0.15，不遮挡交互（ADR-004）
func _build_rn_overlay() -> void:
	_layout_controller.build_rn_overlay(self)

## 游戏开始时初始化叙事面板占位文本
func _init_narrative_panel() -> void:
	_sidebar_controller.reset_narrative(
		"Jour 1 · 厄尔巴岛出发\n\n选择行动，历史将在此处展开。",
		CentJoursTheme.COLOR["text_secondary"]
	)

## 向叙事日志追加一条新记录，最多保留 NARRATIVE_MAX_ENTRIES 条（ADR-004）
func _append_narrative(entry: String, color: Color) -> void:
	_sidebar_controller.append_narrative(entry, color)

## 在 TrayHeader 右侧动态创建"执行行动"确认按钮
func _build_confirm_button() -> void:
	_confirm_button = _tray_controller.create_confirm_button(_tray_header, "执行行动 →")

## 在 TopBarRow 右侧动态创建存档/读档按钮
func _build_save_load_buttons() -> void:
	var save_btn := Button.new()
	save_btn.text = "存档"
	save_btn.custom_minimum_size = Vector2(60, 0)
	save_btn.pressed.connect(_on_save_pressed)
	_top_bar_row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "读档"
	load_btn.custom_minimum_size = Vector2(60, 0)
	load_btn.pressed.connect(_on_load_pressed)
	# 仅在存档存在时可用
	load_btn.disabled = not SaveManager.has_save()
	_top_bar_row.add_child(load_btn)
	# 缓存按钮引用，读档后刷新可用状态
	_save_btn = save_btn
	_load_btn = load_btn

## 存档按钮回调
func _on_save_pressed() -> void:
	if TurnManager.save_to_file():
		_load_btn.disabled = false
		# 短暂闪烁按钮文字作为反馈
		_save_btn.text = "已存档 ✓"
		get_tree().create_timer(1.0).timeout.connect(func(): _save_btn.text = "存档")
	else:
		_save_btn.text = "存档失败"
		get_tree().create_timer(1.5).timeout.connect(func(): _save_btn.text = "存档")

## 读档按钮回调（带确认）
func _on_load_pressed() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "读档将丢失当前进度，确定吗？"
	confirm.ok_button_text = "确认读档"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		if TurnManager.load_from_save():
			_build_decision_cards()
			_refresh_ui()
			_awaiting_action = true
			_set_tray_interactive(true)
	)
	add_child(confirm)
	confirm.popup_centered()

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
	_sync_tray_state()

func _connect_signals() -> void:
	# 接 UI 层信号：状态变化 → 刷新显示
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.legitimacy_changed.connect(_on_legitimacy_changed)
	EventBus.loyalty_changed.connect(_on_loyalty_changed)
	EventBus.historical_event_triggered.connect(_on_history_changed)
	# 接叙事信号：司汤达日记与行动后果文本
	EventBus.stendhal_diary_entry.connect(_on_stendhal_entry)
	EventBus.micro_narrative_shown.connect(_on_micro_narrative)
	EventBus.action_resolution_logged.connect(_on_action_resolution_logged)
	# 接回合结束信号：驱动下一回合
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.game_over.connect(_on_game_over)
	_map_canvas.resized.connect(_map_controller.rebuild_map_nodes)
	_map_canvas.gui_input.connect(_map_controller.on_map_canvas_gui_input)
	_map_controller.selected_node_changed.connect(_on_map_selected_node_changed)
	# 行军交互信号：map_controller 管理行军选点状态机，main_menu 负责提交和侧边栏刷新
	_map_controller.march_confirmed.connect(_on_march_confirmed)
	_map_controller.march_feedback.connect(_on_march_feedback)

func _refresh_ui() -> void:
	_day_label.text = "Jour %d" % GameState.current_day
	_phase_label.text = _phase_display_name(GameState.current_phase)
	_legitimacy_value.text = "%.1f" % GameState.legitimacy
	_legitimacy_bar.value = GameState.legitimacy
	_troops_value.text = _format_number(GameState.total_troops)
	_supply_value.text = "%.0f" % GameState.supply
	_morale_value.text = "%.0f" % GameState.avg_morale
	_fatigue_value.text = "%.0f" % GameState.avg_fatigue
	_layout_controller.set_rn_value(GameState.rouge_noir_index)
	_map_controller.set_napoleon_location(GameState.napoleon_location)
	_refresh_logistics_guidance()
	_refresh_situation_panel()
	_refresh_loyalty_panel()
	# 叙事面板有独立更新路径（_append_narrative / _on_policy_selected），不在此处刷新（ADR-004）
	_apply_rn_atmosphere()
	_sync_tray_state()
	_refresh_card_cooldowns()
	# 数值变化闪烁动效（对比上回合快照）
	_flash_value_change(_legitimacy_value, GameState.legitimacy, _prev_legitimacy)
	_flash_value_change(_troops_value, float(GameState.total_troops), float(_prev_troops))
	_flash_value_change(_supply_value, GameState.supply, _prev_supply)
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
	_sidebar_controller.refresh_situation(
		GameState.current_phase,
		_napoleon_location_label(),
		GameState.legitimacy,
		GameState.supply,
		GameState.avg_fatigue,
		GameState.logistics_posture_label,
		GameState.logistics_focus_title,
		GameState.logistics_focus_detail,
		GameState.faction_support,
		_prev_faction_support
	)

func _refresh_loyalty_panel() -> void:
	_sidebar_controller.refresh_loyalty(
		GameState.characters,
		_loyalty_list.custom_minimum_size.x
	)

## Rouge/Noir 氛围叠加：把 get_rn_tint() 的 bg_tint 写入全屏覆盖层（ADR-004）
func _apply_rn_atmosphere() -> void:
	var tint := CentJoursTheme.get_rn_tint(GameState.rouge_noir_index)
	var overlay := _layout_controller.build_rn_overlay(self)
	if overlay != null:
		overlay.color = tint["bg_tint"]

func _sync_tray_state() -> void:
	_tray_controller.set_tray_state(_tray_controller.get_selected_policy_id(), _awaiting_action)
	_sync_march_preview()

func _refresh_logistics_guidance() -> void:
	var hint_text := "选择一项政策或直接休整"
	if GameState.logistics_focus_short.strip_edges() != "":
		hint_text = GameState.logistics_focus_short
	_tray_controller.set_tray_hint_texts(hint_text, "结算中…")
	_map_controller.set_context_subtitle(GameState.logistics_focus_short)


func _clear_tray_selection() -> void:
	_map_controller.clear_march_state()
	_tray_controller.clear_selection()
	_sync_tray_state()

func _on_confirm_requested(_policy_id: String) -> void:
	_on_confirm_pressed()

func _on_policy_selected(policy_id: String) -> void:
	# 仅在 Action Phase 允许切换选中政策
	if not _awaiting_action:
		return
	# 切换政策时清除行军交互状态
	_map_controller.clear_march_state()
	var meta: Dictionary = PoliticalSystem.POLICY_META.get(policy_id, {})
	_sidebar_controller.set_policy_preview(policy_id, meta)
	_sync_tray_state()

## 地图节点选中后，若当前处于行军模式，则委托 map_controller 处理选点
func _on_map_selected_node_changed(node_id: String) -> void:
	if not _awaiting_action:
		return
	_map_controller.on_node_selected_for_march(node_id)

## 玩家点击"执行行动"：分派到对应行动类型
func _on_confirm_pressed() -> void:
	if not _awaiting_action:
		return
	var selected_policy_id := _tray_controller.get_selected_policy_id()
	# 行军模式由 map_controller 的状态机处理
	if selected_policy_id == "march":
		_map_controller.try_confirm_march()
		return
	# 战斗和忠诚度强化需要弹窗选择参数，不直接提交
	if selected_policy_id == "battle":
		_show_battle_popup()
		return
	if selected_policy_id == "boost_loyalty":
		_show_boost_popup()
		return
	_set_tray_interactive(false)
	# "rest" policy_id 和空选均映射到 rest 行动（ADR-004）
	if selected_policy_id != "" and selected_policy_id != "rest":
		TurnManager.submit_action("policy", {"policy_id": selected_policy_id})
	else:
		TurnManager.submit_action("rest", {})
	_clear_tray_selection()

## 从 GameState.policy_cooldowns 刷新所有卡片的冷却状态（Rust 引擎权威数据）
## 跳过 rest/battle/boost_loyalty（它们不属于政策冷却系统）
func _refresh_card_cooldowns() -> void:
	_tray_controller.refresh_card_cooldowns(
		GameState.policy_cooldowns,
		["rest", "march", "battle", "boost_loyalty"]
	)

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
	_prev_supply = GameState.supply
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
	var category_label := MainMenuConfigData.narrative_category_label(action_type)
	_append_narrative("▸ [%s]\n%s" % [category_label, consequence], CentJoursTheme.COLOR["text_primary"])

## 玩家行动的结构化结算日志：显示主描述 + 影响摘要。
func _on_action_resolution_logged(event_type: String, description: String, effects: Array) -> void:
	_append_narrative(
		_sidebar_controller.build_action_resolution_entry(event_type, description, effects),
		_action_resolution_color(event_type)
	)

func _on_game_over(outcome: String) -> void:
	_dialogs_controller.show_game_over(outcome, _dialog_stats_snapshot())

func _show_battle_popup() -> void:
	_dialogs_controller.show_battle_popup(_battle_popup_state())

func _show_boost_popup() -> void:
	_dialogs_controller.show_boost_popup(_boost_popup_state())

func _submit_modal_action(action_name: String, payload: Dictionary) -> void:
	TurnManager.submit_action(action_name, payload)
	_clear_tray_selection()

## map_controller 行军确认回调：向 TurnManager 提交行军行动
func _on_march_confirmed(target_node: String) -> void:
	_set_tray_interactive(false)
	TurnManager.submit_action("march", {"target_node": target_node})
	_clear_tray_selection()

## map_controller 行军反馈回调：更新侧边栏文本
func _on_march_feedback(text: String, color: Color) -> void:
	if text == "":
		# 空文本表示恢复默认行军预览
		_sidebar_controller.set_policy_preview("march")
		return
	_sidebar_controller.set_narrative_text(text, color)

func _on_phase_changed(_phase: String) -> void:
	_refresh_ui()

func _on_legitimacy_changed(_old_value: float, _new_value: float) -> void:
	_refresh_ui()

func _on_loyalty_changed(_character_id: String, _old_value: float, _new_value: float) -> void:
	_refresh_ui()

## 历史事件到达时，直接写入叙事日志，让正文和史注在同一时间出现。
func _on_history_changed(event_id: String, event_data: Dictionary) -> void:
	_append_narrative(
		_sidebar_controller.build_historical_event_entry(event_id, event_data),
		CentJoursTheme.COLOR["gold"]
	)
	_refresh_ui()

func _action_resolution_color(event_type: String) -> Color:
	if event_type.ends_with("_failed"):
		return CentJoursTheme.COLOR["warning"]
	if event_type == "policy":
		return CentJoursTheme.COLOR["gold_dim"]
	if event_type == "battle":
		return CentJoursTheme.COLOR["text_heading"]
	return CentJoursTheme.COLOR["text_primary"]

func _phase_display_name(phase_id: String) -> String:
	return MainMenuFormattersLib.phase_display_name(phase_id)

func _napoleon_location_label() -> String:
	return MainMenuFormattersLib.napoleon_location_label(_map_controller.get_map_nodes(), GameState.napoleon_location)

func _format_number(value: int) -> String:
	return MainMenuFormattersLib.format_number(value)

## 组装游戏结束弹窗所需的状态快照
## 返回值契约见 dialogs_controller.build_game_over_state() 的 stats 参数
func _dialog_stats_snapshot() -> Dictionary:
	return _dialogs_controller.build_game_over_state({
		MainMenuDialogsControllerScript.STATE_KEY_CURRENT_DAY: GameState.current_day,
		MainMenuDialogsControllerScript.STATE_KEY_LEGITIMACY: GameState.legitimacy,
		MainMenuDialogsControllerScript.STATE_KEY_VICTORIES: GameState.victories,
		MainMenuDialogsControllerScript.STATE_KEY_TOTAL_TROOPS: GameState.total_troops,
		MainMenuDialogsControllerScript.STATE_KEY_AVG_MORALE: GameState.avg_morale,
	})

## 组装战斗弹窗所需的状态 Dictionary
## 返回键契约:
##   characters(Array)      — GameState.characters 角色列表
##   total_troops(int)      — 当前总兵力
##   location_label(String) — 拿破仑所在节点的法语名称
##   location_terrain(String) — 地形类型标识（已规范化）
func _battle_popup_state() -> Dictionary:
	var location_node: Dictionary = _map_controller.get_map_node(GameState.napoleon_location)
	return {
		MainMenuDialogsControllerScript.STATE_KEY_CHARACTERS: GameState.characters,
		MainMenuDialogsControllerScript.STATE_KEY_TOTAL_TROOPS: GameState.total_troops,
		MainMenuDialogsControllerScript.STATE_KEY_LOCATION_LABEL: _napoleon_location_label(),
		MainMenuDialogsControllerScript.STATE_KEY_LOCATION_TERRAIN: MainMenuConfigData.normalize_battle_terrain(String(location_node.get("terrain", "plains"))),
	}

## 组装忠诚度强化弹窗所需的状态 Dictionary
## 返回键契约:
##   characters(Array) — GameState.characters 角色列表
##   legitimacy(float) — 当前合法性 0-100
func _boost_popup_state() -> Dictionary:
	return {
		MainMenuDialogsControllerScript.STATE_KEY_CHARACTERS: GameState.characters,
		MainMenuDialogsControllerScript.STATE_KEY_LEGITIMACY: GameState.legitimacy,
	}

## 同步行军预览高亮：根据当前托盘选中状态切换地图高亮
func _sync_march_preview() -> void:
	var is_march := _tray_controller.get_selected_policy_id() == "march"
	if _awaiting_action and is_march:
		_map_controller.set_march_mode(true)
		return
	_map_controller.set_march_mode(false)
