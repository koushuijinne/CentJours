# Cent Jours — 开发优先级计划

> **更新**: 2026-03-24 v67
> **通用原则**: [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
> **快速接手**: [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
> **开发历史**: [docs/history/development_logs/development_log_001.md](/mnt/e/projects/CentJours/docs/history/development_logs/development_log_001.md)
> **可选自动工作流**: 仅在用户明确要求时阅读 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前技术基线

- 正式入口为 `src/ui/main_menu.tscn`，主链路 `TurnManager -> CentJoursEngine -> GameState -> UI` 已跑通。
- Rust 规则层当前基线为 `172/172` 测试通过。
- 当前数据基线为 `15` 名角色、`41` 个地图节点、`58` 条历史事件，其中 `major 16 / normal 35 / minor 7`。
- 当前活跃开发分支为 `auto/gameplay_update`；`claude/review-project-status-05vxD` 作为稳定参考基线保留。
- Save / Load 已进入 `v2` 兼容阶段，旧存档中的 `fontainebleau_eve` 会在读档时迁移到正式 ID `tuileries_eve`。
- 历史事件正文与 `historical_note` 已接入 UI 日志链路，玩家行动结算日志也已通过 GDExt 回传到主菜单侧栏。
- 动态补给已经进入核心循环：补给值会进入存档、`get_state()`、主菜单顶栏、休整恢复、战斗补给惩罚和每日行动结算日志。
- 前端已拆出 `map / layout / tray / sidebar / dialogs` 控制器，但主菜单相关文件仍偏大，发布级 polish 尚未完成。
- 默认 Godot 验证路径仍是 Windows 原生运行和 Windows 无头，不以 Linux / WSL Godot 无头替代。
- 当前 WSL 环境未安装 `x86_64-pc-windows-gnu` target；从这里执行 `cargo build --features godot-extension` 只会更新 Linux `.so`，不能替代 Windows `cent_jours_core.dll` 验证。

## 当前技术优先级

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|----------|
| **P0** | **把补给系统继续产品化：补给来源、前线压力、玩家可控补给手段与失败反馈** | L | `agent_chat_history` 已明确指出后勤是当前最有价值的玩法增深方向；本轮只完成了底层闭环，下一步必须让玩家真正“围绕补给做决策”。 |
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

- Rust 改动：`cd cent-jours-core && cargo test`
- Rust + GDExt API 改动：先跑 Rust 测试，再到 Windows 侧执行 `cargo build --features godot-extension`
- GDScript / 场景 / UI 改动：使用 Windows 原生 Godot 或 Windows 无头验证
- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 视觉、布局、字体和滚动问题以 Windows 真机验收为最终准绳
- 只有用户明确要求启用自动循环时，才额外遵循 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

## 当前阻塞与风险

- `内容量仍不足`：事件池虽然扩到 `58` 条，但离 `100+` 仍差 `42` 条。
- `补给玩法还没完全产品化`：当前已经有补给压力，但玩家可控杠杆还不够多，仍需把它扩成清晰的策略层。
- `文本 QA 未收口`：已做多轮事件修订，但全量事件还没完成统一史实锚点、信息密度与句式清理。
- `前端发布级 polish 仍未收口`：`DecisionTray` 和 `Map Inspector` 已做结构修复，但仍需持续用 Windows 真机确认。
- `产品化能力缺口`：仍缺设置/选项页、稳定发布导出链路、Steam 商店与宣传资产。
- `Windows DLL 验证链有缺口`：当前环境能跑 Windows Godot 无头，但没有重新产出新的 `cent_jours_core.dll`，所以本轮 Windows smoke 不能当作新 GDExt 行为已验证。
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
| 行军系统 | `battle/march.rs` | 12 |
| 政治系统 | `politics/system.rs` | 9 |
| 命令偏差 | `characters/order_deviation.rs` | 7 |
| 将领关系网络 | `characters/network.rs` | 32 |
| 三系统状态机 | `engine/state.rs` | 44 |
| 历史事件池 | `events/pool.rs` + `EventTier` 枚举 | 39 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 |
| 叙事引擎 | `narratives/mod.rs` | 9 |
| GDExtension | `lib.rs` | — |
| Save / Load | `engine/state.rs` + `save_manager.gd` + `main_menu.gd` | — |
| 历史事件展示闭环 | `events/pool.rs` + `engine/state.rs` + `lib.rs` + `turn_manager.gd` + `sidebar_controller.gd` + `main_menu.gd` | 并入上方统计 |

**合计**: `172` tests

## 文档边界

- 本文档只保留当前技术基线、当前优先级、当前验证方式、当前技术债。
- 当前状态与接手约束统一写入 [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)。
- 多轮开发历史统一写入 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)。
- 产品里程碑与对外版本状态统一写入 [docs/plans/product_plan.md](/mnt/e/projects/CentJours/docs/plans/product_plan.md)。
- 自动循环不是默认入口；只有用户明确要求时，才读取 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)。
