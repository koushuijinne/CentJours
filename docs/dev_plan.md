# Cent Jours — 开发优先级计划

> **更新**: 2026-03-23 v41
> **当前分支**: `claude/review-project-plan-vgQTN`
> **通用原则**: 项目长期稳定原则详见 `docs/development_principles.md`
> **快速接手**: 当前状态见 `docs/codex_handoff.md`，新会话首条 prompt 模板见 `docs/codex_session_prompts.md`

---

## 开发原则

> 项目级完整原则以 `docs/development_principles.md` 为准。本文只保留当前技术轮次直接相关的默认原则与流程要求，避免和总原则文档重复漂移。

### 一、当前轮默认适用原则

- `核心循环优先`：新功能优先服务 Dawn / Action / Dusk 主循环。
- `TDD`：Rust 规则层改动默认先补测试，或至少先写明验收检查项。
- `单一状态源`：引擎是真实状态，`GameState` 只做 UI 只读缓存。
- `GDScript 薄层`：Godot 脚本负责桥接、展示、信号，不复制核心规则。
- `数据驱动设计`：角色、事件、地图、平衡参数优先外置，不散写到脚本。

### 二、文档与提交流程要求

- `活文档`：完成任务后立即更新本文档状态（✅/🔶）和进度快照。
- `交接同步`：完成一轮开发后默认同步更新 `docs/codex_handoff.md`；若接手模板变化，同步更新 `docs/codex_session_prompts.md`。
- `同提交同步`：`docs/dev_plan.md` 的更新应和对应代码变更放在同一次 commit。
- `ADR`：跨层接口、状态流、重要架构选型继续沉淀到 `docs/decisions/ADR-XXX.md`。
- `边界契约`：Rust ↔ GDScript 的 `Dictionary` / `Array` 返回结构要在调用侧或桥接层写清键名和语义。

### 三、提交前强制检查

1. 将已完成项标记 ✅ 并移入模块清单。
2. 更新进度快照、完成描述和 `docs/codex_handoff.md` 当前状态。
3. 重新扫描代码库，记录新出现的技术债或残留风险。
4. 重排下一轮优先级，确保 Priority A 仍是现在就能做的最高价值任务。
5. 若接手方式或默认验证命令有变化，同步更新 `docs/codex_session_prompts.md`。
6. 将文档更新与实现改动放入同一次 commit。

### 四、小步提交

- 每完成一个独立小功能立即 commit + push。
- 推荐格式：`feat(模块): 描述` / `fix(模块): 描述` / `data: 描述`。
- 不积累“难以复盘的大提交”。

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

**约束**: Godot 编辑器已可运行；当前无头测试只在 Windows 环境执行，WSL/Linux 不作为本轮验证路径。

## 当前前端最高优先级（2026-03-22）

- `ADR-006` 第一轮布局稳定性问题已完成并通过 Windows `1280x720` 手动验收：
  - 顶栏垂直裁切
  - 决策托盘内容截断
  - Sidebar 忠诚度 / 叙事面板空间挤压
- `ADR-007` 地图 hover / 空白点击状态机已完成落地：
  - 移除 Godot 默认黑底 tooltip
  - `Map Inspector` 成为唯一详情反馈源
  - 空白点击统一收口到 `idle`
- Priority E（地图标签去碰撞 + hover / click + Map Inspector）现已完成，并通过 Windows 真机验收。
- 当前前端最高优先级已切换到 Priority F：主菜单解耦重构。
- Priority F 第二波已落地：新增 `map_controller.gd`、`layout_controller.gd`、`dialogs_controller.gd`，`src/ui/main_menu.gd` 已从 `1531` 行一路收缩到 `436` 行。
- 主菜单主脚本当前已基本降为编排器；下一步重点从“继续拆分”转向“收尾接口、命名与测试覆盖”。
- 地图交互仍属于 Godot 薄展示层实现：只读取 `map_nodes.json`，不引入 Rust 规则或 `TurnManager` 新接口。
- Windows 无头测试已通过，说明 Windows Godot 启动链路与 `cent_jours_core.dll` 装载正常。
- 默认 Windows 无头测试命令：
  `E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit`
- WSL/Linux 无头测试不在当前轮次执行范围内；若缺 Linux 版 `cent_jours_core.so`，不视为当前 Windows 开发路径阻塞。
- 快速接手入口：
  `docs/codex_handoff.md` / `docs/codex_session_prompts.md`
- 详细任务拆解与验收项见 `docs/frontend_dev_plan.md`。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 12 | ✅ +5边界值（零兵力/零士气/复合惩罚/ratio阈值） |
| 行军系统 | `battle/march.rs` | 10 | ✅ +4直接测试rest_army()（高低补给/边界/公式验证） |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 27 | ✅ +4 命令偏差测试 |
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
| 主场景布局稳定性（第一轮） | `main_menu.tscn` + `main_menu.gd` + `decision_card.gd` + `rn_slider.gd` | — | ✅ ADR-006 首轮代码落地，并已升级为“最小高度 + 弹性布局 + 局部滚动”重构；Windows `1280x720` 手验通过 |

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

## 上轮完成摘要（本轮 v36，2026-03-22）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `src/ui/main_menu.tscn` | ✅ 左侧布局改成“地图吸收剩余高度、托盘只保底不扩张”，Sidebar 忠诚度区加入内部滚动 |
| ② | `src/ui/main_menu.gd` | ✅ 顶栏高度改为按真实内容最小值推导；托盘与 Sidebar 保底高度改为内容驱动，而不是继续堆固定像素 |
| ③ | `src/ui/main_menu.gd` | ✅ 保留窗口响应式安全区与尺寸重算，但开始从“参数化硬编码”转向“最小高度 + 弹性分配” |
| ④ | `src/ui/components/decision_card.gd` | ✅ 卡片新增运行时尺寸重建，标题改为单行省略，内部间距随目标高度重算 |
| ⑤ | `src/ui/components/rn_slider.gd` | ✅ 组件继续尊重外部尺寸，作为顶栏紧凑滑条使用 |

**验证结果：**
- Windows 无头测试已执行：
  `E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit`
- 结果：Godot 成功启动，`godot-rust` 初始化日志正常，退出码 `0`
- Windows Godot `1280x720` 手动验收已通过：顶栏、托盘与 Sidebar 第一轮目标全部达成
- WSL/Linux 无头测试不再作为默认要求；Windows 真机截图继续作为前端视觉问题的最终确认步骤

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

### Tier 1 — 最小可玩 ✅（v29 完成）

> **这是第一个”真正可玩”的里程碑。**

#### 1.1 战斗选择 UI ✅
- 决策托盘新增”发动战役”卡片 → 弹出 PopupPanel（将领/兵力/地形）→ `submit_action(“battle”)`
- 战斗结果通过现有叙事管线（get_last_report → stendhal/consequence）展示

#### 1.2 忠诚度强化 UI ✅
- 决策托盘新增”亲自接见将领”卡片 → 弹出将领列表 → `submit_action(“boost_loyalty”)`
- 合法性 < 10 时确认按钮自动禁用

#### 1.3 游戏结束画面 ✅
- 全屏遮罩 + 居中面板：5 种结局中文标题/描述 + 最终统计 + “重新开始”按钮
- `TurnManager.reset_engine()` 支持重置引擎重来

#### 1.4 冷却逻辑 ✅
- `_refresh_card_cooldowns()` 跳过 rest/battle/boost_loyalty 非政策卡

**Tier 1 完成**: 玩家可选”休整/政策/战斗/强化忠诚”四种行动，游戏结束有完整画面并可重来。

---

### Tier 2 — 战略纵深（3-4 轮，空间维度）

> 行军系统接入，玩家决策从”选什么政策”扩展到”去哪里、何时打”。
> 工作量标记：`[L]` = Large（跨层/大模块），`[M]` = Medium（中等任务），`[S]` = Small（局部补完）。

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

#### 2.4 行军与战斗关联 ✅
- ✅ 战斗地形从当前位置的 `map_nodes.json` 节点 `terrain` 推断（`_battle_popup_state()` 默认填充）
- ✅ 行军疲劳影响下一次战斗结果（`march_fatigue_penalty()` → `ArmyState` 持久化 → `calculate_force_score()` 消耗）
- ✅ 战报叙事包含地形守方加成百分比

**Tier 2 完成标志**: ✅ 玩家在地图上移动拿破仑，行军消耗疲劳，到达目标后发起战斗。

---

### Tier 3 — 深度与沉浸（4-5 轮，可分批做）

> 让已实现但未接入的系统发挥作用。

#### 3.1 命令偏差接入战斗 ✅
**文件**: `engine/state.rs` `process_battle()` + `characters/network.rs`
- ✅ `calculate_deviation()` 根据忠诚度计算偏差系数（0.80–1.20）
- ✅ `process_battle()` 用偏差系数调整实际投入兵力
- ✅ 战报叙事展示偏差信息（超出/少于命令兵力）
- ✅ 4 个偏差单元测试（高/低忠诚度、范围合法性、兵力影响）
- 测试覆盖：135 个（+4 偏差测试）

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

## 本轮完成摘要（本轮 v29，2026-03-22）

| # | 文件 | 处理结果 |
|---|------|---------|
| ① | `src/ui/main_menu.gd` | ✅ 新增战斗卡+忠诚度卡（BATTLE_CARD_META/BOOST_CARD_META）；战斗弹窗（将领/兵力/地形选择）；忠诚度弹窗（将领选择+合法性检查）；游戏结束全屏面板（5种结局+统计+重启） |
| ② | `src/core/turn_manager.gd` | ✅ 新增 `reset_engine()` 支持重新开始游戏 |

**无 Rust 改动，无新文件。** TurnManager 的 battle/boost_loyalty 分支已在 v25 实现，本轮只补前端 UI 入口。

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
