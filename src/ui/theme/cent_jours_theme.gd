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

	# PanelContainer — 用于侧栏、情报面板等容器
	var pc_sb := StyleBoxFlat.new()
	pc_sb.bg_color = COLOR["bg_panel"]
	pc_sb.border_color = COLOR["border_panel"]
	pc_sb.set_border_width_all(1)
	pc_sb.set_corner_radius_all(4)
	pc_sb.content_margin_left = 8
	pc_sb.content_margin_right = 8
	pc_sb.content_margin_top = 6
	pc_sb.content_margin_bottom = 6
	theme.set_stylebox("panel", "PanelContainer", pc_sb)

	# PopupPanel — 弹窗样式（教程、百科、设置、战斗等）
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	popup_sb.border_color = COLOR["gold_dim"]
	popup_sb.set_border_width_all(2)
	popup_sb.set_corner_radius_all(6)
	popup_sb.shadow_color = Color(0, 0, 0, 0.6)
	popup_sb.shadow_size = 12
	popup_sb.shadow_offset = Vector2(0, 4)
	popup_sb.content_margin_left = 16
	popup_sb.content_margin_right = 16
	popup_sb.content_margin_top = 12
	popup_sb.content_margin_bottom = 12
	theme.set_stylebox("panel", "PopupPanel", popup_sb)

	# ScrollContainer — 去掉默认滚动条背景
	var scroll_bg := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", scroll_bg)

	# VScrollBar — 金色滚动条轨道和滑块
	var vscroll_bg := StyleBoxFlat.new()
	vscroll_bg.bg_color = Color(0.12, 0.12, 0.20, 0.3)
	vscroll_bg.set_corner_radius_all(3)
	vscroll_bg.content_margin_left = 2
	vscroll_bg.content_margin_right = 2
	theme.set_stylebox("scroll", "VScrollBar", vscroll_bg)

	var vscroll_grabber := StyleBoxFlat.new()
	vscroll_grabber.bg_color = COLOR["gold_dim"] * Color(1, 1, 1, 0.5)
	vscroll_grabber.set_corner_radius_all(3)
	vscroll_grabber.content_margin_left = 2
	vscroll_grabber.content_margin_right = 2
	theme.set_stylebox("grabber", "VScrollBar", vscroll_grabber)

	var vscroll_grabber_hl := StyleBoxFlat.new()
	vscroll_grabber_hl.bg_color = COLOR["gold_dim"] * Color(1, 1, 1, 0.7)
	vscroll_grabber_hl.set_corner_radius_all(3)
	vscroll_grabber_hl.content_margin_left = 2
	vscroll_grabber_hl.content_margin_right = 2
	theme.set_stylebox("grabber_highlight", "VScrollBar", vscroll_grabber_hl)

	var vscroll_grabber_pr := StyleBoxFlat.new()
	vscroll_grabber_pr.bg_color = COLOR["gold"]
	vscroll_grabber_pr.set_corner_radius_all(3)
	vscroll_grabber_pr.content_margin_left = 2
	vscroll_grabber_pr.content_margin_right = 2
	theme.set_stylebox("grabber_pressed", "VScrollBar", vscroll_grabber_pr)

	# HSlider — 音频滑条等
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.18, 0.18, 0.28, 0.6)
	slider_bg.border_color = COLOR["border_panel"]
	slider_bg.set_border_width_all(1)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = COLOR["gold_dim"]
	slider_fill.set_corner_radius_all(3)
	slider_fill.content_margin_top = 4
	slider_fill.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)

	var slider_highlight := StyleBoxFlat.new()
	slider_highlight.bg_color = COLOR["gold"]
	slider_highlight.set_corner_radius_all(3)
	slider_highlight.content_margin_top = 4
	slider_highlight.content_margin_bottom = 4
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_highlight)

	# TooltipPanel — 工具提示
	var tooltip_sb := StyleBoxFlat.new()
	tooltip_sb.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	tooltip_sb.border_color = COLOR["gold_dim"]
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.set_corner_radius_all(3)
	tooltip_sb.content_margin_left = 8
	tooltip_sb.content_margin_right = 8
	tooltip_sb.content_margin_top = 4
	tooltip_sb.content_margin_bottom = 4
	theme.set_stylebox("panel", "TooltipPanel", tooltip_sb)
	theme.set_color("font_color", "TooltipLabel", COLOR["text_primary"])

	# LineEdit — 输入框
	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color(0.10, 0.10, 0.18, 0.8)
	le_normal.border_color = COLOR["border_panel"]
	le_normal.set_border_width_all(1)
	le_normal.set_corner_radius_all(3)
	le_normal.content_margin_left = 8
	le_normal.content_margin_right = 8
	le_normal.content_margin_top = 4
	le_normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", le_normal)

	var le_focus := StyleBoxFlat.new()
	le_focus.bg_color = Color(0.12, 0.12, 0.22, 0.9)
	le_focus.border_color = COLOR["gold"]
	le_focus.set_border_width_all(1)
	le_focus.set_corner_radius_all(3)
	le_focus.content_margin_left = 8
	le_focus.content_margin_right = 8
	le_focus.content_margin_top = 4
	le_focus.content_margin_bottom = 4
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", COLOR["text_primary"])
	theme.set_color("caret_color", "LineEdit", COLOR["gold"])
	theme.set_color("selection_color", "LineEdit", COLOR["gold_dim"] * Color(1, 1, 1, 0.3))

	# HSeparator / VSeparator — 分隔线
	var sep_sb := StyleBoxFlat.new()
	sep_sb.bg_color = COLOR["border_panel"] * Color(1, 1, 1, 0.5)
	sep_sb.content_margin_top = 1
	sep_sb.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", sep_sb)
	theme.set_constant("separation", "HSeparator", 8)

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
