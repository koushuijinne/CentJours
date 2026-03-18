pub mod resolver;
pub mod march;

pub use resolver::{BattleResult, BattleOutcome, ForceData, Terrain, resolve_battle};
pub use march::{MapGraph, MapNode, MapEdge, ArmyState, MoveResult, SupplyResult,
                move_army, rest_army, update_supply};
