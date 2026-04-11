#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if [[ $# -gt 0 ]]; then
  changed_files=("$@")
else
  mapfile -t changed_files < <(git diff --cached --name-only)
  if (( ${#changed_files[@]} == 0 )); then
    mapfile -t changed_files < <(git diff --name-only)
  fi
fi

if (( ${#changed_files[@]} == 0 )); then
  echo "No changed files. Light guard passes."
  exit 0
fi

echo "Running Codex light guard..."
bash tools/codex_doc_sync_guard.sh "${changed_files[@]}"

mapfile -t shell_files < <(printf '%s\n' "${changed_files[@]}" | rg -N '(\.sh$|^\.githooks/)')
if (( ${#shell_files[@]} > 0 )); then
  echo
  echo "Shell syntax checks:"
  for file_path in "${shell_files[@]}"; do
    echo "  - ${file_path}"
    bash -n "${file_path}"
  done
fi

mapfile -t python_files < <(printf '%s\n' "${changed_files[@]}" | awk '/\.py$/ {print}')
if (( ${#python_files[@]} > 0 )); then
  echo
  echo "Python syntax checks:"
  python3 -m py_compile "${python_files[@]}"
fi

if printf '%s\n' "${changed_files[@]}" | rg -q '^cent-jours-core/(src|tests)/'; then
  echo
  echo "Rust formatting check:"
  cargo fmt --check --manifest-path cent-jours-core/Cargo.toml
fi

echo
python3 tools/codex_validation_scope.py "${changed_files[@]}"

echo
echo "Codex light guard passed."
