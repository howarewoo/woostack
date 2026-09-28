#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Every test is static and provider-free.
rc=0
tests=(
  test-doctor.sh
  test-github-capability.sh
  test-health-checks.sh
  test-orchestrator.sh
)
for t in "${tests[@]}"; do
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
