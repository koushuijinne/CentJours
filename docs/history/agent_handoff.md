# Agent 交接

> **更新**: 2026-03-24
> **当前分支**: 以 `git branch --show-current` 为准
> **目标读者**: 新开会话后需要快速接手项目的 agent / 协作者
> **开发历史**: 见 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时使用 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前项目状态

- 正式入口为 `src/ui/main_menu.tscn`，主循环 `TurnManager -> CentJoursEngine -> GameState -> UI` 已接通。
- Rust 规则层当前基线是 `175/175` 测试通过。
- 当前核心数据基线：`15` 名角色、`41` 个地图节点、`58` 条历史事件，其中 `major 16 / normal 35 / minor 7`。
- 当前活跃开发分支为 `auto/gameplay_update`。
- Save / Load 已进入 `v2` 兼容路径，旧存档会把 `fontainebleau_eve` 迁移为正式 ID `tuileries_eve`。
- 历史事件正文、`historical_note` 与玩家行动结算日志都已接入侧栏日志链路。
- 动态补给已接进核心循环：补给值会进入存档、`get_state()`、主菜单顶栏、休整恢复、战斗补给惩罚和每日行动结算日志。
- 首个玩家可控补给政策 `requisition_supplies / 征用沿线仓储` 已接入政策表、叙事池、模拟策略和 UI 元数据。
- 行军预览现在会优先读取 Rust 引擎返回的权威预测值，能在确认前直接显示预计补给 / 疲劳 / 士气变化；只有接口不可用时才退回前端轻量提示。
- 文档目录已重构为 `docs/plans`、`docs/rules`、`docs/history`、`docs/decisions`，开发历史已从 live 计划文档中抽离到 `docs/history/development_logs/`。
- 前端已拆出 `map / layout / tray / sidebar / dialogs` 控制器，但发布级视觉和交互收口仍未完成。
- Windows 原生 Godot 与 Windows 无头仍是默认验证路径；不要把 Linux / WSL Godot 无头结果当成默认结论。
- 当前环境未安装 `x86_64-pc-windows-gnu` target，本轮 `cargo build --features godot-extension` 只更新了 Linux `.so`；Windows Godot 无头能启动，但加载的仍是旧 `cent_jours_core.dll`。

## 当前最高优先级

1. 把补给系统继续产品化：补给来源、前线压力、玩家可控补给手段、失败解释与教学
2. 把历史事件从 `58` 条继续推到 `100+`，并逐条完成文本 QA
3. 补前 10 天引导、失败归因、结局文本和关键 UI 文案统一
4. 收口 F5：`DecisionTray`、`Map Inspector`、中英混排与设置入口
5. 固化 Windows 发布链路与 Steam 提审资料清单

## 当前已知缺口

- `内容量仍不足`：事件池距离 `100+` 目标还差 `42` 条
- `补给玩法还不够显式`：底层压力已经接通，但玩家还缺少明确的补给操作、反制手段和教学提示
- `补给反馈还不够可操作`：玩家现在能在行军前看到 Rust 权威预测，但为何会断补给、如何补救、什么时候该停下整补，还缺更明确的解释与教学
- `文本 QA 未收口`：剩余事件仍需统一史实锚点、信息密度和句式风格
- `前端发布级 polish 未完成`：结构问题已缓解，但仍需 Windows 真机持续验收
- `产品化能力仍缺`：设置/选项页、导出配置、Steam 商店素材、教程引导都未完成
- `Windows GDExt 验证仍有缺口`：本轮 Windows Godot 无头只能证明项目能起，不能证明新的 Rust 扩展逻辑已随 DLL 更新进入运行时
- `最终资产仍是占位`：地图底图、肖像、插图、BGM、SFX、结局画面还没替换

## 当前写入边界

### 主 agent 推荐独占

- `src/ui/main_menu.gd`
- `src/ui/main_menu.tscn`
- `cent-jours-core/src/engine/state.rs`
- `cent-jours-core/src/lib.rs`
- `src/core/turn_manager.gd`
- `src/core/event_bus.gd`

### 叶子模块

- `src/ui/main_menu/map_controller.gd`
- `src/ui/main_menu/map_render_controller.gd`
- `src/ui/main_menu/layout_controller.gd`
- `src/ui/main_menu/tray_controller.gd`
- `src/ui/main_menu/sidebar_controller.gd`
- `src/ui/main_menu/dialogs_controller.gd`
- `src/ui/components/decision_card.gd`
- `src/ui/main_menu/main_menu_config.gd`
- `src/ui/main_menu/ui_formatters.gd`

### 协作原则

- 主 agent 负责集成、装配、接口冻结和最终回归
- 若继续拆主菜单，优先按职责和数据流拆，不按页面名字拆
- `main_menu.gd` 与 `main_menu.tscn` 仍适合由主 agent 独占，避免并行写冲突

## 默认验证要求

- Rust 改动：`cd cent-jours-core && cargo test`
- Rust + GDExt API 改动：Windows 侧执行

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 若新增 GDExt 接口，再补一次 smoke scene：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours res://src/dev/engine_smoke_test_scene.tscn
```

- 视觉、布局和滚动问题以 Windows 真机验收为最终准绳

## 新会话最少必读文件

- [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
- [docs/plans/development_plan.md](/mnt/e/projects/CentJours/docs/plans/development_plan.md)
- [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
- [docs/decisions/ADR-008-historical-events-expansion.md](/mnt/e/projects/CentJours/docs/decisions/ADR-008-historical-events-expansion.md)
- [docs/history/historical_event_review.md](/mnt/e/projects/CentJours/docs/history/historical_event_review.md)

## 接手注意点

- 不要默认回退工作区里的现有改动
- 不要把 Linux / WSL Godot 无头测试当成默认步骤
- 若继续做内容线，先按 `ADR-008` 和 `historical_event_review` 的修订意见推进
- 若继续做玩法线，优先把补给压力扩成明确的玩家决策，而不是继续堆纯后台数值
- 自动工作流开启时，每轮提交后都要先在对话里输出一份完整压缩摘要，再继续下一轮；这不是结束语
- `tuileries_eve` 现为正式事件 ID；旧 ID 只应出现在迁移代码和兼容性测试里
- 允许直接修改文案，但必须遵守 ADR-008：直接、清楚、可考据，避免 reframing 句式
- 若继续做 UI 线，优先解决玩家可感知问题，再做大文件工程收口
- 若用户明确要求自动循环，再额外启用 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

## 维护约定

- 本文件只保留当前状态、当前优先级、当前验证方式、当前下一步
- 多轮开发历史不要继续回灌到本文件；统一写入 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
- 若默认验证方式变化，更新本文件与 [docs/plans/development_plan.md](/mnt/e/projects/CentJours/docs/plans/development_plan.md)
- 若接手模板变化，更新 [docs/rules/agent_session_prompts.md](/mnt/e/projects/CentJours/docs/rules/agent_session_prompts.md)
