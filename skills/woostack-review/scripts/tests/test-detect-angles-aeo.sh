#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

# setup_diff $1 = changed file path, $2 = diff body (literal +/- prefixes)
setup_diff() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '{"files":[{"path":"%s"}]}\n' "$1" > "$OUTDIR/meta.json"
  printf '%s\n' "$2" > "$OUTDIR/diff.txt"
}
absent() { grep -cx 'aeo' "$OUTDIR/angles.txt" || true; }  # "0" when aeo not enabled

# README prose is documentation, not an answer-engine surface.
setup_diff "README.md" "+Fix setup wording for the local development guide."
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "README prose-only diff does not enable aeo"
assert_contains "$(cat "$OUTDIR/angles.txt")" "docs" "README prose-only diff still enables docs"
rm -rf "$work"

# Skill manifest prose routes to the skills angle, not the AEO angle.
setup_diff "skills/example/SKILL.md" "+Clarify when to use this skill."
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "SKILL.md prose-only diff does not enable aeo"
assert_contains "$(cat "$OUTDIR/angles.txt")" "skills" "SKILL.md prose-only diff still enables skills"
rm -rf "$work"

# AI crawler control files are hard AEO surfaces by path alone.
setup_diff "public/llms.txt" "+Allow: /docs"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "aeo" "llms.txt enables aeo on path alone"
rm -rf "$work"

setup_diff "public/robots.txt" "+User-agent: GPTBot"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "aeo" "robots.txt enables aeo on path alone"
rm -rf "$work"

# Public pricing/product content is an answer-engine citation surface.
setup_diff "app/pricing/page.mdx" "+Compare plan limits and enterprise pricing."
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "aeo" "pricing content page enables aeo"
rm -rf "$work"

# Internal docs are not AEO unless the changed text carries an answer-engine token.
setup_diff "docs/internal/runbook.md" "+Rotate the staging database password after a drill."
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "internal docs prose-only diff does not enable aeo"
assert_contains "$(cat "$OUTDIR/angles.txt")" "docs" "internal docs prose-only diff still enables docs"
rm -rf "$work"

setup_diff "docs/internal/runbook.md" "+Allow GPTBot to fetch the public docs index."
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "aeo" "GPTBot token enables aeo even in markdown"
rm -rf "$work"

setup_diff "src/schema.ts" '+const jsonLd = { "@type": "Article" }'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "aeo" "JSON-LD Article token enables aeo"
rm -rf "$work"

finish
