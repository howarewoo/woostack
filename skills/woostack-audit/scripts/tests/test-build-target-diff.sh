#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/build-target-diff.sh"

# A dir with two text files + one binary -> diff.txt has two new-file sections, all + lines,
# binary skipped; meta.json lists the two text files.
t="$(mktemp -d)"; mkdir -p "$t/src"; printf 'export const a = 1\n' > "$t/src/a.ts"; \
  printf 'def b():\n    return 2\n' > "$t/src/b.py"; printf '\x00\x01\x02' > "$t/src/c.bin"
export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
AUDIT_TARGET="$t/src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "builder exits 0 on a normal target"
assert_eq "$(grep -c '^diff --git' "$OUTDIR/diff.txt")" "2" "one new-file section per text file"
assert_eq "$(grep -c '^new file mode' "$OUTDIR/diff.txt")" "2" "marked as new files (all-added)"
assert_not_contains "$(cat "$OUTDIR/diff.txt")" "c.bin" "binary file skipped"
assert_eq "$(jq '.files | length' "$OUTDIR/meta.json")" "2" "meta lists 2 files"
rm -rf "$t" "$OUTDIR"

# Missing target -> non-zero, no diff.txt.
export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
AUDIT_TARGET="/no/such/path" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "1" "missing target exits 1"
assert_eq "$([ -f "$OUTDIR/diff.txt" ] && echo y || echo n)" "n" "no diff.txt on missing target"
rm -rf "$OUTDIR"

# Binary-only target -> empty diff.txt, exit 0.
t="$(mktemp -d)"; printf '\x00\x01' > "$t/x.bin"; export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
AUDIT_TARGET="$t" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "binary-only exits 0"
assert_eq "$(wc -c < "$OUTDIR/diff.txt" | tr -d ' ')" "0" "binary-only yields empty diff"
rm -rf "$t" "$OUTDIR"

# Chunk integration end-to-end: with max_loc=1 the synthetic diff exceeds the threshold, so
# chunk-diff.sh must emit a non-empty chunks.txt + a non-empty chunks.json manifest. The builder
# calls chunk-diff.sh with `|| true`, so a broken integration would still exit 0 and pass every
# assertion above; these assertions prove the chunking pipeline actually ran and produced usable
# artifacts. (chunk-diff.sh only emits chunk files above threshold, hence the max_loc=1 config.)
t="$(mktemp -d)"; mkdir -p "$t/src"; printf 'export const a = 1\nexport const b = 2\n' > "$t/src/a.ts"
export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
printf '%s\n' '{"chunking":{"max_loc":1}}' > "$OUTDIR/config.json"
AUDIT_TARGET="$t/src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "builder exits 0 when chunking triggers"
assert_eq "$([ -s "$OUTDIR/chunks.txt" ] && echo y || echo n)" "y" "chunk-diff emitted non-empty chunks.txt"
chunks_json_ok="$(jq -e 'type=="array" and length>0' "$OUTDIR/chunks.json" >/dev/null 2>&1 && echo y || echo n)"
assert_eq "$chunks_json_ok" "y" "chunk-diff emitted a non-empty chunks.json manifest"
rm -rf "$t" "$OUTDIR"
finish
