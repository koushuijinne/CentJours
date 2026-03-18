# Cent Jours — 开发优先级计划

> **更新**: 2026-03-18 v2
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

---

## 当前进度快照（2026-03-18）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   █████████░░░  75% 🔶 Rust层✅，Godot集成待安装
M2  政治系统   ███████████░  90% ✅ Rust层✅，平衡达标，UI待Godot
M3  将领网络   ██████████░░  85% 🔶 三系统Rust✅，MC验证+数据集成待
M4  内容填充   ██░░░░░░░░░░  10% 事件池7条，叙事文本0
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**78/78 单元测试全部通过**
**平衡结果**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅（目标15-35%）

**约束**: 暂无 Godot 运行环境。以下所有任务均为纯 Rust 或 JSON/数据工作。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 7 | ✅ |
| 行军系统 | `battle/march.rs` | 6 | ✅ |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 19 | ✅ |
| 三系统状态机 | `engine/state.rs` | 13 | ✅ |
| 历史事件池 | `events/pool.rs` | 13 | ✅ |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 4 | ✅ |
| GDExtension绑定 | `lib.rs` | — | ✅ |

---

## 优先级 A — 推进里程碑（立即开发）

### ① GATE 2 验收：三系统耦合蒙特卡洛 【M3收尾，最高优先级】

**目标**: 用 `GameEngine`（三系统耦合）代替简化的 `simulate_one_game` 跑蒙特卡洛，验证完整系统在1000局内稳定。

**为什么**: `simulation::monte_carlo` 当前使用的是平行但分离的系统，`engine::state` 耦合版本尚未做大规模验证。这是 GATE 2 的核心检查点。

**测试先行**:
```rust
// engine集成蒙特卡洛：1000局不崩溃
fn 三系统耦合1000局不崩溃() {
    let report = run_engine_simulation(1000, 42);
    let total: u32 = report.outcomes.values().sum();
    assert_eq!(total, 1000);
}

// 事件触发率合理：内伊倒戈应在10-40%游戏中触发
fn 内伊倒戈触发率合理() {
    let report = run_engine_simulation(500, 2026);
    let ney_rate = report.event_trigger_rates["ney_defection"];
    assert!(ney_rate >= 0.10 && ney_rate <= 0.50);
}
```

**文件**: `cent-jours-core/src/simulation/monte_carlo.rs` 新增 `run_engine_simulation()`

---

### ② characters.json → CharacterNetwork 数据集成 【M3收尾】

**目标**: 将 `src/data/characters.json`（已有15个历史人物数据）加载进 `CharacterNetwork`，替换当前 `historical_network_day1()` 的硬编码初始状态。

**为什么**: 数据和逻辑应该分离。现在 network.rs 的初始值是硬编码常量，未来调整人物属性需要改 Rust 代码重新编译，而不是改 JSON。

**接口设计**:
```rust
// 从 characters.json 构建网络
impl CharacterNetwork {
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error>;
    pub fn historical_day1() -> Self {
        Self::from_json(include_str!("../../../src/data/characters.json")).unwrap()
    }
}
```

**文件**: `cent-jours-core/src/characters/network.rs` + `src/data/characters.json` 补全关系数据

---

### ③ 扩展历史事件池 【M3/M4衔接，高价值】

**目标**: 当前 `historical.json` 只有 7 个事件，覆盖约 15 个关键天数。需要扩展到 **25-35 个事件**，覆盖完整100天叙事骨架。

**为什么**: EventPool 系统已经完善，但内容极少。这是纯 JSON 工作，不需要改 Rust，投入产出比极高——每增加一个事件就增加一条游戏叙事线。

**待添加事件（历史依据）**:

| 事件 ID | 日期范围 | 触发条件 | 历史背景 |
|---------|---------|---------|---------|
| `return_to_paris` | Day 20-22 | `napoleon_reputation_min: 65` | 进入巴黎，路易十八出逃 |
| `additional_act` | Day 25-35 | `rouge_noir_index_max: 20` | 颁布补充法案，承诺宪政 |
| `congress_vienna_ultimatum` | Day 12-15 | — | 维也纳会议宣布拿破仑为公敌 |
| `davout_war_minister` | Day 22-28 | `davout_loyalty_min: 75` | 达武任战争部长 |
| `soult_chief_of_staff` | Day 25-30 | — | 苏尔特任参谋长（争议任命） |
| `elba_veterans_rejoin` | Day 10-15 | — | 厄尔巴岛老兵陆续归队 |
| `quatre_bras` | Day 83-85 | `day_min: 83` | 四臂村战役，内伊表现争议 |
| `wellington_position` | Day 88-92 | — | 威灵顿占据圣让山脊防线 |
| `prussian_regroup` | Day 85-88 | — | 布吕歇尔在利尼后重整旗鼓 |
| `imperial_guard_elite` | Day 40-50 | `military_support_min: 65` | 老近卫军重建完成 |
| `royalist_uprising` | Day 30-50 | `rouge_noir_index_max: -30` | 旺代保皇派动乱威胁 |
| `british_subsidies` | Day 15-25 | — | 英国向普奥提供资助加速集结 |

**文件**: `src/data/events/historical.json`

---

## 优先级 B — 内容积累（并行可做）

### ④ 司汤达日记文本池

**文件**: `src/data/narratives/stendhal_diary.json`

为以下决策类型各预生成 5 个文本变体（冷峻/讽刺/心理分析风格）：

```json
{
  "conscription": [
    "他今天又签了一道征兵令。他的笔迹很漂亮——即便是在做这种事的时候。",
    "征兵令。士兵们的父亲会读报纸吗？不，但他们的妻子会。"
  ],
  "constitutional_promise": [...],
  "public_speech": [...],
  "battle_victory": [...],
  "battle_defeat": [...]
}
```

### ⑤ 微叙事后果片段

**文件**: `src/data/narratives/consequences.json`

每种政策/事件后，弹出一段普通人视角（2-3句）：

```json
{
  "conscription": [
    "里昂郊外，一个面包师的妻子目送第三个儿子走向集结点。",
    "征兵官在诺曼底记录了一个哑巴的名字。他不会说话，但他会走路。"
  ]
}
```

### ⑥ `.gdextension` 配置文件

Godot 识别 Rust 插件的描述符，写好后安装 Godot 即可直接测试：

**文件**: `cent-jours-core/cent_jours_core.gdextension`

```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = "4.1"

[libraries]
linux.debug.x86_64 = "res://cent-jours-core/target/debug/libcent_jours_core.so"
linux.release.x86_64 = "res://cent-jours-core/target/release/libcent_jours_core.so"
windows.debug.x86_64 = "res://cent-jours-core/target/debug/cent_jours_core.dll"
windows.release.x86_64 = "res://cent-jours-core/target/release/cent_jours_core.dll"
```

---

## 优先级 C — M4 准备（内容填充阶段前置工作）

### ⑦ EventPool → GameEngine 集成

将 `events::pool` 接入 `engine::state`：`process_day()` 每天调用 `event_pool.trigger_all(ctx)`，将事件效果应用到三系统。

**文件**: `cent-jours-core/src/engine/state.rs`

### ⑧ balance_notes.md 更新

记录最终平衡参数，方便 M6 调参时回查：
- 决战联军公式：`70_000 + cs * 1_400`
- 胜利条件：`victories >= 5 AND legit >= 45`
- 即时胜利触发：决战胜 + victories >= 5 → 立即结算

**文件**: `docs/balance_notes.md`

---

## 开发顺序建议

```
① 耦合MC验证 (3-4h)
        ↓
② characters.json集成 (2-3h)
        ↓
③ 扩展事件池到25条 (3-4h，纯JSON)
        ↓
⑦ EventPool → GameEngine集成 (2-3h)
        ↓
    GATE 2 完整验收：
    三系统+事件池 蒙特卡洛 <5s/1000局 ✅

然后并行：
④ 司汤达日记 + ⑤ 微叙事（纯文本，随时可做）
⑥ .gdextension（30min，等Godot安装前准备好）
⑧ balance_notes.md（文档，30min）
```

---

## 离 GATE 2 还差什么

GATE 2 核心问题：**"三系统耦合后复杂度是否可控？平衡是否稳定？"**

Rust 层已经满足条件：
- ✅ battle + politics + characters 三系统有独立实现和测试
- ✅ `engine::state` 实现三系统耦合状态机（13 tests）
- ✅ 蒙特卡洛平衡验证机制存在（78 tests 全通过）
- ⬜ **缺**: 用完整 GameEngine（含事件系统）跑耦合蒙特卡洛

完成① + ② + ③ + ⑦ 后，GATE 2 Rust 层可宣告通过。

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
