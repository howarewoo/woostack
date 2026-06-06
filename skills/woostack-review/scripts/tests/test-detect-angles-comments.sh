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

# A general-purpose source file enables the comments (comment-rot) angle — comment
# rot most often surfaces when surrounding code changes, so it shares architecture's gate.
setup "src/index.ts"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "comments" "source file enables comments angle"
rm -rf "$work"

# A markdown-only PR does NOT enable comments (no code comments to rot).
setup "README.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'comments' "$OUTDIR/angles.txt" || true)" "0" "markdown-only does not enable comments"
rm -rf "$work"
