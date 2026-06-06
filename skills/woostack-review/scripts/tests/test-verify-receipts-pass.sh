#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security > "$OUTDIR/angles.txt"
for a in bugs security; do
  printf '{"angle":"%s","chunk":null,"runner":"claude-code","model":"claude-sonnet-4-6","tier":"standard","ts":"2026-06-06T00:00:00Z"}\n' "$a" > "$OUTDIR/receipt.$a.json"
done

rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "all receipts valid → exit 0"
assert_eq "$(jq -r '.executed_angles | length' "$OUTDIR/swarm-metrics.json")" "2" "metrics record 2 executed angles"
assert_eq "$(jq -r '.expected_total' "$OUTDIR/swarm-metrics.json")" "2" "metrics record expected total"
finish
