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
