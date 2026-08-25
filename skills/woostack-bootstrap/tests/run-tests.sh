#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
