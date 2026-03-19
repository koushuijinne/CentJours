# Cent Jours — 开发优先级计划

> **更新**: 2026-03-19 v10
> **当前分支**: `claude/review-project-plan-LKKTR`

---

## 开发原则

> **测试驱动开发（TDD）**
>
> 所有 Rust 模块遵循严格 TDD 流程：
> 1. **Red** — 先写失败的单元测试，明确输入/输出契约
> 2. **Green** — 写最少实现代码使测试通过
> 3. **Refactor** — 在测试保护下重构，不破坏已有行为
>
> - 禁止在没有对应测试的情况下提交业务逻辑
> - `cargo test` 全通过才能提交

> **小步提交推送**
>
> 每完成一个独立小功能立即 commit + push：
> - 格式：`feat(模块): 描述` / `fix(模块): 描述` / `data: 描述`
> - 永远不要积累"大提交"

> **文档同步更新**
>
> - 完成任务后立即更新本文档状态（✅/🔶）和进度快照
> - 原则：文档反映当前真实状态，而非计划状态
> - **已完成的轮次内容定期清除**，只保留当前优先级和模块清单

> **GDScript 薄层原则**
>
> GDScript 层不包含任何业务逻辑，只负责：
> - 调用 `CentJoursEngine` GDExtension 节点执行行动
> - 读取引擎状态并发射 `EventBus` 信号驱动 UI
> - 提供 UI 展示所需的静态元数据（政策名称、描述等）
>
> 判断标准：如果一段 GDScript 在没有 Godot UI 时仍然"有意义"，它就不应该在 GDScript 里。

> **单一引擎状态源**
>
> `GameState` 单例中的所有运行时数值，必须从 `CentJoursEngine.get_state()` 同步，
> 不自行维护平行计算逻辑。`GameState` 是 UI 的只读缓存，不是第二个游戏引擎。

---

## 当前进度快照（2026-03-19）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ██████████░░  85% 🔶 Rust层✅，EventPool集成✅，Godot待安装
M2  政治系统   ███████████░  90% ✅ Rust层✅，平衡达标，UI待Godot
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████████ 100% GDScript桥接层✅，叙事全覆盖✅，存档系统✅，GDScript精简✅
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

## 优先级 A — 当前轮（⚠️ 含阻塞性 Bug）

### ① game_state.gd 补充缺失字段 ⚠️

`turn_manager.gd` v2 的 `_sync_state_from_engine()` 写入了 4 个未声明的字段，装上 Godot 即崩溃：

```gdscript
# 需追加到 game_state.gd「行军与战役状态」区块
var total_troops: int   = 6000   # 从 CentJoursEngine 同步
var avg_morale:   float = 70.0
var avg_fatigue:  float = 20.0
var victories:    int   = 0
```

**文件**: `src/core/game_state.gd`

---

### ② lib.rs 补充 `load_from_json` GDExtension 方法

`CentJoursEngine` 有 `to_json()` 但缺 `load_from_json()`，存档读取无法闭环。

```rust
#[func]
pub fn load_from_json(&mut self, json: GString) -> bool {
    match crate::engine::GameEngine::from_json(json.to_string().as_str()) {
        Ok(engine) => { self.engine = engine; true }
        Err(_) => false,
    }
}
```

**文件**: `cent-jours-core/src/lib.rs`

---

### ③ 新建 save_manager.gd

封装 `CentJoursEngine.to_json()` / `load_from_json()` 与 `FileAccess` 的交互，实现存读档。

**文件**: `src/core/save_manager.gd`（新建）

---

## 优先级 B — 当前轮

### ④ character_manager.gd 精简

当前 175 行含命令偏差计算、忠诚度网络等已被 engine 接管的逻辑。精简为：
- **保留**: `get_at_risk_characters()`、`get_available_commanders()`（UI查询）
- **移除**: `process_orders_with_deviation()`、手写偏差计算

**文件**: `src/core/characters/character_manager.gd`

---

### ⑤ march_system.gd 精简

执行路径已被 engine 取代。精简为：
- **保留**: `find_path()`、`get_distance()`（地图UI路径渲染用）
- **移除**: `move_army()`、`update_supply()`、`rest_army()` 执行方法

**文件**: `src/core/campaign/march_system.gd`

---

## 优先级 C — 需要 Godot 环境

| 任务 | 阻塞原因 |
|------|---------|
| UI 场景文件（.tscn） | 需要 Godot 编辑器 |
| CentJoursEngine 节点挂载到场景树 | 需要 Godot 编辑器 |
| GDExtension 集成测试 | 需要 Godot 运行环境 |
| `decision_card.gd` 完整实现 | 需要可见 UI 布局 |
| M5 美术资源 | 需要 Godot + 美术工具 |

---

## 开发顺序（当前轮）

```
① game_state.gd 补充字段     ← ⚠️ 修复阻塞 Bug，5 分钟
② lib.rs load_from_json      ← Rust，15 分钟，存档读取闭环
③ save_manager.gd 新建       ← GDScript，配合②

并行：
④ character_manager.gd 精简
⑤ march_system.gd 精简
```

**完成 ①②③ = M4 100%**，等待 Godot 环境进入 M5。

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
