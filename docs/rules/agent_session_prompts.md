# Agent 会话提示词模板

> **用途**: 保存新开会话时可直接复用的首条提示词模板，减少重复解释项目状态。

---

## 1. 普通接手模板

```text
先接手这个项目。请先只阅读以下文件，再开始判断当前状态：
- docs/rules/development_principles.md
- docs/plans/development_plan.md
- docs/history/agent_handoff.md
- docs/decisions/ADR-008-historical-events-expansion.md
- docs/history/historical_event_review.md

请先完成这 4 件事：
1. 简要总结项目当前状态。
2. 列出离项目上线 Steam 还需哪些开发任务，并按优先级排序。
3. 明确这轮默认验证方式，不要切换到 Linux / WSL Godot 无头测试。
4. 给出这轮最小可执行任务，并直接开始实现。

额外要求：
- 不要先做大改。
- 不要先生成泛泛而谈的长方案。
- 默认不启用自动工作流；只有我明确要求时才读取可选规则。
- 允许修改文案，但必须按 ADR-008 直写：直接、清楚、可考据；避免 reframing 句式。
```

## 2. 显式启用自动工作流模板

```text
先接手这个项目，并显式启用自动工作流。请先只阅读以下文件：
- docs/rules/development_principles.md
- docs/plans/development_plan.md
- docs/history/agent_handoff.md
- docs/rules/optional/agent_autonomous_workflow.md
- docs/decisions/ADR-008-historical-events-expansion.md
- docs/history/historical_event_review.md

要求：
- 按可选自动工作流的零阻塞规则连续推进。
- 每轮同步当前状态到交接文档，并把开发历史追加到开发日志。
- 允许必要时开子 agent，但要给出明确写入边界并及时回收。
- 只有出现硬阻塞或我明确叫停时，才允许停止循环。
```

## 3. 主菜单开发线模板

```text
继续接手主菜单开发线。先阅读：
- docs/rules/development_principles.md
- docs/plans/development_plan.md
- docs/history/agent_handoff.md
- src/ui/main_menu.gd
- src/ui/main_menu/layout_controller.gd
- src/ui/main_menu/map_controller.gd
- src/ui/main_menu/tray_controller.gd
- src/ui/main_menu/sidebar_controller.gd
- src/ui/main_menu/dialogs_controller.gd

请先回答：
1. `main_menu.gd` 当前还剩哪些职责没有拆干净。
2. 如果继续拆，最合理的一刀应该落在哪个模块。
3. 这轮是否需要开子 agent；如果需要，按写入边界给出拆分。

要求：
- 默认主 agent 独占 `src/ui/main_menu.gd` 和 `src/ui/main_menu.tscn`。
- 不要先改地图和 Sidebar 视觉，除非这轮任务明确要求。
- 默认只跑 Windows 验证。
```

## 4. 开发前回归检查模板

```text
开始改代码前，先做一轮最小上下文确认。请只检查：
- 当前分支
- `src/ui/main_menu.gd` 当前行数
- `docs/history/agent_handoff.md` 里的当前重点
- `docs/plans/development_plan.md` 是否与代码状态一致

然后输出：
1. 当前代码状态是否与交接文档一致。
2. 如果不一致，先指出漂移点。
3. 给出这轮最小可执行任务，不要扩散范围。
```

## 5. Windows 验证模板

```text
本轮只执行 Windows Godot 验证，不跑 Linux / WSL Godot 无头测试。
请使用以下命令验证：

E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit

如果失败：
1. 报出具体文件和行号。
2. 优先做最小修复。
3. 修完后重新跑同一条 Windows 无头命令确认。
```
