pub mod order_deviation;
pub use order_deviation::{
    Temperament, GeneralData, DeviationResult,
    calculate_deviation, DEFECTION_THRESHOLD,
    ney_waterloo_general, grouchy_wavre_general,
};
