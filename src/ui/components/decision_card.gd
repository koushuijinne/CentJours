## DecisionCard — 决策卡片 UI 组件
## 对应 docs/plans/product_plan.md §3.7.4 "决策托盘"的单张卡片
## 展示政策名称、效果数值、状态（可选/冷却/选中）

class_name DecisionCard
extends PanelContainer

# ── 信号 ──────────────────────────────────────────────
signal card_selected(policy_id: String)

# ── 属性 ──────────────────────────────────────────────
@export var policy_id: String = ""
@export var policy_name: String = "政策名称"
@export var thumbnail_emoji: String = "📜"  # M5阶段替换为实际纹理
@export var card_category: String = "decision"
@export var cost_actions: int = 1
@export var on_cooldown: bool = false
@export var cooldown_days: int = 0
@export var is_disabled: bool = false
@export var disabled_reason: String = ""

# 效果列表，每项: {label, value, type} type = "positive"/"negative"/"rn"
@export var effects: Array = []

var _is_selected: bool = false
var _style_normal:   StyleBoxFlat
var _style_hover:    StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_cooldown: StyleBoxFlat
var _style_disabled: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(132, 118)
	_build_ui()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	# 以卡片中心为缩放原点，避免 hover scale 偏移（ADR-004）
	pivot_offset = custom_minimum_size / 2.0

# ── 公开 API ──────────────────────────────────────────

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_current_style()

func populate(data: Dictionary) -> void:
	policy_id    = data.get("id", "")
	policy_name  = data.get("name", "未知政策")
	cost_actions = data.get("cost", 1)
	on_cooldown  = data.get("cooldown_remaining", 0) > 0
	cooldown_days = data.get("cooldown_remaining", 0)
	# effects 需要单独从 PoliticalSystem 获取
	_rebuild_ui()

func apply_layout_metrics(card_size: Vector2) -> void:
	if custom_minimum_size.is_equal_approx(card_size):
		pivot_offset = card_size / 2.0
		return
	custom_minimum_size = card_size
	pivot_offset = card_size / 2.0
	_rebuild_ui()


func apply_cooldown_state(cooldown_remaining: int) -> void:
	var next_on_cooldown: bool = cooldown_remaining > 0
	var next_days: int = maxi(0, cooldown_remaining)
	var state_changed: bool = next_on_cooldown != on_cooldown or next_days != cooldown_days
	on_cooldown = next_on_cooldown
	cooldown_days = next_days
	if state_changed:
		_rebuild_ui()
	else:
		_apply_current_style()


func apply_availability_state(disabled: bool, reason: String = "") -> void:
	if is_disabled == disabled and disabled_reason == reason:
		_apply_current_style()
		return
	is_disabled = disabled
	disabled_reason = reason
	_rebuild_ui()

# ── UI 构建 ──────────────────────────────────────────

func _build_styles() -> void:
	var accent_color := _category_accent_color()
	var accent_fill := accent_color.darkened(0.72)
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.1, 0.1, 0.18, 0.9)
	_style_normal.border_color = accent_color
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(4)

	_style_hover = _style_normal.duplicate()
	_style_hover.border_color = accent_color.lightened(0.18)
	_style_hover.bg_color = Color(
		minf(accent_fill.r + 0.04, 0.20),
		minf(accent_fill.g + 0.04, 0.18),
		minf(accent_fill.b + 0.05, 0.24),
		0.92
	)

	_style_selected = _style_normal.duplicate()
	_style_selected.border_color = CentJoursTheme.COLOR["gold"]
	_style_selected.bg_color = Color(0.14, 0.12, 0.08, 0.9)
	_style_selected.shadow_color = Color(CentJoursTheme.COLOR["gold"].r,
		CentJoursTheme.COLOR["gold"].g, CentJoursTheme.COLOR["gold"].b, 0.35)
	_style_selected.shadow_size = 6

	_style_cooldown = _style_normal.duplicate()
	_style_cooldown.bg_color = Color(0.08, 0.08, 0.14, 0.5)
	_style_cooldown.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.35)

	_style_disabled = _style_normal.duplicate()
	_style_disabled.bg_color = Color(0.07, 0.07, 0.11, 0.55)
	_style_disabled.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.24)

	add_theme_stylebox_override("panel", _style_normal)

func _build_ui() -> void:
	var card_height := maxf(custom_minimum_size.y, 108.0)
	var thumb_height := clampf(card_height * 0.28, 30.0, 34.0)
	var body_gap := int(clampf(roundf(card_height * 0.018), 1.0, 2.0))
	var body_margin := int(clampf(roundf(card_height * 0.034), 4.0, 5.0))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# 缩略图区域
	var thumb := Label.new()
	thumb.text = thumbnail_emoji
	thumb.add_theme_font_size_override("font_size", 24)
	thumb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb.custom_minimum_size = Vector2(0, thumb_height)
	thumb.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(thumb)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", CentJoursTheme.COLOR["border_panel"])
	vbox.add_child(sep)

	# 正文区域
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", body_gap)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top",   body_margin)
	margin.add_theme_constant_override("margin_bottom",body_margin)
	margin.add_child(body)
	vbox.add_child(margin)

	# 标题
	var title_label := Label.new()
	title_label.text = policy_name
	title_label.add_theme_color_override("font_color", CentJoursTheme.COLOR["text_heading"])
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(title_label)

	# 行动点消耗
	var cost_label := Label.new()
	cost_label.text = "%s · %d 行动点" % [_category_display_name(), cost_actions]
	cost_label.add_theme_color_override("font_color", _category_accent_color())
	cost_label.add_theme_font_size_override("font_size", 9)
	body.add_child(cost_label)

	# 效果列表
	for eff in effects:
		var eff_label := Label.new()
		var val: float = float(eff.get("value", 0))
		var prefix := "+" if val >= 0 else ""
		eff_label.text = "%s%s %s" % [prefix, str(int(val)), eff.get("label", "")]
		eff_label.add_theme_font_size_override("font_size", 9)
		match eff.get("type", "neutral"):
			"positive": eff_label.add_theme_color_override("font_color",
				CentJoursTheme.COLOR["positive"])
			"negative": eff_label.add_theme_color_override("font_color",
				CentJoursTheme.COLOR["negative"])
			"rn":       eff_label.add_theme_color_override("font_color",
				CentJoursTheme.COLOR["rouge_glow"])
			_:          eff_label.add_theme_color_override("font_color",
				CentJoursTheme.COLOR["neutral"])
		body.add_child(eff_label)

	# 冷却覆盖层
	if on_cooldown:
		var cooldown_overlay := Label.new()
		cooldown_overlay.text = "🔒 %dj" % cooldown_days
		cooldown_overlay.add_theme_color_override("font_color", CentJoursTheme.COLOR["neutral"])
		cooldown_overlay.add_theme_font_size_override("font_size", 10)
		body.add_child(cooldown_overlay)
		modulate = Color(1, 1, 1, 0.45)
	elif is_disabled:
		var disabled_overlay := Label.new()
		disabled_overlay.text = disabled_reason if disabled_reason.strip_edges() != "" else "本日不可用"
		disabled_overlay.add_theme_color_override("font_color", CentJoursTheme.COLOR["neutral"])
		disabled_overlay.add_theme_font_size_override("font_size", 10)
		body.add_child(disabled_overlay)
		modulate = Color(1, 1, 1, 0.52)

func _rebuild_ui() -> void:
	for child in get_children():
		child.queue_free()
	modulate = Color.WHITE
	_build_ui()
	_apply_current_style()

# ── 事件处理 ──────────────────────────────────────────

func _on_mouse_entered() -> void:
	if on_cooldown or is_disabled or _is_selected:
		return
	add_theme_stylebox_override("panel", _style_hover)
	_animate_hover(true)

func _on_mouse_exited() -> void:
	if _is_selected:
		return
	if on_cooldown:
		add_theme_stylebox_override("panel", _style_cooldown)
	elif is_disabled:
		add_theme_stylebox_override("panel", _style_disabled)
	else:
		add_theme_stylebox_override("panel", _style_normal)
	_animate_hover(false)

func _on_gui_input(event: InputEvent) -> void:
	if on_cooldown or is_disabled:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			set_selected(true)
			card_selected.emit(policy_id)

func _apply_current_style() -> void:
	if on_cooldown:
		add_theme_stylebox_override("panel", _style_cooldown)
	elif is_disabled:
		add_theme_stylebox_override("panel", _style_disabled)
	elif _is_selected:
		add_theme_stylebox_override("panel", _style_selected)
	else:
		add_theme_stylebox_override("panel", _style_normal)

func _animate_hover(enter: bool) -> void:
	# 用 scale 替代 position 偏移：HBoxContainer 会覆盖 position，scale 不受容器干涉（ADR-004）
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale",
		Vector2(1.04, 1.04) if enter else Vector2.ONE, 0.12)


func _category_display_name() -> String:
	return "机动" if card_category == "maneuver" else "决策"


func _category_accent_color() -> Color:
	if card_category == "maneuver":
		return CentJoursTheme.COLOR["gold_dim"]
	return CentJoursTheme.COLOR["border_panel"]
