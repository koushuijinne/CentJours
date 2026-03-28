# Cent Jours — AI 开发入口

> 本文件是 Claude Code 自动读取的项目入口。保持精简，只提供定位信息。

## 项目一句话

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

## 必读文件（按顺序）

1. `docs/rules/development_principles.md` — 项目原则和硬约束
2. `docs/plans/dev_plan.md` — 当前优先级和 Steam 上线任务
3. `docs/history/agent_handoff.md` — 当前状态和接手约束

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

## 测试

- Rust: `cd cent-jours-core && cargo test` (211 tests)
- Godot: GdUnit4 (50 tests) + headless boot + smoke scene
- CI: `.github/workflows/windows-validation.yml`
- 文档门禁: `.github/workflows/doc-sync.yml`

## 当前基线

- Godot 4.6.1 + Rust stable
- 17 角色 / 43 地图节点 / 58 历史事件
- Save v3 兼容路径
- 难度系统: Elba / Borodino / Austerlitz

## 硬约束

- 不在 GDScript 里复制 Rust 规则
- GameState 是只读缓存，不是第二套引擎
- 代码改动必须同步更新文档（CI 门禁）
- Windows 是默认验证平台，不用 Linux/WSL 结果补位
