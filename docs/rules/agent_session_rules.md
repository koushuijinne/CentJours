# Cent Jours — Agent 会话规则（已合并）

> **状态**: 核心规则已合并到项目根目录 `CLAUDE.md`。本文件仅供人类参考，AI agent 不再需要主动阅读。
>
> **原用途**: 约束 agent 在本仓库中的默认开发行为、文档同步边界和提交闭环。
> **说明**: 如用户明确要求连续自动循环，读取 [docs/rules/optional/agent_autonomous_workflow.md](docs/rules/optional/agent_autonomous_workflow.md)。

---

## 文档职责

| 文件 | 只记录什么 |
|------|------------|
| `docs/plans/dev_plan.md` | 当前技术基线、当前技术优先级、默认验证方式、当前技术债 |
| `docs/plans/product_plan.md` | 产品里程碑、对外版本状态、里程碑通过条件 |
| `docs/history/agent_handoff.md` | 当前状态、当前分支、当前优先级、当前验证要求、接手约束 |
| `docs/history/development_logs/` | 多轮开发历史、每轮变更摘要、验证和下一步 |
| `docs/rules/agent_session_prompts.md` | 新会话首条提示词模板 |
| `docs/rules/development_principles.md` | 长期稳定的项目原则 |
| `docs/rules/optional/agent_autonomous_workflow.md` | 仅在用户明确要求时启用的自动循环规则 |

## 代码注释规则

- 新增或修改的代码应保持易读；当代码块本身不够直观时，补一条简短中文注释说明意图
- 不要为了形式而加注释；重复代码字面含义的注释没有价值
- 如果文件格式本身不支持注释，用清晰命名和结构表达意图

## 完成一轮代码任务后的必做清单

### 1. 同步文档

- 更新 `docs/plans/dev_plan.md`
  - 只写当前技术基线、当前优先级、默认验证方式和当前技术债
- 按需要更新 `docs/plans/product_plan.md`
  - 仅在本轮确实改变里程碑状态或对外版本描述时更新
- 更新 `docs/history/agent_handoff.md`
  - 只保留当前状态、当前优先级、当前验证方式和接手约束
- 追加一条开发历史到 `docs/history/development_logs/`
  - 遵守 `500` 行上限，接近上限就新建下一份日志
- 如果接手模板变了，更新 `docs/rules/agent_session_prompts.md`
- 如果规则本身变了，再更新规则文档；默认不要顺手改可选自动工作流

### 2. 代码质量自查

- 检查新增逻辑是否重复已有实现
- 检查 GDScript 是否越界承担了 Rust 规则层逻辑
- 检查新增 `Dictionary` / `Array` 接口是否写清了键名契约
- 检查文案改动是否遵守 ADR-008 的直写原则

### 3. 验证

- Rust 修改：默认使用 Windows 侧 `cargo test`
- Rust + GDExt API 改动：补 Windows 侧扩展构建
- Godot 前端测试：采用 `GdUnit4 + smoke + Windows 真机`
- GDScript / 场景 / UI 改动：使用 Windows Godot 验证
- 本地运行 `GdUnit4` 时，默认走 `tools/run_gdunit_windows.cmd`
- 不把 Linux / WSL Godot 无头结果当成默认结论

### 4. 提交闭环

- 文档与代码放在同一次 commit，不拆开
- 提交信息使用清晰前缀：`feat` / `fix` / `refactor` / `docs` / `chore`
- 默认及时 push，不堆积本地提交
- 每一轮结束前都要先在对话里输出一份“整个上下文窗口的压缩摘要”，至少覆盖当前分支、最新提交、核心基线、已完成改动、验证边界、已知风险、子 agent 状态和下一轮目标，防止后续上下文压缩卡住

## 禁止行为

- 完成代码后不更新 `development_plan` / `agent_handoff` / `development_logs` 就提交
- 先提交代码，再单独补文档
- 在 GDScript 层复制 Rust 已有的业务规则
- 修改规则层却不补验证
- 默认启用自动工作流；只有用户明确要求时才启用

## 默认开发原则

| 原则 | 判断标准 |
|------|----------|
| **DRY** | 同一条规则是否被复制到多个地方维护 |
| **GDScript 薄层** | 无 UI 时这段逻辑是否仍然有意义 |
| **单一状态源** | GDScript 是否在自行重算引擎已有状态 |
| **KISS** | 是否用更复杂的结构解决了简单问题 |
| **YAGNI** | 这项工作是否对当前迭代真正必要 |

## 阻塞处理

- `软阻塞`：解析 / 编译 / 测试失败，先修复再继续
- `中阻塞`：当前主线卡住但还有别的高价值任务，记录到交接文档后切任务
- `硬阻塞`：涉及产品方向取舍、外部资源或会覆盖用户现有工作时，再停下来问用户

## 核心路径

| 路径 | 用途 |
|------|------|
| `docs/plans/` | 当前开发计划与产品里程碑 |
| `docs/rules/` | 常规规则、模板与可选流程 |
| `docs/history/` | 交接、开发日志、历史扫描和历史审阅 |
| `docs/decisions/` | ADR 架构决策记录 |
| `cent-jours-core/src/` | Rust 游戏逻辑 |
| `src/core/` | GDScript 薄层 |
| `src/data/` | 静态游戏数据 |
