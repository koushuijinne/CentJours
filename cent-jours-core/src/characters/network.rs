//! 将领关系网络
//! 动态关系矩阵 + 忠诚度更新 + 历史事件触发条件
//! 纯Rust，无Godot依赖

use std::collections::HashMap;
use crate::battle::resolver::BattleResult;

// ── 常量 ──────────────────────────────────────────────

/// 忠诚度低于此值时，将领可能拒绝命令或叛变
pub const LOYALTY_CRISIS_THRESHOLD: f64 = 30.0;
/// 忠诚度高于此值时，将领无条件服从
pub const LOYALTY_ABSOLUTE_THRESHOLD: f64 = 80.0;
/// 关系值低于此值时，两将领存在积极敌意
pub const RELATIONSHIP_HOSTILE_THRESHOLD: f64 = -30.0;
/// 每日自然关系衰减系数（无互动时缓慢归零）
const DAILY_RELATIONSHIP_DECAY: f64 = 0.05;

// ── 战斗结果对忠诚度的影响 ──────────────────────────────

/// 战斗结果 → 参战将领忠诚度变化
pub fn loyalty_delta_from_battle(result: BattleResult) -> f64 {
    match result {
        BattleResult::DecisiveVictory  =>  12.0,
        BattleResult::MarginalVictory  =>   6.0,
        BattleResult::Stalemate        =>   0.0,
        BattleResult::MarginalDefeat   =>  -6.0,
        BattleResult::DecisiveDefeat   => -15.0,
    }
}

// ── 历史事件触发条件 ──────────────────────────────────

/// 内伊倒戈检查：内伊对拿破仑的bond高于其当前任务忠诚
/// 历史背景：路易十八派内伊去逮捕拿破仑，但见面后立即倒戈
pub struct NeyDefectionCondition {
    pub ney_loyalty_to_bourbon: f64,   // 对旧政权的忠诚（越低越可能倒戈）
    pub ney_relationship_napoleon: f64, // 与拿破仑的历史情感纽带
    pub napoleon_reputation: f64,       // 拿破仑当时的声望（民众支持/胜绩）
}

impl NeyDefectionCondition {
    /// 返回内伊倒戈的概率（0.0-1.0）
    pub fn defection_probability(&self) -> f64 {
        if self.ney_relationship_napoleon < 50.0 {
            return 0.0; // 关系太差，不会倒戈
        }
        // 忠诚度越低 + 与拿破仑关系越好 + 声望越高 → 概率越大
        let base = (self.ney_relationship_napoleon - 50.0) / 50.0; // 0..1
        let loyalty_factor = 1.0 - (self.ney_loyalty_to_bourbon / 100.0);
        let reputation_factor = self.napoleon_reputation / 100.0;
        (base * 0.5 + loyalty_factor * 0.3 + reputation_factor * 0.2).min(1.0)
    }
}

/// 格鲁希追击检查：是否在滑铁卢前按时赶到
pub struct GrouchyArrivalCondition {
    pub grouchy_loyalty: f64,
    pub communication_distance: u32, // 到拿破仑主力的节点距离
    pub day: u32,                    // 当前天数（滑铁卢约在Day 95）
}

impl GrouchyArrivalCondition {
    /// 格鲁希及时增援的概率
    pub fn arrival_probability(&self) -> f64 {
        if self.day < 90 || self.communication_distance > 4 {
            return 0.0;
        }
        // 忠诚高但谨慎性格 → 等待明确命令 → 大概率延迟
        // 此处返回"及时到达"概率
        let loyalty_factor = self.grouchy_loyalty / 100.0;
        let distance_penalty = (self.communication_distance as f64) * 0.15;
        (loyalty_factor * 0.4 - distance_penalty).max(0.0)
    }
}

// ── 关系变化记录 ──────────────────────────────────────

#[derive(Debug, Clone)]
pub struct RelationshipEvent {
    pub day:    u32,
    pub from:   String,
    pub to:     String,
    pub delta:  f64,
    pub reason: &'static str,
}

// ── 忠诚度历史记录 ────────────────────────────────────

#[derive(Debug, Clone)]
pub struct LoyaltyEvent {
    pub day:       u32,
    pub general_id: String,
    pub delta:     f64,
    pub reason:    &'static str,
}

// ── 核心结构 ──────────────────────────────────────────

/// 将领关系网络：维护所有将领的忠诚度和相互关系
#[derive(Debug, Default)]
pub struct CharacterNetwork {
    /// 各将领当前忠诚度（0-100）
    pub loyalty: HashMap<String, f64>,
    /// 双向关系强度（-100..100），key=(id_a, id_b)，a<b字典序
    pub relationships: HashMap<(String, String), f64>,
    /// 审计日志
    pub loyalty_log:      Vec<LoyaltyEvent>,
    pub relationship_log: Vec<RelationshipEvent>,
}

impl CharacterNetwork {
    /// 创建空网络
    pub fn new() -> Self {
        Self::default()
    }

    /// 添加将领（初始忠诚度）
    pub fn add_general(&mut self, id: &str, initial_loyalty: f64) {
        self.loyalty.insert(id.to_string(), initial_loyalty.clamp(0.0, 100.0));
    }

    /// 设置两将领之间的初始关系值
    pub fn set_relationship(&mut self, a: &str, b: &str, value: f64) {
        let key = relationship_key(a, b);
        self.relationships.insert(key, value.clamp(-100.0, 100.0));
    }

    /// 获取将领当前忠诚度
    pub fn loyalty(&self, id: &str) -> f64 {
        self.loyalty.get(id).copied().unwrap_or(50.0)
    }

    /// 获取两将领之间的关系强度
    pub fn relationship(&self, a: &str, b: &str) -> f64 {
        let key = relationship_key(a, b);
        self.relationships.get(&key).copied().unwrap_or(0.0)
    }

    /// 调整将领忠诚度，记录日志
    pub fn modify_loyalty(&mut self, id: &str, delta: f64, day: u32, reason: &'static str) {
        let entry = self.loyalty.entry(id.to_string()).or_insert(50.0);
        *entry = (*entry + delta).clamp(0.0, 100.0);
        self.loyalty_log.push(LoyaltyEvent {
            day,
            general_id: id.to_string(),
            delta,
            reason,
        });
    }

    /// 根据战斗结果更新参战将领的忠诚度
    pub fn apply_battle_outcome(&mut self, general_id: &str, result: BattleResult, day: u32) {
        let delta = loyalty_delta_from_battle(result);
        if delta.abs() > 0.001 {
            let reason = match result {
                BattleResult::DecisiveVictory => "decisive_victory",
                BattleResult::MarginalVictory => "marginal_victory",
                BattleResult::Stalemate       => "stalemate",
                BattleResult::MarginalDefeat  => "marginal_defeat",
                BattleResult::DecisiveDefeat  => "decisive_defeat",
            };
            self.modify_loyalty(general_id, delta, day, reason);
        }
    }

    /// 调整两将领之间的关系值，记录日志
    pub fn modify_relationship(
        &mut self,
        a: &str,
        b: &str,
        delta: f64,
        day: u32,
        reason: &'static str,
    ) {
        let key = relationship_key(a, b);
        let entry = self.relationships.entry(key).or_insert(0.0);
        *entry = (*entry + delta).clamp(-100.0, 100.0);
        self.relationship_log.push(RelationshipEvent {
            day,
            from: a.to_string(),
            to:   b.to_string(),
            delta,
            reason,
        });
    }

    /// 每日自然衰减：无互动的关系慢慢归零（不改变忠诚度）
    pub fn tick_day(&mut self) {
        for value in self.relationships.values_mut() {
            if value.abs() > 0.1 {
                *value -= value.signum() * DAILY_RELATIONSHIP_DECAY;
            }
        }
    }

    /// 将领是否处于危机忠诚度（可能拒绝命令）
    pub fn is_loyalty_crisis(&self, id: &str) -> bool {
        self.loyalty(id) < LOYALTY_CRISIS_THRESHOLD
    }

    /// 将领是否绝对忠诚（无条件服从）
    pub fn is_absolutely_loyal(&self, id: &str) -> bool {
        self.loyalty(id) >= LOYALTY_ABSOLUTE_THRESHOLD
    }

    /// 两将领之间是否存在积极敌意（含等于阈值边界）
    pub fn are_hostile(&self, a: &str, b: &str) -> bool {
        self.relationship(a, b) <= RELATIONSHIP_HOSTILE_THRESHOLD
    }

    /// 计算内伊倒戈的触发状态
    pub fn ney_defection_condition(&self) -> NeyDefectionCondition {
        NeyDefectionCondition {
            ney_loyalty_to_bourbon:    100.0 - self.loyalty("ney"),  // 反转：对拿破仑忠诚高 → 对波旁低
            ney_relationship_napoleon: self.relationship("ney", "napoleon"),
            napoleon_reputation:       self.loyalty("napoleon"),  // 借用napoleon字段表示声望
        }
    }

    /// 当前危机将领列表（忠诚度低于阈值）
    pub fn crisis_generals(&self) -> Vec<(&str, f64)> {
        self.loyalty
            .iter()
            .filter(|(_, &v)| v < LOYALTY_CRISIS_THRESHOLD)
            .map(|(k, &v)| (k.as_str(), v))
            .collect()
    }

    /// 从 characters.json 数据填充网络（简化版，接收(id, loyalty)对列表）
    pub fn populate_from_data(&mut self, generals: &[(&str, f64)], relationships: &[(&str, &str, f64)]) {
        for &(id, loyalty) in generals {
            self.add_general(id, loyalty);
        }
        for &(a, b, value) in relationships {
            self.set_relationship(a, b, value);
        }
    }
}

/// 规范化关系键（字典序小者在前，确保双向查询一致）
fn relationship_key(a: &str, b: &str) -> (String, String) {
    if a <= b {
        (a.to_string(), b.to_string())
    } else {
        (b.to_string(), a.to_string())
    }
}

// ── 历史场景初始化 ─────────────────────────────────────

/// 创建百日王朝开始时的历史将领网络（Day 1 初始状态）
pub fn historical_network_day1() -> CharacterNetwork {
    let mut net = CharacterNetwork::new();

    // 将领初始忠诚度（来自 characters.json）
    net.populate_from_data(
        &[
            ("napoleon",  100.0), // 自身，用于存储"拿破仑声望"
            ("ney",        65.0),
            ("grouchy",    72.0),
            ("davout",     88.0),
            ("soult",      70.0),
            ("fouche",     45.0), // 警察部长，首鼠两端
            ("carnot",     75.0),
        ],
        &[
            // 正向关系（历史友谊/盟友）
            ("napoleon", "ney",     70.0),
            ("napoleon", "davout",  85.0),
            ("napoleon", "soult",   65.0),
            ("napoleon", "grouchy", 60.0),
            ("davout",   "carnot",  55.0),
            // 负向关系（历史矛盾）
            ("ney",      "grouchy", -30.0),  // 互相不信任
            ("fouche",   "napoleon", 20.0),  // 表面合作，暗中观望
        ],
    );

    net
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_abs_diff_eq;

    fn make_historical_net() -> CharacterNetwork {
        historical_network_day1()
    }

    // ── 基础操作 ──────────────────────────────────────

    #[test]
    fn 添加将领并查询忠诚度() {
        let mut net = CharacterNetwork::new();
        net.add_general("ney", 65.0);
        assert_abs_diff_eq!(net.loyalty("ney"), 65.0, epsilon = 0.001);
    }

    #[test]
    fn 忠诚度钳制在0到100() {
        let mut net = CharacterNetwork::new();
        net.add_general("ney", 65.0);
        net.modify_loyalty("ney", 200.0, 1, "test");
        assert_abs_diff_eq!(net.loyalty("ney"), 100.0, epsilon = 0.001);
        net.modify_loyalty("ney", -999.0, 1, "test");
        assert_abs_diff_eq!(net.loyalty("ney"), 0.0, epsilon = 0.001);
    }

    #[test]
    fn 关系值双向查询一致() {
        let net = make_historical_net();
        assert_abs_diff_eq!(
            net.relationship("ney", "napoleon"),
            net.relationship("napoleon", "ney"),
            epsilon = 0.001
        );
    }

    #[test]
    fn 未知将领默认忠诚度50() {
        let net = CharacterNetwork::new();
        assert_abs_diff_eq!(net.loyalty("unknown"), 50.0, epsilon = 0.001);
    }

    // ── 战斗结果影响 ──────────────────────────────────

    #[test]
    fn 决定性胜利大幅提升忠诚度() {
        let mut net = make_historical_net();
        let before = net.loyalty("ney");
        net.apply_battle_outcome("ney", BattleResult::DecisiveVictory, 10);
        assert!(net.loyalty("ney") > before + 10.0);
    }

    #[test]
    fn 决定性失败大幅降低忠诚度() {
        let mut net = make_historical_net();
        let before = net.loyalty("ney");
        net.apply_battle_outcome("ney", BattleResult::DecisiveDefeat, 10);
        assert!(net.loyalty("ney") < before - 10.0);
    }

    #[test]
    fn 战平不影响忠诚度() {
        let mut net = make_historical_net();
        let before = net.loyalty("ney");
        net.apply_battle_outcome("ney", BattleResult::Stalemate, 10);
        assert_abs_diff_eq!(net.loyalty("ney"), before, epsilon = 0.001);
    }

    // ── 关系衰减 ──────────────────────────────────────

    #[test]
    fn 每日衰减使正向关系逐渐减弱() {
        let mut net = make_historical_net();
        let initial = net.relationship("napoleon", "davout"); // 85.0
        for _ in 0..10 {
            net.tick_day();
        }
        assert!(net.relationship("napoleon", "davout") < initial);
    }

    #[test]
    fn 每日衰减使负向关系逐渐减弱() {
        let mut net = make_historical_net();
        let initial = net.relationship("ney", "grouchy"); // -30.0
        for _ in 0..10 {
            net.tick_day();
        }
        // 负向关系绝对值应减小（向0靠近）
        assert!(net.relationship("ney", "grouchy") > initial);
    }

    // ── 危机判断 ──────────────────────────────────────

    #[test]
    fn 忠诚度低于阈值为危机状态() {
        let mut net = CharacterNetwork::new();
        net.add_general("fouche", 25.0);
        assert!(net.is_loyalty_crisis("fouche"));
    }

    #[test]
    fn 达武高忠诚度为绝对忠诚() {
        let net = make_historical_net();
        assert!(net.is_absolutely_loyal("davout"));
    }

    #[test]
    fn 内伊和格鲁希历史敌意() {
        let net = make_historical_net();
        assert!(net.are_hostile("ney", "grouchy"));
    }

    // ── 内伊倒戈场景 ──────────────────────────────────

    #[test]
    fn 内伊倒戈概率与关系正相关() {
        // 拿破仑声望高 + 内伊与拿破仑关系深 → 高倒戈概率
        let cond_high = NeyDefectionCondition {
            ney_loyalty_to_bourbon:     20.0,
            ney_relationship_napoleon:  85.0,
            napoleon_reputation:        80.0,
        };
        // 声望低 + 关系一般 → 低倒戈概率
        let cond_low = NeyDefectionCondition {
            ney_loyalty_to_bourbon:     70.0,
            ney_relationship_napoleon:  55.0,
            napoleon_reputation:        40.0,
        };
        assert!(cond_high.defection_probability() > cond_low.defection_probability());
        assert!(cond_high.defection_probability() > 0.5);
    }

    #[test]
    fn 内伊关系不足时不会倒戈() {
        let cond = NeyDefectionCondition {
            ney_loyalty_to_bourbon:     10.0,
            ney_relationship_napoleon:  40.0, // 低于50阈值
            napoleon_reputation:        90.0,
        };
        assert_abs_diff_eq!(cond.defection_probability(), 0.0, epsilon = 0.001);
    }

    #[test]
    fn 历史网络内伊倒戈场景概率合理() {
        let net = make_historical_net();
        let cond = net.ney_defection_condition();
        let prob = cond.defection_probability();
        // 初始状态：内伊忠诚度65（对拿破仑），与拿破仑关系70 → 有倒戈可能
        assert!(prob > 0.3, "初始状态内伊应有一定倒戈概率: {:.2}", prob);
    }

    // ── 格鲁希增援场景 ────────────────────────────────

    #[test]
    fn 格鲁希距离过远无法及时增援() {
        let cond = GrouchyArrivalCondition {
            grouchy_loyalty:        72.0,
            communication_distance: 6,   // 超过4节点上限
            day:                    94,
        };
        assert_abs_diff_eq!(cond.arrival_probability(), 0.0, epsilon = 0.001);
    }

    #[test]
    fn 格鲁希近距离高忠诚有一定增援概率() {
        let cond = GrouchyArrivalCondition {
            grouchy_loyalty:        90.0,
            communication_distance: 2,
            day:                    93,
        };
        assert!(cond.arrival_probability() > 0.0);
    }

    // ── 审计日志 ──────────────────────────────────────

    #[test]
    fn 忠诚度变化被记录到日志() {
        let mut net = make_historical_net();
        net.modify_loyalty("ney", 5.0, 10, "battle_victory");
        assert_eq!(net.loyalty_log.len(), 1);
        assert_eq!(net.loyalty_log[0].general_id, "ney");
        assert_abs_diff_eq!(net.loyalty_log[0].delta, 5.0, epsilon = 0.001);
    }

    #[test]
    fn 危机将领列表正确识别() {
        let mut net = CharacterNetwork::new();
        net.add_general("fouche", 25.0); // 危机
        net.add_general("davout", 88.0); // 正常
        net.add_general("ney",    28.0); // 危机

        let crisis = net.crisis_generals();
        assert_eq!(crisis.len(), 2);
        let ids: Vec<&str> = crisis.iter().map(|&(id, _)| id).collect();
        assert!(ids.contains(&"fouche"));
        assert!(ids.contains(&"ney"));
    }
}
