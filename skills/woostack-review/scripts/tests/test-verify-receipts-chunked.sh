#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
printf '%s\n' chunk-0 chunk-1 > "$OUTDIR/chunks.txt"
# chunk-0 executed, chunk-1 missing.
printf '{"angle":"bugs","chunk":"chunk-0","runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.chunk-0.json"

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing (angle,chunk) receipt → exit 1"
assert_contains "$err" "bugs.chunk-1" "names the missing angle.chunk"

# Add the missing chunk receipt → now passes.
printf '{"angle":"bugs","chunk":"chunk-1","runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.chunk-1.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "all chunk receipts valid → exit 0"
finish
