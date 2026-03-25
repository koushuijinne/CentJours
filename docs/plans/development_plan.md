# Cent Jours — 开发优先级计划

> **更新**: 2026-03-24 v83
> **通用原则**: [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
> **快速接手**: [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
> **开发历史**: [docs/history/development_logs/development_log_001.md](/mnt/e/projects/CentJours/docs/history/development_logs/development_log_001.md)
> **可选自动工作流**: 仅在用户明确要求时阅读 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前技术基线

- 正式入口为 `src/ui/main_menu.tscn`，主链路 `TurnManager -> CentJoursEngine -> GameState -> UI` 已跑通。
- Rust 规则层最近一次完整回归基线为 Windows `198/198`；自动工作流后续不再把 Linux / WSL `cargo test` 当成默认验证路径。
- 当前数据基线为 `15` 名角色、`41` 个地图节点、`58` 条历史事件，其中 `major 16 / normal 35 / minor 7`。
- 当前活跃开发分支为 `auto/gameplay_update`；`claude/review-project-status-05vxD` 作为稳定参考基线保留。
- Save / Load 已进入 `v3` 兼容阶段，旧存档中的 `fontainebleau_eve` 会在读档时迁移到正式 ID `tuileries_eve`，新增前沿粮秣站状态也会随存档读写。
- 历史事件正文与 `historical_note` 已接入 UI 日志链路，玩家行动结算日志也已通过 GDExt 回传到主菜单侧栏。
- 动态补给已经进入核心循环：补给值会进入存档、`get_state()`、主菜单顶栏、休整恢复、战斗补给惩罚和每日行动结算日志。
- 首个玩家可控补给政策 `requisition_supplies / 征用沿线仓储` 已接入政策表、叙事池、模拟策略和 UI 元数据，补给玩法不再只有被动承压。
- 第二个玩家可控补给政策 `stabilize_supply_lines / 整顿驿站运输` 已接入：它会短期提高补给线效率，并进存档、预判、结算日志和叙事链。
- 第三个玩家可控补给政策 `establish_forward_depot / 建立前沿粮秣站` 已接入：它会在当前驻地留下短期容量加成，直接影响行军预判、行动后补给结算、地图检查器和地图可视化。
- 侧栏政策预览现在会根据当前补给值和前 10 天阶段给出情境化建议，开始把“哪张补给牌该什么时候打”嵌进 UI 教学里。
- 行军预览现在优先读取 Rust 引擎返回的权威预测值，玩家在确认前就能看到预计补给 / 疲劳 / 士气变化，以及仓储容量、补给线效率、预计可得量与需求拆解；只有接口不可用时才退回前端近似提示。
- 每次行动后的补给结算现在会显式写出节点容量、需求 / 可得量与下一步建议，失败归因已经从“看结果”推进到“告诉玩家为何缺补给、该怎么补救”。
- 地图检查器与行军预判现在还会显式展示补给角色、有效容量、最近补给枢纽与跳数；地图渲染也会标出前沿粮秣站、战略枢纽和前线消耗点。
- 引擎状态现在会直接给出“后勤态势”和“当前阶段目标”；侧栏、决策区提示和地图副标题会统一展示这层建议，玩家不再需要自己从多个补给数字里拼当前目标。
- 当前驻地与行军目标现在还会给出“补给窗口”提示：当前节点大约还能维持几天，或是否已经处于战斗惩罚区，前线推进节奏开始变得可读。
- 行军预判现在还会给出“第二跳推进风险”：落点后还剩几条相对稳妥的继续推进路线、哪条后续线路最稳，以及是否已经把自己推进补给陷阱。
- 引擎状态现在还会给出“阶段运营目标”：这一阶段应该优先抢哪类节点、当前是不是在往正确的仓储层级走；侧栏、地图副标题和行军预判都已复用这层目标。
- 引擎状态现在还会给出“当日行动计划”：当前优先动作、备选动作和推荐行军目标；侧栏、`DecisionTray` 提示、地图副标题、行军预判和终局复盘都会复用这层建议。
- 引擎状态现在还会给出“三日后勤节奏”：今天、明天、后天该怎么排动作和节点承接；侧栏、`DecisionTray` 提示、行军预判和终局复盘都会复用这层节奏建议。
- 引擎状态现在还会给出“区域运营链路”：从当前节点到下一跳、再到后续承接点的推荐节点线；侧栏、地图副标题、行军预判和终局复盘都会复用这层线路建议。
- `DecisionTray` 提示现在会在前 10 天主动输出后勤教程链，根据补给窗口和阶段目标告诉玩家何时该先补给、何时该先抢整补节点。
- 终局复盘现在会带上终盘补给、最后位置、后勤态势、阶段运营目标、当日行动计划和补给窗口，失败归因开始从纯政治/军事统计扩展到后勤节奏。
- 三张补给牌的侧栏预览现在会直接给出“优先 / 可考虑 / 暂缓”的即时建议，开始把政策选择和当前后勤态势真正绑在一起。
- 终局复盘现在会把失败归因进一步落到具体补给牌和节奏错误，例如补给牌打晚、没及时保线、没把中继节点铺成跳板。
- 前端已拆出 `map / layout / tray / sidebar / dialogs` 控制器，但主菜单相关文件仍偏大，发布级 polish 尚未完成。
- 默认验证路径只接受 Windows 原生运行、Windows 无头和 Windows 原生 `cargo build --features godot-extension`。
- 当前这条补给玩法切片已经完成 Windows `cargo test`、Windows DLL 重编、Windows 主项目无头启动和 Windows smoke scene；smoke 输出已确认新 `logistics_route_chain_*` 字段进入 Windows 运行时。后续自动工作流不再回退到 Linux / WSL 侧测试补位。

## 当前技术优先级

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|----------|
| **P0** | **把补给系统继续产品化：补给来源、前线压力、玩家可控补给手段、失败解释与教学** | L | `agent_chat_history` 已明确指出后勤是当前最有价值的玩法增深方向；现在已有三张补给政策、Rust 权威预判、补给角色 / 枢纽可视化、后勤态势 / 阶段目标提示、补给窗口提示、第二跳推进风险预判、阶段运营目标、当日行动计划、三日后勤节奏、区域运营链路、风险拆解和行动后补救建议，下一步该补的是更强的区域运营感、前 10 天教学串联和失败归因闭环。 |
| **P0** | **历史事件从 `58` 条扩到 `100+`，并继续做逐条文本 QA** | L | 这是百日长局成立的内容底座；当前事件量仍不足以支撑长局重玩性。 |
| **P0** | **补前 10 天引导、失败归因、结局文本和关键 UI 文案统一** | M | 新玩家当前仍缺完整解释链，失败后归因和目标感还不够清楚。 |
| **P1** | **收口 F5：`DecisionTray` / `Map Inspector` / 中英混排 / 设置入口** | M | 结构性问题已缓解，但仍需要 Windows 真机视角下的最终收口。 |
| **P1** | **固化 Windows 发布链路：`export_presets.cfg`、构建脚本、验证清单** | M | 当前还没有可重复的 Windows 包导出路径，无法进入稳定提审阶段。 |
| **P1** | **资产替换：地图底图、肖像、插图、BGM、SFX、结局画面** | L | 仍有大量占位内容，不足以支撑 Steam 首发观感。 |
| **P2** | **发布前 QA / 平衡 / 性能回归** | M | 长局试玩、存档回归、Windows UI 验收会成为上线前闸门。 |
| **P2** | **工程收口：大文件继续解耦、`unwrap` 清理、构建警告清理** | M | 会影响维护成本，但不应压过用户可感知的内容和发布链路任务。 |

### 默认连续推进顺序

1. 补给玩法继续产品化与可视化
2. 历史事件扩充与文本 QA
3. 教学 / 失败归因 / 结局与 UI 文案统一
4. 前端发布级 polish 与设置页
5. Windows 发布链路与 Steam 提审资料

## 默认验证方式

- 自动工作流开启时，不运行 Linux / WSL 侧测试，包括 Linux `cargo test`、Linux Godot 无头和任何 WSL 侧补位验证
- Rust + GDExt API 改动：直接到 Windows 侧执行 `cargo build --features godot-extension`
- GDScript / 场景 / UI 改动：使用 Windows 原生 Godot 或 Windows 无头验证
- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 视觉、布局、字体和滚动问题以 Windows 真机验收为最终准绳
- 若本轮没有完成对应的 Windows 验证，就明确记录“未验证”，不要用 Linux / WSL 结果补位，也不要把 Linux / WSL 历史结果写成当前轮验证结论
- 只有用户明确要求启用自动循环时，才额外遵循 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

## 当前阻塞与风险

- `内容量仍不足`：事件池虽然扩到 `58` 条，但离 `100+` 仍差 `42` 条。
- `补给玩法还没完全产品化`：当前已经有三层玩家杠杆、补给角色与枢纽可视化，以及后勤态势 / 阶段目标 / 当日行动计划 / 三日后勤节奏 / 区域运营链路 / 补给窗口 / 第二跳风险提示，但长线运营感和区域节奏仍不够完整。
- `补给教学还没收口`：玩家现在能在行军前和行动后看到仓储容量、补给线效率、可得量与需求拆解，也能在侧栏、地图副标题和决策区看到后勤态势 / 阶段目标 / 当日行动计划 / 三日后勤节奏；前 10 天教程链、政策即时建议和终局后勤复盘已经接通，但还缺更完整的失败归因串联。
- `文本 QA 未收口`：已做多轮事件修订，但全量事件还没完成统一史实锚点、信息密度与句式清理。
- `前端发布级 polish 仍未收口`：`DecisionTray` 和 `Map Inspector` 已做结构修复，但仍需持续用 Windows 真机确认。
- `产品化能力缺口`：仍缺设置/选项页、稳定发布导出链路、Steam 商店与宣传资产。
- `Windows 真机验收仍未收口`：这轮已经补齐 Windows DLL 重编、Windows 无头与 smoke scene，但更长时的 Windows 真机 UI / 体验验收还没完成。
- `最终资产仍是占位`：地图底图、角色肖像、卡片插图、BGM、SFX、结局画面都还没完成。

## 当前技术债

- Rust 全局仍有约 `54` 处 `unwrap()` / `expect()` / `panic!()`，集中在 `events/pool.rs` 与 `engine/state.rs`
- `main_menu.gd` 约 `566` 行，`map_controller.gd` 约 `658` 行，控制器仍有进一步收口空间
- `tests/monte_carlo_balance.py` 与 Rust 核心基线已漂移，不应继续作为平衡主依据
- 当前剩余 `cargo test` 提示主要是文件系统不支持 Rust 增量缓存 hard link，属于环境噪音
- 当前存档仍是单槽 `user://cent_jours_save.json`，更适合开发态而非发布态

## 已完成模块清单

| 模块 | 文件 | 测试数 |
|------|------|--------|
| 战斗解算 | `battle/resolver.rs` | 12 |
| 行军系统 | `battle/march.rs` | 14 |
| 政治系统 | `politics/system.rs` | 12 |
| 命令偏差 | `characters/order_deviation.rs` | 7 |
| 将领关系网络 | `characters/network.rs` | 32 |
| 三系统状态机 | `engine/state.rs` | 65 |
| 历史事件池 | `events/pool.rs` + `EventTier` 枚举 | 39 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 |
| 叙事引擎 | `narratives/mod.rs` | 9 |
| GDExtension | `lib.rs` | — |
| Save / Load | `engine/state.rs` + `save_manager.gd` + `main_menu.gd` | — |
| 历史事件展示闭环 | `events/pool.rs` + `engine/state.rs` + `lib.rs` + `turn_manager.gd` + `sidebar_controller.gd` + `main_menu.gd` | 并入上方统计 |

**合计**: `198` tests

## 文档边界

- 本文档只保留当前技术基线、当前优先级、当前验证方式、当前技术债。
- 当前状态与接手约束统一写入 [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)。
- 多轮开发历史统一写入 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)。
- 产品里程碑与对外版本状态统一写入 [docs/plans/product_plan.md](/mnt/e/projects/CentJours/docs/plans/product_plan.md)。
- 自动循环不是默认入口；只有用户明确要求时，才读取 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)。
