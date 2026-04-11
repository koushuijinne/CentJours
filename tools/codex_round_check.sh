#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

branch="$(git branch --show-current)"
head_commit="$(git rev-parse --short HEAD)"
status_output="$(git status --short)"

echo "Branch: ${branch}"
echo "HEAD:   ${head_commit}"

if [[ -n "${status_output}" ]]; then
  echo
  echo "Working tree is not clean:"
  echo "${status_output}"
  exit 1
fi

if [[ -n "${branch}" ]] && git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
  counts="$(git rev-list --left-right --count "origin/${branch}...HEAD")"
  behind_count="$(awk '{print $1}' <<<"${counts}")"
  ahead_count="$(awk '{print $2}' <<<"${counts}")"

  if [[ "${ahead_count}" != "0" ]]; then
    echo
    echo "Unpushed commits detected: ${ahead_count}"
    git log --oneline "origin/${branch}..HEAD"
    exit 1
  fi

  if [[ "${behind_count}" != "0" ]]; then
    echo
    echo "Local branch is behind origin/${branch}: ${behind_count}"
    exit 1
  fi
fi

echo
echo "Round check passed: working tree clean and branch synced."
