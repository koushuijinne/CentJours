# Cent Jours — 前端开发优先级计划

> **更新**: 2026-03-23 v19
> **当前分支**: `claude/review-project-plan-vgQTN`
> **目标**: 用最少轮次把 Godot 入口从“占位页 + 联调脚本”推进到“可展示、可讲解、可继续绑定数据”的主场景
> **通用原则**: 项目长期稳定原则详见 `docs/development_principles.md`
> **快速接手**: 当前状态见 `docs/codex_handoff.md`，新会话首条 prompt 模板见 `docs/codex_session_prompts.md`

---

## 开发原则

> 项目级完整原则以 `docs/development_principles.md` 为准。本文只保留当前前端轮次最相关的关注点与验收要求。

### 一、当前轮前端关注原则

- `先骨架，后润色`：优先完成信息架构、布局层级、数据占位与交互流向。
- `Godot 薄展示层`：前端负责展示、交互和信号响应，不复制规则计算。
- `原型先行`：优先对齐 `docs/ui_prototype.html` 的结构，再做局部视觉再设计。
- `组件复用优先`：优先复用 `rn_slider.gd`、`decision_card.gd`、主题系统。
- `信息层级优先`：顶栏、地图区、侧栏、托盘要先讲清“现在看到什么、接下来能点什么”。
- `反馈至上`：每次点击、选中、确认、结算都应有可见反馈，而不是静默变化。
- `交接连续性`：每完成一轮开发后同步更新 `docs/codex_handoff.md`；若接手模板变化，再同步更新 `docs/codex_session_prompts.md`。

### 二、当前轮前端验收要求

- `主场景验收优先于菜单完整性`：先把核心 HUD / 战略界面做成可展示、可讲解、可继续接数据。
- `每轮必须可见`：每轮都要能在运行态肉眼看到变化，或能实际触发新交互。
- `分辨率先服务开发`：当前以 `1280x720` 开发调试为主，优先保证 Windows Godot 独立窗口可用。

## 执行前检查

- 本轮是否直接服务于“呈现主场景”，而不是先扩展外围菜单或后端能力。
- 本轮是否定义了可见验收结果，例如新增一块 HUD、一个容器分区或一条可点交互。
- 本轮是否优先复用现有组件、主题和 `docs/ui_prototype.html`，而不是重新发明界面结构。
- 本轮是否保持 Godot 作为薄展示层，避免把核心规则、数值结算或状态源写进场景脚本。
- 本轮结束后，是否需要同步更新 `docs/dev_plan.md`、`docs/codex_handoff.md` 和 `plan.md` 里的进度说明。
- 若接手方式或默认验证命令变化，是否需要同步更新 `docs/codex_session_prompts.md`。

---

## 当前前端基线（2026-03-22）

### 现状判断

- `TurnManager` 已注册为 autoload，与 `GameState`/`EventBus` 对齐
- `_start_game()` 在 `_ready()` 后触发真实回合 Dawn+Action Phase，顶栏显示引擎真实数值
- 确认按钮"执行行动 →"已接入 `TurnManager.submit_action()`，回合闭环打通
- Sidebar 叙事面板已接入 `stendhal_diary_entry` / `micro_narrative_shown` 信号
- 游戏结束时托盘自动禁用并显示结局文本

### 当前进度快照

```
F0  运行入口清理        ████████████ 100% ✅ 正式入口与 smoke test 已分离
F1  主场景结构骨架      ████████████ 100% ✅ 四区布局已可见
F2  HUD 数据展示        ████████████  95% ✅ 真实引擎状态 + RN 氛围 + 数值变化闪烁动效
F3  决策托盘交互        ████████████ 100% ✅ Rest 卡 + 政策卡 + hover scale + 回合闭环 + 引擎驱动真实冷却态（ADR-005）
F4  地图与侧栏占位      ████████████  95% ✅ 38节点数据驱动地图 + 派系趋势箭头 + 全将领忠诚度
F5  视觉统一与动效      ████████░░░░  55% 🔶 RN 氛围 + hover + 数值闪烁 + 节点分级样式
```

### 已有可复用资产

| 模块 | 文件 | 状态 |
|------|------|------|
| 主场景入口 | `src/ui/main_menu.tscn` | ✅ 已升级为正式主场景骨架 |
| 主题系统 | `src/ui/theme/cent_jours_theme.gd` | ✅ 可直接用于面板、按钮、文本配色 |
| Rouge/Noir 组件 | `src/ui/components/rn_slider.gd` | ✅ 信号驱动（已移除轮询） |
| 决策卡片组件 | `src/ui/components/decision_card.gd` | ✅ hover scale 动效已修复 |
| UI 原型 | `docs/ui_prototype.html` | ✅ 作为主场景布局蓝本 |
| 开发测试入口 | `src/dev/engine_smoke_test_scene.tscn` | ✅ 与正式入口解耦 |
| ADR-004 | `docs/decisions/ADR-004-frontend-ux-fixes.md` | ✅ 三轮修复决策记录 |

### 当前阻塞点

1. ~~主场景仍以 `GameState` 当前值做只读展示，尚未接入 `TurnManager` 的真实回合刷新。~~ **✅ 已解决**
2. ~~决策托盘已可见但尚未真正提交行动，仍停留在展示与选择态。~~ **✅ 已解决**
3. ~~右侧边栏叙事已接信号，但忠诚度仍显示固定 3 名将领。~~ **✅ 已解决**
4. ~~叙事文本被 `_refresh_ui()` 覆盖，玩家看不到司汤达日记。~~ **✅ 已解决**
5. ~~地图区仍是静态战略感占位，尚未读取 `map_nodes.json` 做数据驱动布局。~~ **✅ 已解决**：38 节点 + 完整边数据驱动
6. ~~派系支持度无趋势方向箭头。~~ **✅ 已解决**：趋势箭头 ↑/↓/→ 已接入
7. `src/ui/main_menu.gd` 已压到 `436` 行，但仍残留回合流、UI 刷新和状态组装职责，主菜单第三波收尾尚未完成。
8. ~~卡片冷却态目前仅为本回合视觉标记，引擎未暴露政策冷却 API~~ ✅ ADR-005 已实现：`get_state()` 返回 `cooldowns`，前端从 `GameState.policy_cooldowns` 读取真实剩余天数。
9. ✅ `ADR-006` 第一轮已通过 Windows `1280x720` 手动验收：顶栏无垂直裁切。
10. ✅ `ADR-006` 第一轮已通过 Windows `1280x720` 手动验收：托盘与卡片主体完整可见。
11. ✅ `ADR-006` 第一轮已通过 Windows `1280x720` 手动验收：Sidebar 三块面板可读，忠诚度名字列回归已修复。
12. ✅ `ADR-007` 已实现：地图节点不再弹出 Godot 默认黑底 tooltip，空白点击统一收口到 `idle`。

---

## 目标定义

### 本阶段目标

在 Windows 版 Godot 中尽快看到一个**像游戏主界面的主场景**，要求：

- 一进入运行态，就能看到完整的四区布局
- 顶栏显示日期、阶段、Legitimacy、Rouge/Noir、核心资源占位
- 地图区有背景、标题和若干节点占位
- 右侧边栏有将领/事件/叙事信息占位面板
- 底部决策托盘显示至少 3 张 `DecisionCard`
- 主场景不再依赖 `engine_smoke_test.gd` 作为入口脚本

### 非目标

- 暂不追求完整主菜单动画
- 暂不追求真实地图美术
- 暂不追求完整设置页 / 存档页 / 新手引导
- 暂不追求最终品质的字体、图标、音乐和粒子效果

---

## 已完成阶段归档（摘要）

- `Priority A`：正式入口与 smoke test 已分离，主场景四区骨架建立完成。
- `Priority B`：顶栏、Sidebar、地图占位已接入真实数据与数据驱动节点。
- `Priority C`：决策托盘与 `TurnManager` 已打通，真实冷却由 Rust 引擎驱动。
- `Priority D`：Windows `1280x720` 下顶栏、托盘、Sidebar 布局稳定性问题已收口。
- `Priority E`：地图标签去碰撞、hover 高亮、click 锁定详情、`Map Inspector` 已落地，并已通过 Windows 真机验收。

> 已完成任务的详细执行清单不再保留在本文中，历史细节以相关 ADR、提交记录和代码为准，避免前端计划文档持续膨胀。

---

## 里程碑判断

### F-GATE 1: 看起来像游戏了吗？ ✅ 通过

- [x] 一进入运行就能看到四区结构
- [x] 顶栏不是静态空壳
- [x] 底部有真实卡片组件
- [x] 右侧边栏开始承载信息
- [x] 主入口不再依赖 `engine_smoke_test.gd`

### F-GATE 2: 能完成一次可见交互了吗？ ✅ 通过

- [x] 点击一个行动卡片有反馈
- [x] 至少一个状态数值会更新
- [x] 地图节点支持 hover 预览与 click 锁定详情
- [x] 玩家能看懂“这不是菜单，而是主游戏界面”

---

## Priority F — 主菜单解耦重构（当前最高优先级）

### 本轮适用原则

- `Godot 薄展示层`
- `常量集中管理，避免硬编码`
- `结构问题优先于像素补丁`
- `DRY`
- `每轮必须可见`
- `视觉问题以目标平台真机收口`

### 为什么进入这一轮

- `src/ui/main_menu.gd` 原始规模达到 `1531` 行，明显超出“主场景编排器”的合理体量。
- 当前一个脚本同时负责布局、地图、Sidebar、托盘、弹窗、格式化和交互状态，继续叠加功能会显著提高回归风险。
- 第二轮功能已经完成并通过真机验收，现在最值得做的是把主菜单拆回“可持续维护”的结构，再继续扩展存档、引导、动画和更多地图交互。

### 第一波已落地（2026-03-22）

- 已新增 `src/ui/main_menu/ui_formatters.gd`
- 已新增 `src/ui/main_menu/main_menu_config.gd`
- 已新增 `src/ui/main_menu/sidebar_controller.gd`
- 已新增 `src/ui/main_menu/tray_controller.gd`
- `src/ui/main_menu.gd` 已从 `1531` 行收缩到 `1221` 行
- Sidebar 刷新、托盘构建/选中/冷却、文案格式化与展示常量已从主菜单主脚本抽离
- 地图控制、响应式布局和弹窗逻辑仍在 `main_menu.gd`，属于下一波解耦范围

### 第二波已落地（2026-03-22）

- 已新增 `src/ui/main_menu/map_controller.gd`
- 已新增 `src/ui/main_menu/layout_controller.gd`
- 已新增 `src/ui/main_menu/dialogs_controller.gd`
- `src/ui/main_menu.gd` 已从 `1221` 行继续收缩到 `436` 行
- 地图加载、标签去碰撞、hover / click 状态机与 `Map Inspector` 已迁入 `map_controller.gd`
- 静态 UI、主题样式、RN 滑条和响应式布局已迁入 `layout_controller.gd`
- 游戏结束、战斗参数与忠诚度强化弹窗已迁入 `dialogs_controller.gd`
- 主菜单主脚本已基本收缩成编排器：保留节点装配、回合流、信号绑定与顶层刷新
- Windows 无头测试已通过，说明第二波总装没有引入新的主菜单脚本加载错误
- 当前验证原则已收紧：无头测试只执行 Windows 环境，不再要求 Linux / WSL 补充无头验证

### 本轮目标

把 `main_menu.gd` 从“大一统脚本”收缩成**主场景编排器**，目标是：

- `main_menu.gd` 只保留节点装配、信号绑定、顶层调度
- 地图、托盘、Sidebar、弹窗、格式化和配置从主文件中拆出
- 后续功能开发优先落在独立模块，而不是继续堆回主菜单脚本

### 目标架构

#### 1. `main_menu.gd`：只保留主场景编排

保留职责：

- `_ready()` 及初始化顺序
- 场景节点引用
- `TurnManager` / `GameState` / `EventBus` 顶层信号绑定
- 将状态变化分发给子模块
- 统一的顶层刷新入口

移出职责：

- 地图绘制与交互
- 决策托盘构建与选中逻辑
- Sidebar 三块面板刷新
- 响应式布局计算
- 文案格式化和常量表
- 各类弹窗逻辑

#### 2. `src/ui/main_menu/map_controller.gd`

职责：

- 地图节点绘制
- 标签去碰撞与锚点计算
- hover / click 状态
- 相邻路线高亮
- `Map Inspector` 内容刷新

已落地。

#### 3. `src/ui/main_menu/tray_controller.gd`

职责：

- 决策卡片构建与复用
- 选中态 / 冷却态刷新
- 确认按钮联动
- 与 `TurnManager.submit_action()` 的展示层对接

#### 4. `src/ui/main_menu/sidebar_controller.gd`

职责：

- `Current Situation`
- `Marshal Loyalty`
- `History & Narrative`

只负责右侧面板内容更新，不负责地图或托盘状态。

#### 5. `src/ui/main_menu/layout_controller.gd`

职责：

- 主场景响应式布局
- 最小高度 + 弹性分配
- 顶栏 / 地图区 / 托盘 / Sidebar 的尺寸推导

已落地。

#### 6. `src/ui/main_menu/dialogs_controller.gd`

职责：

- 游戏结束遮罩与结局面板
- 战斗参数弹窗
- 忠诚度强化弹窗
- 通过回调与主菜单编排器协作，而不是直接绑死 `TurnManager`

已落地。

#### 7. `src/ui/main_menu/ui_formatters.gd`

职责：

- 数字格式化
- phase / terrain / outcome 等文案映射
- 节点与派系显示文本

把纯格式化函数从主脚本剥离，降低阅读负担。

#### 8. `src/ui/main_menu/main_menu_config.gd`

职责：

- `PRIORITY_POLICY_IDS`
- `POLICY_EMOJIS`
- `POLICY_EFFECTS`
- `OUTCOME_TEXT`
- `TERRAIN_OPTIONS`
- 其他主菜单展示常量

目标是把散落在主脚本顶部的前端配置集中收敛。

### 当前状态

- `ui_formatters.gd`：已落地
- `main_menu_config.gd`：已落地
- `sidebar_controller.gd`：已落地
- `tray_controller.gd`：已落地
- `map_controller.gd`：已落地
- `layout_controller.gd`：已落地
- `dialogs_controller.gd`：已落地
- `main_menu.gd`：已从 `1531` 行降到 `436` 行，已基本降为编排器

### 推荐拆分顺序

1. `ui_formatters.gd` + `main_menu_config.gd`
2. `sidebar_controller.gd` + `tray_controller.gd`
3. `map_controller.gd`
4. `layout_controller.gd`
5. `dialogs_controller.gd`
6. 把 `main_menu.gd` 压成纯编排入口

### 本轮验收标准

- `src/ui/main_menu.gd` 已明显收缩，且主菜单总装后不引入功能回归
- 新模块职责边界清晰，不出现地图 / Sidebar / 托盘相互直接调用
- Windows 无头测试继续通过：
  `E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit`
- Windows Godot 真机运行不出现第一轮和第二轮的回归

### 本轮非目标

- 暂不新增 Rust 接口
- 暂不做地图行军、战斗位置联动
- 暂不扩展新的前端页面
- 暂不做存档系统和新手引导

---

## 地图交互状态机收尾

- `ADR-007` 已落地：
  - 地图热点不再使用 Godot 默认黑底 tooltip
  - `Map Inspector` 成为唯一详情反馈源
  - 点击地图空白时，无论当前是 `hover` 还是 `selected`，都统一收口到 `idle`

> 详见 `docs/decisions/ADR-007-map-hover-selection-state-machine.md`。

## 第二轮完成判断

- [x] 北部默认标签已从“大面积互压”改善到可读状态
- [x] `hover` 预览与 `click` 锁定详情均已跑通
- [x] `Map Inspector` 已成为唯一详情反馈源
- [x] 空白点击统一收口到 `idle`
- [x] 第二轮不引入第一轮顶栏、托盘、Sidebar 的回归

结论：第二轮可以正式标记为**完成**。

---

## 建议执行顺序（下一轮）

1. Priority F：主菜单解耦重构
2. C2 剩余：顶栏/托盘进场动画、面板 hover 统一
3. 存档/读档 UI 入口
4. 新手引导（前 10 天隐式教程提示）

---

## 一句话判断

主场景前两轮功能目标已经基本达成，当前最大的风险不再是“少一个功能”，而是 `main_menu.gd` 过大导致后续任何新功能都在放大维护成本。下一轮应先做主菜单解耦，而不是继续往这个单文件里加逻辑。
