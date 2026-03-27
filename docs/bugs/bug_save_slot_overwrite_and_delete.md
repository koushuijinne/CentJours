# BUG-2026-03-27-SAVE-SLOT-GUARDS

## 标题

多槽存档缺少覆盖确认与删除入口，已保存槽位容易被误覆盖，也无法在 UI 内清理。

## 级别

P1

## 状态

已修复

## 来源

- 发布前主菜单存档流程审计
- `docs/plans/dev_plan.md` 中的多槽存档 UI 技术债

## 问题表现

- 玩家点击已有存档槽位时会直接覆盖，没有二次确认。
- 读档弹窗和存档弹窗都没有删除入口，只能通过外部文件操作清理槽位。
- 槽位确认弹窗进入后，若只依赖默认 UI 行为关闭确认框，`DecisionTray` 的 modal 锁定状态容易残留。

## 修复内容

- 多槽存档在覆盖已有槽位前，先弹出 `SaveOverwriteConfirmDialog`。
- 已存在的槽位在存档 / 读档弹窗中都增加删除按钮。
- 覆盖确认、删除确认、新局确认、读档确认在 `confirmed` 回调里都显式关闭确认弹窗，再执行后续业务，避免 transient modal depth 残留。
- 存档槽位摘要现在会在确认文案里显示 `Day X · 结局状态`，降低误操作成本。

## 回归

- Windows `GdUnit4`
  - `test_existing_save_slot_requires_overwrite_confirmation`
  - `test_delete_save_from_load_picker_removes_slot`
- Windows Godot headless 主项目
- Windows Godot smoke scene

## 相关文件

- [src/ui/main_menu.gd](/mnt/e/projects/CentJours/src/ui/main_menu.gd)
- [tests/godot/main_menu_flow_test.gd](/mnt/e/projects/CentJours/tests/godot/main_menu_flow_test.gd)
