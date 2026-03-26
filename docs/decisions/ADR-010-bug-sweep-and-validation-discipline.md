# ADR-010: Bug Sweep 与验证纪律收口

## 状态: 已采纳

## 背景

`docs/bugs/bugs_check.md` 汇总了最近一轮主菜单和地图交互问题，暴露出的不是单点代码错误，而是四类系统性问题：

1. UI 面板缺少固定边界与内部滚动，长文本会直接把页面撑坏。
2. 回合与 UI 的契约不够明确，提交行动失败时没有统一恢复链。
3. 验证纪律不足，容易把“代码写了”误当成“行为已收口”。
4. 测试分层缺失，Rust 规则层和 Godot 前端都缺少足够的自动回归护栏。

用户还提出了几条流程建议，需要明确哪些直接采纳，哪些要调整后采纳。

---

## 一、对建议的判断

### 1.1 测试工程视角建议

原建议：
- Rust 属性测试 + 项目集成测试加入 GitHub CI
- 本地只跑单元测试

结论：
- `采纳，并落实为 Windows 分层验证`

理由：
- Rust 属性测试适合纯规则层，尤其是 `engine/state.rs`、行军/战斗/事件窗口这类“输入空间大、规则边界硬”的模块，值得补。
- 项目集成测试进 CI 也是正确方向，但本项目真正容易出问题的是 Windows GDExt + Godot 场景链，所以 CI 不能只做 Linux。
- “本地只跑单元测试”仍不采纳。主菜单、回合链和 GDExt 接口是关键路径，本地至少保留最小 Windows smoke，否则会继续出现“单测都过，但场景一运行就炸”的问题。

最终落地：
- 测试拆成五层：
  - Rust 模块内单元测试
  - Rust 正式集成测试
  - Rust 属性测试
  - Godot 前端 `GdUnit4` 契约测试 + smoke
  - Windows 真机清单
- GitHub Actions 采用 Windows runner 跑重测试：
  - Rust 集成测试
  - Rust 属性测试
  - Godot `GdUnit4` 测试
  - Windows `cargo build --features godot-extension`
  - Windows Godot 无头 smoke
  - `GdUnit4` 前统一执行 Windows Godot `--headless --editor --quit`，刷新脚本类缓存
- 本地默认保持“最小必要验证”：
  - Rust 纯规则改动：Windows `cargo test`
  - 主菜单 / 回合 / GDExt 改动：Windows headless + 必要 smoke + 对应 `GdUnit4`

### 1.2 Godot 前端测试建议

新增判断：
- `采纳`

理由：
- 当前 Godot 侧只有一个 `engine_smoke_test_scene.tscn`，只能证明“核心引擎大体能跑”，不能覆盖主菜单、地图交互、存读档和弹窗恢复。
- 前端问题主要出在场景装配、节点路径和交互状态流，不适合一开始就靠大而全的 UI 单测框架解决。

最终落地：
- Godot 前端测试采用“四层制”：
  - 场景 / 主流程无头 smoke
  - `GdUnit4` 控制器契约测试
  - `GdUnit4` 主菜单状态流测试
  - Windows 真机清单
- `GdUnit4` 不是可选观察项，而是当前阶段的正式引入项。
- 在新 checkout / 新环境上运行 `GdUnit4` CLI 前，必须先执行一次 Windows Godot `--headless --editor --quit`，否则 CLI 可能无法识别 `GdUnit4` 全局类。
- `GdUnit4` 重点覆盖：
  - 主菜单初始化
  - `新局 -> 执行行动 -> 次日`
  - `存档 -> 读档`
  - 地图 `hover -> click 锁定 -> 取消锁定`
  - 弹窗确认 / 取消 / 失败恢复
- smoke 继续保留，用来发现节点路径断裂、脚本报错、GDExt 装配问题；它不替代 `GdUnit4`。

### 1.3 架构师视角建议

原建议：
- 检查项目耦合程度
- 判断是否需要重构

结论：
- `采纳，但限定为定向重构`

理由：
- 当前确实有耦合问题，尤其是 `main_menu.gd`、`layout_controller.gd`、`map_controller.gd` 一带。
- 但大范围翻修不是当前最优先。现在的正确路径是“边修 bug 边拆高风险职责”，而不是为了结构漂亮先做大重写。

最终落地：
- 继续按职责拆：
  - `layout`
  - `map interaction`
  - `sidebar`
  - `dialogs`
  - `save/load entry`
- 禁止在 bug sweep 期间顺手做大规模无验收重构

### 1.4 禁止项建议

原建议：
- 禁止 speculative implementation
- 禁止 implicit assumptions
- 禁止 missing error handling

结论：
- `全部采纳`

理由：
- 这三条正对应当前 bug 的成因。
- 本轮存读档弹窗报错就是典型的“没实际点开就假定 API 可用”。
- “增加军费后卡住”也是典型的“提交成功被默认假定，失败恢复链缺失”。

最终落地：
- UI 改动必须至少过一次真实场景加载
- 提交动作必须显式处理失败分支
- 新增入口必须至少走一遍最小交互链，而不是只让主场景能打开

---

## 二、额外补充的规则优化

除了用户提出的建议，本轮再补 6 条执行纪律：

### 2.1 长文本面板必须有固定边界

- 任何会持续增长或不可预测长度的文本区，都必须满足：
  - 固定或上限高度
  - 内部 `ScrollContainer`
  - 不允许依赖父容器无限膨胀

适用对象：
- `SituationPanel`
- `NarrativePanel`
- `MapInspector`
- 后续任何日志、提示、教程区

### 2.2 Hover 与锁定详情必须分层

- hover 只给轻量预览
- click 才给完整详情
- 两者位置保持连续，避免 UI 跳变

### 2.3 功能入口必须走一遍真实交互

新增或改动以下入口时，不能只靠代码审查：
- 存档
- 读档
- 新局
- 行动确认
- 地图选点
- 弹窗确认

至少要做一条真实入口验证，否则记为“未验证”

### 2.4 提交时必须隔离未完成工作线

- 有未完成 WIP 时，提交只 stage 当前闭环修复
- 不把截图、草稿文件、未完成功能线混进 bug fix 提交

### 2.5 每轮先做可闭环的一组问题

- 不是按文件切，而是按用户可感知闭环切
- 例如这轮把：
  - hover / inspector
  - narrative overflow
  - save/load popup
  - action -> next day 语义
  一起收口，而不是各改一半

### 2.6 测试先行于玩法扩展

- 任何新一轮玩法扩展前，先判断这条路径是否已经有对应自动化回归
- 若没有，先补最小测试护栏，再继续扩功能
- 例外只限于：
  - 阻塞当前验证的修复
  - 用户明确要求的紧急可视修复

---

## 三、决策

项目后续的 bug 修复与规则优化采用以下策略：

1. 采用 Windows 分层验证：本地最小验证 + GitHub Actions Windows 重测试
2. Godot 前端测试采用“`GdUnit4` + smoke + Windows 真机清单”
3. Windows 关键路径验证保留，不接受“本地只跑单测”的降级方案
4. `GdUnit4` 执行前必须先刷新 Windows Godot 脚本类缓存
5. 架构优化采用定向重构，不做脱离 bug 目标的大重写
6. 明确禁止：
   - speculative implementation
   - implicit assumptions
   - missing error handling
7. 长文本 UI 一律使用“固定边界 + 内部滚动”
8. hover 与 click 详情一律分层处理
9. 新入口必须经过一次真实交互验证或明确标注未验证
10. 提交必须隔离未完成工作线
11. 玩法扩展前先补最小自动化护栏

---

## 四、后果

正面影响：
- 主菜单和地图 UI 的稳定性会明显提高
- bug 修复轮的回归效率更高
- 重测试可以迁到云端，减少本地等待
- 文档、规则和提交边界会更一致

代价：
- 每轮验证成本会上升
- 一些“先写再说”的快改方式会被限制
- CI、`GdUnit4` 夹具和 smoke 场景都需要额外维护
- UI 调整需要更多真实运行校验，不能只看代码

但这比继续累积“主场景能打开，实际点两下就坏”的隐性债务更划算。
