#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
# Receipt is present, valid JSON, non-empty runner/model — but its .angle field
# says "security" while it occupies the bugs slot. The is_valid_receipt
# `.angle == $a` guard must reject it (a worker writing the wrong angle label is
# a realistic failure mode and exercises a distinct jq branch).
printf '{"angle":"security","chunk":null,"runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.json"

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "mismatched .angle field → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose receipt is invalid"
finish
