//! 叙事引擎 — `narratives`
//!
//! 加载 stendhal_diary.json 和 consequences.json，
//! 根据玩家行动类型随机抽取叙事文本。
//! GameEngine 通过 `last_report()` 把结果暴露给 Godot UI。

use rand::Rng;
use std::collections::HashMap;

// ── JSON 结构（{ "action_type": ["text1", "text2", ...] }）─────────────────

type NarrativeMap = HashMap<String, Vec<String>>;

// ── 叙事池 ────────────────────────────────────────────────────────────────

/// 双文本池：司汤达日记 + 微叙事后果片段
pub struct NarrativePool {
    stendhal: NarrativeMap,
    consequences: NarrativeMap,
}

impl NarrativePool {
    /// 从嵌入的 JSON 文件构建池（生产用）
    pub fn new() -> Self {
        const STENDHAL_JSON: &str =
            include_str!("../../../src/data/narratives/stendhal_diary.json");
        const CONSEQUENCES_JSON: &str =
            include_str!("../../../src/data/narratives/consequences.json");

        Self {
            stendhal: serde_json::from_str(STENDHAL_JSON).expect("stendhal_diary.json parse error"),
            consequences: serde_json::from_str(CONSEQUENCES_JSON)
                .expect("consequences.json parse error"),
        }
    }

    /// 查询某行动类型的司汤达条目数（测试辅助）
    pub fn stendhal_count(&self, action_type: &str) -> usize {
        self.stendhal.get(action_type).map(|v| v.len()).unwrap_or(0)
    }

    /// 查询某行动类型的后果条目数（测试辅助）
    pub fn consequence_count(&self, action_type: &str) -> usize {
        self.consequences
            .get(action_type)
            .map(|v| v.len())
            .unwrap_or(0)
    }

    /// 随机抽取一条司汤达日记文本；action_type 未知则返回 None
    pub fn pick_stendhal<R: Rng>(&self, action_type: &str, rng: &mut R) -> Option<String> {
        let pool = self.stendhal.get(action_type)?;
        if pool.is_empty() {
            return None;
        }
        Some(pool[rng.gen_range(0..pool.len())].clone())
    }

    /// 随机抽取一条后果片段文本；action_type 未知则返回 None
    pub fn pick_consequence<R: Rng>(&self, action_type: &str, rng: &mut R) -> Option<String> {
        let pool = self.consequences.get(action_type)?;
        if pool.is_empty() {
            return None;
        }
        Some(pool[rng.gen_range(0..pool.len())].clone())
    }
}

impl Default for NarrativePool {
    fn default() -> Self {
        Self::new()
    }
}

// ── 行动类型 → 叙事 key 映射 ─────────────────────────────────────────────

/// 将 PlayerAction 字符串标识映射为叙事 key。
/// 战斗的 key 取决于胜负，由调用方传入。
pub fn policy_narrative_key(policy_id: &str) -> Option<&'static str> {
    match policy_id {
        "conscription" => Some("conscription"),
        "constitutional_promise" => Some("constitutional_promise"),
        "public_speech" => Some("public_speech"),
        "reduce_taxes" => Some("reduce_taxes"),
        "increase_military_budget" => Some("increase_military_budget"),
        "requisition_supplies" => Some("requisition_supplies"),
        "stabilize_supply_lines" => Some("stabilize_supply_lines"),
        "grant_titles" => Some("grant_titles"),
        "secret_diplomacy" => Some("diplomatic_secret"),
        "print_money" => Some("print_money"),
        _ => None,
    }
}

// ── 单元测试 ──────────────────────────────────────────────────────────────

#[cfg(test)]
#[allow(non_snake_case)]
mod tests {
    use super::*;
    use rand::rngs::StdRng;
    use rand::SeedableRng;

    fn seeded_rng() -> StdRng {
        StdRng::seed_from_u64(42)
    }

    // ── 加载 ──────────────────────────────────────────

    #[test]
    fn 叙事池加载成功() {
        let pool = NarrativePool::new();
        // 两个 JSON 都应有内容
        assert!(
            pool.stendhal_count("conscription") > 0,
            "stendhal_diary: conscription 应有条目"
        );
        assert!(
            pool.consequence_count("conscription") > 0,
            "consequences: conscription 应有条目"
        );
    }

    #[test]
    fn 司汤达13个行动类型全部有内容() {
        let pool = NarrativePool::new();
        for key in &[
            "conscription",
            "constitutional_promise",
            "public_speech",
            "battle_victory",
            "battle_defeat",
            "reduce_taxes",
            "boost_loyalty",
            "diplomatic_secret",
            "grant_titles",
            "increase_military_budget",
            "requisition_supplies",
            "stabilize_supply_lines",
            "print_money",
        ] {
            assert!(
                pool.stendhal_count(key) > 0,
                "stendhal_diary 缺少 '{}' 的条目",
                key
            );
        }
    }

    #[test]
    fn 后果14个类型全部有内容() {
        let pool = NarrativePool::new();
        for key in &[
            "conscription",
            "reduce_taxes",
            "forced_march",
            "battle_victory",
            "battle_defeat",
            "constitutional_promise",
            "public_speech",
            "boost_loyalty",
            "grant_titles",
            "increase_military_budget",
            "requisition_supplies",
            "stabilize_supply_lines",
            "diplomatic_secret",
            "print_money",
        ] {
            assert!(
                pool.consequence_count(key) > 0,
                "consequences 缺少 '{}' 的条目",
                key
            );
        }
    }

    // ── 抽取 ──────────────────────────────────────────

    #[test]
    fn 已知类型返回非空文本() {
        let pool = NarrativePool::new();
        let mut rng = seeded_rng();
        let text = pool.pick_stendhal("conscription", &mut rng);
        assert!(text.is_some(), "conscription 应返回司汤达文本");
        assert!(!text.unwrap().is_empty(), "文本不应为空字符串");
    }

    #[test]
    fn 未知类型返回None不崩溃() {
        let pool = NarrativePool::new();
        let mut rng = seeded_rng();
        assert!(pool.pick_stendhal("nonexistent_action", &mut rng).is_none());
        assert!(pool
            .pick_consequence("nonexistent_action", &mut rng)
            .is_none());
    }

    #[test]
    fn 多次抽取能取到不同文本() {
        let pool = NarrativePool::new();
        let mut rng = StdRng::seed_from_u64(0);
        // 抽 20 次，应当出现多于 1 种结果（5 个变体）
        let results: std::collections::HashSet<String> = (0..20)
            .filter_map(|_| pool.pick_stendhal("conscription", &mut rng))
            .collect();
        assert!(
            results.len() > 1,
            "多次抽取应出现多种变体，实际只有 {} 种",
            results.len()
        );
    }

    // ── policy_narrative_key 映射 ─────────────────────

    #[test]
    fn 政策key映射正确() {
        assert_eq!(policy_narrative_key("conscription"), Some("conscription"));
        assert_eq!(policy_narrative_key("public_speech"), Some("public_speech"));
        assert_eq!(
            policy_narrative_key("increase_military_budget"),
            Some("increase_military_budget")
        );
        assert_eq!(
            policy_narrative_key("requisition_supplies"),
            Some("requisition_supplies")
        );
        assert_eq!(
            policy_narrative_key("stabilize_supply_lines"),
            Some("stabilize_supply_lines")
        );
        assert_eq!(policy_narrative_key("grant_titles"), Some("grant_titles"));
        assert_eq!(
            policy_narrative_key("secret_diplomacy"),
            Some("diplomatic_secret")
        );
        assert_eq!(policy_narrative_key("print_money"), Some("print_money"));
        assert_eq!(policy_narrative_key("unknown_policy"), None);
    }

    // ── 键名契约验证：映射函数的所有返回键在 JSON 中必须存在 ──────────

    /// 所有在 policy_narrative_key() 中声明的映射，
    /// 其目标 key 必须在 stendhal_diary.json 中有对应条目。
    /// 防止：政策表改了 key 但 JSON 忘更新 → 运行时静默返回 None。
    #[test]
    fn policy_narrative_key所有映射结果在stendhal中有条目() {
        let pool = NarrativePool::new();
        // 所有已注册的 policy_id
        let policy_ids = [
            "conscription",
            "constitutional_promise",
            "public_speech",
            "reduce_taxes",
            "increase_military_budget",
            "requisition_supplies",
            "stabilize_supply_lines",
            "grant_titles",
            "secret_diplomacy",
            "print_money",
        ];
        for pid in &policy_ids {
            let key = policy_narrative_key(pid)
                .unwrap_or_else(|| panic!("policy_id '{}' 未在 policy_narrative_key 中注册", pid));
            assert!(
                pool.stendhal_count(key) > 0,
                "policy '{}' → key '{}' 在 stendhal_diary.json 中无条目，pick_stendhal 将静默失败",
                pid,
                key
            );
        }
    }

    /// 所有在 policy_narrative_key() 中声明的映射，
    /// 其目标 key 必须在 consequences.json 中有对应条目。
    #[test]
    fn policy_narrative_key所有映射结果在consequences中有条目() {
        let pool = NarrativePool::new();
        let policy_ids = [
            "conscription",
            "constitutional_promise",
            "public_speech",
            "reduce_taxes",
            "increase_military_budget",
            "requisition_supplies",
            "stabilize_supply_lines",
            "grant_titles",
            "secret_diplomacy",
            "print_money",
        ];
        for pid in &policy_ids {
            let key = policy_narrative_key(pid).unwrap();
            assert!(
                pool.consequence_count(key) > 0,
                "policy '{}' → key '{}' 在 consequences.json 中无条目，pick_consequence 将静默失败",
                pid,
                key
            );
        }
    }
}
