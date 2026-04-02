# Cent Jours — 项目 Harness

> 本文件是 Claude Code 自动读取的唯一入口。所有硬约束内联于此，不再需要跳转其他规则文件。

## 项目

Godot 4 + Rust GDExtension 策略游戏：扮演 1815 年拿破仑，100 天内从厄尔巴岛重建帝国。

## 架构

```
UI (GDScript Scene/Controller)
  → TurnManager (回合协调)
    → CentJoursEngine (Rust GDExtension 规则引擎)
      → GameState (UI 只读缓存)
        → UI refresh
```

- 规则真值在 Rust (`cent-jours-core/`)
- GDScript 是薄层：场景装配 + 交互 + 展示
- 数据流单向：Engine → TurnManager → GameState → UI

## 基线

```yaml
godot: 4.6.1
rust: stable
characters: 15
map_nodes: 41
events: 58 / 100+
outcomes: 7  # NapoleonVictory DiplomaticSettlement MilitaryDominance WaterlooHistorical WaterlooDefeat PoliticalCollapse MilitaryAnnihilation
difficulty: 3  # Elba Borodino Austerlitz
save_version: v4
tests_rust: 215
tests_gdunit4: 68
ci: windows-fast / windows-full / windows-heavy-nightly
```

## 硬约束（不可违反）

1. 规则真值在 Rust，不在 GDScript 复制
2. GameState 是只读缓存，不自行推导状态
3. 数据流单向：Engine → TurnManager → GameState → UI
4. 代码改动必须同步文档（CI 门禁 `doc-sync.yml`）
5. Windows 是默认验证平台，不用 Linux/WSL 结果补位
6. 不为写实牺牲可读性和公平感
7. 不在核心循环未验证前堆砌外围复杂度
8. 文案遵守 ADR-008：直写、可考据、不 reframe
9. `historical_note` 和联军/外交动态用第三人称档案体

## 做事流程

1. 读本文件（CLAUDE.md）了解约束和基线
2. 读 `docs/plans/dev_plan.md` 确认当前优先级
3. 读 `docs/history/agent_handoff.md` 了解动态状态
4. 改代码前先读相关源文件
5. 改完跑测试：Rust → `cd cent-jours-core && cargo test` | GDScript → GdUnit4
6. 代码和文档同一个 commit，不拆开
7. 更新 `agent_handoff.md`，按需更新 `dev_plan.md`

## 禁止

- 先提交代码再单独补文档
- GDScript 复制 Rust 已有的规则逻辑
- 修改规则层不补测试
- 用 Linux/WSL 测试结果补位 Windows
- 默认启用自动工作流（需用户明确要求）
- 在 GDScript 里自行推导合法性、冷却或战斗结果

## 阻塞处理

- **软阻塞**（编译/测试失败）：立即修复，不切任务
- **中阻塞**（依赖 Windows 真机）：记录后切到不依赖的任务
- **硬阻塞**（产品方向/外部资源）：问用户

## 关键目录

| 路径 | 职责 |
|------|------|
| `cent-jours-core/src/` | Rust 规则引擎（战斗/行军/政治/事件/补给） |
| `cent-jours-core/src/lib.rs` | GDExtension 暴露入口 |
| `src/core/` | GDScript 核心层（TurnManager, GameState, SaveManager, AudioManager） |
| `src/ui/main_menu.gd` | 主场景装配 |
| `src/ui/main_menu/` | 子控制器（map, layout, tray, sidebar, dialogs, topbar_actions） |
| `src/data/` | 静态游戏数据（characters, events, map_nodes） |
| `tests/godot/` | GdUnit4 前端回归 |
| `docs/decisions/` | [ADR 汇总表](docs/decisions/README.md) — 12 篇架构决策记录 |

## 测试命令

```bash
# Rust（必跑）
cd cent-jours-core && cargo test

# GDExtension 构建（改 lib.rs / API 时）
cd cent-jours-core && cargo build --features godot-extension

# GdUnit4（改 GDScript 时，Windows 侧）
tools\run_gdunit_windows.cmd <godot_path> res://tests/godot

# Windows 无头启动
<godot_path> --headless --path <project_path> --quit
```

## 按需阅读

- `docs/plans/dev_plan.md` — 当前计划和 Steam 上线优先级
- `docs/history/agent_handoff.md` — 动态项目状态（已完成系统、当前缺口、写入边界）
- `docs/decisions/README.md` — 12 篇 ADR 架构决策汇总
- `docs/rules/development_principles.md` — 完整 27 条原则（人类参考）
- `docs/rules/optional/agent_autonomous_workflow.md` — 仅在用户要求时启用

## 当前总目标

按 [ADR-011](docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 收口核心玩法，达到 Steam 可上线级别。
