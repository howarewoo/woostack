#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
# Receipt file present + valid JSON object + matching angle, but model is empty.
printf '{"angle":"bugs","chunk":null,"runner":"claude-code","model":"","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty model → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

# Empty runner is likewise invalid. Capture stderr and assert the error names the
# angle, mirroring the empty-model sub-case — a silent or mis-named error path
# would otherwise pass this check.
printf '{"angle":"bugs","chunk":null,"runner":"","model":"m","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty runner → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"
finish
