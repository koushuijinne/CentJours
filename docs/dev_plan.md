# Cent Jours — 开发优先级计划

> **更新**: 2026-03-23 v42
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

1. 将已完成项标记 ✅ 并移入模块清单
2. 更新进度快照（Rust 层 + 前端层）和 `docs/codex_handoff.md`
3. 重新扫描代码库，记录新出现的技术债
4. 重排下一轮优先级
5. 文档更新与代码放入同一次 commit

### 验证规则

- Rust 改动：`cargo test` 全部通过才能提交
- GDScript 改动：无 Godot 环境时肉眼检查语法
- commit message 格式：`feat/fix/refactor/docs(模块): 描述`

---

## Rust/架构层进度快照

```
M0  预研      ████████████ 100% ✅
M0.5 视觉定调  ████████████ 100% ✅
M1  核心循环   ████████████ 100% ✅ Rust层✅，Godot端到端回合闭环✅
M2  政治系统   ███████████░  90% 🔶 Rust层✅，平衡达标，Godot联调起点✅
M3  将领网络   ████████████ 100% ✅ GATE 2 通过
M4  内容填充   ████████████ 100% ✅ 历史事件33条，TDD契约全覆盖
M5  美术音乐   ░░░░░░░░░░░░   0%
M6  打磨发布   ░░░░░░░░░░░░   0%
```

**135 单元测试全部通过**

**平衡结果**: Military 24.2% ✅ | Political 21.2% ✅ | Balanced 22.4% ✅

## 前端层进度快照

```
F0  运行入口清理        ████████████ 100% ✅
F1  主场景结构骨架      ████████████ 100% ✅
F2  HUD 数据展示        ████████████  95% ✅
F3  决策托盘交互        ████████████ 100% ✅
F4  地图与侧栏占位      ████████████  95% ✅
F5  视觉统一与动效      ████████░░░░  55% 🔶
```

### F-GATE

- **F-GATE 1**: 看起来像游戏了吗？ ✅ 通过
- **F-GATE 2**: 能完成一次可见交互了吗？ ✅ 通过

### 前端架构（Priority F 解耦，四波已全部落地）

| 模块 | 文件 | 行数 | 职责 |
|------|------|------|------|
| 编排器 | `main_menu.gd` | 494 | 节点装配、信号绑定、回合流、顶层刷新 |
| 地图控制 | `map_controller.gd` | 656 | 数据模型、交互状态机、行军选点、渲染编排 |
| 地图渲染 | `map_render_controller.gd` | 592 | 节点/边绘制、标签碰撞、视觉状态（纯函数接口） |
| 侧栏 | `sidebar_controller.gd` | ~300 | 当前局势 + 将领忠诚 + 叙事面板 |
| 托盘 | `tray_controller.gd` | ~300 | 决策卡片构建、选中/冷却态、确认联动 |
| 布局 | `layout_controller.gd` | 344 | 响应式布局、最小高度 + 弹性分配 |
| 弹窗 | `dialogs_controller.gd` | 369 | 游戏结束、战斗参数、忠诚度强化 |
| 格式化 | `ui_formatters.gd` | — | 数字/phase/terrain/outcome 文案映射 |
| 配置 | `main_menu_config.gd` | — | 政策ID、emoji、效果、地形选项等常量 |

### 前端当前阻塞点

- `main_menu.gd` 仍混有回合流、HUD 刷新和弹窗状态组装职责（第五波候选）
- F5 视觉统一 55%：托盘双滚动修复、中英混排统一、动效补全待完成

---

## 已完成模块清单

| 模块 | 文件 | 测试数 | 状态 |
|------|------|--------|------|
| 战斗解算 | `battle/resolver.rs` | 12 | ✅ |
| 行军系统 | `battle/march.rs` | 10 | ✅ |
| 政治系统 | `politics/system.rs` | 8 | ✅ |
| 命令偏差 | `characters/order_deviation.rs` | 6 | ✅ |
| 将领关系网络 | `characters/network.rs` | 27 | ✅ +4 命令偏差测试 |
| 三系统状态机 | `engine/state.rs` | 16 | ✅ |
| 历史事件池 | `events/pool.rs` | 16 | ✅ 33条×5叙事 |
| 蒙特卡洛模拟 | `simulation/monte_carlo.rs` | 8 | ✅ |
| 叙事引擎 | `narratives/mod.rs` | 10 | ✅ |
| GDExtension | `lib.rs` | — | ✅ 4节点 |
| Save/Load | `engine/state.rs` | — | ✅ to_json/from_json |

**合计**: 135 tests 全部通过

---

## GATE 2：✅ 通过

| 检查项 | 证据 |
|--------|------|
| 三系统耦合状态机 | `engine::state` 16 tests |
| 蒙特卡洛平衡验证 | Military 24.2% / Political 21.2% / Balanced 22.4% |
| 30条历史事件集成 | 触发率验证通过 |
| Godot 4.6 升级 | gdext 0.4.5, api-4-5 |

---

## Tier 路线图

### Tier 0 — 快速修复 ✅

- ✅ GDExt 补全 3 条缺失政策
- ✅ UI 显示全部 8 张政策卡片

### Tier 1 — 最小可玩 ✅

- ✅ 战斗选择 UI
- ✅ 忠诚度强化 UI
- ✅ 游戏结束画面
- ✅ 冷却逻辑

### Tier 2 — 战略纵深 ✅

- ✅ 2.1 Rust PlayerAction::March + 引擎集成
- ✅ 2.2 GDExt 暴露行军 API
- ✅ 2.3 前端地图点击行军
- ✅ 2.4 行军与战斗关联（地形推断 + 疲劳持久化 + 战报地形加成）

### Tier 3 — 深度与沉浸（当前）

- ✅ **3.1 命令偏差接入战斗**（`calculate_deviation()` + 战报偏差叙事 + 4 测试）
- 🔶 **3.2 叛逃/倒戈触发** [M] — `dusk_settlement()` 每日检查 Ney/Grouchy 条件
- 🔶 **3.3 联军动态化** [M] — 战败后联军士气/兵力下降
- 🔶 **3.4 存档/读档 UI** [S] — 顶栏按钮 + 确认对话框
- 🔶 **3.5 事件效果补完** [S] — `coalition_troops_delta` / `paris_security_bonus` / `political_stability_bonus`

**Tier 3 完成标志**: 将领会叛逃、命令会偏差、联军会因败仗动摇、玩家可存档。

### 依赖关系

```
Tier 0 ──→ Tier 1 ──→ Tier 2 ✅ ──→ Tier 3（当前）
```

### 不在本路线图范围

- M5 美术资源替换（emoji → 真实纹理）
- M6 BGM/音效
- 多语言 / 多存档槽 / Steam 集成 / 教程
