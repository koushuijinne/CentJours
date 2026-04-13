# Development Log 008 — UI 主题扩展 + main_menu.gd 拆分

> **日期**: 2026-04-13
> **分支**: `claude/review-project-status-05vxD`
> **任务**: S4-1 UI 主题 / main_menu.gd 重构

## 本轮完成

### S4-1 UI 主题扩展（20%→55%）
`cent_jours_theme.gd` 新增 9 种控件样式：
- PanelContainer: 带边框和圆角
- PopupPanel: 金色边框、阴影、帝国深色背景
- VScrollBar: 金色滑块（三态：默认/高亮/按下）
- HSlider: 音频滑条金色填充
- TooltipPanel: 深色背景金色边框
- LineEdit: 焦点态金色边框、金色光标
- HSeparator: 半透明分隔线
- ScrollContainer: 清除默认背景

### main_menu.gd 拆分（1260→890 行）
提取 `content_builder.gd`（406 行）：
- 所有百科/策略/叙事/教程内容构建函数
- 纯 static 函数，不持有 UI 节点引用
- main_menu.gd 通过 thin wrapper 委托

## 验证
- Godot headless boot: 通过
- main_menu.gd: 1260→890 行
- content_builder.gd: 新增 406 行
- theme: 159→289 行
