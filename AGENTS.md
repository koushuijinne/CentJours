# Cent Jours — Codex Harness

> 本文件是 Codex 在本仓库的默认入口。Claude Code 专用入口仍是 `CLAUDE.md` 和 `.claude/`，两者互不替代。

## 项目

Godot 4 + Rust GDExtension 策略游戏：扮演 1815 年拿破仑，在 100 天内重建帝国。

## 架构

```text
UI (GDScript Scene/Controller)
  -> TurnManager (回合协调)
    -> CentJoursEngine (Rust GDExtension 规则引擎)
      -> GameState (UI 只读缓存)
        -> UI refresh
```

- 规则真值在 Rust：`cent-jours-core/`
- GDScript 负责场景装配、交互、展示
- 数据流单向：Engine -> TurnManager -> GameState -> UI

## 当前基线

```yaml
godot: 4.6.1
rust: stable
characters: 15
map_nodes: 41
events: 66 / 100+
outcomes: 7
difficulty: 3
save_version: v4
tests_rust: 215
tests_gdunit4: 68
ci: windows-fast / windows-full / windows-heavy-nightly
harness: AGENTS.md / doc-sync guard / round check / harness status / validation scope / light guard / optional git hooks
```

## 不可违反的硬约束

1. 规则真值在 Rust，不在 GDScript 复制规则。
2. `GameState` 是只读缓存，不自行推导合法性、冷却、战斗或结局结果。
3. 数据流保持单向：Engine -> TurnManager -> GameState -> UI。
4. 代码改动必须同步文档；提交前跑文档同步检查。
5. Windows 是默认验证平台，不用 Linux / WSL 结果补位。
6. 修改规则层必须补测试；修改前端状态流必须补 `GdUnit4` 或 Windows 真机验证记录。
7. 不为写实牺牲可读性、反馈清晰度和玩家公平感。
8. 文案遵守 ADR-008：直写、可考据、不 reframe；`historical_note` 和联军/外交动态默认第三人称档案体。

## Codex 默认工作流

1. 先读本文件。
2. 再读 [docs/plans/dev_plan.md](docs/plans/dev_plan.md) 确认当前优先级。
3. 再读 [docs/history/agent_handoff.md](docs/history/agent_handoff.md) 获取动态状态。
4. 改代码前先读相关源文件，不凭文档猜实现。
5. 改完先跑对应验证，再更新文档。
6. 代码和文档放在同一个 commit，不拆开。
7. 一轮结束前运行 `tools/codex_doc_sync_guard.sh`；需要看当前门禁状态时运行 `tools/codex_harness_status.sh`；准备停在某个 round 时运行 `tools/codex_round_check.sh`。
8. 改动较大或准备 push 前，运行 `tools/codex_light_guard.sh` 查看最小本地守卫和推荐云端验证链。

## 默认验证口径

- Rust 规则 / 数据结构改动：

```bash
cd cent-jours-core && cargo test
```

- 改 `lib.rs` / GDExt API：

```bash
cd cent-jours-core && cargo build --features godot-extension
```

- 改 GDScript / 主菜单状态流（Windows）：

```bash
tools/run_gdunit_windows.cmd <godot_path> res://tests/godot
<godot_path> --headless --path <project_path> --quit
<godot_path> --headless --path <project_path> --scene res://src/dev/engine_smoke_test_scene.tscn
```

- 若只做局部前端修复，可先跑对应单个 `GdUnit4` 文件，再决定是否跑全量。
- Linux / WSL 测试可以辅助定位，但不能写成权威验证结论。

## Codex 专用工具

- `tools/codex_doc_sync_guard.sh`
  - 本地文档同步检查；优先读 staged 文件，没有 staged 时读 working tree 变更。
- `tools/codex_round_check.sh`
  - 回合结束前检查工作区是否干净、是否有未推送提交。
- `tools/codex_harness_status.sh`
  - 输出当前分支、ahead/behind、hooksPath、worktree 洁净度和文档变更状态。
- `tools/codex_validation_scope.py`
  - 按改动文件类型输出最小本地验证和推荐云端验证链。
- `tools/codex_light_guard.sh`
  - 运行 doc sync、shell/python 语法、Rust fmt，并打印本轮验证范围建议。
- `tools/install_codex_git_hooks.sh`
  - 把仓库内 `.githooks/` 安装为当前 repo 的 git hooks（`pre-commit + pre-push`）。

## 禁止

- 改代码不看源文件，直接凭文档或截图猜实现。
- 先提交代码，再单独补文档。
- 在 GDScript 里复制 Rust 已有的规则逻辑。
- 用 Linux / WSL 测试结果替代 Windows 验证。
- 未补验证就把主循环、存读档、结局、补给或主菜单状态流当作“已收口”。

## 关键路径

| 路径 | 职责 |
|------|------|
| `cent-jours-core/src/` | Rust 规则引擎 |
| `cent-jours-core/src/lib.rs` | GDExtension 暴露入口 |
| `src/core/` | GDScript 核心层 |
| `src/ui/main_menu.gd` | 主场景装配 |
| `src/ui/main_menu/` | map / layout / tray / sidebar / dialogs / topbar_actions |
| `src/data/` | 静态数据 |
| `tests/godot/` | GdUnit4 前端回归 |
| `docs/decisions/` | ADR 决策记录 |

## 按需阅读

- [docs/plans/dev_plan.md](docs/plans/dev_plan.md) — 当前计划和 Steam 上线优先级
- [docs/history/agent_handoff.md](docs/history/agent_handoff.md) — 动态状态、当前缺口、写入边界
- [docs/decisions/README.md](docs/decisions/README.md) — ADR 索引
- [docs/rules/development_principles.md](docs/rules/development_principles.md) — 完整原则
- [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md) — 仅在用户明确要求时启用

## 当前总目标

按 [ADR-011](docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 收口核心玩法，达到 Steam 可上线级别。
