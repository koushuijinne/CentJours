#!/bin/bash
# Stop hook: 检查是否有未提交/未推送的改动，有则阻止停机
# exit 0 = 允许停机 | exit 2 = 阻止停机（stderr 反馈给 AI）

INPUT=$(cat)

# 防止无限循环：如果已经被拦过一次，放行
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

cd "$(echo "$INPUT" | jq -r '.cwd // "."')" 2>/dev/null || exit 0

# 检查是否有未提交的改动
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "工作区有未提交的改动，请先 commit 和 push。" >&2
  exit 2
fi

# 检查是否有未跟踪的新文件（排除常见忽略项）
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -5)
if [ -n "$UNTRACKED" ]; then
  echo "有未跟踪的新文件需要处理：$UNTRACKED" >&2
  exit 2
fi

# 检查是否有未推送的 commit
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$CURRENT_BRANCH" ]; then
  UNPUSHED=$(git log "origin/${CURRENT_BRANCH}..HEAD" --oneline 2>/dev/null | wc -l)
  if [ "$UNPUSHED" -gt 0 ]; then
    echo "还有 $UNPUSHED 个未推送的 commit，请先 push。" >&2
    exit 2
  fi
fi

# 一切干净，允许停机
exit 0
