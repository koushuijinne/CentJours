# 开发日志 003

> **起始日期**: 2026-03-28
> **分支**: `auto/gameplay_update`

---

## 轮次 1: 行军主流程 GdUnit4 回归

日期: 2026-03-28
目标: 把行军主流程从纯人工点测推进到 GdUnit4 可重复验证
适用原则: TDD、核心循环优先、验证闭环、文档同步

改动:
- `tests/godot/main_menu_flow_test.gd` 新增 4 条行军流程测试：
  - `test_march_confirm_without_target_shows_selection_guidance` — 未选目标时确认行军，验证提示文案和状态不变
  - `test_invalid_march_target_shows_rejection_feedback` — 选择不可达节点（paris），验证拒绝反馈和 pending target 清空
  - `test_valid_march_target_confirm_advances_day_and_updates_location` — 选择合法邻接节点 → 确认 → 验证天数推进、位置更新、pending/policy 清空
  - `test_switching_away_from_march_clears_pending_target` — 选中行军目标后切换到休整，验证 pending target 清空和叙事切换
- GdUnit4 预期基线从 `41` 升到 `45`

验证:
- 所有 4 条测试的 API 引用已通过代码审计确认存在：`select_policy`、`select_node`、`get_pending_march_target`、`get_map_node`、`get_selected_policy_id`、`GameState.available_march_targets`、`GameState.napoleon_location`
- 所有 UI 文案断言已确认与生产代码一致
- 本轮未改生产代码，属于纯测试扩展
- Windows GdUnit4 运行时验证标记为待验证（当前环境为 WSL，按规则不补位）

提交/推送:
- 与文档同步一起提交并推送到 `auto/gameplay_update`

下一步:
- 继续按 P0 推进：补更多核心玩法状态流回归或处理 bugs_check 中的关键问题

---

## 轮次 2: 战斗/接见/休整成功推进 GdUnit4 回归

日期: 2026-03-28
目标: 补齐三种核心行动的成功提交 → 天数推进 → 状态重置回归
适用原则: TDD、核心循环优先、验证闭环、文档同步

改动:
- `tests/godot/main_menu_flow_test.gd` 新增 3 条行动成功推进测试：
  - `test_battle_submit_success_advances_day_and_resets_tray` — 战斗弹窗确认后天数推进到 2、阶段回 action、tray 清空、弹窗消失
  - `test_boost_submit_success_advances_day_and_resets_tray` — 接见弹窗确认后天数推进到 2、阶段回 action、tray 清空、弹窗消失
  - `test_rest_action_advances_day_without_popup` — 休整直接确认，不经弹窗，天数推进到 2、tray 清空
- GdUnit4 预期基线从 `45` 升到 `48`

验证:
- 所有 API 引用和 UI 节点名已通过代码审计确认
- 本轮未改生产代码，属于纯测试扩展
- Windows GdUnit4 运行时验证标记为待验证

提交/推送:
- 与文档同步一起提交并推送到 `auto/gameplay_update`

下一步:
- 继续按 P0 推进：补多日连续行动、政策冷却回归，或转向 bugs_check 关键问题

---

## 轮次 3: 政策冷却 + 连续两日行动 GdUnit4 回归

日期: 2026-03-28
目标: 验证政策冷却机制和多日连续行动的状态一致性
适用原则: TDD、核心循环优先、验证闭环、文档同步

改动:
- `tests/godot/main_menu_flow_test.gd` 新增 2 条测试：
  - `test_policy_action_triggers_cooldown_on_next_day` — 使用 public_speech 后 Day 2 卡片显示冷却
  - `test_two_consecutive_days_rest_then_march` — Day 1 休整 → Day 2 行军，验证天数、位置、tray 状态一致性
- GdUnit4 预期基线从 `48` 升到 `50`

验证:
- API 引用和 cooldown 机制已通过 Rust 源码和 GDScript 层审计确认
- 本轮未改生产代码
- Windows GdUnit4 运行时验证标记为待验证

提交/推送:
- 与文档同步一起提交并推送到 `auto/gameplay_update`

下一步:
- 继续按 P0 推进：补存读档后状态一致性、bugs_check 剩余项或更多边界回归

---

## 轮次 4: 测试文件按职责拆分

日期: 2026-03-28
目标: 响应用户反馈"大文件及时拆分"，把 1022 行的 main_menu_flow_test.gd 按职责拆成三个文件
适用原则: KISS、文档同步

改动:
- `tests/godot/main_menu_flow_test.gd` — 缩减为 250 行 / 11 tests：初始化、核心行动流、行军、政策冷却、多日连续行动
- `tests/godot/save_load_flow_test.gd` — 新建 393 行 / 13 tests：存读档槽位全链路
- `tests/godot/dialog_flow_test.gd` — 新建 419 行 / 15 tests：设置、战斗/接见弹窗、结局
- 测试总数不变：50 tests = 11 + 13 + 15 + 8 (map) + 3 (settings)
- 每个文件有独立的 before_test/after_test 和所需 helpers

验证:
- 测试总数审计：11 + 13 + 15 + 8 + 3 = 50，与拆分前一致
- 本轮未改生产代码
- Windows GdUnit4 运行时验证标记为待验证

提交/推送:
- 与文档同步一起提交并推送到 `auto/gameplay_update`

下一步:
- 继续按 P0 推进：bugs_check 剩余项或更多边界回归
