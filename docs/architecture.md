# 架构文档

## 文档目标

本文档面向第一次接手项目的人类开发者，回答三个问题：

- 运行时是怎么串起来的
- 哪层负责什么，不该在哪里写逻辑
- 核心数据和验证链是怎么流动的

## 总体结构

项目采用 Godot 前端 + Rust 规则引擎的双层结构。

```text
UI(Scene/Controller)
    ↓
TurnManager
    ↓
CentJoursEngine (Rust GDExtension)
    ↓
GameState / Save / Narrative / EventBus
    ↓
UI refresh / logs / dialogs / map feedback
```

关键原则：

- 规则真值在 Rust
- GDScript 是薄层协调与 UI 装配
- `GameState` 是 UI 读缓存，不是第二套规则引擎

## 目录职责

### Rust 核心

- `cent-jours-core/src/engine/`
  整局状态、存档、主规则状态机
- `cent-jours-core/src/battle/`
  战役与行军相关规则
- `cent-jours-core/src/politics/`
  政治与合法性系统
- `cent-jours-core/src/characters/`
  将领、忠诚度、命令偏差
- `cent-jours-core/src/events/`
  历史事件池与触发窗口
- `cent-jours-core/src/narratives/`
  叙事报告与后果文本
- `cent-jours-core/src/lib.rs`
  GDExtension 暴露入口和 Godot 可调用接口

### Godot 薄层

- `src/core/turn_manager.gd`
  回合流程和 UI 到引擎的主协调点
- `src/core/game_state.gd`
  UI 读缓存与静态数据装载（含 key_decisions 关键决策追踪）
- `src/core/save_manager.gd`
  Save/Load 文件读写与槽位管理
- `src/core/event_bus.gd`
  前端事件分发
- `src/core/audio_manager.gd`
  音频管理器 autoload（BGM 交叉淡入、SFX 池化播放、音量持久化）

### 主菜单前端

- `src/ui/main_menu.gd`
  主场景装配层
- `src/ui/main_menu/map_controller.gd`
  地图交互和行军预览
- `src/ui/main_menu/sidebar_controller.gd`
  右侧信息面板
- `src/ui/main_menu/dialogs_controller.gd`
  战斗、接见、结局等弹窗
- `src/ui/main_menu/tray_controller.gd`
  `DecisionTray` 选择与确认状态
- `src/ui/main_menu/topbar_actions_controller.gd`
  顶栏按钮（设置、存读档、新局确认）与 modal 管理
- `src/ui/main_menu/layout_controller.gd`
  布局与响应式边界

### 数据与测试

- `src/data/`
  人物、地图、历史事件、叙事等静态数据
- `tests/godot/`
  Godot `GdUnit4` 自动回归
- `src/dev/engine_smoke_test_scene.tscn`
  主链路 smoke
- `.github/workflows/doc-sync.yml`
  文档同步门禁
- `.github/workflows/windows-validation.yml`
  Windows CI

## 主循环

运行时主循环是三段式：

1. `Dawn`
   - `TurnManager.start_new_turn()`
   - 从 Rust 读状态到 `GameState`
   - 刷新 UI 与情报
2. `Action`
   - 玩家在 `DecisionTray`、地图和弹窗里提交动作
   - `TurnManager.submit_action()` 负责统一入口
3. `Dusk`
   - Rust 执行整日结算
   - `TurnManager` 同步状态、叙事、历史事件和 game over

这个结构的意义是：所有行动都通过统一入口进规则层，避免 UI 控制器各自偷偷改状态。

## 数据流

### 普通行动

```text
UI click
  -> main_menu.gd
  -> TurnManager.submit_action()
  -> CentJoursEngine.process_day_*
  -> TurnManager._sync_state_from_engine()
  -> EventBus / GameState
  -> UI refresh
```

### 行军预判

```text
Map select
  -> map_controller.gd
  -> TurnManager.get_march_preview()
  -> CentJoursEngine.preview_march()
  -> preview dictionary
  -> sidebar/map feedback
```

### 历史事件与叙事

```text
CentJoursEngine process day
  -> triggered events
  -> get_last_report()
  -> TurnManager emits EventBus signals
  -> sidebar narrative / history panel
```

## Save / Load 架构

Save/Load 当前走 `v3` 路径。

```text
UI slot picker
  -> SaveManager
  -> CentJoursEngine.to_json() / load_from_json()
  -> disk file
  -> TurnManager resync
  -> GameState / UI refresh
```

当前关键点：

- `SaveManager` 管理 3 个槽位
- 老存档仍允许兼容读取
- 旧事件 ID `fontainebleau_eve` 会在读档时迁移到正式 ID `tuileries_eve`
- 前沿粮秣站等补给状态已纳入存档

## 架构边界

### 应该写在 Rust 的内容

- 战斗、行军、补给、政治、事件触发规则
- 存档真值与兼容迁移
- 不依赖 UI 的状态推导
- 结算时序与规则不变量

### 应该写在 GDScript 的内容

- 场景树装配
- 交互状态机
- 面板、弹窗、地图、日志展示
- 调用 Rust 接口并把结果翻译成 UI

### 不该做的事

- 不在 GDScript 里复制 Rust 已有的规则判断
- 不把 `GameState` 当作第二套业务真值
- 不把“为了显示方便”的字段回写成规则层权威状态

## 难度系统

Rust 引擎内置 `Difficulty` 枚举（Elba / Borodino / Austerlitz），影响敌军强度、政治衰减、补给加成和初始合法性。GDExtension 通过 `set_difficulty()` / `get_difficulty()` 暴露，存档兼容。GDScript 侧通过新局流程弹窗选择难度，经 `TurnManager.set_difficulty()` 传入引擎。

## 失败归因

`GameState.key_decisions` 追踪关键决策点（战败、低补给行军、合法性/补给危机），最多保留 20 条。游戏结束弹窗会展示最近 8 条关键决策时间线和当前难度标记。

## 当前已知架构压力

- `main_menu.gd` 已从 1025 行减到 670 行，但仍可继续拆分
- `GameState` 字段很多，接口文档必须跟上，否则容易出现“字段知道存在，但不知道边界”
- 主菜单与地图交互仍是高回归区，需要继续用 `GdUnit4` 压住

## 验证结构

当前默认验证是 Windows-first：

- Rust tests
- Windows GDExt build
- Godot `GdUnit4`
- Godot headless boot
- smoke scene
- doc-sync 门禁
- 视觉问题看 Windows 真机

Linux / WSL 不作为默认权威验证结论。

## 开发建议

- 改规则先看 Rust，再看 `TurnManager`
- 改 UI 先找对应 controller，不要默认直接堆进 `main_menu.gd`
- 改存档先看 `SaveManager`、`TurnManager.load_from_save()` 和 Rust `engine/state`
- 改历史事件先看 `src/data/events/historical.json` 与 `cent-jours-core/src/events/pool.rs`
