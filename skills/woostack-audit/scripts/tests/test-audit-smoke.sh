#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

# Fixture target.
t="$(mktemp -d)"; printf 'export const unused = 1\n' > "$t/a.ts"
export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"

# Stage 1: build the synthetic diff.
AUDIT_TARGET="$t" bash "$DIR/build-target-diff.sh" >/dev/null 2>&1
assert_eq "$(grep -c '^diff --git' "$OUTDIR/diff.txt")" "1" "synthetic diff built"

# Stage 2: audit config emits forced angles.
AUDIT_CONFIG_FILE="$t/none.json" bash "$DIR/load-audit-config.sh" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/config.json")" "simplify" "config forces simplify"

# Stage N: render a hand-seeded findings.json (swarm output is mocked — wiring test, not model).
printf '[{"angle":"simplify","severity":"HIGH","file":"%s/a.ts","line":1,"title":"Unused export","description":"x","fix":"delete"}]\n' "$t" > "$OUTDIR/findings.json"
AUDIT_REPORT_PATH="$OUTDIR/report.md" AUDIT_TARGET="$t" bash "$DIR/render-report.sh" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/report.md")" "Unused export" "report rendered from findings"
rm -rf "$t" "$OUTDIR"
finish
