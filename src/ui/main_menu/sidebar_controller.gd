extends RefCounted
class_name MainMenuSidebarController

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")
const MainMenuFormattersLib = preload("res://src/ui/main_menu/ui_formatters.gd")

const DEFAULT_VISIBLE_LOYALTY_COUNT := 6
const DEFAULT_NARRATIVE_TEXT := "Day 1 - Elba departure\n\nChoose an action; history will unfold here."
const POLICY_PREVIEW_COLOR := CentJoursTheme.COLOR["text_secondary"]
const SPECIAL_POLICY_PREVIEW_TEXTS := {
	"rest": "休整 · 养精蓄锐\n\n让军队获得喘息之机，为下一步行动积蓄力量。",
	"march": "行军部署\n\n选择一个与当前位置相邻的节点，确认后推进一天并同步拿破仑位置。",
	"battle": "发动战役\n\n选择将领和兵力，与反法联军决战。点击确认后选择参数。",
	"boost_loyalty": "亲自接见将领\n\n消耗 5 合法性，目标将领忠诚度 +8。需合法性 >= 10。"
}
const FACTION_ORDER := ["military", "populace", "liberals", "nobility"]
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

func bind(situation_body: Label, loyalty_list: VBoxContainer, narrative_body: Label) -> void:
	_situation_body = situation_body
	_loyalty_list = loyalty_list
	_narrative_body = narrative_body

func unbind() -> void:
	_situation_body = null
	_loyalty_list = null
	_narrative_body = null
	_narrative_log.clear()

func set_loyalty_visible_limit(value: int) -> void:
	_loyalty_visible_limit = max(1, value)

func set_loyalty_overflow_template(template: String) -> void:
	if template.strip_edges() != "":
		_loyalty_overflow_template = template

func reset_narrative(initial_text: String = DEFAULT_NARRATIVE_TEXT, color: Color = CentJoursTheme.COLOR["text_secondary"]) -> void:
	_narrative_log.clear()
	if _narrative_body == null:
		return
	_narrative_body.text = initial_text
	_narrative_body.add_theme_color_override("font_color", color)

func set_narrative_text(text: String, color: Color = CentJoursTheme.COLOR["text_secondary"]) -> void:
	_narrative_log.clear()
	if _narrative_body == null:
		return
	_narrative_body.text = text
	_narrative_body.add_theme_color_override("font_color", color)

func set_policy_preview(policy_id: String, policy_meta: Dictionary = {}, color: Color = POLICY_PREVIEW_COLOR) -> void:
	set_narrative_text(build_policy_preview_text(policy_id, policy_meta), color)

func build_policy_preview_text(policy_id: String, policy_meta: Dictionary = {}) -> String:
	var normalized_policy_id := String(policy_id)
	if SPECIAL_POLICY_PREVIEW_TEXTS.has(normalized_policy_id):
		return String(SPECIAL_POLICY_PREVIEW_TEXTS[normalized_policy_id])

	var policy_name := String(policy_meta.get("name", normalized_policy_id))
	var policy_summary := String(policy_meta.get("summary", "等待结算…"))
	return "▷ %s\n\n%s" % [policy_name, policy_summary]

func append_narrative(entry: String, color: Color = CentJoursTheme.COLOR["text_primary"]) -> void:
	_narrative_log.push_front(entry)
	if _narrative_log.size() > MainMenuConfigData.NARRATIVE_MAX_ENTRIES:
		_narrative_log.pop_back()
	if _narrative_body == null:
		return
	_narrative_body.text = NARRATIVE_SEPARATOR.join(_narrative_log)
	_narrative_body.add_theme_color_override("font_color", color)

func refresh_situation(
	phase_id: String,
	napoleon_location_label: String,
	legitimacy: float,
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

	_situation_body.text = "%s\n%s · Legitimacy %.1f\n\n%s" % [
		MainMenuFormattersLib.phase_display_name(phase_id),
		napoleon_location_label,
		legitimacy,
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
	faction_support: Dictionary,
	prev_faction_support: Dictionary,
	characters: Dictionary,
	content_width: float = -1.0,
	max_visible: int = -1
) -> void:
	refresh_situation(phase_id, napoleon_location_label, legitimacy, faction_support, prev_faction_support)
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
