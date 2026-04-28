#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Windows 上 `python3` 常常是 Microsoft Store 的占位 stub（未安装时直接 exit 9009），
# 因此优先环境变量 PYTHON，再依次回退到 python3 / python / py。
resolve_python() {
  if [[ -n "${PYTHON:-}" ]]; then
    echo "${PYTHON}"
    return 0
  fi
  for cand in python3 python py; do
    if command -v "${cand}" >/dev/null 2>&1; then
      # 过滤 Windows Store 的 python3 占位 stub
      local resolved
      resolved="$(command -v "${cand}")"
      case "${resolved}" in
        */WindowsApps/*) continue ;;
      esac
      echo "${cand}"
      return 0
    fi
  done
  return 1
}

PY="$(resolve_python)" || {
  echo "找不到可用的 Python 解释器（尝试了 PYTHON / python3 / python / py）" >&2
  exit 1
}

if [[ $# -gt 0 ]]; then
  exec "${PY}" tools/check_doc_sync.py --files "$@"
fi

mapfile -t staged_files < <(git diff --cached --name-only)
if (( ${#staged_files[@]} > 0 )); then
  exec "${PY}" tools/check_doc_sync.py --files "${staged_files[@]}"
fi

mapfile -t changed_files < <(git diff --name-only)
if (( ${#changed_files[@]} > 0 )); then
  exec "${PY}" tools/check_doc_sync.py --files "${changed_files[@]}"
fi

echo "No changed files. Doc sync check passes."
