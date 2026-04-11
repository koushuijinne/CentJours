#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

chmod +x \
  .githooks/pre-commit \
  .githooks/pre-push \
  tools/codex_cycle.sh \
  tools/codex_doc_sync_guard.sh \
  tools/codex_light_guard.sh \
  tools/codex_harness_status.sh \
  tools/codex_pick_next_task.py \
  tools/codex_round_check.sh \
  tools/codex_round_summary.py \
  tools/codex_validation_scope.py \
  tools/install_codex_git_hooks.sh

git config core.hooksPath .githooks
echo "Installed repository hooks via core.hooksPath=.githooks (pre-commit + pre-push)"
