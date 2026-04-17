# Development Log 014 — log_narrative 机动槽 Bug + 测试稳定化

> **日期**: 2026-04-17
> **分支**: `claude/review-project-status-05vxD`
> **任务**: S0-3 测试稳定化 + 游戏性 Bug 修复

## 关键 Bug 修复：教程弹窗吃机动槽

### 根因
`_maybe_show_daily_tutorial_popup()` 调用 `TurnManager.submit_action("log_narrative", ...)` 记录教程到叙事日志，但 `_run_action_step` 的 match 语句没有 `"log_narrative"` 分支，落入默认 `_:` 分支执行 `engine.execute_day_rest()`。

**后果**: Day 1-10 每天教程弹窗出现时，Rust 引擎静默执行一次休整，占用玩家当日唯一的机动槽。相当于前 10 天玩家无法行军/战役。

### 修复
- `_run_action_step` 新增 `"log_narrative"` 早期返回：只 emit `micro_narrative_shown` 信号，不接触 Rust 引擎
- 这是产品级 Bug：影响所有新局前 10 天的可玩性

## 测试稳定化

### `_end_day` 轮询替代固定帧数
- 旧方案：`simulate_frames(20)` + `simulate_frames(8)` 等待 `call_deferred("_begin_next_turn")` 完成
- 新方案：轮询 `GameState.current_day > day_before && current_phase == "action"`，最多 60 帧
- 消除全部 5 个 timing flaky：lines 180, 212, 219, 287, 293

### `reset_engine()` 同步 `GameState.current_phase`
- Bug: `reset_engine()` 重置 `TurnManager.current_phase` 但不重置 `GameState.current_phase`
- 后果: 下一个测试的 `_refresh_ui()` 看到 `current_phase == "action"` 并尝试 `submit_action`，触发 `[TurnManager] 当前不在行动阶段` 警告
- 修复: `reset_engine()` 同步设置 `GameState.current_phase = "dawn"`

### `_ready()` deferred 调用顺序
- 旧顺序: `_refresh_ui` → `_start_game` — UI 刷新时游戏还没进入行动阶段
- 新顺序: `_start_game` → `_refresh_ui` — 先初始化游戏再刷新 UI

### 新增测试
- `test_game_over_shows_failure_attribution_when_key_decisions_exist`: 验证游戏结束弹窗中失败归因区段正确显示关键决策

## 验证
- GdUnit4 全套: 77/77 (5 suites, 0 failures, 0 flaky, 0 warnings) ✓
- Rust: cargo test ✓
- Godot headless: 无错误 ✓

## 基线变化
- GdUnit4: 76 → 77 tests
- QA 自动化通过: 43 → 46 / 54
- 真机待验: 10 → 8
- 已知 flaky: 1 → 0
