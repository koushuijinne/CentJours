# Codex Harness 适配方案

## 目标

在不修改 `CLAUDE.md` 和 `.claude/` 的前提下，为本地 Codex 增加一套可直接使用的 harness engineering。

## 为什么不能直接复用 Claude 版

### 入口不同

- Claude 版默认入口是 [CLAUDE.md](../../CLAUDE.md)
- Codex 在本仓库默认读取的是根 [AGENTS.md](../../AGENTS.md)
- 结论：`CLAUDE.md` 的约束内容能复用，但不能直接当 Codex 自动入口

### 机制不同

- Claude 版使用 [.claude/settings.json](../../.claude/settings.json) 定义 `Stop` 和 `PreToolUse` hooks
- 这些 hook 是 Claude Code 私有事件模型
- Codex 当前环境没有仓库级 `Stop` / `PreToolUse` 接口
- 结论：`.claude/hooks/` 的脚本逻辑可以借鉴，但不能直接指望 Codex 自动执行

## Codex 版结构

### 1. 单入口

- 新增根 [AGENTS.md](../../AGENTS.md)
- 作用：
  - 成为 Codex 的默认仓库入口
  - 内联项目基线、硬约束、默认验证和禁止事项
  - 约束 Codex 先读 `dev_plan.md` 和 `agent_handoff.md`

### 2. 文档同步守卫

- 新增 [tools/codex_doc_sync_guard.sh](../../tools/codex_doc_sync_guard.sh)
- 复用已有 [tools/check_doc_sync.py](../../tools/check_doc_sync.py)
- 行为：
  - 优先检查 staged 文件
  - 若没有 staged，则检查当前 working tree 变更
  - 代码改动未同步 `docs/` 或 `README.md` 时失败

### 3. 回合结束检查

- 新增 [tools/codex_round_check.sh](../../tools/codex_round_check.sh)
- 行为：
  - 检查工作区是否干净
  - 检查是否存在未推送 commit
  - 检查本地是否落后于远端
- 作用：
  - 替代 Claude `Stop hook` 的一部分效果
  - 让 Codex 在“本轮准备收口”前有一个显式检查入口

### 4. Harness 状态摘要

- 新增 [tools/codex_harness_status.sh](../../tools/codex_harness_status.sh)
- 行为：
  - 输出当前分支、HEAD、`core.hooksPath`
  - 输出 ahead/behind、staged/modified/untracked 计数
  - 输出当前是否存在文档变更
- 作用：
  - 把 Codex 当前本地 harness 状态变成显式信息
  - 便于 round 开始前和准备提交前快速检查

### 5. 可安装 git hooks

- 新增 [tools/install_codex_git_hooks.sh](../../tools/install_codex_git_hooks.sh)
- 新增 [.githooks/pre-commit](../../.githooks/pre-commit)
- 新增 [.githooks/pre-push](../../.githooks/pre-push)
- 安装后：

```bash
bash tools/install_codex_git_hooks.sh
```

- 结果：
  - 当前仓库会把 `core.hooksPath` 指向 `.githooks/`
  - 每次 `git commit` 前自动跑文档同步检查
  - 每次 `git push` 前自动跑 `codex_round_check.sh --pre-push`

## 这套方案的边界

### 已解决

- Codex 有了仓库内单入口
- 文档同步从“靠记忆”变成“可执行脚本 + 可安装 hook”
- 回合收口有了显式检查脚本
- Codex 现在可以显式查看本地 harness 状态，并在 push 前有一层本地门禁

### 没有伪装成已解决

- Codex 仍没有 Claude 那种仓库级 `Stop hook`
- “自动别停”仍然不能靠仓库配置强制实现
- 如果要真正外部驱动死循环，仍需要单独监督器或外部 orchestration

## 建议使用方式

### 日常开发

1. 先读 [AGENTS.md](../../AGENTS.md)
2. 读 [dev_plan.md](dev_plan.md)
3. 读 [agent_handoff.md](../history/agent_handoff.md)
4. 开发后先跑对应验证
5. 提交前跑：

```bash
bash tools/codex_doc_sync_guard.sh
```

6. 需要检查本地 harness 状态时跑：

```bash
bash tools/codex_harness_status.sh
```

### 安装本地 hooks

```bash
bash tools/install_codex_git_hooks.sh
```

### 一轮准备收口前

```bash
bash tools/codex_round_check.sh
```

## 后续可选增强

1. 为 `codex_round_check.sh` 增加压缩摘要模板输出
2. 在 `pre-push` 里按文件类型挂最小验证，而不只检查分支状态和文档同步
3. 若后续 Codex 暴露仓库级 hook 接口，再把这套脚本接回自动事件触发
