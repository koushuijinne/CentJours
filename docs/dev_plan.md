# Cent Jours — 开发优先级计划

> **更新**: 2026-03-18 v4
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

## 当前进度快照（2026-03-18）

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ██████████░░  85% 🔶 Rust层✅，EventPool集成✅，Godot待安装
M2  政治系统   ███████████░  90% ✅ Rust层✅，平衡达标，UI待Godot
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████░░░░  65% 事件池24条✅，叙事文本✅(stendhal+consequences)，叙事引擎0%
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**89/89 单元测试全部通过**（最后运行：2026-03-18）

**平衡结果（不变）**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅

**约束**: 暂无 Godot 运行环境。以下所有任务均为纯 Rust 或 JSON/数据工作。

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 7 | ✅ |
| 行军系统 | `battle/march.rs` | 6 | ✅ |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 23 | ✅ 含from_json |
| 三系统状态机 | `engine/state.rs` | 16 | ✅ 含EventPool集成 3新测试 |
| 历史事件池 | `events/pool.rs` | 13 | ✅ 24条事件 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 | ✅ 已简化（EventPool内嵌） |
| GDExtension绑定 | `lib.rs` | — | ✅ |

**合计**: 89 tests | 全部通过

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

**下一轮待开发**:
- 叙事引擎：将 stendhal_diary / consequences 接入 GameEngine，process_day 后返回叙事文本
- M4 剩余：更多事件文本变体（当前24条事件各只有3条叙事）
- 待 Godot 安装后：GDExtension 集成测试、UI 接入

---

## GATE 2 状态：✅ 通过

**核心问题**: "三系统耦合后复杂度是否可控？平衡是否稳定？"

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 三系统独立实现 | ✅ | battle / politics / characters 各有完整测试 |
| 三系统耦合状态机 | ✅ | `engine::state` 13 tests |
| 耦合蒙特卡洛验证 | ✅ | `run_engine_simulation(1000)` < 2s |
| 事件系统集成 | ✅ | 24条历史事件，触发率验证通过 |
| 平衡三策略均在目标范围 | ✅ | 15%-35% 全部满足 |

**结论**: GATE 2 通过。下一里程碑为 M4 内容填充，目标完成度 100%（当前 30%）。

---

*「在战争中，只有一件事是确定的：任何事都不确定。」— 拿破仑*
