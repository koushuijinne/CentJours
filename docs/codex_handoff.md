# Codex Handoff

> **更新**: 2026-03-23
> **当前分支**: `claude/review-project-plan-vgQTN`
> **目标读者**: 新开会话后需要快速接手项目的 Codex / 协作者

---

## 1. 当前项目状态

- Rust 规则层与 Godot 前端已完成基础联调，主循环可跑通。
- Windows Godot 运行与 Windows 无头测试可用，当前默认只走 Windows 验证路径。
- `src/ui/main_menu.gd` 已从原始 `1531` 行收缩到当前 `436` 行，主菜单已基本转为编排器。
- `map / layout / tray / sidebar / dialogs` 五类 controller 已建立，主菜单子系统已完成两波拆分。

## 2. 当前最高优先级

- 主菜单第三波收尾：继续压纯 `src/ui/main_menu.gd` 的职责边界。
- 优先级高于新菜单页、引导页、额外动画和外围视觉扩散。
- 当前更值得做的是“收尾接口、命名、验证、轻量 polish”，而不是重新推翻现有结构。

## 3. 已完成的关键改动

- 主场景已脱离 smoke test 入口，`src/ui/main_menu.tscn` 是正式入口。
- `src/ui/main_menu/map_controller.gd` 已接管地图节点绘制、hover / click、`Map Inspector`。
- `src/ui/main_menu/layout_controller.gd` 已接管主题样式、响应式布局、RN 滑条与托盘布局。
- `src/ui/main_menu/sidebar_controller.gd` 已接管 `Current Situation`、`Marshal Loyalty`、`History & Narrative` 刷新。
- `src/ui/main_menu/tray_controller.gd` 已接管托盘卡片构建、选中态、冷却态和确认按钮联动。
- `src/ui/main_menu/dialogs_controller.gd` 已接管游戏结束、战斗参数、忠诚度强化弹窗。
- Windows 无头测试已经通过，修复过一次由 `decision_card.gd` 类型推断引起的连带编译失败。
- 已新增 `docs/codex_session_prompts.md`，并在计划文档中建立了 handoff / prompt 模板入口。

## 4. 当前已知问题

- `Decision Tray` 仍是“双滚动”状态：底部横向滚动条 + 右侧竖向滚动条同时存在。
- 主菜单存在中英混排，文案本地化还未统一。
- `Map Inspector` 长文本在部分节点上排版偏紧，仍有后续 polish 空间。
- `src/ui/main_menu.gd` 虽然已显著收缩，但仍混有回合流、UI 刷新和状态组装职责。

## 5. 下一步推荐任务

1. 继续拆分 `src/ui/main_menu.gd` 的回合流和 action dispatch。
2. 评估是否引入 `flow_controller` 或 `hud_presenter`，目标把主脚本压到 `260-320` 行。
3. 如果本轮不继续解耦，就转做主菜单 polish，优先处理托盘双滚动和中英混排。
4. 所有新改动优先落到叶子模块，不要把逻辑重新堆回 `main_menu.gd`。

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
- `src/ui/main_menu.gd`

## 9. 新会话接手时的注意点

- 不要默认回退工作区里的现有改动。
- 不要把 Linux / WSL 无头测试当成默认步骤。
- 若用户只问“还能不能继续拆”“现在有没有问题”，先基于当前代码和截图回答，不要先扩散到大改。
- 若继续拆主菜单，优先按模块和写入边界拆，而不是按页面名字拆。

## 10. 维护约定

- 每完成一轮开发后，默认同步更新本文件。
- 若新会话首条 prompt、接手入口或默认验证方式发生变化，同步更新 `docs/codex_session_prompts.md`。
