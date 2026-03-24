//! 行军系统模块
//! 节点移动、强行军、疲劳恢复、补给管理、Dijkstra路径查找

use super::resolver::Terrain;
use serde::Deserialize;
use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap, HashSet};

// ── 地图数据结构 ──────────────────────────────────────

/// 从 map_nodes.json 反序列化的单个节点
#[derive(Debug, Clone, Deserialize)]
pub struct MapNode {
    pub id: String,
    pub name: String,
    pub terrain: String,
    pub defense_bonus: f64,
    pub supply_capacity: u32,
    pub connections: Vec<String>,
}

/// 从 map_nodes.json 反序列化的边（用于加权路径查找）
#[derive(Debug, Clone, Deserialize)]
pub struct MapEdge {
    pub from: String,
    pub to: String,
    pub distance: u32,
    pub road_quality: String,
}

/// 运行时地图图结构
pub struct MapGraph {
    nodes: HashMap<String, MapNode>,
    /// 邻接表：node_id → Vec<(neighbor_id, travel_cost)>
    edges: HashMap<String, Vec<(String, u32)>>,
}

impl MapGraph {
    /// 获取某节点的直接相邻节点列表（供 UI 与行军校验复用）
    pub fn neighbors_of(&self, node_id: &str) -> Vec<String> {
        self.edges
            .get(node_id)
            .map(|neighbors| neighbors.iter().map(|(id, _)| id.clone()).collect())
            .unwrap_or_default()
    }

    pub fn new(nodes: Vec<MapNode>, edges: Vec<MapEdge>) -> Self {
        let node_map: HashMap<String, MapNode> =
            nodes.into_iter().map(|n| (n.id.clone(), n)).collect();

        let mut adj: HashMap<String, Vec<(String, u32)>> = HashMap::new();
        for edge in &edges {
            adj.entry(edge.from.clone())
                .or_default()
                .push((edge.to.clone(), edge.distance));
            // 双向
            adj.entry(edge.to.clone())
                .or_default()
                .push((edge.from.clone(), edge.distance));
        }
        Self {
            nodes: node_map,
            edges: adj,
        }
    }

    /// 获取节点地形
    pub fn terrain_of(&self, node_id: &str) -> Terrain {
        let t = self
            .nodes
            .get(node_id)
            .map(|n| n.terrain.as_str())
            .unwrap_or("plains");
        match t {
            "mountains" => Terrain::Mountains,
            "hills" => Terrain::Hills,
            "forest" => Terrain::Forest,
            "urban" => Terrain::Urban,
            "ridgeline" => Terrain::Ridgeline,
            "river_junction" => Terrain::RiverJunction,
            "coastal" => Terrain::Coastal,
            "fortress" => Terrain::Fortress,
            _ => Terrain::Plains,
        }
    }

    pub fn node_name(&self, node_id: &str) -> String {
        self.nodes
            .get(node_id)
            .map(|node| node.name.clone())
            .unwrap_or_else(|| node_id.to_string())
    }

    /// 节点是否相邻（直接连接）
    pub fn is_adjacent(&self, from: &str, to: &str) -> bool {
        self.edges
            .get(from)
            .map(|neighbors| neighbors.iter().any(|(n, _)| n == to))
            .unwrap_or(false)
    }

    /// Dijkstra 最短路径查找
    /// 返回 (path: Vec<node_id>, total_cost: u32)；无路可达返回 None
    pub fn find_path(&self, from: &str, to: &str) -> Option<(Vec<String>, u32)> {
        if from == to {
            return Some((vec![from.to_string()], 0));
        }

        // (cost, node_id, path)
        let mut heap: BinaryHeap<(Reverse<u32>, String, Vec<String>)> = BinaryHeap::new();
        let mut visited: HashSet<String> = HashSet::new();

        heap.push((Reverse(0), from.to_string(), vec![from.to_string()]));

        while let Some((Reverse(cost), node, path)) = heap.pop() {
            if node == to {
                return Some((path, cost));
            }
            if visited.contains(&node) {
                continue;
            }
            visited.insert(node.clone());

            if let Some(neighbors) = self.edges.get(&node) {
                for (neighbor, edge_cost) in neighbors {
                    if !visited.contains(neighbor) {
                        let mut new_path = path.clone();
                        new_path.push(neighbor.clone());
                        heap.push((Reverse(cost + edge_cost), neighbor.clone(), new_path));
                    }
                }
            }
        }
        None
    }

    /// 两节点间节点距离（边数，不含权重）
    pub fn node_distance(&self, from: &str, to: &str) -> u32 {
        // BFS
        if from == to {
            return 0;
        }
        let mut queue = std::collections::VecDeque::new();
        let mut visited = HashSet::new();
        queue.push_back((from.to_string(), 0u32));
        visited.insert(from.to_string());
        while let Some((node, dist)) = queue.pop_front() {
            if let Some(neighbors) = self.edges.get(&node) {
                for (n, _) in neighbors {
                    if n == to {
                        return dist + 1;
                    }
                    if !visited.contains(n) {
                        visited.insert(n.clone());
                        queue.push_back((n.clone(), dist + 1));
                    }
                }
            }
        }
        u32::MAX // 不可达
    }

    pub fn supply_capacity_of(&self, node_id: &str) -> u32 {
        self.nodes
            .get(node_id)
            .map(|n| n.supply_capacity)
            .unwrap_or(1)
    }

    pub fn supply_role_of(&self, node_id: &str) -> &'static str {
        self.nodes
            .get(node_id)
            .map(|n| supply_role_for_capacity(n.supply_capacity))
            .unwrap_or("frontline_outpost")
    }

    pub fn supply_role_label_of(&self, node_id: &str) -> &'static str {
        supply_role_label(self.supply_role_of(node_id))
    }
}

pub fn supply_role_for_capacity(capacity: u32) -> &'static str {
    match capacity {
        0..=2 => "frontline_outpost",
        3..=5 => "transit_stop",
        6..=9 => "regional_depot",
        _ => "strategic_depot",
    }
}

pub fn supply_role_label(role: &str) -> &'static str {
    match role {
        "frontline_outpost" => "前沿消耗点",
        "transit_stop" => "沿线转运点",
        "regional_depot" => "区域整补点",
        "strategic_depot" => "战略大仓",
        _ => "前沿消耗点",
    }
}

// ── 行军参数常量 ──────────────────────────────────────

pub const BASE_MOVEMENT: u32 = 1;
pub const FORCED_MARCH_BONUS: u32 = 1;
pub const FORCED_MARCH_FATIGUE: f64 = 20.0;
pub const FORCED_MARCH_MORALE: f64 = -10.0;
pub const NORMAL_FATIGUE_RECOVERY: f64 = 15.0;
pub const REST_FATIGUE_RECOVERY: f64 = 30.0;
pub const SUPPLY_OK_THRESHOLD: f64 = 45.0;
pub const SUPPLY_TROOP_STEP: f64 = 12_000.0;
pub const MIN_SUPPLY_DEMAND: f64 = 4.0;
pub const BASE_LINE_SUPPLY: f64 = 2.0;
pub const SUPPLY_BALANCE_MULTIPLIER: f64 = 4.0;
pub const MAX_DAILY_SUPPLY_GAIN: f64 = 12.0;
pub const MAX_DAILY_SUPPLY_LOSS: f64 = -15.0;

// ── 行军输入/输出 ─────────────────────────────────────

#[derive(Debug, Clone)]
pub struct ArmyState {
    pub id: String,
    pub location: String,
    pub troops: u32,
    pub morale: f64,
    pub fatigue: f64,
    pub supply: f64,
}

#[derive(Debug, Clone)]
pub struct MoveResult {
    pub success: bool,
    pub reason: Option<String>,
    pub new_location: String,
    pub fatigue_delta: f64,
    pub morale_delta: f64,
    pub new_fatigue: f64,
    pub new_morale: f64,
    pub forced_march: bool,
}

#[derive(Debug, Clone)]
pub struct SupplyResult {
    pub supply_ok: bool,
    pub supply_delta: f64,
    pub demand: f64,
    pub available: f64,
    pub new_supply: f64,
    pub line_efficiency: f64,
}

// ── 核心行军函数 ──────────────────────────────────────

/// 执行行军命令
///
/// - `army`：当前军队状态
/// - `target_node`：目标节点 id
/// - `forced`：是否强行军
/// - `map`：地图图结构
pub fn move_army(army: &ArmyState, target_node: &str, forced: bool, map: &MapGraph) -> MoveResult {
    // 验证相邻
    if !map.is_adjacent(&army.location, target_node) {
        return MoveResult {
            success: false,
            reason: Some(format!("{} 与 {} 不相邻", army.location, target_node)),
            new_location: army.location.clone(),
            fatigue_delta: 0.0,
            morale_delta: 0.0,
            new_fatigue: army.fatigue,
            new_morale: army.morale,
            forced_march: false,
        };
    }

    let terrain_penalty = map.terrain_of(target_node).march_fatigue_penalty();

    let (fatigue_delta, morale_delta) = if forced {
        (FORCED_MARCH_FATIGUE + terrain_penalty, FORCED_MARCH_MORALE)
    } else {
        // 普通行军：净恢复 10 点（-15+5）
        (-NORMAL_FATIGUE_RECOVERY + 5.0 + terrain_penalty, 0.0)
    };

    let new_fatigue = (army.fatigue + fatigue_delta).clamp(0.0, 100.0);
    let new_morale = (army.morale + morale_delta).clamp(0.0, 100.0);

    MoveResult {
        success: true,
        reason: None,
        new_location: target_node.to_string(),
        fatigue_delta,
        morale_delta,
        new_fatigue,
        new_morale,
        forced_march: forced,
    }
}

/// 驻扎休整（不移动）
pub fn rest_army(army: &ArmyState) -> (f64, f64) {
    // 返回 (fatigue_recovery, morale_recovery)
    let fat_rec = if army.supply > SUPPLY_OK_THRESHOLD {
        REST_FATIGUE_RECOVERY + 10.0
    } else {
        REST_FATIGUE_RECOVERY
    };
    let mor_rec = if army.supply > SUPPLY_OK_THRESHOLD {
        10.0
    } else {
        5.0
    };
    (fat_rec, mor_rec)
}

/// 更新补给状态
pub fn update_supply(army: &ArmyState, line_efficiency: f64, map: &MapGraph) -> SupplyResult {
    update_supply_with_capacity(
        army,
        line_efficiency,
        map.supply_capacity_of(&army.location),
    )
}

pub fn update_supply_with_capacity(
    army: &ArmyState,
    line_efficiency: f64,
    supply_capacity: u32,
) -> SupplyResult {
    let capacity = supply_capacity as f64;
    let demand = (army.troops as f64 / SUPPLY_TROOP_STEP).max(MIN_SUPPLY_DEMAND)
        * (1.0 + army.fatigue / 250.0);
    let available = capacity * line_efficiency.clamp(0.2, 1.2) + BASE_LINE_SUPPLY;
    let supply_delta = ((available - demand) * SUPPLY_BALANCE_MULTIPLIER)
        .clamp(MAX_DAILY_SUPPLY_LOSS, MAX_DAILY_SUPPLY_GAIN);
    let new_supply = (army.supply + supply_delta).clamp(0.0, 100.0);
    let supply_ok = new_supply >= SUPPLY_OK_THRESHOLD;

    SupplyResult {
        supply_ok,
        supply_delta,
        demand,
        available,
        new_supply,
        line_efficiency,
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn simple_map() -> MapGraph {
        let nodes = vec![
            MapNode {
                id: "paris".into(),
                name: "Paris".into(),
                terrain: "urban".into(),
                defense_bonus: 1.5,
                supply_capacity: 20,
                connections: vec!["laon".into(), "fontainebleau".into()],
            },
            MapNode {
                id: "laon".into(),
                name: "Laon".into(),
                terrain: "hills".into(),
                defense_bonus: 1.4,
                supply_capacity: 5,
                connections: vec!["paris".into(), "maubeuge".into()],
            },
            MapNode {
                id: "fontainebleau".into(),
                name: "Fontainebleau".into(),
                terrain: "forest".into(),
                defense_bonus: 1.2,
                supply_capacity: 4,
                connections: vec!["paris".into()],
            },
            MapNode {
                id: "maubeuge".into(),
                name: "Maubeuge".into(),
                terrain: "plains".into(),
                defense_bonus: 1.5,
                supply_capacity: 5,
                connections: vec!["laon".into(), "charleroi".into()],
            },
            MapNode {
                id: "charleroi".into(),
                name: "Charleroi".into(),
                terrain: "plains".into(),
                defense_bonus: 1.2,
                supply_capacity: 6,
                connections: vec!["maubeuge".into(), "waterloo".into()],
            },
            MapNode {
                id: "waterloo".into(),
                name: "Waterloo".into(),
                terrain: "ridgeline".into(),
                defense_bonus: 1.3,
                supply_capacity: 2,
                connections: vec!["charleroi".into()],
            },
        ];
        let edges = vec![
            MapEdge {
                from: "paris".into(),
                to: "laon".into(),
                distance: 2,
                road_quality: "royal_road".into(),
            },
            MapEdge {
                from: "paris".into(),
                to: "fontainebleau".into(),
                distance: 1,
                road_quality: "royal_road".into(),
            },
            MapEdge {
                from: "laon".into(),
                to: "maubeuge".into(),
                distance: 2,
                road_quality: "secondary_road".into(),
            },
            MapEdge {
                from: "maubeuge".into(),
                to: "charleroi".into(),
                distance: 1,
                road_quality: "secondary_road".into(),
            },
            MapEdge {
                from: "charleroi".into(),
                to: "waterloo".into(),
                distance: 2,
                road_quality: "dirt_road".into(),
            },
        ];
        MapGraph::new(nodes, edges)
    }

    fn army_at(loc: &str) -> ArmyState {
        ArmyState {
            id: "test_army".into(),
            location: loc.into(),
            troops: 60_000,
            morale: 80.0,
            fatigue: 20.0,
            supply: 70.0,
        }
    }

    #[test]
    fn 普通行军到相邻节点() {
        let map = simple_map();
        let army = army_at("paris");
        let result = move_army(&army, "laon", false, &map);
        assert!(result.success);
        assert_eq!(result.new_location, "laon");
        assert!(!result.forced_march);
    }

    #[test]
    fn 强行军增加疲劳() {
        let map = simple_map();
        let army = army_at("paris");
        let normal = move_army(&army, "laon", false, &map);
        let forced = move_army(&army, "laon", true, &map);
        assert!(forced.new_fatigue > normal.new_fatigue);
        assert!(forced.morale_delta < 0.0);
    }

    #[test]
    fn 不相邻节点无法直接移动() {
        let map = simple_map();
        let army = army_at("paris");
        let result = move_army(&army, "waterloo", false, &map);
        assert!(!result.success);
    }

    #[test]
    fn dijkstra路径查找_巴黎到滑铁卢() {
        let map = simple_map();
        let path = map.find_path("paris", "waterloo");
        assert!(path.is_some());
        let (nodes, cost) = path.unwrap();
        // 路径应包含起终点
        assert_eq!(nodes.first().unwrap(), "paris");
        assert_eq!(nodes.last().unwrap(), "waterloo");
        // 成本应合理（不超过所有边之和）
        assert!(cost > 0 && cost < 100);
    }

    #[test]
    fn 节点距离_巴黎到滑铁卢() {
        let map = simple_map();
        let dist = map.node_distance("paris", "waterloo");
        // paris → laon → maubeuge → charleroi → waterloo = 4 跳
        assert_eq!(dist, 4);
    }

    #[test]
    fn 补给线断裂时供应减少() {
        let map = simple_map();
        let army = army_at("waterloo"); // 远离补给线
        let intact = update_supply(&army, 0.9, &map);
        let severed = update_supply(&army, 0.3, &map);
        assert!(severed.available < intact.available);
        assert!(severed.new_supply < intact.new_supply);
    }

    #[test]
    fn 前线低容量节点会持续消耗补给() {
        let map = simple_map();
        let army = army_at("waterloo");
        let result = update_supply(&army, 0.7, &map);

        assert!(result.supply_delta < 0.0, "滑铁卢低容量节点应难以维持补给");
        assert!(result.new_supply < army.supply);
    }

    #[test]
    fn 高容量节点能补回补给() {
        let map = simple_map();
        let mut army = army_at("paris");
        army.supply = 40.0;
        let result = update_supply(&army, 1.1, &map);

        assert!(result.supply_delta > 0.0, "巴黎应具备明显补给恢复能力");
        assert!(result.new_supply > army.supply);
    }

    #[test]
    fn 节点容量会映射为补给角色() {
        let map = simple_map();
        assert_eq!(map.supply_role_of("waterloo"), "frontline_outpost");
        assert_eq!(map.supply_role_label_of("waterloo"), "前沿消耗点");
        assert_eq!(map.supply_role_of("laon"), "transit_stop");
        assert_eq!(map.supply_role_of("charleroi"), "regional_depot");
        assert_eq!(map.supply_role_of("paris"), "strategic_depot");
    }

    #[test]
    fn 临时容量加成会改变补给结果() {
        let army = army_at("waterloo");
        let baseline = update_supply_with_capacity(&army, 0.7, 2);
        let boosted = update_supply_with_capacity(&army, 0.7, 6);
        assert!(boosted.available > baseline.available);
        assert!(boosted.new_supply > baseline.new_supply);
    }

    // ── rest_army() 直接单元测试 ─────────────────────

    #[test]
    fn 补给充足时休整疲劳恢复40士气恢复10() {
        let army = ArmyState {
            id: "test".into(),
            location: "paris".into(),
            troops: 50_000,
            morale: 70.0,
            fatigue: 60.0,
            supply: 80.0, // > 阈值
        };
        let (fat_rec, mor_rec) = rest_army(&army);
        assert_eq!(
            fat_rec,
            REST_FATIGUE_RECOVERY + 10.0,
            "充足补给疲劳恢复应为40"
        );
        assert_eq!(mor_rec, 10.0, "充足补给士气恢复应为10");
    }

    #[test]
    fn 补给不足时休整疲劳恢复30士气恢复5() {
        let army = ArmyState {
            id: "test".into(),
            location: "waterloo".into(),
            troops: 50_000,
            morale: 70.0,
            fatigue: 60.0,
            supply: 30.0, // ≤ 阈值
        };
        let (fat_rec, mor_rec) = rest_army(&army);
        assert_eq!(fat_rec, REST_FATIGUE_RECOVERY, "不足补给疲劳恢复应为30");
        assert_eq!(mor_rec, 5.0, "不足补给士气恢复应为5");
    }

    #[test]
    fn 补给恰好阈值时取低档() {
        // supply = 阈值，条件 supply > 阈值 为 false → 低档
        let army = ArmyState {
            id: "test".into(),
            location: "paris".into(),
            troops: 50_000,
            morale: 70.0,
            fatigue: 60.0,
            supply: SUPPLY_OK_THRESHOLD,
        };
        let (fat_rec, mor_rec) = rest_army(&army);
        assert_eq!(
            fat_rec, REST_FATIGUE_RECOVERY,
            "supply=阈值时应取低档疲劳恢复"
        );
        assert_eq!(mor_rec, 5.0, "supply=阈值时应取低档士气恢复");
    }

    #[test]
    fn 休整恢复量高于强行军消耗() {
        // 休整疲劳恢复(30+) 应远大于强行军消耗(20)
        let army = ArmyState {
            id: "test".into(),
            location: "paris".into(),
            troops: 50_000,
            morale: 70.0,
            fatigue: 60.0,
            supply: 20.0, // 低档
        };
        let (fat_rec, _) = rest_army(&army);
        assert!(
            fat_rec > FORCED_MARCH_FATIGUE,
            "休整恢复({fat_rec})应大于强行军消耗({FORCED_MARCH_FATIGUE})"
        );
    }
}
