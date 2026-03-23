# Cent Jours — 开发优先级计划

> **更新**: 2026-03-23 v45
> **通用原则**: 项目长期稳定原则详见 `docs/development_principles.md`
> **快速接手**: 当前状态见 `docs/codex_handoff.md`，新会话首条 prompt 模板见 `docs/codex_session_prompts.md`

---

## 开发原则

> 项目级完整原则以 `docs/development_principles.md` 为准。本文只保留当前轮次直接相关的默认原则。

- `核心循环优先`：新功能优先服务 Dawn / Action / Dusk 主循环
- `TDD`：Rust 规则层改动默认先补测试
- `单一状态源`：引擎是真实状态，`GameState` 只做 UI 只读缓存
- `GDScript 薄层`：Godot 脚本负责桥接、展示、信号，不复制核心规则
- `数据驱动设计`：角色、事件、地图、平衡参数优先外置
- `先骨架后润色`：优先完成信息架构与交互流向，再做视觉打磨
- `组件复用优先`：优先复用 `rn_slider.gd`、`decision_card.gd`、主题系统
- `视觉以真机收口`：Windows Godot `1280x720` 是前端布局的默认收口标准

### 文档与提交流程

- `活文档`：完成任务后立即更新本文档状态（✅/🔶）和进度快照
- `交接同步`：完成一轮后同步更新 `docs/codex_handoff.md`
- `同提交同步`：文档更新与代码变更放在同一次 commit
- `小步提交`：每完成一个独立功能立即 commit + push
- `ADR`：跨层接口、状态流、重要架构选型沉淀到 `docs/decisions/ADR-XXX.md`
- `边界契约`：Rust ↔ GDScript 的 `Dictionary` / `Array` 返回结构要写清键名和语义

### 提交前强制检查

> ⚠️ 前两步是**阻塞条件**——不完成就不能 commit。

1. **🔴 删除已完成内容**：已完成的 Tier/任务描述、已解决的阻塞点、过时的上下文——直接删除（git log 追溯）
2. **🔴 制定下一轮优先级**：扫描代码库后写出下一轮待办，每个待办项必须附一句话决策理由
3. 将已完成项标记 ✅ 并移入模块清单
4. 更新进度快照（Rust 层 + 前端层）和 `docs/codex_handoff.md`
5. 重新扫描代码库，记录新出现的技术债
6. 文档更新与代码放入同一次 commit

### 验证规则

- Rust 改动：`cargo test` 全部通过才能提交
- GDScript 改动：无 Godot 环境时肉眼检查语法
- commit message 格式：`feat/fix/refactor/docs(模块): 描述`

---

## 进度快照

### Rust/架构层

```
M0–M4  ████████████ 100% ✅  Tier 0–3 全部完成
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**143 单元测试全部通过** | **平衡**: Military 24.2% | Political 21.2% | Balanced 22.4%

### 前端层

```
F0–F4  ████████████  95-100% ✅
F5     ████████░░░░  55% 🔶  视觉统一与动效
```

### 当前阻塞点

- `main_menu.gd` 543 行，仍混有回合流 + HUD 刷新 + 弹窗状态组装（第五波解耦候选）
- F5 视觉：托盘双滚动未修复、中英混排未统一、动效无框架（ad-hoc flash）

### 技术债

- Rust 全局 53 处 `unwrap()`/`expect()`/`panic!()`（集中在 `events/pool.rs` 24 处、`state.rs` 9 处）
- 嵌套 Dictionary 子键缺 per-key 文档（如 `factions` 子结构）

---

## 已完成模块清单

| 模块 | 文件 | 测试数 |
|------|------|--------|
| 战斗解算 | `battle/resolver.rs` | 12 |
| 行军系统 | `battle/march.rs` | 10 |
| 政治系统 | `politics/system.rs` | 8 |
| 命令偏差 | `characters/order_deviation.rs` | 6 |
| 将领关系网络 | `characters/network.rs` | 27+4 |
| 三系统状态机 | `engine/state.rs` | 24 |
| 历史事件池 | `events/pool.rs` | 16 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 |
| 叙事引擎 | `narratives/mod.rs` | 10 |
| GDExtension | `lib.rs` | — |
| Save/Load | `engine/state.rs` + `main_menu.gd` | — |

**合计**: 143 tests

---

## 下一轮优先级（Tier 4 — 内容与打磨）

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|---------|
| **P1** | **历史事件扩充 33→100+** | L | 当前 33 条仅覆盖目标 11%（300–500 条），是产品可玩性最大瓶颈；事件池是纯 JSON 数据，不涉及架构变更，风险极低 |
| **P2** | **F5 视觉统一** | M | 托盘双滚动 + 中英混排是用户可感知的最直接问题；55%→80% 可显著提升第一印象 |
| **P3** | **main_menu.gd 第五波解耦** | M | 543 行超阈值，回合流/HUD 刷新混在编排器里增加改动风险；但不阻塞功能，排在视觉后面 |
| **P4** | **Rust unwrap 清理** | S | 53 处 unwrap 是长期债务，不影响功能但降低健壮性；逐文件替换为 Result 传播，可穿插在其他任务间完成 |

### 不在本轮范围

- M5 美术资源替换（emoji → 真实纹理）
- M6 BGM/音效
- 多语言 / 多存档槽 / Steam 集成 / 教程
