pub mod network;
pub mod order_deviation;

pub use network::{
    historical_network_day1, loyalty_delta_from_battle, CharacterNetwork, GrouchyArrivalCondition,
    LoyaltyEvent, NeyDefectionCondition, RelationshipEvent, LOYALTY_ABSOLUTE_THRESHOLD,
    LOYALTY_CRISIS_THRESHOLD,
};
pub use order_deviation::{
    calculate_deviation, grouchy_wavre_general, ney_waterloo_general, DeviationResult, GeneralData,
    Temperament, DEFECTION_THRESHOLD,
};
