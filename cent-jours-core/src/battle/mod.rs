pub mod march;
pub mod resolver;

pub use march::{
    move_army, rest_army, update_supply, ArmyState, MapEdge, MapGraph, MapNode, MoveResult,
    SupplyResult,
};
pub use resolver::{resolve_battle, BattleOutcome, BattleResult, ForceData, Terrain};
