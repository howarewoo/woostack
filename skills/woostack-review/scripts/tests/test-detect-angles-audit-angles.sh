#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"
setup() { work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"; \
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"; : > "$OUTDIR/diff.txt"; }

# Ordinary source changes receive only the singular general correctness pass.
setup "src/index.ts"; bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(cat "$OUTDIR/angles.txt")" "bugs" "ordinary source uses one correctness pass"
rm -rf "$work"

# Specialist signals remain deterministic and narrow.
setup "src/auth/login.ts"; bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "security" "auth path enables security specialist"
assert_eq "$(grep -cx 'architecture' "$OUTDIR/angles.txt" || true)" "0" "architecture fanout removed"
assert_eq "$(grep -cx 'production-readiness' "$OUTDIR/angles.txt" || true)" "0" "production-readiness fanout removed"
rm -rf "$work"

# Docs-only PR receives the general pass but no source-quality specialists.
setup "README.md"; bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'simplify' "$OUTDIR/angles.txt" || true)" "0" "docs-only: simplify fanout removed"
assert_eq "$(grep -cx 'production-readiness' "$OUTDIR/angles.txt" || true)" "0" "docs-only: no production-readiness"
rm -rf "$work"

# simplify cannot be disabled by input skip or config skip is obsolete: the
# angle is no longer dispatched, while bugs remains protected.
setup "README.md"
printf '{"angles":{"skip":["bugs"]}}\n' > "$OUTDIR/config.json"
INPUT_DISABLE_ANGLES="bugs" bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'bugs' "$OUTDIR/angles.txt" || true)" "1" "bugs cannot be disabled"
rm -rf "$work"


# Site 3 (load-config.sh VALID_ANGLES): both new angles must be registered, else
# review.angles.force / .skip silently reject them. This site was historically missed when adding
# an angle.
VA_LINE="$(grep 'VALID_ANGLES' "$DIR/load-config.sh")"
assert_contains "$VA_LINE" "simplify" "VALID_ANGLES includes simplify"
assert_contains "$VA_LINE" "production-readiness" "VALID_ANGLES includes production-readiness"

# Site 10 (anthropic.md standard-tier angle list): both angles must appear so the per-provider tier
# table does not silently drop them; this site was historically missed for the comments angle.
ANTHRO_LINE="$(grep 'effort: medium.*(' "$DIR/../prompts/anthropic.md")"
assert_contains "$ANTHRO_LINE" "simplify" "anthropic standard tier lists simplify"
assert_contains "$ANTHRO_LINE" "production-readiness" "anthropic standard tier lists production-readiness"

finish
