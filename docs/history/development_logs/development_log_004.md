# Development Log 004 — S2-3 结构化教程流第一版

> **日期**: 2026-04-13
> **分支**: `claude/review-project-status-05vxD`
> **任务**: S2-3 前 10 天新手教程流

## 本轮完成

### 教程数据层
- 新建 `src/data/tutorials/tutorial_stages.json`，定义 10 个教程阶段（Days 1-10）
- 每阶段包含：id、day_range、topic、title、body、operation_guide、可选 condition_hint
- 覆盖 7 个主题：overview / movement / supply / politics / command_deviation / strategy / diplomacy / summary

### 教程引擎层 (main_menu.gd)
- 新增 `_load_tutorial_stages()` 从 JSON 加载教程数据
- 新增 `_get_tutorial_stage_for_day()` 按日期匹配教程阶段
- 重构 `_maybe_show_daily_tutorial_popup()` 使用结构化阶段内容，附加条件提示和操作指南
- 保留 `_build_tutorial_hint_text()` 用于地图副标题的简短提示，按主题分类

### 侧栏政治教学 (sidebar_controller.gd)
- 新增 `_build_boost_loyalty_preview_text()` 包含将领忠诚度教学和前 10 天提示
- 新增 `boost_loyalty` 的 `_policy_recommendation()` 分支，根据合法性和忠诚度给出建议

### 测试 (main_menu_flow_test.gd)
- 新增 6 条 GdUnit4 测试：
  - `test_tutorial_popup_day1_shows_structured_welcome` — Day 1 弹窗内容
  - `test_tutorial_popup_day2_shows_movement_topic` — Day 2 行军主题
  - `test_tutorial_no_popup_after_day10` — Day 11 无弹窗
  - `test_tutorial_stages_json_loads_all_10_stages` — JSON 数据完整性
  - `test_tutorial_covers_all_core_topics` — 覆盖三大核心主题
  - `test_boost_loyalty_preview_includes_tutorial_guidance` — 政治教学内容
- 修复 `test_strategy_goals_popup` 的断言错误（"结局路线提示"→"结局路线"）

## 验证
- Rust: `cargo test 215/215` 通过
- Godot headless boot: 通过（无脚本错误）
- GdUnit4 main_menu_flow: 20/26 通过（3 个为 pre-existing failures，与本轮改动无关）

## 未验证
- Windows 真机换行/遮挡检查
- 教程弹窗的实际游玩手感

## 下一步
- S2-4 中期张力补强（Day 20-80 定时危机/叛变/联军压力曲线）
- 教程流的交互式引导（不只是文本弹窗，加入高亮和引导箭头）
