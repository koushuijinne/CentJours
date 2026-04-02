# Agent 交接

> **更新**: 2026-04-01
> **约束和流程**: 见 `CLAUDE.md`（项目根目录，Claude Code 自动读取）
> **开发历史**: 见 [docs/history/development_logs/](docs/history/development_logs/)
> **可选自动工作流**: 仅在用户明确要求时使用 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)

---

## 核心基线

| 维度 | 状态 |
|------|------|
| 入口 | `src/ui/main_menu.tscn`，主循环 `TurnManager → CentJoursEngine → GameState → UI` 已接通 |
| 数据 | 15 角色 / 41 地图节点 / 58 历史事件 (major 16 / normal 35 / minor 7) |
| 测试 | Windows `cargo test 215/215` + GdUnit4 `68/68` + Windows CI + smoke |
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
- **前端拆分**: main_menu.gd 1025→684 行，6 个子控制器
- **弹窗状态机**: modal 统一锁定，存读档/设置/战斗/接见/结局弹窗有 GdUnit4 回归
- **教程链**: 前 10 天弹窗 + 侧栏双层呈现 + 日志回看 + 版式护栏
- **百科入口**: 红黑指数、合法性、系统影响解释
- **日内行动节奏**: 1 机动槽 + 2 决策点 + 手动结束今天
- **多结局系统**: 7 种 GameOutcome + 外交进度 (0-100) + UI OUTCOME_TEXT 7 套文本

## 当前最高优先级

1. `S1-1` 到 `S1-11` 作为真人试玩修复包同步推进
2. `S2-1` 历史事件扩到 100+ 条
3. 持续维持 Windows CI + Rust 测试 + GdUnit4 回归

## 当前已知缺口

- 事件池距离 `100+` 目标还差 `42` 条
- 补给教学和区域运营感仍需加深
- 文本 QA 未收口（史实锚点、句式风格）
- 前端发布级 polish 和 Windows 真机验收未完成
- 最终资产仍是占位（地图底图、肖像、BGM、SFX）
- 叙事系统需从"司汤达日记"迁移为"贝特朗日记"（18 文件 96 处引用）

## 写入边界

### 主 agent 独占

`main_menu.gd` / `main_menu.tscn` / `engine/state.rs` / `lib.rs` / `turn_manager.gd` / `event_bus.gd`

### 叶子模块

`map_controller.gd` / `layout_controller.gd` / `tray_controller.gd` / `sidebar_controller.gd` / `dialogs_controller.gd` / `main_menu_config.gd` / `decision_card.gd` / `ui_formatters.gd`

## 维护约定

- 本文件只保留当前状态和动态信息
- 硬约束和做事流程已合并到 `CLAUDE.md`
- 多轮开发历史写入 [docs/history/development_logs/](docs/history/development_logs/)
