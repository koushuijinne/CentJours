# Cent Jours — 开发优先级计划

> **更新**: 2026-03-21 v23
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

## 当前进度快照（2026-03-21）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ███████████░  90% 🔶 Rust层✅，Godot打开✅，CentJoursEngine smoke test✅
M2  政治系统   ███████████░  90% 🔶 Rust层✅，平衡达标，Godot联调起点✅
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████████ 100% ✅ 历史事件33条，TDD契约全覆盖，测试127个
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**127/127 单元测试全部通过 + Godot smoke test 已通过**（最后运行：2026-03-21）

**平衡结果**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅

**约束**: Godot 编辑器已可运行；WSL 音频仍回落 dummy driver，但不阻塞脚本解析和 GDExtension 联调。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 12 | ✅ +5边界值（零兵力/零士气/复合惩罚/ratio阈值） |
| 行军系统 | `battle/march.rs` | 10 | ✅ +4直接测试rest_army()（高低补给/边界/公式验证） |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 23 | ✅ |
| 三系统状态机 | `engine/state.rs` | 16 | ✅ |
| 历史事件池 | `events/pool.rs` | 16 | ✅ 33条×5叙事（+3 Day10-19补白） |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 | ✅ |
| 叙事引擎 | `narratives/mod.rs` | 10 | ✅ +2契约验证（policy_id→JSON键名全量覆盖） |
| GDExtension节点 | `lib.rs` | — | ✅ 4节点（Battle/Politics/Character/Game） |
| Save/Load序列化 | `engine/state.rs` | — | ✅ to_json/from_json |
| GDScript桥接层 | `turn_manager.gd` | — | ✅ v2 接入CentJoursEngine |
| Godot 集成修复 | `turn_manager.gd` + `character_manager.gd` | — | ✅ 修复原生类名冲突 + RefCounted 懒初始化 |
| 仓库协作清理 | `.gitignore` + Git index | — | ✅ 忽略 `.godot/` / `cent-jours-core/target/` / 原生构建产物，并将已跟踪 `.godot` 缓存移出索引 |
| 政治UI层 | `political_system.gd` | — | ✅ v2 精简展示层 |
| 命令偏差代理 | `order_deviation.gd` | — | ✅ v2 CharacterManager代理 |
| 将领查询层 | `character_manager.gd` | — | ✅ v2 精简，移除冗余逻辑 |
| 地图路径查询 | `march_system.gd` | — | ✅ v2 精简，仅保留路径/距离 |
| 存档系统 | `save_manager.gd` + `lib.rs` | — | ✅ to_json/load_from_json 完整闭环 |
| 战斗展示元数据 | `battle_resolver.gd` | — | ✅ v2 精简为展示常量（138行→35行，DRY修复） |
| GameState 合规清理 | `game_state.gd` | — | ✅ v2 stub 违规方法，Bug修复（信号双发） |
| 忠诚度引擎暴露 | `lib.rs` | — | ✅ 新增 `get_all_loyalties()` |
| 忠诚度同步 | `turn_manager.gd` | — | ✅ v3 `_sync_state_from_engine()` loyalty 闭环 + 全契约注释 |
| 架构决策记录 | `docs/decisions/` | — | ✅ ADR-001/002/003（Rust+GDExtension、只读缓存、原生类集成边界） |
| 阈值常量 DRY 修复 | `order_deviation.rs` + `game_state.gd` | — | ✅ DEFECTION_THRESHOLD → re-export LOYALTY_CRISIS_THRESHOLD |
| 将领技能数据驱动化 | `network.rs` + `state.rs` | 4 | ✅ TDD，修复 davout/soult 数值错误，107 tests |

**合计**: 127 tests 全部通过

---

## GATE 2：✅ 通过

| 检查项 | 证据 |
|--------|------|
| 三系统耦合状态机 | `engine::state` 16 tests |
| 蒙特卡洛平衡验证 | Military 24.2% / Political 21.2% / Balanced 22.4%，均在 15%-35% |
| 30条历史事件集成 | 触发率验证通过 |
| Godot 4.6 升级 | gdext 0.4.5, api-4-5, VarDictionary |

---

## 上轮完成摘要（本轮 v23，2026-03-21）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `main_menu.tscn` | ✅ 解除 `engine_smoke_test.gd` 的临时挂载，主菜单恢复为正常入口场景 |
| ② | 提交流程建议 | ✅ 明确不建议直接 `git add .`，应按“代码修复 / 文档 / 仓库清理”选择性暂存 |

**验证结果：**
- `src/ui/main_menu.tscn` 已不再引用 `res://src/core/engine_smoke_test.gd`
- `engine_smoke_test.gd` 仍可作为临时开发验证脚本单独保留或后续删除

---

## 上轮完成摘要（本轮 v22，2026-03-21）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `.gitignore` | ✅ 补充 Godot 缓存、Rust target、Windows/Linux/macOS 原生构建产物忽略规则 |
| ② | Git index | ✅ 已跟踪 `.godot` 缓存全部执行 `git rm -r --cached .godot`，本地文件保留 |
| ③ | `engine_smoke_test.gd` / `main_menu.tscn` | ✅ 判定为临时联调改动：测试脚本可保留为开发工具，但当前挂载到主菜单的场景改动不建议提交 |

**验证结果：**
- `git status --short` 已确认 `.godot` 变为索引删除，后续会受 `.gitignore` 保护
- `.gdextension` / `*.import` / `*.uid` 未被纳入忽略，保留跨平台协作所需元数据

---

## 上轮完成摘要（本轮 v21，2026-03-21）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `character_manager.gd` | ✅ 删除冲突的 `class_name CharacterManager`，避免遮蔽 Rust 原生类 |
| ② | `turn_manager.gd` | ✅ `CentJoursEngine` 改为懒初始化，移除非法 `@export RefCounted` 用法 |
| ③ | `docs/decisions/ADR-003-gdscript-native-class-integration.md` | ✅ 记录报错背景、决策与 smoke test 验证路径 |
| ④ | Godot 4.6.1 编辑器 + 手动 smoke test | ✅ `CentJoursEngine.new()`、`get_state()`、`process_day_rest()` 闭环验证通过 |

**验证结果：**
- `cargo test --features godot-extension` 已于 2026-03-21 通过（127/127）
- 用户在 Godot 中执行 smoke test：
  `current_day()`、`get_state()`、`get_all_loyalties()`、`process_day_rest()`、`get_last_report()` 全部返回正常

---

## 上轮完成摘要（2026-03-19）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `turn_manager.gd` | ✅ 补充全部 Dictionary 边界契约注释（3 处 engine 调用） |
| ② | `order_deviation.rs` / `game_state.gd` | ✅ DRY 修复：`DEFECTION_THRESHOLD` 改为 re-export `LOYALTY_CRISIS_THRESHOLD`；GDScript 侧注释 Rust 映射 |
| ③ | `network.rs` + `state.rs` | ✅ 将领技能值数据驱动化（TDD，4 个新测试）；修复 davout(82→92)、soult(72→80) 数据错误 |

**107/107 单元测试全部通过**

---

## 上轮完成摘要（本轮，2026-03-19）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `pool.rs` + `state.rs` + `historical.json` | ✅ 事件效果/触发条件数据驱动化（TDD，4个新测试，111/111通过） |

**本轮修复详情：**
- `EventEffects.ney_loyalty_delta` / `fouche_loyalty_delta` → `loyalty_deltas: HashMap<String, f64>`
- `EventTrigger.davout_loyalty_min`（定义但从未检查的 Bug）→ `loyalty_min: HashMap<String, f64>`
- `TriggerContext` 新增 `loyalty_map` 全量将领忠诚度快照
- `build_trigger_ctx()` 填充 `loyalty_map`，`apply_event_effects()` 迭代 `loyalty_deltas`
- `historical.json` 3处旧格式迁移（ney_defection、davout_paris_assignment、fouche_conspiracy）

---

## 上轮完成摘要（本轮 v19，2026-03-19）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `network.rs:507` | ✅ 删除孤立 `#[test]` 属性，消除 duplicate_macro_attributes warning |
| ② | `pool.rs` + `state.rs` | ✅ `coalition_not_defeated` TDD 修复：`TriggerContext` 新增 `coalition_defeated: bool`；`can_trigger()` 添加检查；`build_trigger_ctx()` 从 `GameOutcome::NapoleonVictory` 推导；+3 新测试（111→113） |

**113/113 单元测试全部通过**

---

## 优先级 A — 当前轮（Godot 已可用）

### 全库扫描（2026-03-19，v20 重新扫描）

**无 P0/P1 架构违规。发现以下内容缺口与测试盲区：**

| # | 文件 / 数据 | 问题 | 严重程度 |
|---|------------|------|---------|
| ① | `historical.json` Day 13-19 | 7天完全无事件（拿破仑北上巴黎关键阶段，M4 核心交付物缺口） | 🔴 P1 内容 |
| ② | `battle/march.rs` `rest_army()` | 唯一无直接测试的 pub 函数，疲劳/士气恢复公式未验证 | 🟡 P2 |
| ③ | `narratives/mod.rs` | 无内容验证测试，JSON 键名与代码枚举不一致时运行时静默失败 | 🟡 P2 |
| ④ | `battle/resolver.rs` | 边界值未测试（零兵力、士气0/100、补给耗尽叠加） | 🟢 P3 |
| ⑤ | `historical.json` | 事件总量 30 条，M4 目标 300-500 条，内容缺口巨大 | 🟢 P3 内容 |

---

### ① historical.json — 填充 Day 13-19 事件空白 🔴 P1

**违反原则**：M4 交付物缺口（plan.md 历史事件池）

Day 13-19 是拿破仑从格勒诺布尔北上至里昂、再到巴黎的关键 7 天，
历史上充满戏剧性时刻，但 historical.json 在此区间完全空白，造成叙事死区。

**目标**：新增 3-5 条事件覆盖此区间，TDD 验证可触发。

**文件**：`src/data/events/historical.json`

---

### ② march.rs — `rest_army()` 补充单元测试 🟡 P2

**违反原则**：TDD（公开函数无直接测试）

`rest_army()` 恢复疲劳和士气，是行军系统核心恢复机制，
目前只通过 `engine::state` 集成测试间接覆盖，未独立验证公式正确性。

**文件**：`cent-jours-core/src/battle/march.rs`

---

### ③ narratives/mod.rs — 叙事键名验证测试 🟡 P2

**违反原则**：TDD（数据-代码契约无验证）

`narrative_key_for_action()` 将行动类型映射到 JSON 键名，
若 JSON 缺少对应键则 `pick_stendhal()` 返回 None，运行时静默失败，玩家看不到叙事文本。

**文件**：`cent-jours-core/src/narratives/mod.rs`

---

### ④ resolver.rs — 战斗边界值测试 🟢 P3

零兵力、极端士气、补给耗尽叠加等极端场景未验证，低概率但可能触发。

---

## 优先级 B — 需要 Godot 环境

| 任务 | 阻塞原因 |
|------|---------|
| `rn_slider.gd:31-41` — `_process` 轮询改为 EventBus 信号订阅 | 需要 Godot 运行验证信号触发 |
| UI 场景文件（.tscn） | 需要 Godot 编辑器 |
| CentJoursEngine 节点挂载到场景树 | 需要 Godot 编辑器 |
| GDExtension 集成测试 | 需要 Godot 运行环境 |
| `decision_card.gd` 完整布局 | 需要可见 UI 布局确认 |
| M5 美术资源 | 需要 Godot + 美术工具 |

---

## GATE 3 前置条件（等待 Godot 环境）

| 检查项 | 状态 |
|--------|------|
| GDScript 层完全合规（无业务逻辑、无平行计算） | ✅ 完成 |
| GameState loyalty 与引擎闭环同步 | ✅ 完成 |
| 127 单元测试全部通过 | ✅ 完成 |
| GDExtension 集成测试（Godot 运行） | ⏳ 等待 Godot 环境 |
| 完整回合流程端到端测试 | ⏳ 等待 Godot 环境 |

---

## 本轮完成摘要（v20，2026-03-20）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `src/data/events/historical.json` | ✅ 新增 `lyon_artois_flees`（Day10-14）/ `burgundy_popular_surge`（Day14-17）/ `fontainebleau_eve`（Day17-19），填充北上巴黎叙事空白，+3 TDD测试（113→116） |
| ② | `battle/march.rs` | ✅ `rest_army()` 4个直接单元测试：高/低补给档位、边界值supply=50、公式关系断言（116→120） |
| ③ | `narratives/mod.rs` | ✅ +2 契约验证测试：`policy_narrative_key()` 所有映射结果在 stendhal + consequences JSON 均有条目，防止键名漂移静默失败（120→122） |
| ④ | `battle/resolver.rs` | ✅ +5 边界值测试：零兵力/零士气/双方零兵力不崩溃、满疲劳×断补给复合惩罚、ratio_to_result 全阈值边界（122→127） |

**127/127 单元测试全部通过**

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
