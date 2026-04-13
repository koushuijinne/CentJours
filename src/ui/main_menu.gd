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
const TopbarActionsControllerScript = preload("res://src/ui/main_menu/topbar_actions_controller.gd")

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
@onready var _diplomacy_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/DiplomacyBlock/DiplomacyValue
@onready var _troops_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/TroopsBlock/TroopsValue
@onready var _supply_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/SupplyBlock/SupplyValue
@onready var _morale_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/MoraleBlock/MoraleValue
@onready var _fatigue_value: Label = $RootLayout/TopBar/TopBarMargin/TopBarRow/ResourceBlock/FatigueBlock/FatigueValue
@onready var _main_area: HBoxContainer = $RootLayout/MainArea
@onready var _left_column: VBoxContainer = $RootLayout/MainArea/LeftColumn
@onready var _map_area: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea
@onready var _map_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapTitle
@onready var _map_subtitle: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapSubtitle
@onready var _map_hover_panel: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapHoverPanel
@onready var _map_hover_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapHoverPanel/MapHoverMargin/MapHoverScroll/MapHoverBox/MapHoverTitle
@onready var _map_hover_meta: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapHoverPanel/MapHoverMargin/MapHoverScroll/MapHoverBox/MapHoverMeta
@onready var _map_scroll: ScrollContainer = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapScroll
@onready var _map_canvas: Control = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapScroll/MapCanvas
@onready var _map_inspector_panel: PanelContainer = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel
@onready var _map_inspector_title: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorTitle
@onready var _map_inspector_meta: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorMeta
@onready var _map_inspector_stats: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorStats
@onready var _map_inspector_history: Label = $RootLayout/MainArea/LeftColumn/MapArea/MapMargin/MapContent/MapInspectorPanel/MapInspectorMargin/MapInspectorScroll/MapInspectorBox/MapInspectorHistory
@onready var _sidebar: PanelContainer = $RootLayout/MainArea/Sidebar
@onready var _situation_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel
@onready var _situation_box: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox
@onready var _situation_scroll: ScrollContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox/SituationScroll
@onready var _situation_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/SituationPanel/SituationMargin/SituationBox/SituationScroll/SituationBody
@onready var _loyalty_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel
@onready var _loyalty_scroll: ScrollContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel/LoyaltyMargin/LoyaltyBox/LoyaltyScroll
@onready var _loyalty_list: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/LoyaltyPanel/LoyaltyMargin/LoyaltyBox/LoyaltyScroll/LoyaltyList
@onready var _narrative_panel: PanelContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel
@onready var _narrative_box: VBoxContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox
@onready var _narrative_scroll: ScrollContainer = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox/NarrativeScroll
@onready var _narrative_body: Label = $RootLayout/MainArea/Sidebar/SidebarMargin/SidebarContent/NarrativePanel/NarrativeMargin/NarrativeBox/NarrativeScroll/NarrativeBody
@onready var _decision_tray: PanelContainer = $RootLayout/MainArea/LeftColumn/DecisionTray
@onready var _tray_margin: MarginContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin
@onready var _tray_content: VBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent
@onready var _tray_header: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader
@onready var _tray_hint: Label = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/TrayHeader/TrayHint
@onready var _decision_scroll: ScrollContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll
@onready var _decision_scroll_content: MarginContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll/DecisionScrollContent
@onready var _decision_row: HBoxContainer = $RootLayout/MainArea/LeftColumn/DecisionTray/TrayMargin/TrayContent/DecisionScroll/DecisionScrollContent/DecisionRow

var _confirm_button: Button       # 执行行动确认按钮（动态创建）
var _end_day_button: Button       # 结束今天并推进到次日
var _awaiting_action: bool = false  # 是否处于等待玩家操作的行动阶段
var _last_tutorial_popup_day_shown: int = 0
var _tutorial_stages: Array = []  # 从 tutorial_stages.json 加载的结构化教程数据
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
var _topbar_actions = TopbarActionsControllerScript.new()

const MANEUVER_POLICY_IDS := ["rest", "march", "battle"]
const TRAY_LOCK_NONE := ""
const TRAY_LOCK_MODAL := "modal"
const TRAY_LOCK_RESOLVING := "resolving"
const TRAY_LOCK_PROCESSING := "processing"
const TRAY_LOCK_GAME_OVER := "game_over"

func _decision_policy_ids() -> Array[String]:
	var ids: Array[String] = ["boost_loyalty"]
	ids.append_array(MainMenuConfigData.PRIORITY_POLICY_IDS)
	return ids

var _tray_lock_reason: String = TRAY_LOCK_NONE
var _game_over_active: bool = false

func _ready() -> void:
	# 统一入口主题，保证占位骨架先具备正式视觉语言。
	theme = CentJoursTheme.create()
	_layout_controller.name = "LayoutController"
	_map_controller.name = "MapController"
	_dialogs_controller.name = "DialogsController"
	_tray_controller.name = "TrayController"
	_topbar_actions.name = "TopbarActionsController"
	add_child(_layout_controller)
	add_child(_map_controller)
	add_child(_dialogs_controller)
	add_child(_tray_controller)
	add_child(_topbar_actions)
	_topbar_actions.configure(self, _top_bar_row, {
		"set_tray_interactive": Callable(self, "_set_tray_interactive"),
		"get_tray_lock_reason": Callable(self, "_get_tray_lock_reason"),
		"is_dialog_modal_active": Callable(_dialogs_controller, "is_modal_active"),
		"restart_game": Callable(self, "_restart_game"),
		"refresh_ui": Callable(self, "_refresh_ui"),
		"map_clear_interaction": Callable(_map_controller, "clear_interaction_state"),
		"build_decision_cards": Callable(self, "_build_decision_cards"),
	})
	_topbar_actions.load_and_apply_user_settings(get_window())
	_topbar_actions.new_game_confirmed.connect(_on_new_game_flow)
	_topbar_actions.strategy_goals_requested.connect(_show_strategy_goals_popup)
	_topbar_actions.narrative_log_requested.connect(_show_narrative_log_popup)
	_topbar_actions.glossary_requested.connect(_show_glossary_popup)
	_dialogs_controller.difficulty_selected.connect(_on_difficulty_selected)
	_topbar_actions.settings_applied.connect(func(_s): call_deferred("_apply_responsive_layout"))
	_configure_layout_controller()
	_configure_static_ui()
	_apply_panel_styles()
	_build_rouge_noir_slider()
	_configure_sidebar_controller()
	_build_confirm_button()
	_topbar_actions.build_topbar_buttons()
	_configure_tray_controller()
	_configure_dialogs_controller()
	_build_decision_cards()
	_build_rn_overlay()
	_configure_map_controller()
	_connect_signals()
	resized.connect(_on_main_menu_resized)
	call_deferred("_apply_responsive_layout")
	_load_tutorial_stages()
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
			"map_hover_panel": _map_hover_panel,
			"map_hover_title": _map_hover_title,
			"map_hover_meta": _map_hover_meta,
			"map_inspector_title": _map_inspector_title,
			"map_inspector_meta": _map_inspector_meta,
			"map_inspector_stats": _map_inspector_stats,
			"map_inspector_history": _map_inspector_history,
		"sidebar": _sidebar,
		"map_area": _map_area,
		"map_inspector_panel": _map_inspector_panel,
		"situation_panel": _situation_panel,
		"situation_box": _situation_box,
		"situation_scroll": _situation_scroll,
			"loyalty_panel": _loyalty_panel,
			"loyalty_scroll": _loyalty_scroll,
			"loyalty_list": _loyalty_list,
			"narrative_panel": _narrative_panel,
			"narrative_box": _narrative_box,
			"narrative_scroll": _narrative_scroll,
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
			_map_scroll,
			_map_title,
			_map_subtitle,
			_map_hover_panel,
			_map_hover_title,
			_map_hover_meta,
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
	_map_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_tray_controller.set_tray_hint_texts("今天还能做：1 次机动，2 次决策。", _tray_disabled_hint_text())
	_tray_controller.set_confirm_button_text("先选择动作")
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
		"第 1 天 · 厄尔巴岛出发\n\n选择行动，历史将在此处展开。",
		CentJoursTheme.COLOR["text_secondary"]
	)

## 向叙事日志追加一条新记录，最多保留 NARRATIVE_MAX_ENTRIES 条（ADR-004）
func _append_narrative(entry: String, color: Color) -> void:
	_sidebar_controller.append_narrative(entry, color)

## 在 TrayHeader 右侧动态创建"执行行动"确认按钮
func _build_confirm_button() -> void:
	_confirm_button = _tray_controller.create_confirm_button(_tray_header, "执行当前动作")
	if _confirm_button != null:
		_confirm_button.name = "ExecuteActionButton"
	_end_day_button = Button.new()
	_end_day_button.name = "EndDayButton"
	_end_day_button.text = "结束今天 → 次日"
	_end_day_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_end_day_button.custom_minimum_size = Vector2(132, 28)
	_end_day_button.pressed.connect(_on_end_day_pressed)
	_tray_header.add_child(_end_day_button)





## 新局流程入口：先弹出难度选择
func _on_new_game_flow() -> void:
	_dialogs_controller.show_difficulty_selection()

## 难度选择完成后：设置引擎难度并重启
func _on_difficulty_selected(difficulty_id: String) -> void:
	GameState.difficulty = difficulty_id
	TurnManager.set_difficulty(difficulty_id)
	_restart_game()

func _restart_game() -> void:
	_game_over_active = false
	TurnManager.reset_engine()
	_map_controller.clear_interaction_state()
	_build_decision_cards()
	_start_game()
	_refresh_ui()
	_topbar_actions.refresh_save_load_buttons()

## 引导第一回合：先同步晨间状态，再进入行动阶段等待玩家
func _start_game() -> void:
	_game_over_active = false
	TurnManager.start_new_turn()
	TurnManager.begin_action_phase()
	_set_tray_interactive(true)
	_init_narrative_panel()

## 控制托盘卡片与确认按钮的可交互状态
func _set_tray_interactive(enabled: bool, lock_reason: String = TRAY_LOCK_NONE) -> void:
	_awaiting_action = enabled
	_tray_lock_reason = TRAY_LOCK_NONE if enabled else lock_reason
	_sync_tray_state()


func _get_tray_lock_reason() -> String:
	return _tray_lock_reason


func _connect_signals() -> void:
	# 接 UI 层信号：状态变化 → 刷新显示
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.legitimacy_changed.connect(_on_legitimacy_changed)
	EventBus.loyalty_changed.connect(_on_loyalty_changed)
	EventBus.historical_event_triggered.connect(_on_history_changed)
	EventBus.bertrand_diary_entry.connect(_on_bertrand_entry)
	EventBus.micro_narrative_shown.connect(_on_micro_narrative)
	EventBus.action_resolution_logged.connect(_on_action_resolution_logged)
	# 接回合结束信号：驱动下一回合
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.game_over.connect(_on_game_over)
	_map_scroll.resized.connect(_map_controller.rebuild_map_nodes)
	_map_canvas.resized.connect(_map_controller.rebuild_map_nodes)
	_map_canvas.gui_input.connect(_map_controller.on_map_canvas_gui_input)
	_map_controller.selected_node_changed.connect(_on_map_selected_node_changed)
	# 行军交互信号：map_controller 管理行军选点状态机，main_menu 负责提交和侧边栏刷新
	_map_controller.march_confirmed.connect(_on_march_confirmed)
	_map_controller.march_feedback.connect(_on_march_feedback)

func _refresh_ui() -> void:
	_day_label.text = "第 %d 天" % GameState.current_day
	_phase_label.text = "%s · %s · 决策点 %d" % [
		_phase_display_name(GameState.current_phase),
		"机动可用" if GameState.maneuver_available else "机动已用",
		GameState.actions_remaining
	]
	_legitimacy_value.text = "%.1f" % GameState.legitimacy
	_legitimacy_bar.value = GameState.legitimacy
	_diplomacy_value.text = "%d / 100" % GameState.diplomatic_progress
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
	_maybe_show_daily_tutorial_popup()
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
	var strategy_context := _build_strategy_context()
	_sidebar_controller.refresh_situation(
		GameState.current_phase,
		_napoleon_location_label(),
		GameState.legitimacy,
		GameState.supply,
		GameState.avg_fatigue,
		GameState.diplomatic_progress,
		GameState.logistics_runway_label,
		GameState.logistics_posture_label,
		GameState.logistics_focus_title,
		GameState.logistics_focus_detail,
		GameState.logistics_objective_label,
		GameState.logistics_objective_detail,
		GameState.logistics_action_plan_title,
		GameState.logistics_action_plan_detail,
		GameState.logistics_tempo_plan_title,
		GameState.logistics_tempo_plan_detail,
		GameState.logistics_route_chain_title,
		GameState.logistics_route_chain_detail,
		GameState.logistics_regional_pressure_title,
		GameState.logistics_regional_pressure_detail,
		GameState.logistics_regional_task_title,
		GameState.logistics_regional_task_detail,
		GameState.logistics_regional_task_progress_label,
		GameState.logistics_regional_task_reward_label,
		strategy_context,
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
	var overlay: ColorRect = _layout_controller.build_rn_overlay(self)
	if overlay != null:
		overlay.color = tint["bg_tint"]

func _sync_tray_state() -> void:
	_tray_controller.set_disabled_hint_text(_tray_disabled_hint_text())
	_tray_controller.set_tray_state(_tray_controller.get_selected_policy_id(), _awaiting_action)
	_tray_controller.apply_policy_availability(_disabled_policy_state_for_current_budget())
	_tray_controller.set_confirm_button_text(_tray_confirm_button_text())
	if _end_day_button != null:
		_end_day_button.disabled = not _awaiting_action
	_sync_march_preview()


func _disabled_policy_state_for_current_budget() -> Dictionary:
	var disabled := {}
	if not _awaiting_action:
		var lock_reason := _tray_card_lock_reason_text()
		for policy_id in MANEUVER_POLICY_IDS:
			disabled[policy_id] = lock_reason
		for policy_id in _decision_policy_ids():
			disabled[policy_id] = lock_reason
		return disabled
	if not GameState.maneuver_available:
		for policy_id in MANEUVER_POLICY_IDS:
			disabled[policy_id] = "今日机动已用"
	if GameState.actions_remaining <= 0:
		for policy_id in _decision_policy_ids():
			disabled[policy_id] = "决策点已用尽"
	return disabled

func _refresh_logistics_guidance() -> void:
	var hint_text := _build_tutorial_hint_text()
	var is_tutorial := hint_text.begins_with("前10天教程：")

	var display_hint := ""
	if not is_tutorial:
		display_hint = hint_text.strip_edges()

	if display_hint == "":
		display_hint = "先决定今天的机动，再安排剩余决策点。"
		if GameState.logistics_regional_pressure_short.strip_edges() != "":
			display_hint = GameState.logistics_regional_pressure_short
		elif GameState.logistics_route_chain_short.strip_edges() != "":
			display_hint = GameState.logistics_route_chain_short
		elif GameState.logistics_tempo_plan_short.strip_edges() != "":
			display_hint = GameState.logistics_tempo_plan_short
		elif GameState.logistics_action_plan_short.strip_edges() != "":
			display_hint = GameState.logistics_action_plan_short
		elif GameState.logistics_objective_short.strip_edges() != "":
			display_hint = GameState.logistics_objective_short
		elif GameState.logistics_focus_short.strip_edges() != "":
			display_hint = GameState.logistics_focus_short

	var map_subtitle_text := _build_map_context_subtitle(display_hint, _build_strategy_context())

	# 教程期提示已移至中央弹窗与日志，侧栏 TrayHint 仅保留预算信息，避免视觉拥挤（ADR-008）
	_tray_controller.set_enabled_hint_text(_build_action_budget_hint_text())
	if not is_tutorial and display_hint != "":
		_tray_controller.set_enabled_hint_text("%s\n%s" % [_build_action_budget_hint_text(), display_hint])

	_tray_controller.set_disabled_hint_text(_tray_disabled_hint_text())
	_map_controller.set_context_subtitle(map_subtitle_text)

func _tray_disabled_hint_text() -> String:
	match _tray_lock_reason:
		TRAY_LOCK_MODAL:
			return "设置已打开，先关闭弹窗。"
		TRAY_LOCK_RESOLVING:
			return "正在结束今天…"
		TRAY_LOCK_PROCESSING:
			return "正在处理当前动作…"
		TRAY_LOCK_GAME_OVER:
			return "战局已结束，请查看结局或开始新局。"
		_:
			return "界面已锁定。"


func _tray_card_lock_reason_text() -> String:
	match _tray_lock_reason:
		TRAY_LOCK_MODAL:
			return "先关闭弹窗"
		TRAY_LOCK_RESOLVING:
			return "正在结束今天"
		TRAY_LOCK_PROCESSING:
			return "正在处理"
		TRAY_LOCK_GAME_OVER:
			return "战局已结束"
		_:
			return "界面已锁定"


func _build_action_budget_hint_text() -> String:
	if GameState.maneuver_available and GameState.actions_remaining > 0:
		return "今天还能做：1 次机动，%d 次决策。通常先决定位置，再安排政策。" % GameState.actions_remaining
	if GameState.maneuver_available and GameState.actions_remaining <= 0:
		return "今天还能做：1 次机动，0 次决策。决策点已用尽，先决定是否机动，或直接结束今天。"
	if not GameState.maneuver_available and GameState.actions_remaining > 0:
		return "今天还能做：0 次机动，%d 次决策。机动已完成，接下来专注安排政策。" % GameState.actions_remaining
	return "今天的机动和决策都已排完，直接结束今天。"


func _tray_confirm_button_text() -> String:
	var selected_policy_id := _tray_controller.get_selected_policy_id()
	if selected_policy_id == "":
		return "先选择动作"
	if MANEUVER_POLICY_IDS.has(selected_policy_id):
		return "执行机动"
	return "执行决策"

func _build_map_context_subtitle(hint_text: String, strategy_context: Dictionary) -> String:
	var lines: Array[String] = []
	var route_source := ""
	for candidate_variant in [
		GameState.logistics_route_chain_short,
		GameState.logistics_objective_short,
		GameState.logistics_regional_task_short,
		GameState.logistics_regional_pressure_short
	]:
		var candidate := String(candidate_variant).strip_edges()
		if candidate != "":
			route_source = candidate
			break
	if hint_text.begins_with("前10天教程："):
		lines.append(hint_text)
	elif route_source != "":
		lines.append("路线：%s" % route_source)
	elif hint_text.strip_edges() != "":
		lines.append(hint_text)

	var focus_title := String(strategy_context.get("focus_title", "")).strip_edges()
	var next_step := String(strategy_context.get("focus_next_step", "")).strip_edges()
	if focus_title != "":
		var strategy_line := "战略：当前最接近%s" % focus_title
		if next_step != "":
			strategy_line += "。%s" % next_step
		lines.append(strategy_line)

	if hint_text.begins_with("前10天教程："):
		lines.append("操作：点击城市锁定详情，滚轮缩放地图，右键复位。")
	return "\n".join(lines)

func _load_tutorial_stages() -> void:
	var file := FileAccess.open("res://src/data/tutorials/tutorial_stages.json", FileAccess.READ)
	if not file:
		push_warning("tutorial_stages.json not found, tutorial popups disabled")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("tutorial_stages.json parse error: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	_tutorial_stages = data.get("stages", [])


func _get_tutorial_stage_for_day(day: int) -> Dictionary:
	for stage in _tutorial_stages:
		var day_range: Array = stage.get("day_range", [0, 0])
		if day >= int(day_range[0]) and day <= int(day_range[1]):
			return stage
	return {}


func _build_tutorial_hint_text() -> String:
	if GameState.current_day > 10:
		return ""
	# 紧急补给提示优先于阶段教程（玩家需要立即行动）
	if GameState.logistics_runway_days == 0:
		return "前10天教程：你已经跌进战斗惩罚区。下一步优先休整或补给，不要继续硬顶。"
	if GameState.logistics_runway_days == 1 or GameState.supply < 55.0:
		return "前10天教程：补给开始见底时，先打补给牌或休整，不要连续站在低容量节点。"
	# 阶段教程简短提示（用于地图副标题）
	var stage := _get_tutorial_stage_for_day(GameState.current_day)
	if stage.is_empty():
		return ""
	var topic: String = stage.get("topic", "")
	match topic:
		"supply":
			if GameState.supply < 55.0:
				return "前10天教程：补给偏低，试试使用补给类政策牌。"
			return "前10天教程：留意顶栏补给数值，它是你的生命线。"
		"politics":
			if GameState.legitimacy < 40.0:
				return "前10天教程：合法性偏低，考虑做政治决策巩固支持。"
			return "前10天教程：四个派系的支持决定你的合法性。"
		"command_deviation":
			return "前10天教程：保持补给和士气，减少命令偏差。"
		"diplomacy":
			return "前10天教程：外交进度由合法性和控制区域推动。"
		_:
			# overview, movement, strategy, summary 等
			if GameState.logistics_regional_pressure_short.strip_edges() != "":
				return "前10天教程：%s" % GameState.logistics_regional_pressure_short
			return "前10天教程：查看侧栏了解当前建议。"


func _build_strategy_context() -> Dictionary:
	var focus := _build_primary_route_snapshot()
	var risk := _build_primary_risk_snapshot()
	var faction_pressure := _build_faction_pressure_snapshot()
	return {
		"focus_title": String(focus.get("title", "")).strip_edges(),
		"focus_reason": String(focus.get("reason", "")).strip_edges(),
		"focus_next_step": String(focus.get("next_step", "")).strip_edges(),
		"risk_title": String(risk.get("title", "")).strip_edges(),
		"risk_detail": String(risk.get("detail", "")).strip_edges(),
		"faction_title": String(faction_pressure.get("title", "")).strip_edges(),
		"faction_detail": String(faction_pressure.get("detail", "")).strip_edges()
	}


func _build_primary_route_snapshot() -> Dictionary:
	var outcome_id := "napoleon_victory"
	var reason := "当前局面还在塑形期，最值钱的路线仍然是同时把政治、补给和胜场养成能改写历史的组合。"
	if GameState.legitimacy < 15.0:
		outcome_id = "political_collapse"
		reason = "合法性已经压到即时失败区，巴黎可能会先于前线停止承担这场战争。"
	elif GameState.total_troops < 12000 or (GameState.supply < 30.0 and GameState.victories <= 1):
		outcome_id = "military_annihilation"
		reason = "兵力和续航都在危险区，继续用高损耗换位置会更接近军事覆灭。"
	elif GameState.current_day >= 60 and GameState.legitimacy >= 65.0 and GameState.diplomatic_progress >= 70:
		outcome_id = "diplomatic_settlement"
		reason = "你已经跨进外交兑现窗口，当前最接近的是把高合法性和外交进度守到停火落地。"
	elif GameState.victories >= 3 and GameState.legitimacy >= 50.0:
		outcome_id = "napoleon_victory"
		reason = "战场和政治都还站得住，现在最接近的是把中盘优势滚成改写历史的胜局。"
	elif GameState.victories >= 3:
		outcome_id = "military_dominance"
		reason = "你的战果已经跑在政治线前面，当前更像一条靠军功硬压出来的军事霸权路线。"
	elif GameState.current_day >= 45 and GameState.diplomatic_progress >= 45 and GameState.legitimacy >= 55.0:
		outcome_id = "diplomatic_settlement"
		reason = "中盘政治基础还稳，外交进度也已经成形，继续经营外交比硬赌决战更近。"
	elif GameState.victories >= 2 and GameState.legitimacy >= 45.0:
		outcome_id = "napoleon_victory"
		reason = "你已经有了翻盘骨架，只差把优势滚成足够多的有效胜利。"
	elif GameState.current_day >= 80:
		outcome_id = "waterloo_historical"
		reason = "终盘已经逼近，若再不把胜场或外交进度推上去，局面会更像守到滑铁卢。"
	elif GameState.victories <= 0 and GameState.legitimacy < 40.0:
		outcome_id = "waterloo_defeat"
		reason = "战场和政治都没有起色，继续硬顶更像是在滑向彻底败亡。"

	var info: Dictionary = MainMenuConfigData.OUTCOME_TEXT.get(outcome_id, {})
	return {
		"id": outcome_id,
		"title": String(info.get("title", outcome_id)),
		"reason": reason,
		"next_step": String(info.get("next_step", "")).strip_edges()
	}


func _build_primary_risk_snapshot() -> Dictionary:
	if GameState.legitimacy < 15.0:
		return {
			"title": "政治崩溃",
			"detail": "合法性 %.1f，任何继续消耗派系或合法性的动作都可能让巴黎先倒向退位。" % GameState.legitimacy
		}
	if GameState.total_troops < 12000:
		return {
			"title": "军事覆灭",
			"detail": "兵力只剩 %s，再用高损耗战斗硬换位置，军队会先于政权崩掉。" % _format_number(GameState.total_troops)
		}
	if GameState.supply < 45.0:
		return {
			"title": "补给透支",
			"detail": "当前补给 %.0f，前线已经接近或跌入惩罚区。先保线再推进，否则任何路线都会一起变窄。" % GameState.supply
		}
	if GameState.current_day >= 75 and GameState.victories < 2:
		return {
			"title": "终盘战果不足",
			"detail": "已到第 %d 天，胜场只有 %d。若这一段还没有决定性战果，终盘会更像守到历史败局。" % [GameState.current_day, GameState.victories]
		}
	var faction_pressure := _build_faction_pressure_snapshot()
	return {
		"title": String(faction_pressure.get("title", "派系失衡")),
		"detail": String(faction_pressure.get("detail", "当前最大的风险来自内部支持失衡。"))
	}


func _build_faction_pressure_snapshot() -> Dictionary:
	var weakest_id := ""
	var weakest_support := 101.0
	var strongest_id := ""
	var strongest_support := -1.0
	for faction_id in GameState.faction_support.keys():
		var support := float(GameState.faction_support.get(faction_id, 0.0))
		if support < weakest_support:
			weakest_support = support
			weakest_id = String(faction_id)
		if support > strongest_support:
			strongest_support = support
			strongest_id = String(faction_id)

	var weakest_label: String = String(MainMenuConfigData.FACTION_LABELS.get(weakest_id, weakest_id))
	var strongest_label: String = String(MainMenuConfigData.FACTION_LABELS.get(strongest_id, strongest_id))
	var pressure_reason := ""
	match weakest_id:
		"military":
			pressure_reason = "军方正在变脆，继续战败或压缩军费会直接反噬前线调度。"
		"populace":
			pressure_reason = "民众正在变脆，征用、印钞和长期战损都会让巴黎压力继续累积。"
		"liberals":
			pressure_reason = "自由派正在变脆，若还想保住议会和行政面的支持，就别长期只靠强压。"
		"nobility":
			pressure_reason = "贵族和保守秩序正在变脆，继续冲红线会让政治基础变得更窄。"
		_:
			pressure_reason = "当前内部支持并不均衡，别把最脆的一派继续往危险线推。"

	return {
		"title": "派系压力 · %s最脆" % weakest_label,
		"detail": "当前最脆的是%s %.0f，最稳的是%s %.0f。%s" % [
			weakest_label,
			weakest_support,
			strongest_label,
			strongest_support,
			pressure_reason
		]
	}


func _clear_tray_selection() -> void:
	_map_controller.clear_march_state()
	_tray_controller.clear_selection()
	_sync_tray_state()

func _on_confirm_requested(_policy_id: String) -> void:
	_on_confirm_pressed()

func _on_policy_selected(policy_id: String) -> void:
	# 仅在行动阶段允许切换选中政策
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
	if selected_policy_id == "":
		_show_tutorial_popup("先选动作再执行", "请先在下方选择一个机动动作或政策；如果今天已经安排完毕，直接点击“结束今天 → 次日”。")
		return
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
	# "rest" 仍视为当前日的一次机动动作，但不会立即推进到次日。
	var submitted := false
	if selected_policy_id != "rest":
		submitted = TurnManager.submit_action("policy", {"policy_id": selected_policy_id})
	else:
		submitted = TurnManager.submit_action("rest", {})
	if not submitted:
		return
	_clear_tray_selection()

func _on_end_day_pressed() -> void:
	if not _awaiting_action:
		return
	_set_tray_interactive(false, TRAY_LOCK_RESOLVING)
	if not TurnManager.end_day():
		_set_tray_interactive(true)

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
	call_deferred("_begin_next_turn")
	_refresh_ui()

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


func _maybe_show_daily_tutorial_popup() -> void:
	if GameState.current_day > 10:
		return
	if GameState.current_phase != "action":
		return
	if _last_tutorial_popup_day_shown == GameState.current_day:
		return
	_last_tutorial_popup_day_shown = GameState.current_day

	var stage := _get_tutorial_stage_for_day(GameState.current_day)
	if stage.is_empty():
		# 回退到旧逻辑：如果 JSON 没加载成功，至少显示条件提示
		var fallback := _build_tutorial_hint_text().strip_edges()
		if fallback == "":
			return
		_show_tutorial_popup("前 10 天教程", fallback)
		if GameState.current_phase == "action":
			TurnManager.submit_action("log_narrative", {"title": "教程指导", "body": fallback})
		return

	var title: String = stage.get("title", "教程")
	var body: String = stage.get("body", "")
	var op_guide: String = stage.get("operation_guide", "")

	# 附加条件提示（如果当前状态满足条件）
	var condition_hint: Dictionary = stage.get("condition_hint", {})
	if not condition_hint.is_empty():
		var field: String = condition_hint.get("field", "")
		var op: String = condition_hint.get("operator", "")
		var threshold = condition_hint.get("value", 0)
		var current_value: float = 0.0
		match field:
			"supply": current_value = GameState.supply
			"legitimacy": current_value = GameState.legitimacy
			"avg_fatigue": current_value = GameState.avg_fatigue
			"avg_morale": current_value = GameState.avg_morale
		var triggered := false
		match op:
			"<": triggered = current_value < float(threshold)
			">": triggered = current_value > float(threshold)
			"<=": triggered = current_value <= float(threshold)
			">=": triggered = current_value >= float(threshold)
		if triggered:
			body += "\n\n%s" % String(condition_hint.get("hint", ""))

	if op_guide != "":
		body += "\n\n[操作指南]\n%s" % op_guide

	var popup_title := "教程 Day %d · %s" % [GameState.current_day, title]
	_show_tutorial_popup(popup_title, body)
	if GameState.current_phase == "action":
		TurnManager.submit_action("log_narrative", {"title": popup_title, "body": body})

func _show_tutorial_popup(title: String, body: String) -> void:
	_dialogs_controller.show_info_popup("TutorialPopup", title, body)

func _show_strategy_goals_popup() -> void:
	var strategy_text := _build_strategy_goals_overview()
	_dialogs_controller.show_info_popup("StrategyGoalsPopup", "当前战略目标", strategy_text)

func _show_glossary_popup() -> void:
	var glossary_text := _build_glossary_overview()
	_dialogs_controller.show_info_popup("GlossaryPopup", "游戏百科", glossary_text)

func _show_narrative_log_popup() -> void:
	var log_text := _build_narrative_log_overview()
	_dialogs_controller.show_info_popup("NarrativeLogPopup", "历史日志", log_text)

func _build_strategy_goals_overview() -> String:
	var lines: Array[String] = []
	lines.append("当前局势概览")
	lines.append("第 %d 天 · 合法性 %.1f · 胜场 %d · 外交进度 %d/100 · 补给 %.0f" % [
		GameState.current_day,
		GameState.legitimacy,
		GameState.victories,
		GameState.diplomatic_progress,
		GameState.supply
	])
	lines.append("")
	lines.append("当前最接近的路线")
	for summary in _build_strategy_priority_lines():
		lines.append("• %s" % summary)
	lines.append("")
	lines.append("结局路线")
	for outcome_id in [
		"napoleon_victory",
		"diplomatic_settlement",
		"military_dominance",
		"waterloo_historical",
		"waterloo_defeat",
		"political_collapse",
		"military_annihilation"
	]:
		var info: Dictionary = MainMenuConfigData.OUTCOME_TEXT.get(outcome_id, {})
		if info.is_empty():
			continue
		lines.append("【%s】" % String(info.get("title", outcome_id)))
		lines.append(String(info.get("desc", "暂无说明。")))
		var status_lines := _build_strategy_status_lines(outcome_id)
		if not status_lines.is_empty():
			lines.append("当前状态")
			for status_line in status_lines:
				lines.append("- %s" % status_line)
		var goal_line := String(info.get("goal_line", "")).strip_edges()
		if goal_line != "":
			lines.append("达成要点")
			lines.append(goal_line)
		var watch_for := String(info.get("watch_for", "")).strip_edges()
		if watch_for != "":
			lines.append("要避开")
			lines.append(watch_for)
		var next_step := String(info.get("next_step", "")).strip_edges()
		if next_step != "":
			lines.append("下一步")
			lines.append(next_step)
		lines.append("")
	lines.append("当前建议")
	lines.append("优先同时考虑机动节奏、合法性、补给、外交进度和胜场，不要只盯一项数值。")
	return "\n".join(lines)


func _build_glossary_overview() -> String:
	var rn_tooltip := PoliticalSystem.get_rouge_noir_tooltip()
	var lines: Array[String] = []
	lines.append("红 / 黑指数")
	lines.append("红越高，说明你更依赖动员、强硬和短期压力；黑越高，说明你更依赖秩序、妥协和保守支持。这个指数不会单独决定胜负，但会放大不同派系对政策的反应。")
	lines.append("当前倾向：%s。" % String(rn_tooltip.get("label", "政治中立")))
	var rn_effects: Array = rn_tooltip.get("effects", [])
	if not rn_effects.is_empty():
		var rn_effect_labels: Array[String] = []
		for effect_variant in rn_effects:
			rn_effect_labels.append(String(effect_variant))
		lines.append("当前主要影响：%s。" % "；".join(rn_effect_labels))
	else:
		lines.append("当前主要影响：你还在中间区，两侧加成和副作用都不明显。")
	lines.append("怎么理解：红不是绝对正确，黑也不是绝对安全。红线更容易换来短期兵力和动员，黑线更容易稳住秩序与保守支持，但两边走得太极端都会让另一头的派系代价越来越高。")
	lines.append("")
	lines.append("合法性")
	lines.append("合法性是四个派系支持度的加权结果，代表这个政权还能不能继续让法国承受战争。它会影响每日决策点、部分行动门槛、结局判断，以及你还能不能用政治方式稳住局面。")
	lines.append("合法性高于 70 时，每天会多 1 个决策点；低于 10 时，连“亲自接见将领”都会失效。")
	lines.append("")
	lines.append("如何提高合法性")
	lines.append("最直接的方法是打胜仗、稳住军方和民众支持，并避免把某一派系长期压到危险线。")
	lines.append("偏保守政策更容易稳住贵族和行政面，偏动员政策更容易拉升民众和军方，但两边走得太极端都会带来新的副作用。")
	lines.append("接见将领会立刻消耗 5 点合法性；战败、补给崩盘和连续把派系推向敌对区，都会让合法性更难回升。")
	lines.append("")
	lines.append("外交进度")
	lines.append("外交进度代表你是否把联军逼到了谈判桌前。它不会自己增长，必须靠外交相关的政策、事件和中盘政治信誉慢慢积累。")
	lines.append("当前外交进度：%d / 100。外交线不是临门一脚，它要求你在第 60 天之后仍然保持足够高的合法性，同时把外交进度推满。" % GameState.diplomatic_progress)
	lines.append("")
	lines.append("补给")
	lines.append("补给不是单纯库存，而是你维持帝国战争机器的“生命线”。它取决于你当前节点容量、补给线稳定性，以及区域走廊的链路质量。")
	lines.append("影响：补给充足时（>60），行军损耗更低，战斗有加成；补给匮乏时（<45），不仅战斗力受损，还会引发合法性持续流失，甚至导致军队逃兵。")
	lines.append("补救方法：在容量高的城市节点“休整”，或使用补给相关政策牌。不要在低容量的前沿节点长期逗留。")
	lines.append("")
	lines.append("一天的节奏")
	lines.append("当前日内模型是：1 次机动槽（行军 / 战役 / 休整）+ 2 次决策点。机动区和决策区分开看，通常先决定位置，再决定当天政策。")
	lines.append("")
	lines.append("命令偏差")
	lines.append("行军和战役的实际结果可能偏离你的预期。偏差来源有三个：")
	lines.append("• 疲劳：疲劳越高，部队越可能走不到目标或战斗力打折。")
	lines.append("• 补给：补给不足时，行军消耗加倍，战斗惩罚叠加。")
	lines.append("• 将领忠诚：忠诚度低于 30 的将领可能抗命甚至叛逃。")
	lines.append("管理偏差的核心是：不要同时让疲劳、补给和忠诚度都处于危险区。")
	lines.append("")
	lines.append("结局怎么读")
	lines.append("结局是政治、军事与外交共同博弈的结果：")
	lines.append("• 军事覆灭：补给或兵力降至极值，军队将先于政权瓦解。补给长期低于 30 会加速这一结局。")
	lines.append("• 政治崩溃：合法性跌破临界点（10），巴黎将由于内部动荡强制你退位。连续忽视派系支持是最常见的原因。")
	lines.append("• 外交调停：第 60 天后，高合法性（≥65）搭配满额的外交进度（≥70），可达成体面的停火。")
	lines.append("• 拿破仑胜利：胜场足够多（≥3）且合法性稳定（≥50），历史将由你改写。")
	lines.append("• 军事霸权：战果跑在政治线前面（≥3 胜但合法性不足），靠军功硬压出来的局面。")
	lines.append("若合法性或兵力先崩，游戏会提前结束，不会等到百日终盘。")
	lines.append("")
	lines.append("当前局面提示")
	lines.append("第 %d 天 · 合法性 %.1f · 补给 %.0f · 外交进度 %d/100 · 机动%s · 决策点 %d" % [
		GameState.current_day,
		GameState.legitimacy,
		GameState.supply,
		GameState.diplomatic_progress,
		"可用" if GameState.maneuver_available else "已用",
		GameState.actions_remaining
	])
	return "\n".join(lines)


func _build_strategy_priority_lines() -> Array[String]:
	var strategy_context := _build_strategy_context()
	var lines: Array[String] = []
	if String(strategy_context.get("focus_title", "")).strip_edges() != "":
		lines.append("当前最接近%s：%s" % [
			strategy_context.get("focus_title", ""),
			strategy_context.get("focus_reason", "")
		])
	if String(strategy_context.get("risk_title", "")).strip_edges() != "":
		lines.append("当前主要风险是%s：%s" % [
			strategy_context.get("risk_title", ""),
			strategy_context.get("risk_detail", "")
		])
	if String(strategy_context.get("faction_title", "")).strip_edges() != "":
		lines.append("%s：%s" % [
			strategy_context.get("faction_title", ""),
			strategy_context.get("faction_detail", "")
		])
	if GameState.current_day <= 10:
		lines.append("前 10 天不要急着追单一路线，先把补给线和跳板节点稳住，避免教程期就把终盘余量交掉。")
	if lines.is_empty():
		lines.append("当前局面还在塑形期。先决定今天的位置和补给节奏，再决定要押政治、外交还是战场。")
	return lines


func _build_strategy_status_lines(outcome_id: String) -> Array[String]:
	var lines: Array[String] = []
	match outcome_id:
		"napoleon_victory":
			lines.append("政治线：当前合法性 %.1f。它需要你把巴黎的支持撑到终盘。" % GameState.legitimacy)
			lines.append("战场线：当前胜场 %d。你需要的不只是活到终盘，而是把关键战役转成有效胜利。" % GameState.victories)
		"diplomatic_settlement":
			lines.append("时间线：外交结局只会在第 60 天之后真正兑现，现在是第 %d 天。" % GameState.current_day)
			lines.append("外交线：当前进度 %d/100。若中盘不持续经营，这条线不会自己长出来。" % GameState.diplomatic_progress)
			lines.append("政治线：当前合法性 %.1f。外交解法要求你一直像个还能谈判的政权。" % GameState.legitimacy)
		"military_dominance":
			lines.append("战场线：当前胜场 %d。它接受政治基础一般，但要求你把战果滚成碾压态势。" % GameState.victories)
			lines.append("风险线：当前合法性 %.1f。若政治线再掉得太狠，军队再强也可能先被内部否决。" % GameState.legitimacy)
		"waterloo_historical":
			lines.append("这是拖到终盘但没改写历史的路线。当前胜场 %d、合法性 %.1f，都还不够让局面彻底翻盘。" % [GameState.victories, GameState.legitimacy])
		"waterloo_defeat":
			lines.append("这条线代表政治和军事都没守住。当前胜场 %d、合法性 %.1f，若继续一起下滑就会落到这里。" % [GameState.victories, GameState.legitimacy])
		"political_collapse":
			lines.append("即时失败风险：当前合法性 %.1f。它越低，巴黎越可能先于前线否决整场战争。" % GameState.legitimacy)
		"military_annihilation":
			lines.append("即时失败风险：当前兵力 %d、补给 %.0f。若连续高损耗并硬顶低补给，军队会先崩。" % [GameState.total_troops, GameState.supply])
	return lines


func _build_narrative_log_overview() -> String:
	var log_body := _narrative_body.text.strip_edges()
	var strategy_context := _build_strategy_context()
	var lines: Array[String] = []
	lines.append("日志说明")
	lines.append("这里会保留教程、历史事件、行动结算和日记摘录。你可以把它当成回看窗口：先看当前局势，再往下翻最近发生了什么。")
	lines.append("")
	lines.append("当前局势快照")
	lines.append("第 %d 天 · 合法性 %.1f · 胜场 %d · 外交进度 %d/100 · 补给 %.0f" % [
		GameState.current_day,
		GameState.legitimacy,
		GameState.victories,
		GameState.diplomatic_progress,
		GameState.supply
	])
	if String(strategy_context.get("focus_title", "")).strip_edges() != "":
		lines.append("当前最接近%s：%s" % [
			strategy_context.get("focus_title", ""),
			strategy_context.get("focus_reason", "")
		])
	if String(strategy_context.get("risk_title", "")).strip_edges() != "":
		lines.append("当前主要风险：%s" % strategy_context.get("risk_detail", ""))
	lines.append("")
	lines.append("最近记录")
	if log_body == "":
		lines.append("当前还没有可回看的日志。")
	else:
		lines.append(log_body)
	return "\n".join(lines)

func _on_bertrand_entry(day: int, text: String) -> void:
	_append_narrative("第 %d 天 — 贝特朗日记\n%s" % [day, text], CentJoursTheme.COLOR["gold_dim"])

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
	_game_over_active = true
	_set_tray_interactive(false, TRAY_LOCK_GAME_OVER)
	_dialogs_controller.show_game_over(outcome, _dialog_stats_snapshot())

func _show_battle_popup() -> void:
	_dialogs_controller.show_battle_popup(_battle_popup_state())

func _show_boost_popup() -> void:
	_dialogs_controller.show_boost_popup(_boost_popup_state())

func _submit_modal_action(action_name: String, payload: Dictionary) -> bool:
	if not TurnManager.submit_action(action_name, payload):
		_set_tray_interactive(true)
		return false
	_clear_tray_selection()
	return true

## map_controller 行军确认回调：向 TurnManager 提交行军行动
func _on_march_confirmed(target_node: String) -> void:
	if not TurnManager.submit_action("march", {"target_node": target_node}):
		return
	_clear_tray_selection()

## map_controller 行军反馈回调：更新侧边栏文本
func _on_march_feedback(text: String, color: Color) -> void:
	if text == "":
		# 空文本表示恢复默认行军预览
		_sidebar_controller.set_policy_preview("march")
		return
	_sidebar_controller.set_narrative_text(text, color)

func _on_phase_changed(_phase: String) -> void:
	if _phase == "action":
		_set_tray_interactive(true)
	elif _game_over_active:
		_set_tray_interactive(false, TRAY_LOCK_GAME_OVER)
	else:
		_set_tray_interactive(false, TRAY_LOCK_PROCESSING)
	_refresh_ui()

func _on_legitimacy_changed(_old_value: float, _new_value: float) -> void:
	_refresh_ui()

func _on_loyalty_changed(_character_id: String, _old_value: float, _new_value: float) -> void:
	_refresh_ui()

## 历史事件到达时，直接写入叙事日志，让正文和史注在同一时间出现。
func _on_history_changed(event_id: String, event_data: Dictionary) -> void:
	var entry := _sidebar_controller.build_historical_event_entry(event_id, event_data)
	_append_narrative(entry, CentJoursTheme.COLOR["gold"])
	_dialogs_controller.show_info_popup("HistoricalEventPopup", String(event_data.get("label", "历史事件")), entry)
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
	var base := _dialogs_controller.build_game_over_state({
		MainMenuDialogsControllerScript.STATE_KEY_CURRENT_DAY: GameState.current_day,
		MainMenuDialogsControllerScript.STATE_KEY_LEGITIMACY: GameState.legitimacy,
		MainMenuDialogsControllerScript.STATE_KEY_VICTORIES: GameState.victories,
		MainMenuDialogsControllerScript.STATE_KEY_DIPLOMATIC_PROGRESS: GameState.diplomatic_progress,
		MainMenuDialogsControllerScript.STATE_KEY_TOTAL_TROOPS: GameState.total_troops,
		MainMenuDialogsControllerScript.STATE_KEY_AVG_MORALE: GameState.avg_morale,
		MainMenuDialogsControllerScript.STATE_KEY_SUPPLY: GameState.supply,
		MainMenuDialogsControllerScript.STATE_KEY_LOCATION_LABEL: _napoleon_location_label(),
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_POSTURE_LABEL: GameState.logistics_posture_label,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_OBJECTIVE_LABEL: GameState.logistics_objective_label,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL: GameState.logistics_primary_action_label,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON: GameState.logistics_primary_action_reason,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL: GameState.logistics_tempo_plan_detail,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL: GameState.logistics_route_chain_detail,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL: GameState.logistics_regional_pressure_detail,
		MainMenuDialogsControllerScript.STATE_KEY_LOGISTICS_RUNWAY_LABEL: GameState.logistics_runway_label,
	})
	base["key_decisions"] = GameState.key_decisions.duplicate()
	base["difficulty"] = GameState.difficulty
	return base

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
