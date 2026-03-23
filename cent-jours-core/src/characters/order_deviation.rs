//! 命令偏差模型（Order Deviation）
//! 实现计划书附录A.2：将领执行命令时基于性格和忠诚度的系统性偏差

use rand::Rng;

// ── 将领性格 ──────────────────────────────────────────

/// 将领性格类型，决定命令偏差方向
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Temperament {
    Cautious,  // 谨慎：倾向延迟、保守用兵
    Balanced,  // 均衡：偏差最小
    Impulsive, // 冲动：倾向提前行动、多投兵力（Ney型）
    Reckless,  // 鲁莽：几乎必然激进化命令
}

impl Temperament {
    /// 性格对应的偏差参数 (timing, force_commitment)
    /// timing > 0 = 倾向延迟；force_commitment > 0 = 倾向多投兵力
    pub fn profile(&self) -> (f64, f64) {
        match self {
            Self::Cautious => (0.30, -0.20),
            Self::Balanced => (0.00, 0.00),
            Self::Impulsive => (-0.20, 0.30),
            Self::Reckless => (-0.30, 0.50),
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "cautious" => Self::Cautious,
            "impulsive" => Self::Impulsive,
            "reckless" => Self::Reckless,
            _ => Self::Balanced,
        }
    }
}

// ── 将领数据 ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct GeneralData {
    pub id: String,
    pub name: String,
    pub loyalty: f64, // 0-100
    pub temperament: Temperament,
    pub military_skill: f64, // 0-100
}

// ── 偏差计算参数 ──────────────────────────────────────

pub const DISTANCE_PENALTY_PER_NODE: f64 = 0.05; // 每个节点距离 +5% 偏差
pub const MAX_DISTANCE_PENALTY: f64 = 0.40; // 最大通信距离惩罚 40%
/// 忠诚度低于此值 → 可能拒绝命令（单一来源：characters/network.rs::LOYALTY_CRISIS_THRESHOLD）
pub use crate::characters::network::LOYALTY_CRISIS_THRESHOLD as DEFECTION_THRESHOLD;

// ── 偏差结果 ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct DeviationResult {
    pub general_id: String,
    pub general_name: String,
    /// 时机偏差：正值 = 延迟执行（小时级）；负值 = 提前行动
    pub timing_deviation: f64,
    /// 兵力投入偏差：正值 = 过度进攻；负值 = 保守用兵
    pub force_deviation: f64,
    /// 是否执行命令（低忠诚度时可能拒绝）
    pub order_followed: bool,
    pub base_reliability: f64,
    pub distance_penalty: f64,
}

impl DeviationResult {
    /// 生成人类可读的叙事描述（占位符，M4阶段替换为LLM预生成文本）
    pub fn narrative(&self) -> String {
        if !self.order_followed {
            return format!("{} 拒绝执行命令。", self.general_name);
        }
        let name = &self.general_name;
        if self.timing_deviation < -0.15 && self.force_deviation > 0.2 {
            format!("{} 比命令提前行动，并投入了远超预期的兵力。", name)
        } else if self.timing_deviation > 0.2 {
            format!("{} 的行动比预期晚了几个小时。", name)
        } else if self.force_deviation > 0.3 {
            format!("{} 按时行动，但投入了额外的预备队。", name)
        } else if self.force_deviation < -0.2 {
            format!("{} 执行了命令，但刻意保留了部分兵力。", name)
        } else {
            format!("{} 按照命令准确执行。", name)
        }
    }
}

// ── 核心偏差计算 ──────────────────────────────────────

/// 计算将领执行命令时的偏差
///
/// # 参数
/// - `general`：将领数据
/// - `communication_distance`：与拿破仑司令部的节点距离
/// - `battlefield_chaos`：战场混乱度（0.0-1.0）
/// - `rng`：随机数生成器
pub fn calculate_deviation<R: Rng>(
    general: &GeneralData,
    communication_distance: u32,
    battlefield_chaos: f64,
    rng: &mut R,
) -> DeviationResult {
    // 基础可靠性：忠诚度100 → base=0.5；忠诚度0 → base=1.0
    let base_reliability = 1.0 - (general.loyalty / 100.0) * 0.5;

    let (timing_profile, force_profile) = general.temperament.profile();

    // 通信距离惩罚
    let distance_penalty =
        (communication_distance as f64 * DISTANCE_PENALTY_PER_NODE).min(MAX_DISTANCE_PENALTY);

    // 战场混乱随机扰动
    let chaos_range = battlefield_chaos * 0.1;
    let chaos_noise: f64 = rng.gen_range(-chaos_range..=chaos_range);

    let timing_deviation = base_reliability * timing_profile + distance_penalty + chaos_noise;
    let force_deviation = base_reliability * force_profile + chaos_noise * 0.5;

    // 低忠诚度时判断是否拒绝命令
    let order_followed = if general.loyalty < DEFECTION_THRESHOLD {
        let defect_chance = (DEFECTION_THRESHOLD - general.loyalty) / DEFECTION_THRESHOLD * 0.4;
        let defect_chance = defect_chance + battlefield_chaos * 0.1;
        rng.gen::<f64>() > defect_chance
    } else {
        true
    };

    DeviationResult {
        general_id: general.id.clone(),
        general_name: general.name.clone(),
        timing_deviation,
        force_deviation,
        order_followed,
        base_reliability,
        distance_penalty,
    }
}

// ── 历史场景验证 ──────────────────────────────────────

/// 内伊在滑铁卢的骑兵冲锋场景参数
pub fn ney_waterloo_general() -> GeneralData {
    GeneralData {
        id: "ney".into(),
        name: "Michel Ney".into(),
        loyalty: 65.0,
        temperament: Temperament::Impulsive,
        military_skill: 85.0,
    }
}

/// 格鲁希追击普鲁士场景参数
pub fn grouchy_wavre_general() -> GeneralData {
    GeneralData {
        id: "grouchy".into(),
        name: "Emmanuel de Grouchy".into(),
        loyalty: 75.0,
        temperament: Temperament::Cautious,
        military_skill: 68.0,
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rand::rngs::StdRng;
    use rand::SeedableRng;

    fn rng(seed: u64) -> StdRng {
        StdRng::seed_from_u64(seed)
    }

    fn davout() -> GeneralData {
        GeneralData {
            id: "davout".into(),
            name: "Louis Davout".into(),
            loyalty: 95.0,
            temperament: Temperament::Cautious,
            military_skill: 92.0,
        }
    }

    #[test]
    fn 达武高忠诚度基础偏差小() {
        let result = calculate_deviation(&davout(), 0, 0.0, &mut rng(1));
        assert!(result.order_followed);
        // base_reliability = 1 - 0.95*0.5 = 0.525；偏差幅度应很小
        assert!(result.base_reliability < 0.6);
    }

    #[test]
    fn 内伊冲动性格倾向提前行动() {
        let ney = ney_waterloo_general();
        let results: Vec<_> = (0..100)
            .map(|i| calculate_deviation(&ney, 0, 0.6, &mut rng(i)))
            .collect();
        let early_action = results.iter().filter(|r| r.timing_deviation < 0.0).count();
        // 冲动性格大多数情况下应倾向提前
        assert!(
            early_action > 60,
            "内伊倾向提前的比例应>60%，实际={}/100",
            early_action
        );
    }

    #[test]
    fn 格鲁希谨慎性格倾向延迟() {
        let grouchy = grouchy_wavre_general();
        let results: Vec<_> = (0..100)
            .map(|i| calculate_deviation(&grouchy, 3, 0.4, &mut rng(i)))
            .collect();
        let delayed = results.iter().filter(|r| r.timing_deviation > 0.0).count();
        assert!(
            delayed > 70,
            "格鲁希倾向延迟的比例应>70%，实际={}/100",
            delayed
        );
    }

    #[test]
    fn 通信距离增加偏差() {
        let general = davout();
        let near = calculate_deviation(&general, 0, 0.0, &mut rng(42));
        let far = calculate_deviation(&general, 8, 0.0, &mut rng(42));
        // 距离越远，timing偏差越大（通信惩罚累加）
        assert!(far.distance_penalty > near.distance_penalty);
    }

    #[test]
    fn 距离惩罚上限40percent() {
        let general = davout();
        let result = calculate_deviation(&general, 100, 0.0, &mut rng(0));
        assert!(result.distance_penalty <= MAX_DISTANCE_PENALTY + f64::EPSILON);
    }

    #[test]
    fn 低忠诚度有概率拒绝命令() {
        let traitor = GeneralData {
            id: "traitor".into(),
            name: "叛将".into(),
            loyalty: 5.0,
            temperament: Temperament::Balanced,
            military_skill: 50.0,
        };
        let refusals = (0..200u64)
            .filter(|&i| !calculate_deviation(&traitor, 0, 0.0, &mut rng(i)).order_followed)
            .count();
        // 忠诚度5/30 = 16.7% 基础拒绝率 * 0.4 = 约6.7%，有一定概率拒绝
        assert!(refusals > 0, "低忠诚度将领应有拒绝命令的情况");
    }

    #[test]
    fn 高忠诚度将领几乎不拒绝() {
        let loyal = GeneralData {
            id: "loyal".into(),
            name: "忠臣".into(),
            loyalty: 95.0,
            temperament: Temperament::Balanced,
            military_skill: 80.0,
        };
        let refusals = (0..1000u64)
            .filter(|&i| !calculate_deviation(&loyal, 0, 0.0, &mut rng(i)).order_followed)
            .count();
        assert_eq!(refusals, 0, "忠诚度95的将领不应拒绝命令");
    }
}
