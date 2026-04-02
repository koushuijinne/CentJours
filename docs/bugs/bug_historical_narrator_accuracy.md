# BUG-2026-03-28-HISTORICAL-NARRATOR

## 基本信息

- `ID`: `BUG-2026-03-28-HISTORICAL-NARRATOR`
- `标题`: 百日王朝叙事者历史准确性错误：当前仍以 Stendhal 作为在场日记叙事者
- `级别`: `P1`
- `状态`: `待处理`
- `来源`: 2026-03-28 历史审校

## 复现

1. 查看 `src/data/narratives/stendhal_diary.json`
2. 查看 `TurnManager -> EventBus -> MainMenu` 的叙事链路
3. 查看 `product_plan`、`ADR-008`、`interfaces` 等 live 文档

## 预期结果

- 百日王朝期间的在场日记叙事者应采用历史上真实在场且贴近拿破仑核心圈的人物
- 当前方案应迁移为 `Henri Gatien Bertrand` 宫廷总管日记
- `Stendhal` 只保留为文学风格和《红与黑》来源，不再承担游戏内在场 narrator 身份

## 实际结果

- 代码、数据、事件总线、UI 标题和多份 live 文档仍把 `Stendhal` 当作游戏内日记叙事者
- 这会把“文学参考人物”与“百日在场观察者”混成同一层

## 影响范围

- 叙事历史准确性
- 运行时命名与数据文件
- UI 文案与产品文档
- 后续 narrator 相关美术模板

## 根因

- 早期原型把《红与黑》的文学调性和游戏内 narrator 直接绑定
- 后续虽然强化了历史真实性，但没有把 narrator 设定一起迁移

## 修复方案

- 新建 `Bertrand diary` 的数据与文案方案，替代当前 `stendhal_diary` 运行时设定
- 迁移运行时命名：
  - `stendhal_diary.json`
  - `stendhal_diary_entry`
  - `GameState.stendhal_diary`
  - `DayReport.stendhal`
  - `CentJoursEngine::get_last_report()` 的 `stendhal` 键
- live 文档同步改为“大贝特朗 / Henri Gatien Bertrand 宫廷总管日记”
- `Stendhal` 保留在文学参考、Rouge/Noir 来源和书目引用层

## 当前 TODO 清单

- [ ] 设计 Bertrand diary 的叙事身份、语气边界和文本来源
- [ ] 评估是否需要存档兼容迁移
- [ ] 替换运行时 JSON / GDScript / Rust 字段名
- [ ] 替换 UI 标题、事件总线和测试说明
- [ ] 清理 live 文档中的“司汤达在场 narrator”表述
- [ ] 保留《红与黑》作为美学与命名来源，不再作为在场角色依据

## 附件

- 当前排查命中范围：`src/core/turn_manager.gd`、`src/core/game_state.gd`、`src/core/event_bus.gd`、`src/ui/main_menu.gd`、`cent-jours-core/src/narratives/mod.rs`、`cent-jours-core/src/engine/state.rs`、`cent-jours-core/src/lib.rs`、`docs/plans/product_plan.md`、`docs/decisions/ADR-008-historical-events-expansion.md`、`docs/interfaces.md`
