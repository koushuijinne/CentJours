# Cent Jours — 开发优先级计划

> **更新**: 2026-03-19 v15
> **当前分支**: `claude/review-project-plan-LKKTR`

---

## 开发原则

### 一、核心原则（项目级）

> **TDD（测试驱动开发）**
>
> 所有 Rust 模块遵循严格 TDD 流程：
> 1. **Red** — 先写失败的单元测试，明确输入/输出契约
> 2. **Green** — 写最少实现代码使测试通过
> 3. **Refactor** — 在测试保护下重构，不破坏已有行为
>
> - 禁止在没有对应测试的情况下提交业务逻辑
> - `cargo test` 全通过才能提交

> **GDScript 薄层原则（SoC — 关注点分离）**
>
> GDScript 层不包含任何业务逻辑，只负责：
> - 调用 `CentJoursEngine` GDExtension 节点执行行动
> - 读取引擎状态并发射 `EventBus` 信号驱动 UI
> - 提供 UI 展示所需的静态元数据（政策名称、描述等）
>
> 判断标准：如果一段 GDScript 在没有 Godot UI 时仍然"有意义"，它就不应该在 GDScript 里。

> **单一状态源（Single Source of Truth）**
>
> `GameState` 单例中的所有运行时数值，必须从 `CentJoursEngine.get_state()` 同步，
> 不自行维护平行计算逻辑。`GameState` 是 UI 的只读缓存，不是第二个游戏引擎。

> **DRY（Don't Repeat Yourself）**
>
> 同一块逻辑只在一处定义：
> - 战斗解算逻辑 → 仅在 `BattleEngine`（Rust）
> - 政治计算逻辑 → 仅在 `PoliticsSystem`（Rust）
> - 常量定义 → 仅在 Rust 层或 GDScript 展示层，绝不两处都写
>
> 判断标准：修改一条规则是否需要同时改两个文件？如是，则违反 DRY。

> **YAGNI（You Aren't Gonna Need It）**
>
> 不实现当前不需要的功能；不为假设中的未来需求做抽象：
> - M5 之前不做多余 UI 抽象层
> - 不提前泛化只使用一次的逻辑
> - 删除比保留更好，需要时再加回来

> **KISS（Keep It Simple）**
>
> 最简方案优先；三行相似代码优于一个过早的抽象：
> - 信号发射只做一次，不重复发射
> - 数据流方向单一（引擎 → GameState → UI），不反向写入
> - 判断分支优先用 `match`，避免嵌套 `if`

### 二、契约与文档原则

> **边界契约注释（轻量契约式编程）**
>
> Rust ↔ GDScript 之间传递 `Dictionary` 时，键名是字符串，无编译期保证。
> 每个 GDExtension 函数必须在调用侧注释明确契约：
>
> ```gdscript
> # engine.get_state() 返回键（来自 lib.rs get_state）:
> # day(int) legitimacy(float) rouge_noir(float)
> # troops(int) morale(float) fatigue(float) victories(int)
> # is_over(bool) outcome(String) factions(Dictionary)
> ```
>
> 判断标准：新开发者仅凭 GDScript 文件能否知道 Dictionary 中有哪些键？

> **ADR（架构决策记录）**
>
> 每个重大技术选型（非显而易见的）记录于 `docs/decisions/ADR-NNN.md`：
> - 背景、决策、后果三段式，50 行以内
> - 已决策事项不在每次 PR 中重新讨论
>
> 待补充的决策：
> - ADR-001: 为何选 Rust + GDExtension 而非纯 GDScript
> - ADR-002: GameState 为只读缓存而非双向状态

> **活文档（Living Documentation）**
>
> - 完成任务后立即更新本文档状态（✅/🔶）和进度快照
> - 原则：文档反映当前真实状态，而非计划状态
> - **已完成的轮次内容定期清除**，只保留当前优先级和模块清单

### 三、提交与流程原则

> **完成任务后的强制清单（每次不可跳过）**
>
> 完成任何代码任务后，**在提交前**必须完成：
> 1. 将已完成项标记 ✅ 并移入模块清单
> 2. 更新进度快照（进度条 + 描述）
> 3. 重新扫描代码库，找新的技术债
> 4. 重排下一轮优先级（Priority A = 现在就能做的最高价值任务）
> 5. **dev_plan.md 更新与代码变更放同一次 commit**
>
> 判断标准：dev_plan.md 超过一个工作轮次没有更新，说明流程出了问题。
> 详细规则见根目录 `CLAUDE.md`。

> **小步提交推送**
>
> 每完成一个独立小功能立即 commit + push：
> - 格式：`feat(模块): 描述` / `fix(模块): 描述` / `data: 描述`
> - 永远不要积累"大提交"

---

## 当前进度快照（2026-03-19）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ██████████░░  85% 🔶 Rust层✅，EventPool集成✅，Godot待安装
M2  政治系统   ███████████░  90% 🔶 Rust层✅，平衡达标，UI待Godot
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████████ 100% ✅ GDScript桥接层✅，叙事全覆盖✅，存档系统✅，GDScript全合规✅，loyalty闭环✅
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**103/103 单元测试全部通过**（最后运行：2026-03-19）

**平衡结果**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅

**约束**: 暂无 Godot 运行环境。Rust/GDScript 均可开发，.tscn 场景无法运行测试。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 7 | ✅ |
| 行军系统 | `battle/march.rs` | 6 | ✅ |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 23 | ✅ |
| 三系统状态机 | `engine/state.rs` | 16 | ✅ |
| 历史事件池 | `events/pool.rs` | 13 | ✅ 30条×5叙事 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 | ✅ |
| 叙事引擎 | `narratives/mod.rs` | 8 | ✅ 11类stendhal + 12类consequence |
| GDExtension节点 | `lib.rs` | — | ✅ 4节点（Battle/Politics/Character/Game） |
| Save/Load序列化 | `engine/state.rs` | — | ✅ to_json/from_json |
| GDScript桥接层 | `turn_manager.gd` | — | ✅ v2 接入CentJoursEngine |
| 政治UI层 | `political_system.gd` | — | ✅ v2 精简展示层 |
| 命令偏差代理 | `order_deviation.gd` | — | ✅ v2 CharacterManager代理 |
| 将领查询层 | `character_manager.gd` | — | ✅ v2 精简，移除冗余逻辑 |
| 地图路径查询 | `march_system.gd` | — | ✅ v2 精简，仅保留路径/距离 |
| 存档系统 | `save_manager.gd` + `lib.rs` | — | ✅ to_json/load_from_json 完整闭环 |
| 战斗展示元数据 | `battle_resolver.gd` | — | ✅ v2 精简为展示常量（138行→35行，DRY修复） |
| GameState 合规清理 | `game_state.gd` | — | ✅ v2 stub 违规方法，Bug修复（信号双发） |
| 忠诚度引擎暴露 | `lib.rs` | — | ✅ 新增 `get_all_loyalties()` |
| 忠诚度同步 | `turn_manager.gd` | — | ✅ `_sync_state_from_engine()` loyalty 闭环 |
| 架构决策记录 | `docs/decisions/` | — | ✅ ADR-001（Rust+GDExtension）、ADR-002（只读缓存） |

**合计**: 103 tests 全部通过

---

## GATE 2：✅ 通过

| 检查项 | 证据 |
|--------|------|
| 三系统耦合状态机 | `engine::state` 16 tests |
| 蒙特卡洛平衡验证 | Military 24.2% / Political 21.2% / Balanced 22.4%，均在 15%-35% |
| 30条历史事件集成 | 触发率验证通过 |
| Godot 4.6 升级 | gdext 0.4.5, api-4-5, VarDictionary |

---

## ✅ 优先级 A — 本轮已全部完成（2026-03-19）

| # | 文件 | 违反原则 | 处理结果 |
|---|------|---------|---------|
| ① | `game_state.gd` | 单一状态源 + KISS（信号双发 Bug） | ✅ Bug 修复，4 个违规方法已 stub |
| ② | `battle_resolver.gd` | DRY + GDScript 薄层（138 行解算逻辑重复） | ✅ 精简为 35 行展示常量 |
| ③ | `lib.rs` | 单一状态源（忠诚度未暴露给 GDScript） | ✅ 新增 `get_all_loyalties()` |
| ④ | `turn_manager.gd` | 单一状态源（loyalty 不从引擎同步） | ✅ `_sync_state_from_engine()` 新增忠诚度同步块 |
| ⑤ | `docs/decisions/` | ADR 缺失（架构决策无记录） | ✅ 新建 ADR-001、ADR-002 |

**103/103 单元测试全部通过**（cargo test 验证，2026-03-19）

**GDScript 层现已完全合规**：
- `GameState` → 只读缓存，无任何平行计算逻辑
- `BattleResolver` → 纯展示常量，无业务逻辑
- `TurnManager` → 单一同步入口，loyalty 闭环完成

---

## 优先级 B — 需要 Godot 环境

| 任务 | 阻塞原因 |
|------|---------|
| UI 场景文件（.tscn） | 需要 Godot 编辑器 |
| CentJoursEngine 节点挂载到场景树 | 需要 Godot 编辑器 |
| GDExtension 集成测试 | 需要 Godot 运行环境 |
| `decision_card.gd` 完整布局 | 需要可见 UI 布局确认 |
| `rn_slider.gd` 信号化轮询（`_process` → 订阅信号） | 需要 Godot 运行确认 |
| M5 美术资源 | 需要 Godot + 美术工具 |

---

## GATE 3 前置条件（等待 Godot 环境）

| 检查项 | 状态 |
|--------|------|
| GDScript 层完全合规（无业务逻辑、无平行计算） | ✅ 完成 |
| GameState loyalty 与引擎闭环同步 | ✅ 完成 |
| 103 单元测试全部通过 | ✅ 完成 |
| GDExtension 集成测试（Godot 运行） | ⏳ 等待 Godot 环境 |
| 完整回合流程端到端测试 | ⏳ 等待 Godot 环境 |

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
