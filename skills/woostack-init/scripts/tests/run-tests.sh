#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
cd "$HERE"
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
for contract in \
  "$ROOT/skills/woostack-build/tests/test-linear-build-contract.sh" \
  "$ROOT/skills/woostack-build/tests/test-linear-plan-contract.sh"
do
  echo "== ${contract#"$ROOT"/} =="
  if bash "$contract"; then :; else rc=1; fi
done
exit "$rc"
