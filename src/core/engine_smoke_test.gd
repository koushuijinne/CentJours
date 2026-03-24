extends Node

func _ready() -> void:
	var policy_engine := CentJoursEngine.new()
	print("policy_day=", policy_engine.current_day())
	print("policy_state=", policy_engine.get_state())
	policy_engine.process_day_policy("constitutional_promise")
	print("after_policy_state=", policy_engine.get_state())
	print("policy_last_action_events=", policy_engine.get_last_action_events())
	print("policy_last_report=", policy_engine.get_last_report())

	var boost_engine := CentJoursEngine.new()
	boost_engine.process_day_boost_loyalty("ney")
	print("boost_last_action_events=", boost_engine.get_last_action_events())
	print("boost_last_report=", boost_engine.get_last_report())

	var battle_engine := CentJoursEngine.new()
	battle_engine.process_day_battle("ney", 60000, "plains")
	print("battle_last_action_events=", battle_engine.get_last_action_events())
	print("battle_last_report=", battle_engine.get_last_report())
	get_tree().quit()
