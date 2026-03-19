## MarchSystem — 地图路径查询层（v2）
## 行军执行逻辑已移至 CentJoursEngine（Rust）
## 本脚本只提供地图 UI 所需的路径查找和距离计算

class_name MarchSystem
extends RefCounted

# ── 地图数据缓存 ──────────────────────────────────────
var _map_graph: Dictionary = {}   # node_id -> node_data

func initialize(map_data: Dictionary) -> void:
	for node in map_data.get("nodes", []):
		_map_graph[node["id"]] = node.duplicate(true)

# ── 路径与距离查询（供地图 UI 渲染路径指示）──────────────

## 找出从起点到终点的最短路径（节点 id 列表，含起点和终点）
func find_path(from_node: String, to_node: String) -> Array:
	if from_node == to_node:
		return [from_node]

	var visited: Dictionary = {}
	var queue: Array = [[from_node, [from_node]]]

	while queue.size() > 0:
		var current_pair: Array = queue.pop_front()
		var node: String = current_pair[0]
		var path: Array  = current_pair[1]

		if node == to_node:
			return path
		if node in visited:
			continue
		visited[node] = true

		for neighbor in _map_graph.get(node, {}).get("connections", []):
			if not neighbor in visited:
				var new_path: Array = path.duplicate()
				new_path.append(neighbor)
				queue.append([neighbor, new_path])

	return []

## 计算两节点间的最短节点距离（BFS 跳数）
func get_distance(from_node: String, to_node: String) -> int:
	return max(0, find_path(from_node, to_node).size() - 1)

## 获取一个节点的相邻节点列表（供地图 UI 高亮可移动格）
func get_neighbors(node_id: String) -> Array:
	return _map_graph.get(node_id, {}).get("connections", [])

## 获取节点地形信息（供地图 UI Tooltip）
func get_node_terrain(node_id: String) -> String:
	return _map_graph.get(node_id, {}).get("terrain", "plains")
