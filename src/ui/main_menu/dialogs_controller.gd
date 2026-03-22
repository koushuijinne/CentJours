## MainMenuDialogsController - extracts modal dialog responsibilities from MainMenu.
## Host/main menu injects callbacks so this controller stays decoupled from TurnManager
## and the underlying game state source.

extends Node
class_name MainMenuDialogsController

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")

const CALLBACK_SET_TRAY_INTERACTIVE := "set_tray_interactive"
const CALLBACK_RESET_ENGINE := "reset_engine"
const CALLBACK_REBUILD_DECISION_CARDS := "rebuild_decision_cards"
const CALLBACK_START_GAME := "start_game"
const CALLBACK_REFRESH_UI := "refresh_ui"
const CALLBACK_SUBMIT_ACTION := "submit_action"
const CALLBACK_RESTART_REQUESTED := "restart_requested"

const ACTION_BATTLE := "battle"
const ACTION_BOOST_LOYALTY := "boost_loyalty"

const STATE_KEY_CURRENT_DAY := "current_day"
const STATE_KEY_DAY := "day"
const STATE_KEY_LEGITIMACY := "legitimacy"
const STATE_KEY_VICTORIES := "victories"
const STATE_KEY_TOTAL_TROOPS := "total_troops"
const STATE_KEY_AVG_MORALE := "avg_morale"
const STATE_KEY_CHARACTERS := "characters"

const DEFAULT_GAME_OVER_STATE := {
	STATE_KEY_CURRENT_DAY: 1,
	STATE_KEY_LEGITIMACY: 0.0,
	STATE_KEY_VICTORIES: 0,
	STATE_KEY_TOTAL_TROOPS: 0,
	STATE_KEY_AVG_MORALE: 0.0,
}

signal restart_requested
signal battle_confirmed(general_id: String, troops: int, terrain: String)
signal boost_confirmed(general_id: String)

var _host: Node = null
var _callbacks: Dictionary = {}

var _game_over_overlay: ColorRect = null
var _battle_popup: PopupPanel = null
var _boost_popup: PopupPanel = null


func configure(host: Node, callbacks: Dictionary = {}) -> void:
	_host = host
	set_callbacks(callbacks)


func set_callbacks(callbacks: Dictionary) -> void:
	_callbacks.clear()
	if callbacks == null:
		return
	for callback_name in _expected_callback_names():
		var callback: Variant = callbacks.get(callback_name, Callable())
		if callback is Callable and callback.is_valid():
			_callbacks[callback_name] = callback


func build_game_over_state(stats: Dictionary = {}) -> Dictionary:
	var normalized := DEFAULT_GAME_OVER_STATE.duplicate(true)
	normalized[STATE_KEY_CURRENT_DAY] = _get_int_stat(stats, STATE_KEY_CURRENT_DAY, _get_int_stat(stats, STATE_KEY_DAY, int(DEFAULT_GAME_OVER_STATE[STATE_KEY_CURRENT_DAY])))
	normalized[STATE_KEY_LEGITIMACY] = _get_float_stat(stats, STATE_KEY_LEGITIMACY, float(DEFAULT_GAME_OVER_STATE[STATE_KEY_LEGITIMACY]))
	normalized[STATE_KEY_VICTORIES] = _get_int_stat(stats, STATE_KEY_VICTORIES, int(DEFAULT_GAME_OVER_STATE[STATE_KEY_VICTORIES]))
	normalized[STATE_KEY_TOTAL_TROOPS] = _get_int_stat(stats, STATE_KEY_TOTAL_TROOPS, int(DEFAULT_GAME_OVER_STATE[STATE_KEY_TOTAL_TROOPS]))
	normalized[STATE_KEY_AVG_MORALE] = _get_float_stat(stats, STATE_KEY_AVG_MORALE, float(DEFAULT_GAME_OVER_STATE[STATE_KEY_AVG_MORALE]))
	return normalized


func dismiss_active_popups() -> void:
	_close_game_over_overlay()
	_close_battle_popup()
	_close_boost_popup()


func is_modal_active() -> bool:
	return _game_over_overlay != null or _battle_popup != null or _boost_popup != null


func show_game_over(outcome: String, stats: Dictionary = {}) -> void:
	_close_game_over_overlay()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

	_game_over_overlay = ColorRect.new()
	_game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.color = Color(0, 0, 0, 0.7)
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_host_or_self().add_child(_game_over_overlay)

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

	var info: Dictionary = MainMenuConfigData.OUTCOME_TEXT.get(outcome, {"title": "— Fin —", "desc": outcome})
	var title_label := Label.new()
	title_label.text = String(info.get("title", "— Fin —"))
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = String(info.get("desc", outcome))
	desc_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var game_over_state := build_game_over_state(stats)
	var current_day := int(game_over_state[STATE_KEY_CURRENT_DAY])
	var legitimacy := float(game_over_state[STATE_KEY_LEGITIMACY])
	var victories := int(game_over_state[STATE_KEY_VICTORIES])
	var total_troops := int(game_over_state[STATE_KEY_TOTAL_TROOPS])
	var avg_morale := float(game_over_state[STATE_KEY_AVG_MORALE])
	var stats_label := Label.new()
	stats_label.text = "\n最终统计\n天数: %d  |  合法性: %.0f\n胜场: %d  |  兵力: %d  |  士气: %.0f" % [
		current_day,
		legitimacy,
		victories,
		total_troops,
		avg_morale
	]
	stats_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(140, 36)
	restart_btn.pressed.connect(_on_restart_requested)
	vbox.add_child(restart_btn)

	panel.add_child(vbox)
	_game_over_overlay.add_child(panel)


func show_battle_popup(state: Dictionary = {}) -> void:
	_close_popup(_battle_popup)
	_battle_popup = PopupPanel.new()

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 300)

	var title := Label.new()
	title.text = "发动战役"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var characters: Dictionary = state.get(STATE_KEY_CHARACTERS, {})

	var gen_label := Label.new()
	gen_label.text = "指挥将领："
	vbox.add_child(gen_label)

	var gen_option := OptionButton.new()
	for char_id in characters:
		var c: Dictionary = characters[char_id]
		if c.get("role", "") == "marshal":
			var loyalty: float = float(c.get("loyalty", 50))
			var skill: int = int(c.get("military_skill", 50))
			gen_option.add_item("%s (技能:%d 忠诚:%.0f)" % [c.get("name", char_id), skill, loyalty])
			gen_option.set_item_metadata(gen_option.item_count - 1, char_id)
	vbox.add_child(gen_option)

	var troop_label := Label.new()
	troop_label.text = "投入兵力："
	vbox.add_child(troop_label)

	var total_troops := int(state.get(STATE_KEY_TOTAL_TROOPS, 1000))
	var troop_slider := HSlider.new()
	troop_slider.min_value = 1000
	troop_slider.max_value = max(total_troops, 1000)
	troop_slider.step = 1000
	troop_slider.value = total_troops / 2
	vbox.add_child(troop_slider)

	var troop_value := Label.new()
	troop_value.text = "%d 人" % int(troop_slider.value)
	troop_slider.value_changed.connect(func(v: float): troop_value.text = "%d 人" % int(v))
	vbox.add_child(troop_value)

	var terrain_label := Label.new()
	terrain_label.text = "战场地形："
	vbox.add_child(terrain_label)

	var terrain_option := OptionButton.new()
	for tid in MainMenuConfigData.TERRAIN_OPTIONS:
		terrain_option.add_item(String(MainMenuConfigData.TERRAIN_OPTIONS[tid]))
		terrain_option.set_item_metadata(terrain_option.item_count - 1, tid)
	vbox.add_child(terrain_option)

	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.text = "确认出战"
	confirm_btn.pressed.connect(_confirm_battle.bind(gen_option, troop_slider, terrain_option))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_close_battle_popup)
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_battle_popup.add_child(vbox)
	_host_or_self().add_child(_battle_popup)
	_battle_popup.popup_centered()


func show_boost_popup(state: Dictionary = {}) -> void:
	_close_popup(_boost_popup)
	_boost_popup = PopupPanel.new()

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 220)

	var title := Label.new()
	title.text = "亲自接见将领（-5 合法性 → +8 忠诚度）"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var legitimacy := float(state.get(STATE_KEY_LEGITIMACY, 0.0))
	if legitimacy < 10.0:
		var warn := Label.new()
		warn.text = "合法性不足（需 >= 10，当前 %.0f）" % legitimacy
		warn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		vbox.add_child(warn)

	var characters: Dictionary = state.get(STATE_KEY_CHARACTERS, {})
	var gen_option := OptionButton.new()
	for char_id in characters:
		var c: Dictionary = characters[char_id]
		var loyalty: float = float(c.get("loyalty", 50))
		gen_option.add_item("%s (忠诚度: %.0f)" % [MainMenuFormattersLib.character_display_name(characters, String(char_id)), loyalty])
		gen_option.set_item_metadata(gen_option.item_count - 1, char_id)
	vbox.add_child(gen_option)

	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.text = "确认接见"
	confirm_btn.disabled = legitimacy < 10.0
	confirm_btn.pressed.connect(_confirm_boost.bind(gen_option))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_close_boost_popup)
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_boost_popup.add_child(vbox)
	_host_or_self().add_child(_boost_popup)
	_boost_popup.popup_centered()


func _confirm_battle(gen_opt: OptionButton, troop_slider: HSlider, terrain_opt: OptionButton) -> void:
	var general_id: String = gen_opt.get_item_metadata(gen_opt.selected)
	var troops: int = int(troop_slider.value)
	var terrain: String = String(terrain_opt.get_item_metadata(terrain_opt.selected))
	_close_battle_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])
	var payload := {
		"general_id": general_id,
		"troops": troops,
		"terrain": terrain
	}
	if not _call_optional(CALLBACK_SUBMIT_ACTION, [ACTION_BATTLE, payload]):
		battle_confirmed.emit(general_id, troops, terrain)


func _confirm_boost(gen_opt: OptionButton) -> void:
	var general_id: String = gen_opt.get_item_metadata(gen_opt.selected)
	_close_boost_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])
	var payload := {"general_id": general_id}
	if not _call_optional(CALLBACK_SUBMIT_ACTION, [ACTION_BOOST_LOYALTY, payload]):
		boost_confirmed.emit(general_id)


func _on_restart_requested() -> void:
	_close_game_over_overlay()
	_call_optional(CALLBACK_RESET_ENGINE)
	_call_optional(CALLBACK_REBUILD_DECISION_CARDS)
	_call_optional(CALLBACK_START_GAME)
	_call_optional(CALLBACK_REFRESH_UI)
	if not _call_optional(CALLBACK_RESTART_REQUESTED):
		restart_requested.emit()


func _close_game_over_overlay() -> void:
	if _game_over_overlay == null:
		return
	_game_over_overlay.queue_free()
	_game_over_overlay = null


func _close_popup(popup: PopupPanel) -> void:
	if popup != null:
		popup.queue_free()


func _close_battle_popup() -> void:
	_close_popup(_battle_popup)
	_battle_popup = null


func _close_boost_popup() -> void:
	_close_popup(_boost_popup)
	_boost_popup = null


func _call_optional(callback_name: String, args: Array = []) -> bool:
	var callback: Variant = _callbacks.get(callback_name, Callable())
	if callback is Callable and callback.is_valid():
		(callback as Callable).callv(args)
		return true
	return false


func _host_or_self() -> Node:
	return _host if _host != null else self


func _expected_callback_names() -> Array[String]:
	return [
		CALLBACK_SET_TRAY_INTERACTIVE,
		CALLBACK_RESET_ENGINE,
		CALLBACK_REBUILD_DECISION_CARDS,
		CALLBACK_START_GAME,
		CALLBACK_REFRESH_UI,
		CALLBACK_SUBMIT_ACTION,
		CALLBACK_RESTART_REQUESTED,
	]


func _get_int_stat(stats: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = stats.get(key, fallback)
	return int(value) if value != null else fallback


func _get_float_stat(stats: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = stats.get(key, fallback)
	return float(value) if value != null else fallback
