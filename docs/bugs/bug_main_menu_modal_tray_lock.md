# BUG-2026-03-27-MAIN-MENU-MODAL-LOCK

## 标题

主菜单顶层 modal 打开时，`DecisionTray` 仍可继续交互

## 级别

P1

## 状态

已修复

## 来源

- 本轮主菜单状态机审计
- 关联代码：[main_menu.gd](/mnt/e/projects/CentJours/src/ui/main_menu.gd)

## 现象

- `新局`
- `存档槽位`
- `读档确认`

这些 modal 打开后，主托盘和“执行今日行动”按钮仍可能保持可点击状态。

## 风险

- 玩家可能在 modal 未关闭时继续提交行动。
- 存读档与行动执行之间会出现竞态，导致状态恢复链变得不可预测。
- 后续新增 modal 如果复用旧模式，会继续把这个漏洞带回去。

## 修复

- `main_menu.gd` 新增统一的 transient modal 状态机：
  - 打开 `新局`、`存档槽位`、`读档确认` 时锁住托盘
  - 关闭后按进入 modal 前的状态恢复
  - 连续 modal 链路用深度计数保护，避免“上一个弹窗刚关、下一个弹窗刚开”时误恢复
- `tests/godot/main_menu_flow_test.gd` 已新增 / 加强回归：
  - 存档槽位打开时执行按钮禁用
  - 存档槽位取消后恢复
  - `新局` 取消时恢复
  - `读档确认` 取消时恢复

## 回归

- Windows `GdUnit4`
- Windows Godot headless 主项目
- Windows Godot smoke scene

## 备注

- 这条规则只覆盖 `main_menu.gd` 自己创建的 transient modal。
- 战斗、接见和结局弹窗仍由 [dialogs_controller.gd](/mnt/e/projects/CentJours/src/ui/main_menu/dialogs_controller.gd) 负责，它们已有独立的托盘锁定链路。
