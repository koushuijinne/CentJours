# Cent Jours — 开发优先级计划

> **更新**: 2026-03-22 v26
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

## 当前进度快照（2026-03-22）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ████████████ 100% ✅ Rust层✅，Godot端到端回合闭环✅
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
| 前端主场景骨架 | `main_menu.tscn` + `main_menu.gd` + `src/dev/engine_smoke_test_scene.tscn` | — | ✅ 正式入口脱离 smoke test，四区布局 + 组件接入 + 独立开发测试场景 |
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
| 架构决策记录 | `docs/decisions/` | — | ✅ ADR-001/002/003/005（Rust+GDExtension、只读缓存、原生类集成边界、冷却接口暴露） |
| 阈值常量 DRY 修复 | `order_deviation.rs` + `game_state.gd` | — | ✅ DEFECTION_THRESHOLD → re-export LOYALTY_CRISIS_THRESHOLD |
| 将领技能数据驱动化 | `network.rs` + `state.rs` | 4 | ✅ TDD，修复 davout/soult 数值错误，107 tests |
| 政策冷却接口暴露 | `system.rs` + `lib.rs` + `turn_manager.gd` + `game_state.gd` + `political_system.gd` + `main_menu.gd` | — | ✅ ADR-005，`get_state()` 返回 `cooldowns`，前端从 GameState 缓存读取真实冷却天数，删除硬编码与前端自行标记逻辑 |

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

## 优先级 A — 当前轮（主场景已可展示，进入真实绑定期）

### 全库扫描（2026-03-21，v24 重新扫描）

**当前无 P0/P1 架构违规。v25 本轮修复了 ①③，②④ 进入下一优先级：**

| # | 文件 / 模块 | 问题 | 严重程度 |
|---|------------|------|---------|
| ① | `src/ui/main_menu.gd` | ~~顶栏仍只读取 `GameState` 当前值，尚未接入 `TurnManager` 驱动的一天流程刷新~~ **✅ 已修复**：`TurnManager` 注册为 autoload，`_start_game()` 引导真实回合 | ✅ 已修复 |
| ② | `src/ui/main_menu.gd` Sidebar | 右侧边栏叙事信号已接入（`stendhal_diary_entry` / `micro_narrative_shown`），但忠诚度仍显示固定3名将领，派系无趋势箭头 | 🟡 P2 前端 |
| ③ | `src/ui/main_menu.gd` Decision Tray | ~~卡片已可见，但仍未触发 `submit_action()` 或 `policy_enacted` 闭环~~ **✅ 已修复**：确认按钮接入 `submit_action()`，回合闭环打通 | ✅ 已修复 |
| ④ | `src/ui/main_menu.gd` Map Area | 地图仍为静态战略感占位，尚未读取 `map_nodes.json` 做数据驱动布局 | 🟢 P3 前端 |

---

### ① 顶栏数据绑定升级 🟡 P2

**目标**：让 Top Bar 从“读取初始缓存”升级到“跟随真实回合刷新”。

**文件**：`src/ui/main_menu.gd` + `src/core/turn_manager.gd`

**要求**：
- 由 `TurnManager.start_new_turn()` 驱动 Dawn 初始同步
- 顶栏跟随 `EventBus.phase_changed` / `legitimacy_changed` / `loyalty_changed` 刷新
- 至少验证一次 `Rest` 后数值可见变化

---

### ② Sidebar 占位升级 🟡 P2

**目标**：把边栏从占位摘要变成真实信息承载区。

**文件**：`src/ui/main_menu.gd`

**要求**：
- 展示最近历史事件 ID 与司汤达文本
- 扩展将领摘要，不止 3 名固定角色
- 让局势摘要包含派系趋势而不是纯静态拼接

---

### ③ Decision Tray 接入行动闭环 🟡 P2

**目标**：让卡片从“会亮”变成“能推进一天”。

**文件**：`src/ui/main_menu.gd` + `src/core/turn_manager.gd`

**要求**：
- 选择卡片后能提交对应 policy id
- 处理选中态、不可用态和结果刷新
- 与 `engine.process_day_policy()` 的真实可用政策保持一致

---

## 优先级 B — 视觉与地图深化

| 任务 | 说明 |
|------|------|
| 地图区读取 `map_nodes.json` | 用真实节点替换手写坐标 |
| `rn_slider.gd` 轮询优化 | 从 `_process` 过渡到更明确的状态刷新机制 |
| Sidebar 叙事样式 | 把事件/日记做成真正的阅读面板而非单段文本 |
| 主场景视觉打磨 | 分隔线、字号层级、地图光效、托盘 hover 反馈 |

---

## GATE 3 前置条件（已进入 Godot 主场景迭代）

| 检查项 | 状态 |
|--------|------|
| GDScript 层完全合规（无业务逻辑、无平行计算） | ✅ 完成 |
| GameState loyalty 与引擎闭环同步 | ✅ 完成 |
| 主场景四区骨架可见 | ✅ 完成 |
| `RougeNoirSlider` / `DecisionCard` 已接入正式入口 | ✅ 完成 |
| 完整回合流程端到端测试 | ✅ 完成（TurnManager autoload + confirm button 闭环） |

---

## 本轮完成摘要（本轮 v25，2026-03-22）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `project.godot` | ✅ 将 `TurnManager` 注册为 autoload，与 `GameState`/`EventBus` 对齐 |
| ② | `src/ui/main_menu.gd` | ✅ 新增 `_start_game()` / `_begin_next_turn()` 驱动真实回合 Dawn+Action；新增确认按钮 `_build_confirm_button()`；`_on_confirm_pressed()` 提交政策或休整；接入 `stendhal_diary_entry` / `micro_narrative_shown` / `turn_ended` / `game_over` 信号 |

**验证目标：**
- 运行后顶栏显示引擎真实数值（非初始占位）
- 点选政策卡片 → 点"执行行动" → 回合推进 → Day 数字 +1，数值变化可见
- 边栏叙事面板显示司汤达日记文本或行动后果
- 游戏结束时托盘禁用并显示结局

---

## 本轮完成摘要（本轮 v24，2026-03-21）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `src/ui/main_menu.tscn` | ✅ 从占位页重构为 Top Bar / Map Area / Sidebar / Decision Tray 四区主场景骨架 |
| ② | `src/ui/main_menu.gd` | ✅ 新增主场景 UI 控制脚本，初始化 Theme、读取 `GameState`、接入 `RougeNoirSlider` 与 4 张 `DecisionCard` |
| ③ | `src/dev/engine_smoke_test_scene.tscn` | ✅ 新增独立开发测试场景，正式入口彻底脱离 smoke test |

**验证目标：**
- 运行正式入口后，不再自动打印 smoke test 日志
- 主场景可见四区布局、顶栏资源摘要、地图节点占位、边栏摘要和决策托盘

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
