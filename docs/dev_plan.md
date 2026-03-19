# Cent Jours — 开发优先级计划

> **更新**: 2026-03-19 v11
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

> **完成大任务后立即更新 plan.md**
>
> 每完成一个里程碑（M 级）或大型功能组，立即：
> - 清理本文档中已完成的优先级条目（不留"已完成"占位行）
> - 重新扫描代码库，发现新的技术债或不一致
> - 重排剩余任务优先级，确保 A 组始终是"现在就能做"的最高价值任务
>
> 判断标准：plan.md 超过一个工作轮次没有更新，说明流程出了问题。

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
M2  政治系统   ███████████░  90% 🔶 Rust层✅，平衡达标，UI待Godot
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████████ 100% ✅ GDScript桥接层✅，叙事全覆盖✅，存档系统✅，GDScript精简✅
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

## 优先级 A — 当前轮（无需 Godot 环境）

### ① battle_resolver.gd 精简 ⚠️ 违反薄层原则

`battle_resolver.gd` 包含完整的战斗解算逻辑（130+ 行），与 Rust `BattleEngine` 完全重复，
严重违反 GDScript 薄层原则。

**目标**：精简为仅保留地形常量映射和辅助展示方法，战斗解算代理给 `BattleEngine`：

```gdscript
# 保留：地形字符串→显示名映射（UI Tooltip用）
const TERRAIN_DISPLAY_NAMES := { "plains": "平原", "hills": "山地", ... }

# 移除：_calculate_force_score(), _ratio_to_result(),
#        _calculate_casualties(), _calculate_morale_impact()
#        resolve() 整个解算方法
```

**文件**: `src/core/campaign/battle_resolver.gd`

---

### ② game_state.gd 清理平行计算方法 ⚠️ 违反单一状态源原则

`GameState` 中以下方法在 GDScript 层维护独立计算逻辑，与引擎状态源冲突：

- `recalculate_legitimacy()` — 合法性已由 `CentJoursEngine.get_state()["legitimacy"]` 提供
- `modify_faction_support()` — 派系支持不能直接从 GDScript 修改，应通过 engine action 驱动
- `shift_rouge_noir()` — rouge_noir 由引擎决定，GDScript 不应直接写入

**目标**：将上述方法替换为只读的同步入口，删除直接修改逻辑。

**文件**: `src/core/game_state.gd`

---

### ③ CentJoursEngine 暴露将领忠诚度查询

当前 `get_state()` 只返回聚合军队数据，不含各将领忠诚度。
`GameState.characters` 中的 `loyalty` 字段在游戏运行时从不更新，会与引擎内部状态漂移。

**目标**：在 `lib.rs` 中新增：

```rust
#[func]
pub fn get_character_loyalty(&self, character_id: GString) -> f64 {
    self.engine.get_loyalty(character_id.to_string().as_str())
        .unwrap_or(50.0)
}

#[func]
pub fn get_all_loyalties(&self) -> Dictionary {
    // 返回 { character_id: loyalty_f64, ... }
}
```

同时确认 `GameEngine` 有对应的 `get_loyalty()` 方法（或新增）。

**文件**: `cent-jours-core/src/lib.rs` + `cent-jours-core/src/engine/`

---

### ④ turn_manager.gd 补充 character loyalty 同步

在 `_sync_state_from_engine()` 中，通过 `engine.get_all_loyalties()` 更新
`GameState.characters[id]["loyalty"]`，确保 UI 显示的忠诚度与引擎一致。

依赖 ③ 完成。

**文件**: `src/core/turn_manager.gd`

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

## 开发顺序（当前轮）

```
① battle_resolver.gd 精简     ← GDScript，薄层违规修复，独立可做
② game_state.gd 清理          ← GDScript，状态源违规修复，独立可做

③ lib.rs get_character_loyalty ← Rust，需先确认 engine 层接口
④ turn_manager.gd loyalty 同步 ← GDScript，依赖 ③
```

**完成 ①②③④ → GDScript 层完全合规，角色状态闭环。**
届时进入 GATE 3 检查（等待 Godot 环境）。

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
