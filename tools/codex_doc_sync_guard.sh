#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if [[ $# -gt 0 ]]; then
  exec python tools/check_doc_sync.py --files "$@"
fi

mapfile -t staged_files < <(git diff --cached --name-only)
if (( ${#staged_files[@]} > 0 )); then
  exec python tools/check_doc_sync.py --files "${staged_files[@]}"
fi

mapfile -t changed_files < <(git diff --name-only)
if (( ${#changed_files[@]} > 0 )); then
  exec python tools/check_doc_sync.py --files "${changed_files[@]}"
fi

echo "No changed files. Doc sync check passes."
