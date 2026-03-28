# 接口文档

## 文档目标

本文档记录当前最重要的跨层契约，重点是：

- Godot 调什么
- Rust 返回什么
- Save/Load 和 `GameState` 怎么同步
- 哪些入口是测试和 CI 的标准入口

本文档不追求把所有字段逐一展开到最细，而是给稳定边界和定位入口。更完整的字段说明，优先看代码里的契约注释。

## 1. TurnManager 对 UI 暴露的核心接口

文件：`src/core/turn_manager.gd`

| 方法 | 用途 | 关键输入 | 关键输出 |
|------|------|----------|----------|
| `start_new_turn()` | 开始新的一天并跑 Dawn | 无 | 同步 `GameState`，触发 `turn_started` |
| `begin_action_phase()` | 进入可交互阶段 | 无 | 更新 phase 并触发 `phase_changed("action")` |
| `submit_action(action_type, params)` | 统一提交行动入口 | `battle / march / policy / boost_loyalty / rest` | `bool`，表示是否接受提交 |
| `get_march_preview(target_node)` | 只读行军预判 | 目标节点 ID | `Dictionary` 预判结果 |
| `save_to_file(slot_id)` | 保存存档 | 槽位 ID | `bool` |
| `load_from_save(slot_id)` | 从槽位读档 | 槽位 ID | `bool` |
| `set_difficulty(difficulty_id)` | 设置下次新局难度 | 难度 ID 字符串 | 无 |
| `reset_engine()` | 新局重置（应用 pending 难度） | 无 | 重建引擎并清缓存 |

### `submit_action()` 参数契约

- `battle`
  - `{ general_id, troops, terrain }`
- `march`
  - `{ target_node }`
- `policy`
  - `{ policy_id }`
- `boost_loyalty`
  - `{ general_id }`
- `rest`
  - `{}`

## 2. Rust GDExtension 核心入口

文件：`cent-jours-core/src/lib.rs`

### `CentJoursEngine`

这是整局规则引擎，也是当前 Godot 主循环真正依赖的核心对象。

关键方法：

| 方法 | 用途 |
|------|------|
| `process_day_rest()` | 执行休整 |
| `process_day_battle(general_id, troops, terrain)` | 执行战斗 |
| `process_day_march(target_node)` | 执行行军 |
| `process_day_policy(policy_id)` | 执行政策 |
| `process_day_boost_loyalty(general_id)` | 执行接见将领 |
| `preview_march(target_node)` | 返回只读行军预判 |
| `get_state()` | 返回整局状态快照 |
| `get_last_report()` | 返回最近一次叙事报告 |
| `get_triggered_events()` | 返回已触发历史事件列表 |
| `current_day()` | 返回当前天数 |
| `is_over()` | 返回是否结束 |
| `to_json()` | 序列化整局状态 |
| `load_from_json(json)` | 反序列化整局状态 |
| `set_difficulty(id)` | 设置难度 (elba/borodino/austerlitz) |
| `get_difficulty()` | 返回当前难度 ID |

### 其他 GDExt 节点

| 类型 | 用途 |
|------|------|
| `BattleEngine` | 独立战斗解算 |
| `PoliticsEngine` | 政治状态与政策演算 |
| `CharacterManager` | 忠诚度与命令偏差计算 |

这些节点仍然存在，但当前主玩法主线以 `CentJoursEngine` 为主。

## 3. `get_march_preview()` / `preview_march()` 契约

当前主菜单地图和侧栏会直接消费这些字段：

- `valid`
- `reason`
- `fatigue_delta`
- `morale_delta`
- `supply_delta`
- `projected_fatigue`
- `projected_morale`
- `projected_supply`
- `supply_capacity`
- `base_supply_capacity`
- `temporary_capacity_bonus`
- `supply_demand`
- `supply_available`
- `line_efficiency`
- `supply_role`
- `supply_role_label`
- `supply_hub_name`
- `supply_hub_distance`
- `supply_runway_days`
- `follow_up_total_options`
- `follow_up_safe_options`
- `follow_up_risky_options`
- `follow_up_status_id`
- `follow_up_status_label`
- `follow_up_best_target`
- `follow_up_best_target_label`
- `follow_up_best_runway_days`

如果你修改这些键名或语义，必须同步：

- `src/core/turn_manager.gd`
- `src/ui/main_menu/map_controller.gd`
- `src/ui/main_menu/sidebar_controller.gd`
- 相关 `GdUnit4` 与 smoke

## 4. GameState 同步契约

文件：`src/core/game_state.gd`

`GameState` 是 Godot 侧只读缓存，主要分为几组：

- 回合状态
  - `current_day`
  - `current_phase`
- 军事与地图
  - `napoleon_location`
  - `available_march_targets`
  - `total_troops`
  - `avg_morale`
  - `avg_fatigue`
  - `supply`
- 补给态势与教学
  - `logistics_posture_*`
  - `logistics_objective_*`
  - `logistics_action_plan_*`
  - `logistics_tempo_plan_*`
  - `logistics_route_chain_*`
  - `logistics_regional_pressure_*`
  - `logistics_regional_task_*`
  - `logistics_runway_*`
- 政治
  - `legitimacy`
  - `rouge_noir_index`
  - `faction_support`
  - `policy_cooldowns`
- 叙事与历史
  - `triggered_events`
  - `stendhal_diary`

- 失败归因
  - `key_decisions` — 关键决策记录数组（最多 20 条）
  - `difficulty` — 当前难度 ID

规则：

- `GameState` 不自行重算规则
- `GameState` 字段主要由 `TurnManager._sync_state_from_engine()` 同步
- UI 如果需要新字段，优先先在 Rust 暴露，再通过 `TurnManager` 下发

## 5. Save / Load 契约

文件：

- `src/core/save_manager.gd`
- `src/core/turn_manager.gd`
- `cent-jours-core/src/engine/state.rs`

当前要点：

- 存档版本：`v3`
- 默认 3 个槽位
- 兼容老单槽路径
- `outcome` 会正规化，进行中状态显示为“进行中”
- 读档成功后：
  - phase 重设为 `action`
  - `GameState.triggered_events` 从引擎重建
  - UI 需要刷新按钮、卡片、地图和侧栏

如果你改动存档字段或迁移规则，必须同步：

- Rust 存档结构
- `SaveManager`
- `TurnManager.load_from_save()`
- 对应回归测试
- 文档

## 6. 主菜单弹窗契约

主要文件：

- `src/ui/main_menu.gd`
- `src/ui/main_menu/dialogs_controller.gd`

当前已固定的可测试节点包括：

- `SaveSlotPickerPopup`
- `LoadSlotPickerPopup`
- `NewGameConfirmDialog`
- `LoadConfirmDialog`
- `BattlePopup`
- `BattleConfirmButton`
- `BattleCancelButton`
- `BoostPopup`
- `BoostConfirmButton`
- `BoostCancelButton`
- `GameOverOverlay`
- `GameOverTitleLabel`
- `GameOverStatsLabel`
- `GameOverRestartButton`

这些节点名已经被 `GdUnit4` 用作稳定测试锚点。改名时必须同步测试。

## 7. 音频管理器契约

文件：`src/core/audio_manager.gd`

AudioManager 是 autoload 单例（在 `project.godot` 注册）。

| 方法 | 用途 |
|------|------|
| `play_bgm(track_key)` | 切换 BGM（交叉淡入） |
| `stop_bgm()` | 停止 BGM |
| `play_sfx(event_key)` | 播放音效（池化） |
| `set_volume(channel, value)` | 设置音量 (master/music/sfx, 0.0-1.0) |
| `get_volume(channel)` | 获取音量 |
| `set_muted(muted)` | 全局静音开关 |

BGM 曲目键: `main_menu`, `march`, `politics`, `battle`, `victory`, `defeat`
SFX 事件键: `button_click`, `turn_advance`, `battle_resolve`, `event_popup`, `save_complete`, `achievement`

音频设置持久化路径: `user://cent_jours_audio.cfg`

## 8. 玩家设置契约

文件：

- `src/core/settings_manager.gd`
- `src/ui/main_menu.gd`

当前最小设置链路：

- 持久化路径：`user://cent_jours_settings.cfg`
- 配置分区：`display`
- 当前键：
  - `window_mode`
  - `ui_scale`

已固定的窗口模式值：

- `windowed`
- `maximized`
- `fullscreen`

已固定的界面缩放值：

- `0.9`
- `1.0`
- `1.1`
- `1.25`

规则：

- `SettingsManager` 负责默认值、归一化、`ConfigFile` 读写和把设置应用到当前窗口
- `main_menu.gd` 只负责顶栏入口和设置弹窗 UI
- 若增加新的设置项，至少同步：
  - `SettingsManager`
  - 主菜单设置弹窗
  - `GdUnit4` 回归
  - 本文档

当前已固定的可测试节点包括：

- `SettingsButton`
- `SettingsPopup`
- `SettingsWindowModeOption`
- `SettingsUiScaleOption`
- `SettingsApplyButton`
- `SettingsResetButton`
- `SettingsCancelButton`

这些节点名已经进入 `GdUnit4` 回归。改名时必须同步测试。

## 9. 测试与 CI 入口

### 本地

Rust：

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo test
```

Windows GDExt build：

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

Godot `GdUnit4`：

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

Headless boot：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

Smoke：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --scene res://src/dev/engine_smoke_test_scene.tscn
```

### CI

文件：`.github/workflows/doc-sync.yml`

- 作用：代码路径改动时，强制要求同步更新 `README.md` 或 `docs/`
- 覆盖路径：
  - `src/`
  - `cent-jours-core/`
  - `tests/`
  - `tools/`
  - `.github/workflows/`
- 本地复用入口：`python3 tools/check_doc_sync.py --files ...`

文件：`.github/workflows/windows-validation.yml`

当前触发范围：

- `src/**`
- `cent-jours-core/**`
- `tests/**`
- `addons/**`
- `tools/run_gdunit_windows.cmd`
- `.github/workflows/windows-validation.yml`

当前顺序：

1. Rust tests
2. Windows GDExt build
3. Godot `GdUnit4`
4. headless boot
5. smoke scene

`windows-validation.yml` 已启用 `concurrency`，同分支新 run 会取消旧 run；同时改成白名单触发，避免文档和无关 workflow 改动占用 Windows runner。

## 10. 维护要求

发生以下变化时必须同步本文档：

- `TurnManager` 输入输出契约变化
- `CentJoursEngine` 暴露方法变化
- `GameState` 新增整组字段
- Save / Load 版本或迁移变化
- `GdUnit4` 稳定节点名变化
- CI 执行顺序变化
- 文档同步门禁路径变化
