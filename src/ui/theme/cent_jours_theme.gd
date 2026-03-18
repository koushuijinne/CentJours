## CentJoursTheme — Godot 4 Theme 配置脚本
## 从 design_tokens.json 读取，生成运行时 Theme 资源
## 在 project.godot 的 autoload 中或场景初始化时调用

class_name CentJoursTheme
extends RefCounted

# ── 设计令牌（硬编码备份，与 design_tokens.json 同步） ──
const COLOR := {
	"bg_primary":    Color("#1A1A2E"),
	"bg_panel":      Color(0.118, 0.118, 0.196, 0.88),
	"bg_panel_dark": Color(0.055, 0.055, 0.102, 0.95),
	"border_panel":  Color("#3A3A5C"),
	"gold":          Color("#C9A84C"),
	"gold_dim":      Color("#8B7332"),
	"gold_bright":   Color("#E8C96A"),
	"rouge":         Color("#8B2500"),
	"rouge_glow":    Color("#D4421E"),
	"noir":          Color("#2C2C3A"),
	"noir_glow":     Color("#4A6FA5"),
	"text_primary":  Color("#E8E0D0"),
	"text_secondary":Color("#A09880"),
	"text_heading":  Color("#F0E6C8"),
	"positive":      Color("#C9A84C"),
	"negative":      Color("#A03020"),
	"neutral":       Color("#A09880"),
	"warning":       Color("#C87820"),
}

# ── 字体尺寸 ──────────────────────────────────────────
const FONT_SIZE := {
	"xs": 12, "sm": 14, "base": 16,
	"lg": 20, "xl": 28, "2xl": 40, "3xl": 64
}

# ── 间距 ──────────────────────────────────────────────
const SPACING := { "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32 }

# ── 生成 Theme 对象 ────────────────────────────────────

## 创建并返回游戏主 Theme（项目初始化时调用一次）
static func create() -> Theme:
	var theme := Theme.new()

	# Panel 样式
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = COLOR["bg_panel"]
	panel_sb.border_color = COLOR["border_panel"]
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(4)
	panel_sb.shadow_color = Color(0, 0, 0, 0.4)
	panel_sb.shadow_size = 4
	panel_sb.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "Panel", panel_sb)

	# Button 默认样式
	var btn_normal := _make_button_style(COLOR["gold_dim"] * 0.4, COLOR["gold_dim"])
	var btn_hover  := _make_button_style(COLOR["gold_dim"] * 0.6, COLOR["gold"])
	var btn_press  := _make_button_style(COLOR["gold_dim"] * 0.2, COLOR["gold_dim"])
	var btn_disabled := _make_button_style(Color(0.2, 0.2, 0.3, 0.5), COLOR["border_panel"])
	theme.set_stylebox("normal",   "Button", btn_normal)
	theme.set_stylebox("hover",    "Button", btn_hover)
	theme.set_stylebox("pressed",  "Button", btn_press)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color",          "Button", COLOR["text_primary"])
	theme.set_color("font_hover_color",    "Button", COLOR["text_heading"])
	theme.set_color("font_pressed_color",  "Button", COLOR["gold"])
	theme.set_color("font_disabled_color", "Button", COLOR["neutral"])

	# ProgressBar 样式
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.22, 0.22, 0.35, 0.6)
	pb_bg.set_border_width_all(1)
	pb_bg.border_color = COLOR["border_panel"]
	pb_bg.set_corner_radius_all(3)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = COLOR["gold"]
	pb_fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill",       "ProgressBar", pb_fill)

	# Label 颜色
	theme.set_color("font_color", "Label", COLOR["text_primary"])

	return theme

static func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 12
	sb.content_margin_right  = 12
	sb.content_margin_top    = 6
	sb.content_margin_bottom = 6
	return sb

# ── Rouge/Noir 动态色调调制 ──────────────────────────────

## 根据 rn_index (-100 到 +100) 计算当前全局色调
## 正值偏 Rouge，负值偏 Noir
## 返回：{bg_tint: Color, gold_tint: Color, intensity: float}
static func get_rn_tint(rn_index: float) -> Dictionary:
	var intensity := absf(rn_index) / 100.0  # 0.0 - 1.0
	var max_alpha := 0.15

	var bg_tint: Color
	var gold_tint: Color

	if rn_index > 0:
		# 偏Rouge：背景微红，金色偏铜
		bg_tint = Color(COLOR["rouge_glow"].r, COLOR["rouge_glow"].g,
			COLOR["rouge_glow"].b, intensity * max_alpha)
		gold_tint = COLOR["gold"].lerp(Color("#C88A3C"), intensity * 0.4)
	else:
		# 偏Noir：背景微蓝，金色偏银
		bg_tint = Color(COLOR["noir_glow"].r, COLOR["noir_glow"].g,
			COLOR["noir_glow"].b, intensity * max_alpha)
		gold_tint = COLOR["gold"].lerp(Color("#A8B8C9"), intensity * 0.4)

	return {
		"bg_tint": bg_tint,
		"gold_tint": gold_tint,
		"intensity": intensity
	}

# ── 忠诚度颜色映射 ────────────────────────────────────

## 根据忠诚度数值返回对应颜色
static func get_loyalty_color(loyalty: float) -> Color:
	if loyalty >= 70.0:
		return Color("#4A9A4A")   # 绿色：可靠
	elif loyalty >= 40.0:
		return Color("#C87820")   # 琥珀：不确定
	else:
		return Color("#C03020")   # 红色：危险

## 根据忠诚度数值返回文字描述
static func get_loyalty_label(loyalty: float) -> String:
	if loyalty >= 80.0: return "无条件忠诚"
	elif loyalty >= 65.0: return "可靠"
	elif loyalty >= 40.0: return "摇摆"
	elif loyalty >= 30.0: return "不稳定"
	else: return "⚠ 叛逃风险"

# ── 派系颜色映射 ──────────────────────────────────────

const FACTION_COLORS := {
	"liberals": Color("#4A6FA5"),   # 蓝色：自由派
	"nobility": Color("#8B6030"),   # 棕金：旧贵族
	"populace": Color("#8B2500"),   # 暗红：民众
	"military": Color("#C9A84C"),   # 金色：军方
}

static func get_faction_color(faction_id: String) -> Color:
	return FACTION_COLORS.get(faction_id, COLOR["neutral"])
