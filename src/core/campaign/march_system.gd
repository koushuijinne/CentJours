## MarchSystem — 行军系统
## 管理军队移动、强行军、疲劳、补给

class_name MarchSystem
extends RefCounted

# ── 常量 ──────────────────────────────────────────────
const BASE_MOVEMENT: int = 1          # 普通行军：每回合移动1个节点
const FORCED_MARCH_BONUS: int = 1     # 强行军额外移动力
const FORCED_MARCH_FATIGUE: float = 20.0    # 强行军疲劳增加
const FORCED_MARCH_MORALE: float = -10.0   # 强行军士气损失
const NORMAL_FATIGUE_RECOVERY: float = 15.0  # 普通行军疲劳恢复
const REST_FATIGUE_RECOVERY: float = 30.0    # 驻扎疲劳恢复
const SUPPLY_CONSUMPTION_RATE: float = 0.1   # 每天基础补给消耗（比例）

# ── 地图数据缓存 ──────────────────────────────────────
var _map_graph: Dictionary = {}   # node_id -> {connections: [...], supply_capacity: int}

func initialize(map_data: Dictionary) -> void:
	for node in map_data.get("nodes", []):
		_map_graph[node["id"]] = node.duplicate(true)

# ── 军队移动 ──────────────────────────────────────────

## 执行行军命令
## army: {id, location, troops, morale, fatigue, supply, general_id}
## target_node: 目标节点 id
## forced: 是否强行军
## 返回 MoveResult 字典
func move_army(army: Dictionary, target_node: String, forced: bool) -> Dictionary:
	var current_node: String = army["location"]

	# 验证移动是否合法
	if not _is_adjacent(current_node, target_node):
		return {"success": false, "reason": "目标节点不相邻"}

	if not _is_node_accessible(target_node):
		return {"success": false, "reason": "目标节点无法到达"}

	# 计算移动代价
	var fatigue_delta: float = 0.0
	var morale_delta: float = 0.0

	if forced:
		fatigue_delta = FORCED_MARCH_FATIGUE
		morale_delta = FORCED_MARCH_MORALE
	else:
		# 普通行军也有轻微疲劳，但会从上次的疲劳中恢复一部分
		fatigue_delta = -NORMAL_FATIGUE_RECOVERY + 5.0  # 净恢复10点

	# 地形行军难度修正
	var terrain_penalty := _get_terrain_march_penalty(target_node)
	fatigue_delta += terrain_penalty

	var new_fatigue := clampf(float(army.get("fatigue", 0)) + fatigue_delta, 0.0, 100.0)
	var new_morale := clampf(float(army.get("morale", 50)) + morale_delta, 0.0, 100.0)

	return {
		"success": true,
		"new_location": target_node,
		"fatigue_delta": fatigue_delta,
		"morale_delta": morale_delta,
		"new_fatigue": new_fatigue,
		"new_morale": new_morale,
		"forced_march": forced
	}

## 驻扎休整（不移动）
func rest_army(army: Dictionary) -> Dictionary:
	var fatigue_recovery := REST_FATIGUE_RECOVERY
	var morale_recovery := 5.0

	# 补给充足时额外恢复
	if float(army.get("supply", 0)) > 50.0:
		fatigue_recovery += 10.0
		morale_recovery += 5.0

	return {
		"fatigue_delta": -fatigue_recovery,
		"morale_delta": morale_recovery,
		"new_fatigue": maxf(0.0, float(army.get("fatigue", 0)) - fatigue_recovery),
		"new_morale": minf(100.0, float(army.get("morale", 50)) + morale_recovery)
	}

# ── 补给管理 ──────────────────────────────────────────

## 更新补给状态
## supply_lines: 连接到补给来源的路径是否畅通
func update_supply(army: Dictionary, supply_lines_intact: bool) -> Dictionary:
	var node_id: String = army.get("location", "")
	var node_capacity: float = float(_map_graph.get(node_id, {}).get("supply_capacity", 1))
	var troops: int = army.get("troops", 0)

	# 需求 vs 供应
	var demand: float = troops * SUPPLY_CONSUMPTION_RATE
	var available: float = node_capacity * (1.0 if supply_lines_intact else 0.3)

	var supply_ok: bool = available >= demand * 0.5
	var supply_delta: float = minf(available, demand) - float(army.get("supply", 50))

	var result := {
		"supply_ok": supply_ok,
		"supply_delta": supply_delta,
		"demand": demand,
		"available": available
	}

	if not supply_ok:
		EventBus.supply_shortage.emit(army.get("id", "unknown"))

	return result

# ── 路径查找（Dijkstra简化版）──────────────────────────

## 找出从起点到终点的最短路径（节点数）
func find_path(from_node: String, to_node: String) -> Array:
	if from_node == to_node:
		return [from_node]

	var visited: Dictionary = {}
	var queue: Array = [[from_node, [from_node]]]

	while queue.size() > 0:
		var current_pair: Array = queue.pop_front()
		var node: String = current_pair[0]
		var path: Array = current_pair[1]

		if node == to_node:
			return path

		if node in visited:
			continue
		visited[node] = true

		var node_data: Dictionary = _map_graph.get(node, {})
		for neighbor in node_data.get("connections", []):
			if not neighbor in visited:
				var new_path: Array = path.duplicate()
				new_path.append(neighbor)
				queue.append([neighbor, new_path])

	return []  # 无路可达

## 计算两点间的节点距离
func get_distance(from_node: String, to_node: String) -> int:
	var path := find_path(from_node, to_node)
	return max(0, path.size() - 1)

# ── 内部辅助 ──────────────────────────────────────────

func _is_adjacent(node_a: String, node_b: String) -> bool:
	var node_data: Dictionary = _map_graph.get(node_a, {})
	return node_b in node_data.get("connections", [])

func _is_node_accessible(node_id: String) -> bool:
	# 检查节点是否被封锁（如被敌军大规模占领）
	var controller: String = GameState.map_control.get(node_id, "neutral")
	return controller != "enemy_fortified"

func _get_terrain_march_penalty(node_id: String) -> float:
	var terrain: String = _map_graph.get(node_id, {}).get("terrain", "plains")
	match terrain:
		"mountains":  return 15.0
		"hills":       return 8.0
		"forest":      return 5.0
		"urban":       return 3.0
		_:             return 0.0
