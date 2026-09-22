#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Static tests are provider-free; live behavior consumes only normalized fixture receipts.
unset WOOSTACK_DOCTOR_LIVE WOOSTACK_DOCTOR_LIVE_CONTEXT
rc=0
tests=(
  test-doctor.sh
  test-github-capability.sh
  test-health-checks.sh
  test-models-leaf-shape.sh
  test-orchestrator.sh
  test-omp-session-name.sh
)
for t in "${tests[@]}"; do
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
