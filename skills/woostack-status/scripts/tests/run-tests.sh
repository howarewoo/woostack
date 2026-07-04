#!/usr/bin/env bash
set -euo pipefail
# Tests exercise status.sh dozens of times; never let those runs open browser tabs.
export WOO_STATUS_NO_OPEN=1
cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
