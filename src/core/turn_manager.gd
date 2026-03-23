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

	# 发射新触发的历史事件信号（引擎在 Dawn 阶段内部自动触发）
	_emit_new_triggered_events()

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

## Dusk Phase：调用 Rust 引擎执行行动，同步结果，触发叙事
func _run_dusk_phase(action_type: String, params: Dictionary) -> void:
	_ensure_engine()
	current_phase = Phase.DUSK
	GameState.current_phase = PHASE_NAMES[Phase.DUSK]
	EventBus.phase_changed.emit("dusk")
	var previous_location: String = GameState.napoleon_location

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
			EventBus.policy_enacted.emit(policy_id)
		"boost_loyalty":
			engine.process_day_boost_loyalty(params.get("general_id", ""))
		_:  # "rest" 及未知类型
			engine.process_day_rest()

	# ── 同步状态 ─────────────────────────────────────
	_sync_state_from_engine()
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
			EventBus.micro_narrative_shown.emit(action_type, consequence)

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
##   victories(int)   — 已赢得战役场次
##   napoleon_location(String) — 拿破仑当前所在地图节点
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
	GameState.victories        = int(state.get("victories", 0))
	GameState.napoleon_location = String(state.get("napoleon_location", GameState.napoleon_location))
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

## 发射本次 Dawn 阶段新触发的历史事件信号
## engine.get_triggered_events() 返回 Array[String]（事件 ID 列表，与 events/pool.rs 一致）
func _emit_new_triggered_events() -> void:
	_ensure_engine()
	var all_triggered: Array = Array(engine.get_triggered_events())
	for event_id in all_triggered:
		if not GameState.triggered_events.has(event_id):
			GameState.triggered_events.append(event_id)
			EventBus.historical_event_triggered.emit(event_id)

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
