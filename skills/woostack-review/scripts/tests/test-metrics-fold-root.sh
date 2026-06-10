#!/usr/bin/env bash
# Regression for issue #272: metrics-fold must anchor .woostack/ to the git repo
# root, never the current working directory. Run it from a package subdir with
# GITHUB_WORKSPACE unset and assert the rolling metrics + the .gitignore append
# land at the git toplevel, and that no .woostack/ is created inside the package.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/metrics-fold.sh"

repo="$(mktemp -d)"
( cd "$repo" && git init -q )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
sub="$toplevel/packages/infrastructure/ai"
mkdir -p "$sub"

out="$(mktemp -d)/out"
mkdir -p "$out"
printf '%s\n' '{"metrics": true}' > "$out/config.json"
cat > "$out/findings.metrics.json" <<'JSON'
{
  "schema_version": 3,
  "mode": "defender-only",
  "degraded": false,
  "angles": {
    "bugs": {"raw_count": 1, "kept": 1, "nit_count": 0, "overlap_total": 0, "overlap_with": {}}
  }
}
JSON

# Run from the package subdir, GITHUB_WORKSPACE unset, OUTDIR pinned.
( cd "$sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/metrics-fold-root.out" 2>&1

assert_eq "$(test -f "$toplevel/.woostack/metrics.json" && echo yes || echo no)" "yes" \
  "rolling metrics.json written at the git toplevel"
assert_eq "$(test -e "$sub/.woostack" && echo yes || echo no)" "no" \
  "no .woostack/ polluting the package subdir"
assert_contains "$(cat "$toplevel/.gitignore" 2>/dev/null || true)" ".woostack/metrics.json" \
  ".gitignore append lands at the git toplevel"
assert_eq "$(test -e "$sub/.gitignore" && echo yes || echo no)" "no" \
  "no .gitignore created inside the package subdir"

rm -rf "$repo" "$(dirname "$out")"
finish
