#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security types > "$OUTDIR/angles.txt"
# bugs + security executed; types produced NO receipt.
for a in bugs security; do
  printf '{"angle":"%s","chunk":null,"runner":"claude-code","model":"m","tier":"standard","ts":"t"}\n' "$a" > "$OUTDIR/receipt.$a.json"
done

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing receipt → exit 1"
assert_contains "$err" "did not execute" "error states workers did not execute"
assert_contains "$err" "types" "error names the non-executing angle"
assert_not_contains "$err" "no angle analysis executed" "partial failure uses the partial message"
finish
