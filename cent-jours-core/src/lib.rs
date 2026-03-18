//! cent-jours-core — Cent Jours 核心游戏逻辑库
//!
//! # 架构
//! - **纯Rust层**：battle / march / politics / characters / simulation
//! - **GDExtension层**（feature = "godot-extension"）：
//!   暴露 `BattleEngine`、`PoliticsEngine`、`CharacterManager` 给 Godot 4

pub mod battle;
pub mod characters;
pub mod engine;
pub mod events;
pub mod narratives;
pub mod politics;
pub mod simulation;

// ── GDExtension 绑定层 ────────────────────────────────────
// 仅在 `cargo build --features godot-extension` 时编译

#[cfg(feature = "godot-extension")]
mod gdext_bindings {
    use godot::prelude::*;

    use crate::battle::resolver::{ForceData, Terrain, resolve_battle};
    use crate::politics::system::{PoliticsState, default_policies};
    use crate::characters::order_deviation::{GeneralData, Temperament, calculate_deviation};

    struct CentJoursExtension;

    #[gdextension]
    unsafe impl ExtensionLibrary for CentJoursExtension {}

    // ── BattleEngine ──────────────────────────────────────

    /// GDExtension节点：战斗解算引擎
    ///
    /// GDScript 用法：
    /// ```gdscript
    /// var engine = BattleEngine.new()
    /// var result = engine.resolve(attacker_dict, defender_dict, terrain_str)
    /// ```
    #[derive(GodotClass)]
    #[class(base = RefCounted)]
    pub struct BattleEngine {
        base: Base<RefCounted>,
    }

    #[godot_api]
    impl IRefCounted for BattleEngine {
        fn init(base: Base<RefCounted>) -> Self {
            Self { base }
        }
    }

    #[godot_api]
    impl BattleEngine {
        /// 解算战斗，返回包含战果的 Dictionary
        ///
        /// attacker/defender 各为 Dictionary，包含键：
        ///   troops(int), morale(float), fatigue(float),
        ///   general_skill(float), supply_ok(bool)
        ///
        /// terrain 为字符串：plains / hills / forest / urban /
        ///         river_crossing / ridgeline
        #[func]
        pub fn resolve(&self, attacker: Dictionary, defender: Dictionary, terrain: GString) -> Dictionary {
            let mut rng = rand::thread_rng();

            let attacker_force = dict_to_force(&attacker);
            let defender_force = dict_to_force(&defender);
            let terrain_val    = str_to_terrain(terrain.to_string().as_str());

            let outcome = resolve_battle(&attacker_force, &defender_force, terrain_val, &mut rng);

            let mut result = Dictionary::new();
            result.insert("result",          outcome.result.as_str());
            result.insert("attacker_score",  outcome.attacker_score);
            result.insert("defender_score",  outcome.defender_score);
            result.insert("random_factor",   outcome.random_factor);

            let (atk_cas, def_cas) = outcome.result.casualty_rates();
            result.insert("attacker_casualty_rate", atk_cas);
            result.insert("defender_casualty_rate", def_cas);

            let (atk_mor, def_mor) = outcome.result.morale_deltas();
            result.insert("attacker_morale_delta", atk_mor);
            result.insert("defender_morale_delta", def_mor);

            result
        }
    }

    fn dict_to_force(d: &Dictionary) -> ForceData {
        ForceData {
            troops:        d.get("troops").map(|v| i64::from(v) as u32).unwrap_or(1000),
            morale:        d.get("morale").map(|v| f64::from(v)).unwrap_or(70.0),
            fatigue:       d.get("fatigue").map(|v| f64::from(v)).unwrap_or(20.0),
            general_skill: d.get("general_skill").map(|v| f64::from(v)).unwrap_or(60.0),
            supply_ok:     d.get("supply_ok").map(|v| bool::from(v)).unwrap_or(true),
        }
    }

    fn str_to_terrain(s: &str) -> Terrain {
        match s {
            "hills"          => Terrain::Hills,
            "forest"         => Terrain::Forest,
            "urban"          => Terrain::Urban,
            "river_crossing" => Terrain::RiverCrossing,
            "ridgeline"      => Terrain::Ridgeline,
            _                => Terrain::Plains,
        }
    }

    // ── PoliticsEngine ────────────────────────────────────

    /// GDExtension节点：政治系统引擎（有状态，整局存活）
    #[derive(GodotClass)]
    #[class(base = RefCounted)]
    pub struct PoliticsEngine {
        base:  Base<RefCounted>,
        state: PoliticsState,
    }

    #[godot_api]
    impl IRefCounted for PoliticsEngine {
        fn init(base: Base<RefCounted>) -> Self {
            Self { base, state: PoliticsState::default() }
        }
    }

    #[godot_api]
    impl PoliticsEngine {
        /// 每日结算（Godot 每回合结束时调用）
        #[func]
        pub fn daily_tick(&mut self) {
            self.state.daily_tick();
        }

        /// 执行政策；返回 { "ok": bool, "error": String }
        #[func]
        pub fn enact_policy(&mut self, policy_id: GString) -> Dictionary {
            let policies = default_policies();
            let mut out = Dictionary::new();

            if let Some(p) = policies.iter().find(|p| p.id == policy_id.to_string().as_str()) {
                match self.state.enact_policy(p) {
                    Ok(())  => { out.insert("ok", true);  out.insert("error", ""); }
                    Err(e)  => { out.insert("ok", false); out.insert("error", e); }
                }
            } else {
                out.insert("ok", false);
                out.insert("error", format!("未知政策: {}", policy_id));
            }
            out
        }

        /// 获取当前政治状态快照
        #[func]
        pub fn get_state(&self) -> Dictionary {
            let mut d = Dictionary::new();
            d.insert("rouge_noir_index",  self.state.rouge_noir_index);
            d.insert("legitimacy",        self.state.legitimacy);
            d.insert("economic_index",    self.state.economic_index);
            d.insert("actions_remaining", self.state.actions_remaining as i64);
            d.insert("is_collapsed",      self.state.is_collapsed());

            let mut factions = Dictionary::new();
            for (k, v) in &self.state.faction_support {
                factions.insert(k.as_str(), *v);
            }
            d.insert("factions", factions);
            d
        }

        /// 修改派系支持度（战斗胜负等外部事件触发）
        #[func]
        pub fn modify_faction(&mut self, faction_id: GString, delta: f64) {
            self.state.modify_faction(faction_id.to_string().as_str(), delta);
        }
    }

    // ── CharacterManager ──────────────────────────────────

    /// GDExtension节点：将领命令偏差计算器
    #[derive(GodotClass)]
    #[class(base = RefCounted)]
    pub struct CharacterManager {
        base: Base<RefCounted>,
    }

    #[godot_api]
    impl IRefCounted for CharacterManager {
        fn init(base: Base<RefCounted>) -> Self {
            Self { base }
        }
    }

    #[godot_api]
    impl CharacterManager {
        /// 计算将领命令偏差，返回 DeviationResult Dictionary
        #[func]
        pub fn calculate_deviation(
            &self,
            general: Dictionary,
            communication_distance: i64,
            battlefield_chaos: f64,
        ) -> Dictionary {
            let mut rng = rand::thread_rng();

            let temperament_str = general.get("temperament")
                .map(|v| GString::from(v).to_string())
                .unwrap_or_default();

            let general_data = GeneralData {
                id:             general.get("id").map(|v| GString::from(v).to_string()).unwrap_or_default(),
                name:           general.get("name").map(|v| GString::from(v).to_string()).unwrap_or_default(),
                loyalty:        general.get("loyalty").map(|v| f64::from(v)).unwrap_or(50.0),
                temperament:    Temperament::from_str(&temperament_str),
                military_skill: general.get("military_skill").map(|v| f64::from(v)).unwrap_or(60.0),
            };

            let result = calculate_deviation(
                &general_data,
                communication_distance as u32,
                battlefield_chaos,
                &mut rng,
            );

            let mut d = Dictionary::new();
            d.insert("general_id",       result.general_id.as_str());
            d.insert("general_name",     result.general_name.as_str());
            d.insert("timing_deviation", result.timing_deviation);
            d.insert("force_deviation",  result.force_deviation);
            d.insert("order_followed",   result.order_followed);
            d.insert("base_reliability", result.base_reliability);
            d.insert("distance_penalty", result.distance_penalty);
            d.insert("narrative",        result.narrative().as_str());
            d
        }
    }

    // ── CentJoursEngine ───────────────────────────────────

    /// GDExtension节点：统一游戏引擎（整局存活，有状态）
    ///
    /// GDScript 用法：
    /// ```gdscript
    /// var engine = CentJoursEngine.new()
    /// engine.process_day_rest()
    /// var report = engine.get_last_report()   # { stendhal, consequence }
    /// var state  = engine.get_state()         # { day, legitimacy, troops, ... }
    /// ```
    #[derive(GodotClass)]
    #[class(base = RefCounted)]
    pub struct CentJoursEngine {
        base:   Base<RefCounted>,
        engine: crate::engine::GameEngine,
        rng:    rand::rngs::StdRng,
    }

    #[godot_api]
    impl IRefCounted for CentJoursEngine {
        fn init(base: Base<RefCounted>) -> Self {
            use rand::SeedableRng;
            Self {
                base,
                engine: crate::engine::GameEngine::new(),
                rng:    rand::rngs::StdRng::from_entropy(),
            }
        }
    }

    #[godot_api]
    impl CentJoursEngine {
        // ── 行动接口 ─────────────────────────────────────

        /// 推进一天：玩家休整
        #[func]
        pub fn process_day_rest(&mut self) {
            use crate::engine::PlayerAction;
            self.engine.process_day(PlayerAction::Rest, &mut self.rng);
        }

        /// 推进一天：发动战役
        /// general_id: 将领ID字符串，troops: 投入兵力，terrain: 地形字符串
        #[func]
        pub fn process_day_battle(&mut self, general_id: GString, troops: i64, terrain: GString) {
            use crate::engine::PlayerAction;
            use crate::battle::resolver::Terrain as T;
            let t = match terrain.to_string().as_str() {
                "hills"          => T::Hills,
                "forest"         => T::Forest,
                "urban"          => T::Urban,
                "river_crossing" => T::RiverCrossing,
                "ridgeline"      => T::Ridgeline,
                _                => T::Plains,
            };
            self.engine.process_day(PlayerAction::LaunchBattle {
                general_id: general_id.to_string(),
                troops:     troops.max(0) as u32,
                terrain:    t,
            }, &mut self.rng);
        }

        /// 推进一天：颁布政策
        /// policy_id: 政策ID（如 "conscription", "constitutional_promise" 等）
        #[func]
        pub fn process_day_policy(&mut self, policy_id: GString) {
            use crate::engine::PlayerAction;
            // GDScript传来的是String，需要转为&'static str
            // 通过内联匹配实现（避免生命周期问题）
            let action = match policy_id.to_string().as_str() {
                "conscription"             => PlayerAction::EnactPolicy { policy_id: "conscription" },
                "constitutional_promise"   => PlayerAction::EnactPolicy { policy_id: "constitutional_promise" },
                "public_speech"            => PlayerAction::EnactPolicy { policy_id: "public_speech" },
                "reduce_taxes"             => PlayerAction::EnactPolicy { policy_id: "reduce_taxes" },
                "increase_military_budget" => PlayerAction::EnactPolicy { policy_id: "increase_military_budget" },
                _ => PlayerAction::Rest,
            };
            self.engine.process_day(action, &mut self.rng);
        }

        /// 推进一天：强化将领忠诚度
        #[func]
        pub fn process_day_boost_loyalty(&mut self, general_id: GString) {
            use crate::engine::PlayerAction;
            self.engine.process_day(PlayerAction::BoostLoyalty {
                general_id: general_id.to_string(),
            }, &mut self.rng);
        }

        // ── 状态查询 ─────────────────────────────────────

        /// 获取当前引擎状态快照
        /// 返回 Dictionary，包含 day, legitimacy, rouge_noir, troops, victories,
        ///   is_over, outcome, faction_support(Dict)
        #[func]
        pub fn get_state(&self) -> Dictionary {
            let e = &self.engine;
            let mut d = Dictionary::new();
            d.insert("day",         e.day as i64);
            d.insert("legitimacy",  e.politics.legitimacy);
            d.insert("rouge_noir",  e.politics.rouge_noir_index);
            d.insert("troops",      e.army.total_troops as i64);
            d.insert("morale",      e.army.avg_morale);
            d.insert("fatigue",     e.army.avg_fatigue);
            d.insert("victories",   e.army.victories as i64);
            d.insert("is_over",     e.is_over());
            d.insert("outcome",     e.outcome()
                .map(|o| o.as_str())
                .unwrap_or("in_progress"));

            let mut factions = Dictionary::new();
            for (k, v) in &e.politics.faction_support {
                factions.insert(k.as_str(), *v);
            }
            d.insert("factions", factions);
            d
        }

        /// 获取最近一天的叙事报告
        /// 返回 Dictionary：{ "stendhal": String|null, "consequence": String|null, "day": int }
        #[func]
        pub fn get_last_report(&self) -> Dictionary {
            let mut d = Dictionary::new();
            match self.engine.last_report() {
                Some(r) => {
                    d.insert("day",         r.day as i64);
                    d.insert("stendhal",    r.stendhal.as_deref().unwrap_or(""));
                    d.insert("consequence", r.consequence.as_deref().unwrap_or(""));
                    d.insert("has_narrative", r.stendhal.is_some());
                }
                None => {
                    d.insert("day",           0i64);
                    d.insert("stendhal",      "");
                    d.insert("consequence",   "");
                    d.insert("has_narrative", false);
                }
            }
            d
        }

        /// 获取已触发的历史事件 ID 列表（Array of String）
        #[func]
        pub fn get_triggered_events(&self) -> Array<GString> {
            self.engine.triggered_events()
                .iter()
                .map(|s| GString::from(s.as_str()))
                .collect()
        }

        /// 游戏是否已结束
        #[func]
        pub fn is_over(&self) -> bool {
            self.engine.is_over()
        }

        /// 当前天数
        #[func]
        pub fn current_day(&self) -> i64 {
            self.engine.current_day() as i64
        }
    }
}
