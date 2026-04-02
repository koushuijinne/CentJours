# ADR 汇总表

> 架构决策记录（Architecture Decision Records）。新的跨层架构调整、状态流改造、重要接口变化应继续追加。

| # | 标题 | 状态 | 一句话决策 | 影响范围 |
|---|------|------|------------|----------|
| [001](ADR-001-rust-gdextension.md) | Rust + GDExtension | 已采纳 | 业务逻辑全部在 Rust，GDScript 只做 UI 和信号转发 | 核心架构、测试、CI |
| [002](ADR-002-gamestate-readonly-cache.md) | GameState 只读缓存 | 已采纳 | GameState 是纯 UI 缓存，所有状态从 Engine → TurnManager → GameState 单向流动 | 数据同步、状态一致性 |
| [003](ADR-003-gdscript-native-class-integration.md) | GDScript 原生类集成 | 已采纳 | 移除 GDScript class_name 冲突，CentJoursEngine 懒初始化 | 项目解析、跨平台兼容 |
| [004](ADR-004-frontend-ux-fixes.md) | 前端 UX 修复 | 已采纳 | 修复叙事面板覆写、卡片动画、地图路线、颜色主题等体验问题 | UI/UX、叙事、地图渲染 |
| [005](ADR-005-expose-policy-cooldown-api.md) | 暴露政策冷却 API | 已采纳 | `get_state()` 包含 cooldowns 字段，前端移除冗余冷却跟踪 | Rust 接口、决策卡片 |
| [006](ADR-006-main-scene-presentation-stabilization.md) | 主场景展示稳定化 | 已采纳 | 三阶段修复顶栏裁切、托盘截断、侧栏压缩，基线 1280x720 | 主场景布局、响应式 |
| [007](ADR-007-map-hover-selection-state-machine.md) | 地图 Hover/选择状态机 | 已采纳 | 统一状态机 idle → hovering → selected，空白点击清除状态 | 地图交互、UI 状态 |
| [008](ADR-008-historical-events-expansion.md) | 历史事件扩到 100+ | 已采纳 | 三级事件体系 (major/normal/minor)，定义写作检查清单和参考文献 | 事件数据、叙事内容 |
| [009](ADR-009-tier4-content-polish-roadmap.md) | Tier 4 内容打磨路线 | 已采纳 | P1 事件扩充 → P2 文本 QA → P3 视觉打磨 → P4 发布流水线 | 项目路线、内容质量 |
| [010](ADR-010-bug-sweep-and-validation-discipline.md) | Bug 清扫与验证纪律 | 已采纳 | Windows-first 五层验证，禁止投机代码，结构化 bug 文档 | 测试、CI/CD、代码纪律 |
| [011](ADR-011-core-loop-systemization-and-historical-depth.md) | 核心循环系统化 | 已采纳 | 锁定产品定位为"百日政军危机模拟器"，定义 Steam 首发基线 | 产品范围、叙事视角 |
| [012](ADR-012-developer-documentation-operability.md) | 开发者文档可操作性 | 已采纳 | 建立 README + architecture + interfaces 三入口，CI 门禁文档同步 | 文档结构、开发者上手 |
