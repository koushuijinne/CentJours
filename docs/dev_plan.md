# Cent Jours — 开发优先级计划

> **更新**: 2026-03-19 v8
> **当前分支**: `claude/review-project-plan-LKKTR`

---

## 开发原则

> **测试驱动开发（TDD）**
>
> 所有 Rust 模块遵循严格 TDD 流程：
> 1. **Red** — 先写失败的单元测试，明确模块的输入/输出契约
> 2. **Green** — 写最少的实现代码使测试通过
> 3. **Refactor** — 在测试保护下重构，不破坏已有行为
>
> 规则：
> - 禁止在没有对应测试的情况下提交业务逻辑
> - 每个公开函数至少1个正向测试 + 1个边界/错误测试
> - `cargo test` 全通过才能提交
> - 历史场景测试（Ney/Grouchy）作为验收标准

> **小步提交推送（Commit + Push Often）**
>
> 每完成一个独立的小功能立即 **commit 并 push**：
> - 一个函数 + 对应测试 = 一次 commit + push
> - 一个 JSON 数据文件更新 = 一次 commit + push
> - 提交信息格式：`feat(模块): 功能描述` / `test(模块): 测试描述` / `data: 描述`
> - 永远不要积累"大提交"——每次 commit 保持单一职责，完成即 push

> **文档同步更新**
>
> - **完成小任务后**：立即更新 `docs/dev_plan.md` 中对应任务的状态（✅/🔶）和进度快照
> - **完成大任务/里程碑后**：同步更新 `plan.md` 中对应 M 阶段的交付物勾选和状态标注
> - 原则：文档反映的始终是**当前真实状态**，而非计划状态

---

## 当前进度快照（2026-03-19）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ██████████░░  85% 🔶 Rust层✅，EventPool集成✅，Godot待安装
M2  政治系统   ███████████░  90% ✅ Rust层✅，平衡达标，UI待Godot
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ███████████░  95% GDScript桥接层✅，全政策叙事覆盖✅，缺game_state字段补全
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**103/103 单元测试全部通过**（最后运行：2026-03-19）

**平衡结果（不变）**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅

**约束**: 暂无 Godot 运行环境。Rust/JSON/GDScript 均可开发，但 .tscn 场景无法运行测试。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 7 | ✅ |
| 行军系统 | `battle/march.rs` | 6 | ✅ |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 23 | ✅ 含from_json |
| 三系统状态机 | `engine/state.rs` | 16 | ✅ 含EventPool集成 |
| 历史事件池 | `events/pool.rs` | 13 | ✅ 30条事件×5条叙事 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 | ✅ |
| 叙事引擎 | `narratives/mod.rs` | 8 | ✅ 11类stendhal + 12类consequence |
| GDExtension节点 | `lib.rs` | — | ✅ 4节点（Battle/Politics/Character/Game） |
| Save/Load序列化 | `engine/state.rs` | — | ✅ SaveState + to_json/from_json |
| GDScript桥接层 | `turn_manager.gd` | — | ✅ v2 接入CentJoursEngine |
| 政治UI层 | `political_system.gd` | — | ✅ v2 精简为展示层 |
| 命令偏差代理 | `order_deviation.gd` | — | ✅ v2 CharacterManager代理 |

**合计**: 103 tests | 全部通过

---

## 优先级 A — ✅ 全部完成（2026-03-18）

### ① EventPool → GameEngine 内部集成 ✅

**目标**: 当前 `run_engine_simulation()` 在外部手动调用 `event_pool.trigger_all()`。正式集成应该在 `GameEngine::process_day()` 的 Dawn 阶段**自动**触发事件，并将效果应用到三系统。这样 Godot 层只需调用 `process_day()`，不需要自己管理事件池。

**为什么优先**: 这是让引擎"自包含"的最后一步——完成后 GameEngine 就是一个完整的游戏状态机，外部无需额外驱动逻辑。

**TDD 测试先行**:
```rust
// GameEngine 包含 EventPool，process_day 时自动触发
fn 引擎内部自动触发内伊倒戈() {
    let mut engine = GameEngine::new();
    let mut rng = StdRng::seed_from_u64(42);
    // 推进到 Day 6（内伊倒戈窗口）
    for _ in 1..6 {
        engine.process_day(PlayerAction::Rest, &mut rng);
    }
    // 引擎应已自动触发并记录事件
    assert!(engine.triggered_events().iter().any(|id| id == "ney_defection")
        || engine.characters.loyalty("ney") > 55.0, // 效果已应用
        "Day 6 前后应自动触发或尝试内伊倒戈");
}

// 事件不重复触发
fn 事件只触发一次() {
    let mut engine = GameEngine::new();
    let mut rng = StdRng::seed_from_u64(42);
    for _ in 0..20 {
        engine.process_day(PlayerAction::Rest, &mut rng);
    }
    let ney_count = engine.triggered_events().iter()
        .filter(|id| *id == "ney_defection").count();
    assert!(ney_count <= 1, "内伊倒戈不应重复触发");
}
```

**改动**:
- `GameEngine` 结构体新增 `event_pool: EventPool` 字段
- `process_day()` Dawn 阶段调用 `event_pool.trigger_all(ctx)`
- 新增 `triggered_events() -> &[String]` 查询接口
- `build_trigger_ctx()` 移入 `engine/state.rs`（从 monte_carlo.rs 中独立出来）

**文件**: `cent-jours-core/src/engine/state.rs`

---

### ② `.gdextension` 配置文件 ✅

**目标**: 写好 Godot 识别 Rust 插件的描述符，安装 Godot 后可直接测试 GDExtension 绑定。

**为什么优先**: 30 分钟工作，安装 Godot 前必须准备好，拖到 M5 会阻塞集成。

**文件**: `cent-jours-core/cent_jours_core.gdextension`

```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = "4.1"

[libraries]
linux.debug.x86_64   = "res://cent-jours-core/target/debug/libcent_jours_core.so"
linux.release.x86_64 = "res://cent-jours-core/target/release/libcent_jours_core.so"
windows.debug.x86_64   = "res://cent-jours-core/target/debug/cent_jours_core.dll"
windows.release.x86_64 = "res://cent-jours-core/target/release/cent_jours_core.dll"
macos.debug   = "res://cent-jours-core/target/debug/libcent_jours_core.dylib"
macos.release = "res://cent-jours-core/target/release/libcent_jours_core.dylib"
```

---

### ③ balance_notes.md — 记录最终平衡参数 ✅

**目标**: 将当前有效的平衡参数整理成文档，M6 调参时直接查阅，避免重新推导。

**内容**:
- 决战联军公式：`70_000 + coalition_strength * 1_400`
- 胜利条件：`victories >= 5 AND legitimacy >= 45.0`
- 即时胜利：决战胜 + victories >= 5 → 立即 `NapoleonVictory`
- 三策略胜率：Military 24.2% / Political 21.2% / Balanced 22.4%
- 政治崩溃率 < 30% 均满足

**文件**: `docs/balance_notes.md`

---

## 优先级 B — ✅ 全部完成（2026-03-18，并行执行）

### ④ 司汤达日记文本池 ✅

**文件**: `src/data/narratives/stendhal_diary.json`

为以下 8 种决策类型各预写 5 个文本变体，风格：冷峻 / 讽刺 / 心理分析：

| 决策类型 | 文体方向 |
|----------|---------|
| `conscription` | 观察征兵现场的人性细节 |
| `constitutional_promise` | 讽刺皇帝承诺宪政的矛盾 |
| `public_speech` | 冷静分析演说的政治效果 |
| `battle_victory` | 胜利背后的代价与疲惫 |
| `battle_defeat` | 失败时皇帝面部表情的微妙变化 |
| `reduce_taxes` | 民众短暂的感激与长期的漠然 |
| `boost_loyalty` | 将领被私下召见时的心理活动 |
| `diplomatic_secret` | 外交的虚伪与必要性 |

**参考文风**:
```json
{
  "conscription": [
    "他今天又签了一道征兵令。他的笔迹很漂亮——即便是在做这种事的时候。",
    "征兵令。士兵们的父亲会读报纸吗？不，但他们的妻子会。",
    "我在档案馆看到了那份名单。大部分人的名字我不认识，这可能是一件好事。"
  ]
}
```

### ⑤ 微叙事后果片段 ✅

**文件**: `src/data/narratives/consequences.json`

每种政策/行动后弹出一段普通人视角（2-3句）。为以下类型各写 5 条：

| 类型 | 普通人视角 |
|------|----------|
| `conscription` | 家庭送别场景 |
| `reduce_taxes` | 市场/街道细节 |
| `forced_march` | 掉队士兵 |
| `battle_victory` | 远处听到炮声的平民 |
| `battle_defeat` | 逃兵经过村庄 |
| `constitutional_promise` | 读报人的反应 |

**参考**:
```json
{
  "forced_march": [
    "一个掉队的步兵在路边坐下，再也没有站起来。",
    "马匹比人先倒下，这让士兵们感到莫名的安慰。"
  ]
}
```

---

## 开发顺序（当前阶段）— ✅ 本轮全部完成

```
① EventPool→GameEngine 集成  ✅ 89 tests 全通过
② .gdextension 配置           ✅
③ balance_notes.md            ✅

并行完成：
④ 司汤达日记文本（8类×5条）  ✅
⑤ 微叙事后果片段（6类×5条）  ✅
```

---

## 优先级 A — ✅ 全部完成（2026-03-19）

### ① 叙事引擎：`narratives` 模块 + `DayReport` ✅

**目标**: 将 `stendhal_diary.json` 和 `consequences.json` 接入引擎。`process_day()` 执行后，可通过 `engine.last_report()` 获取当天叙事文本，Godot UI 直接渲染。

**TDD 测试先行**:
```rust
fn 叙事池加载成功() {
    let pool = NarrativePool::new();
    assert!(pool.stendhal_count("conscription") > 0);
    assert!(pool.consequence_count("conscription") > 0);
}

fn 执行征兵政策后有叙事() {
    let mut engine = GameEngine::new();
    let mut rng = StdRng::seed_from_u64(42);
    engine.process_day(PlayerAction::EnactPolicy { policy_id: "conscription" }, &mut rng);
    let report = engine.last_report().unwrap();
    assert!(report.stendhal.is_some(), "征兵令应有司汤达评论");
    assert!(report.consequence.is_some(), "征兵令应有后果片段");
}

fn 未知动作类型不崩溃() {
    let mut engine = GameEngine::new();
    let mut rng = StdRng::seed_from_u64(42);
    engine.process_day(PlayerAction::Rest, &mut rng);
    // Rest 无叙事，但不应 panic
    let _ = engine.last_report();
}
```

**改动**:
- 新建 `cent-jours-core/src/narratives/mod.rs` — `NarrativePool` 结构体
- 新建 `DayReport { day, stendhal, consequence }` 在 `engine/state.rs`
- `GameEngine` 增加 `narratives: NarrativePool` 和 `last_report: Option<DayReport>` 字段
- `process_day()` 末尾填充 `last_report`
- 暴露 `engine.last_report() -> Option<&DayReport>`

**行动类型 → 叙事 key 映射**:
| PlayerAction | stendhal key | consequence key |
|---|---|---|
| LaunchBattle（胜） | `battle_victory` | `battle_victory` |
| LaunchBattle（败） | `battle_defeat` | `battle_defeat` |
| EnactPolicy `conscription` | `conscription` | `conscription` |
| EnactPolicy `constitutional_promise` | `constitutional_promise` | `constitutional_promise` |
| EnactPolicy `public_speech` | `public_speech` | — |
| EnactPolicy `reduce_taxes` | `reduce_taxes` | `reduce_taxes` |
| BoostLoyalty | `boost_loyalty` | — |
| Rest | — | — |

**文件**: `cent-jours-core/src/narratives/mod.rs`

---

### ② GameEngine GDExtension 节点 ✅

**目标**: 新增 `CentJoursEngine` GDExtension 节点，把 `GameEngine::process_day()` / `last_report()` / `triggered_events()` 等统一暴露给 Godot。

**文件**: `cent-jours-core/src/lib.rs`

---

### ③ Save/Load 序列化 ✅

**目标**: `GameEngine` 实现 `serde::Serialize/Deserialize`，提供 `to_json()` / `from_json()` 方法，支持游戏存档。`EventPool` 的 `triggered_ids` 同步序列化，保证存档读取后事件不重复触发。

---

## 优先级 B — ✅ 全部完成（2026-03-19）

### ④ 扩充 24 个历史事件叙事变体（2-3 → 5 条/事件）✅

所有 24 个事件均已扩展至 5 条叙事。
**文件**: `src/data/events/historical.json`

### ⑤ 新增历史事件（24 → 30 条）✅

新增 6 个关键历史事件：
- `laffrey_confrontation`（拉弗雷峡谷，Day 3-5）✅
- `la_bedoyere_defection`（拉贝多耶尔倒戈，Day 5-8）✅
- `chamber_ultimatum`（众议院最后通牒，Day 90-96）✅
- `napoleon_last_letter_tsar`（致沙皇最后一封信，Day 40-60）✅
- `waterloo_eve_rain`（滑铁卢雨夜，Day 84-86）✅
- `murat_naples_betrayal`（缪拉那不勒斯背叛，Day 30-50）✅

**文件**: `src/data/events/historical.json`

---

## 开发顺序（新一轮）

```
① narratives 模块 + DayReport      ✅ commit + push
② GameEngine GDExtension 节点      ✅ commit + push
③ Save/Load 序列化                  ✅ commit + push

并行完成：
④ 扩充事件叙事变体                  ✅
⑤ 新增历史事件（24→30）             ✅
```

---

## GATE 2 状态：✅ 通过

**核心问题**: "三系统耦合后复杂度是否可控？平衡是否稳定？"

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 三系统独立实现 | ✅ | battle / politics / characters 各有完整测试 |
| 三系统耦合状态机 | ✅ | `engine::state` 16 tests |
| 耦合蒙特卡洛验证 | ✅ | `run_engine_simulation(1000)` < 2s |
| 事件系统集成 | ✅ | 30条历史事件，触发率验证通过 |
| 平衡三策略均在目标范围 | ✅ | 15%-35% 全部满足 |
| Godot 4.6 升级 | ✅ | gdext 0.4.5, api-4-5, VarDictionary |

**结论**: GATE 2 通过。M4 内容填充进行中（82%），目标：完成 GDScript 桥接层后进入 M5。

---

## 已完成技术升级清单（2026-03-19）

| 项目 | 变更 |
|------|------|
| Godot 版本 | 4.3 → **4.6** (`project.godot`) |
| gdext crate | `godot = "0.1"` → **`"0.4"` + `api-4-5`** |
| GDExtension 最低版本 | `compatibility_minimum = "4.6"` |
| API 迁移 | `Dictionary` → `VarDictionary`，`From<Variant>` → `.to::<T>()` |
| 枚举修正 | `Terrain::RiverCrossing` → `RiverJunction`，`BattleOutcome` 字段对齐 |

---

## 优先级 A — 当前轮（无 Godot 可完成）

### ① GDScript 桥接层：turn_manager.gd 接入 CentJoursEngine

**目标**: `turn_manager.gd` 当前只管理回合流程，战斗/政治计算仍在 GDScript 侧（`battle_resolver.gd`、`political_system.gd`）。
应改为调用 `CentJoursEngine` GDExtension 节点，让 Rust 核心作为权威状态源，GDScript 只负责 UI 驱动。

**改动**:
```gdscript
# turn_manager.gd
var engine: CentJoursEngine  # 挂载 GDExtension 节点

func begin_action_phase():
    # 玩家选择行动后：
    engine.process_day_battle(general_id, troops, terrain)
    # 或 engine.process_day_policy(policy_id)
    # 或 engine.process_day_rest()

func _run_dusk_phase():
    var state = engine.get_state()
    var report = engine.get_last_report()
    EventBus.emit_signal("turn_ended", state, report)
```

**文件**: `src/core/turn_manager.gd`

**优先原因**: 这是整个游戏可运行的最后一步胶水代码。完成后，安装 Godot 即可立即运行游戏。

---

### ② 完善占位符 GDScript：political_system.gd

**目标**: 当前 `political_system.gd` 标注为"未完整"——政策定义写了，但 `enact_policy()` 没有接入 `PoliticsEngine` GDExtension 节点的逻辑。

**改动**:
```gdscript
# political_system.gd
var politics_engine: PoliticsEngine  # GDExtension 节点

func enact_policy(policy_id: String) -> Dictionary:
    return politics_engine.enact_policy(policy_id)

func get_state() -> Dictionary:
    return politics_engine.get_state()

func daily_tick():
    politics_engine.daily_tick()
```

**文件**: `src/core/politics/political_system.gd`

---

### ③ 完善占位符 GDScript：order_deviation.gd

**目标**: `order_deviation.gd` 当前是纯 GDScript 实现（`TEMPERAMENT_PROFILES` + 手写计算），应改为调用 `CharacterManager` GDExtension 节点。

**文件**: `src/core/characters/order_deviation.gd`

---

## 优先级 B — 内容扩充（无 Godot 可完成）

### ④ 叙事文本补全：缺失的政策类型

当前 `stendhal_diary.json` 和 `consequences.json` 覆盖 8 种行动类型，但以下政策尚无叙事 key：

| 政策 ID | 当前状态 | 需补充 |
|---------|---------|--------|
| `increase_military_budget` | ❌ 无叙事 | stendhal + consequence |
| `noble_titles` | ❌ 无叙事 | stendhal + consequence |
| `print_money` | ❌ 无叙事 | stendhal + consequence |
| `diplomatic_secret` | ✅ stendhal | ❌ 缺 consequence |

**影响**: 调用这些政策时 `last_report().stendhal` 返回 `None`，UI 会显示空白。

**文件**: `src/data/narratives/stendhal_diary.json` / `consequences.json`
并在 `narratives/mod.rs` 的 `policy_narrative_key()` 补充映射。

---

### ⑤ 历史事件叙事文本扩充（30 条 × 剩余变体）

`historical.json` 中有 30 条事件，每条有 2-5 条叙事。部分早期事件（M1 时写的）只有 2 条变体，建议扩展至 5 条以减少重复感。

**优先扩充**: `elba_escape`、`grenoble_arrival`、`paris_entry`（最常触发的早期事件）

**文件**: `src/data/events/historical.json`

---

## 优先级 C — 需要 Godot 环境

| 任务 | 描述 | 阻塞原因 |
|------|------|---------|
| UI 场景文件 | `main_menu.tscn`, `game_screen.tscn`, `map_view.tscn` | 需要 Godot 编辑器 |
| `decision_card.gd` 完整实现 | 卡片 UI 组件（`decision_card.gd` 当前为占位符） | 需要可见 UI 布局 |
| Rouge/Noir 滑块动画 | `rn_slider.gd` 动画效果 | 需要 Godot 预览 |
| GDExtension 集成测试 | 加载 `.so`/`.dll`，验证 GDExtension 节点注册 | 需要 Godot 运行环境 |
| M5 美术资源 | 地图美术、人物立绘、UI 主题 | 需要 Godot + 美术工具 |

---

## 开发顺序（v7 轮）✅ 全部完成（2026-03-19）

```
① turn_manager.gd 接入 CentJoursEngine    ✅
② political_system.gd 精简为展示层        ✅
③ order_deviation.gd 改为 CharacterManager 代理  ✅

并行：
④ 补全 4 个政策叙事文本（grant_titles/increase_military_budget/print_money/secret_diplomacy） ✅
⑤ 历史事件叙事 2→5 条（已提前完成，无需补充） ✅
```

---

## 优先级 A — 当前轮（⚠️ 含阻塞性 Bug，无 Godot 可完成）

### ① game_state.gd 补充缺失字段 ⚠️ 阻塞性

**问题**: `turn_manager.gd` v2 的 `_sync_state_from_engine()` 写入了 4 个 `GameState` 中不存在的字段：

```gdscript
GameState.total_troops  # ❌ 未声明
GameState.avg_morale    # ❌ 未声明
GameState.avg_fatigue   # ❌ 未声明
GameState.victories     # ❌ 未声明
```

**影响**: 安装 Godot 后第一次运行即报错崩溃。

**修复**（在 `game_state.gd` `# ── 行军与战役状态` 区块追加）:
```gdscript
# 军队摘要（从 CentJoursEngine 同步，只读）
var total_troops: int   = 6000   # 当前总兵力
var avg_morale:   float = 70.0   # 平均士气
var avg_fatigue:  float = 20.0   # 平均疲劳
var victories:    int   = 0      # 战役胜利次数
```

**文件**: `src/core/game_state.gd`

---

### ② 存档系统 GDScript 接口

**目标**: 新建 `src/core/save_manager.gd`，封装 `CentJoursEngine.to_json()` / `from_json()` 与 Godot `FileAccess` 的交互，实现游戏存读档。

**接口设计**:
```gdscript
class_name SaveManager
extends Node

const SAVE_PATH := "user://cent_jours_save.json"

## 存档：调用 Rust 引擎序列化，写入磁盘
static func save_game(engine: CentJoursEngine) -> bool:
    var json_str: String = engine.to_json()
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if not file: return false
    file.store_string(json_str)
    return true

## 读档：从磁盘加载，调用 Rust 引擎反序列化，返回是否成功
static func load_game(engine: CentJoursEngine) -> bool:
    if not FileAccess.file_exists(SAVE_PATH): return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file: return false
    return engine.load_from_json(file.get_as_text())

static func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
    DirAccess.remove_absolute(SAVE_PATH)
```

**注意**: Rust `CentJoursEngine` 需要暴露 `load_from_json(json: GString) -> bool`，当前只有 `to_json()`，需在 `lib.rs` 补充该方法。

**文件**: `src/core/save_manager.gd` + `cent-jours-core/src/lib.rs`

---

### ③ lib.rs 补充 `load_from_json` GDExtension 方法

**目标**: `CentJoursEngine` 当前只有 `to_json() -> GString`，缺少 `load_from_json(GString) -> bool`，存档系统无法完成读档。

**改动** (在 `lib.rs` 的 `CentJoursEngine` impl 中追加):
```rust
/// 从 JSON 字符串恢复引擎状态（读档）
/// 成功返回 true，JSON 解析失败返回 false
#[func]
pub fn load_from_json(&mut self, json: GString) -> bool {
    match crate::engine::GameEngine::from_json(json.to_string().as_str()) {
        Ok(engine) => {
            self.engine = engine;
            true
        }
        Err(_) => false,
    }
}
```

**文件**: `cent-jours-core/src/lib.rs`

---

## 优先级 B — 当前轮（无 Godot 可完成）

### ④ character_manager.gd 精简

**目标**: `character_manager.gd` 当前有约 175 行，包含命令偏差计算、忠诚度网络、历史事件触发等自有实现——这些现在全由 `CentJoursEngine` 内部处理。精简为状态展示层（类似 `political_system.gd` v2 的思路）。

**保留**: `get_at_risk_characters()`、`get_available_commanders()`（UI 用）

**移除**: 命令偏差计算（已由 `CharacterManager` GDExtension 处理）、`process_orders_with_deviation()`（已由 `turn_manager.gd` v2 通过 engine 处理）

**文件**: `src/core/characters/character_manager.gd`

---

### ⑤ march_system.gd 与 battle_resolver.gd 标记与精简

**现状**: 两个文件仍有完整的 GDScript 侧计算实现，但执行路径已被 `CentJoursEngine` 取代。

**行动**:
- `march_system.gd`：保留 `find_path()` / `get_distance()` 等地图查询方法（供地图 UI 渲染路径使用），移除 `move_army()` / `update_supply()` 执行方法
- `battle_resolver.gd`：添加文件头注释说明该文件已被 `CentJoursEngine` 取代，保留作为文档参考，实际不再调用

**文件**: `src/core/campaign/march_system.gd`、`src/core/campaign/battle_resolver.gd`

---

## 优先级 C — 需要 Godot 环境

| 任务 | 描述 | 阻塞原因 |
|------|------|---------|
| UI 场景文件 | `main_menu.tscn`, `game_screen.tscn`, `map_view.tscn` | 需要 Godot 编辑器 |
| `decision_card.gd` 完整实现 | 卡片 UI 组件 | 需要可见 UI 布局 |
| Rouge/Noir 滑块动画 | `rn_slider.gd` 动画效果 | 需要 Godot 预览 |
| GDExtension 集成测试 | 验证 4 个 GDExtension 节点正确注册 | 需要 Godot 运行环境 |
| CentJoursEngine 节点挂载 | 在场景树中创建节点并连接到 TurnManager | 需要 Godot 编辑器 |
| M5 美术资源 | 地图美术、人物立绘、UI 主题 | 需要 Godot + 美术工具 |

---

## 开发顺序（当前轮）

```
① game_state.gd 补充字段         ← ⚠️ 最高优先，修复阻塞性 Bug
② lib.rs 补充 load_from_json     ← 存档读档闭环（Rust，15分钟）
③ save_manager.gd 新建           ← 配合②，完成存档系统

并行：
④ character_manager.gd 精简      ← 移除冗余逻辑
⑤ march_system.gd 精简           ← 保留地图查询，移除执行逻辑
```

**完成 ①②③ 后，M4 进度将达到 100%**，等待 Godot 环境进行集成测试后进入 M5。

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
