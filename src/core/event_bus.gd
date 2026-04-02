## EventBus — 全局事件总线（自动加载单例）
## 解耦各系统之间的通信，避免直接引用

extends Node

@warning_ignore_start("unused_signal")

# 回合事件
signal turn_started(day: int)
signal turn_ended(day: int)
signal phase_changed(phase: String)

# 行军与战役事件
signal unit_moved(unit_id: String, from_node: String, to_node: String)
signal battle_resolved(attacker_id: String, defender_id: String, result: String)
signal forced_march_performed(unit_id: String)
signal supply_shortage(unit_id: String)

# 政治事件
signal policy_enacted(policy_id: String)
signal legitimacy_changed(old_value: float, new_value: float)
signal faction_support_changed(faction_id: String, old_value: float, new_value: float)
signal political_crisis(faction_id: String, severity: String)

# 将领事件
signal loyalty_changed(character_id: String, old_value: float, new_value: float)
signal order_deviation_occurred(character_id: String, order_id: String, deviation: Dictionary)
signal character_defected(character_id: String)
signal character_joined(character_id: String)

# 叙事事件
signal narrative_triggered(narrative_id: String, context: Dictionary)
# TODO(history): 当前事件名仍沿用早期原型命名，后续按 BUG-2026-03-28-HISTORICAL-NARRATOR 迁移为 Bertrand 日记事件。
signal stendhal_diary_entry(day: int, text: String)
signal micro_narrative_shown(category: String, text: String)
signal action_resolution_logged(event_type: String, description: String, effects: Array)

# 游戏状态事件
signal game_over(outcome: String)
signal historical_event_triggered(event_id: String, event_data: Dictionary)

@warning_ignore_restore("unused_signal")
