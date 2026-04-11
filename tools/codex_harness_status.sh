#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

branch="$(git branch --show-current)"
head_commit="$(git rev-parse --short HEAD)"
hooks_path="$(git config --get core.hooksPath || true)"
staged_count="$(git diff --cached --name-only | wc -l | tr -d ' ')"
modified_count="$(git diff --name-only | wc -l | tr -d ' ')"
untracked_count="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"

ahead_count="0"
behind_count="0"
if [[ -n "${branch}" ]] && git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
  counts="$(git rev-list --left-right --count "origin/${branch}...HEAD")"
  behind_count="$(awk '{print $1}' <<<"${counts}")"
  ahead_count="$(awk '{print $2}' <<<"${counts}")"
fi

docs_changed="no"
while IFS= read -r path; do
  if [[ "${path}" == "README.md" || "${path}" == docs/* ]]; then
    docs_changed="yes"
    break
  fi
done < <(
  {
    git diff --cached --name-only
    git diff --name-only
    git ls-files --others --exclude-standard
  } | awk 'NF' | sort -u
)

worktree_state="clean"
if [[ "${staged_count}" != "0" || "${modified_count}" != "0" || "${untracked_count}" != "0" ]]; then
  worktree_state="dirty"
fi

echo "Codex harness status"
echo "Branch:        ${branch:-detached}"
echo "HEAD:          ${head_commit}"
echo "HooksPath:     ${hooks_path:-<default>}"
echo "Ahead/Behind:  ${ahead_count}/${behind_count}"
echo "Worktree:      ${worktree_state}"
echo "Staged:        ${staged_count}"
echo "Modified:      ${modified_count}"
echo "Untracked:     ${untracked_count}"
echo "Docs changed:  ${docs_changed}"
