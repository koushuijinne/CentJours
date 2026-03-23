# Codex Session Prompts

> **用途**: 保存新开会话时可直接复用的首条 prompt 模板，减少重复解释项目状态。

---

## 1. 新会话第一条 Prompt 固定模板

```text
先接手这个项目。请先只阅读以下文件，再开始判断当前状态：
- docs/development_principles.md
- docs/dev_plan.md
- docs/codex_handoff.md
- src/ui/main_menu.gd

请先完成这 4 件事：
1. 用 5 句话总结项目当前状态。
2. 说明当前最高优先级是什么。
3. 列出下一步最合理的 1-3 个开发任务。
4. 明确这轮默认验证方式，不要擅自切换到 Linux/WSL 无头测试。

额外要求：
- 不要先做大改。
- 不要先生成泛泛而谈的长方案。
- 如果需要继续开发，优先沿着 main menu 当前解耦方向推进。
```

## 2. 主菜单开发线启动模板

```text
继续接手主菜单开发线。先阅读：
- docs/development_principles.md
- docs/dev_plan.md
- docs/codex_handoff.md
- src/ui/main_menu.gd
- src/ui/main_menu/layout_controller.gd
- src/ui/main_menu/map_controller.gd
- src/ui/main_menu/tray_controller.gd
- src/ui/main_menu/sidebar_controller.gd
- src/ui/main_menu/dialogs_controller.gd

请先回答：
1. main_menu.gd 当前还剩哪些职责没有拆干净。
2. 如果继续拆，最合理的一刀应该落在哪个模块。
3. 这轮是否需要开 subagent；如果需要，按写入边界给出拆分。

要求：
- 默认主 agent 独占 src/ui/main_menu.gd 和 src/ui/main_menu.tscn。
- 不要先改地图和 Sidebar 视觉，除非这轮任务明确要求。
- 默认无头测试只跑 Windows。
```

## 3. 开发前回归检查模板

```text
开始改代码前，先做一轮最小上下文确认。请只检查：
- 当前分支
- src/ui/main_menu.gd 当前行数
- docs/codex_handoff.md 里的当前重点
- docs/dev_plan.md 是否与代码状态一致

然后输出：
1. 当前代码状态是否与 handoff 一致。
2. 如果不一致，先指出漂移点。
3. 给出这轮最小可执行任务，不要扩散范围。
```

## 4. Windows 无头验证模板

```text
本轮只执行 Windows 无头测试，不跑 Linux / WSL 无头测试。
请使用以下命令验证：

E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit

如果失败：
1. 报出具体文件和行号。
2. 优先做最小修复。
3. 修完后重新跑同一条 Windows 无头命令确认。
```
