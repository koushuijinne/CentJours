pub mod march;
pub mod resolver;

pub use march::{
    move_army, rest_army, supply_role_for_capacity, supply_role_label, update_supply,
    update_supply_with_capacity, ArmyState, MapEdge, MapGraph, MapNode, MoveResult, SupplyResult,
    SUPPLY_OK_THRESHOLD,
};
pub use resolver::{resolve_battle, BattleOutcome, BattleResult, ForceData, Terrain};
