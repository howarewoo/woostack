#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Static tests are provider-free; live behavior consumes only normalized fixture receipts.
unset WOOSTACK_DOCTOR_LIVE WOOSTACK_DOCTOR_LIVE_CONTEXT
rc=0
tests=(
  test-doctor.sh
  test-linear-mcp.sh
  test-models-leaf-shape.sh
  test-repair-handoff.sh
  test-no-stale-paths.sh
  test-omp-agents.sh
  test-omp-session-name.sh
  test-review-models-moved.sh
)
for t in "${tests[@]}"; do
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
