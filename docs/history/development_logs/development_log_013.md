# Development Log 013 — UI 溢出修复 + 构建链 + EventBus 修复

> **日期**: 2026-04-15 ~ 2026-04-16
> **分支**: `claude/review-project-status-05vxD`
> **任务**: 反馈 06 响应 + S6-2 构建链 + S0-3 测试扩展

## 反馈 06 响应

### 画面溢出修复
- **根因**: `apply_responsive_layout` 中侧栏面板和托盘各自独立计算 `custom_minimum_size`，总和可能超过视口高度
- **修复**: 
  - 新增视口高度预算系统：先算出可用高度，再按比例分配给侧栏（局势 40% / 叙事 35% / 忠诚 25%）
  - 托盘封顶在可用高度的 35%
  - `RootLayout.clip_contents = true` 安全兜底
- **回归**: `test_layout_does_not_overflow_viewport` GdUnit4 测试

### 优先级调整
- 用户反馈：翻译优先级调低，MVP 完整度优先
- 已停止 i18n 扩展，转向核心 MVP 交付

## EventBus 信号缺失修复
- `node_selection_cleared` 信号在 `map_controller.gd:446` 被 emit 但未在 `event_bus.gd` 声明
- 修复后 map_controller 测试 10/10 通过
- 全套 GdUnit4 76/76 通过（之前卡在 debugger break）

## Windows 发布构建链 (S6-2)
- `export_presets.cfg`: Windows Desktop 导出预设
- `tools/build_release.cmd`: Rust release 构建 + Godot 导出脚本
- Release DLL 构建验证通过（4.5MB 优化版）
- 阻塞：需安装 Godot export templates

## i18n 深化（反馈前完成）
- 182 → 210 翻译键
- content_builder.gd + map_controller.gd 22 个章节标题 tr() 化

## 验证
- Godot headless: 无错误 ✓
- GdUnit4 全套: 76/76 (5 suites) ✓
- Rust release: cargo build --features godot-extension ✓
- map_controller tests: 10/10 ✓
- main_menu_flow tests: 27/27 ✓

## 基线变化
- GdUnit4: 68 → 76 tests
- 翻译键: 182 → 210
- 设置系统: 55% → 75%（语言切换已加入）
- 本地化: 45% → 50%
