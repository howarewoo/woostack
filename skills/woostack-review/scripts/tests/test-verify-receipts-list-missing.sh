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

# Scenario 2: under chunking, missing labels take the dotted <angle>.<chunk>
# form. --list-missing shares the same missing[] array as gate mode, so the
# chunked label format must surface here too.
export OUTDIR="$work/out2"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
printf '%s\n' chunk-0 chunk-1 > "$OUTDIR/chunks.txt"
printf '{"angle":"bugs","chunk":"chunk-0","runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.chunk-0.json"
# bugs.chunk-1 missing.
rc=0; out="$(bash "$SCRIPT" --list-missing)" || rc=$?
assert_exit 0 "$rc" "--list-missing exits 0 under chunking"
assert_contains "$out" "bugs.chunk-1" "lists missing dotted <angle>.<chunk> label"
assert_not_contains "$out" "bugs.chunk-0" "present chunk receipt not listed as missing"
finish
