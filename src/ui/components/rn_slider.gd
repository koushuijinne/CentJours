## RougeNoirSlider — Rouge/Noir 双指针进度条组件
## 中心为零点，左侧偏Rouge，右侧偏Noir
## 随 GameState.rouge_noir_index 实时更新，带平滑渐变动画

class_name RougeNoirSlider
extends Control

# ── 信号 ──────────────────────────────────────────────
signal value_changed(new_value: float)

# ── 属性 ──────────────────────────────────────────────
@export var animate_duration: float = 2.0   # 渐变过渡时间（秒）
@export var show_labels: bool = true

# ── 节点引用（在 .tscn 中连接，或自动创建） ───────────
var _track_rect: ColorRect
var _fill_left:  ColorRect   # Rouge 方向
var _fill_right: ColorRect   # Noir 方向
var _indicator:  ColorRect   # 中央指示点
var _label_rouge: Label
var _label_noir:  Label
var _label_value: Label

var _current_value: float = 0.0
var _target_value: float = 0.0
var _tween: Tween

const TRACK_HEIGHT := 8.0
const INDICATOR_SIZE := 14.0

func _ready() -> void:
	_build_ui()
	# phase_changed 在每次引擎同步后必然触发，用信号驱动替代每帧轮询（ADR-004）
	EventBus.phase_changed.connect(_on_phase_changed)

# ── 公开 API ──────────────────────────────────────────

func set_value(val: float) -> void:
	_target_value = clampf(val, -100.0, 100.0)
	_animate_to(_target_value)
	value_changed.emit(_target_value)

func get_value() -> float:
	return _current_value

# ── 内部构建 ──────────────────────────────────────────

func _build_ui() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(220, 32)

	var track := ColorRect.new()
	track.color = CentJoursTheme.COLOR["border_panel"]
	track.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	track.custom_minimum_size = Vector2(0, TRACK_HEIGHT)
	track.position.y = (size.y - TRACK_HEIGHT) / 2.0
	add_child(track)
	_track_rect = track

	# Rouge 填充（从中心向左）
	_fill_left = ColorRect.new()
	_fill_left.color = CentJoursTheme.COLOR["rouge_glow"]
	add_child(_fill_left)

	# Noir 填充（从中心向右）
	_fill_right = ColorRect.new()
	_fill_right.color = CentJoursTheme.COLOR["noir_glow"]
	add_child(_fill_right)

	# 指示点
	_indicator = ColorRect.new()
	_indicator.color = CentJoursTheme.COLOR["gold"]
	_indicator.custom_minimum_size = Vector2(INDICATOR_SIZE, INDICATOR_SIZE)
	add_child(_indicator)

	if show_labels:
		_label_rouge = Label.new()
		_label_rouge.text = "Rouge"
		_label_rouge.add_theme_color_override("font_color", CentJoursTheme.COLOR["rouge_glow"])
		_label_rouge.add_theme_font_size_override("font_size", 10)
		add_child(_label_rouge)

		_label_noir = Label.new()
		_label_noir.text = "Noir"
		_label_noir.add_theme_color_override("font_color", CentJoursTheme.COLOR["noir_glow"])
		_label_noir.add_theme_font_size_override("font_size", 10)
		add_child(_label_noir)

	_update_visual(0.0)

func _animate_to(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_update_visual, _current_value, target, animate_duration)
	_current_value = target

func _update_visual(val: float) -> void:
	var w := size.x
	var cy := size.y / 2.0
	var center_x := w / 2.0
	var ratio := val / 100.0   # -1.0 to +1.0

	# 更新填充（只显示有值的一侧）
	if val < 0:  # 偏Noir
		_fill_left.hide()
		_fill_right.show()
		_fill_right.position = Vector2(center_x, cy - TRACK_HEIGHT / 2.0)
		_fill_right.size = Vector2((-ratio) * center_x, TRACK_HEIGHT)
	else:
		_fill_right.hide()
		_fill_left.show()
		_fill_left.position = Vector2(center_x - ratio * center_x, cy - TRACK_HEIGHT / 2.0)
		_fill_left.size = Vector2(ratio * center_x, TRACK_HEIGHT)

	# 移动指示点
	var ind_x := center_x + ratio * center_x - INDICATOR_SIZE / 2.0
	_indicator.position = Vector2(ind_x, cy - INDICATOR_SIZE / 2.0)
	_indicator.size = Vector2(INDICATOR_SIZE, INDICATOR_SIZE)

	# 指示点颜色随 RN 变化
	var tint := CentJoursTheme.get_rn_tint(val)
	_indicator.color = tint["gold_tint"]

func _on_phase_changed(_phase: String) -> void:
	# 每次阶段切换时同步引擎最新的 rouge_noir 值，替代原有的每帧轮询
	set_value(GameState.rouge_noir_index)
