# Cent Jours — 开发优先级计划

> **更新**: 2026-03-24 v88
> **通用原则**: [docs/rules/development_principles.md](/mnt/e/projects/CentJours/docs/rules/development_principles.md)
> **快速接手**: [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md)
> **开发历史**: [docs/history/development_logs/development_log_001.md](/mnt/e/projects/CentJours/docs/history/development_logs/development_log_001.md)
> **可选自动工作流**: 仅在用户明确要求时阅读 [docs/rules/optional/agent_autonomous_workflow.md](/mnt/e/projects/CentJours/docs/rules/optional/agent_autonomous_workflow.md)

---

## 当前技术基线

- 项目已经有可玩的纵向切片，正式入口仍是 `src/ui/main_menu.tscn`，主链路 `TurnManager -> CentJoursEngine -> GameState -> UI` 已跑通。
- 当前内容规模为 `15` 名角色、`41` 个地图节点、`58` 条历史事件；补给、政治、历史日志、存档读档和主菜单主循环都已接通。
- Save / Load 已进入 `v3` 兼容阶段；最近一次权威回归基线是 Windows `211/211` Rust tests。
- Rust 规则层的第一批正式集成测试和属性测试已经落地；当前最大的工程缺口改成 Godot 前端 `GdUnit4` 和 Windows CI 还没接入。

## 当前技术优先级

| 优先级 | 项目 | 规模 | 决策理由 |
|--------|------|------|----------|
| **P0** | **补齐 Godot 前端 `GdUnit4 + smoke` 回归入口** | L | Rust 规则层第一批集成测试和属性测试已经补上，当前最脆弱的缺口转到主菜单、地图交互、存读档和弹窗状态流。 |
| **P0** | **建立 Windows GitHub Actions 重测试跑道** | M | 重测试应该上云，节省本地等待时间，并把 Windows 作为权威环境固化成可重复流水线。 |
| **P0** | **把 `docs/bugs` 中的关键问题转成可重复验证** | M | 修过的 bug 不转成自动化验证，后面还会重复出现。 |
| **P1** | **继续补强补给玩法的产品化表达与教学链** | L | 后勤已经是当前玩法主轴，但应建立在更稳的测试护栏之上。 |
| **P1** | **历史事件扩到 `100+` 并继续文本 QA** | L | 内容量仍是长局重玩性的核心约束。 |
| **P1** | **补前 10 天引导、失败归因、结局文本与关键 UI 文案统一** | M | 新玩家理解链仍不完整，需要结合玩法和日志一起收口。 |
| **P2** | **前端发布级 polish 与设置入口** | M | 地图、Tray、Sidebar 已基本可用，但还需要更稳的 Windows 真机收口。 |
| **P2** | **Windows 发布链路、资产替换与 Steam 提审准备** | L | 这条线建立在玩法和测试稳定之后。 |

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

- 接入 `GdUnit4`，建立第一批 Godot 自动回归。
- 保留现有 `engine_smoke_test_scene.tscn`，但不再把它当成唯一前端验证。
- 新增面向主菜单的分层测试：
  - `main_menu_load_smoke`：确认主场景、关键节点树、GDExt 初始化和基础绑定不坏
  - `main_menu_flow_smoke`：覆盖 `新局 -> 执行行动 -> 次日 -> 存档 -> 读档`
  - `map_interaction_smoke`：覆盖地图 hover、click 锁定、缩放、拖拽/复位、行军落点
  - `dialog_flow_smoke`：覆盖存读档、确认弹窗、失败恢复交互
  - `GdUnit4` 契约测试：覆盖 controller、formatter、主菜单状态同步
- Godot 测试策略采用“四层制”：
  - 无头 smoke：跑最小行为链，负责发现节点路径断裂、脚本报错、状态不同步
  - `GdUnit4` 控制器契约测试：验证节点绑定、可见性、状态切换、按钮可用性
  - `GdUnit4` 主流程测试：验证 `新局 / 执行行动 / 次日 / 存档 / 读档`
  - Windows 真机清单：布局、字体、滚动、遮挡、中文换行等视觉问题仍以人工验收为准

### 第 3 轮: 把 bug 修复、回归验证和玩法推进绑在一起

- 对照 [docs/bugs/bugs_check.md](/mnt/e/projects/CentJours/docs/bugs/bugs_check.md) 做剩余问题收口，并把每个问题绑定到一条 smoke、`GdUnit4` 用例或清单。
- 收口主菜单当前最脆弱的状态流：
  - 行动提交失败后的恢复
  - 存读档后的 phase / UI 同步
  - hover 与锁定详情的边界行为
  - `执行行动` 与 `进入次日` 的语义一致性
- 只有在这三类回归稳定后，再继续扩补给玩法、历史事件和发布级 polish。

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
  - GDScript / 场景 / UI 改动：Windows Godot 无头 + 必要的 Windows GUI 冒烟
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

- 若本轮没有完成对应的 Windows 验证，就明确记录“未验证”；不要用 Linux / WSL 结果补位。

## 当前阻塞与风险

- `测试体系缺口最大`：Godot 前端还没有接入 `GdUnit4` 并建立系统化自动回归。
- `Windows CI 还没落地`：当前重测试只能本地跑，速度慢，也不利于稳定复现。
- `主菜单状态流仍脆弱`：存读档、行动提交、地图 hover / 锁定和面板同步仍是高风险区。
- `内容线仍未收口`：事件量、教学链、失败归因和最终资产都还不够完整。

## 当前技术债

- Rust 全局仍有约 `54` 处 `unwrap()` / `expect()` / `panic!()`，集中在 `events/pool.rs` 与 `engine/state.rs`。
- `main_menu.gd` 和 `map_controller.gd` 仍偏大，后续还需要继续按职责下沉。
- `tests/monte_carlo_balance.py` 与 Rust 核心基线已漂移，不应继续作为平衡主依据。
- 多槽存档 UI 已接入，但元信息、覆盖确认和删除入口还不完整。

## 测试现状概览

- Rust 当前自动化包含模块内单元测试、`cent-jours-core/tests/` 集成测试和 `proptest` 属性测试，最近一次 Windows 基线合计 `211` tests。
- Godot 前端目前只有 `src/dev/engine_smoke_test_scene.tscn` 这一类 smoke 入口，还没有 `GdUnit4` 测试与系统化 UI 自动回归。
- 仓库里目前还没有 `.github/workflows/`，Windows CI 需要从零搭起来。

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
