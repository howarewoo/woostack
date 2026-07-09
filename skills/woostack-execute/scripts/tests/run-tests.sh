#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
