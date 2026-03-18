# Cent Jours — 开发优先级计划

> **更新**: 2026-03-18
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

## 当前进度快照

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ████████░░░░  65% 🔶 Rust层✅，Godot集成待安装
M2  政治系统   ████████░░░░  70% 🔶 Rust层✅，UI待，平衡调试待
M3  将领网络   ██████░░░░░░  50% 🔶 命令偏差✅，关系网络/耦合待
M4  内容填充   ░░░░░░░░░░░░   0%
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**约束**: 暂无 Godot 运行环境。以下所有任务均为纯 Rust，`cargo test` 可验证。

---

## 优先级 A — 推进里程碑（立即开发）

### ① `characters::network` — 将领关系图 【M3核心】

**目标**: 动态将领关系矩阵，支持忠诚度更新和历史事件触发

**测试先行**:
```rust
// 内伊倒戈：loyalty<30 且 napoleon_bond>60 → 触发倒戈事件
assert!(network.can_defect_to_napoleon("ney"));

// 战胜提升忠诚度
network.apply_battle_outcome("ney", BattleResult::MarginalVictory);
assert!(network.loyalty("ney") > initial_loyalty);

// 关系衰减：长时间无互动
network.tick_day();
assert!(network.relationship("ney", "grouchy") <= initial_bond);
```

**数据结构**:
```
CharacterNetwork {
    generals: HashMap<String, GeneralData>       // 来自 characters.json
    relationships: HashMap<(String,String), f64> // 双向关系强度 -100..100
    loyalty_history: Vec<(u32, String, f64)>     // (day, id, delta) 审计日志
}
```

**文件**: `cent-jours-core/src/characters/network.rs`

---

### ② `engine::state` — 三系统耦合状态机 【M3/GATE2核心】

**目标**: 统一持有 battle + politics + characters，按回合驱动三系统

**测试先行**:
```rust
// 战胜应同时提升军方支持和相关将领忠诚
let mut engine = GameEngine::default();
engine.process_battle_victory("ney", BattleResult::MarginalVictory);
assert!(engine.politics.faction_support["military"] > 50.0);
assert!(engine.characters.loyalty("ney") > 65.0);

// 政治崩溃应触发游戏结束事件
engine.politics.rouge_noir_index = -80.0; // 极端Noir
engine.process_day(42);
assert!(engine.outcome() == Some(GameOutcome::PoliticalCollapse));
```

**文件**: `cent-jours-core/src/engine/state.rs` + `mod.rs`

---

### ③ `events::pool` — JSON驱动历史事件池 【M3/M4衔接】

**目标**: 100天事件池，按条件触发，支持叙事文本变体

**事件 JSON 结构**:
```json
{
  "id": "ney_defection",
  "day_range": [5, 7],
  "trigger": {
    "napoleon_reputation": { "min": 60 },
    "ney_loyalty": { "max": 40 },
    "ney_relationship_napoleon": { "min": 55 }
  },
  "effects": {
    "ney_loyalty": "+35",
    "military_support": "+10",
    "nobility_support": "-15"
  },
  "narratives": [
    "内伊在路边停住马，望着山坡上那面熟悉的鹰旗，久久无语。",
    "「皇帝」——他低声说，就好像这个词本身就能解释一切。"
  ]
}
```

**文件**:
- `src/data/events/historical.json` — 历史触发事件（Ney倒戈、Grouchy追击等）
- `cent-jours-core/src/events/pool.rs` — Rust 加载器 + 触发器

---

### ④ 平衡调试 — 修复3个已知问题 【M2收尾】

详见 `docs/balance_notes.md`。修复目标：三种策略胜率均落入 **15%–35%**。

| 问题 | 当前 | 目标 | 调整方向 |
|------|------|------|----------|
| 军事策略惩罚过重 | ~0% 胜率 | 15-25% | 降低敌军扩张速度，增加战胜奖励 |
| 政治/平衡策略 100% 胜率 | 100% | 20-35% | 强化外交压力，增加后期随机危机 |
| 滑铁卢无特殊规则 | 确定性结果 | 随机结果 | Day 80+ 触发联军会师加速机制 |

---

## 优先级 B — 内容积累（并行可做）

### ⑤ 司汤达日记文本池
`src/data/narratives/stendhal_diary.json`
- 为每类决策预生成 5 个文体变体（冷峻 / 讽刺 / 心理分析）
- 可用 Claude API 批量生成初稿，人工审核历史准确性

### ⑥ 微叙事后果片段
`src/data/narratives/consequences.json`
- 每种政策/行动 20-30 个普通人视角片段（2-3句）

### ⑦ `.gdextension` 配置文件
Godot 识别 Rust 插件的描述符，写好后安装 Godot 即可直接调用：
```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = "4.1"

[libraries]
linux.debug.x86_64 = "res://cent-jours-core/target/debug/libcent_jours_core.so"
linux.release.x86_64 = "res://cent-jours-core/target/release/libcent_jours_core.so"
```

---

## 开发顺序建议

```
① network (3-4h) → ② engine::state (4-5h) → ④ balance (2h) → ③ events (4-5h)
                                ↓
                    GATE 2 验收：三系统蒙特卡洛 <5s/1000局
```

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
