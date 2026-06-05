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

# A SKILL.md in the diff enables the skills angle and NOT docs.
setup "skills/foo/SKILL.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "skills" "SKILL.md enables skills angle"
assert_eq "$(grep -cx 'docs' "$OUTDIR/angles.txt" || true)" "0" "SKILL.md-only does not enable docs"
rm -rf "$work"

# A non-SKILL code file does not enable skills.
setup "src/index.ts"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'skills' "$OUTDIR/angles.txt" || true)" "0" "no SKILL.md -> no skills angle"
rm -rf "$work"

# A real README still enables docs (exclusion is SKILL.md-specific, not all .md).
setup "README.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "docs" "README.md still enables docs"
rm -rf "$work"

finish
