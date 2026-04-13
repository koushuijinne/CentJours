# Agent 交接

> **更新**: 2026-04-13
> **约束和流程**: 见 `CLAUDE.md`（项目根目录，Claude Code 自动读取）
> **Codex 入口**: 见 `AGENTS.md`（项目根目录，Codex 默认读取）
> **开发历史**: 见 [docs/history/development_logs/](docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时使用 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)

---

## 核心基线

| 维度 | 状态 |
|------|------|
| 入口 | `src/ui/main_menu.tscn`，主循环 `TurnManager → CentJoursEngine → GameState → UI` 已接通 |
| 数据 | 15 角色 / 41 地图节点 / 100 历史事件 (S2-1 已达标) |
| 测试 | Windows `cargo test 215/215` + GdUnit4 `26/26` (main_menu_flow, 3 pre-existing flaky) + Windows CI + smoke |
| 自动工作流 | 已启用（2026-04-13），权限配置 `Bash(*)`，hook/tools/fmt 已修复 Windows 兼容 |
| 存档 | Save v4 兼容路径，旧 `fontainebleau_eve` → `tuileries_eve` 迁移 |
| 分支 | `claude/review-project-status-05vxD`（已合并 `auto/gameplay_update`） |

## 已完成的系统

- **补给系统**: 4 张补给政策牌，行军预判读 Rust 权威值，结算日志含补给解释
- **后勤决策辅助**: 引擎输出后勤态势/阶段目标/当日计划/三日节奏/区域链路/区域压力
- **难度系统**: Rust Difficulty 枚举 (Elba/Borodino/Austerlitz) + GDExtension + 新局 UI
- **失败归因**: GameState.key_decisions 追踪 + 游戏结束弹窗展示
- **音频框架**: AudioManager autoload (BGM 交叉淡入 + SFX 池)，缺音频资产
- **设置系统**: 窗口模式 + UI 缩放 + 音频滑条 + 锁定语义拆分
- **弹窗恢复链**: 外部关闭弹窗后自动回收 modal 锁定
- **行动面板语义**: 机动/决策预算提示 + 确认按钮切换 + 禁用原因
- **地图交互**: hover 预览 / click 锁定 + 空白点击清空 + 补给标注
- **前端拆分**: main_menu.gd 1025→890 行，7 个子控制器（+content_builder.gd 406 行）
- **弹窗状态机**: modal 统一锁定，存读档/设置/战斗/接见/结局弹窗有 GdUnit4 回归
- **教程链**: 结构化 10 阶段教程（JSON 数据驱动）覆盖 overview/movement/supply/politics/command_deviation/strategy/diplomacy/summary + 侧栏双层呈现 + 日志回看 + 版式护栏
- **百科与目标入口**: 红黑指数、合法性、外交进度、系统影响、结局路线和提高路径解释
- **战略指导层**: 顶栏外交进度、侧栏战略焦点/主要风险/派系压力、地图副标题路线提示已统一口径
- **验证链优化**: 已为 `fast / full / heavy-nightly` 引入 Godot 二进制缓存与日志上传机制
- **教程弹窗化**: 完成教程文本从侧栏向中央弹窗的迁移，注入操作指南并同步至 narrative log，通过 GdUnit4 防回归
- **日内行动节奏**: 1 机动槽 + 2 决策点 + 手动结束今天
- **多结局系统**: 7 种 GameOutcome + 外交进度 (0-100) + UI OUTCOME_TEXT 7 套文本
- **Codex harness**: 新增根 `AGENTS.md`、`tools/codex_doc_sync_guard.sh`、`tools/codex_round_check.sh`、`tools/codex_harness_status.sh`、`tools/codex_pick_next_task.py`、`tools/codex_round_summary.py`、`tools/codex_cycle.sh`、`tools/codex_validation_scope.py`、`tools/codex_light_guard.sh` 和可安装 `.githooks/pre-commit + pre-push`

## 当前最高优先级

1. `S0-1` 到 `S0-4` 作为默认验证链和 Codex harness 主线持续推进
2. `S1-1` 到 `S1-11` 作为真人试玩修复包同步推进
3. `S2-1` 历史事件扩到 100+ 条已降为最低优先级，暂不抢占主线

## 当前已知缺口

- ~~事件池~~ S2-1 已达标（100 条）
- 教程已覆盖三大核心（补给/政治/命令偏差），后续需加深中盘区域运营感
- 文本 QA 未收口（史实锚点、句式风格）
- 前端发布级 polish 和 Windows 真机验收未完成
- 最终资产仍是占位（地图底图、肖像、BGM、SFX）
- ~~叙事系统迁移~~ 已完成：Stendhal → Bertrand（文件重命名 + 文风重写 + 全量代码引用迁移）
- Codex harness 已能输出“下一条任务 / 压缩摘要 / 最小本地验证 / 推荐云端链”，但更细的文件到测试映射还没收口
- 补给、派系和结局之间的长期因果解释已接入顶栏/侧栏/地图副标题第一版，但还没覆盖更多中盘事件与区域任务链

## 写入边界

### 主 agent 独占

`main_menu.gd` / `main_menu.tscn` / `engine/state.rs` / `lib.rs` / `turn_manager.gd` / `event_bus.gd`

### 叶子模块

`map_controller.gd` / `layout_controller.gd` / `tray_controller.gd` / `sidebar_controller.gd` / `dialogs_controller.gd` / `main_menu_config.gd` / `decision_card.gd` / `ui_formatters.gd`

## 维护约定

- 本文件只保留当前状态和动态信息
- 硬约束和做事流程已合并到 `CLAUDE.md`
- Codex 使用根 `AGENTS.md`，不依赖 Claude 专用 `.claude/` hooks
- 多轮开发历史写入 [docs/history/development_logs/](docs/history/development_logs/)
