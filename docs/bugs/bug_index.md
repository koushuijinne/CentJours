# Bug 索引

## 用途

这里记录三类问题：

- 玩家可感知的功能 / UI bug
- 在开发过程中发现的代码层问题、验证噪音或结构缺陷
- 历史准确性 / 设定一致性 TODO

截图附件继续放在 `docs/bugs/`，但以后都要从本索引能追到具体问题条目。

## 字段约定

- `ID`
- `标题`
- `级别`
- `状态`
- `来源`
- `回归`
- `详情`

## 当前条目

| ID | 标题 | 级别 | 状态 | 来源 | 回归 | 详情 |
|----|------|------|------|------|------|------|
| `BUG-2026-03-24-UI-SWEEP` | 主菜单与地图首轮 bug sweep | P0 | 已修复 | [docs/bugs/bugs_check.md](docs/bugs/bugs_check.md) | Windows headless / smoke / `GdUnit4` | [docs/history/bug_audit_2026-03-24.md](docs/history/bug_audit_2026-03-24.md) |
| `BUG-2026-03-27-MAP-DETAIL-ANCHOR` | 地图 hover 预览与锁定详情位置跳变，长文本详情缺少稳定滚动护栏 | P1 | 已修复 | [docs/bugs/bugs_check.md](docs/bugs/bugs_check.md) | Windows headless / smoke / `GdUnit4` | [docs/bugs/bug_map_detail_anchor_and_scroll.md](docs/bugs/bug_map_detail_anchor_and_scroll.md) |
| `BUG-2026-03-27-MAIN-MENU-MODAL-LOCK` | 主菜单顶层 modal 打开时，`DecisionTray` 仍可继续交互 | P1 | 已修复 | 本轮主菜单状态机审计 | Windows headless / smoke / `GdUnit4` | [docs/bugs/bug_main_menu_modal_tray_lock.md](docs/bugs/bug_main_menu_modal_tray_lock.md) |
| `BUG-2026-03-27-SAVE-SLOT-GUARDS` | 多槽存档缺少覆盖确认与删除入口，确认弹窗可能残留 modal 锁定 | P1 | 已修复 | 发布前主菜单存档流程审计 | Windows headless / smoke / `GdUnit4` | [docs/bugs/bug_save_slot_overwrite_and_delete.md](docs/bugs/bug_save_slot_overwrite_and_delete.md) |
| `BUG-2026-03-27-EVENTBUS-WARNINGS` | `EventBus` 声明型 signal 在 `GdUnit4` 中持续产生 warning 噪音 | P2 | 已修复 | 本轮 `GdUnit4` 日志审计 | Windows headless / smoke / `GdUnit4` | [docs/bugs/bug_eventbus_signal_warnings.md](docs/bugs/bug_eventbus_signal_warnings.md) |
| `BUG-2026-03-28-VALIDATION-MATRIX` | 将关键 bug 收口为自动化回归与 Windows 真机清单 | P1 | 已建立 | 本轮验证链收口 | Windows headless / smoke / `GdUnit4` | [docs/bugs/bug_validation_matrix_2026-03-28.md](docs/bugs/bug_validation_matrix_2026-03-28.md) |
| `BUG-2026-03-28-HISTORICAL-NARRATOR` | 百日王朝叙事者历史准确性错误：当前仍以 Stendhal 作为在场日记叙事者 | P1 | 待处理 | 2026-03-28 历史审校 | TODO 清单 | [docs/bugs/bug_historical_narrator_accuracy.md](docs/bugs/bug_historical_narrator_accuracy.md) |

## 维护规则

- 新 bug 先建条目，再做修复
- 修复完成后必须补“回归”字段
- 纯截图不算 bug 记录
- 同一个问题如果既有历史审计文档，又有当前修复条目，以当前条目为准，历史文档作为来源材料
