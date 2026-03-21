## CharacterManager — 将领状态查询层（v2）
## 执行逻辑已移至 CentJoursEngine（Rust）
## 本脚本只提供 UI 所需的将领列表和风险查询

# 注意：此脚本不再声明全局 class_name，
# 避免与 Rust GDExtension 注册的原生 CharacterManager 类重名。
extends Node

# ── 查询方法（供 UI 和 TurnManager 调用）──────────────────

## 获取忠诚度低于阈值的将领（供情报阶段 Dawn UI 警告）
func get_at_risk_characters() -> Array:
	var at_risk: Array = []
	for char_id in GameState.characters:
		var loyalty := GameState.get_loyalty(char_id)
		if loyalty < GameState.DEFECTION_LOYALTY_THRESHOLD:
			at_risk.append({
				"id":      char_id,
				"name":    GameState.characters[char_id].get("name", char_id),
				"loyalty": loyalty,
				"risk":    "defection"
			})
	return at_risk

## 获取当前可指挥的将领列表（供行动阶段 UI 选择）
func get_available_commanders() -> Array:
	var commanders: Array = []
	for char_id in GameState.characters:
		var char_data: Dictionary = GameState.characters[char_id]
		if char_data.get("role", "") in ["marshal", "general"]:
			var avail_from: int = char_data.get("available_from_day", 1)
			if GameState.current_day >= avail_from:
				commanders.append({
					"id":             char_id,
					"name":           char_data.get("name", char_id),
					"loyalty":        GameState.get_loyalty(char_id),
					"military_skill": char_data.get("military_skill", 50),
					"temperament":    char_data.get("temperament", "balanced")
				})
	return commanders

## 获取指定将领的展示数据（供详情 UI）
func get_character_display(char_id: String) -> Dictionary:
	if not char_id in GameState.characters:
		return {}
	var char_data: Dictionary = GameState.characters[char_id]
	return {
		"id":             char_id,
		"name":           char_data.get("name", char_id),
		"loyalty":        GameState.get_loyalty(char_id),
		"military_skill": char_data.get("military_skill", 50),
		"temperament":    char_data.get("temperament", "balanced"),
		"role":           char_data.get("role", ""),
		"is_at_risk":     GameState.get_loyalty(char_id) < GameState.DEFECTION_LOYALTY_THRESHOLD
	}
