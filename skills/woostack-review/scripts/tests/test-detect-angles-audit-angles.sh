#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"
setup() { work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"; \
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"; : > "$OUTDIR/diff.txt"; }

# Source file enables both new angles (same gate as architecture).
setup "src/index.ts"; bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "simplify" "source enables simplify"
assert_contains "$(cat "$OUTDIR/angles.txt")" "production-readiness" "source enables production-readiness"
rm -rf "$work"

# Docs-only PR enables neither.
setup "README.md"; bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'simplify' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no simplify"
assert_eq "$(grep -cx 'production-readiness' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no production-readiness"
rm -rf "$work"
finish
