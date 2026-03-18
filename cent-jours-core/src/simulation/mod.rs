pub mod monte_carlo;
pub use monte_carlo::{
    GameOutcome, GameRecord, PlayerStrategy,
    SimulationReport, TARGET_VICTORY_RATE_MAX, TARGET_VICTORY_RATE_MIN,
    print_report, run_simulation, simulate_one_game,
};
