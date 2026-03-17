## TurnManager — 回合流程控制器
## 管理 Dawn → Action → Dusk 三段式回合结构

extends Node

# ── 回合阶段定义 ──────────────────────────────────────
enum Phase { DAWN, ACTION, DUSK }

const PHASE_NAMES: Dictionary = {
	Phase.DAWN:   "dawn",
	Phase.ACTION: "action",
	Phase.DUSK:   "dusk"
}

var current_phase: Phase = Phase.DAWN
var _phase_complete: bool = false

# ── 依赖注入 ──────────────────────────────────────────
@onready var campaign_system = $"../CampaignSystem"
@onready var political_system = $"../PoliticalSystem"
@onready var character_manager = $"../CharacterManager"

# ── 主循环 ────────────────────────────────────────────
func start_new_turn() -> void:
	GameState.current_day += 1
	EventBus.turn_started.emit(GameState.current_day)
	_run_dawn_phase()

## Dawn Phase（黎明阶段）：情报汇报，玩家获取信息，无决策
func _run_dawn_phase() -> void:
	current_phase = Phase.DAWN
	GameState.current_phase = PHASE_NAMES[Phase.DAWN]
	EventBus.phase_changed.emit("dawn")

	# 收集情报
	var intel := _gather_intelligence()
	# 触发历史事件检查
	_check_historical_events()
	# 重置每日行动次数
	GameState.actions_remaining = _get_daily_action_allowance()

	# 通知 UI 显示情报摘要，等待玩家确认
	# （UI 确认后调用 begin_action_phase）

## Action Phase（决策阶段）：玩家做出军事和政治决策
func begin_action_phase() -> void:
	current_phase = Phase.ACTION
	GameState.current_phase = PHASE_NAMES[Phase.ACTION]
	EventBus.phase_changed.emit("action")
	# 等待玩家输入（由 UI 层调用 submit_actions）

## 玩家提交行动后调用
func submit_actions(military_orders: Array, political_actions: Array) -> void:
	if current_phase != Phase.ACTION:
		push_warning("不在 Action Phase，无法提交行动")
		return
	# 处理行动在 _run_dusk_phase 中统一结算
	_run_dusk_phase(military_orders, political_actions)

## Dusk Phase（黄昏阶段）：结算所有行动后果
func _run_dusk_phase(military_orders: Array, political_actions: Array) -> void:
	current_phase = Phase.DUSK
	GameState.current_phase = PHASE_NAMES[Phase.DUSK]
	EventBus.phase_changed.emit("dusk")

	# 1. 执行军事命令（含命令偏差）
	character_manager.process_orders_with_deviation(military_orders)

	# 2. 执行政治行动
	for action in political_actions:
		political_system.enact_policy(action)

	# 3. 更新军队状态（疲劳、补给、士气）
	campaign_system.update_army_states()

	# 4. AI 行动（反法同盟集结）
	_run_enemy_ai()

	# 5. 更新人物关系
	character_manager.update_relationships()

	# 6. 触发叙事
	_trigger_daily_narrative()

	# 7. 检查游戏结束
	var outcome := GameState.check_game_over()
	if outcome != "":
		EventBus.game_over.emit(outcome)
		return

	EventBus.turn_ended.emit(GameState.current_day)

# ── 内部辅助 ──────────────────────────────────────────

func _gather_intelligence() -> Dictionary:
	## 收集当日情报（敌军动向、政治风向、将领状态）
	var intel := {
		"enemy_movements": campaign_system.get_enemy_movements() if campaign_system else [],
		"at_risk_characters": character_manager.get_at_risk_characters() if character_manager else [],
		"faction_trends": political_system.get_faction_trends() if political_system else {}
	}
	return intel

func _check_historical_events() -> void:
	## 检查是否到达关键历史节点
	var day := GameState.current_day
	var events_by_day := {
		5:  "ney_defection_window",
		7:  "grenoble_arrival",
		20: "paris_entry",
		85: "grouchy_appointment_window",
		86: "ligny_bataille",
		87: "quatre_bras_aftermath",
		100: "waterloo_eve"
	}
	if day in events_by_day:
		var event_id: String = events_by_day[day]
		if not event_id in GameState.triggered_events:
			GameState.triggered_events.append(event_id)
			EventBus.historical_event_triggered.emit(event_id)

func _get_daily_action_allowance() -> int:
	## 基础2个行动，高合法性可额外获得1个
	var base := 2
	if GameState.legitimacy >= 70.0:
		return base + 1
	return base

func _run_enemy_ai() -> void:
	## 简单 AI：反法同盟逐步向法国边境集结
	## 详细逻辑在 CampaignSystem 中
	if campaign_system:
		campaign_system.advance_coalition_forces()

func _trigger_daily_narrative() -> void:
	## 触发司汤达日记和微叙事
	EventBus.stendhal_diary_entry.emit(
		GameState.current_day,
		"[Stendhal日记占位符 - Day %d]" % GameState.current_day
	)
