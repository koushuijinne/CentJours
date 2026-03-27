# Cent Jours — 开发优先级计划

> **更新**: 2026-03-25 v90
> **通用原则**: [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
> **快速接手**: [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
> **开发历史**: [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时阅读 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前技术基线

- 项目已经有可玩的纵向切片，正式入口仍是 `src/ui/main_menu.tscn`，主链路 `TurnManager -> CentJoursEngine -> GameState -> UI` 已跑通。
- 当前内容规模为 `15` 名角色、`41` 个地图节点、`58` 条历史事件；补给、政治、历史日志、存档读档和主菜单主循环都已接通。
- Save / Load 已进入 `v3` 兼容阶段；最近一次权威回归基线是 Windows `211/211` Rust tests、Windows `GdUnit4 18/18`、Windows Godot 主项目无头和 smoke scene。
- Rust 规则层的第一批正式集成测试和属性测试已经落地；Godot 前端第一批 `GdUnit4` 回归也已接入，Windows GitHub Actions 工作流与仓库脚本也已落地。
- 面向人类开发者的三份核心入口文档已补齐：根 `README.md`、`docs/architecture.md`、`docs/interfaces.md`。
- 当前总目标已按 [ADR-011](/mnt/e/projects/CentJours/docs/decisions/ADR-011-core-loop-systemization-and-historical-depth.md) 固定为：核心玩法优化完成，并达到 Steam 可上线级别。

## 当前技术优先级

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|----------|
| **P0** | **补仓库根 `README.md` 与开发者统一入口** | M | 当前 `docs/` 更适合持续开发中的接手，不够适合第一次进入仓库的人类开发者。 |
| **P0** | **补 `architecture.md` 与 `interfaces.md`** | M | 运行时边界、存档契约、Rust / Godot 数据流目前主要分散在代码和 ADR 中，阅读成本偏高。 |
| **P0** | **规范 `docs/bugs/` 为结构化 bug 记录区** | S | 当前 bug 目录已有截图和历史记录，但缺少统一索引、模板和回归字段。 |
| **P0** | **继续收口 Windows GitHub Actions 验证链** | M | 已观察到首条成功 run，下一步要收紧 docs-only 触发和并发占用，把 Windows runner 留给真正的代码验证。 |
| **P0** | **把 `docs/bugs` 中的关键问题继续转成可重复验证** | M | 第一批主菜单与地图问题已经进入 `GdUnit4`，剩余 bug 仍要持续绑定自动化回归。 |
| **P0** | **继续扩 Godot `GdUnit4` 覆盖面** | M | 存读档槽位、槽位标签、新局确认/取消、读档取消、战斗取消、接见禁用态和结局弹窗已纳入回归，下一步继续补设置和更多失败恢复边界。 |
| **P1** | **继续补强补给玩法的产品化表达与教学链** | L | 后勤已经是当前玩法主轴，但应建立在更稳的测试护栏之上。 |
| **P1** | **历史事件扩到 `100+` 并继续文本 QA** | L | 内容量仍是长局重玩性的核心约束。 |
| **P1** | **补前 10 天引导、失败归因、结局文本与关键 UI 文案统一** | M | 新玩家理解链仍不完整，需要结合玩法和日志一起收口。 |
| **P2** | **前端发布级 polish 与设置入口** | M | 地图、Tray、Sidebar 已基本可用，但还需要更稳的 Windows 真机收口。 |
| **P2** | **Windows 发布链路、资产替换与 Steam 提审准备** | L | 这条线建立在玩法和测试稳定之后。 |
| **P2** | **低优先级：大本营互动层表达** | L | 只记录为后续扩展方向，不进入当前 Steam 首发主线。 |

## 未来三轮计划

### 第 1 轮: 先把测试底座补起来

- 当前状态：已完成
- 新建 Rust 正式集成测试入口：
  - `cent-jours-core/tests/save_load_flow.rs`
  - `cent-jours-core/tests/action_resolution_flow.rs`
  - `cent-jours-core/tests/march_preview_contract.rs`
- 引入属性测试框架，先覆盖最容易退化的不变量：
  - 补给、士气、疲劳的上下界
  - 行军预判与结算的基本一致性
  - 历史事件触发窗口不越界
  - 存档迁移不会重复写入或丢状态
- 把“修 bug 但不补验证”改成硬门槛：今后每修一类主菜单 bug，至少补一条 Rust 或 Godot 回归。

### 第 2 轮: 补 Godot 前端回归模型

- 当前状态：已完成
- `GdUnit4` 已接入项目，运行时最小集已落到 `addons/gdUnit4/`。
- 第一批 Godot 自动回归已建立：
  - `tests/godot/main_menu_flow_test.gd`
  - `tests/godot/map_controller_contract_test.gd`
- 已覆盖的前端行为：
  - 主菜单加载后的关键节点与默认状态
  - `执行行动 -> 次日`
  - `存档 -> 读档`
  - `新局` 确认弹窗与重开
  - 地图 hover 预览与 click 锁定详情分层
  - 地图缩放与右键复位
- 现有 `engine_smoke_test_scene.tscn` 继续保留，但不再是唯一前端验证。
- 已确认一条执行约束：在新 checkout / 新环境上跑 `GdUnit4` 前，要先执行一次 Windows Godot `--headless --editor --quit`，刷新脚本类缓存，否则 CLI 可能找不到 `GdUnit4` 全局类。

### 第 3 轮: 把 bug 修复、回归验证和玩法推进绑在一起

- 当前状态：已完成
- 建立 `.github/workflows/` 的 Windows 流水线，默认顺序为：
  - Windows Rust `cargo test`
  - Windows `cargo build --features godot-extension`
  - Windows Godot `--headless --editor --quit`
  - Windows `GdUnit4`
  - Windows Godot smoke scene
- 已新增仓库脚本 `tools/run_gdunit_windows.cmd`，把 `缓存刷新 -> GdUnit4` 顺序固化成单一入口。
- 已新增 `.github/workflows/windows-validation.yml`，在 Windows runner 上执行 Rust tests、GDExt build、`GdUnit4`、headless boot 与 smoke scene，并上传 `reports/`。
- 对照 [docs/bugs/bugs_check.md](/mnt/e/projects/CentJours/docs/bugs/bugs_check.md) 的继续收口，后续改成在这条 workflow 和本地脚本上迭代用例。

## Godot 部分怎么测试

- 当前策略改成：`GdUnit4 + smoke + Windows 真机`，三层都要，不是只做 smoke。
- Godot 前端测试建议按下面四层补齐：
  1. `场景加载 smoke`
     - 目标：场景能打开，关键节点路径存在，脚本不会在 `_ready()` 直接报错
  2. `主流程 smoke`
     - 目标：`新局 / 执行行动 / 次日 / 存档 / 读档 / 地图选点` 这些用户真实路径可重复执行
  3. `GdUnit4` 契约与状态流测试
     - 目标：验证 hover、click 锁定、地图缩放、弹窗确认、失败恢复、按钮状态、面板同步
  4. `Windows 真机清单`
     - 目标：字体、中文换行、遮挡、滚动、面板边界、按钮可达性
- `GdUnit4` 重点先覆盖：
  - `main_menu` 初始化后的关键节点和默认状态
  - `新局 -> 执行行动 -> 次日`
  - `存档 -> 读档`
  - 地图 `hover -> click 锁定 -> 取消锁定`
  - 弹窗打开 / 确认 / 取消 / 失败恢复
  - `DecisionTray` 的选中、禁用、提交后状态
- 现阶段仍不建议直接做像素级截图对比。布局和视觉问题继续交给 Windows 真机验收。
- 真正适合优先单元化的 Godot 侧对象，主要是：
  - formatter
  - 纯数据映射
  - 不依赖场景树的轻量控制器辅助函数

## 默认验证方式

- 自动工作流开启时，不运行 Linux / WSL 侧测试，包括 Linux `cargo test`、Linux Godot 无头和任何 WSL 侧补位验证。
- 本地默认保留最小 Windows 验证：
  - Rust 改动：Windows `cargo test`
  - Rust + GDExt API 改动：Windows `cargo build --features godot-extension`
  - GDScript / 场景 / UI 改动：Windows Godot `--headless --editor --quit` + Windows `GdUnit4` + Windows Godot 无头 + 必要的 Windows GUI 冒烟
- 昂贵测试优先逐步迁到 GitHub Actions 的 Windows runner：
  - Rust 集成测试
  - Rust 属性测试
  - Godot `GdUnit4`
  - Godot smoke
  - 关键流程回归
- 默认 Windows 无头命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- `GdUnit4` 前置缓存刷新命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --editor --path E:\projects\CentJours --quit
```

- `GdUnit4` 默认命令：

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

- 若本轮没有完成对应的 Windows 验证，就明确记录“未验证”；不要用 Linux / WSL 结果补位。

## 当前阻塞与风险

- `Windows CI 仍需继续收口`：首条成功 run 已出现，但旧的 docs-only push 仍会占用 runner；需要继续收紧触发策略和并发取消，避免无效排队。
- `主菜单状态流仍脆弱`：存读档标签格式化 bug 已修，存读档、行动提交、地图 hover / 锁定和面板同步仍是高风险区。
- `内容线仍未收口`：事件量、教学链、失败归因和最终资产都还不够完整。

## 当前技术债

- Rust 全局仍有约 `54` 处 `unwrap()` / `expect()` / `panic!()`，集中在 `events/pool.rs` 与 `engine/state.rs`。
- `main_menu.gd` 和 `map_controller.gd` 仍偏大，后续还需要继续按职责下沉。
- `tests/monte_carlo_balance.py` 与 Rust 核心基线已漂移，不应继续作为平衡主依据。
- 多槽存档 UI 已接入，但元信息、覆盖确认和删除入口还不完整。
- 人类开发者导向的主入口文档仍不完整：缺根 `README.md`，也缺长期维护的架构与接口文档。
- 代码命名与注释风格仍不统一：存在旧中文函数名和“关键路径说明不足”的问题，需渐进治理，而不是一次性大扫除。

## 测试现状概览

- Rust 当前自动化包含模块内单元测试、`cent-jours-core/tests/` 集成测试和 `proptest` 属性测试，最近一次 Windows 基线合计 `211` tests。
- Godot 前端当前已有 `GdUnit4` `18/18` 回归，已覆盖主菜单初始化、执行行动、存读档槽位、槽位标签文案、新局确认/取消、读档取消、叙事面板、区域任务显示、战斗弹窗取消、接见禁用态、结局弹窗显示/重开/天数截断和地图交互；另保留 `src/dev/engine_smoke_test_scene.tscn` smoke 入口。
- 仓库里现在已有 `.github/workflows/windows-validation.yml` 和 `tools/run_gdunit_windows.cmd`，Windows CI 与本地执行入口已经落地。

## 文档边界

- 本文档只保留当前技术基线、当前优先级、当前验证方式、当前技术债和当前三轮计划。
- 当前状态与接手约束统一写入 [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)。
- 多轮开发历史统一写入 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)。
- 产品里程碑与对外版本状态统一写入 [docs/plans/product_plan.md](/mnt/e/projects/CentJours/docs/plans/product_plan.md)。

<!--
旧三轮计划归档：

第 1 轮: 主菜单与地图交互稳定化
- 目标:
  - 清掉 hover / 锁定详情遮挡与跳位
  - 修掉存读档入口报错
  - 给长文本面板补固定边界和内部滚动
  - 收口“执行行动 -> 次日”的语义
- 当前状态:
  - 已完成

第 2 轮: 入口验证与场景契约硬化
- 目标:
  - 给存档 / 读档 / 新局 / 行动确认 / 地图选点补真实交互验证清单
  - 给关键 UI 入口补最小可复现 smoke 脚本或检查表
  - 补“提交失败后恢复交互”的统一护栏
- 验收:
  - Windows headless 主项目
  - Windows smoke scene
  - 至少一次 Windows GUI 启动冒烟

第 3 轮: 主菜单耦合继续下沉
- 目标:
  - 继续把 `main_menu.gd` 中的弹窗、顶栏入口、地图态同步拆到更清晰的职责边界
  - 避免后续 bug fix 再落回“大文件里顺手混改”
  - 给多槽存档补更完整的元信息与删除/覆盖细节
- 边界:
  - 只做定向重构
  - 不做脱离 bug / 入口稳定化目标的大重写
-->
