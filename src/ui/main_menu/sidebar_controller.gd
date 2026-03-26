extends RefCounted
class_name MainMenuSidebarController

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")

const DEFAULT_VISIBLE_LOYALTY_COUNT := 6
const DEFAULT_NARRATIVE_TEXT := "Day 1 - Elba departure\n\nChoose an action; history will unfold here."
const POLICY_PREVIEW_COLOR := CentJoursTheme.COLOR["text_secondary"]
const SPECIAL_POLICY_PREVIEW_TEXTS := {
	"rest": "休整 · 养精蓄锐\n\n让军队获得喘息之机，为下一步行动积蓄力量。",
	"march": "行军部署\n\n选择一个与当前位置相邻的节点，确认后推进一天并同步拿破仑位置。前线低容量节点会明显拉高补给压力。",
	"battle": "发动战役\n\n选择将领和兵力，与反法联军决战。点击确认后选择参数。",
	"boost_loyalty": "亲自接见将领\n\n消耗 5 合法性，目标将领忠诚度 +8。需合法性 >= 10。"
}
const FACTION_ORDER := ["military", "populace", "liberals", "nobility"]
const EVENT_TIER_LABELS := {
	"major": "重大史事",
	"normal": "历史事件",
	"minor": "历史片段"
}
const ACTION_EVENT_LABELS := {
	"policy": "政策结算",
	"policy_failed": "政策受阻",
	"battle": "战役结算",
	"march": "行军结算",
	"march_failed": "行军受阻",
	"supply": "补给结算",
	"boost_loyalty": "将领关系",
	"boost_failed": "关系经营受阻",
	"rest": "休整结算"
}
const LOYALTY_VALUE_WIDTH := 126.0
const LOYALTY_MIN_NAME_WIDTH := 96.0
const LOYALTY_MIN_ROW_WIDTH := 228.0
const NARRATIVE_SEPARATOR := "\n-----\n"

var _situation_body: Label = null
var _loyalty_list: VBoxContainer = null
var _narrative_body: Label = null

var _loyalty_visible_limit: int = DEFAULT_VISIBLE_LOYALTY_COUNT
var _loyalty_overflow_template: String = "…another %d officers"
var _narrative_log: Array[String] = []
var _narrative_preview_text: String = ""
var _narrative_preview_color: Color = CentJoursTheme.COLOR["text_secondary"]
var _narrative_log_color: Color = CentJoursTheme.COLOR["text_primary"]

func bind(situation_body: Label, loyalty_list: VBoxContainer, narrative_body: Label) -> void:
	_situation_body = situation_body
	_loyalty_list = loyalty_list
	_narrative_body = narrative_body

func unbind() -> void:
	_situation_body = null
	_loyalty_list = null
	_narrative_body = null
	_narrative_log.clear()
	_narrative_preview_text = ""

func set_loyalty_visible_limit(value: int) -> void:
	_loyalty_visible_limit = max(1, value)

func set_loyalty_overflow_template(template: String) -> void:
	if template.strip_edges() != "":
		_loyalty_overflow_template = template

func reset_narrative(initial_text: String = DEFAULT_NARRATIVE_TEXT, color: Color = CentJoursTheme.COLOR["text_secondary"]) -> void:
	_narrative_log.clear()
	_narrative_preview_text = initial_text
	_narrative_preview_color = color
	_narrative_log_color = CentJoursTheme.COLOR["text_primary"]
	_render_narrative()

func set_narrative_text(text: String, color: Color = CentJoursTheme.COLOR["text_secondary"]) -> void:
	_narrative_preview_text = text
	_narrative_preview_color = color
	_render_narrative()

func set_policy_preview(policy_id: String, policy_meta: Dictionary = {}, color: Color = POLICY_PREVIEW_COLOR) -> void:
	set_narrative_text(build_policy_preview_text(policy_id, policy_meta), color)

func build_policy_preview_text(policy_id: String, policy_meta: Dictionary = {}) -> String:
	var normalized_policy_id := String(policy_id)
	if SPECIAL_POLICY_PREVIEW_TEXTS.has(normalized_policy_id):
		if normalized_policy_id == "rest":
			return _build_rest_preview_text()
		return String(SPECIAL_POLICY_PREVIEW_TEXTS[normalized_policy_id])
	if normalized_policy_id == "requisition_supplies":
		return _build_requisition_preview_text(policy_meta)
	if normalized_policy_id == "stabilize_supply_lines":
		return _build_supply_line_preview_text(policy_meta)
	if normalized_policy_id == "establish_forward_depot":
		return _build_forward_depot_preview_text(policy_meta)
	if normalized_policy_id == "secure_regional_corridor":
		return _build_regional_corridor_preview_text(policy_meta)

	var policy_name := String(policy_meta.get("name", normalized_policy_id))
	var policy_summary := String(policy_meta.get("summary", "等待结算…"))
	return "▷ %s\n\n%s" % [policy_name, policy_summary]


func _build_rest_preview_text() -> String:
	var guidance := "当前以恢复疲劳和士气为主。"
	if GameState.supply < 45.0:
		guidance = "当前补给已经偏低，单纯休整的恢复会打折。若还要继续推进，先补补给更稳。"
	elif GameState.current_day <= 10:
		guidance = "前 10 天更适合把休整当作节奏控制，而不是长期停顿。看下一站仓储再决定是否继续赶路。"
	return "休整 · 养精蓄锐\n\n让军队获得喘息之机，为下一步行动积蓄力量。\n%s\n%s" % [
		guidance,
		_build_policy_recommendation_line("rest")
	]


func _build_requisition_preview_text(policy_meta: Dictionary) -> String:
	var policy_name := String(policy_meta.get("name", "征用沿线仓储"))
	var summary := String(policy_meta.get("summary", "快速回补补给，代价是激怒沿线民众与自由派"))
	var guidance := ""
	if GameState.supply < 45.0:
		guidance = "适用：补给已进危险区，且你还得继续行军或准备接战。它是止血按钮，不适合当常规维护。"
	elif GameState.supply < 60.0:
		guidance = "适用：补给开始吃紧，下一站又不是高容量节点时。"
	else:
		guidance = "当前补给还顶得住。更适合把它留到前线连续推进、库存跌到 45-60 之间时再用。"
	if GameState.current_day <= 10:
		guidance += "\n前 10 天不要太早把这张牌交掉，除非你已经决定连续北上。"
	return "▷ %s\n\n%s\n\n当前补给 %.0f。\n%s\n%s" % [
		policy_name,
		summary,
		GameState.supply,
		guidance,
		_build_policy_recommendation_line("requisition_supplies")
	]


func _build_supply_line_preview_text(policy_meta: Dictionary) -> String:
	var policy_name := String(policy_meta.get("name", "整顿驿站运输"))
	var summary := String(policy_meta.get("summary", "短期整顿运输线，立刻小幅回补补给，并在接下来数日提高补给线效率"))
	var guidance := ""
	if GameState.supply < 45.0:
		guidance = "适用：如果已经跌进危险区，通常应先用征用仓储止血；这张牌更适合在还没断供前提前保线。"
	elif GameState.current_day <= 10:
		guidance = "适用：前 10 天连续北上前先把运输线整顿好。它更像是为了连续两三天推进提前铺路。"
	else:
		guidance = "适用：你准备连续推进、又不想每次都靠征用仓储硬撑时。它解决的是补给线效率，不是一次性大回补。"
	return "▷ %s\n\n%s\n\n当前补给 %.0f。\n%s\n%s" % [
		policy_name,
		summary,
		GameState.supply,
		guidance,
		_build_policy_recommendation_line("stabilize_supply_lines")
	]


func _build_forward_depot_preview_text(policy_meta: Dictionary) -> String:
	var policy_name := String(policy_meta.get("name", "建立前沿粮秣站"))
	var summary := String(policy_meta.get("summary", "在当前驻地建立临时粮秣站，立刻小幅回补补给，并在接下来数日提高该节点的本地仓储容量"))
	var guidance := "适用：准备把当前节点当作两到三天的前线跳板时。它补的是本地仓储，不是整条补给线。"
	if GameState.forward_depot_days > 0 and GameState.forward_depot_location == GameState.napoleon_location:
		guidance = "当前驻地已经有前沿粮秣站，剩余 %d 天。更好的选择通常是利用这几天的窗口把补给和疲劳拉回来，而不是重复铺站。" % GameState.forward_depot_days
	elif GameState.supply < 45.0:
		guidance = "当前补给已进危险区。若马上就要断供，通常先用征用仓储止血；粮秣站更适合在还能站稳时提前铺设。"
	elif GameState.current_day <= 10:
		guidance = "前 10 天若准备连续北上，这张牌适合放在中等容量节点，把它变成临时整补跳板。"
	return "▷ %s\n\n%s\n\n当前补给 %.0f。\n%s\n%s" % [
		policy_name,
		summary,
		GameState.supply,
		guidance,
		_build_policy_recommendation_line("establish_forward_depot")
	]


func _build_regional_corridor_preview_text(policy_meta: Dictionary) -> String:
	var policy_name := String(policy_meta.get("name", "巩固区域走廊"))
	var summary := String(policy_meta.get("summary", "同步保线并加固当前驻地，把一段脆弱路线先稳成可持续走廊"))
	var guidance := "适用：当前区域走廊开始承压时，用一张牌同时保线、补位和加固当前中继节点。"
	if GameState.logistics_regional_pressure_id == "corridor_breaking":
		guidance = "适用：当前走廊已经压到临界线。这张牌比单纯保线或单点铺站更适合先把整段线路救回来。"
	elif GameState.logistics_regional_pressure_id == "corridor_fragile":
		guidance = "适用：当前只剩很窄的安全承接。先补强这一段，再把后续两跳接完整。"
	elif GameState.logistics_regional_pressure_id == "corridor_stabilizing":
		guidance = "适用：当前走廊已经在稳住中，用它能把现有窗口拉得更长，避免下一跳又重新断开。"
	elif GameState.logistics_regional_pressure_id == "corridor_secure":
		guidance = "当前走廊已经够稳，这张牌可以留到下一次线路变脆时再打。"
	return "▷ %s\n\n%s\n\n当前补给 %.0f。\n%s\n%s" % [
		policy_name,
		summary,
		GameState.supply,
		guidance,
		_build_policy_recommendation_line("secure_regional_corridor")
	]


func _build_policy_recommendation_line(policy_id: String) -> String:
	var recommendation := _policy_recommendation(policy_id)
	var label := String(recommendation.get("label", "可考虑"))
	var reason := String(recommendation.get("reason", "当前没有额外提示。"))
	return "当前建议：%s。%s" % [label, reason]


func _policy_recommendation(policy_id: String) -> Dictionary:
	match policy_id:
		"rest":
			if GameState.supply < 45.0:
				return {"label": "暂缓", "reason": "补给已跌进危险区，先止血再休整更稳。"}
			if GameState.logistics_runway_days == 1 or GameState.avg_fatigue >= 55.0:
				return {"label": "优先", "reason": "再硬顶一天就可能掉进惩罚区，先把疲劳和节奏拉回来。"}
			return {"label": "可考虑", "reason": "它适合在跳板节点上重置节奏，但不该取代补给动作。 "}
		"requisition_supplies":
			if GameState.supply < 45.0 or GameState.logistics_runway_days == 0:
				return {"label": "优先", "reason": "现在最缺的是立刻止血；再拖一回合，战斗和休整都会吃惩罚。"}
			if GameState.supply < 60.0 and GameState.logistics_objective_target_role == "frontline_outpost":
				return {"label": "优先", "reason": "你还要为前线点付补给代价，这张牌应该留给这种硬顶时刻。"}
			return {"label": "暂缓", "reason": "库存还没逼到危险区，这张牌更适合留作止血按钮。"}
		"stabilize_supply_lines":
			if GameState.logistics_posture_label == "运输线拉长":
				return {"label": "优先", "reason": "你现在输在运输线，不是单次库存不足；先把线效率提起来。"}
			if GameState.current_day <= 10 and GameState.supply >= 45.0:
				return {"label": "优先", "reason": "前 10 天若准备连续北上，先保线比事后补洞更稳。"}
			if GameState.supply < 45.0:
				return {"label": "暂缓", "reason": "已经跌进危险区时，它通常不如征用仓储直接。"}
			return {"label": "可考虑", "reason": "它适合为接下来两三天连续推进提前铺路。"}
		"establish_forward_depot":
			if GameState.forward_depot_days > 0 and GameState.forward_depot_location == GameState.napoleon_location:
				return {"label": "暂缓", "reason": "当前驻地已有粮秣站，重复铺站收益低。"}
			if GameState.logistics_objective_target_role == "regional_depot" and GameState.current_day <= 10:
				return {"label": "优先", "reason": "你正需要把中容量节点变成整补跳板，这张牌最契合当前目标。"}
			if GameState.supply < 45.0:
				return {"label": "可考虑", "reason": "它能帮下一两天，但立刻止血仍更依赖征用仓储。"}
			return {"label": "可考虑", "reason": "当你准备在当前节点停两三天时，它比单纯赶路更稳。"}
		"secure_regional_corridor":
			if GameState.logistics_regional_pressure_id == "corridor_breaking":
				return {"label": "优先", "reason": "当前整段走廊都在承压，这张牌最适合先把中继线救回来。"}
			if GameState.logistics_regional_pressure_id == "corridor_fragile":
				return {"label": "优先", "reason": "现在输在整段线路太脆，不只是某一个节点缺补给。"}
			if GameState.logistics_regional_pressure_id == "corridor_stabilizing":
				return {"label": "可考虑", "reason": "当前已经在稳线，用它可以把窗口再拉长一截。"}
			return {"label": "暂缓", "reason": "当前区域走廊还顶得住，这张牌更适合留到线路变脆时再打。"}
		_:
			return {"label": "可考虑", "reason": "当前没有额外提示。"}

func append_narrative(entry: String, color: Color = CentJoursTheme.COLOR["text_primary"]) -> void:
	_narrative_preview_text = ""
	_narrative_log_color = color
	_narrative_log.push_front(entry)
	if _narrative_log.size() > MainMenuConfigData.NARRATIVE_MAX_ENTRIES:
		_narrative_log.pop_back()
	_render_narrative()

## 历史事件日志同时保留随机叙事和史注，帮助玩家区分氛围文本与史实说明。
func build_historical_event_entry(event_id: String, event_data: Dictionary = {}) -> String:
	var label := String(event_data.get("label", event_id))
	var tier := String(event_data.get("tier", "normal"))
	var narrative := String(event_data.get("narrative", "")).strip_edges()
	var historical_note := String(event_data.get("historical_note", "")).strip_edges()
	var header := "◆ [%s] %s" % [EVENT_TIER_LABELS.get(tier, "历史事件"), label]

	var sections: Array[String] = [header]
	if narrative != "":
		sections.append(narrative)
	if historical_note != "":
		sections.append("史注\n%s" % historical_note)
	return "\n\n".join(sections)

func build_action_resolution_entry(
	event_type: String,
	description: String,
	effects: Array = []
) -> String:
	var header := "● [%s]" % ACTION_EVENT_LABELS.get(event_type, "行动结算")
	var sections: Array[String] = [header]
	var normalized_description := description.strip_edges()
	if normalized_description != "":
		sections.append(normalized_description)

	var effect_lines: Array[String] = []
	for effect_variant in effects:
		var effect_text := String(effect_variant).strip_edges()
		if effect_text != "":
			effect_lines.append("- %s" % effect_text)
	if not effect_lines.is_empty():
		sections.append("影响\n%s" % "\n".join(effect_lines))

	return "\n\n".join(sections)

func refresh_situation(
	phase_id: String,
	napoleon_location_label: String,
	legitimacy: float,
	supply: float,
	fatigue: float,
	logistics_runway_label: String,
	logistics_posture_label: String,
	logistics_focus_title: String,
	logistics_focus_detail: String,
	logistics_objective_label: String,
	logistics_objective_detail: String,
	logistics_action_plan_title: String,
	logistics_action_plan_detail: String,
	logistics_tempo_plan_title: String,
	logistics_tempo_plan_detail: String,
	logistics_route_chain_title: String,
	logistics_route_chain_detail: String,
	logistics_regional_pressure_title: String,
	logistics_regional_pressure_detail: String,
	logistics_regional_task_title: String,
	logistics_regional_task_detail: String,
	logistics_regional_task_progress_label: String,
	logistics_regional_task_reward_label: String,
	faction_support: Dictionary,
	prev_faction_support: Dictionary
) -> void:
	if _situation_body == null:
		return

	var faction_lines: Array[String] = []
	for faction_id in FACTION_ORDER:
		var support := float(faction_support.get(faction_id, 0.0))
		var prev := float(prev_faction_support.get(faction_id, support))
		var arrow := _trend_arrow(support - prev)
		faction_lines.append("  %s %s %.0f %s" % [
			_faction_emoji(faction_id),
			MainMenuConfigData.FACTION_LABELS.get(faction_id, faction_id),
			support,
			arrow
		])

	var logistics_lines: Array[String] = []
	if logistics_posture_label.strip_edges() != "":
		logistics_lines.append("后勤态势 · %s" % logistics_posture_label)
	if logistics_runway_label.strip_edges() != "":
		logistics_lines.append(logistics_runway_label)
	if logistics_focus_title.strip_edges() != "":
		logistics_lines.append(logistics_focus_title)
	if logistics_focus_detail.strip_edges() != "":
		logistics_lines.append(logistics_focus_detail)
	if logistics_objective_label.strip_edges() != "":
		logistics_lines.append(logistics_objective_label)
	if logistics_objective_detail.strip_edges() != "":
		logistics_lines.append(logistics_objective_detail)
	if logistics_action_plan_title.strip_edges() != "":
		logistics_lines.append(logistics_action_plan_title)
	if logistics_action_plan_detail.strip_edges() != "":
		logistics_lines.append(logistics_action_plan_detail)
	if logistics_tempo_plan_title.strip_edges() != "":
		logistics_lines.append(logistics_tempo_plan_title)
	if logistics_tempo_plan_detail.strip_edges() != "":
		logistics_lines.append(logistics_tempo_plan_detail)
	if logistics_route_chain_title.strip_edges() != "":
		logistics_lines.append(logistics_route_chain_title)
	if logistics_route_chain_detail.strip_edges() != "":
		logistics_lines.append(logistics_route_chain_detail)
	if logistics_regional_pressure_title.strip_edges() != "":
		logistics_lines.append(logistics_regional_pressure_title)
	if logistics_regional_pressure_detail.strip_edges() != "":
		logistics_lines.append(logistics_regional_pressure_detail)
	if logistics_regional_task_title.strip_edges() != "":
		logistics_lines.append(logistics_regional_task_title)
	if logistics_regional_task_detail.strip_edges() != "":
		logistics_lines.append(logistics_regional_task_detail)
	elif logistics_regional_task_progress_label.strip_edges() != "" or logistics_regional_task_reward_label.strip_edges() != "":
		if logistics_regional_task_progress_label.strip_edges() != "":
			logistics_lines.append(logistics_regional_task_progress_label)
		if logistics_regional_task_reward_label.strip_edges() != "":
			logistics_lines.append(logistics_regional_task_reward_label)

	_situation_body.text = "%s\n%s · Legitimacy %.1f\n补给 %.0f · 疲劳 %.0f\n\n%s\n\n%s" % [
		MainMenuFormattersLib.phase_display_name(phase_id),
		napoleon_location_label,
		legitimacy,
		supply,
		fatigue,
		"\n".join(logistics_lines),
		"\n".join(faction_lines)
	]
	_situation_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_primary"])

func refresh_loyalty(
	characters: Dictionary,
	content_width: float = -1.0,
	max_visible: int = -1
) -> void:
	if _loyalty_list == null:
		return

	var limit: int = _loyalty_visible_limit if max_visible <= 0 else max(1, max_visible)
	_clear_container(_loyalty_list)

	var all_ids: Array = characters.keys()
	all_ids.sort_custom(func(a, b): return _character_loyalty(characters, a) > _character_loyalty(characters, b))

	var visible_ids: Array = all_ids.slice(0, limit)
	var hidden_count: int = all_ids.size() - visible_ids.size()
	var row_width := _resolve_loyalty_row_width(content_width)

	for hero_id in visible_ids:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.x = row_width

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = maxf(row_width - LOYALTY_VALUE_WIDTH, LOYALTY_MIN_NAME_WIDTH)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.text = MainMenuFormattersLib.character_display_name(characters, String(hero_id))
		name_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
		row.add_child(name_label)

		var loyalty := _character_loyalty(characters, hero_id)
		var value_label := Label.new()
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		value_label.custom_minimum_size = Vector2(LOYALTY_VALUE_WIDTH, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = "%.0f · %s" % [loyalty, CentJoursTheme.get_loyalty_label(loyalty)]
		value_label.add_theme_color_override("font_color", CentJoursTheme.get_loyalty_color(loyalty))
		row.add_child(value_label)

		_loyalty_list.add_child(row)

	if hidden_count > 0:
		var overflow := Label.new()
		overflow.text = _loyalty_overflow_template % hidden_count
		overflow.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		_loyalty_list.add_child(overflow)

func refresh_all(
	phase_id: String,
	napoleon_location_label: String,
	legitimacy: float,
	supply: float,
	fatigue: float,
	logistics_runway_label: String,
	logistics_posture_label: String,
	logistics_focus_title: String,
	logistics_focus_detail: String,
	logistics_objective_label: String,
	logistics_objective_detail: String,
	logistics_action_plan_title: String,
	logistics_action_plan_detail: String,
	logistics_tempo_plan_title: String,
	logistics_tempo_plan_detail: String,
	logistics_route_chain_title: String,
	logistics_route_chain_detail: String,
	logistics_regional_pressure_title: String,
	logistics_regional_pressure_detail: String,
	logistics_regional_task_title: String,
	logistics_regional_task_detail: String,
	logistics_regional_task_progress_label: String,
	logistics_regional_task_reward_label: String,
	faction_support: Dictionary,
	prev_faction_support: Dictionary,
	characters: Dictionary,
	content_width: float = -1.0,
	max_visible: int = -1
) -> void:
	refresh_situation(
		phase_id,
		napoleon_location_label,
		legitimacy,
		supply,
		fatigue,
		logistics_runway_label,
		logistics_posture_label,
		logistics_focus_title,
		logistics_focus_detail,
		logistics_objective_label,
		logistics_objective_detail,
		logistics_action_plan_title,
		logistics_action_plan_detail,
		logistics_tempo_plan_title,
		logistics_tempo_plan_detail,
		logistics_route_chain_title,
		logistics_route_chain_detail,
		logistics_regional_pressure_title,
		logistics_regional_pressure_detail,
		logistics_regional_task_title,
		logistics_regional_task_detail,
		logistics_regional_task_progress_label,
		logistics_regional_task_reward_label,
		faction_support,
		prev_faction_support
	)
	refresh_loyalty(characters, content_width, max_visible)

func _resolve_loyalty_row_width(content_width: float) -> float:
	if content_width > 0.0:
		return content_width
	if _loyalty_list != null and _loyalty_list.size.x > 0.0:
		return _loyalty_list.size.x
	if _loyalty_list != null and _loyalty_list.custom_minimum_size.x > 0.0:
		return _loyalty_list.custom_minimum_size.x
	return LOYALTY_MIN_ROW_WIDTH

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _render_narrative() -> void:
	if _narrative_body == null:
		return

	var sections: Array[String] = []
	if _narrative_preview_text.strip_edges() != "":
		sections.append(_narrative_preview_text)
	if not _narrative_log.is_empty():
		sections.append(NARRATIVE_SEPARATOR.join(_narrative_log))

	if sections.is_empty():
		_narrative_body.text = DEFAULT_NARRATIVE_TEXT
		_narrative_body.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_secondary"])
		return

	_narrative_body.text = NARRATIVE_SEPARATOR.join(sections)
	var color := _narrative_preview_color if _narrative_log.is_empty() else _narrative_log_color
	_narrative_body.add_theme_color_override("font_color", color)

func _trend_arrow(delta: float) -> String:
	if delta > 1.0:
		return "↑"
	elif delta < -1.0:
		return "↓"
	return "→"

func _faction_emoji(faction_id: String) -> String:
	match faction_id:
		"military":
			return "⚔"
		"populace":
			return "👥"
		"liberals":
			return "⚖"
		"nobility":
			return "👑"
		_:
			return "·"

func _character_loyalty(characters: Dictionary, hero_id: String) -> float:
	var char_data: Dictionary = characters.get(hero_id, {})
	return float(char_data.get("loyalty", 50.0))
