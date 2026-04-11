#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

mode="round"
if [[ "${1:-}" == "--pre-push" ]]; then
  mode="pre-push"
  shift
fi

branch="$(git branch --show-current)"
status_output="$(git status --short)"

bash tools/codex_harness_status.sh

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

  if [[ "${behind_count}" != "0" ]]; then
    echo
    echo "Local branch is behind origin/${branch}: ${behind_count}"
    exit 1
  fi

  if [[ "${mode}" == "pre-push" ]]; then
    mapfile -t changed_for_push < <(git diff --name-only "origin/${branch}...HEAD")
    if (( ${#changed_for_push[@]} > 0 )); then
      echo
      echo "Running doc sync guard for commits pending push..."
      bash tools/codex_doc_sync_guard.sh "${changed_for_push[@]}"
    fi
  elif [[ "${ahead_count}" != "0" ]]; then
    echo
    echo "Unpushed commits detected: ${ahead_count}"
    git log --oneline "origin/${branch}..HEAD"
    exit 1
  fi
elif [[ "${mode}" == "pre-push" ]]; then
  mapfile -t changed_for_push < <(git show --pretty='' --name-only HEAD)
  if (( ${#changed_for_push[@]} > 0 )); then
    echo
    echo "Running doc sync guard for current HEAD..."
    bash tools/codex_doc_sync_guard.sh "${changed_for_push[@]}"
  fi
fi

echo
if [[ "${mode}" == "pre-push" ]]; then
  echo "Pre-push check passed: working tree clean, branch not behind, doc sync verified."
else
  echo "Round check passed: working tree clean and branch synced."
fi
