## CharacterManager — 将领忠诚度网络管理器

class_name CharacterManager
extends Node

var _order_deviation: OrderDeviation
var _march_system: MarchSystem  # 用于计算通信距离

func _ready() -> void:
	_order_deviation = OrderDeviation.new()

func initialize_march_system(march_sys: MarchSystem) -> void:
	_march_system = march_sys

# ── 命令处理 ──────────────────────────────────────────

## 处理一批军事命令（含偏差计算）
func process_orders_with_deviation(orders: Array) -> Array:
	var results: Array = []
	for order in orders:
		var char_id: String = order.get("character_id", "")
		if not char_id in GameState.characters:
			continue

		var character: Dictionary = GameState.characters[char_id]
		var distance := _calculate_communication_distance(char_id)
		var chaos := _estimate_battlefield_chaos()

		var deviation := _order_deviation.calculate(order, character, distance, chaos)

		if not deviation["order_followed"]:
			EventBus.order_deviation_occurred.emit(char_id, order.get("id", ""), deviation)

		results.append({
			"order": order,
			"deviation": deviation,
			"character_name": character.get("name", char_id)
		})

	return results

## 计算将领与拿破仑司令部的通信距离（节点数）
func _calculate_communication_distance(char_id: String) -> int:
	if not _march_system:
		return 0
	var char_location: String = GameState.characters[char_id].get("current_location",
		GameState.characters[char_id].get("starting_location", "paris"))
	return _march_system.get_distance(GameState.napoleon_location, char_location)

## 估算当前战场混乱度（基于当日是否有战斗）
func _estimate_battlefield_chaos() -> float:
	# 简化：Day 86-100（比利时战役）混乱度更高
	var day := GameState.current_day
	if day >= 86:
		return 0.7
	elif day >= 80:
		return 0.4
	elif day <= 20:
		return 0.2  # 北上阶段基本无战斗
	return 0.3

# ── 忠诚度网络更新 ────────────────────────────────────

## 每回合更新将领关系和忠诚度
func update_relationships() -> void:
	_apply_daily_loyalty_drift()
	_process_relationship_influences()

func _apply_daily_loyalty_drift() -> void:
	## 每日忠诚度微弱漂移：军事胜利提升，政治危机降低
	var day_factor := 0.0

	# 整体合法性影响
	if GameState.legitimacy > 60.0:
		day_factor += 0.2
	elif GameState.legitimacy < 30.0:
		day_factor -= 0.3

	# 军方支持度影响
	if GameState.faction_support["military"] > 70.0:
		day_factor += 0.1

	for char_id in GameState.characters:
		var char_data: Dictionary = GameState.characters[char_id]
		if char_data.get("role", "") in ["marshal", "general"]:
			GameState.modify_loyalty(char_id, day_factor)

## 将领间关系互相影响忠诚度（简化：某将领叛逃会拉低相关将领）
func _process_relationship_influences() -> void:
	for char_id in GameState.characters:
		var char_data: Dictionary = GameState.characters[char_id]
		var relationships: Dictionary = char_data.get("relationships", {})
		var napoleon_rel: float = float(relationships.get("napoleon", 50))
		# 与拿破仑关系越好，忠诚度恢复越快
		if napoleon_rel > 70 and float(char_data.get("loyalty", 50)) < 70.0:
			GameState.modify_loyalty(char_id, 0.1)

# ── 历史事件触发 ──────────────────────────────────────

## 处理内伊倒戈事件（Day 5-7窗口）
func trigger_ney_defection_window() -> Dictionary:
	if not "ney" in GameState.characters:
		return {"triggered": false}

	var ney_loyalty := GameState.get_loyalty("ney")
	var napoleon_reputation: float = GameState.legitimacy

	# 基础倒戈概率：受当前声望影响
	var defection_chance: float = 0.3 + (napoleon_reputation / 100.0) * 0.5

	# 特殊：如果之前有接触事件提升了关系，概率更高
	if "ney_contacted" in GameState.triggered_events:
		defection_chance += 0.2

	var success := randf() < defection_chance

	if success:
		GameState.modify_loyalty("ney", 20.0)  # 倒戈后忠诚度大幅提升
		GameState.characters["ney"]["current_location"] = "grenoble"
		EventBus.character_joined.emit("ney")
		return {"triggered": true, "success": true, "new_loyalty": GameState.get_loyalty("ney")}
	else:
		# 内伊未倒戈，成为威胁
		GameState.modify_loyalty("ney", -10.0)
		return {"triggered": true, "success": false}

## 处理格鲁希任命（Day 85-90窗口）
func trigger_grouchy_appointment(appoint: bool) -> Dictionary:
	if not "grouchy" in GameState.characters:
		return {}

	if appoint:
		GameState.characters["grouchy"]["role"] = "field_commander"
		GameState.characters["grouchy"]["assigned_mission"] = "pursue_prussians"
		GameState.modify_loyalty("grouchy", 5.0)
		return {
			"appointed": true,
			"warning": "格鲁希的谨慎性格意味着他会严格执行命令——即使听到滑铁卢的炮声。",
			"risk_level": "high"
		}
	return {"appointed": false}

# ── 查询方法 ──────────────────────────────────────────

## 获取忠诚度低于阈值的将领（用于情报阶段警告）
func get_at_risk_characters() -> Array:
	var at_risk: Array = []
	for char_id in GameState.characters:
		var loyalty := GameState.get_loyalty(char_id)
		if loyalty < GameState.DEFECTION_LOYALTY_THRESHOLD:
			at_risk.append({
				"id": char_id,
				"name": GameState.characters[char_id].get("name", char_id),
				"loyalty": loyalty,
				"risk": "defection"
			})
	return at_risk

## 获取所有可指挥将领列表
func get_available_commanders() -> Array:
	var commanders: Array = []
	for char_id in GameState.characters:
		var char_data: Dictionary = GameState.characters[char_id]
		if char_data.get("role", "") in ["marshal", "general"]:
			var avail_from: int = char_data.get("available_from_day", 1)
			if GameState.current_day >= avail_from:
				commanders.append({
					"id": char_id,
					"name": char_data.get("name", char_id),
					"loyalty": GameState.get_loyalty(char_id),
					"military_skill": char_data.get("military_skill", 50),
					"temperament": char_data.get("temperament", "balanced")
				})
	return commanders
