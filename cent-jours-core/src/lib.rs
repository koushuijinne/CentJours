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

    use godot::prelude::VarDictionary as Dictionary;

    use crate::battle::resolver::{resolve_battle, ForceData, Terrain};
    use crate::characters::order_deviation::{calculate_deviation, GeneralData, Temperament};
    use crate::politics::system::{default_policies, PoliticsState};

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
        /// terrain 为字符串：plains / hills / mountains / forest / urban /
        ///         river_crossing / river_junction / coastal / fortress / ridgeline
        #[func]
        pub fn resolve(
            &self,
            attacker: Dictionary,
            defender: Dictionary,
            terrain: GString,
        ) -> Dictionary {
            let mut rng = rand::thread_rng();

            let attacker_force = dict_to_force(&attacker);
            let defender_force = dict_to_force(&defender);
            let terrain_val = str_to_terrain(terrain.to_string().as_str());

            let outcome = resolve_battle(&attacker_force, &defender_force, terrain_val, &mut rng);

            let mut result = Dictionary::new();
            let _ = result.insert("result", outcome.result.as_str());
            let _ = result.insert("ratio", outcome.ratio);
            let _ = result.insert("attacker_casualties", outcome.attacker_casualties as i64);
            let _ = result.insert("defender_casualties", outcome.defender_casualties as i64);
            let _ = result.insert("random_factor", outcome.random_factor);

            let (atk_cas, def_cas) = outcome.result.casualty_rates();
            let _ = result.insert("attacker_casualty_rate", atk_cas);
            let _ = result.insert("defender_casualty_rate", def_cas);

            let (atk_mor, def_mor) = outcome.result.morale_deltas();
            let _ = result.insert("attacker_morale_delta", atk_mor);
            let _ = result.insert("defender_morale_delta", def_mor);

            result
        }
    }

    fn dict_to_force(d: &Dictionary) -> ForceData {
        ForceData {
            troops: d
                .get("troops")
                .map(|v| v.to::<i64>() as u32)
                .unwrap_or(1000),
            morale: d.get("morale").map(|v| v.to::<f64>()).unwrap_or(70.0),
            fatigue: d.get("fatigue").map(|v| v.to::<f64>()).unwrap_or(20.0),
            general_skill: d
                .get("general_skill")
                .map(|v| v.to::<f64>())
                .unwrap_or(60.0),
            supply_ok: d.get("supply_ok").map(|v| v.to::<bool>()).unwrap_or(true),
        }
    }

    fn str_to_terrain(s: &str) -> Terrain {
        match s {
            "hills" => Terrain::Hills,
            "mountains" => Terrain::Mountains,
            "forest" => Terrain::Forest,
            "urban" => Terrain::Urban,
            "river_crossing" => Terrain::RiverJunction,
            "river_junction" => Terrain::RiverJunction,
            "coastal" => Terrain::Coastal,
            "fortress" => Terrain::Fortress,
            "ridgeline" => Terrain::Ridgeline,
            _ => Terrain::Plains,
        }
    }

    // ── PoliticsEngine ────────────────────────────────────

    /// GDExtension节点：政治系统引擎（有状态，整局存活）
    #[derive(GodotClass)]
    #[class(base = RefCounted)]
    pub struct PoliticsEngine {
        base: Base<RefCounted>,
        state: PoliticsState,
    }

    #[godot_api]
    impl IRefCounted for PoliticsEngine {
        fn init(base: Base<RefCounted>) -> Self {
            Self {
                base,
                state: PoliticsState::default(),
            }
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

            if let Some(p) = policies
                .iter()
                .find(|p| p.id == policy_id.to_string().as_str())
            {
                match self.state.enact_policy(p) {
                    Ok(()) => {
                        let _ = out.insert("ok", true);
                        let _ = out.insert("error", "");
                    }
                    Err(e) => {
                        let _ = out.insert("ok", false);
                        let _ = out.insert("error", e);
                    }
                }
            } else {
                let _ = out.insert("ok", false);
                let _ = out.insert("error", format!("未知政策: {}", policy_id));
            }
            out
        }

        /// 获取当前政治状态快照
        #[func]
        pub fn get_state(&self) -> Dictionary {
            let mut d = Dictionary::new();
            let _ = d.insert("rouge_noir_index", self.state.rouge_noir_index);
            let _ = d.insert("legitimacy", self.state.legitimacy);
            let _ = d.insert("economic_index", self.state.economic_index);
            let _ = d.insert("actions_remaining", self.state.actions_remaining as i64);
            let _ = d.insert("is_collapsed", self.state.is_collapsed());

            let mut factions = Dictionary::new();
            for (k, v) in &self.state.faction_support {
                let _ = factions.insert(k.as_str(), *v);
            }
            let _ = d.insert("factions", factions);
            d
        }

        /// 修改派系支持度（战斗胜负等外部事件触发）
        #[func]
        pub fn modify_faction(&mut self, faction_id: GString, delta: f64) {
            self.state
                .modify_faction(faction_id.to_string().as_str(), delta);
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

            let temperament_str = general
                .get("temperament")
                .map(|v| v.to::<GString>().to_string())
                .unwrap_or_default();

            let general_data = GeneralData {
                id: general
                    .get("id")
                    .map(|v| v.to::<GString>().to_string())
                    .unwrap_or_default(),
                name: general
                    .get("name")
                    .map(|v| v.to::<GString>().to_string())
                    .unwrap_or_default(),
                loyalty: general
                    .get("loyalty")
                    .map(|v| v.to::<f64>())
                    .unwrap_or(50.0),
                temperament: Temperament::from_str(&temperament_str),
                military_skill: general
                    .get("military_skill")
                    .map(|v| v.to::<f64>())
                    .unwrap_or(60.0),
            };

            let result = calculate_deviation(
                &general_data,
                communication_distance as u32,
                battlefield_chaos,
                &mut rng,
            );

            let mut d = Dictionary::new();
            let _ = d.insert("general_id", result.general_id.as_str());
            let _ = d.insert("general_name", result.general_name.as_str());
            let _ = d.insert("timing_deviation", result.timing_deviation);
            let _ = d.insert("force_deviation", result.force_deviation);
            let _ = d.insert("order_followed", result.order_followed);
            let _ = d.insert("base_reliability", result.base_reliability);
            let _ = d.insert("distance_penalty", result.distance_penalty);
            let _ = d.insert("narrative", result.narrative().as_str());
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
        base: Base<RefCounted>,
        engine: crate::engine::GameEngine,
        rng: rand::rngs::StdRng,
    }

    #[godot_api]
    impl IRefCounted for CentJoursEngine {
        fn init(base: Base<RefCounted>) -> Self {
            use rand::SeedableRng;
            Self {
                base,
                engine: crate::engine::GameEngine::new(),
                rng: rand::rngs::StdRng::from_entropy(),
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
            use crate::battle::resolver::Terrain as T;
            use crate::engine::PlayerAction;
            let t = match terrain.to_string().as_str() {
                "hills" => T::Hills,
                "mountains" => T::Mountains,
                "forest" => T::Forest,
                "urban" => T::Urban,
                "river_crossing" => T::RiverJunction,
                "river_junction" => T::RiverJunction,
                "coastal" => T::Coastal,
                "fortress" => T::Fortress,
                "ridgeline" => T::Ridgeline,
                _ => T::Plains,
            };
            self.engine.process_day(
                PlayerAction::LaunchBattle {
                    general_id: general_id.to_string(),
                    troops: troops.max(0) as u32,
                    terrain: t,
                },
                &mut self.rng,
            );
        }

        /// 推进一天：执行行军
        /// target_node: 相邻地图节点 ID
        #[func]
        pub fn process_day_march(&mut self, target_node: GString) {
            use crate::engine::PlayerAction;
            self.engine.process_day(
                PlayerAction::March {
                    target_node: target_node.to_string(),
                },
                &mut self.rng,
            );
        }

        /// 推进一天：颁布政策
        /// policy_id: 政策ID（如 "conscription", "constitutional_promise" 等）
        #[func]
        pub fn process_day_policy(&mut self, policy_id: GString) {
            use crate::engine::PlayerAction;
            // GDScript传来的是String，需要转为&'static str
            // 通过内联匹配实现（避免生命周期问题）
            let action = match policy_id.to_string().as_str() {
                "conscription" => PlayerAction::EnactPolicy {
                    policy_id: "conscription",
                },
                "constitutional_promise" => PlayerAction::EnactPolicy {
                    policy_id: "constitutional_promise",
                },
                "public_speech" => PlayerAction::EnactPolicy {
                    policy_id: "public_speech",
                },
                "reduce_taxes" => PlayerAction::EnactPolicy {
                    policy_id: "reduce_taxes",
                },
                "increase_military_budget" => PlayerAction::EnactPolicy {
                    policy_id: "increase_military_budget",
                },
                "requisition_supplies" => PlayerAction::EnactPolicy {
                    policy_id: "requisition_supplies",
                },
                "stabilize_supply_lines" => PlayerAction::EnactPolicy {
                    policy_id: "stabilize_supply_lines",
                },
                "establish_forward_depot" => PlayerAction::EnactPolicy {
                    policy_id: "establish_forward_depot",
                },
                "secure_regional_corridor" => PlayerAction::EnactPolicy {
                    policy_id: "secure_regional_corridor",
                },
                // 补全缺失的 3 条政策（之前静默退化为 Rest）
                "grant_titles" => PlayerAction::EnactPolicy {
                    policy_id: "grant_titles",
                },
                "secret_diplomacy" => PlayerAction::EnactPolicy {
                    policy_id: "secret_diplomacy",
                },
                "print_money" => PlayerAction::EnactPolicy {
                    policy_id: "print_money",
                },
                _ => PlayerAction::Rest,
            };
            self.engine.process_day(action, &mut self.rng);
        }

        /// 推进一天：强化将领忠诚度
        #[func]
        pub fn process_day_boost_loyalty(&mut self, general_id: GString) {
            use crate::engine::PlayerAction;
            self.engine.process_day(
                PlayerAction::BoostLoyalty {
                    general_id: general_id.to_string(),
                },
                &mut self.rng,
            );
        }

        /// 预览一次普通行军，不修改真实状态。
        #[func]
        pub fn preview_march(&self, target_node: GString) -> Dictionary {
            let preview = self.engine.preview_march(target_node.to_string().as_str());
            let mut d = Dictionary::new();
            let _ = d.insert("valid", preview.valid);
            let _ = d.insert("reason", preview.reason.unwrap_or_default());
            let _ = d.insert("target_node", preview.target_node.as_str());
            let _ = d.insert("fatigue_delta", preview.fatigue_delta);
            let _ = d.insert("morale_delta", preview.morale_delta);
            let _ = d.insert("supply_delta", preview.supply_delta);
            let _ = d.insert("projected_fatigue", preview.projected_fatigue);
            let _ = d.insert("projected_morale", preview.projected_morale);
            let _ = d.insert("projected_supply", preview.projected_supply);
            let _ = d.insert("supply_capacity", preview.supply_capacity as i64);
            let _ = d.insert("base_supply_capacity", preview.base_supply_capacity as i64);
            let _ = d.insert(
                "temporary_capacity_bonus",
                preview.temporary_capacity_bonus as i64,
            );
            let _ = d.insert("supply_demand", preview.supply_demand);
            let _ = d.insert("supply_available", preview.supply_available);
            let _ = d.insert("line_efficiency", preview.line_efficiency);
            let _ = d.insert("supply_role", preview.supply_role.as_str());
            let _ = d.insert("supply_role_label", preview.supply_role_label.as_str());
            let _ = d.insert("supply_hub_name", preview.supply_hub_name.as_str());
            let _ = d.insert("supply_hub_distance", preview.supply_hub_distance as i64);
            let _ = d.insert("supply_runway_days", preview.supply_runway_days);
            let _ = d.insert(
                "follow_up_total_options",
                preview.follow_up_total_options as i64,
            );
            let _ = d.insert(
                "follow_up_safe_options",
                preview.follow_up_safe_options as i64,
            );
            let _ = d.insert(
                "follow_up_risky_options",
                preview.follow_up_risky_options as i64,
            );
            let _ = d.insert("follow_up_status_id", preview.follow_up_status_id.as_str());
            let _ = d.insert(
                "follow_up_status_label",
                preview.follow_up_status_label.as_str(),
            );
            let _ = d.insert(
                "follow_up_best_target",
                preview.follow_up_best_target.as_str(),
            );
            let _ = d.insert(
                "follow_up_best_target_label",
                preview.follow_up_best_target_label.as_str(),
            );
            let _ = d.insert(
                "follow_up_best_runway_days",
                preview.follow_up_best_runway_days,
            );
            d
        }

        // ── 状态查询 ─────────────────────────────────────

        /// 获取当前引擎状态快照
        /// 返回 Dictionary，包含 day, legitimacy, rouge_noir, troops, morale,
        /// fatigue, supply, victories, defeats,
        ///   is_over, outcome, faction_support(Dict)
        #[func]
        pub fn get_state(&self) -> Dictionary {
            let e = &self.engine;
            let mut d = Dictionary::new();
            let _ = d.insert("day", e.day as i64);
            let _ = d.insert("legitimacy", e.politics.legitimacy);
            let _ = d.insert("rouge_noir", e.politics.rouge_noir_index);
            let _ = d.insert("troops", e.army.total_troops as i64);
            let _ = d.insert("morale", e.army.avg_morale);
            let _ = d.insert("fatigue", e.army.avg_fatigue);
            let _ = d.insert("supply", e.army.supply);
            let _ = d.insert("victories", e.army.victories as i64);
            let _ = d.insert("defeats", e.army.defeats as i64);
            let _ = d.insert("napoleon_location", e.napoleon_location.as_str());
            let _ = d.insert("is_over", e.is_over());
            let _ = d.insert(
                "outcome",
                e.outcome().map(|o| o.as_str()).unwrap_or("in_progress"),
            );
            if let Some((location, bonus, days)) = e.active_forward_depot() {
                let _ = d.insert("forward_depot_location", location);
                let _ = d.insert("forward_depot_capacity_bonus", bonus as i64);
                let _ = d.insert("forward_depot_days", days as i64);
            } else {
                let _ = d.insert("forward_depot_location", "");
                let _ = d.insert("forward_depot_capacity_bonus", 0i64);
                let _ = d.insert("forward_depot_days", 0i64);
            }
            let logistics = e.logistics_brief();
            let _ = d.insert("logistics_posture_id", logistics.posture_id.as_str());
            let _ = d.insert("logistics_posture_label", logistics.posture_label.as_str());
            let _ = d.insert("logistics_focus_title", logistics.focus_title.as_str());
            let _ = d.insert("logistics_focus_detail", logistics.focus_detail.as_str());
            let _ = d.insert("logistics_focus_short", logistics.focus_short.as_str());
            let _ = d.insert("logistics_objective_id", logistics.objective_id.as_str());
            let _ = d.insert(
                "logistics_objective_label",
                logistics.objective_label.as_str(),
            );
            let _ = d.insert(
                "logistics_objective_target_role",
                logistics.objective_target_role.as_str(),
            );
            let _ = d.insert(
                "logistics_objective_target_role_label",
                logistics.objective_target_role_label.as_str(),
            );
            let _ = d.insert(
                "logistics_objective_detail",
                logistics.objective_detail.as_str(),
            );
            let _ = d.insert(
                "logistics_objective_short",
                logistics.objective_short.as_str(),
            );
            let _ = d.insert(
                "logistics_action_plan_title",
                logistics.action_plan_title.as_str(),
            );
            let _ = d.insert(
                "logistics_action_plan_detail",
                logistics.action_plan_detail.as_str(),
            );
            let _ = d.insert(
                "logistics_action_plan_short",
                logistics.action_plan_short.as_str(),
            );
            let _ = d.insert(
                "logistics_primary_action_id",
                logistics.primary_action_id.as_str(),
            );
            let _ = d.insert(
                "logistics_primary_action_label",
                logistics.primary_action_label.as_str(),
            );
            let _ = d.insert(
                "logistics_primary_action_reason",
                logistics.primary_action_reason.as_str(),
            );
            let _ = d.insert(
                "logistics_primary_action_target",
                logistics.primary_action_target.as_str(),
            );
            let _ = d.insert(
                "logistics_primary_action_target_label",
                logistics.primary_action_target_label.as_str(),
            );
            let _ = d.insert(
                "logistics_secondary_action_id",
                logistics.secondary_action_id.as_str(),
            );
            let _ = d.insert(
                "logistics_secondary_action_label",
                logistics.secondary_action_label.as_str(),
            );
            let _ = d.insert(
                "logistics_secondary_action_reason",
                logistics.secondary_action_reason.as_str(),
            );
            let _ = d.insert(
                "logistics_tempo_plan_title",
                logistics.tempo_plan_title.as_str(),
            );
            let _ = d.insert(
                "logistics_tempo_plan_detail",
                logistics.tempo_plan_detail.as_str(),
            );
            let _ = d.insert(
                "logistics_tempo_plan_short",
                logistics.tempo_plan_short.as_str(),
            );
            let _ = d.insert(
                "logistics_route_chain_title",
                logistics.route_chain_title.as_str(),
            );
            let _ = d.insert(
                "logistics_route_chain_detail",
                logistics.route_chain_detail.as_str(),
            );
            let _ = d.insert(
                "logistics_route_chain_short",
                logistics.route_chain_short.as_str(),
            );
            let _ = d.insert(
                "logistics_regional_pressure_id",
                logistics.regional_pressure_id.as_str(),
            );
            let _ = d.insert(
                "logistics_regional_pressure_label",
                logistics.regional_pressure_label.as_str(),
            );
            let _ = d.insert(
                "logistics_regional_pressure_title",
                logistics.regional_pressure_title.as_str(),
            );
            let _ = d.insert(
                "logistics_regional_pressure_detail",
                logistics.regional_pressure_detail.as_str(),
            );
            let _ = d.insert(
                "logistics_regional_pressure_short",
                logistics.regional_pressure_short.as_str(),
            );
            let _ = d.insert(
                "logistics_runway_days",
                e.current_supply_runway_days()
                    .map(|days| days as i64)
                    .unwrap_or(-1),
            );
            let _ = d.insert(
                "logistics_runway_label",
                e.current_supply_runway_label().as_str(),
            );

            let mut factions = Dictionary::new();
            for (k, v) in &e.politics.faction_support {
                let _ = factions.insert(k.as_str(), *v);
            }
            let _ = d.insert("factions", factions);

            // 政策冷却：{ policy_id(String): 剩余天数(int) }
            let mut cooldowns = Dictionary::new();
            for (id, remaining) in e.politics.cooldowns() {
                let _ = cooldowns.insert(id.as_str(), *remaining as i64);
            }
            let _ = d.insert("cooldowns", cooldowns);

            d
        }

        /// 获取当前可直接行军到的相邻节点列表
        #[func]
        pub fn get_adjacent_nodes(&self) -> Array<GString> {
            self.engine
                .adjacent_nodes()
                .into_iter()
                .map(|node_id| GString::from(node_id.as_str()))
                .collect()
        }

        /// 获取最近一天的叙事报告
        /// 返回 Dictionary：{ "stendhal": String|null, "consequence": String|null, "day": int }
        #[func]
        pub fn get_last_report(&self) -> Dictionary {
            let mut d = Dictionary::new();
            match self.engine.last_report() {
                Some(r) => {
                    let _ = d.insert("day", r.day as i64);
                    let _ = d.insert("stendhal", r.stendhal.as_deref().unwrap_or(""));
                    let _ = d.insert("consequence", r.consequence.as_deref().unwrap_or(""));
                    let _ = d.insert("has_narrative", r.stendhal.is_some());
                }
                None => {
                    let _ = d.insert("day", 0i64);
                    let _ = d.insert("stendhal", "");
                    let _ = d.insert("consequence", "");
                    let _ = d.insert("has_narrative", false);
                }
            }
            d
        }

        /// 获取最近一次玩家行动的结算记录。
        /// 返回 Array[Dictionary]，每项键：
        ///   day / event_type / description / effects(Array[String])
        #[func]
        pub fn get_last_action_events(&self) -> Array<Dictionary> {
            self.engine
                .last_action_events()
                .iter()
                .map(|event| {
                    let mut d = Dictionary::new();
                    let effects: Array<GString> = event
                        .effects
                        .iter()
                        .map(|effect| GString::from(effect.as_str()))
                        .collect();
                    let _ = d.insert("day", event.day as i64);
                    let _ = d.insert("event_type", event.event_type);
                    let _ = d.insert("description", event.description.as_str());
                    let _ = d.insert("effects", effects);
                    d
                })
                .collect()
        }

        /// 获取已触发的历史事件 ID 列表（Array of String）
        #[func]
        pub fn get_triggered_events(&self) -> Array<GString> {
            self.engine
                .triggered_events()
                .iter()
                .map(|s| GString::from(s.as_str()))
                .collect()
        }

        /// 获取最近一次触发的历史事件详情。
        /// 返回 Array[Dictionary]，每项键：
        ///   id / label / tier / narrative / historical_note
        #[func]
        pub fn get_last_triggered_events(&self) -> Array<Dictionary> {
            self.engine
                .last_triggered_events()
                .iter()
                .map(|event| {
                    let mut d = Dictionary::new();
                    let _ = d.insert("id", event.id.as_str());
                    let _ = d.insert("label", event.label.as_str());
                    let _ = d.insert("tier", event.tier.as_str());
                    let _ = d.insert("narrative", event.narrative.as_str());
                    let _ = d.insert("historical_note", event.historical_note.as_str());
                    d
                })
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

        /// 获取所有将领当前忠诚度快照
        /// 返回 Dictionary：{ character_id(String): loyalty(float) }
        #[func]
        pub fn get_all_loyalties(&self) -> Dictionary {
            let mut d = Dictionary::new();
            for (id, &loyalty) in &self.engine.characters.loyalty {
                let _ = d.insert(id.as_str(), loyalty);
            }
            d
        }

        /// 序列化引擎状态为 JSON 字符串（存档用）
        #[func]
        pub fn to_json(&self) -> GString {
            GString::from(self.engine.to_json().as_str())
        }

        /// 从 JSON 字符串恢复引擎状态（读档用）
        /// 成功返回 true，JSON 格式错误返回 false
        #[func]
        pub fn load_from_json(&mut self, json: GString) -> bool {
            match crate::engine::GameEngine::from_json(json.to_string().as_str()) {
                Ok(engine) => {
                    self.engine = engine;
                    true
                }
                Err(_) => false,
            }
        }
    }
}
