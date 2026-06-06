#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security types > "$OUTDIR/angles.txt"
printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.json"
# security + types missing.

rc=0; out="$(bash "$SCRIPT" --list-missing)" || rc=$?
assert_exit 0 "$rc" "--list-missing exits 0 (non-failing)"
assert_contains "$out" "security" "lists missing security"
assert_contains "$out" "types" "lists missing types"
assert_not_contains "$out" "bugs" "valid receipt not listed as missing"
finish
