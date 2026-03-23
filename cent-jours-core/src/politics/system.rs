//! 政治系统：Rouge/Noir 双指针 + 四势力支持度模型

use std::collections::HashMap;

// ── 常量 ──────────────────────────────────────────────

pub const CRISIS_THRESHOLD: f64 = 10.0; // 任何势力跌破此值 → 政治危机风险
pub const FACTION_IDS: [&str; 4] = ["liberals", "nobility", "populace", "military"];

/// 各势力自然均衡值（无外力时每日缓慢向此靠拢）
pub const FACTION_EQUILIBRIUM: [(&str, f64); 4] = [
    ("liberals", 40.0),
    ("nobility", 35.0),
    ("populace", 50.0),
    ("military", 55.0),
];

/// 合法性加权（四势力的权重）
pub const FACTION_WEIGHTS: [(&str, f64); 4] = [
    ("liberals", 0.25),
    ("nobility", 0.20),
    ("populace", 0.30),
    ("military", 0.25),
];

pub const FACTION_RECOVERY_RATE: f64 = 0.8; // 每日均衡恢复速率（提升：帮助军事策略恢复政治稳定）

// ── 政策结构 ──────────────────────────────────────────

/// 一个政策行动的效果定义
#[derive(Debug, Clone)]
pub struct PolicyEffect {
    pub id: &'static str,
    pub name: &'static str,
    pub cost_actions: u8,
    pub rouge_noir_delta: f64,
    pub faction_deltas: HashMap<&'static str, f64>,
    pub economic_delta: f64,
    pub cooldown_days: u8,
}

/// 内置政策表
pub fn default_policies() -> Vec<PolicyEffect> {
    vec![
        PolicyEffect {
            id: "conscription",
            name: "颁布征兵令",
            cost_actions: 1,
            rouge_noir_delta: 5.0,
            faction_deltas: [("military", 10.0), ("populace", -8.0), ("liberals", -3.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: -5.0,
            cooldown_days: 5,
        },
        PolicyEffect {
            id: "constitutional_promise",
            name: "承诺宪政改革",
            cost_actions: 1,
            rouge_noir_delta: -8.0,
            faction_deltas: [("liberals", 15.0), ("nobility", -5.0), ("populace", 5.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: 0.0,
            cooldown_days: 10,
        },
        PolicyEffect {
            id: "public_speech",
            name: "发表公开演说",
            cost_actions: 1,
            rouge_noir_delta: 3.0,
            faction_deltas: [("populace", 12.0), ("nobility", -3.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: 0.0,
            cooldown_days: 3,
        },
        PolicyEffect {
            id: "grant_titles",
            name: "授予贵族头衔",
            cost_actions: 1,
            rouge_noir_delta: -5.0,
            faction_deltas: [("nobility", 12.0), ("liberals", -5.0), ("populace", -3.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: 0.0,
            cooldown_days: 7,
        },
        PolicyEffect {
            id: "reduce_taxes",
            name: "减税措施",
            cost_actions: 1,
            rouge_noir_delta: 0.0,
            faction_deltas: [("populace", 10.0), ("liberals", 3.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: -8.0,
            cooldown_days: 8,
        },
        PolicyEffect {
            id: "increase_military_budget",
            name: "增加军费",
            cost_actions: 1,
            rouge_noir_delta: 4.0,
            faction_deltas: [("military", 15.0), ("liberals", -5.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: -10.0,
            cooldown_days: 5,
        },
        PolicyEffect {
            id: "secret_diplomacy",
            name: "秘密外交",
            cost_actions: 2,
            rouge_noir_delta: -3.0,
            faction_deltas: HashMap::new(),
            economic_delta: 0.0,
            cooldown_days: 15,
        },
        PolicyEffect {
            id: "print_money",
            name: "印钞应急",
            cost_actions: 1,
            rouge_noir_delta: 8.0,
            faction_deltas: [("populace", -5.0), ("liberals", -8.0), ("nobility", -5.0)]
                .iter()
                .cloned()
                .collect(),
            economic_delta: 15.0,
            cooldown_days: 20,
        },
    ]
}

// ── 政治系统状态 ──────────────────────────────────────

#[derive(Debug, Clone)]
pub struct PoliticsState {
    /// -100（极端Rouge）到 +100（极端Noir），0为均衡
    pub rouge_noir_index: f64,
    /// 四势力支持度（0-100）
    pub faction_support: HashMap<String, f64>,
    /// 整体合法性（四势力加权平均）
    pub legitimacy: f64,
    /// 经济指数（0-100）
    pub economic_index: f64,
    /// 政策冷却（policy_id → 剩余天数）
    cooldowns: HashMap<String, u8>,
    /// 当日剩余行动点
    pub actions_remaining: u8,
}

impl Default for PoliticsState {
    fn default() -> Self {
        let mut faction_support = HashMap::new();
        faction_support.insert("liberals".into(), 45.0);
        faction_support.insert("nobility".into(), 30.0);
        faction_support.insert("populace".into(), 65.0);
        faction_support.insert("military".into(), 70.0);

        let mut state = Self {
            rouge_noir_index: 0.0,
            faction_support,
            legitimacy: 0.0,
            economic_index: 50.0,
            cooldowns: HashMap::new(),
            actions_remaining: 2,
        };
        state.recalculate_legitimacy();
        state
    }
}

impl PoliticsState {
    /// 重新计算合法性（调用任何改变势力支持度的操作后调用）
    pub fn recalculate_legitimacy(&mut self) {
        self.legitimacy = FACTION_WEIGHTS
            .iter()
            .map(|(id, w)| self.faction_support.get(*id).copied().unwrap_or(0.0) * w)
            .sum();
    }

    /// 移动 Rouge/Noir 指针
    pub fn shift_rouge_noir(&mut self, delta: f64) {
        self.rouge_noir_index = (self.rouge_noir_index + delta).clamp(-100.0, 100.0);
    }

    /// 修改派系支持度（自动触发合法性重算）
    pub fn modify_faction(&mut self, faction_id: &str, delta: f64) {
        let current = self.faction_support.get(faction_id).copied().unwrap_or(0.0);
        let new_val = (current + delta).clamp(0.0, 100.0);
        self.faction_support.insert(faction_id.to_string(), new_val);
        self.recalculate_legitimacy();
    }

    /// 执行政策（返回执行成功与否及原因）
    pub fn enact_policy(&mut self, policy: &PolicyEffect) -> Result<(), String> {
        if self.actions_remaining < policy.cost_actions {
            return Err(format!(
                "行动点不足（需要{}，剩余{}）",
                policy.cost_actions, self.actions_remaining
            ));
        }
        if self.cooldowns.get(policy.id).copied().unwrap_or(0) > 0 {
            return Err(format!("政策冷却中（剩余{}天）", self.cooldowns[policy.id]));
        }

        self.actions_remaining -= policy.cost_actions;

        // 应用效果
        self.shift_rouge_noir(policy.rouge_noir_delta);
        for (faction_id, delta) in &policy.faction_deltas {
            // Rouge/Noir 对特定派系效果的放大
            let modified_delta = self.apply_rn_modifier(faction_id, *delta);
            self.modify_faction(faction_id, modified_delta);
        }
        self.economic_index = (self.economic_index + policy.economic_delta).clamp(0.0, 100.0);
        self.cooldowns
            .insert(policy.id.to_string(), policy.cooldown_days);

        Ok(())
    }

    /// Rouge/Noir 状态对派系效果的修正系数
    fn apply_rn_modifier(&self, faction_id: &str, base_delta: f64) -> f64 {
        let rn = self.rouge_noir_index;
        match faction_id {
            "populace" if rn > 0.0 => base_delta * (1.0 + rn / 200.0),
            "nobility" if rn < 0.0 => base_delta * (1.0 + (-rn) / 200.0),
            "military" if rn > 0.0 => base_delta * (1.0 + rn / 300.0),
            _ => base_delta,
        }
    }

    /// 每日结算（冷却递减 + 自然恢复 + 经济漂移）
    pub fn daily_tick(&mut self) {
        // 冷却递减
        for val in self.cooldowns.values_mut() {
            *val = val.saturating_sub(1);
        }
        self.cooldowns.retain(|_, v| *v > 0);

        // 自然恢复：向均衡值靠拢
        for (faction_id, eq) in FACTION_EQUILIBRIUM {
            let current = self.faction_support.get(faction_id).copied().unwrap_or(0.0);
            let new_val = if current < eq {
                (current + FACTION_RECOVERY_RATE).min(eq)
            } else {
                (current - FACTION_RECOVERY_RATE * 0.5).max(eq)
            };
            self.faction_support.insert(faction_id.to_string(), new_val);
        }
        self.recalculate_legitimacy();

        // 经济自然微弱恢复（Rouge过高时受损）
        let eco_drift = if self.rouge_noir_index > 30.0 {
            0.2
        } else {
            0.5
        };
        self.economic_index = (self.economic_index + eco_drift).min(100.0);

        // 重置行动点
        self.actions_remaining = if self.legitimacy >= 70.0 { 3 } else { 2 };
    }

    /// 获取政策冷却表（policy_id → 剩余天数），供 GDExtension 接口读取
    pub fn cooldowns(&self) -> &HashMap<String, u8> {
        &self.cooldowns
    }

    /// 检测危机：返回跌破 CRISIS_THRESHOLD 的势力列表
    pub fn critical_factions(&self) -> Vec<&str> {
        FACTION_IDS
            .iter()
            .filter(|id| {
                self.faction_support.get(**id).copied().unwrap_or(100.0) < CRISIS_THRESHOLD
            })
            .copied()
            .collect()
    }

    /// 是否触发政治崩溃（2个或以上势力跌破阈值）
    pub fn is_collapsed(&self) -> bool {
        self.critical_factions().len() >= 2
    }
}

// ── 单元测试 ──────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn fresh_state() -> PoliticsState {
        PoliticsState::default()
    }

    fn policy(id: &'static str) -> PolicyEffect {
        default_policies().into_iter().find(|p| p.id == id).unwrap()
    }

    #[test]
    fn 初始合法性计算正确() {
        let s = fresh_state();
        // 0.25*45 + 0.20*30 + 0.30*65 + 0.25*70 = 11.25+6+19.5+17.5 = 54.25
        assert!((s.legitimacy - 54.25).abs() < 0.01);
    }

    #[test]
    fn 征兵令提升军方降低民众() {
        let mut s = fresh_state();
        let p = policy("conscription");
        s.enact_policy(&p).unwrap();
        assert!(s.faction_support["military"] > 70.0);
        assert!(s.faction_support["populace"] < 65.0);
        assert!(s.rouge_noir_index > 0.0);
    }

    #[test]
    fn 宪政承诺降低rouge_noir() {
        let mut s = fresh_state();
        s.shift_rouge_noir(20.0); // 先让Rouge偏高
        let p = policy("constitutional_promise");
        s.enact_policy(&p).unwrap();
        assert!(s.rouge_noir_index < 20.0);
        assert!(s.faction_support["liberals"] > 45.0);
    }

    #[test]
    fn 行动点不足时政策失败() {
        let mut s = fresh_state();
        s.actions_remaining = 0;
        let p = policy("conscription");
        assert!(s.enact_policy(&p).is_err());
    }

    #[test]
    fn 政策冷却生效() {
        let mut s = fresh_state();
        let p = policy("public_speech"); // 冷却3天
        s.enact_policy(&p).unwrap();
        assert!(s.enact_policy(&p).is_err()); // 立即再执行应失败
                                              // 过3天后可再次执行
        s.daily_tick();
        s.daily_tick();
        s.daily_tick();
        assert!(s.enact_policy(&p).is_ok());
    }

    #[test]
    fn 派系支持不超出0到100范围() {
        let mut s = fresh_state();
        s.modify_faction("liberals", 200.0);
        assert_eq!(s.faction_support["liberals"], 100.0);
        s.modify_faction("liberals", -500.0);
        assert_eq!(s.faction_support["liberals"], 0.0);
    }

    #[test]
    fn 两派崩溃触发政治崩溃() {
        let mut s = fresh_state();
        s.modify_faction("liberals", -45.0); // → 0
        s.modify_faction("nobility", -30.0); // → 0
        assert!(s.is_collapsed());
    }

    #[test]
    fn 每日自然恢复向均衡值靠拢() {
        let mut s = fresh_state();
        s.modify_faction("populace", -30.0); // → 35 (均衡50)
        let before = s.faction_support["populace"];
        s.daily_tick();
        let after = s.faction_support["populace"];
        assert!(after > before, "应向均衡值恢复");
    }

    #[test]
    fn rouge_偏高时民众效果放大() {
        let mut s_neutral = fresh_state();
        let mut s_rouge = fresh_state();
        s_rouge.shift_rouge_noir(60.0); // 强烈偏Rouge

        let p = policy("public_speech"); // 含 populace +12

        let pop_before_neutral = s_neutral.faction_support["populace"];
        let pop_before_rouge = s_rouge.faction_support["populace"];
        s_neutral.enact_policy(&p).unwrap();
        s_rouge.enact_policy(&p).unwrap();

        let pop_gain_neutral = s_neutral.faction_support["populace"] - pop_before_neutral;
        let pop_gain_rouge = s_rouge.faction_support["populace"] - pop_before_rouge;
        assert!(
            pop_gain_rouge > pop_gain_neutral,
            "Rouge状态下民众效果应放大"
        );
    }
}
