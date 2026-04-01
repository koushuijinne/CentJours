# Harness Engineering 改造方案

> **目标**: 把散落在 8+ 个文件里的 AI agent 约束重构为分层清晰、可自动执行的 harness 结构
> **原则**: 减少 AI 需要读的文件数、内联关键约束、用 hooks 替代"自觉遵守"

---

## 一、现状诊断

### 当前 AI 需要读的文件链

```
CLAUDE.md (63行, 入口)
  → development_principles.md (178行, 原则)
    → execution_checklist.md (105行, 检查清单)
  → dev_plan.md (253行, 计划)
  → agent_handoff.md (163行, 状态)
    → agent_session_rules.md (99行, 会话规则)
      → agent_session_prompts.md (102行, 提示词模板)
      → agent_autonomous_workflow.md (170行, 可选自动流)
  → ADR README (19行, 汇总表)
```

**总计 8 个文件、~1150 行**，AI 每次新 session 理论上要读完才能安全工作。

### 核心问题

| 问题 | 说明 |
|------|------|
| **入口太浅** | CLAUDE.md 只是跳板，关键约束藏在二三级文件里 |
| **约束散落** | 硬约束分布在 principles (§6)、handoff (写入边界)、session_rules (禁止行为) 三处 |
| **重复表述** | "不在 GDScript 复制 Rust 规则"出现在 CLAUDE.md、principles、session_rules 至少 3 次 |
| **状态与规则混杂** | agent_handoff 既有动态状态又有静态约束（写入边界、验证矩阵） |
| **无自动执行** | 全靠 AI "读了就遵守"，没有 hooks 强制检查 |
| **提示词模板冗余** | agent_session_prompts.md 本质上是 CLAUDE.md 应该做的事 |
| **execution_checklist 利用率低** | AI 几乎不会主动去翻这个文件 |

---

## 二、目标架构

### 三层 harness 设计

```
第一层：CLAUDE.md（自动读取，<150行）
  ├── 项目定位 + 架构（不变）
  ├── 硬约束（从 3 个文件合并去重，内联）
  ├── 当前基线（结构化数据，非散文）
  ├── 做事流程（精简版，替代 session_rules 核心）
  └── 关键目录 + 测试命令（不变）

第二层：按需读取
  ├── docs/plans/dev_plan.md（当前计划，AI 按任务读）
  ├── docs/history/agent_handoff.md（纯动态状态，去掉静态规则）
  └── docs/decisions/README.md（ADR 汇总，按需）

第三层：归档参考（不再要求 AI 主动读）
  ├── docs/rules/development_principles.md（保留，人类参考）
  ├── docs/rules/execution_checklist.md（合并进 CLAUDE.md 后降级）
  ├── docs/rules/agent_session_rules.md（合并进 CLAUDE.md 后降级）
  └── docs/rules/agent_session_prompts.md（被 CLAUDE.md 替代，可删）
```

### 改造前后对比

| 维度 | 改造前 | 改造后 |
|------|--------|--------|
| AI 必读文件数 | 3+（实际 8） | 1（CLAUDE.md）+ 按需 2 |
| 硬约束位置 | 散落 3 处 | CLAUDE.md 一处 |
| 基线数据格式 | 散文 | 结构化 key: value |
| 自动执行 | 无 | hooks 强制文档同步检查 |
| 提示词模板 | 独立文件 | 不再需要（CLAUDE.md 本身就是） |
| 总读取量 | ~1150 行 | ~150 行（第一层）+ ~400 行（按需） |

---

## 三、具体改造清单

### 3.1 重写 CLAUDE.md（核心）

新 CLAUDE.md 结构：

```markdown
# Cent Jours — 项目 Harness

## 项目
Godot 4 + Rust GDExtension 策略游戏：1815 拿破仑百日王朝。

## 架构
[保持原有架构图不变]

## 基线
tests_rust: 215
tests_gdunit4: 68
save_version: v4
characters: 15
map_nodes: 41
events: 58/100+
outcomes: 7
difficulty_levels: 3

## 硬约束（不可违反）
1. 规则真值在 Rust，不在 GDScript 复制
2. GameState 是只读缓存，不自行推导
3. 数据流单向：Engine → TurnManager → GameState → UI
4. 代码改动必须同步文档（CI 门禁）
5. Windows 是默认验证平台
6. 不为写实牺牲可读性和公平感
7. 不在核心循环未验证前堆砌外围复杂度
8. 文案遵守 ADR-008：直写、可考据、不 reframe

## 做事流程
1. 读 CLAUDE.md（本文件）了解约束
2. 按任务读 dev_plan.md 确认优先级
3. 读 agent_handoff.md 了解当前状态
4. 改代码前先读相关源文件
5. 改完跑测试：Rust → cargo test | GDScript → GdUnit4
6. 代码和文档同一个 commit，不拆开
7. 更新 dev_plan.md + agent_handoff.md

## 禁止
- 先提交代码再补文档
- GDScript 复制 Rust 规则
- 修改规则层不补测试
- 用 Linux/WSL 测试结果补位 Windows

## 关键目录
[保持原表不变]

## 测试命令
[保持原有不变，更新数字]

## 阻塞处理
- 软阻塞（编译/测试失败）：立即修复
- 中阻塞（依赖 Windows 真机）：记录后切任务
- 硬阻塞（产品方向/外部资源）：问用户

## 按需阅读
- docs/plans/dev_plan.md — 当前计划和优先级
- docs/history/agent_handoff.md — 动态项目状态
- docs/decisions/README.md — 架构决策汇总
- docs/rules/development_principles.md — 完整原则（27条）
```

### 3.2 瘦身 agent_handoff.md

**删除以下静态内容**（已合并进 CLAUDE.md）：
- "当前写入边界"章节 → 删除（约束已在 CLAUDE.md）
- "验证与 CI"章节 → 精简为一行链接
- 重复的硬约束描述

**保留纯动态内容**：
- 核心基线表（每轮更新数字）
- 已完成的系统列表
- 当前最高优先级
- 当前已知缺口

**目标**：从 163 行 → ~80 行

### 3.3 废弃 / 降级文件

| 文件 | 处置 |
|------|------|
| `agent_session_prompts.md` | **删除** — CLAUDE.md 本身就是最好的提示词模板，AI 自动读 |
| `agent_session_rules.md` | **降级为参考** — 核心规则已内联到 CLAUDE.md，文件头加 "已合并到 CLAUDE.md，本文件仅供人类参考" |
| `execution_checklist.md` | **降级为参考** — A/B/C 分级和五维度检查对 AI 实际帮助不大，人类需要时自行查阅 |
| `agent_autonomous_workflow.md` | **保留不变** — 仍然只在用户显式要求时启用 |

### 3.4 配置 hooks（可选，高价值）

创建 `.claude/settings.json`：

```json
{
  "hooks": {
    "PreCommit": [
      {
        "command": "python3 tools/check_doc_sync.py --files $(git diff --cached --name-only)",
        "description": "检查代码改动是否同步了文档"
      }
    ]
  }
}
```

这样 AI 提交代码时会自动被拦截，如果没更新文档就不能 commit。把"别忘了更新文档"从规则变成机制。

---

## 四、预期效果

| 指标 | 改造前 | 改造后 |
|------|--------|--------|
| AI 新 session 读取量 | ~1150 行 / 8 文件 | ~150 行 / 1 文件 + 按需 |
| 硬约束遗漏风险 | 高（散落 3 处） | 低（CLAUDE.md 一处） |
| 文档同步遗忘 | 靠自觉 | hooks 拦截 |
| 重复表述 | 3-4 处 | 0（单一来源） |
| 新 agent 上手时间 | 读 5 分钟（常漏读） | 读 1 文件即可工作 |

---

## 五、执行顺序

1. **重写 CLAUDE.md** — 把硬约束、流程、禁止事项内联，更新基线数字
2. **瘦身 agent_handoff.md** — 删除静态约束章节，只保留动态状态
3. **降级旧文件** — agent_session_rules.md 和 execution_checklist.md 加"已合并"标注
4. **删除 agent_session_prompts.md** — 功能被 CLAUDE.md 完全替代
5. **配置 hooks** — 创建 .claude/settings.json
6. **验证** — 新开 session 测试 AI 是否只读 CLAUDE.md 就能正确工作

---

## 六、风险与取舍

| 风险 | 缓解 |
|------|------|
| CLAUDE.md 变太长（>200行） | 严格控制，结构化格式替代散文 |
| 人类也需要详细原则 | development_principles.md 保留不删，只是 AI 不再必读 |
| hooks 可能误拦 | 先用 warning 模式，稳定后改 blocking |
| 旧 session 引用被删文件 | 文件降级而非删除，加重定向说明 |
