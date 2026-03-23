# Cent Jours — 开发优先级计划

> **更新**: 2026-03-23 v56
> **通用原则**: 项目长期稳定原则详见 `docs/development_principles.md`
> **快速接手**: 当前状态见 `docs/codex_handoff.md`
> **自动推进**: 全自动开发循环见 `docs/codex_autonomous_workflow.md`

---

## 当前状态摘要

- 主循环已打通：Godot `main_menu.tscn` 是正式入口，`TurnManager -> CentJoursEngine -> GameState -> UI` 链路可跑。
- Rust 规则层在 2026-03-23 复核通过 `156/156` 测试；当前数据基线为 `15` 名角色、`41` 个地图节点、`49` 条分级历史事件。
- 行军、战斗、政治、命令偏差、联军动态化、叙事池、单槽存档/读档都已接入，不再是纯原型骨架。
- `historical_note` 已从 Rust 事件池接入 UI 滚动日志，历史事件会在当回合结算后即时显示正文与史注。
- 事件池累计已补入 `18` 条中盘 / 联军 / 小人物 / 指挥事件，覆盖维也纳同盟条约、托伦蒂诺败报、五月原野大典、沙勒罗瓦突破、苏尔特接任参谋长、德尔隆第一军迷失等节奏空白段，并新增事件 JSON 质量护栏测试。
- 结局弹窗现已实际显示 `OUTCOME_TEXT` 中的 `epilogue / review_hint`，行动后果微叙事也已改为中文类别标签，不再直接暴露裸 `action_type` key。
- 行动结算日志链已打通：`GameEngine.last_action_events -> GDExt get_last_action_events() -> TurnManager/EventBus -> MainMenu`，政策 / 战役 / 行军 / 强化忠诚结果都已有结构化摘要；角色显示名也已回收到 `characters.json.display_name`，行动日志与主菜单角色列表统一改用中文短称。
- 前端已经拆出 `map / layout / tray / sidebar / dialogs` 控制器，但主菜单相关文件仍然偏大，UI 收口还没完成。
- 当前离 Steam 发布仍有明显缺口：内容量不足、事件文案 QA 未收口、前端发布级 polish 不足、Windows 发布链路未成型、商店与资产交付尚未建立。

## 开发原则

> 项目级完整原则以 `docs/development_principles.md` 为准。本文只保留当前轮次直接相关的默认原则。

- `核心循环优先`：新功能优先服务 Dawn / Action / Dusk 主循环
- `TDD`：Rust 规则层改动默认先补测试
- `单一状态源`：引擎是真实状态，`GameState` 只做 UI 只读缓存
- `GDScript 薄层`：Godot 脚本负责桥接、展示、信号，不复制核心规则
- `数据驱动设计`：角色、事件、地图、平衡参数优先外置
- `先骨架后润色`：优先完成信息架构与交互流向，再做视觉打磨
- `组件复用优先`：优先复用 `rn_slider.gd`、`decision_card.gd`、主题系统
- `视觉以真机收口`：Windows Godot `1280x720` 是前端布局的默认收口标准
- `零阻塞默认`：除硬阻塞外不暂停，完成一轮后自动扫描并重排下一轮最高价值任务

### 文档与提交流程

- `活文档`：完成任务后立即更新本文档状态（`✅/🔶`）和进度快照
- `交接同步`：完成一轮后同步更新 `docs/codex_handoff.md`
- `自动开发文档`：若默认验证方式、阻塞处理或自动决策规则变化，同步更新 `docs/codex_autonomous_workflow.md`
- `同提交同步`：文档更新与代码变更放在同一次 commit
- `小步提交`：每完成一个独立功能立即 commit + push
- `ADR`：跨层接口、状态流、重要架构选型沉淀到 `docs/decisions/ADR-XXX.md`
- `边界契约`：Rust ↔ GDScript 的 `Dictionary` / `Array` 返回结构要写清键名和语义
  `get_last_action_events()` 当前返回 `day / event_type / description / effects`，且只表示“最近一次玩家行动”的缓存，不包含 Dawn 历史事件

### 默认验证方式

- Rust 改动：`cd cent-jours-core && cargo test`
- Rust + GDExt API 改动：先跑本地 Rust 测试，再到 Windows 侧执行 `cargo build --features godot-extension`
- GDScript / 场景 / UI 改动：只用 Windows 原生 Godot 真机或 Windows 无头验证，不以 Linux / WSL 无头替代
- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 前端视觉、布局和字体收口以 Windows 真机截图 / 肉眼为最终准绳

---

## 进度快照

### Rust/架构层

```text
M0-M4  ████████████ 100% ✅  基础规则、事件、叙事、存档最小闭环已完成
M5  资产收口   ░░░░░░░░░░░░   0%
M6  发布收口   ░░░░░░░░░░░░   0%
```

**156 单元测试全部通过** | **事件池**: 49 条（major 15 / normal 29 / minor 5）

### 前端层

```text
F0-F4  ████████████ 95-100% ✅  主场景、地图、托盘、侧栏、弹窗已联调
F5     ████████░░░░ 55% 🔶      视觉统一、文本统一、发布级 polish 未收口
```

---

## 当前阻塞点

- `内容量仍不足`：历史事件已增至 `49` 条，但距离 `ADR-008` 的 `100+` 目标仍差 `51` 条，百日长局的重玩性还不够。
- `文本 QA 未收口`：首批 `8` 条旧事件修订和累计 `18` 条新增事件已落地，但全量 `49` 条仍未逐条统一史实、句式和注释风格。
- `结局/全局文案仍未完全收口`：角色短名与行动结算已统一，但主菜单其余 UI 仍有中英法混排，结局文本也仍缺更丰富的变体层次。
- `前端发布级 polish 不足`：托盘双滚动、中英混排、`Map Inspector` 紧凑、弹窗与信息层级仍需收口。
- `产品化能力缺口`：仍缺设置/选项页、发布导出配置、商店与宣传资产、教程/前 10 天引导。
- `发布链路缺失`：仓库里还没有 `export_presets.cfg`、Windows 发布脚本、Steam 提审清单等上线所需资产。

## 技术债

- Rust 全局 `54` 处 `unwrap()` / `expect()` / `panic!()`，集中在 `events/pool.rs` 与 `engine/state.rs`
- `main_menu.gd` `549` 行，`map_controller.gd` `658` 行，控制器拆分后仍有继续收口空间
- `tests/monte_carlo_balance.py` 已与 Rust 核心基线漂移，不应再作为平衡主依据
- `cargo test` 虽通过，但仍有测试命名和未使用函数警告，发布前应收敛构建噪音
- 当前存档仍是单槽 `user://cent_jours_save.json`，更适合开发态而非发布态

---

## 已完成模块清单

| 模块 | 文件 | 测试数 |
|------|------|--------|
| 战斗解算 | `battle/resolver.rs` | 12 |
| 行军系统 | `battle/march.rs` | 10 |
| 政治系统 | `politics/system.rs` | 9 |
| 命令偏差 | `characters/order_deviation.rs` | 7 |
| 将领关系网络 | `characters/network.rs` | 30 |
| 三系统状态机 | `engine/state.rs` | 41 |
| 历史事件池 | `events/pool.rs` + `EventTier` 枚举 | 29 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 |
| 叙事引擎 | `narratives/mod.rs` | 9 |
| GDExtension | `lib.rs` | — |
| Save/Load | `engine/state.rs` + `save_manager.gd` + `main_menu.gd` | — |
| 历史事件展示闭环 | `events/pool.rs` + `engine/state.rs` + `lib.rs` + `turn_manager.gd` + `sidebar_controller.gd` + `main_menu.gd` | 2 |

**合计**: 156 tests

---

## Steam 上线前优先级

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|---------|
| **P0** | **历史事件扩充 49 → 100+，并完成文本 QA** | L | 这是百日长局成立的前提；没有足够事件量和文风/史实校正，Steam 首发会直接暴露内容重复与可信度问题。 |
| **P0** | **补齐行动后果文本与结局文本** | M | 历史事件、政策结算与终局尾声都已接通，但战役/行军/失败归因仍需继续文本化，结局层次也还不够丰富。 |
| **P0** | **前 10 天引导 + 失败归因 + UI 文案统一** | M | 当前系统复杂度已经够高，没有嵌入式教学和统一文案会显著抬高 Steam 新玩家流失率。 |
| **P1** | **F5 视觉与布局收口** | M | 托盘双滚动、混合语言、`Map Inspector` 紧凑和弹窗层级问题是最直接的第一印象缺陷，应在可玩闭环之后优先修复。 |
| **P1** | **基础产品化能力：设置/选项、存档 UX、错误提示** | M | 目前更像开发态主场景；Steam 首发至少需要窗口/显示/音量类设置入口和更稳健的存档交互。 |
| **P1** | **Windows 发布链路成型：`export_presets.cfg`、构建脚本、验证清单** | M | 仓库尚无可重复的发布导出路径，必须先把“如何稳定产出 Windows 包”固化下来，才能谈提审。 |
| **P1** | **资产替换：地图底图、肖像、卡片插图、BGM、SFX、结局画面** | L | 当前仍大量依赖占位内容；不上资产就无法达到 `plan.md` 定义的 Steam 商业化呈现标准。 |
| **P1** | **Steam 商店与提审资料：胶囊图、截图、描述、trailer、提审清单** | L | 即使游戏本体可玩，没有商店素材与提审流程文件，也无法进入 wishlist 与发售节奏。 |
| **P2** | **发布前 QA / 平衡 / 性能回归** | M | 包含长局试玩、Windows 真机 UI 回归、存档回归、蒙特卡洛复核；这是上线前的稳定性闸门。 |
| **P2** | **工程收口：大文件继续解耦、`unwrap` 清理、构建警告清理** | M | 这些问题会放大发布期返工成本，但不应压过用户可感知的内容与发布链路任务。 |
| **P3** | **Steam 增值项：成就、多语言、多存档槽** | M | 有价值，但相比“先稳定上线”不是首发阻塞项，除非市场策略明确要求。 |

### 默认连续推进顺序

1. 历史事件扩充与文本 QA
2. 教学/失败归因/文案统一
3. 前端发布级 polish 与设置页
4. Windows 发布链路与 Steam 资料
5. 资产替换与发布前 QA

### 不在首发阻塞范围

- 移动端移植
- DLC/额外战役
- 高级 Steam 集成（云存档、排行榜等）
- 主机/手柄专项适配
