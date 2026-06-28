#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"
setup() { work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"; \
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"; : > "$OUTDIR/diff.txt"; }

# simplify always runs; source file also enables production-readiness.
setup "src/index.ts"; bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "simplify" "source enables simplify"
assert_contains "$(cat "$OUTDIR/angles.txt")" "production-readiness" "source enables production-readiness"
rm -rf "$work"

# Docs-only PR still gets simplify, but not production-readiness.
setup "README.md"; bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'simplify' "$OUTDIR/angles.txt" || true)" "1" "docs-only: simplify remains on"
assert_eq "$(grep -cx 'production-readiness' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no production-readiness"
rm -rf "$work"

# simplify cannot be disabled by input skip or config skip.
setup "README.md"
printf '{"angles":{"skip":["simplify"]}}\n' > "$OUTDIR/config.json"
INPUT_DISABLE_ANGLES="simplify" bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'simplify' "$OUTDIR/angles.txt" || true)" "1" "skip cannot disable simplify"
rm -rf "$work"

# Site 3 (load-config.sh VALID_ANGLES): both new angles must be registered, else
# review.angles.force / .skip silently reject them. This is the historically
# missed site when adding an angle (memory: review-add-angle-sites).
VA_LINE="$(grep 'VALID_ANGLES' "$DIR/load-config.sh")"
assert_contains "$VA_LINE" "simplify" "VALID_ANGLES includes simplify"
assert_contains "$VA_LINE" "production-readiness" "VALID_ANGLES includes production-readiness"

# Site 10 (anthropic.md Sonnet-tier list): both angles must appear so the
# per-provider tier table doesn't silently drop them (memory: review-add-angle-sites,
# the site historically missed for the comments angle).
ANTHRO_LINE="$(grep 'Sonnet for' "$DIR/../prompts/anthropic.md")"
assert_contains "$ANTHRO_LINE" "simplify" "anthropic Sonnet tier lists simplify"
assert_contains "$ANTHRO_LINE" "production-readiness" "anthropic Sonnet tier lists production-readiness"

finish
