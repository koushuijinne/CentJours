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
var _new_game_btn: Button         # 顶栏新局按钮（动态创建）
var _save_btn: Button             # 顶栏存档按钮（动态创建）
var _load_btn: Button             # 顶栏读档按钮（动态创建）
var _awaiting_action: bool = false  # 是否处于等待玩家操作的 Action Phase
var _transient_modal_depth: int = 0
var _tray_interactive_before_modal: bool = false
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
	_layout_controller.name = "LayoutController"
	_map_controller.name = "MapController"
	_dialogs_controller.name = "DialogsController"
	_tray_controller.name = "TrayController"
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
	_tray_controller.set_tray_hint_texts("选择一项政策或直接休整", "正在结算并进入次日…")
	_tray_controller.set_confirm_button_text("执行今日行动 → 次日")
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
	_confirm_button = _tray_controller.create_confirm_button(_tray_header, "执行今日行动 → 次日")
	if _confirm_button != null:
		_confirm_button.name = "ExecuteActionButton"

## 在 TopBarRow 右侧动态创建存档/读档按钮
func _build_save_load_buttons() -> void:
	var new_game_btn := Button.new()
	new_game_btn.name = "NewGameButton"
	new_game_btn.text = "新局"
	new_game_btn.custom_minimum_size = Vector2(60, 0)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	_top_bar_row.add_child(new_game_btn)

	var save_btn := Button.new()
	save_btn.name = "SaveGameButton"
	save_btn.text = "存档"
	save_btn.custom_minimum_size = Vector2(60, 0)
	save_btn.pressed.connect(_on_save_pressed)
	_top_bar_row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.name = "LoadGameButton"
	load_btn.text = "读档"
	load_btn.custom_minimum_size = Vector2(60, 0)
	load_btn.pressed.connect(_on_load_pressed)
	_top_bar_row.add_child(load_btn)
	# 缓存按钮引用，读档后刷新可用状态
	_new_game_btn = new_game_btn
	_save_btn = save_btn
	_load_btn = load_btn
	_refresh_save_load_buttons()

## 存档按钮回调
func _on_save_pressed() -> void:
	_show_slot_picker("save")

## 读档按钮回调
func _on_load_pressed() -> void:
	_show_slot_picker("load")

func _on_new_game_pressed() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.name = "NewGameConfirmDialog"
	confirm.dialog_text = "重新开始将丢失当前未保存进度，确定吗？"
	confirm.ok_button_text = "确认新开一局"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(_restart_game)
	add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()

func _show_slot_picker(mode: String) -> void:
	var popup := PopupPanel.new()
	popup.name = "SaveSlotPickerPopup" if mode == "save" else "LoadSlotPickerPopup"
	var content := VBoxContainer.new()
	content.name = "SlotPickerContent"
	content.custom_minimum_size = Vector2(320, 0)
	content.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.name = "SlotPickerTitle"
	title.text = "选择存档槽位" if mode == "save" else "选择要读取的存档"
	title.add_theme_font_size_override("font_size", 16)
	content.add_child(title)

	for slot in SaveManager.list_save_slots():
		var slot_id := int(slot.get("slot_id", 0))
		var exists := bool(slot.get("exists", false))
		var button := Button.new()
		button.name = "%sSlotButton%d" % ["Save" if mode == "save" else "Load", slot_id]
		button.text = String(slot.get("label", "槽位 %d" % slot_id))
		button.disabled = mode == "load" and not exists
		if mode == "save":
			button.pressed.connect(_save_to_slot.bind(slot_id, popup))
		else:
			button.pressed.connect(_load_from_slot.bind(slot_id, popup))
		content.add_child(button)

	var cancel_btn := Button.new()
	cancel_btn.name = "SlotPickerCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): _close_transient_popup(popup))
	content.add_child(cancel_btn)

	popup.add_child(content)
	add_child(popup)
	_open_transient_modal(popup)
	popup.popup_centered()

func _save_to_slot(slot_id: int, popup: PopupPanel) -> void:
	_close_transient_popup(popup)
	if TurnManager.save_to_file(slot_id):
		_refresh_save_load_buttons()
		_save_btn.text = "已存档 ✓"
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_save_btn):
				_save_btn.text = "存档"
		)
	else:
		_save_btn.text = "存档失败"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(_save_btn):
				_save_btn.text = "存档"
		)

func _load_from_slot(slot_id: int, popup: PopupPanel) -> void:
	_close_transient_popup(popup)
	var confirm := ConfirmationDialog.new()
	confirm.name = "LoadConfirmDialog"
	confirm.dialog_text = "读档将覆盖当前进度，确定读取槽位 %d 吗？" % slot_id
	confirm.ok_button_text = "确认读档"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		if TurnManager.load_from_save(slot_id):
			_map_controller.clear_interaction_state()
			_build_decision_cards()
			_refresh_ui()
			_set_tray_interactive(true)
			_refresh_save_load_buttons()
	)
	add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()

func _restart_game() -> void:
	TurnManager.reset_engine()
	_map_controller.clear_interaction_state()
	_build_decision_cards()
	_start_game()
	_refresh_ui()
	_refresh_save_load_buttons()

func _refresh_save_load_buttons() -> void:
	if _load_btn != null:
		_load_btn.disabled = not SaveManager.has_any_save()

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


func _open_transient_modal(popup: Window) -> void:
	if popup == null:
		return
	if _transient_modal_depth == 0:
		_tray_interactive_before_modal = _awaiting_action and not _dialogs_controller.is_modal_active()
	_transient_modal_depth += 1
	_set_tray_interactive(false)
	var visibility_changed_cb := Callable(self, "_on_transient_modal_visibility_changed").bind(popup)
	if not popup.visibility_changed.is_connected(visibility_changed_cb):
		popup.visibility_changed.connect(visibility_changed_cb)


func _close_transient_popup(popup: Window) -> void:
	if popup == null:
		return
	popup.hide()
	popup.queue_free()


func _on_transient_modal_visibility_changed(popup: Window) -> void:
	if popup != null and popup.visible:
		return
	var visibility_changed_cb := Callable(self, "_on_transient_modal_visibility_changed").bind(popup)
	if popup != null and popup.visibility_changed.is_connected(visibility_changed_cb):
		popup.visibility_changed.disconnect(visibility_changed_cb)
	_on_transient_modal_closed()


func _on_transient_modal_closed() -> void:
	_transient_modal_depth = max(_transient_modal_depth - 1, 0)
	if _transient_modal_depth > 0:
		return
	if _dialogs_controller.is_modal_active():
		return
	_set_tray_interactive(_tray_interactive_before_modal)

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
	_map_scroll.resized.connect(_map_controller.rebuild_map_nodes)
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
	_tray_controller.set_tray_state(_tray_controller.get_selected_policy_id(), _awaiting_action)
	_sync_march_preview()

func _refresh_logistics_guidance() -> void:
	var hint_text := _build_tutorial_hint_text()
	if hint_text.strip_edges() == "":
		hint_text = "选择一项政策或直接休整"
		if GameState.logistics_regional_pressure_short.strip_edges() != "":
			hint_text = GameState.logistics_regional_pressure_short
		elif GameState.logistics_route_chain_short.strip_edges() != "":
			hint_text = GameState.logistics_route_chain_short
		elif GameState.logistics_tempo_plan_short.strip_edges() != "":
			hint_text = GameState.logistics_tempo_plan_short
		elif GameState.logistics_action_plan_short.strip_edges() != "":
			hint_text = GameState.logistics_action_plan_short
		elif GameState.logistics_objective_short.strip_edges() != "":
			hint_text = GameState.logistics_objective_short
		elif GameState.logistics_focus_short.strip_edges() != "":
			hint_text = GameState.logistics_focus_short
	var map_subtitle_text := _build_map_context_subtitle(hint_text)
	_tray_controller.set_tray_hint_texts(hint_text, "正在结算并进入次日…")
	_map_controller.set_context_subtitle(map_subtitle_text)

func _build_map_context_subtitle(hint_text: String) -> String:
	var candidates := [
		GameState.logistics_route_chain_short,
		GameState.logistics_objective_short,
		GameState.logistics_regional_pressure_short,
		GameState.logistics_tempo_plan_short,
		GameState.logistics_focus_short
	]
	for candidate_variant in candidates:
		var candidate := String(candidate_variant).strip_edges()
		if candidate != "" and candidate != hint_text:
			return candidate
	if hint_text.begins_with("前10天教程："):
		return "提示：点击城市锁定详情，滚轮缩放地图，右键复位。"
	return hint_text

func _build_tutorial_hint_text() -> String:
	if GameState.current_day > 10:
		return ""
	if GameState.current_day <= 3 and GameState.logistics_objective_target_role_label.strip_edges() != "":
		return "前10天教程：先离开前沿消耗点，优先把路线接到%s。" % GameState.logistics_objective_target_role_label
	if GameState.logistics_runway_days == 0:
		return "前10天教程：你已经跌进战斗惩罚区。下一步优先休整或补给，不要继续硬顶。"
	if GameState.logistics_runway_days == 1 or GameState.supply < 55.0:
		return "前10天教程：补给开始见底时，先打补给牌或休整，不要连续站在低容量节点。"
	if GameState.current_day <= 10 and GameState.logistics_regional_pressure_short.strip_edges() != "":
		return "前10天教程：%s" % GameState.logistics_regional_pressure_short
	if GameState.current_day <= 7 and GameState.logistics_objective_short.strip_edges() != "":
		return "前10天教程：%s" % GameState.logistics_objective_short
	if GameState.current_day <= 10 and GameState.logistics_route_chain_short.strip_edges() != "":
		return "前10天教程：%s" % GameState.logistics_route_chain_short
	if GameState.current_day <= 10 and GameState.logistics_tempo_plan_short.strip_edges() != "":
		return "前10天教程：%s" % GameState.logistics_tempo_plan_short
	if GameState.current_day <= 10 and GameState.logistics_action_plan_short.strip_edges() != "":
		return "前10天教程：%s" % GameState.logistics_action_plan_short
	if GameState.current_day <= 10 and GameState.logistics_objective_target_role_label.strip_edges() != "":
		return "前10天教程：把%s接成跳板后，再考虑发动战役或继续前推。" % GameState.logistics_objective_target_role_label
	return ""


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
	var submitted := false
	if selected_policy_id != "" and selected_policy_id != "rest":
		submitted = TurnManager.submit_action("policy", {"policy_id": selected_policy_id})
	else:
		submitted = TurnManager.submit_action("rest", {})
	if not submitted:
		_set_tray_interactive(true)
		return
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
	if not TurnManager.submit_action(action_name, payload):
		_set_tray_interactive(true)
		return
	_clear_tray_selection()

## map_controller 行军确认回调：向 TurnManager 提交行军行动
func _on_march_confirmed(target_node: String) -> void:
	_set_tray_interactive(false)
	if not TurnManager.submit_action("march", {"target_node": target_node}):
		_set_tray_interactive(true)
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
	_set_tray_interactive(_phase == "action")
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
