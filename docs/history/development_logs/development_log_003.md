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

## 2026-03-29 第 4 轮
分支: `claude/review-project-status-05vxD`
范围: 收口设置弹窗语义、百科解释深度与地图空白点击清空链，并用全量 Windows 验证兜底
变更:
- 在 [src/ui/main_menu.gd](../../../src/ui/main_menu.gd)、[src/ui/main_menu/tray_controller.gd](../../../src/ui/main_menu/tray_controller.gd)、[src/ui/main_menu/topbar_actions_controller.gd](../../../src/ui/main_menu/topbar_actions_controller.gd) 拆开 Tray 锁定原因，区分 `modal / resolving / processing / game_over`，修复“打开设置后托盘提示误写成正在结束今天”的问题。
- 在 [src/ui/main_menu/dialogs_controller.gd](../../../src/ui/main_menu/dialogs_controller.gd) 给设置、信息、战斗、接见等弹窗统一标注锁定原因，避免 modal 复用结算态。
- 在 [src/core/politics/political_system.gd](../../../src/core/politics/political_system.gd) 与 [src/ui/main_menu.gd](../../../src/ui/main_menu.gd) 扩写百科正文，明确红黑指数的当前倾向、合法性的作用、阈值收益和提高路径。
- 在 [src/ui/main_menu/map_controller.gd](../../../src/ui/main_menu/map_controller.gd) 修掉“点击地图空白后 hover 立刻被鼠标停留位置吸回”的状态机 bug，增加 hover 抑制直到真实鼠标移动。
- 在 [tests/godot/dialog_flow_test.gd](../../../tests/godot/dialog_flow_test.gd)、[tests/godot/main_menu_flow_test.gd](../../../tests/godot/main_menu_flow_test.gd)、[tests/godot/map_controller_contract_test.gd](../../../tests/godot/map_controller_contract_test.gd) 补对应回归；`map_controller_contract_test.gd` 新增“空白点击清空后，鼠标移动才能恢复 hover”用例。
- 更新 [docs/plans/dev_plan.md](../../plans/dev_plan.md)、[docs/history/agent_handoff.md](../agent_handoff.md)、[docs/bugs/bug_validation_matrix_2026-03-28.md](../../bugs/bug_validation_matrix_2026-03-28.md)，把当前 P0、验证矩阵和基线同步到这轮真实结果。
验证:
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot/map_controller_contract_test.gd` 通过：`10/10`
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot` 通过：`64/64`
- Windows Godot 主项目无头启动通过
- Windows smoke scene 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 继续收口 `S1-8` 行动面板禁用态与分区重排，并把百科第一版继续补到补给与结局关联。

## 2026-03-29 第 5 轮
分支: `claude/review-project-status-05vxD`
范围: 把单条 Windows 验证链拆成 `fast / full / heavy-nightly` 三层，降低本地等待成本
变更:
- 在 [tools/run_gdunit_windows.cmd](../../../tools/run_gdunit_windows.cmd) 增加多测试路径支持；现在可以一次刷新 Godot 缓存后串行执行多个 `GdUnit4` 套件，供 `windows-fast` 复用。
- 新增 [windows-fast.yml](../../../.github/workflows/windows-fast.yml)，在开发分支 `push / pull_request` 上执行 Rust 快速测试、Windows GDExt build、核心 `GdUnit4` 和 headless boot。
- 将 [windows-validation.yml](../../../.github/workflows/windows-validation.yml) 重定义为 `windows-full`，保留开发分支 `push + workflow_dispatch` 的全量 `cargo test`、全量 `GdUnit4` 与 smoke scene。
- 新增 [windows-heavy-nightly.yml](../../../.github/workflows/windows-heavy-nightly.yml)，在 `schedule + workflow_dispatch` 下执行 Monte Carlo 长测和 `PROPTEST_CASES=1024` 的大样本属性测试。
- 更新 [README.md](../../../README.md)、[docs/architecture.md](../../architecture.md)、[docs/interfaces.md](../../interfaces.md)、[docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md](../../decisions/ADR-010-bug-sweep-and-validation-discipline.md)、[docs/plans/dev_plan.md](../../plans/dev_plan.md)、[docs/history/agent_handoff.md](../agent_handoff.md)，把 CI 口径同步成“三层云端验证 + 本地最小验证”。
验证:
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot/dialog_flow_test.gd res://tests/godot/settings_manager_test.gd` 通过，确认多路径执行可用
- 本地 `python3 tools/check_doc_sync.py --files ...` 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 观察首轮 `windows-fast / windows-full / windows-heavy-nightly` 的云端稳定性，再继续推进 `S1-8` 的行动面板语义重排。

## 2026-03-29 第 6 轮
分支: `claude/review-project-status-05vxD`
范围: 修复真人试玩 `05` 的 modal 外部关闭灰态残留，并把回归护栏补到设置 / 百科两条链
变更:
- 在 [src/ui/main_menu/topbar_actions_controller.gd](../../../src/ui/main_menu/topbar_actions_controller.gd) 给设置、新局、存读档和确认弹窗补 `exclusive = true`，并把 transient modal 的 `visibility_changed + tree_exiting` 收尾链补齐，避免外部 hide 后残留 modal 深度。
- 在 [src/ui/main_menu/dialogs_controller.gd](../../../src/ui/main_menu/dialogs_controller.gd) 给信息、难度、战役、接见弹窗统一接入 tracked modal 回收；外部 hide 会自动恢复 Tray，提交型关闭则通过 suppress 标记避免误把 processing 态恢复成可交互。
- 在 [tests/godot/dialog_flow_test.gd](../../../tests/godot/dialog_flow_test.gd) 新增 `test_settings_popup_hidden_externally_restores_action_interactivity`，验证设置弹窗被外部关闭后不会留下灰态按钮。
- 在 [tests/godot/main_menu_flow_test.gd](../../../tests/godot/main_menu_flow_test.gd) 新增 `test_glossary_popup_hidden_externally_restores_action_interactivity`，验证百科弹窗同样具备恢复链。
- 更新 [docs/plans/dev_plan.md](../../plans/dev_plan.md)、[docs/history/agent_handoff.md](../agent_handoff.md)、[docs/bugs/bug_validation_matrix_2026-03-28.md](../../bugs/bug_validation_matrix_2026-03-28.md)，同步最新真人试玩 `05` 的修复状态和验证入口。
验证:
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot/dialog_flow_test.gd res://tests/godot/main_menu_flow_test.gd` 通过：`37/37`
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot` 通过：`66/66`
- Windows Godot 主项目无头启动通过
- Windows smoke scene 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 继续推进 `S1-8` 行动面板禁用态与分区重排，并补更多 modal 组合链的 Windows 真机验收。

## 2026-03-29 第 7 轮
分支: `claude/review-project-status-05vxD`
范围: 落第一版 `S1-8` 行动面板语义包，并用全量 Windows `GdUnit4` 重新立基线
变更:
- 在 [src/ui/main_menu.gd](../../../src/ui/main_menu.gd) 把 Tray 提示改成状态驱动：直接说明今天还剩多少机动 / 决策预算，并按预算切换说明文案。
- 在 [src/ui/main_menu.gd](../../../src/ui/main_menu.gd) 和 [src/ui/main_menu/tray_controller.gd](../../../src/ui/main_menu/tray_controller.gd) 让确认按钮按当前选择切换“先选择动作 / 执行机动 / 执行决策”，不再用一条固定文案覆盖所有动作。
- 在 [src/ui/main_menu/tray_controller.gd](../../../src/ui/main_menu/tray_controller.gd) 给托盘补了显式“机动 / 决策”分区，并把禁用态从布尔值升级成“带原因的禁用状态”。
- 在 [src/ui/components/decision_card.gd](../../../src/ui/components/decision_card.gd) 增加 `disabled_reason`，决策点耗尽时卡片会直接显示“决策点已用尽”，机动已用时会显示“今日机动已用”。
- 在 [tests/godot/main_menu_flow_test.gd](../../../tests/godot/main_menu_flow_test.gd) 新增行动预算提示、确认按钮语义和禁用原因断言；在 [tests/godot/dialog_flow_test.gd](../../../tests/godot/dialog_flow_test.gd) 同步设置弹窗下按钮文案的最新口径。
- 更新 [docs/plans/dev_plan.md](../../plans/dev_plan.md)、[docs/history/agent_handoff.md](../agent_handoff.md)、[docs/bugs/bug_validation_matrix_2026-03-28.md](../../bugs/bug_validation_matrix_2026-03-28.md)，把 `S1-8` 状态和 `68/68` 基线同步为当前真值。
验证:
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot/main_menu_flow_test.gd` 通过：`19/19`
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot/dialog_flow_test.gd` 通过：`20/20`
- Windows `tools\\run_gdunit_windows.cmd ... res://tests/godot` 通过：`68/68`
- Windows Godot 主项目无头启动通过
- Windows smoke scene 通过
- 未运行 Linux / WSL 侧测试
提交/推送:
- 待本轮统一提交
下一步:
- 继续把 `S1-8` 从“语义清楚”推进到“视觉层级更清楚”，优先补真机观感和更强的机动 / 决策区分。
