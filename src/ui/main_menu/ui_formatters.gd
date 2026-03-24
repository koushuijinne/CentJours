extends RefCounted
class_name MainMenuFormatters

static func phase_display_name(phase_id: String) -> String:
	match phase_id:
		"dawn":
			return "Aube · 情报阶段"
		"action":
			return "Action · 决策阶段"
		"dusk":
			return "Crepuscule · 结算阶段"
		_:
			return phase_id.capitalize()

static func character_display_name(characters: Dictionary, hero_id: String) -> String:
	var char_data: Dictionary = characters.get(hero_id, {})
	return String(char_data.get("display_name", char_data.get("name", hero_id.capitalize())))

static func napoleon_location_label(map_nodes: Array, napoleon_location: String) -> String:
	for node_info in map_nodes:
		if String(node_info.get("id", "")) == String(napoleon_location):
			return String(node_info.get("name_fr", node_info.get("name", "Unknown")))
	return String(napoleon_location)

static func humanize_token(token: String) -> String:
	return token.replace("_", " ").capitalize()

static func format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(abs(value))
	var parts: Array[String] = []
	while digits.length() > 3:
		parts.push_front(digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.push_front(digits)
	var formatted := ",".join(parts)
	return "-" + formatted if negative else formatted
