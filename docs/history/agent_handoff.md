# Agent 交接

> **更新**: 2026-03-29
> **当前分支**: 以 `git branch --show-current` 为准
> **目标读者**: 新开会话后需要快速接手项目的 agent / 协作者
> **开发历史**: 见 [docs/history/development_logs/](docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时使用 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)
> **当前总目标**: 按 [ADR-011](docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 收口核心玩法，达到 Steam 可上线级别

---

## 当前项目状态

### 核心基线

| 维度 | 状态 |
|------|------|
| 入口 | `src/ui/main_menu.tscn`，主循环 `TurnManager → CentJoursEngine → GameState → UI` 已接通 |
| 数据 | 15 角色 / 41 地图节点 / 58 历史事件 (major 16 / normal 35 / minor 7) |
| 测试 | Windows `cargo test 215/215` + GdUnit4 `68/68` + Windows CI + smoke |
| 存档 | Save v4 兼容路径，旧 `fontainebleau_eve` → `tuileries_eve` 迁移 |
| 分支 | `claude/review-project-status-05vxD`（已合并 `auto/gameplay_update`） |

### 已完成的系统

- **补给系统**: 动态补给进核心循环，4 张补给政策牌（征用/整顿/前沿粮秣站/巩固走廊），行军预判读 Rust 权威值，结算日志含补给解释
- **后勤决策辅助**: 引擎输出后勤态势/阶段目标/当日计划/三日节奏/区域链路/区域压力，UI 侧栏和地图统一展示
- **难度系统**: Rust Difficulty 枚举 (Elba/Borodino/Austerlitz) + GDExtension + 新局 UI 弹窗选择
- **失败归因**: GameState.key_decisions 追踪关键决策，游戏结束弹窗展示决策时间线 + 难度标记
- **音频框架**: AudioManager autoload (BGM 交叉淡入 + SFX 池 + 音量持久化)，缺音频资产
- **设置系统**: 窗口模式 + UI 缩放 + 音频滑条，设置弹窗进 GdUnit4 回归
- **设置锁定语义**: 设置弹窗不再复用“正在结束今天”提示，Tray 锁定原因已拆成 modal / resolving / processing / game_over
- **弹窗恢复链**: 设置 / 百科弹窗即使被外部点击或引擎 hide 关闭，也会回收 modal 锁定，不再留下灰态政策按钮
- **行动面板语义**: Tray 现在会直接说明今天还剩多少机动 / 决策预算，确认按钮按“机动 / 决策”切换，禁用卡片也会显示原因
- **地图交互**: MapScroll + 滚轮缩放 + hover 预览 / click 锁定详情两层，补给角色/枢纽/粮秣站标注
- **前端拆分**: main_menu.gd 1025→684 行，拆出 map / layout / tray / sidebar / dialogs / topbar_actions 6 个子控制器
- **弹窗状态机**: modal 统一锁定 DecisionTray，存读档/设置/战斗/接见/结局弹窗均有 GdUnit4 回归
- **教程链**: 前 10 天后勤教程已改成弹窗 + 侧栏提示双层呈现，日志支持回看
- **弹窗护栏**: 教程弹窗现在有固定宽度与 `GdUnit4` 版式回归，避免长中文正文再次被压成竖排窄列
- **百科入口**: 顶栏百科第一版已能解释红黑指数、合法性、系统影响与提高路径，并有 GdUnit4 断言保护
- **地图清空链**: 点击空白区域或详情背景可可靠清空锁定节点，hover 不会立刻被旧鼠标位置吸回
- **日内行动节奏**: 每天改为 1 次机动槽（行军 / 战役 / 休整）+ 2 次决策点，并由玩家手动结束今天
- **战略目标入口**: 顶栏已提供“结局 / 日志”入口，当前局势与可达成结局可直接弹窗查看
- **多结局系统**: GameOutcome 7 种路径 (NapoleonVictory / DiplomaticSettlement / MilitaryDominance / WaterlooHistorical / WaterlooDefeat / PoliticalCollapse / MilitaryAnnihilation)，外交进度系统 (diplomatic_progress 0-100)，check_outcome() 优先级逻辑，UI OUTCOME_TEXT 7 套文本 + 变体选择

### 验证与 CI

- Windows 是默认验证平台，不用 Linux/WSL 结果补位
- Windows CI 已拆成三层：
  - `windows-fast`：Rust 快速测试 → GDExt build → 核心 `GdUnit4` → headless boot
  - `windows-full`：全量 `cargo test` → GDExt build → 全量 `GdUnit4` → smoke
  - `windows-heavy-nightly`：Monte Carlo 长测 → 大样本属性测试
- `project.godot`、代码路径和相关 workflow 变更会触发对应 Windows 验证链
- `doc-sync.yml` 门禁：代码路径改动必须同步更新 README 或 docs/

## 当前最高优先级

1. `S1-1` 到 `S1-5` 作为同一个真人试玩修复包同步推进，不按单项串行排队
2. 行动经济、弹窗教程/事件、结局目标入口、中文优先收口、地图优先布局都属于当前并行 `P0`，其中设置弹窗语义、地图清空链、教程弹窗版式和真机可读性继续优先
3. 上述修复同时继续维持 Windows CI、Rust 集成/属性测试和 `GdUnit4` 回归

## 当前已知缺口

- `真人试玩核心问题已部分收口`：日内行动、教程弹窗、结局入口、中文 UI 和地图占比已经落第一版；本轮又补了教程弹窗宽度护栏和第二轮地图压缩，但节奏手感、弹窗文案和地图真机观感还要继续 polish
- `内容量仍不足`：事件池距离 `100+` 目标还差 `42` 条
- `补给玩法还不够显式`：底层压力、四张补给政策、后勤态势 / 阶段目标 / 当日行动计划 / 三日节奏 / 区域运营链路 / 区域运营压力已经接通，但仍缺更强的区域运营感和更长期的前线节奏设计
- `补给教学还没收口`：玩家现在已经能看到风险来源、阶段目标、当日行动计划和三日节奏，也能从终局复盘回看建议，但仍缺更系统的失败归因串联
- `文本 QA 未收口`：剩余事件仍需统一史实锚点、信息密度和句式风格
- `前端发布级 polish 未完成`：主菜单主要 bug 已清一轮，但仍需 Windows 真机继续看地图缩放、hover 预览和存读档弹窗的最终体验
- `Windows CI 仍需继续收口`：三层链路已经落地，但还要继续观察 `fast / full / nightly` 的稳定性、取消行为和 runner 占用
- `前端自动回归仍不够宽`：存读档、设置、音频滑条、地图交互边界、战斗/接见失败恢复与成功推进、行军主流程、休整行动、政策冷却、连续两日行动、教程 modal 干扰链、读档后一致性、难度恢复、教程弹窗宽度、设置弹窗锁定语义、地图空白点击清空，以及设置/百科弹窗外部关闭恢复都已纳入 `GdUnit4`，`EventBus` 噪音也已清掉；但更多长链 UI 状态和真机视觉问题还没全覆盖
- `行动面板视觉层级仍可继续加深`：第一版已经补齐预算提示、确认按钮和禁用原因，但更强的视觉分组、图标层级和真机观感还要继续 polish
- `产品化能力仍缺`：最小设置入口已落地，但更完整的选项页、导出配置、Steam 商店素材、教程引导都未完成
- `Windows 真机体验验收仍未收口`：这轮已经补齐 Windows DLL 重编、Windows 无头与 smoke scene，但更长时的真机 UI / 体验验收还没补
- `最终资产仍是占位`：地图底图、肖像、插图、BGM、SFX、结局画面还没替换
- `文档维护纪律需要持续执行`：根 `README.md`、架构文档、接口文档和 bug 索引都已是正式入口；若不同步维护，CI 和人工接手都会立即漂移。
- `命名与注释治理未收口`：旧中文测试函数名和关键路径说明不足的问题仍在渐进治理中。

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

- [docs/rules/development_principles.md](docs/rules/development_principles.md)
- [docs/plans/dev_plan.md](docs/plans/dev_plan.md)
- [docs/history/agent_handoff.md](docs/history/agent_handoff.md)
- [docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md](docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md)
- [docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md](docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md)
- [docs/decisions/ADR-008-historical-events-expansion.md](docs/decisions/ADR-008-historical-events-expansion.md)
- [docs/history/historical_event_review.md](docs/history/historical_event_review.md)

## 接手注意点

- 自动工作流开启时，默认不能停下来；除非 Steam 提审 / 发版收口、用户明确叫停或出现硬阻塞，否则每轮摘要后都必须直接进入下一轮
- 测试三轮计划已经完成，但这只代表测试底座阶段收口；后续必须继续推进当前 `P0`，不能把“三轮已完成”当成停止理由
- 不要默认回退工作区里的现有改动
- 不要把 Linux / WSL Godot 无头测试当成默认步骤
- 若继续做内容线，先按 `ADR-008` 和 `historical_event_review` 的修订意见推进
- 若继续做产品方向判断，先以 `ADR-011` 为准：优先核心循环、历史逻辑与 Steam 首发完整度，不把低优先级扩展层提到主线前面
- 若继续做玩法线，优先把补给压力扩成明确的玩家决策，而不是继续堆纯后台数值
- 若继续按 2026-03-29 真人试玩修复，行动经济、弹窗教程/事件、结局入口、中文收口和地图优先布局要同步推进，不要拆成五个相互等待的串行任务
- 自动工作流开启时，每轮提交后都要先在对话里输出一份完整压缩摘要，再继续下一轮；这不是结束语
- 自动工作流开启时，每轮结束前都要回看一次 [docs/rules/agent_session_rules.md](docs/rules/agent_session_rules.md)，并输出覆盖整个上下文窗口的压缩摘要，防止后续压缩卡住
- 自动工作流开启时，除非项目已经达到可进入 Steam 提审 / 发版收口阶段，否则不允许把任何压缩摘要、阶段性汇报或提交结果当作收尾
- 自动工作流开启时，单轮默认要做成“完整功能包”，优先覆盖规则 / UI / 验证 / 文档中的至少三层；若任务过小，先打包相邻子任务再开工
- 自动工作流开启时，必要时可开 `1-2` 个子 agent 加速只读审计或叶子模块实现，但主 agent 仍独占集成文件，并在提交前统一回收全部子 agent
- `tuileries_eve` 现为正式事件 ID；旧 ID 只应出现在迁移代码和兼容性测试里
- 允许直接修改文案，但必须遵守 ADR-008：直接、清楚、可考据，避免 reframing 句式
- 拿破仑第一人称只用于教学、行动建议、阶段复盘、结局前独白等玩家直面文本；`historical_note`、联军情报、议会与外交动态默认保持第三人称或档案体
- 若继续做 UI 线，优先解决玩家可感知问题，再做大文件工程收口
- 若用户明确要求自动循环，再额外启用 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)

## 维护约定

- 本文件只保留当前状态、当前优先级、当前验证方式、当前下一步
- 多轮开发历史不要继续回灌到本文件；统一写入 [docs/history/development_logs/](docs/history/development_logs/)
- 若默认验证方式变化，更新本文件与 [docs/plans/dev_plan.md](docs/plans/dev_plan.md)
- 若接手模板变化，更新 [docs/rules/agent_session_prompts.md](docs/rules/agent_session_prompts.md)
