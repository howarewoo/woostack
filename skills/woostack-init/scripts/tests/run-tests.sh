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
build_contract="$ROOT/skills/woostack-build/tests/test-linear-build-contract.sh"
echo "== ${build_contract#"$ROOT"/} =="
if bash "$build_contract"; then :; else rc=1; fi
plan_contract="$ROOT/skills/woostack-build/tests/test-linear-plan-contract.sh"
echo "== ${plan_contract#"$ROOT"/} =="
if bash "$plan_contract"; then :; else rc=1; fi
exit "$rc"
