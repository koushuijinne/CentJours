extends Node

func _ready() -> void:
	var engine := CentJoursEngine.new()
	print("day=", engine.current_day())
	print("state=", engine.get_state())
	print("loyalties=", engine.get_all_loyalties())

	engine.process_day_rest()

	print("after_rest_state=", engine.get_state())
	print("last_report=", engine.get_last_report())
