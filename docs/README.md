# 文档索引

项目文档按职责分为四类，并补了 3 份面向人类开发者的主入口文档：

- [README.md](README.md)
  仓库根入口，包含部署、运行、测试、roadmap、术语表和文档导航
- [docs/architecture.md](docs/architecture.md)
  系统结构、数据流、Save/Load 与验证边界
- [docs/interfaces.md](docs/interfaces.md)
  Rust / Godot / Save / Test 的核心接口契约

- [docs/plans/](docs/plans/)
  当前开发计划与产品里程碑
- [docs/rules/](docs/rules/)
  常规规则、接手模板与可选流程
- [docs/history/](docs/history/)
  交接、开发日志、历史扫描和历史审阅
- [docs/decisions/](docs/decisions/)
  ADR 架构决策记录
- [docs/bugs/bug_index.md](docs/bugs/bug_index.md)
  结构化 bug 索引、模板和当前代码问题记录
- [docs/reference_materials/](docs/reference_materials/)
  文学 / 美术参考素材归档，不直接作为运行时资源

默认接手顺序：

1. [docs/rules/development_principles.md](docs/rules/development_principles.md)
2. [docs/plans/dev_plan.md](docs/plans/dev_plan.md)
3. [docs/history/agent_handoff.md](docs/history/agent_handoff.md)
4. 相关 ADR 与任务相关代码

只有用户明确要求“自动工作流 / 零阻塞循环”时，才额外阅读 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)。
