# Agent 交接

> **更新**: 2026-03-25
> **当前分支**: 以 `git branch --show-current` 为准
> **目标读者**: 新开会话后需要快速接手项目的 agent / 协作者
> **开发历史**: 见 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时使用 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)
> **当前总目标**: 按 [ADR-011](/mnt/e/projects/CentJours/docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 收口核心玩法，达到 Steam 可上线级别

---

## 当前项目状态

- 正式入口为 `src/ui/main_menu.tscn`，主循环 `TurnManager -> CentJoursEngine -> GameState -> UI` 已接通。
- Rust 规则层最近一次完整回归基线是 Windows `211/211`；自动工作流后续不再把 Linux / WSL `cargo test` 当成默认验证路径。
- 当前核心数据基线：`15` 名角色、`41` 个地图节点、`58` 条历史事件，其中 `major 16 / normal 35 / minor 7`。
- 当前活跃开发分支为 `auto/gameplay_update`。
- Godot 前端第一批 `GdUnit4` 自动回归已接入，当前 Windows 基线包含 `GdUnit4 7/7`、Windows Godot 主项目无头和 Windows smoke scene；Windows CI workflow 与本地脚本入口也已写入仓库。
- Save / Load 已进入 `v3` 兼容路径，旧存档会把 `fontainebleau_eve` 迁移为正式 ID `tuileries_eve`，前沿粮秣站状态也会随存档读写。
- 历史事件正文、`historical_note` 与玩家行动结算日志都已接入侧栏日志链路。
- 动态补给已接进核心循环：补给值会进入存档、`get_state()`、主菜单顶栏、休整恢复、战斗补给惩罚和每日行动结算日志。
- 首个玩家可控补给政策 `requisition_supplies / 征用沿线仓储` 已接入政策表、叙事池、模拟策略和 UI 元数据。
- 第二个玩家可控补给政策 `stabilize_supply_lines / 整顿驿站运输` 已接入：它会短期提高补给线效率，并进存档、预判、结算日志和叙事链。
- 第三个玩家可控补给政策 `establish_forward_depot / 建立前沿粮秣站` 已接入：它会在当前驻地留下短期容量加成，并把这层状态同步到预判、地图检查器、地图渲染和存档。
- 第四个玩家可控补给政策 `secure_regional_corridor / 巩固区域走廊` 已接入：它会同时保线并加固当前驻地，把脆弱中继线先稳成可持续走廊。
- 行军预览现在会优先读取 Rust 引擎返回的权威预测值，能在确认前直接显示预计补给 / 疲劳 / 士气变化，并拆开显示仓储容量、补给线效率、预计可得量和需求；只有接口不可用时才退回前端轻量提示。
- 行动后的补给结算现在会写出节点容量、需求 / 可得量与下一步建议，玩家已经能在结算日志里直接看到“为什么缺补给、该怎么补救”。
- 侧栏政策预览现在会根据当前补给值和前 10 天阶段给出情境化建议，开始把补给教学直接嵌进 UI。
- 地图检查器和行军预判现在会明确显示补给角色、有效容量、最近补给枢纽与跳数；地图渲染也会标出前沿粮秣站、战略枢纽和前线消耗点。
- 引擎状态现在会给出后勤态势与阶段目标；侧栏、决策区提示和地图副标题会统一展示这层建议，当前行动目标不再只靠玩家自己读数字。
- 当前驻地和行军落点现在会给出补给窗口提示，直接告诉玩家大约还能撑几天，或是否已经跌进战斗惩罚区。
- 行军预判现在还会给出第二跳推进风险，直接告诉玩家落点后还剩几条相对稳妥的继续推进路线，以及哪条后续线路更稳。
- 引擎状态现在还会给出阶段运营目标，明确这一阶段该优先抢哪类节点；侧栏、地图副标题和行军预判都会复用这层目标。
- 引擎状态现在还会给出“当日行动计划”：当前优先动作、备选动作，以及推荐行军目标；侧栏、`DecisionTray` 提示、地图副标题、行军预判和终局复盘都会复用这层建议。
- 引擎状态现在还会给出“三日后勤节奏”：今天、明天、后天该怎么排动作和节点承接；侧栏、`DecisionTray` 提示、行军预判和终局复盘都会复用这层节奏建议。
- 引擎状态现在还会给出“区域运营链路”：当前节点、下一跳和后续承接点的推荐节点线；侧栏、地图副标题、行军预判和终局复盘都会复用这层建议。
- 引擎状态现在还会给出“区域运营压力”：当前这片线路是承压、脆弱、稳固中还是可持续；侧栏、地图副标题、行军预判、政策预览和终局复盘都会复用这层反馈。
- `DecisionTray` 提示现在会在前 10 天主动输出后勤教程链，根据补给窗口和阶段目标告诉玩家何时该先补给、何时该先抢整补节点。
- 终局复盘现在会带上终盘补给、最后位置、后勤态势、阶段运营目标和补给窗口，失败归因已经开始接后勤节奏。
- 三张补给牌的侧栏预览现在会直接给出“优先 / 可考虑 / 暂缓”的即时建议，政策选择已经开始和当前后勤态势直接对齐。
- 终局复盘现在还会把失败归因落到具体补给牌和节奏错误，例如补给牌打晚、没及时保线、没把中继节点铺成跳板。
- 主菜单 bug sweep 已完成第一轮闭环：前 10 天教程重复、地图 hover 面板挡图、城市详情窄列换行、读档阶段错位、单槽读档、缺少新局入口和“执行行动”语义不清等问题已收口。
- 地图现在支持 `MapScroll + 滚轮缩放 + 右键复位`，并拆成“hover 小预览 + click 锁定详情”两层；多槽存读档与顶栏 `新局` 入口也已接通。
- `docs/bugs/bugs_check.md` 的第二轮问题已进入收口：叙事面板超屏、hover 与锁定详情位置跳变、存读档弹窗报错，均按 ADR-010 的规则继续处理。
- 文档目录已重构为 `docs/plans`、`docs/rules`、`docs/history`、`docs/decisions`，开发历史已从 live 计划文档中抽离到 `docs/history/development_logs/`。
- 前端已拆出 `map / layout / tray / sidebar / dialogs` 控制器，但发布级视觉和交互收口仍未完成。
- Windows 原生 Godot 与 Windows 无头仍是默认验证路径；不要把 Linux / WSL Godot 无头结果当成默认结论。
- 自动工作流下不要运行 Linux / WSL 侧测试，包括 Linux `cargo test` 和 Linux Godot 无头；若 Windows 验证链暂时不完整，就明确写“未验证”，不要用 Linux 结果补位。
- 当前这条补给玩法切片已经完成 Windows `cargo test`、Windows DLL 重编、Windows 主项目无头启动和 Windows smoke scene；smoke 输出已确认新 `logistics_route_chain_*`、`logistics_regional_pressure_*` 字段和 `secure_regional_corridor` 建议进入 Windows 运行时。自动工作流后续不再回到 Linux / WSL 侧测试补位。

## 当前最高优先级

1. 观察并修正 Windows GitHub Actions 首轮云端结果
2. 把 `docs/bugs` 中的关键问题继续转成可重复验证
3. 继续扩 Godot `GdUnit4` 覆盖面
4. 在测试护栏稳定后继续推进补给玩法产品化
5. 然后再扩历史事件、教学链和发布级 polish

## 当前已知缺口

- `内容量仍不足`：事件池距离 `100+` 目标还差 `42` 条
- `补给玩法还不够显式`：底层压力、四张补给政策、后勤态势 / 阶段目标 / 当日行动计划 / 三日节奏 / 区域运营链路 / 区域运营压力已经接通，但仍缺更强的区域运营感和更长期的前线节奏设计
- `补给教学还没收口`：玩家现在已经能看到风险来源、阶段目标、当日行动计划和三日节奏，也能从终局复盘回看建议，但仍缺更系统的失败归因串联
- `文本 QA 未收口`：剩余事件仍需统一史实锚点、信息密度和句式风格
- `前端发布级 polish 未完成`：主菜单主要 bug 已清一轮，但仍需 Windows 真机继续看地图缩放、hover 预览和存读档弹窗的最终体验
- `Windows CI 仍待首轮绿灯`：首次云端运行已失败，原因是 workflow 误写了不存在的 `win64_console` 下载地址；该问题已在仓库修正，正等待下一次云端结果
- `产品化能力仍缺`：设置/选项页、导出配置、Steam 商店素材、教程引导都未完成
- `Windows 真机体验验收仍未收口`：这轮已经补齐 Windows DLL 重编、Windows 无头与 smoke scene，但更长时的真机 UI / 体验验收还没补
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

- 自动工作流开启时，不运行 Linux / WSL 侧测试，包括 Linux `cargo test`、Linux Godot 无头和任何 WSL 侧补位验证
- Rust + GDExt API 改动：Windows 侧执行 `cargo build --features godot-extension`
- Godot 前端测试策略：`GdUnit4 + smoke + Windows 真机`
- 没有 Windows 对应验证就写明缺口，不要把 Linux / WSL 结果写成当前轮验证结论
- 在新 checkout / 新环境上执行 `GdUnit4` 前，先跑一次 Windows Godot `--headless --editor --quit`，刷新脚本类缓存；默认使用 `tools/run_gdunit_windows.cmd` 封装这条顺序

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- `GdUnit4` 前置缓存刷新命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --editor --path E:\projects\CentJours --quit
```

- `GdUnit4` 默认命令：

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

- 若新增 GDExt 接口，再补一次 smoke scene：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours res://src/dev/engine_smoke_test_scene.tscn
```

- 视觉、布局和滚动问题以 Windows 真机验收为最终准绳

## 新会话最少必读文件

- [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
- [docs/plans/dev_plan.md](/mnt/e/projects/CentJours/docs/plans/dev_plan.md)
- [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
- [docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md](/mnt/e/projects/CentJours/docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md)
- [docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md](/mnt/e/projects/CentJours/docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md)
- [docs/decisions/ADR-008-historical-events-expansion.md](/mnt/e/projects/CentJours/docs/decisions/ADR-008-historical-events-expansion.md)
- [docs/history/historical_event_review.md](/mnt/e/projects/CentJours/docs/history/historical_event_review.md)

## 接手注意点

- 自动工作流开启时，默认不能停下来；除非 Steam 提审 / 发版收口、用户明确叫停或出现硬阻塞，否则每轮摘要后都必须直接进入下一轮
- 测试三轮计划已经完成，但这只代表测试底座阶段收口；后续必须继续推进当前 `P0`，不能把“三轮已完成”当成停止理由
- 不要默认回退工作区里的现有改动
- 不要把 Linux / WSL Godot 无头测试当成默认步骤
- 若继续做内容线，先按 `ADR-008` 和 `historical_event_review` 的修订意见推进
- 若继续做产品方向判断，先以 `ADR-011` 为准：优先核心循环、历史逻辑与 Steam 首发完整度，不把低优先级扩展层提到主线前面
- 若继续做玩法线，优先把补给压力扩成明确的玩家决策，而不是继续堆纯后台数值
- 自动工作流开启时，每轮提交后都要先在对话里输出一份完整压缩摘要，再继续下一轮；这不是结束语
- 自动工作流开启时，每轮结束前都要回看一次 [docs/rules/agent_session_rules.md](/mnt/e/projects/CentJours/docs/rules/agent_session_rules.md)，并输出覆盖整个上下文窗口的压缩摘要，防止后续压缩卡住
- 自动工作流开启时，除非项目已经达到可进入 Steam 提审 / 发版收口阶段，否则不允许把任何压缩摘要、阶段性汇报或提交结果当作收尾
- 自动工作流开启时，单轮默认要做成“完整功能包”，优先覆盖规则 / UI / 验证 / 文档中的至少三层；若任务过小，先打包相邻子任务再开工
- 自动工作流开启时，必要时可开 `1-2` 个子 agent 加速只读审计或叶子模块实现，但主 agent 仍独占集成文件，并在提交前统一回收全部子 agent
- `tuileries_eve` 现为正式事件 ID；旧 ID 只应出现在迁移代码和兼容性测试里
- 允许直接修改文案，但必须遵守 ADR-008：直接、清楚、可考据，避免 reframing 句式
- 拿破仑第一人称只用于教学、行动建议、阶段复盘、结局前独白等玩家直面文本；`historical_note`、联军情报、议会与外交动态默认保持第三人称或档案体
- 若继续做 UI 线，优先解决玩家可感知问题，再做大文件工程收口
- 若用户明确要求自动循环，再额外启用 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

## 维护约定

- 本文件只保留当前状态、当前优先级、当前验证方式、当前下一步
- 多轮开发历史不要继续回灌到本文件；统一写入 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
- 若默认验证方式变化，更新本文件与 [docs/plans/dev_plan.md](/mnt/e/projects/CentJours/docs/plans/dev_plan.md)
- 若接手模板变化，更新 [docs/rules/agent_session_prompts.md](/mnt/e/projects/CentJours/docs/rules/agent_session_prompts.md)
