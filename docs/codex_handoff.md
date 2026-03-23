# Codex Handoff

> **更新**: 2026-03-23
> **当前分支**: `codex/overnight-project-advance`
> **目标读者**: 新开会话后需要快速接手项目的 Codex / 协作者

---

## 1. 当前项目状态

- Rust 规则层与 Godot 前端已完成基础联调，主循环可跑通。
- Windows Godot 运行与 Windows 无头测试可用，当前默认只走 Windows 验证路径。
- `Tier 2` 的行军最小闭环已基本打通：Rust `PlayerAction::March`、GDExt `process_day_march/get_adjacent_nodes`、TurnManager 同步、主菜单行军卡片、地图选点与确认流程已经接上。
- 地图行军模式现在直接吃引擎返回的 `available_march_targets`，并会高亮可达节点与出发路线，不再由前端私算邻接。
- 战役弹窗已接入当前位置上下文：会显示当前节点，并默认选中当前节点地形；`mountains/coastal/fortress` 等地形的 UI 选项与 GDExt 映射已补齐。
- `Tier 3.5` 已推进一轮：`coalition_troops_bonus`、`paris_security_bonus`、`political_stability_bonus` 现在会真正进入引擎状态机，不再被事件系统静默吞掉。
- `src/ui/main_menu.gd` 已从原始 `1531` 行收缩到当前 `523` 行，主菜单已基本转为编排器，但第三波解耦仍未收口。
- `map / layout / tray / sidebar / dialogs` 五类 controller 已建立，主菜单子系统已完成两波拆分。

## 2. 当前最高优先级

- 主菜单第三波收尾：把这轮新增的行军 / 战役上下文逻辑继续从 `src/ui/main_menu.gd` 外移。
- 在不推翻现有结构的前提下，继续补 `Tier 2.4` 和可独立前推的 `Tier 3` 子项。
- 优先级仍高于新菜单页、引导页、额外动画和外围视觉扩散。

## 3. 已完成的关键改动

- 主场景已脱离 smoke test 入口，`src/ui/main_menu.tscn` 是正式入口。
- `src/ui/main_menu/map_controller.gd` 已接管地图节点绘制、hover / click、`Map Inspector`。
- `src/ui/main_menu/layout_controller.gd` 已接管主题样式、响应式布局、RN 滑条与托盘布局。
- `src/ui/main_menu/sidebar_controller.gd` 已接管 `Current Situation`、`Marshal Loyalty`、`History & Narrative` 刷新。
- `src/ui/main_menu/tray_controller.gd` 已接管托盘卡片构建、选中态、冷却态和确认按钮联动。
- `src/ui/main_menu/dialogs_controller.gd` 已接管游戏结束、战斗参数、忠诚度强化弹窗。
- Windows 无头测试已经通过，修复过一次由 `decision_card.gd` 类型推断引起的连带编译失败。
- 已为 Rust 引擎新增 `napoleon_location` 存档同步、`PlayerAction::March`、`process_day_march()` 与 `get_adjacent_nodes()`。
- `TurnManager` 现在会把引擎权威的可达行军目标同步到 `GameState.available_march_targets`。
- 主菜单地图在行军模式下会高亮可达节点 / 路线，并在 Sidebar 给出无效目标与确认提示。
- 这轮已确认 Windows GDExt 改动后必须在 Windows 侧执行 `cargo build --features godot-extension`，否则 Godot 会加载到缺少导出符号的 DLL。
- 已清理 `cent-jours-core/src/lib.rs` 中大批 `VarDictionary::insert` 的 warning 噪音，Windows GDExt 构建输出显著变干净。
- `coalition_troops_bonus` 已接入 `coalition_force()`；`paris_security_bonus` / `political_stability_bonus` 已接入每日结算，并已纳入存档 / 读档一致性。
- 当前 Rust 测试数量已提升到 `131`，包含新增的事件效果状态承接测试。
- 已新增 `docs/codex_session_prompts.md`，并在计划文档中建立了 handoff / prompt 模板入口。
- 已新增 `docs/codex_overnight_plan.md`，用于定义夜间自动开发的循环机制与交付标准。

## 4. 当前已知问题

- `Decision Tray` 仍是“双滚动”状态：底部横向滚动条 + 右侧竖向滚动条同时存在。
- 主菜单存在中英混排，文案本地化还未统一。
- `Map Inspector` 长文本在部分节点上排版偏紧，仍有后续 polish 空间。
- `src/ui/main_menu.gd` 虽然已显著收缩，但仍混有回合流、UI 刷新、行军预览和战役上下文组装职责。
- 战役虽然已带上当前位置默认地形，但战斗规则本身仍未真正消费“当前地图位置”的战略含义；`Tier 2.4` 还没有完全做完。
- Windows Rust DLL 若未按 `--features godot-extension` 重编，Godot 会出现“`gdext_rust_init` / 新 API 不存在”的假性脚本错误。
- 夜间计划已正式加上“禁止自然收口停机”规则，但执行层仍取决于会话是否持续存活。

## 5. 下一步推荐任务

1. 继续拆分 `src/ui/main_menu.gd` 的回合流、行军预览和战役上下文组装。
2. 推进 `Tier 2.4`：让战斗与当前地图位置产生更真实的规则联系，而不只是默认地形。
3. 延续 `Tier 3.3`：在现有 `coalition_troops_bonus` 基础上，让联军动态化不只依赖日期，也响应战役与历史事件累计状态。
4. 若本轮不继续补战略层，就转做主菜单 polish，优先处理托盘双滚动和中英混排。

## 6. 当前结构与写入边界

### 主 agent 推荐独占

- `src/ui/main_menu.gd`
- `src/ui/main_menu.tscn`

### 叶子模块

- `src/ui/main_menu/map_controller.gd`
- `src/ui/main_menu/layout_controller.gd`
- `src/ui/main_menu/tray_controller.gd`
- `src/ui/main_menu/sidebar_controller.gd`
- `src/ui/main_menu/dialogs_controller.gd`
- `src/ui/components/decision_card.gd`
- `src/ui/main_menu/main_menu_config.gd`
- `src/ui/main_menu/ui_formatters.gd`

### 协作原则

- 主 agent 负责集成、装配、接口冻结和最终回归。
- subagent 按独立模块拆分，不要多人同时改 `main_menu.gd`。
- 若接口需要主入口配合，优先在回复里给出精确集成说明，再由主 agent 接回。

## 7. 验证要求

### 默认无头验证

- 只执行 Windows 无头测试，不跑 Linux / WSL 无头测试。
- 若本轮修改了 Rust GDExt API，先在 Windows 侧重编：

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

- 默认命令：

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

### 当前验证优先级

- 前端视觉问题以 Windows 真机截图为最终准绳。
- 无头测试主要用于脚本解析、资源装载、扩展初始化兜底。

## 8. 新会话最少必读文件

- `docs/development_principles.md`
- `docs/dev_plan.md`
- `docs/frontend_dev_plan.md`
- `docs/codex_handoff.md`
- `docs/codex_overnight_plan.md`
- `src/ui/main_menu.gd`

## 9. 新会话接手时的注意点

- 不要默认回退工作区里的现有改动。
- 不要把 Linux / WSL 无头测试当成默认步骤。
- 若用户只问“还能不能继续拆”“现在有没有问题”，先基于当前代码和截图回答，不要先扩散到大改。
- 若继续拆主菜单，优先按模块和写入边界拆，而不是按页面名字拆。

## 10. 维护约定

- 每完成一轮开发后，默认同步更新本文件。
- 若新会话首条 prompt、接手入口或默认验证方式发生变化，同步更新 `docs/codex_session_prompts.md`。
- 若碰到环境阻塞，先记录到本文件，再切到不依赖该阻塞的下一条高价值任务继续推进。
