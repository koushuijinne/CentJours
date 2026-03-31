## MainMenuTrayController - extracts decision tray responsibilities from MainMenu
## Owns tray card construction, selection state, cooldown refresh, and confirm-button helpers.

class_name MainMenuTrayController
extends Node

signal policy_selected(policy_id: String)
signal confirm_requested(policy_id: String)
signal selection_changed(policy_id: String)

var _decision_row: HBoxContainer = null
var _tray_hint: Label = null
var _confirm_button: Button = null

var _card_specs: Array[Dictionary] = []
var _cards_by_policy_id: Dictionary = {}
var _disabled_policy_ids: Dictionary = {}
var _disabled_policy_reasons: Dictionary = {}
var _selected_policy_id: String = ""
var _awaiting_action: bool = false

var _enabled_hint_text: String = "选择一项政策或直接休整"
var _disabled_hint_text: String = "结算中…"
var _confirm_button_text: String = "执行行动 →"


func configure(decision_row: HBoxContainer, tray_hint: Label = null, confirm_button: Button = null, card_specs: Array = []) -> void:
	bind_nodes(decision_row, tray_hint, confirm_button)
	if not card_specs.is_empty():
		set_card_specs(card_specs)


func bind_nodes(decision_row: HBoxContainer, tray_hint: Label = null, confirm_button: Button = null) -> void:
	_decision_row = decision_row
	_tray_hint = tray_hint
	if confirm_button != null:
		set_confirm_button(confirm_button)


func set_card_specs(card_specs: Array) -> void:
	_card_specs = card_specs.duplicate(true)
	rebuild_cards()


func rebuild_cards() -> void:
	if _decision_row == null:
		return

	for child in _decision_row.get_children():
		child.queue_free()

	_cards_by_policy_id.clear()

	for spec in _card_specs:
		if not (spec is Dictionary):
			continue
		if bool(spec.get("section_break", false)):
			var separator := _build_section_break(spec)
			if separator != null:
				_decision_row.add_child(separator)
			continue
		var card := _build_card_from_spec(spec)
		if card == null:
			continue
		_decision_row.add_child(card)
		_cards_by_policy_id[card.policy_id] = card

	_sync_selected_policy_to_cards()
	_apply_selected_state()
	_refresh_policy_availability_state()
	_apply_tray_interactive_state()


func set_tray_state(policy_id: String = "", awaiting_action: bool = false, emit_selection_changed: bool = false) -> void:
	_awaiting_action = awaiting_action
	_set_selected_policy_id(policy_id, emit_selection_changed)
	_apply_tray_interactive_state()


func set_state(policy_id: String = "", awaiting_action: bool = false, emit_selection_changed: bool = false) -> void:
	set_tray_state(policy_id, awaiting_action, emit_selection_changed)


func create_confirm_button(parent: Container, text: String = "执行行动 →") -> Button:
	if parent == null:
		return null
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(120, 28)
	parent.add_child(button)
	set_confirm_button(button)
	return button


func set_confirm_button(button: Button) -> void:
	if _confirm_button == button:
		_apply_tray_interactive_state()
		return

	if _confirm_button != null and _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.disconnect(_on_confirm_pressed)

	_confirm_button = button
	if _confirm_button == null:
		return

	if not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.text = _confirm_button_text
	_apply_tray_interactive_state()


func set_confirm_button_text(text: String) -> void:
	_confirm_button_text = text
	if _confirm_button != null:
		_confirm_button.text = text


func set_tray_hint_texts(enabled_text: String, disabled_text: String) -> void:
	_enabled_hint_text = enabled_text
	_disabled_hint_text = disabled_text
	_apply_tray_interactive_state()


func set_enabled_hint_text(text: String) -> void:
	_enabled_hint_text = text
	_apply_tray_interactive_state()


func set_disabled_hint_text(text: String) -> void:
	_disabled_hint_text = text
	_apply_tray_interactive_state()


func set_tray_interactive(enabled: bool) -> void:
	_awaiting_action = enabled
	_apply_tray_interactive_state()


func is_tray_interactive() -> bool:
	return _awaiting_action


func get_selected_policy_id() -> String:
	return _selected_policy_id


func clear_selection() -> void:
	_set_selected_policy_id("", false)


func set_selected_policy_id(policy_id: String) -> void:
	_set_selected_policy_id(policy_id, true)


func select_policy(policy_id: String) -> void:
	if not _awaiting_action:
		return
	if _disabled_policy_ids.has(policy_id):
		return
	_set_selected_policy_id(policy_id, true)
	policy_selected.emit(policy_id)


func get_cards() -> Dictionary:
	if _cards_by_policy_id.is_empty():
		return {}
	return _cards_by_policy_id.duplicate()


func get_card(policy_id: String) -> DecisionCard:
	return _cards_by_policy_id.get(policy_id, null)


func get_selected_card() -> DecisionCard:
	if _selected_policy_id == "":
		return null
	return get_card(_selected_policy_id)


func apply_policy_availability(disabled_policy_data: Variant = []) -> void:
	_disabled_policy_ids.clear()
	_disabled_policy_reasons.clear()
	if disabled_policy_data is Dictionary:
		for policy_id_variant in disabled_policy_data.keys():
			var policy_id := String(policy_id_variant)
			if policy_id == "":
				continue
			_disabled_policy_ids[policy_id] = true
			_disabled_policy_reasons[policy_id] = String(disabled_policy_data.get(policy_id_variant, ""))
	else:
		for policy_id_variant in disabled_policy_data:
			var policy_id := String(policy_id_variant)
			if policy_id == "":
				continue
			_disabled_policy_ids[policy_id] = true
	if _disabled_policy_ids.has(_selected_policy_id):
		_selected_policy_id = ""
	_apply_selected_state()
	_refresh_policy_availability_state()
	_apply_tray_interactive_state()


func apply_layout_metrics(card_size: Vector2) -> void:
	if _decision_row == null:
		return
	for child in _decision_row.get_children():
		if child is DecisionCard:
			child.apply_layout_metrics(card_size)


func refresh_card_cooldowns(cooldowns: Dictionary, skip_policy_ids: Array = []) -> void:
	if _decision_row == null:
		return
	var skip := {}
	for policy_id in skip_policy_ids:
		skip[String(policy_id)] = true

	for child in _decision_row.get_children():
		if not (child is DecisionCard):
			continue
		if skip.has(child.policy_id):
			continue
		var cd: int = int(cooldowns.get(child.policy_id, 0))
		child.apply_cooldown_state(cd)


func build_default_card_specs(
	rest_meta: Dictionary,
	policy_ids: Array,
	policy_meta: Dictionary,
	policy_emojis: Dictionary,
	policy_effects: Dictionary,
	march_meta: Dictionary,
	battle_meta: Dictionary,
	boost_meta: Dictionary
) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	specs.append({
		"section_break": true,
		"label": "机动",
		"label_only": true
	})
	specs.append(_make_card_spec(rest_meta))
	specs.append(_make_card_spec(march_meta))
	specs.append(_make_card_spec(battle_meta))
	specs.append({
		"section_break": true,
		"label": "决策"
	})
	specs.append(_make_card_spec(boost_meta))

	for policy_id in policy_ids:
		var meta: Dictionary = policy_meta.get(policy_id, {})
		specs.append({
			"policy_id": policy_id,
			"name": String(meta.get("name", policy_id)),
			"emoji": String(policy_emojis.get(policy_id, "📜")),
			"cost_actions": int(meta.get("cost", 1)),
			"effects": policy_effects.get(policy_id, [])
		})

	return specs


func _make_card_spec(meta: Dictionary) -> Dictionary:
	return {
		"policy_id": String(meta.get("policy_id", "")),
		"name": String(meta.get("name", "政策名称")),
		"emoji": String(meta.get("emoji", "📜")),
		"cost_actions": int(meta.get("cost_actions", meta.get("cost", 1))),
		"effects": meta.get("effects", [])
	}


func _build_card_from_spec(spec: Dictionary) -> DecisionCard:
	var policy_id := String(spec.get("policy_id", ""))
	if policy_id.is_empty():
		return null

	var card := DecisionCard.new()
	card.policy_id = policy_id
	card.policy_name = String(spec.get("name", policy_id))
	card.thumbnail_emoji = String(spec.get("emoji", "📜"))
	card.cost_actions = int(spec.get("cost_actions", 1))
	card.effects = spec.get("effects", [])
	card.card_selected.connect(_on_card_selected)
	return card


func _build_section_break(spec: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.name = "DecisionSectionBreak%s" % String(spec.get("label", ""))
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 6)
	container.custom_minimum_size = Vector2(48, 0)

	if bool(spec.get("label_only", false)):
		var start_label := Label.new()
		start_label.text = String(spec.get("label", ""))
		start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		start_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		start_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
		start_label.add_theme_font_size_override("font_size", 10)
		container.add_child(start_label)
		return container

	var separator := VSeparator.new()
	separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(separator)

	var label := Label.new()
	label.text = String(spec.get("label", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", CentJoursTheme.COLOR["gold_dim"])
	label.add_theme_font_size_override("font_size", 9)
	container.add_child(label)
	return container


func _set_selected_policy_id(policy_id: String, emit_selection_changed: bool) -> void:
	if _selected_policy_id == policy_id:
		return
	_selected_policy_id = policy_id
	_apply_selected_state()
	if emit_selection_changed:
		selection_changed.emit(policy_id)


func _sync_selected_policy_to_cards() -> void:
	if _selected_policy_id == "" or _cards_by_policy_id.has(_selected_policy_id):
		return
	_selected_policy_id = ""


func _on_card_selected(policy_id: String) -> void:
	if not _awaiting_action:
		var card_variant: Variant = _cards_by_policy_id.get(policy_id, null)
		if card_variant is DecisionCard:
			var card: DecisionCard = card_variant
			card.set_selected(false)
		return
	if _disabled_policy_ids.has(policy_id):
		var disabled_variant: Variant = _cards_by_policy_id.get(policy_id, null)
		if disabled_variant is DecisionCard:
			var disabled_card: DecisionCard = disabled_variant
			disabled_card.set_selected(false)
		return
	select_policy(policy_id)


func _on_confirm_pressed() -> void:
	confirm_requested.emit(_selected_policy_id)


func _apply_selected_state() -> void:
	if _decision_row == null:
		return
	for child in _decision_row.get_children():
		if child is DecisionCard:
			child.set_selected(child.policy_id == _selected_policy_id)


func _refresh_policy_availability_state() -> void:
	if _decision_row == null:
		return
	for child in _decision_row.get_children():
		if child is DecisionCard:
			var reason := String(_disabled_policy_reasons.get(child.policy_id, ""))
			child.apply_availability_state(_disabled_policy_ids.has(child.policy_id), reason)


func _apply_tray_interactive_state() -> void:
	if _confirm_button == null and _tray_hint == null:
		return
	if _confirm_button != null:
		_confirm_button.disabled = not _awaiting_action
		_confirm_button.text = _confirm_button_text
	if _tray_hint != null:
		_tray_hint.text = _enabled_hint_text if _awaiting_action else _disabled_hint_text
