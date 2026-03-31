## TopbarActionsController — 从 MainMenu 提取的顶栏按钮与弹窗管理
## 负责设置弹窗、存读档槽位选择、新局确认、模态状态追踪
## 不直接驱动 TurnManager 或 CentJoursEngine

extends Node
class_name TopbarActionsController

const SettingsManagerScript = preload("res://src/core/settings_manager.gd")

signal save_completed(slot_id: int, success: bool)
signal load_completed(slot_id: int, success: bool)
signal new_game_confirmed
signal settings_applied(settings: Dictionary)
signal strategy_goals_requested
signal narrative_log_requested
signal glossary_requested

var _host: Node = null
var _top_bar_row: HBoxContainer = null
var _strategy_btn: Button = null
var _log_btn: Button = null
var _glossary_btn: Button = null
var _settings_btn: Button = null
var _new_game_btn: Button = null
var _save_btn: Button = null
var _load_btn: Button = null

var _settings_state: Dictionary = {}
var _transient_modal_depth: int = 0
var _tracked_transient_modals: Dictionary = {}
var _tray_interactive_before_modal: bool = false

var _on_set_tray_interactive: Callable = Callable()
var _on_is_dialog_modal_active: Callable = Callable()
var _on_restart_game: Callable = Callable()
var _on_refresh_ui: Callable = Callable()
var _on_map_clear_interaction: Callable = Callable()
var _on_build_decision_cards: Callable = Callable()
var _on_refresh_save_load: Callable = Callable()


func configure(
	host: Node,
	top_bar_row: HBoxContainer,
	callbacks: Dictionary = {}
) -> void:
	_host = host
	_top_bar_row = top_bar_row
	_on_set_tray_interactive = callbacks.get("set_tray_interactive", Callable())
	_on_is_dialog_modal_active = callbacks.get("is_dialog_modal_active", Callable())
	_on_restart_game = callbacks.get("restart_game", Callable())
	_on_refresh_ui = callbacks.get("refresh_ui", Callable())
	_on_map_clear_interaction = callbacks.get("map_clear_interaction", Callable())
	_on_build_decision_cards = callbacks.get("build_decision_cards", Callable())
	_on_refresh_save_load = callbacks.get("refresh_save_load", Callable())


func load_and_apply_user_settings(window: Window) -> Dictionary:
	_settings_state = SettingsManagerScript.load_settings()
	SettingsManagerScript.apply_settings(_settings_state, window)
	return _settings_state


func build_topbar_buttons() -> Dictionary:
	var strategy_btn := Button.new()
	strategy_btn.name = "StrategyGoalsButton"
	strategy_btn.text = "结局"
	strategy_btn.custom_minimum_size = Vector2(60, 0)
	strategy_btn.pressed.connect(func(): strategy_goals_requested.emit())
	_top_bar_row.add_child(strategy_btn)

	var log_btn := Button.new()
	log_btn.name = "NarrativeLogButton"
	log_btn.text = "日志"
	log_btn.custom_minimum_size = Vector2(60, 0)
	log_btn.pressed.connect(func(): narrative_log_requested.emit())
	_top_bar_row.add_child(log_btn)

	var glossary_btn := Button.new()
	glossary_btn.name = "GlossaryButton"
	glossary_btn.text = "百科"
	glossary_btn.custom_minimum_size = Vector2(60, 0)
	glossary_btn.pressed.connect(func(): glossary_requested.emit())
	_top_bar_row.add_child(glossary_btn)

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "设置"
	settings_btn.custom_minimum_size = Vector2(60, 0)
	settings_btn.pressed.connect(_on_settings_pressed)
	_top_bar_row.add_child(settings_btn)

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

	_strategy_btn = strategy_btn
	_log_btn = log_btn
	_glossary_btn = glossary_btn
	_settings_btn = settings_btn
	_new_game_btn = new_game_btn
	_save_btn = save_btn
	_load_btn = load_btn
	refresh_save_load_buttons()

	return {
		"settings_btn": settings_btn,
		"strategy_btn": strategy_btn,
		"log_btn": log_btn,
		"glossary_btn": glossary_btn,
		"new_game_btn": new_game_btn,
		"save_btn": save_btn,
		"load_btn": load_btn,
	}


func refresh_save_load_buttons() -> void:
	if _load_btn != null:
		_load_btn.disabled = not SaveManager.has_any_save()


# ── 设置弹窗 ──────────────────────────────────────────

func _on_settings_pressed() -> void:
	_show_settings_popup()


func _show_settings_popup() -> void:
	var popup := PopupPanel.new()
	popup.name = "SettingsPopup"

	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.custom_minimum_size = Vector2(320, 0)
	content.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.name = "SettingsTitle"
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 16)
	content.add_child(title)

	var current_settings := SettingsManagerScript.normalize_settings(_settings_state)
	var window_mode_option := OptionButton.new()
	window_mode_option.name = "SettingsWindowModeOption"
	for option in SettingsManagerScript.WINDOW_MODE_OPTIONS:
		window_mode_option.add_item(String(option.get("label", "")))
		window_mode_option.set_item_metadata(window_mode_option.item_count - 1, String(option.get("id", "")))
	window_mode_option.select(SettingsManagerScript.find_window_mode_index(String(current_settings.get("window_mode", "windowed"))))
	content.add_child(_build_settings_option_row("窗口模式", window_mode_option))

	var ui_scale_option := OptionButton.new()
	ui_scale_option.name = "SettingsUiScaleOption"
	for option in SettingsManagerScript.UI_SCALE_OPTIONS:
		ui_scale_option.add_item(String(option.get("label", "")))
		ui_scale_option.set_item_metadata(ui_scale_option.item_count - 1, float(option.get("value", 1.0)))
	ui_scale_option.select(SettingsManagerScript.find_ui_scale_index(float(current_settings.get("ui_scale", 1.0))))
	content.add_child(_build_settings_option_row("界面缩放", ui_scale_option))

	# 音频音量控制
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio_mgr: Node = _get_audio_manager()
		if audio_mgr != null:
			content.add_child(_build_volume_row(
				"音乐音量",
				audio_mgr.get_music_volume(),
				func(v: float): audio_mgr.set_music_volume(v),
				"SettingsMusicVolume"
			))
			content.add_child(_build_volume_row(
				"音效音量",
				audio_mgr.get_sfx_volume(),
				func(v: float): audio_mgr.set_sfx_volume(v),
				"SettingsSfxVolume"
			))

	var buttons := HBoxContainer.new()
	buttons.name = "SettingsButtonRow"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)

	var reset_button := Button.new()
	reset_button.name = "SettingsResetButton"
	reset_button.text = "恢复默认"
	reset_button.pressed.connect(func(): _reset_settings_from_popup(popup))
	buttons.add_child(reset_button)

	var cancel_button := Button.new()
	cancel_button.name = "SettingsCancelButton"
	cancel_button.text = "取消"
	cancel_button.pressed.connect(func(): _close_transient_popup(popup))
	buttons.add_child(cancel_button)

	var apply_button := Button.new()
	apply_button.name = "SettingsApplyButton"
	apply_button.text = "应用"
	apply_button.pressed.connect(func(): _apply_settings_from_popup(window_mode_option, ui_scale_option, popup))
	buttons.add_child(apply_button)

	content.add_child(buttons)
	popup.add_child(content)
	_host.add_child(popup)
	_open_transient_modal(popup)
	popup.popup_centered(Vector2i(420, 360))


func _build_settings_option_row(label_text: String, option_button: OptionButton) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(96, 0)
	row.add_child(label)
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option_button)
	return row


func _build_volume_row(
	label_text: String,
	initial_value: float,
	on_change: Callable,
	node_prefix: String = ""
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if node_prefix != "":
		row.name = "%sRow" % node_prefix
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(96, 0)
	if node_prefix != "":
		label.name = "%sLabel" % node_prefix
	row.add_child(label)
	var slider := HSlider.new()
	if node_prefix != "":
		slider.name = "%sSlider" % node_prefix
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


func _apply_settings_from_popup(window_mode_option: OptionButton, ui_scale_option: OptionButton, popup: PopupPanel) -> void:
	var window_mode_index := window_mode_option.get_selected_id()
	var ui_scale_index := ui_scale_option.get_selected_id()
	var settings := {
		"window_mode": String(window_mode_option.get_item_metadata(window_mode_index)),
		"ui_scale": float(ui_scale_option.get_item_metadata(ui_scale_index)),
	}
	_settings_state = SettingsManagerScript.normalize_settings(settings)
	SettingsManagerScript.save_settings(_settings_state)
	_close_transient_popup(popup)
	SettingsManagerScript.apply_settings(_settings_state, _host.get_window())
	settings_applied.emit(_settings_state)


func _reset_settings_from_popup(popup: PopupPanel) -> void:
	_settings_state = SettingsManagerScript.default_settings()
	SettingsManagerScript.save_settings(_settings_state)
	_close_transient_popup(popup)
	SettingsManagerScript.apply_settings(_settings_state, _host.get_window())
	settings_applied.emit(_settings_state)


func _get_audio_manager() -> Node:
	var root := _host.get_tree().root if _host != null else null
	if root != null and root.has_node("AudioManager"):
		return root.get_node("AudioManager")
	return null


# ── 新局确认 ──────────────────────────────────────────

func _on_new_game_pressed() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.name = "NewGameConfirmDialog"
	confirm.dialog_text = "重新开始将丢失当前未保存进度，确定吗？"
	confirm.ok_button_text = "确认新开一局"
	confirm.cancel_button_text = "取消"
	_prepare_transient_confirmation_dialog(confirm)
	confirm.confirmed.connect(func():
		_close_transient_popup(confirm)
		new_game_confirmed.emit()
	)
	_host.add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()


# ── 存读档 ──────────────────────────────────────────

func _on_save_pressed() -> void:
	_show_slot_picker("save")


func _on_load_pressed() -> void:
	_show_slot_picker("load")


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
		var row := HBoxContainer.new()
		row.name = "SlotPickerRow%d" % slot_id
		row.add_theme_constant_override("separation", 8)
		var button := Button.new()
		button.name = "%sSlotButton%d" % ["Save" if mode == "save" else "Load", slot_id]
		button.text = String(slot.get("label", "槽位 %d" % slot_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = mode == "load" and not exists
		if mode == "save" and exists:
			button.pressed.connect(_confirm_save_overwrite.bind(slot_id, popup))
		elif mode == "save":
			button.pressed.connect(_save_to_slot.bind(slot_id, popup))
		else:
			button.pressed.connect(_load_from_slot.bind(slot_id, popup))
		row.add_child(button)

		if exists:
			var delete_btn := Button.new()
			delete_btn.name = "%sDeleteSlotButton%d" % ["Save" if mode == "save" else "Load", slot_id]
			delete_btn.text = "删除"
			delete_btn.custom_minimum_size = Vector2(68, 0)
			delete_btn.pressed.connect(_confirm_delete_save.bind(slot_id, popup))
			row.add_child(delete_btn)

		content.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.name = "SlotPickerCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): _close_transient_popup(popup))
	content.add_child(cancel_btn)

	popup.add_child(content)
	_host.add_child(popup)
	_open_transient_modal(popup)
	popup.popup_centered()


func _save_to_slot(slot_id: int, popup: PopupPanel) -> void:
	_close_transient_popup(popup)
	var success := TurnManager.save_to_file(slot_id)
	if success:
		refresh_save_load_buttons()
		_save_btn.text = "已存档 ✓"
		_host.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_save_btn):
				_save_btn.text = "存档"
		)
	else:
		_save_btn.text = "存档失败"
		_host.get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(_save_btn):
				_save_btn.text = "存档"
		)
	save_completed.emit(slot_id, success)


func _load_from_slot(slot_id: int, popup: PopupPanel) -> void:
	_close_transient_popup(popup)
	var confirm := ConfirmationDialog.new()
	confirm.name = "LoadConfirmDialog"
	confirm.dialog_text = "读档将覆盖当前进度，确定读取槽位 %d 吗？" % slot_id
	confirm.ok_button_text = "确认读档"
	confirm.cancel_button_text = "取消"
	_prepare_transient_confirmation_dialog(confirm)
	confirm.confirmed.connect(func():
		_close_transient_popup(confirm)
		var success := TurnManager.load_from_save(slot_id)
		if success:
			if _on_map_clear_interaction.is_valid():
				_on_map_clear_interaction.call()
			if _on_build_decision_cards.is_valid():
				_on_build_decision_cards.call()
			if _on_refresh_ui.is_valid():
				_on_refresh_ui.call()
			if _on_set_tray_interactive.is_valid():
				_on_set_tray_interactive.call(true)
			refresh_save_load_buttons()
		load_completed.emit(slot_id, success)
	)
	_host.add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()


func _confirm_save_overwrite(slot_id: int, popup: PopupPanel) -> void:
	_close_transient_popup(popup)
	var confirm := ConfirmationDialog.new()
	confirm.name = "SaveOverwriteConfirmDialog"
	confirm.dialog_text = "槽位 %d 已有存档（%s），确定覆盖吗？" % [slot_id, _slot_meta_summary(slot_id)]
	confirm.ok_button_text = "确认覆盖"
	confirm.cancel_button_text = "取消"
	_prepare_transient_confirmation_dialog(confirm)
	confirm.canceled.connect(func(): _show_slot_picker("save"))
	confirm.confirmed.connect(func():
		_close_transient_popup(confirm)
		_save_to_slot(slot_id, null)
	)
	_host.add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()


func _confirm_delete_save(slot_id: int, popup: PopupPanel) -> void:
	var mode := "save" if popup != null and popup.name == "SaveSlotPickerPopup" else "load"
	_close_transient_popup(popup)
	var confirm := ConfirmationDialog.new()
	confirm.name = "DeleteSaveConfirmDialog"
	confirm.dialog_text = "确定删除槽位 %d（%s）吗？" % [slot_id, _slot_meta_summary(slot_id)]
	confirm.ok_button_text = "确认删除"
	confirm.cancel_button_text = "取消"
	_prepare_transient_confirmation_dialog(confirm)
	confirm.canceled.connect(func(): _show_slot_picker(mode))
	confirm.confirmed.connect(func():
		_close_transient_popup(confirm)
		SaveManager.delete_save(slot_id)
		refresh_save_load_buttons()
	)
	_host.add_child(confirm)
	_open_transient_modal(confirm)
	confirm.popup_centered()


func _slot_meta_summary(slot_id: int) -> String:
	var meta := SaveManager.get_save_meta(slot_id)
	if meta.is_empty():
		return "空槽位"
	return "第 %d 天 · %s" % [
		int(meta.get("day", 0)),
		SaveManager._outcome_label(SaveManager._normalize_outcome(meta.get("outcome", "in_progress")))
	]


# ── 模态管理 ──────────────────────────────────────────

func _prepare_transient_confirmation_dialog(confirm: ConfirmationDialog) -> void:
	if confirm == null:
		return
	confirm.canceled.connect(func(): _close_transient_popup(confirm))


func _open_transient_modal(popup: Window) -> void:
	if popup == null:
		return
	var popup_id := popup.get_instance_id()
	if _tracked_transient_modals.has(popup_id):
		return
	if _transient_modal_depth == 0:
		var awaiting := true
		if _on_is_dialog_modal_active.is_valid():
			awaiting = not _on_is_dialog_modal_active.call()
		_tray_interactive_before_modal = awaiting
	_tracked_transient_modals[popup_id] = true
	_transient_modal_depth += 1
	if _on_set_tray_interactive.is_valid():
		_on_set_tray_interactive.call(false)
	var visibility_changed_cb := Callable(self, "_on_transient_modal_visibility_changed").bind(popup)
	if not popup.visibility_changed.is_connected(visibility_changed_cb):
		popup.visibility_changed.connect(visibility_changed_cb)


func _close_transient_popup(popup: Window) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	popup.hide()
	popup.queue_free()


func _on_transient_modal_visibility_changed(popup: Window) -> void:
	if popup != null and popup.visible:
		return
	var popup_id := popup.get_instance_id() if popup != null else 0
	if not _tracked_transient_modals.has(popup_id):
		return
	_tracked_transient_modals.erase(popup_id)
	var visibility_changed_cb := Callable(self, "_on_transient_modal_visibility_changed").bind(popup)
	if popup != null and popup.visibility_changed.is_connected(visibility_changed_cb):
		popup.visibility_changed.disconnect(visibility_changed_cb)
	_on_transient_modal_closed()


func _on_transient_modal_closed() -> void:
	_transient_modal_depth = max(_transient_modal_depth - 1, 0)
	if _transient_modal_depth > 0:
		return
	if _on_is_dialog_modal_active.is_valid() and _on_is_dialog_modal_active.call():
		return
	if _on_set_tray_interactive.is_valid():
		_on_set_tray_interactive.call(_tray_interactive_before_modal)
