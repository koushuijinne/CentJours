#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

focus="any"
if [[ "${1:-}" == "--focus" ]]; then
  focus="${2:-any}"
fi

echo "=== Harness Status ==="
bash tools/codex_harness_status.sh

echo
echo "=== Next Task ==="
python3 tools/codex_pick_next_task.py --focus "${focus}"

echo
echo "=== Round Summary ==="
python3 tools/codex_round_summary.py
