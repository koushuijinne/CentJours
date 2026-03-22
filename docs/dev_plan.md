# Cent Jours — 开发优先级计划

> **更新**: 2026-03-22 v28
> **当前分支**: `claude/review-project-plan-vgQTN`

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

## 离”真正可玩”还有多远？— 优先级路线图（v27 全库扫描）

### 现状总览

| 维度 | 已完成 | 缺失 |
|------|--------|------|
| **回合流程** | Dawn→Action→Dusk 闭环 ✅ | — |
| **政策系统** | Rust 8 条 ✅ / GDExt 仅暴露 5 条 / UI 仅显示 4 条 | 3 条 GDExt match 缺失 + 4 条 UI 卡片缺失 |
| **战斗系统** | Rust resolve_battle ✅ / GDExt process_day_battle ✅ | **无 UI**：选将领/兵力/地形 全无 |
| **行军系统** | Rust march.rs 移动/补给/Dijkstra ✅ | **完全断线**：无 PlayerAction::March、无 GDExt API、无 UI |
| **忠诚度强化** | Rust process_boost_loyalty ✅ / GDExt ✅ | **无 UI**：无法选择将领 |
| **将领偏差** | Rust order_deviation ✅ / GDExt calculate_deviation ✅ | 未接入战斗流程 |
| **叛逃系统** | Ney/Grouchy 概率模型已写 | 未在主循环调用 |
| **联军** | 线性增长 40k→200k | 无事件波动/无击败机制 |
| **游戏结束** | 引擎检测 3 种结局 ✅ | UI 仅一行文字，无重启 |
| **存档** | SaveManager to_json/load_from_json ✅ | 无 UI 入口 |
| **冷却显示** | ADR-005 已完成 ✅ | — |

> **强化将领机制说明**：`process_boost_loyalty(general_id)` 消耗 5 点合法性，目标将领忠诚度 +8。前置条件：合法性 ≥ 10。本质是拿破仑用政治资本换将领忠心。

---

### Tier 0 — 快速修复 ✅（v28 完成）

> 不需要新架构，只是接通已有管线。

#### 0.1 GDExt 补全 3 条缺失政策 ✅
- `lib.rs` match 添加 `grant_titles`、`secret_diplomacy`、`print_money`
- 蒙特卡洛 AI 策略覆盖全部 8 条（Military +print_money, Political +grant_titles, engine_action 全量）
- `cargo test` 127/127 通过

#### 0.2 UI 显示全部 8 张政策卡片 ✅
- `PRIORITY_POLICY_IDS` 扩展为 8 条
- `POLICY_EMOJIS` / `POLICY_EFFECTS` 补全 4 条新卡片数据

**Tier 0 完成**: 玩家能使用全部 8 种政策，包括 2 行动点的秘密外交。

---

### Tier 1 — 最小可玩（2-3 轮，核心玩法闭环）

> 玩家能战斗、能强化忠诚、游戏能正常结束和重来。
> **这是第一个”真正可玩”的里程碑。**

#### 1.1 战斗选择 UI [M]
**新文件**: `src/ui/dialogs/battle_setup_dialog.gd`
**修改**: `src/ui/main_menu.gd`

- 决策托盘新增”发动战役”卡片
- 点击后弹出 PopupPanel：
  - 将领下拉（从 `GameState.characters` 筛选 role=marshal）
  - 兵力滑块（min 1000, max GameState.total_troops）
  - 地形选择（plains/hills/forest/urban）
  - 确认/取消
- 确认后调 `TurnManager.submit_action(“battle”, {general_id, troops, terrain})`

#### 1.2 战斗结果展示 [S]
**修改**: `src/ui/main_menu.gd` / `src/core/turn_manager.gd`

- 从 `engine.get_last_report()` 读取叙事文本展示
- 对比战前战后 troops/morale 差值，在顶栏闪烁

#### 1.3 忠诚度强化 UI [S]
**修改**: `src/ui/main_menu.gd`

- 决策托盘新增”强化将领”卡片（消耗 5 合法性 → 忠诚度 +8）
- 点击后弹出将领列表，选中 → 确认 → `TurnManager.submit_action(“boost_loyalty”, {general_id})`

#### 1.4 游戏结束画面 [S]
**修改**: `src/ui/main_menu.gd` `_on_game_over()`

- 全屏半透明遮罩 + 居中 PanelContainer
- 结局标题（NapoleonVictory / WaterlooHistorical / WaterlooDefeat / PoliticalCollapse / MilitaryAnnihilation）
- 最终统计（天数、合法性、胜场、兵力）
- “重新开始”按钮

**Tier 1 完成标志**: 玩家每回合能选择”休整 / 政策 / 战斗 / 强化忠诚”四种行动，游戏结束时看到结局画面并可重来。

---

### Tier 2 — 战略纵深（3-4 轮，空间维度）

> 行军系统接入，玩家决策从”选什么政策”扩展到”去哪里、何时打”。

#### 2.1 Rust: PlayerAction::March + 引擎集成 [L]
**文件**: `cent-jours-core/src/engine/state.rs`

- 新增 `PlayerAction::March { target_node: String }`
- 新增 `process_march()` → 调用 `battle/march.rs` 的 `move_army()`
- `GameEngine` 新增 `pub napoleon_location: String` 字段
- `SaveState` 增加位置字段
- TDD：行军测试（移动到相邻节点、非相邻失败、疲劳变化）

#### 2.2 GDExt: 暴露行军 API [M]
**文件**: `cent-jours-core/src/lib.rs`

- 新增 `process_day_march(target_node: GString)`
- `get_state()` 增加 `napoleon_location` 字段
- 新增 `get_adjacent_nodes() -> Array<GString>`

#### 2.3 前端: 地图点击行军 [M]
**文件**: `src/ui/main_menu.gd`

- 地图节点添加点击事件 → 高亮可达节点 → 确认行军
- 决策托盘新增”行军”卡片，点击后切换到地图交互模式
- `TurnManager.submit_action(“march”, {target_node})`

#### 2.4 行军与战斗关联 [S]
- 战斗地形从当前位置的 `map_nodes.json` 节点 `type` 推断
- 行军疲劳影响下一次战斗结果

**Tier 2 完成标志**: 玩家在地图上移动拿破仑，行军消耗疲劳，到达目标后发起战斗。

---

### Tier 3 — 深度与沉浸（4-5 轮，可分批做）

> 让已实现但未接入的系统发挥作用。

#### 3.1 命令偏差接入战斗 [M]
**文件**: `engine/state.rs` `process_battle()`
- 战斗前调 `calculate_deviation()` 影响将领表现
- 前端战报展示偏差叙事

#### 3.2 叛逃/倒戈触发 [M]
**文件**: `engine/state.rs` `dusk_settlement()`
- 每日检查 `NeyDefectionCondition` / `GrouchyArrivalCondition`
- 忠诚度低于阈值时触发叛逃

#### 3.3 联军动态化 [M]
**文件**: `engine/state.rs` `coalition_force()`
- 战败后联军士气/兵力下降
- `apply_event_effects()` 处理 `coalition_troops_delta`

#### 3.4 存档/读档 UI [S]
**文件**: `src/ui/main_menu.gd`
- 顶栏增加存档/读档按钮 + 确认对话框

#### 3.5 事件效果补完 [S]
**文件**: `engine/state.rs` `apply_event_effects()`
- 处理 `coalition_troops_delta`、`paris_security_bonus`、`political_stability_bonus`

**Tier 3 完成标志**: 将领会叛逃、命令会偏差、联军会因败仗动摇、玩家可存档。

---

### 总量估算

| Tier | 改动范围 | 复杂度 | 预计轮次 |
|------|---------|--------|---------|
| **Tier 0** | GDExt match 补 3 行 + GDScript 常量扩展 | S | 1 轮 |
| **Tier 1** | 战斗对话框 + 忠诚度弹窗 + 结束画面 | M | 2-3 轮 |
| **Tier 2** | Rust 新 Action + GDExt + 地图交互 | L | 3-4 轮 |
| **Tier 3** | 5 个独立子任务 | M×5 | 4-5 轮 |

**到 Tier 1 = 真正可玩（~4 轮）** / **到 Tier 2 = 有战略深度（~8 轮）** / **到 Tier 3 = 完整体验（~13 轮）**

### 依赖关系

```
Tier 0 ──→ Tier 1 ──→ Tier 2 ──→ Tier 3
                                    ↑
            Tier 1.1 ───────→ Tier 2.4 (战斗需要位置)
            Tier 2.1 ───────→ Tier 3.1 (偏差需要行军距离)
            Tier 2.1 ───────→ Tier 3.2 (叛逃需要位置上下文)
```

### 不在本路线图范围

- M5 美术资源替换（emoji → 真实纹理）
- M6 BGM/音效
- 多语言 / 多存档槽 / Steam 集成 / 教程

### 关键文件清单

| 文件 | Tier | 改动类型 |
|------|------|---------|
| `cent-jours-core/src/lib.rs` | 0, 2 | 补政策 match + 行军 API |
| `cent-jours-core/src/engine/state.rs` | 2, 3 | March Action + 偏差/叛逃 |
| `cent-jours-core/src/simulation/monte_carlo.rs` | 0 | AI 策略补全 |
| `src/ui/main_menu.gd` | 0, 1, 2 | 卡片 + 对话框 + 地图交互 |
| `src/ui/dialogs/battle_setup_dialog.gd` | 1 | 新建 |
| `src/core/turn_manager.gd` | 2 | march 分支 |
| `src/core/game_state.gd` | 2 | napoleon_location |

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

## 本轮完成摘要（本轮 v28，2026-03-22）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `cent-jours-core/src/lib.rs` | ✅ `process_day_policy()` match 补全 grant_titles/secret_diplomacy/print_money |
| ② | `cent-jours-core/src/simulation/monte_carlo.rs` | ✅ AI 策略覆盖全部 8 条政策（Military +print_money, Political +grant_titles, engine_action 全量） |
| ③ | `src/ui/main_menu.gd` | ✅ PRIORITY_POLICY_IDS 扩展为 8 条 + POLICY_EMOJIS/EFFECTS 补全 4 条新卡片 |
| ④ | `docs/dev_plan.md` + `plan.md` | ✅ Tier 0 标记完成 |

**验证**: 127/127 cargo test 通过

---

## 本轮完成摘要（本轮 v27，2026-03-22）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `docs/dev_plan.md` | ✅ 全库前后端扫描，替换过期 Priority A/B 为 Tier 0-3 可玩性路线图 |
| ② | `plan.md` | ✅ 同步更新里程碑状态 |

**分析发现：**
- GDExt `process_day_policy()` 仅暴露 5/8 政策（grant_titles/secret_diplomacy/print_money 缺失）
- 战斗/行军/忠诚度强化 3 大核心行动均无 UI 入口
- 行军系统 Rust→GDExt→UI 全链路断线（无 PlayerAction::March）
- 游戏结束仅一行文字，无重启
- 定义 Tier 0-3 路线图：~4 轮到可玩，~8 轮到有深度，~13 轮到完整体验

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
