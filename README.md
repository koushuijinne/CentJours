# Cent Jours

你扮演 1815 年的拿破仑，从厄尔巴岛出逃，在 100 天内重建帝国、稳住政治与补给体系，并决定自己是在巴黎站稳脚跟，还是走向滑铁卢。

本项目当前是一个 Windows-first 的 Godot 4 + Rust GDExtension 策略游戏原型，主场景入口为 `src/ui/main_menu.tscn`。仓库已经具备可玩的纵向切片，也已经接入 Windows 自动化测试、Godot `GdUnit4` 回归和 Windows CI。
主菜单当前还提供最小设置入口，可持久化窗口模式和界面缩放。

## 环境部署说明

### 默认开发环境

- 操作系统：Windows
- Godot：`4.6.1`
- Rust：stable toolchain
- 构建链：建议使用 MSVC 工具链与 Visual Studio C++ Build Tools

项目当前不把 Linux / WSL 结果作为权威验证结论。Linux / WSL 可以做只读查看或轻量辅助，但默认开发、构建和验证以 Windows 为准。

### 首次拉取后的最小准备

1. 安装 Rust stable
2. 安装 Godot `4.6.1` Windows 版本
3. 确认可以在 Windows 命令行里运行 `cargo`
4. 确认 Godot 可执行文件路径可用

### 本地运行

Godot GUI 打开项目：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64.exe --path E:\projects\CentJours
```

Windows 无头启动：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

### GDExtension 构建

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

## 测试与质量

### 本地默认验证

- Rust 规则层：Windows `cargo test`
- Rust + GDExt API：Windows `cargo build --features godot-extension`
- Godot 前端：Windows `GdUnit4 + headless boot + smoke scene`

Rust 测试：

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo test
```

Godot `GdUnit4`：

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

Smoke scene：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --scene res://src/dev/engine_smoke_test_scene.tscn
```

### 当前质量门槛

- 代码改动默认要补对应验证
- 代码路径改动默认要同步更新 `README.md` 或 `docs/`，GitHub Actions 会做文档同步门禁
- 主菜单和地图交互问题优先绑定 `GdUnit4`
- 视觉、布局、滚动与可读性问题以 Windows 真机为最终标准
- GitHub Actions 已有 Windows workflow，会跑 Rust tests、GDExt build、`GdUnit4`、headless boot 和 smoke
- 玩家设置会写入 `user://cent_jours_settings.cfg`，默认管理窗口模式与界面缩放

## Roadmap

### 当前优先级

- 继续收口 Windows CI、文档同步门禁与 Godot 前端自动回归
- 把 `docs/bugs` 里的关键问题持续转成自动化验证
- 在测试护栏稳定后继续推进补给玩法产品化与教学链

### 中期目标

- 补给玩法继续产品化，强化教学链和失败归因
- 历史事件池扩到 `100+`
- 继续清理主菜单状态机和发布级交互问题

### 最终目标

- 核心玩法收口到 Steam 可上线级别
- 完成首发所需的验证、文档、资产和发布准备

## 文档导航

- [docs/plans/dev_plan.md](docs/plans/dev_plan.md)
  当前技术基线、优先级和验证方式
- [docs/plans/product_plan.md](docs/plans/product_plan.md)
  产品里程碑和版本目标
- [docs/architecture.md](docs/architecture.md)
  系统结构、模块关系和主数据流
- [docs/interfaces.md](docs/interfaces.md)
  Rust / Godot / Save / Test 的核心接口契约
- [docs/bugs/bug_index.md](docs/bugs/bug_index.md)
  结构化 bug 索引与当前代码问题记录
- [docs/history/agent_handoff.md](docs/history/agent_handoff.md)
  当前状态、当前分支和接手约束
- [docs/decisions/](docs/decisions/)
  ADR 决策记录
- [docs/bugs/](docs/bugs/)
  bug 记录、截图和回归追踪

## 术语表

- `CentJoursEngine`
  Rust GDExtension 暴露给 Godot 的整局规则引擎。
- `TurnManager`
  GDScript 薄层回合协调器，负责 Dawn / Action / Dusk 流程驱动。
- `GameState`
  Godot 侧只读缓存，保存 UI 直接消费的状态快照。
- `GDExtension`
  Godot 4 与 Rust 之间的原生扩展机制。
- `GdUnit4`
  当前 Godot 前端自动回归测试框架。
- `smoke scene`
  `src/dev/engine_smoke_test_scene.tscn`，用于快速检查主链路是否打通。
- `historical_note`
  历史事件的事实性补注，与正文分层展示。
- `logistics posture`
  当前补给态势，如前线消耗区、稳定走廊等。
- `forward depot`
  前沿粮秣站，短期提高驻地容量的补给设施状态。
- `AudioManager`
  音频管理器 autoload 单例，管理 BGM 交叉淡入、SFX 池化播放和音量持久化。
- `Difficulty`
  Rust 枚举 (Elba/Borodino/Austerlitz)，影响敌军强度、政治衰减、补给和合法性。
- `Save v3`
  当前存档版本，包含 `tuileries_eve` 迁移和前沿粮秣站状态。
