//! 蒙特卡洛平衡测试入口
//! 用法：`cargo run --bin balance-test -- --runs 1000 --seed 42`

use cent_jours_core::simulation::{print_report, run_simulation, PlayerStrategy};

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let runs = args
        .windows(2)
        .find(|w| w[0] == "--runs")
        .and_then(|w| w[1].parse::<u32>().ok())
        .unwrap_or(500);

    let seed = args
        .windows(2)
        .find(|w| w[0] == "--seed")
        .and_then(|w| w[1].parse::<u64>().ok())
        .unwrap_or(2026);

    println!("Cent Jours — 蒙特卡洛平衡测试");
    println!("模拟局数: {}  随机种子: {}", runs, seed);

    for strategy in [
        PlayerStrategy::Military,
        PlayerStrategy::Political,
        PlayerStrategy::Balanced,
    ] {
        let report = run_simulation(runs, strategy, seed);
        print_report(&report);
    }
}
