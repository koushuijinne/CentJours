# 开发日志 003

## 2026-03-29 第 1 轮
分支: `claude/review-project-status-05vxD`
范围: 收口真人试玩反馈，把原始人类文档转成结构化修复计划，并同步 live 文档优先级
变更:
- 保留原始人类反馈文档 [docs/advice/真实游玩体验.md](docs/advice/真实游玩体验.md) 不改写，仅作为来源材料提交入库。
- 将 4 张 P 社 UI 参考图和 1 张当前实际画面对照图归档到 `docs/reference_materials/visual/`，并更新 [docs/reference_materials/README.md](docs/reference_materials/README.md)。
- 新增 [docs/bugs/bug_real_playtest_2026-03-29.md](docs/bugs/bug_real_playtest_2026-03-29.md)，把真人试玩问题拆成行动经济重构、弹窗教程/事件、结局目标入口、中文优先收口、地图优先布局五条修复线。
- 更新 [docs/bugs/bug_index.md](docs/bugs/bug_index.md)，把这轮真人试玩问题登记为 `BUG-2026-03-29-REAL-PLAYTEST`。
- 更新 [docs/plans/dev_plan.md](docs/plans/dev_plan.md)，把 2026-03-29 真人试玩反馈提到当前 `P0`，并把阶段顺序重排为“真人试玩核心修复”优先于后续内容扩充。
- 更新 [docs/history/agent_handoff.md](docs/history/agent_handoff.md)，把接手优先级与当前已知缺口改成反映这轮真人试玩暴露的问题。
验证:
- 仅执行文档与引用整理，没有运行 Windows 构建、Rust tests 或 Godot 验证。
- 未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮与试玩反馈原文、参考图归档和计划文档同步一起提交并推送到 `claude/review-project-status-05vxD`。
下一步:
- 先按 `P0-1` 设计行动经济重构方案，再把真人试玩问题逐条转成 Rust / `GdUnit4` / Windows 真机回归项。

## 2026-03-29 第 2 轮
分支: `claude/review-project-status-05vxD`
范围: 落第一版 S1 真人试玩修复，并补齐 Windows 自动回归
变更:
- Rust / GDExt / GDScript 主链落地日内行动节奏：每天改为 `1` 次机动槽（行军 / 战役 / 休整）+ `2` 次决策点，并由玩家手动点击“结束今天 → 次日”推进到下一天。
- 主菜单新增教程 / 历史事件 / 结局目标 / 日志回看弹窗链，顶栏补“结局”“日志”，玩家可见主 UI 文本继续向中文收口，地图占比上调。
- 扩 `GdUnit4` 到 `57` 条，新增连续两日行动、存读档取消链、新局取消链、教程 modal 干扰链等回归；本轮还修了测试夹具，使跨天后会先关闭教程 modal，再继续验证真实交互状态。
- 更新 [docs/plans/dev_plan.md](docs/plans/dev_plan.md)、[docs/history/agent_handoff.md](docs/history/agent_handoff.md)、[docs/bugs/bug_real_playtest_2026-03-29.md](docs/bugs/bug_real_playtest_2026-03-29.md)、[docs/bugs/bug_validation_matrix_2026-03-28.md](docs/bugs/bug_validation_matrix_2026-03-28.md) 到当前基线。
验证:
- Windows `cargo test` 通过：`215/215`
- Windows `cargo build --features godot-extension` 通过
- Windows `GdUnit4` 通过：`57/57`
- Windows Godot 主项目无头启动通过
- Windows smoke scene 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 继续做 S1 第二轮 polish，优先补中文 UI 残留、地图真机可读性和弹窗文案密度。

## 2026-03-29 第 3 轮
分支: `claude/review-project-status-05vxD`
范围: 收口 `P0-A + P0-B + P0-C`，把最新真人试玩里的教程版式回归转成自动化护栏
变更:
- 在 [src/ui/main_menu/dialogs_controller.gd](../../../src/ui/main_menu/dialogs_controller.gd) 给统一信息弹窗补了固定宽度、滚动区最小宽度和正文最小宽度，避免长中文内容被挤成竖排窄列。
- 在 [tests/godot/main_menu_flow_test.gd](../../../tests/godot/main_menu_flow_test.gd) 新增教程弹窗宽度断言，把“前10天教程正文被压窄”的问题正式转成 `GdUnit4` 回归。
- 在 [src/ui/main_menu/layout_controller.gd](../../../src/ui/main_menu/layout_controller.gd) 做地图优先布局第二轮压缩：继续缩小右侧栏和 hover/锁定详情面板，让地图主区域更大。
- 在 [src/ui/main_menu.tscn](../../../src/ui/main_menu.tscn) 和 [src/ui/main_menu.gd](../../../src/ui/main_menu.gd) 清掉主菜单玩家可见英文占位，`Stendhal` 显示口径改为中性中文“日记摘录”，不改变后续 Bertrand 迁移 TODO。
- 更新 [docs/plans/dev_plan.md](../../plans/dev_plan.md)、[docs/history/agent_handoff.md](../agent_handoff.md)、[docs/bugs/bug_validation_matrix_2026-03-28.md](../../bugs/bug_validation_matrix_2026-03-28.md)，同步 `58/58` 基线和新护栏。
验证:
- Windows `cargo build --features godot-extension` 通过
- Windows `cargo test` 通过：`215/215`
- Windows `GdUnit4` 通过：`58/58`
- Windows Godot 主项目无头启动通过
- Windows smoke scene 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 继续扩长文本弹窗的版式回归与 Windows 真机观感清单，不把教程弹窗这一条护栏当成全量收口。
