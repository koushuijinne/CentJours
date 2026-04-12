#!/bin/bash
# 自动开发循环脚本
# 运行说明：启动后，AI 将自动执行任务 -> 验证 -> 提交 -> 摘要 -> 下一轮

MAX_ROUNDS=20

for i in $(seq 1 $MAX_ROUNDS); do
  echo "=== Round $i ==="
  
  # 执行核心任务：
  # 1. 自动 pick 下一个 P0 任务
  # 2. 自动执行逻辑并更新代码
  # 3. 运行本地验证 (GdUnit4/Rust)
  # 4. 同步文档 (doc-sync-check)
  # 5. 提交改动并汇总状态
  
  # 注意：在 AI 对话中，我们将利用这一逻辑，通过连续的 Directive 调用实现
  # 这里是作为 Agent 的逻辑伪代码，实际执行由 Gemini CLI 主动调用工具链完成
  
  echo "Picking task..."
  TASK=$(python tools/codex_pick_next_task.py --focus gameplay)
  echo "Task: $TASK"
  
  # 这里由主 Agent 逻辑接管
  # 每次循环通过输出 Round Summary 保持状态一致性
  
  sleep 2
done
