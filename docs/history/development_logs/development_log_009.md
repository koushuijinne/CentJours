# Development Log 009 — i18n 框架 + 500 行拆分计划

> **日期**: 2026-04-13
> **分支**: `claude/review-project-status-05vxD`
> **任务**: S5-1 i18n 框架 / 硬约束 #10 文件拆分计划

## 本轮完成

### S5-1 i18n 框架引入
- 新建 `src/data/translations/game_text.csv`：45 个翻译键（zh + en 双列）
- `game_state.gd` 新增 `_load_translations()`：运行时 CSV 解析 + TranslationServer 注册
- `project.godot` 配置 `locale/fallback="zh"`
- `topbar_actions_controller.gd` 7 个按钮文本改为 `tr("UI_BTN_*")`
- `main_menu.gd` 结束今天按钮改为 `tr("UI_BTN_END_DAY")`
- 后续：继续抽取剩余硬编码字符串（预计 200+ 处）

### 硬约束 #10 — 超 500 行文件拆分计划
扫描发现 14 个文件超过 500 行，已在 dev_plan.md 记录拆分方案和优先级：
- P1: engine/state.rs (5303 行) — 拆 test + logistics
- P2: events/pool.rs, map_controller.gd, dialogs_controller.gd
- P3: 其余 8 个文件
- P4: monte_carlo.rs (独立工具)

## 验证
- Godot headless boot: 通过（i18n CSV 运行时加载成功）
