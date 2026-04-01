#!/bin/bash
# PreToolUse hook (Bash git commit): 检查代码改动是否同步了文档
# exit 0 = 放行 | exit 2 = 阻止（stderr 反馈给 AI）

INPUT=$(cat)

# 只拦截 git commit 命令
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
if ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0
fi

cd "$(echo "$INPUT" | jq -r '.cwd // "."')" 2>/dev/null || exit 0

# 获取 staged 文件列表
STAGED=$(git diff --cached --name-only 2>/dev/null)

# 如果改了代码但没改文档，发出警告
CODE_CHANGED=$(echo "$STAGED" | grep -E '^(src/|cent-jours-core/|tests/)' | head -1)
DOC_CHANGED=$(echo "$STAGED" | grep -E '^(docs/|README\.md|CLAUDE\.md)' | head -1)

if [ -n "$CODE_CHANGED" ] && [ -z "$DOC_CHANGED" ]; then
  echo "代码改动了但没有同步文档。请检查是否需要更新 docs/ 或 CLAUDE.md。" >&2
  exit 2
fi

exit 0
