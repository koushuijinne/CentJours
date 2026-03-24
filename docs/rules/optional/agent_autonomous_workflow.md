# Agent 自动工作流

> **更新**: 2026-03-24
> **用途**: 只有在用户明确要求“自动工作流 / 零阻塞循环 / 连续循环”时才启用。
> **关系**: 本文件是 [docs/rules/agent_session_rules.md](/mnt/e/projects/CentJours/docs/rules/agent_session_rules.md) 的可选补充，不是默认入口。

---

## 0. 启用条件

- 只有在用户明确要求连续自动推进时，才读取并执行本文件
- 若用户没有明确提出该模式，默认回到常规规则文档
- 启用后，本文件在当前会话内优先于普通“先停下汇报”的习惯

## 1. 最高优先级规则

- 目标不是“完成一个回答”，而是“完成一轮高价值开发闭环，再自动决定下一轮”
- 只要仓库里仍有无阻塞的高价值 `P0 / P1` 子任务，就不要把总结、回顾、交接更新、提交 / 推送当成停机点
- 每轮完成后必须在对话里先输出一份“整个上下文窗口的压缩摘要”，覆盖当前分支、最新提交、核心基线、已完成改动、验证结果、已知风险、活跃子 agent 状态和下一轮目标，防止自动压缩时丢失上下文
- 这份对话内压缩摘要不是结束语，也不是停机点；输出后必须立刻继续下一轮
- 自动循环期间不要把这类压缩摘要包装成 `final` 式收尾；除非用户明确叫停或出现硬阻塞，否则继续使用过程内汇报并持续推进
- 允许必要时开子 agent，但必须先划清写入边界，并在任务结束后及时回收
- 允许直接修改文案，但必须遵守 ADR-008：直接、清楚、可考据，避免 reframing 句式
- 每轮结束后必须同时完成两件事：
  - 刷新 [docs/history/agent_handoff.md](/mnt/e/projects/CentJours/docs/history/agent_handoff.md) 的当前状态
  - 追加一条开发历史到 [docs/history/development_logs/](/mnt/e/projects/CentJours/docs/history/development_logs/)
- 只有出现 `硬阻塞`、用户明确说“停”，或当前确实没有更高价值且可执行的任务时，才允许结束

## 2. 一轮标准开发循环

1. 读取最小必要上下文
   - 必读：
     - `docs/rules/development_principles.md`
     - `docs/plans/development_plan.md`
     - `docs/history/agent_handoff.md`
   - 按任务补读：相关 ADR、历史审阅、目标模块代码
2. 建立当前真实基线
   - 看当前分支、工作区改动、测试状态、关键文件大小、当前阻塞
3. 自动选择最高价值任务
   - 先看 `docs/plans/development_plan.md` 当前 `P0 / P1`
   - 再看是否能在本轮形成闭环验证
4. 直接实现
   - 小步推进，优先闭环
   - 不在同一轮掺入无关大重构
5. 立即验证
   - Rust 改动跑 `cargo test`
   - UI / GDExt 改动走 Windows 原生验证
6. 同步文档
   - 更新 `docs/plans/development_plan.md`
   - 更新 `docs/history/agent_handoff.md`
   - 追加轮次记录到 `docs/history/development_logs/`
   - 仅在规则本身变化时更新本文件
7. 提交并推送
   - 默认执行 `git add -A`
   - 用清晰提交信息提交
   - push 到当前工作分支
8. 输出对话内压缩摘要
   - 用短而完整的方式复述“如果下一条消息前发生自动压缩，后续 agent 最少要知道什么”
   - 明确本轮真实验证边界，不能把未验证内容写成已验证
   - 若开过子 agent，写明哪些已回收，哪些仍在运行
9. 自动进入下一轮
   - 扫描剩余缺口
   - 选出下一条最高价值且无阻塞的任务
   - 直接继续，不等待额外提示

## 3. 默认优先级重排

1. 阻塞主循环、编译、测试或验证链路的问题
2. `docs/plans/development_plan.md` 当前 `P0` 项
3. 能把一条垂直切片从半成品推进到可演示 / 可提交的任务
4. 玩家可直接感知的高收益 UI / 文案 / 体验问题
5. 会明显放大返工成本的工程债
6. 文档、交接和工具链完善

若两个任务价值接近，优先选择：

- 更接近 Steam 首发阻塞项的任务
- 更容易闭环验证的任务
- 更不依赖用户拍板的任务

## 4. 何时直接决策

以下情况默认不问用户，直接做：

- 实现路径选择，不改变产品方向
- 文档收口、命名统一、路径修复、规则澄清
- 为形成本轮完整闭环所需的最小补充
- 存在更小、更稳、更符合现有架构的实现方式

以下情况才停下来问用户：

- 删除大量现有内容或高风险回退
- 多个产品方向之间需要取舍
- 需要外部账户、平台后台、付费资源或仓库外权限
- 当前工作区已有改动与本轮任务直接冲突，且无法安全避开

## 5. 阻塞处理

### 软阻塞

- 解析失败
- 编译失败
- 测试失败
- Windows 验证失败但可定位

处理方式：

- 立即修复
- 修后重跑同一验证
- 不切换任务

### 中阻塞

- 当前主线依赖 Windows 真机结果，但还有其他高价值任务可继续
- 当前模块信息不足，但其他模块可以独立推进

处理方式：

- 在 `agent_handoff` 写清阻塞与待验证步骤
- 立即切到不依赖该阻塞的下一条任务
- 不因“主线暂时卡住”而停机

### 硬阻塞

- 需要用户做产品取舍
- 需要外部账户或平台后台操作
- 需要确认是否会覆盖用户现有工作

处理方式：

- 只问最小必要问题
- 同时给出推荐选项和理由
- 等待用户明确答复

## 6. 默认验证矩阵

- Rust 规则层：`cd cent-jours-core && cargo test`
- Rust + GDExt API：Windows 侧重编扩展

```bash
cd /d E:\projects\CentJours\cent-jours-core
cargo build --features godot-extension
```

- GDScript / 场景 / UI：默认只走 Windows 原生验证

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- 视觉、布局、字号、滚动与动效问题以 Windows 真机为最终准绳
- 不把 Linux / WSL Godot 无头结果当成默认验证结论

## 7. 一轮完成的判定

满足以下条件才算一轮完成：

- 当前目标有清晰产出，不是半成品
- 已完成对应验证，或已明确记录无法验证的原因
- `development_plan` / `agent_handoff` / `development_logs` 已同步
- 已完成 `git add -A`、commit、push，或已记录无法 push 的原因
- 已经选出下一轮最高价值任务

以下情况都不算完成，必须继续：

- 只是写了当前状态总结或下一步建议
- 只是更新了交接文档或开发日志
- 只是 commit / push 了当前改动
- 只是发出一次回顾性汇报
