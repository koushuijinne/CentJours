pub mod monte_carlo;
pub use crate::engine::GameOutcome;
pub use monte_carlo::{
    print_report, run_simulation, simulate_one_game, GameRecord, PlayerStrategy, SimulationReport,
    TARGET_VICTORY_RATE_MAX, TARGET_VICTORY_RATE_MIN,
};
