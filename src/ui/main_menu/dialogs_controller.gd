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
const STATE_KEY_SUPPLY := "supply"
const STATE_KEY_CHARACTERS := "characters"
const STATE_KEY_LOCATION_LABEL := "location_label"
const STATE_KEY_LOCATION_TERRAIN := "location_terrain"
const STATE_KEY_LOGISTICS_POSTURE_LABEL := "logistics_posture_label"
const STATE_KEY_LOGISTICS_OBJECTIVE_LABEL := "logistics_objective_label"
const STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL := "logistics_primary_action_label"
const STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON := "logistics_primary_action_reason"
const STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL := "logistics_tempo_plan_detail"
const STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL := "logistics_route_chain_detail"
const STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL := "logistics_regional_pressure_detail"
const STATE_KEY_LOGISTICS_RUNWAY_LABEL := "logistics_runway_label"

const DEFAULT_GAME_OVER_STATE := {
	STATE_KEY_CURRENT_DAY: 1,
	STATE_KEY_LEGITIMACY: 0.0,
	STATE_KEY_VICTORIES: 0,
	STATE_KEY_TOTAL_TROOPS: 0,
	STATE_KEY_AVG_MORALE: 0.0,
	STATE_KEY_SUPPLY: 0.0,
	STATE_KEY_LOCATION_LABEL: "",
	STATE_KEY_LOGISTICS_POSTURE_LABEL: "",
	STATE_KEY_LOGISTICS_OBJECTIVE_LABEL: "",
	STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL: "",
	STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON: "",
	STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL: "",
	STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL: "",
	STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL: "",
	STATE_KEY_LOGISTICS_RUNWAY_LABEL: "",
}

signal restart_requested
signal difficulty_selected(difficulty_id: String)
signal battle_confirmed(general_id: String, troops: int, terrain: String)
signal boost_confirmed(general_id: String)

var _host: Node = null
var _callbacks: Dictionary = {}

var _game_over_overlay: ColorRect = null
var _difficulty_popup: PopupPanel = null
var _battle_popup: PopupPanel = null
var _boost_popup: PopupPanel = null
var _info_popup: PopupPanel = null


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
	normalized[STATE_KEY_SUPPLY] = _get_float_stat(stats, STATE_KEY_SUPPLY, float(DEFAULT_GAME_OVER_STATE[STATE_KEY_SUPPLY]))
	normalized[STATE_KEY_LOCATION_LABEL] = String(stats.get(STATE_KEY_LOCATION_LABEL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOCATION_LABEL]))
	normalized[STATE_KEY_LOGISTICS_POSTURE_LABEL] = String(stats.get(STATE_KEY_LOGISTICS_POSTURE_LABEL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_POSTURE_LABEL]))
	normalized[STATE_KEY_LOGISTICS_OBJECTIVE_LABEL] = String(stats.get(STATE_KEY_LOGISTICS_OBJECTIVE_LABEL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_OBJECTIVE_LABEL]))
	normalized[STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL] = String(stats.get(STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL]))
	normalized[STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON] = String(stats.get(STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON]))
	normalized[STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL] = String(stats.get(STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL]))
	normalized[STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL] = String(stats.get(STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL]))
	normalized[STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL] = String(stats.get(STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL]))
	normalized[STATE_KEY_LOGISTICS_RUNWAY_LABEL] = String(stats.get(STATE_KEY_LOGISTICS_RUNWAY_LABEL, DEFAULT_GAME_OVER_STATE[STATE_KEY_LOGISTICS_RUNWAY_LABEL]))
	return normalized


func dismiss_active_popups() -> void:
	_close_game_over_overlay()
	_close_difficulty_popup()
	_close_battle_popup()
	_close_boost_popup()
	_close_info_popup()


func is_modal_active() -> bool:
	return _game_over_overlay != null or _difficulty_popup != null or _battle_popup != null or _boost_popup != null or _info_popup != null


func show_info_popup(popup_name: String, title_text: String, body_text: String, close_text: String = "关闭") -> void:
	_close_info_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

	_info_popup = PopupPanel.new()
	_info_popup.name = popup_name
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(580, 0)
	content.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.name = "%sTitle" % popup_name
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % popup_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(540, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)

	var body := Label.new()
	body.name = "%sBody" % popup_name
	body.text = body_text
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(520, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	scroll.add_child(body)

	var close_button := Button.new()
	close_button.name = "%sCloseButton" % popup_name
	close_button.text = close_text
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_dismiss_info_popup)
	content.add_child(close_button)

	_info_popup.add_child(content)
	_host_or_self().add_child(_info_popup)
	_info_popup.popup_centered(Vector2i(620, 480))


func show_game_over(outcome: String, stats: Dictionary = {}) -> void:
	_close_game_over_overlay()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

	_game_over_overlay = ColorRect.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.color = Color(0, 0, 0, 0.7)
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_host_or_self().add_child(_game_over_overlay)

	var panel := PanelContainer.new()
	panel.name = "GameOverPanel"
	panel.custom_minimum_size = Vector2(500, 420)
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
	title_label.name = "GameOverTitleLabel"
	title_label.text = String(info.get("title", "— Fin —"))
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "GameOverDescLabel"
	desc_label.text = String(info.get("desc", outcome))
	desc_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var game_over_state := build_game_over_state(stats)
	var current_day := _display_game_over_day(int(game_over_state[STATE_KEY_CURRENT_DAY]))
	var legitimacy := float(game_over_state[STATE_KEY_LEGITIMACY])
	var victories := int(game_over_state[STATE_KEY_VICTORIES])
	var total_troops := int(game_over_state[STATE_KEY_TOTAL_TROOPS])
	var avg_morale := float(game_over_state[STATE_KEY_AVG_MORALE])
	var supply := float(game_over_state[STATE_KEY_SUPPLY])
	_append_game_over_section(
		vbox,
		"终局尾声",
		_build_game_over_epilogue(outcome, game_over_state, info),
		CentJoursTheme.COLOR["gold_dim"],
		CentJoursTheme.COLOR["text_primary"]
	)

	var stats_label := Label.new()
	stats_label.name = "GameOverStatsLabel"
	stats_label.text = "\n最终统计\n天数: %d  |  合法性: %.0f\n胜场: %d  |  兵力: %d  |  士气: %.0f  |  补给: %.0f" % [
		current_day,
		legitimacy,
		victories,
		total_troops,
		avg_morale,
		supply
	]
	stats_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	_append_game_over_section(
		vbox,
		"战局复盘",
		_build_game_over_review(outcome, game_over_state, info),
		CentJoursTheme.COLOR["gold_dim"],
		CentJoursTheme.COLOR["text_secondary"]
	)

	# 关键决策时间线（失败归因）
	var key_decisions: Array = Array(stats.get("key_decisions", []))
	if not key_decisions.is_empty():
		_append_game_over_section(
			vbox,
			"关键决策",
			_build_key_decisions_text(key_decisions),
			CentJoursTheme.COLOR["gold_dim"],
			CentJoursTheme.COLOR["text_secondary"]
		)

	# 难度标记
	var diff_id: String = String(stats.get("difficulty", "borodino"))
	if diff_id != "":
		var diff_info: Dictionary = MainMenuConfigData.DIFFICULTY_OPTIONS.get(diff_id, {})
		var diff_label: String = String(diff_info.get("label", diff_id))
		var diff_note := Label.new()
		diff_note.text = "难度：%s" % diff_label
		diff_note.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		diff_note.add_theme_font_size_override("font_size", 12)
		diff_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(diff_note)

	var restart_btn := Button.new()
	restart_btn.name = "GameOverRestartButton"
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(140, 36)
	restart_btn.pressed.connect(_on_restart_requested)
	vbox.add_child(restart_btn)

	panel.add_child(vbox)
	_game_over_overlay.add_child(panel)


func _build_game_over_epilogue(outcome: String, game_over_state: Dictionary, info: Dictionary) -> String:
	return _select_outcome_copy(outcome, game_over_state, info, "epilogue_variants", "epilogue")


## 终局复盘优先解释“为什么输/赢”，把已有 review_hint 和实时统计拼在一起。
func _build_game_over_review(outcome: String, game_over_state: Dictionary, info: Dictionary) -> String:
	var lines: Array[String] = []
	var review_hint := _select_outcome_copy(outcome, game_over_state, info, "review_hint_variants", "review_hint")
	if review_hint != "":
		lines.append(review_hint)

	var current_day := _display_game_over_day(int(game_over_state[STATE_KEY_CURRENT_DAY]))
	var legitimacy := float(game_over_state[STATE_KEY_LEGITIMACY])
	var victories := int(game_over_state[STATE_KEY_VICTORIES])
	var total_troops := int(game_over_state[STATE_KEY_TOTAL_TROOPS])
	var avg_morale := float(game_over_state[STATE_KEY_AVG_MORALE])
	var supply := float(game_over_state[STATE_KEY_SUPPLY])
	var location_label := String(game_over_state.get(STATE_KEY_LOCATION_LABEL, "")).strip_edges()
	var logistics_posture_label := String(game_over_state.get(STATE_KEY_LOGISTICS_POSTURE_LABEL, "")).strip_edges()
	var logistics_objective_label := String(game_over_state.get(STATE_KEY_LOGISTICS_OBJECTIVE_LABEL, "")).strip_edges()
	var logistics_primary_action_label := String(game_over_state.get(STATE_KEY_LOGISTICS_PRIMARY_ACTION_LABEL, "")).strip_edges()
	var logistics_primary_action_reason := String(game_over_state.get(STATE_KEY_LOGISTICS_PRIMARY_ACTION_REASON, "")).strip_edges()
	var logistics_tempo_plan_detail := String(game_over_state.get(STATE_KEY_LOGISTICS_TEMPO_PLAN_DETAIL, "")).strip_edges()
	var logistics_route_chain_detail := String(game_over_state.get(STATE_KEY_LOGISTICS_ROUTE_CHAIN_DETAIL, "")).strip_edges()
	var logistics_regional_pressure_detail := String(game_over_state.get(STATE_KEY_LOGISTICS_REGIONAL_PRESSURE_DETAIL, "")).strip_edges()
	var logistics_runway_label := String(game_over_state.get(STATE_KEY_LOGISTICS_RUNWAY_LABEL, "")).strip_edges()

	match outcome:
		"napoleon_victory":
			lines.append("你把政权撑到了终局，还拿下了 %d 场有效胜利。政治线和军事线都没有先失手。" % victories)
		"diplomatic_settlement":
			lines.append("你在第 %d 天通过外交途径达成了停火，合法性 %.0f 和外交进程共同促成了这个结局。" % [current_day, legitimacy])
		"military_dominance":
			lines.append("你拿下了 %d 场胜利，以压倒性军事优势结束了百日。但合法性只有 %.0f，帝国靠剑而立。" % [victories, legitimacy])
		"waterloo_historical":
			lines.append("你把百日政权维持到了最后，但 %d 场胜利还不足以把中盘优势滚成改写历史的结果。" % victories)
		"waterloo_defeat":
			lines.append("终局时合法性 %.0f、胜场 %d，说明政治与军事两条线都没能守住最后的窗口。" % [legitimacy, victories])
		"political_collapse":
			lines.append("你在第 %d 天提前出局，说明巴黎内部先于战场给出了否决。" % current_day)
		"military_annihilation":
			lines.append("你在第 %d 天把兵力打到只剩 %d，前线先于首都承受不住损耗。" % [current_day, total_troops])

	if outcome != "napoleon_victory" and victories < 3:
		lines.append("有效胜场只有 %d 场，军事窗口没有被扩大成决定性优势。" % victories)
	if legitimacy < 35.0:
		lines.append("终局合法性只剩 %.0f，政治支持已经不足以继续承担战争。" % legitimacy)
	if supply < 45.0:
		lines.append("终局补给只剩 %.0f，说明你在最后几步里已经把库存压进了前线惩罚区。" % supply)
	if total_troops < 20000:
		lines.append("终局兵力只剩 %d，人力储备已经不够继续换时间。" % total_troops)
	if avg_morale < 45.0:
		lines.append("终局士气 %.0f，说明连续损耗和疲劳没有被及时修复。" % avg_morale)
	if logistics_posture_label != "":
		lines.append("最后的后勤态势是“%s”。" % logistics_posture_label)
	if logistics_objective_label != "":
		lines.append("最后阶段的运营目标仍是“%s”，说明你还没把节奏切到更安全的位置。" % logistics_objective_label)
	if logistics_primary_action_label != "":
		lines.append("若终局前还能再做一步，更稳的操作应是“%s”。" % logistics_primary_action_label)
	if logistics_primary_action_reason != "":
		lines.append(logistics_primary_action_reason)
	if logistics_tempo_plan_detail != "":
		lines.append("若提前两三天开始修正节奏，更稳的顺序通常是：\n%s" % logistics_tempo_plan_detail)
	if logistics_route_chain_detail != "":
		lines.append("若要把这几天走成一条更稳的运营线，可以参考：\n%s" % logistics_route_chain_detail)
	if logistics_regional_pressure_detail != "":
		lines.append("若想先把当前区域站稳，再考虑继续前推，可参考：\n%s" % logistics_regional_pressure_detail)
	if logistics_runway_label != "":
		lines.append(logistics_runway_label)
	if location_label != "":
		lines.append("最后位置在 %s。" % location_label)
	lines.append_array(_build_logistics_policy_review(game_over_state))

	return "\n".join(lines)


func _build_logistics_policy_review(game_over_state: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var supply := float(game_over_state[STATE_KEY_SUPPLY])
	var logistics_posture_label := String(game_over_state.get(STATE_KEY_LOGISTICS_POSTURE_LABEL, "")).strip_edges()
	var logistics_objective_label := String(game_over_state.get(STATE_KEY_LOGISTICS_OBJECTIVE_LABEL, "")).strip_edges()
	var logistics_runway_label := String(game_over_state.get(STATE_KEY_LOGISTICS_RUNWAY_LABEL, "")).strip_edges()

	if supply < 45.0:
		lines.append("政策复盘：补给跌破 45 还在继续硬顶，通常说明「征用沿线仓储」打得太晚，或该先休整却继续赶路。")
	elif supply < 60.0:
		lines.append("政策复盘：补给已经开始承压时，更早打出「整顿驿站运输」能让后面两三天的推进稳很多。")

	if logistics_posture_label == "运输线拉长":
		lines.append("政策复盘：终局还处在“运输线拉长”，说明你没有及时用「整顿驿站运输」或在中继节点建立「前沿粮秣站」。")
	elif logistics_posture_label == "前线消耗区":
		lines.append("政策复盘：你把部队长期停在低容量前线点。更稳的打法是先接上整补点，再决定要不要为前线付补给代价。")

	if logistics_objective_label.find("区域整补点") >= 0:
		lines.append("政策复盘：阶段目标还停在“区域整补点”，说明路线没有尽早接上中继仓储；这时比继续赌前线更该优先铺站或整顿运输。")
	elif logistics_objective_label.find("决定性前线点") >= 0 and supply < 55.0:
		lines.append("政策复盘：终盘可以为决定性前线点付代价，但前提是先把库存和跳板备好；否则会在最后几步把补给压垮。")

	if logistics_runway_label.find("惩罚区") >= 0:
		lines.append("政策复盘：最后的补给窗口已经在惩罚区，这通常不是单回合失误，而是连续几步都没把补给牌和整补日排进节奏。 ")

	return lines


func _build_key_decisions_text(decisions: Array) -> String:
	var lines: Array[String] = []
	for decision in decisions:
		var d: Dictionary = decision if decision is Dictionary else {}
		var day: int = int(d.get("day", 0))
		var desc: String = String(d.get("desc", ""))
		if desc != "":
			lines.append("第 %d 天 — %s" % [day, desc])
	if lines.is_empty():
		return ""
	# 最多展示最后 8 条关键决策
	if lines.size() > 8:
		lines = lines.slice(lines.size() - 8)
	return "\n".join(lines)


## 允许结局文案按终局状态选择不同变体；未提供 variants 时回退到单条文案。
func _select_outcome_copy(
	outcome: String,
	game_over_state: Dictionary,
	info: Dictionary,
	variants_key: String,
	fallback_key: String
) -> String:
	var variants: Array = Array(info.get(variants_key, []))
	if variants.is_empty():
		return String(info.get(fallback_key, "")).strip_edges()

	var variant_index := _select_outcome_variant_index(outcome, game_over_state, variants.size())
	return String(variants[variant_index]).strip_edges()


func _select_outcome_variant_index(outcome: String, game_over_state: Dictionary, variant_count: int) -> int:
	if variant_count <= 1:
		return 0

	var current_day := _display_game_over_day(int(game_over_state[STATE_KEY_CURRENT_DAY]))
	var legitimacy := float(game_over_state[STATE_KEY_LEGITIMACY])
	var victories := int(game_over_state[STATE_KEY_VICTORIES])
	var total_troops := int(game_over_state[STATE_KEY_TOTAL_TROOPS])
	var avg_morale := float(game_over_state[STATE_KEY_AVG_MORALE])

	var selected_index := 0
	match outcome:
		"napoleon_victory":
			selected_index = 1 if victories >= 4 or legitimacy >= 65.0 else 0
		"diplomatic_settlement":
			selected_index = 1 if legitimacy >= 70.0 else 0
		"military_dominance":
			selected_index = 1 if victories >= 6 else 0
		"waterloo_historical":
			selected_index = 1 if legitimacy >= 45.0 else 0
		"waterloo_defeat":
			selected_index = 1 if total_troops < 15000 or legitimacy < 20.0 else 0
		"political_collapse":
			selected_index = 1 if current_day < 60 else 0
		"military_annihilation":
			selected_index = 1 if avg_morale < 30.0 else 0
		_:
			selected_index = 1 if current_day >= 80 else 0
	return clampi(selected_index, 0, variant_count - 1)


func _append_game_over_section(
	container: VBoxContainer,
	title: String,
	body: String,
	title_color: Color,
	body_color: Color
) -> void:
	var trimmed_body := body.strip_edges()
	if trimmed_body == "":
		return

	var title_label := Label.new()
	title_label.text = "\n%s" % title
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title_label)

	var body_label := Label.new()
	body_label.text = trimmed_body
	body_label.add_theme_color_override("font_color", body_color)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(body_label)


func _display_game_over_day(day: int) -> int:
	return min(day, 100)


func show_difficulty_selection() -> void:
	_close_difficulty_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

	_difficulty_popup = PopupPanel.new()
	_difficulty_popup.name = "DifficultyPopup"

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380, 0)
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.name = "DifficultyTitle"
	title.text = "选择难度"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_bright"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for diff_id in MainMenuConfigData.DIFFICULTY_OPTIONS:
		var diff_data: Dictionary = MainMenuConfigData.DIFFICULTY_OPTIONS[diff_id]
		var btn := Button.new()
		btn.name = "Difficulty_%s" % diff_id
		btn.text = String(diff_data.get("label", diff_id))
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_difficulty_chosen.bind(String(diff_id)))
		vbox.add_child(btn)

		var desc := Label.new()
		desc.text = String(diff_data.get("desc", ""))
		desc.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		desc.add_theme_font_size_override("font_size", 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc)

	var cancel_btn := Button.new()
	cancel_btn.name = "DifficultyCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_dismiss_difficulty_popup)
	vbox.add_child(cancel_btn)

	_difficulty_popup.add_child(vbox)
	_host_or_self().add_child(_difficulty_popup)
	_difficulty_popup.popup_centered()


func _on_difficulty_chosen(diff_id: String) -> void:
	_close_difficulty_popup()
	difficulty_selected.emit(diff_id)


func _close_difficulty_popup() -> void:
	_close_popup(_difficulty_popup)
	_difficulty_popup = null


func _dismiss_difficulty_popup() -> void:
	_close_difficulty_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])


func show_battle_popup(state: Dictionary = {}) -> void:
	_close_popup(_battle_popup)
	_battle_popup = PopupPanel.new()
	_battle_popup.name = "BattlePopup"
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 300)

	var title := Label.new()
	title.text = "发动战役"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var location_label := String(state.get(STATE_KEY_LOCATION_LABEL, ""))
	var default_terrain_id := String(state.get(STATE_KEY_LOCATION_TERRAIN, "plains"))
	if location_label != "":
		var location_hint := Label.new()
		location_hint.text = "当前战场：%s" % location_label
		location_hint.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		vbox.add_child(location_hint)

	var characters: Dictionary = state.get(STATE_KEY_CHARACTERS, {})

	var gen_label := Label.new()
	gen_label.text = "指挥将领："
	vbox.add_child(gen_label)

	var gen_option := OptionButton.new()
	gen_option.name = "BattleGeneralOption"
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
	troop_slider.name = "BattleTroopSlider"
	troop_slider.min_value = 1000
	troop_slider.max_value = max(total_troops, 1000)
	troop_slider.step = 1000
	troop_slider.value = max(float(total_troops) / 2.0, troop_slider.min_value)
	vbox.add_child(troop_slider)

	var troop_value := Label.new()
	troop_value.text = "%d 人" % int(troop_slider.value)
	troop_slider.value_changed.connect(func(v: float): troop_value.text = "%d 人" % int(v))
	vbox.add_child(troop_value)

	var terrain_label := Label.new()
	terrain_label.text = "战场地形："
	vbox.add_child(terrain_label)

	var terrain_option := OptionButton.new()
	terrain_option.name = "BattleTerrainOption"
	for tid in MainMenuConfigData.TERRAIN_OPTIONS:
		terrain_option.add_item(String(MainMenuConfigData.TERRAIN_OPTIONS[tid]))
		terrain_option.set_item_metadata(terrain_option.item_count - 1, tid)
		if String(tid) == default_terrain_id:
			terrain_option.select(terrain_option.item_count - 1)
	vbox.add_child(terrain_option)

	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.name = "BattleConfirmButton"
	confirm_btn.text = "确认出战"
	confirm_btn.pressed.connect(_confirm_battle.bind(gen_option, troop_slider, terrain_option))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "BattleCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_dismiss_battle_popup)
	btn_row.add_child(cancel_btn)
	vbox.add_child(btn_row)

	_battle_popup.add_child(vbox)
	_host_or_self().add_child(_battle_popup)
	_battle_popup.popup_centered()


func show_boost_popup(state: Dictionary = {}) -> void:
	_close_popup(_boost_popup)
	_boost_popup = PopupPanel.new()
	_boost_popup.name = "BoostPopup"
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])

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
	gen_option.name = "BoostGeneralOption"
	for char_id in characters:
		var c: Dictionary = characters[char_id]
		var loyalty: float = float(c.get("loyalty", 50))
		gen_option.add_item("%s (忠诚度: %.0f)" % [MainMenuFormattersLib.character_display_name(characters, String(char_id)), loyalty])
		gen_option.set_item_metadata(gen_option.item_count - 1, char_id)
	vbox.add_child(gen_option)

	var btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.name = "BoostConfirmButton"
	confirm_btn.text = "确认接见"
	confirm_btn.disabled = legitimacy < 10.0
	confirm_btn.pressed.connect(_confirm_boost.bind(gen_option))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "BoostCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_dismiss_boost_popup)
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
		_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])
		if not _has_callback(CALLBACK_SUBMIT_ACTION):
			battle_confirmed.emit(general_id, troops, terrain)


func _confirm_boost(gen_opt: OptionButton) -> void:
	var general_id: String = gen_opt.get_item_metadata(gen_opt.selected)
	_close_boost_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [false])
	var payload := {"general_id": general_id}
	if not _call_optional(CALLBACK_SUBMIT_ACTION, [ACTION_BOOST_LOYALTY, payload]):
		_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])
		if not _has_callback(CALLBACK_SUBMIT_ACTION):
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


func _close_info_popup() -> void:
	_close_popup(_info_popup)
	_info_popup = null


func _dismiss_battle_popup() -> void:
	_close_battle_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])


func _dismiss_boost_popup() -> void:
	_close_boost_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])


func _dismiss_info_popup() -> void:
	_close_info_popup()
	_call_optional(CALLBACK_SET_TRAY_INTERACTIVE, [true])


func _call_optional(callback_name: String, args: Array = []) -> bool:
	var callback: Variant = _callbacks.get(callback_name, Callable())
	if callback is Callable and callback.is_valid():
		var result: Variant = (callback as Callable).callv(args)
		if result is bool:
			return bool(result)
		return true
	return false


func _has_callback(callback_name: String) -> bool:
	var callback: Variant = _callbacks.get(callback_name, Callable())
	return callback is Callable and callback.is_valid()


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
