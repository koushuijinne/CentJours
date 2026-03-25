## TurnManager — 回合流程控制器（v2，接入 CentJoursEngine）
## 管理 Dawn → Action → Dusk 三段式回合结构
## 所有游戏逻辑通过 CentJoursEngine（Rust GDExtension）执行
## GDScript 层只负责驱动 UI 信号

extends Node

# ── 回合阶段定义 ──────────────────────────────────────
enum Phase { DAWN, ACTION, DUSK }

const PHASE_NAMES: Dictionary = {
	Phase.DAWN:   "dawn",
	Phase.ACTION: "action",
	Phase.DUSK:   "dusk"
}

var current_phase: Phase = Phase.DAWN

# ── Rust 引擎节点（在场景中通过编辑器或代码连接）────────
## CentJoursEngine 是 GDExtension 暴露的 RefCounted，
## 不能作为 @export 字段挂到 Inspector，因此改为运行时懒初始化。
var engine: CentJoursEngine = null

# ── 主循环 ────────────────────────────────────────────

func _ready() -> void:
	_ensure_engine()

func start_new_turn() -> void:
	_ensure_engine()
	var day := engine.current_day()
	EventBus.turn_started.emit(day)
	_run_dawn_phase()

## Dawn Phase：同步状态、显示情报、通知 UI 等待玩家确认
func _run_dawn_phase() -> void:
	current_phase = Phase.DAWN
	GameState.current_phase = PHASE_NAMES[Phase.DAWN]
	EventBus.phase_changed.emit("dawn")

	# 同步引擎状态到 GameState 单例（供 UI 读取）
	_sync_state_from_engine()

	# UI 调用 begin_action_phase() 后进入下一段

## Action Phase：等待玩家做出决策
func begin_action_phase() -> void:
	current_phase = Phase.ACTION
	GameState.current_phase = PHASE_NAMES[Phase.ACTION]
	EventBus.phase_changed.emit("action")

## 玩家提交行动
## action_type: "battle" | "march" | "policy" | "boost_loyalty" | "rest"
## params 契约（来自 lib.rs CentJoursEngine 各 process_day_* 方法）:
##   battle        → { general_id(String), troops(int), terrain(String) }
##   march         → { target_node(String) }
##   policy        → { policy_id(String) }
##   boost_loyalty → { general_id(String) }
##   rest          → {}
func submit_action(action_type: String, params: Dictionary = {}) -> void:
	if current_phase != Phase.ACTION:
		push_warning("[TurnManager] 不在 Action Phase，无法提交行动")
		return
	_run_dusk_phase(action_type, params)

## 只读预览一次普通行军，不修改真实状态。
## 返回值契约（来自 lib.rs CentJoursEngine::preview_march）:
##   valid(bool)
##   reason(String)
##   target_node(String)
##   fatigue_delta(float)
##   morale_delta(float)
##   supply_delta(float)
##   projected_fatigue(float)
##   projected_morale(float)
##   projected_supply(float)
##   supply_capacity(int)
##   base_supply_capacity(int)
##   temporary_capacity_bonus(int)
##   supply_demand(float)
##   supply_available(float)
##   line_efficiency(float)
##   supply_role(String)
##   supply_role_label(String)
##   supply_hub_name(String)
##   supply_hub_distance(int)
##   supply_runway_days(int)
##   follow_up_total_options(int)
##   follow_up_safe_options(int)
##   follow_up_risky_options(int)
##   follow_up_status_id(String)
##   follow_up_status_label(String)
##   follow_up_best_target(String)
##   follow_up_best_target_label(String)
##   follow_up_best_runway_days(int)
func get_march_preview(target_node: String) -> Dictionary:
	_ensure_engine()
	if target_node.strip_edges() == "":
		return {
			"valid": false,
			"reason": "缺少目标节点。",
			"target_node": "",
			"fatigue_delta": 0.0,
			"morale_delta": 0.0,
			"supply_delta": 0.0,
			"projected_fatigue": GameState.avg_fatigue,
			"projected_morale": GameState.avg_morale,
			"projected_supply": GameState.supply,
			"supply_capacity": 0,
			"base_supply_capacity": 0,
			"temporary_capacity_bonus": 0,
			"supply_demand": 0.0,
			"supply_available": 0.0,
			"line_efficiency": 0.0,
			"supply_role": "",
			"supply_role_label": "",
			"supply_hub_name": "",
			"supply_hub_distance": 0,
			"supply_runway_days": -1,
			"follow_up_total_options": 0,
			"follow_up_safe_options": 0,
			"follow_up_risky_options": 0,
			"follow_up_status_id": "",
			"follow_up_status_label": "",
			"follow_up_best_target": "",
			"follow_up_best_target_label": "",
			"follow_up_best_runway_days": -1
		}
	return Dictionary(engine.preview_march(target_node))

## Dusk Phase：调用 Rust 引擎执行行动，同步结果，触发叙事
func _run_dusk_phase(action_type: String, params: Dictionary) -> void:
	_ensure_engine()
	current_phase = Phase.DUSK
	GameState.current_phase = PHASE_NAMES[Phase.DUSK]
	EventBus.phase_changed.emit("dusk")
	var previous_location: String = GameState.napoleon_location
	var previous_victories: int = GameState.victories
	# GameState 当前只缓存胜场，不缓存败场；败场归因需通过引擎状态回读。
	var previous_defeats: int = int(engine.get_state().get("defeats", 0))

	# ── 调用 Rust 引擎处理完整一天 ──────────────────────
	match action_type:
		"battle":
			engine.process_day_battle(
				params.get("general_id", ""),
				int(params.get("troops", 0)),
				params.get("terrain", "plains")
			)
		"march":
			var target_node: String = params.get("target_node", "")
			engine.process_day_march(target_node)
		"policy":
			var policy_id: String = params.get("policy_id", "")
			engine.process_day_policy(policy_id)
		"boost_loyalty":
			engine.process_day_boost_loyalty(params.get("general_id", ""))
		_:  # "rest" 及未知类型
			engine.process_day_rest()

	# ── 同步状态 ─────────────────────────────────────
	_sync_state_from_engine()
	# 历史事件已在 process_day() 的 Dawn 阶段生效；这里立刻转发给 UI，
	# 避免玩家要等到下一回合才看到事件正文和史注。
	_emit_new_triggered_events()
	_emit_last_action_events()
	if action_type == "march" and previous_location != GameState.napoleon_location:
		EventBus.unit_moved.emit("napoleon_main_force", previous_location, GameState.napoleon_location)

	# ── 叙事报告 ─────────────────────────────────────
	# engine.get_last_report() 返回键（来自 lib.rs CentJoursEngine::get_last_report）:
	#   day(int)           — 发生该叙事的天数
	#   has_narrative(bool)— 本回合是否有叙事内容
	#   stendhal(String)   — 日记体叙事文本（可为空串）
	#   consequence(String)— 行动后果文本（可为空串）
	var report := engine.get_last_report()
	var day: int = report.get("day", GameState.current_day)
	if report.get("has_narrative", false):
		var stendhal: String = report.get("stendhal", "")
		if stendhal != "":
			EventBus.stendhal_diary_entry.emit(day, stendhal)
		var consequence: String = report.get("consequence", "")
		if consequence != "":
			var narrative_category := _resolve_report_category(
				action_type,
				params,
				previous_victories,
				previous_defeats
			)
			EventBus.micro_narrative_shown.emit(narrative_category, consequence)

	# ── 检查游戏结束 ─────────────────────────────────
	if engine.is_over():
		# engine.get_state() 返回键（来自 lib.rs CentJoursEngine::get_state）:
		#   outcome(String) — "waterloo_historical"|"political_collapse"|"triumph"|...
		var state := engine.get_state()
		EventBus.game_over.emit(state.get("outcome", "unknown"))
		return

	GameState.current_day = engine.current_day()
	EventBus.turn_ended.emit(GameState.current_day)

# ── 内部辅助 ──────────────────────────────────────────

## 从 CentJoursEngine 读取状态并同步到 GameState 单例
## engine.get_state() 返回键（来自 lib.rs CentJoursEngine::get_state）:
##   day(int)         — 当前天数
##   legitimacy(float)— 政治合法性 0-100
##   rouge_noir(float)— 政治倾向 -100(极端革命)～+100(极端保守)
##   troops(int)      — 当前总兵力
##   morale(float)    — 平均士气 0-100
##   fatigue(float)   — 平均疲劳 0-100
##   supply(float)    — 当前补给值 0-100（兼容读取，若 Rust 尚未暴露则使用上次缓存）
##   victories(int)   — 已赢得战役场次
##   napoleon_location(String) — 拿破仑当前所在地图节点
##   logistics_posture_id(String)
##   logistics_posture_label(String)
##   logistics_focus_title(String)
##   logistics_focus_detail(String)
##   logistics_focus_short(String)
##   logistics_objective_id(String)
##   logistics_objective_label(String)
##   logistics_objective_target_role(String)
##   logistics_objective_target_role_label(String)
##   logistics_objective_detail(String)
##   logistics_objective_short(String)
##   logistics_action_plan_title(String)
##   logistics_action_plan_detail(String)
##   logistics_action_plan_short(String)
##   logistics_primary_action_id(String)
##   logistics_primary_action_label(String)
##   logistics_primary_action_reason(String)
##   logistics_primary_action_target(String)
##   logistics_primary_action_target_label(String)
##   logistics_secondary_action_id(String)
##   logistics_secondary_action_label(String)
##   logistics_secondary_action_reason(String)
##   logistics_tempo_plan_title(String)
##   logistics_tempo_plan_detail(String)
##   logistics_tempo_plan_short(String)
##   logistics_runway_days(int)
##   logistics_runway_label(String)
##   is_over(bool)    — 游戏是否结束
##   outcome(String)  — 结局标识（游戏进行中为 "in_progress"）
##   factions(Dictionary) — { faction_id(String): support(float) }
##     faction_id 取值: "liberals"|"nobility"|"populace"|"military"
##   cooldowns(Dictionary) — { policy_id(String): remaining_days(int) }
##     仅包含冷却中的政策，归零后自动移除
func _sync_state_from_engine() -> void:
	_ensure_engine()
	var state := engine.get_state()

	var old_legit: float = GameState.legitimacy
	var old_rn: float    = GameState.rouge_noir_index

	GameState.current_day      = engine.current_day()
	GameState.legitimacy       = float(state.get("legitimacy", GameState.legitimacy))
	GameState.rouge_noir_index = float(state.get("rouge_noir", GameState.rouge_noir_index))
	GameState.total_troops     = int(state.get("troops",    0))
	GameState.avg_morale       = float(state.get("morale",  70.0))
	GameState.avg_fatigue      = float(state.get("fatigue", 20.0))
	GameState.supply           = float(state.get("supply", GameState.supply))
	GameState.victories        = int(state.get("victories", 0))
	GameState.napoleon_location = String(state.get("napoleon_location", GameState.napoleon_location))
	GameState.forward_depot_location = String(state.get("forward_depot_location", ""))
	GameState.forward_depot_capacity_bonus = int(state.get("forward_depot_capacity_bonus", 0))
	GameState.forward_depot_days = int(state.get("forward_depot_days", 0))
	GameState.logistics_posture_id = String(state.get("logistics_posture_id", ""))
	GameState.logistics_posture_label = String(state.get("logistics_posture_label", ""))
	GameState.logistics_focus_title = String(state.get("logistics_focus_title", ""))
	GameState.logistics_focus_detail = String(state.get("logistics_focus_detail", ""))
	GameState.logistics_focus_short = String(state.get("logistics_focus_short", ""))
	GameState.logistics_objective_id = String(state.get("logistics_objective_id", ""))
	GameState.logistics_objective_label = String(state.get("logistics_objective_label", ""))
	GameState.logistics_objective_target_role = String(state.get("logistics_objective_target_role", ""))
	GameState.logistics_objective_target_role_label = String(state.get("logistics_objective_target_role_label", ""))
	GameState.logistics_objective_detail = String(state.get("logistics_objective_detail", ""))
	GameState.logistics_objective_short = String(state.get("logistics_objective_short", ""))
	GameState.logistics_action_plan_title = String(state.get("logistics_action_plan_title", ""))
	GameState.logistics_action_plan_detail = String(state.get("logistics_action_plan_detail", ""))
	GameState.logistics_action_plan_short = String(state.get("logistics_action_plan_short", ""))
	GameState.logistics_primary_action_id = String(state.get("logistics_primary_action_id", ""))
	GameState.logistics_primary_action_label = String(state.get("logistics_primary_action_label", ""))
	GameState.logistics_primary_action_reason = String(state.get("logistics_primary_action_reason", ""))
	GameState.logistics_primary_action_target = String(state.get("logistics_primary_action_target", ""))
	GameState.logistics_primary_action_target_label = String(state.get("logistics_primary_action_target_label", ""))
	GameState.logistics_secondary_action_id = String(state.get("logistics_secondary_action_id", ""))
	GameState.logistics_secondary_action_label = String(state.get("logistics_secondary_action_label", ""))
	GameState.logistics_secondary_action_reason = String(state.get("logistics_secondary_action_reason", ""))
	GameState.logistics_tempo_plan_title = String(state.get("logistics_tempo_plan_title", ""))
	GameState.logistics_tempo_plan_detail = String(state.get("logistics_tempo_plan_detail", ""))
	GameState.logistics_tempo_plan_short = String(state.get("logistics_tempo_plan_short", ""))
	GameState.logistics_runway_days = int(state.get("logistics_runway_days", -1))
	GameState.logistics_runway_label = String(state.get("logistics_runway_label", ""))
	GameState.available_march_targets.clear()
	for node_id in Array(engine.get_adjacent_nodes()):
		GameState.available_march_targets.append(String(node_id))

	# 同步政策冷却（来自 Rust PoliticsState.cooldowns）
	GameState.policy_cooldowns = state.get("cooldowns", {})

	var factions: Dictionary = state.get("factions", {})
	for faction_id in factions:
		var old_val: float = GameState.faction_support.get(faction_id, 50.0)
		var new_val: float = float(factions[faction_id])
		if absf(new_val - old_val) > 0.01:
			GameState.faction_support[faction_id] = new_val
			EventBus.faction_support_changed.emit(faction_id, old_val, new_val)

	if absf(GameState.legitimacy - old_legit) > 0.01:
		EventBus.legitimacy_changed.emit(old_legit, GameState.legitimacy)

	# engine.get_all_loyalties() 返回键（来自 lib.rs CentJoursEngine::get_all_loyalties）:
	#   { character_id(String): loyalty(float 0-100) }
	#   character_id 取值: "ney"|"davout"|"grouchy"|"soult"|"fouche" 等（与 characters.json 一致）
	var all_loyalties: Dictionary = engine.get_all_loyalties()
	for char_id in all_loyalties:
		if char_id in GameState.characters:
			var old_loyalty: float = float(GameState.characters[char_id].get("loyalty", 50.0))
			var new_loyalty: float = float(all_loyalties[char_id])
			if absf(new_loyalty - old_loyalty) > 0.01:
				GameState.characters[char_id]["loyalty"] = new_loyalty
				EventBus.loyalty_changed.emit(char_id, old_loyalty, new_loyalty)

## 发射本回合新触发的历史事件详情
## engine.get_last_triggered_events() 返回 Array[Dictionary]，每项键：
##   id(String)              — 事件 ID
##   label(String)           — 展示标题
##   tier(String)            — major | normal | minor
##   narrative(String)       — 本次抽到的叙事正文
##   historical_note(String) — 史实注释
func _emit_new_triggered_events() -> void:
	_ensure_engine()
	var triggered_details: Array = Array(engine.get_last_triggered_events())
	for event_variant in triggered_details:
		var event_data: Dictionary = Dictionary(event_variant)
		var event_id: String = String(event_data.get("id", ""))
		if event_id == "":
			continue
		if not GameState.triggered_events.has(event_id):
			GameState.triggered_events.append(event_id)
			EventBus.historical_event_triggered.emit(event_id, event_data)

## 发射最近一次玩家行动的结算记录
## engine.get_last_action_events() 返回 Array[Dictionary]，每项键：
##   day(int)                — 事件发生日
##   event_type(String)      — policy | battle | march | rest | *_failed
##   description(String)     — 主描述文本
##   effects(Array[String])  — 影响摘要
func _emit_last_action_events() -> void:
	_ensure_engine()
	var action_details: Array = Array(engine.get_last_action_events())
	for event_variant in action_details:
		var event_data: Dictionary = Dictionary(event_variant)
		var event_type: String = String(event_data.get("event_type", ""))
		var description: String = String(event_data.get("description", "")).strip_edges()
		var effects: Array = Array(event_data.get("effects", []))
		if event_type == "" and description == "":
			continue
		EventBus.action_resolution_logged.emit(event_type, description, effects)

## 根据本回合实际结算结果为微叙事选择可读类别。
## policy 需要展开到具体 policy_id，battle 需要区分胜负结果。
func _resolve_report_category(
	action_type: String,
	params: Dictionary,
	previous_victories: int,
	previous_defeats: int
) -> String:
	match action_type:
		"policy":
			return String(params.get("policy_id", "policy"))
		"battle":
			if GameState.victories > previous_victories:
				return "battle_victory"
			var current_defeats := int(engine.get_state().get("defeats", previous_defeats))
			if current_defeats > previous_defeats:
				return "battle_defeat"
			return "battle"
		"boost_loyalty":
			return "boost_loyalty"
		_:
			return action_type

## 从存档加载引擎状态（供 Save/Load UI 调用）
## 成功返回 true，失败返回 false
func load_from_save() -> bool:
	_ensure_engine()
	if not SaveManager.load_game(engine):
		return false
	current_phase = Phase.DAWN
	GameState.triggered_events.clear()
	# 从引擎读取已触发事件列表
	for event_id in Array(engine.get_triggered_events()):
		GameState.triggered_events.append(String(event_id))
	_sync_state_from_engine()
	return true

## 保存当前引擎状态到存档
func save_to_file() -> bool:
	_ensure_engine()
	return SaveManager.save_game(engine)

## 重置引擎，用于重新开始游戏
func reset_engine() -> void:
	engine = CentJoursEngine.new()
	current_phase = Phase.DAWN
	# 重新加载角色数据
	GameState._load_all_data()
	GameState.triggered_events.clear()

## 确保 TurnManager 生命周期内始终复用同一个原生引擎实例。
func _ensure_engine() -> void:
	if engine == null:
		engine = CentJoursEngine.new()
