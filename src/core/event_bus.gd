## EventBus — 全局事件总线（自动加载单例）
## 解耦各系统之间的通信，避免直接引用

extends Node

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
signal stendhal_diary_entry(day: int, text: String)
signal micro_narrative_shown(category: String, text: String)

# 游戏状态事件
signal game_over(outcome: String)
signal historical_event_triggered(event_id: String)
