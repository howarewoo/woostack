#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

# setup $1 = newline-separated changed file paths
setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"
  : > "$OUTDIR/diff.txt"
}

# Ordinary code no longer fans out into the comment-rot angle; the bugs pass is
# the only general-purpose review.
setup "src/index.ts"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'comments' "$OUTDIR/angles.txt" || true)" "0" "source file does not enable comments fanout"
assert_eq "$(cat "$OUTDIR/angles.txt")" "bugs" "source file keeps singular correctness pass"
rm -rf "$work"

# A markdown-only PR does NOT enable comments.
setup "README.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'comments' "$OUTDIR/angles.txt" || true)" "0" "markdown-only does not enable comments"
rm -rf "$work"
