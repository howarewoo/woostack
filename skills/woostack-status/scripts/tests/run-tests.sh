#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for test_file in test-status.sh test-status-enrichment.sh; do
  [ -e "$test_file" ] || continue
  echo "== $test_file =="
  if bash "$test_file"; then :; else rc=1; fi
done
exit "$rc"
