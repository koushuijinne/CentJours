# Codex Handoff

> **更新**: 2026-03-23
> **当前分支**: 以 `git branch --show-current` 为准（不再在 handoff 中硬编码）
> **目标读者**: 新开会话后需要快速接手项目的 Codex / 协作者
> **自动推进**: 见 `docs/codex_autonomous_workflow.md`

---

## 1. 当前项目状态

- Rust 规则层与 Godot 前端已完成基础联调，主循环可跑通，正式入口是 `src/ui/main_menu.tscn`
- 2026-03-23 复核 `cargo test` 为 **156/156 全通过**
- 当前核心数据基线：`15` 名角色、`41` 个地图节点、`49` 条历史事件（major 15 / normal 29 / minor 5）
- 行军、战斗、政治、命令偏差、联军动态化、叙事池、单槽存档/读档均已接入
- 玩家行动结算日志已可见：政策 / 战役 / 行军 / 强化忠诚会显示结构化影响摘要，日志通过 `last_action_events -> GDExt -> TurnManager/EventBus -> MainMenu` 进入侧栏；角色短名已统一来自 `characters.json.display_name`
- 前端已拆出 `map / layout / tray / sidebar / dialogs` 控制器，但发布级 polish 尚未完成
- Windows Godot 运行与 Windows 无头测试仍是默认验证路径；**不要切到 Linux / WSL 无头测试作为默认方案**
- 当前尚未达到 Steam 发布就绪：内容量、文案 QA、UI 收口、设置/导出/商店链路、最终资产都还缺

## 2. 当前最高优先级

1. 历史事件从 `49` 条扩充到 `100+`，并按 `docs/advice/claude_event_history.md` 修正文风与史实问题
2. 补前 10 天引导、失败归因与结局文本，让新玩家信息解释真正完整成立
3. 收口 F5：托盘双滚动、中英混排、`Map Inspector` 紧凑、设置入口与前 10 天引导
4. 固化 Windows 发布链路与 Steam 提审资料清单

## 3. 已完成的关键改动

- 主场景已脱离 smoke test 入口，`src/ui/main_menu.tscn` 是正式入口
- `TurnManager` 已通过 `CentJoursEngine` 驱动 Dawn / Action / Dusk，全局状态由 Rust 引擎权威维护
- `PlayerAction::March`、`process_day_march()`、`get_adjacent_nodes()`、地图高亮与确认流程均已接上
- 事件 tier 架构已完成，`historical.json` 已带 `tier` 字段并与 Rust `EventPool` 对齐
- `coalition_troops_bonus`、`paris_security_bonus`、`political_stability_bonus` 已真实进入状态机
- 叙事引擎已接入 `GameEngine`，政策 / 战役 / 强化忠诚可产生 `DayReport`
- `historical_note` 已接入 Rust → GDExt → TurnManager → Sidebar/叙事日志链路，历史事件会在当回合结算后即时显示正文与史注
- 已对 8 条重点历史事件做首轮文案 QA，修正了部分史实硬伤、解释不足和过度文学化问题
- 累计已新增 18 条中盘 / 联军 / 小人物 / 指挥事件，补齐 Day 20-84 的多处节奏空白；本轮再补 `soult_chief_of_staff`、`carnot_returns_government`、`lavalette_postal_network`、`drouet_march_confusion`，事件池扩至 49 条
- `events::pool` 已有事件数量、ID 唯一性、`historical_note` 非空、tier 对应叙事段数、禁止无效负 bonus 等回归测试，防止后续扩容时静默退化
- 结局弹窗已开始消费 `OUTCOME_TEXT` 里的 `epilogue / review_hint`，并按终局统计生成复盘说明；行动后果微叙事也已改为中文类别标签
- `GameEngine` 已缓存最近一次玩家行动的 `DayEvent`，`CentJoursEngine.get_last_action_events()` 已暴露到 Godot；政策 / 战役 / 行军 / 强化忠诚结算都会输出可读描述和结构化 effects
- `characters.json` 已补 `display_name` 字段，GDScript 角色列表与 Rust 行动结算日志都改为优先使用中文短称
- 叙事面板的“预览/日志”冲突已缓解：选择下一张卡不会再清空既有历史日志，结构化行动结算会写入侧栏滚动日志
- `map_controller.gd` 已改为运行时 `load(...).new()` 加载地图渲染脚本，Windows Godot 无头验证恢复可通过
- `src/dev/engine_smoke_test_scene.tscn` 现可直接验证 `process_day_policy()` / `process_day_boost_loyalty()` / `process_day_battle()` 与 `get_last_action_events()` 的 GDExt 调用链
- Save / Load 已接入主菜单顶栏，但仍是开发态单槽存档
- 主菜单已完成多轮解耦，职责已拆到 `map / layout / tray / sidebar / dialogs` 五类 controller

## 4. 当前已知问题与缺口

- `Decision Tray` 仍有双滚动问题
- 主菜单仍有中英混排，文本语言策略未统一
- `Map Inspector` 长文本在部分节点上仍偏紧
- `main_menu.gd` 仍有 `549` 行，`map_controller.gd` 已到 `658` 行，控制器拆分还没完全收口
- `docs/advice/claude_event_history.md` 指出的史实与文风问题只完成了首批 8 条旧事件修订；累计 18 条新增事件虽已按新标准入库，但全量 49 条仍待统一审校
- 行动结算与角色短名已统一，但主菜单其余 UI 仍有中英法混排，离最终文本统一还有距离
- 仓库内仍缺 `export_presets.cfg`、Windows 发布脚本、Steam 提审与商店素材清单
- 资产层仍处于占位阶段：地图底图、肖像、卡片插图、BGM、SFX、结局画面均未完成

## 5. 下一步推荐任务

1. 先做内容闭环：扩写事件、继续修文案、补政策/结局文本
2. 再做新玩家闭环：前 10 天引导、失败归因、文案统一、设置入口
3. 然后做发布闭环：Windows 导出链路、Steam 提审资料、资产替换
4. 工程收口任务（大文件解耦、`unwrap` 清理、构建警告清理）穿插进行，但不要压过用户可感知问题

## 6. 当前结构与写入边界

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

## 7. 验证要求

### 默认验证方式

- Rust 改动：`cd cent-jours-core && cargo test`
- Rust + GDExt API 改动：Windows 侧先执行

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 若本轮改动涉及新增 GDExt 接口，补跑一次 smoke scene（当前覆盖 policy / boost / battle 三条路径）：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours res://src/dev/engine_smoke_test_scene.tscn
```

### 当前验证优先级

- 前端视觉问题以 Windows 真机截图为最终准绳
- 无头测试主要用于脚本解析、资源装载、扩展初始化兜底
- **不要默认跑 Linux / WSL 无头测试**

## 8. 新会话最少必读文件

- `docs/development_principles.md`
- `docs/dev_plan.md`
- `docs/codex_handoff.md`
- `docs/codex_autonomous_workflow.md`
- `docs/decisions/ADR-008-historical-events-expansion.md`
- `docs/advice/claude_event_history.md`

## 9. 新会话接手时的注意点

- 不要默认回退工作区里的现有改动
- 不要把 Linux / WSL 无头测试当成默认步骤
- 若继续做内容线，先按 `ADR-008` 的 Checklist 和 `claude_event_history` 的修订意见落地
- 本轮已修掉 `napoleon_leaves_paris_north` 中不会生效的负 `paris_security_bonus / political_stability_bonus`；后续新增事件不要再用这类负 bonus 表达减益
- 若继续做 UI 线，优先解决玩家可感知问题，再做大文件工程收口
- 若被 Windows 验证卡住，先记录到 handoff，再切到不依赖该验证的下一条高价值任务继续推进

## 10. 维护约定

- 每完成一轮开发后，默认同步更新本文件
- 若默认验证方式、自动推进规则或接手入口变化，同步更新 `docs/codex_autonomous_workflow.md`
- 若当前优先级发生变化，同步更新 `docs/dev_plan.md`
