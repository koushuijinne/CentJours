# Cent Jours — 开发优先级计划

> **更新**: 2026-03-28 v98
> **通用原则**: [docs/rules/development_principles.md](docs/rules/development_principles.md)
> **快速接手**: [docs/history/agent_handoff.md](docs/history/agent_handoff.md)
> **开发历史**: [docs/history/development_logs/](docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时阅读 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前技术基线

- 项目已经有可玩的纵向切片，正式入口仍是 `src/ui/main_menu.tscn`，主链路 `TurnManager -> CentJoursEngine -> GameState -> UI` 已跑通。
- 当前内容规模为 `15` 名角色、`41` 个地图节点、`58` 条历史事件；补给、政治、历史日志、存档读档和主菜单主循环都已接通。
- Save / Load 已进入 `v3` 兼容阶段；最近一次权威回归基线是 Windows `211/211` Rust tests、Windows `GdUnit4 54/54`、Windows Godot 主项目无头和 smoke scene。
- Rust 规则层的第一批正式集成测试和属性测试已经落地；Godot 前端第一批 `GdUnit4` 回归也已接入，Windows GitHub Actions 工作流与仓库脚本也已落地。
- GitHub Actions 已新增文档同步门禁：代码路径改动必须伴随 `README.md` 或 `docs/` 更新。
- 当前总目标已按 [ADR-011](docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 固定为：核心玩法优化完成，并达到 Steam 可上线级别。
- `auto/gameplay_update` 分支的后勤系统、主菜单修复、GdUnit4 测试拆分和开发者文档已合并到本分支。
- 本轮新增：难度系统 UI（Elba/Borodino/Austerlitz）、失败归因（GameState.key_decisions）、AudioManager 框架（BGM 交叉淡入 + SFX 池 + 音量持久化）、topbar_actions_controller 拆分（main_menu.gd 1025→684 行）。

---

## Steam 上线就绪度评估

> 基于 2026-03-28 全仓库审查

| 维度 | 完成度 | 判断 |
|------|--------|------|
| 核心玩法引擎 | 95% | Rust 规则层 + GDScript 前端主循环已跑通 |
| 存读档系统 | 100% | v3 兼容迁移已落地 |
| 历史事件内容 | 58% | 58/100+ 条，需补 42+ 条 |
| 教程/引导 | 10% | 仅有前 10 天 hint 文本，无正式教程流 |
| 结局系统 | 85% | 7 种结局路径已实现（NapoleonVictory / DiplomaticSettlement / MilitaryDominance / WaterlooHistorical / WaterlooDefeat / PoliticalCollapse / MilitaryAnnihilation），含外交进度系统、失败归因、难度标记、UI 文本和变体选择 |
| 音频 | 10% | AudioManager 框架已建立，缺音频资产文件 |
| 美术资产 | 0% | 无角色肖像、无地图美术、无战斗特效，仅有 icon.svg |
| 本地化 | 0% | 中文硬编码，无 i18n 框架，无英文翻译 |
| Steam 集成 | 0% | 无 Steamworks SDK、无成就、无云存档 |
| 设置系统 | 55% | 窗口模式 + UI 缩放 + 音频滑条 + 难度选择已有，缺按键/语言 |
| 地图视觉 | 0% | 数据完整(41 节点)，渲染为线框，无美术 |
| 测试覆盖 | 高 | Rust 211 + GdUnit4 54 + Windows CI |
| UI 主题 | 20% | 使用 Godot 默认主题，未实现产品计划的帝国新古典风格 |

---

## Steam 上线优先级任务

### 阶段 0: 验证链稳定（当前进行中）

> 目标：确保后续所有开发都有回归兜底

| ID | 任务 | 优先级 | 规模 | 状态 |
|----|------|--------|------|------|
| S0-1 | 继续收口 Windows GitHub Actions 验证链 | P0 | M | 进行中 |
| S0-2 | 把 `docs/bugs` 中的关键问题继续转成可重复验证 | P0 | M | 进行中 |
| S0-3 | 继续扩 Godot `GdUnit4` 覆盖面（存读档一致性、更多边界） | P0 | M | 进行中 |

### 阶段 1: 核心循环补厚 + 内容扩充

> 目标：让一局游戏从头到尾有完整体验

| ID | 任务 | 优先级 | 规模 | 说明 |
|----|------|--------|------|------|
| S1-1 | 历史事件扩到 100+ 条 | P0 | XL | 当前 58 条，需补中期政治/外交/社会事件 42+ 条，按 ADR-008 分级 |
| S1-2 | ~~完成多结局系统~~ | P0 | L | **已完成** — 7 种结局路径 (NapoleonVictory / DiplomaticSettlement / MilitaryDominance / WaterlooHistorical / WaterlooDefeat / PoliticalCollapse / MilitaryAnnihilation)，含外交进度系统、Rust check_outcome() 多路径逻辑、UI OUTCOME_TEXT + 变体选择 |
| S1-3 | 前 10 天新手教程流 | P0 | L | 引导玩家理解补给、政治、命令偏差三大核心，用场景内提示而非独立教程关 |
| S1-4 | 中期张力补强 (Day 20-80) | P1 | L | 增加定时危机事件、派系叛变窗口、联军集结压力曲线，避免重复行动感 |
| S1-5 | ~~失败归因系统~~ | P1 | M | **已完成** — GameState.key_decisions 追踪 + 游戏结束弹窗展示 |
| S1-6 | ~~难度选择 UI + 难度参数生效~~ | P1 | M | **已完成** — 新局弹窗选择 → TurnManager → Rust 引擎 |

### 阶段 2: 音频系统

> 目标：从无声变有声，达到可发布最低标准

| ID | 任务 | 优先级 | 规模 | 说明 |
|----|------|--------|------|------|
| S2-1 | ~~建立音频管理器框架~~ | P0 | M | **已完成** — AudioManager autoload + BGM 交叉淡入 + SFX 池 + 音量持久化 |
| S2-2 | 制作/采购 BGM | P0 | L | 最少 6 首：主菜单、行军、政治、战斗、胜利、失败；目标 AI 生成(AIVA/Suno) + 人工筛选 |
| S2-3 | 制作/采购 SFX | P1 | M | 最少：按钮点击、回合推进、战斗结算、事件弹窗、存档、成就；可用免费素材库 |
| S2-4 | Rouge/Noir 音乐动态切换 | P2 | M | 根据政治指针在暖色调/冷色调 BGM 间渐变 |

### 阶段 3: 视觉资产与 UI 主题

> 目标：脱离 Godot 默认外观，建立产品视觉身份

| ID | 任务 | 优先级 | 规模 | 说明 |
|----|------|--------|------|------|
| S3-1 | 自定义 UI 主题 | P0 | L | 按产品计划的帝国新古典调色板，替换按钮/面板/字体/进度条主题 |
| S3-2 | 17 张角色肖像 | P0 | L | AI 生成 + 手工修正，David 新古典肖像画风格，深色背景侧光 |
| S3-3 | 地图底图美术 | P0 | L | 法国 + 比利时区域底图（深色基调地形图），节点标记用金色菱形 |
| S3-4 | 行军路线与军队可视化 | P1 | M | 金色虚线路径 + 简化军队图标，替换当前线框 |
| S3-5 | 战斗结算视觉反馈 | P2 | M | 战斗结果弹窗增加简化动画/插图 |
| S3-6 | 应用图标与 Steam 胶囊图 | P1 | S | Steam 商店页需要：主胶囊图、头图、截图 5-10 张 |

### 阶段 4: 本地化与 Steam 集成

> 目标：满足 Steam 提审和国际发售最低要求

| ID | 任务 | 优先级 | 规模 | 说明 |
|----|------|--------|------|------|
| S4-1 | 引入 i18n 框架 | P0 | L | 使用 Godot 内置 `tr()` + CSV/PO，抽取所有硬编码中文字符串 |
| S4-2 | 英文翻译 | P0 | XL | 全量 UI + 58-100 条事件 + 教程 + 结局文本，约 3-5 万字 |
| S4-3 | Steamworks SDK 集成 | P0 | L | 使用 GodotSteam 插件，接入初始化、成就、云存档、Overlay |
| S4-4 | 成就系统设计与实现 | P1 | M | 10-20 个成就：首次胜利、各结局达成、特定历史选择 |
| S4-5 | Steam 商店页准备 | P1 | M | 商店描述(中/英)、标签、截图、预告片素材、年龄分级 |
| S4-6 | 手柄支持验证 | P2 | M | Godot 原生支持手柄，需验证全流程可用性 |

### 阶段 5: 发布打磨

> 目标：提审前最终收口

| ID | 任务 | 优先级 | 规模 | 说明 |
|----|------|--------|------|------|
| S5-1 | 设置系统补全 | P1 | M | 音频音量滑条+难度选择已有，还缺按键绑定、语言选择 |
| S5-2 | Windows 发布构建链 | P0 | M | Godot export template + 签名 + 安装包测试 |
| S5-3 | 全流程 QA 清单 | P0 | L | 从安装到通关全路径人工验收，覆盖所有结局 |
| S5-4 | 性能优化 | P1 | M | 内存泄漏检查、大地图帧率、长局稳定性 |
| S5-5 | 主菜单 `main_menu.gd` 继续拆分 | P2 | M | 已从 1025→684 行，可继续下沉到子控制器 |

---

## 推荐执行顺序

```
阶段 0 ──────► 阶段 1 ──────► 阶段 2 ──────► 阶段 3 ──────► 阶段 4 ──────► 阶段 5
验证链稳定     核心循环+内容   音频系统       视觉资产       本地化+Steam    发布打磨
(当前)        ↕ 可并行 ↕      ↕ 可并行 ↕
              阶段 2          阶段 3
```

- 阶段 0 是一切的前提，必须持续维护
- 阶段 1 是玩法核心，不达标则其他都无意义
- 阶段 2 和 3 可以与阶段 1 并行推进（音频/美术不依赖代码逻辑）
- 阶段 4 依赖阶段 1 的文本稳定后才能开始翻译
- 阶段 5 是最终收口，依赖前四阶段基本完成

---

## 当前技术债

- Rust 全局仍有约 `54` 处 `unwrap()` / `expect()` / `panic!()`，集中在 `events/pool.rs` 与 `engine/state.rs`。
- `main_menu.gd`（684 行）和 `map_controller.gd` 仍偏大，后续还需要继续按职责下沉。
- `tests/monte_carlo_balance.py` 与 Rust 核心基线已漂移，不应继续作为平衡主依据。
- 多槽存档 UI 已接入并补齐覆盖确认与删除入口，但设置与更多失败恢复链路仍不完整。
- 代码命名与注释风格仍不统一：存在旧中文测试函数名和"关键路径说明不足"的问题，需渐进治理。

---

## Godot 部分怎么测试

- 当前策略：`GdUnit4 + smoke + Windows 真机`，三层都要。
- Godot 前端测试按四层补齐：
  1. `场景加载 smoke` — 场景能打开，关键节点存在，`_ready()` 不报错
  2. `主流程 smoke` — 新局/执行行动/次日/存档/读档/地图选点可重复执行
  3. `GdUnit4 契约与状态流测试` — hover、click 锁定、缩放、弹窗确认、失败恢复
  4. `Windows 真机清单` — 字体、中文换行、遮挡、滚动、面板边界
- `GdUnit4` 测试按职责拆分到五个文件（共 54 tests）：
  - `main_menu_flow_test.gd` — 初始化、核心行动流、行军（11 tests）
  - `save_load_flow_test.gd` — 存读档槽位、覆盖/删除、新局、难度恢复、一致性（15 tests）
  - `dialog_flow_test.gd` — 设置、音频滑条、战斗/接见弹窗、失败恢复、结局（17 tests）
  - `map_controller_contract_test.gd` — 地图交互边界（8 tests）
  - `settings_manager_test.gd` — 设置管理器（3 tests）

## 默认验证方式

- 自动工作流开启时，不运行 Linux / WSL 侧测试。
- 本地默认保留最小 Windows 验证：
  - Rust 改动：Windows `cargo test`
  - Rust + GDExt API 改动：Windows `cargo build --features godot-extension`
  - GDScript / 场景 / UI 改动：Windows Godot `--headless --editor --quit` + Windows `GdUnit4` + Windows Godot 无头 + 必要的 Windows GUI 冒烟
- 昂贵测试优先迁到 GitHub Actions 的 Windows runner。
- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- `GdUnit4` 默认命令：

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

- 若本轮没有完成对应的 Windows 验证，就明确记录"未验证"。

---

## 测试现状概览

- Rust 自动化包含模块内单元测试、`cent-jours-core/tests/` 集成测试和 `proptest` 属性测试，Windows 基线合计 `211` tests。
- Godot 前端 `GdUnit4` `54/54` 回归，覆盖主菜单初始化、行动执行、存读档、难度恢复、设置音频滑条、战斗/接见/休整、政策冷却、地图交互等核心路径。
- `EventBus` 的 `unused_signal` 噪音已精准屏蔽。
- `.github/workflows/windows-validation.yml` 和 `tools/run_gdunit_windows.cmd` 已落地；`project.godot` 变更现在也会触发 Windows 验证链。

---

## 文档边界

- 本文档只保留当前技术基线、Steam 上线任务优先级、当前验证方式、当前技术债。
- 当前状态与接手约束统一写入 [docs/history/agent_handoff.md](docs/history/agent_handoff.md)。
- 多轮开发历史统一写入 [docs/history/development_logs/](docs/history/development_logs/)。
- 产品里程碑与对外版本状态统一写入 [docs/plans/product_plan.md](docs/plans/product_plan.md)。
