pub mod order_deviation;
pub mod network;

pub use order_deviation::{
    Temperament, GeneralData, DeviationResult,
    calculate_deviation, DEFECTION_THRESHOLD,
    ney_waterloo_general, grouchy_wavre_general,
};
pub use network::{
    CharacterNetwork, NeyDefectionCondition, GrouchyArrivalCondition,
    LoyaltyEvent, RelationshipEvent,
    historical_network_day1, loyalty_delta_from_battle,
    LOYALTY_CRISIS_THRESHOLD, LOYALTY_ABSOLUTE_THRESHOLD,
};
