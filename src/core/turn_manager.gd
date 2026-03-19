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
## CentJoursEngine GDExtension 节点，是游戏状态的唯一权威来源
@export var engine: CentJoursEngine

# ── 主循环 ────────────────────────────────────────────

func start_new_turn() -> void:
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
## action_type: "battle" | "policy" | "boost_loyalty" | "rest"
## params: 对应行动所需参数
##   battle       → { general_id: String, troops: int, terrain: String }
##   policy       → { policy_id: String }
##   boost_loyalty→ { general_id: String }
##   rest         → {}
func submit_action(action_type: String, params: Dictionary = {}) -> void:
	if current_phase != Phase.ACTION:
		push_warning("[TurnManager] 不在 Action Phase，无法提交行动")
		return
	_run_dusk_phase(action_type, params)

## Dusk Phase：调用 Rust 引擎执行行动，同步结果，触发叙事
func _run_dusk_phase(action_type: String, params: Dictionary) -> void:
	current_phase = Phase.DUSK
	GameState.current_phase = PHASE_NAMES[Phase.DUSK]
	EventBus.phase_changed.emit("dusk")

	# ── 调用 Rust 引擎处理完整一天 ──────────────────────
	match action_type:
		"battle":
			engine.process_day_battle(
				params.get("general_id", ""),
				int(params.get("troops", 0)),
				params.get("terrain", "plains")
			)
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

	# ── 叙事报告 ─────────────────────────────────────
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
		var state := engine.get_state()
		EventBus.game_over.emit(state.get("outcome", "unknown"))
		return

	GameState.current_day = engine.current_day()
	EventBus.turn_ended.emit(GameState.current_day)

# ── 内部辅助 ──────────────────────────────────────────

## 从 CentJoursEngine 读取状态并同步到 GameState 单例
func _sync_state_from_engine() -> void:
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

	var factions: Dictionary = state.get("factions", {})
	for faction_id in factions:
		var old_val: float = GameState.faction_support.get(faction_id, 50.0)
		var new_val: float = float(factions[faction_id])
		if absf(new_val - old_val) > 0.01:
			GameState.faction_support[faction_id] = new_val
			EventBus.faction_support_changed.emit(faction_id, old_val, new_val)

	if absf(GameState.legitimacy - old_legit) > 0.01:
		EventBus.legitimacy_changed.emit(old_legit, GameState.legitimacy)

	# 同步将领忠诚度（engine.get_all_loyalties() 是权威来源）
	# engine.get_all_loyalties() 返回键：{ character_id(String): loyalty(float) }
	var all_loyalties: Dictionary = engine.get_all_loyalties()
	for char_id in all_loyalties:
		if char_id in GameState.characters:
			var old_loyalty: float = float(GameState.characters[char_id].get("loyalty", 50.0))
			var new_loyalty: float = float(all_loyalties[char_id])
			if absf(new_loyalty - old_loyalty) > 0.01:
				GameState.characters[char_id]["loyalty"] = new_loyalty
				EventBus.loyalty_changed.emit(char_id, old_loyalty, new_loyalty)

## 发射本次 Dawn 阶段新触发的历史事件信号
func _emit_new_triggered_events() -> void:
	var all_triggered: Array = Array(engine.get_triggered_events())
	for event_id in all_triggered:
		if not GameState.triggered_events.has(event_id):
			GameState.triggered_events.append(event_id)
			EventBus.historical_event_triggered.emit(event_id)
