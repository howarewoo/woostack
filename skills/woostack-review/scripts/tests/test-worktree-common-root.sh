#!/usr/bin/env bash
# Regression for secondary worktrees: review metrics stay primary-only while root resolution keeps
# tracked work anchored to the active worktree.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

RESOLVE="$DIR/resolve-root.sh"
METRICS_FOLD="$DIR/metrics-fold.sh"

repo="$(mktemp -d)"
wt="$repo-worktree"
out="$(mktemp -d)"
repo="$(cd "$repo" && pwd -P)"
out="$(cd "$out" && pwd -P)"
wt="$(cd "$(dirname "$wt")" && pwd -P)/$(basename "$wt")"

git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Test User"
printf 'root\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -q -m init

printf '.woostack/metrics.json\n' > "$repo/.gitignore"

git -C "$repo" worktree add -q -b worktree-run "$wt" HEAD
wt="$(cd "$wt" && pwd -P)"


resolved="$out/roots.env"
(
  cd "$wt"
  env -u GITHUB_WORKSPACE bash -c 'source "$1"; printf "root=%s\ncommon=%s\n" "$WOOSTACK_ROOT" "$WOOSTACK_COMMON_ROOT"' _ "$RESOLVE"
) > "$resolved"

assert_eq "$(grep '^root=' "$resolved" | cut -d= -f2-)" "$wt" "WOOSTACK_ROOT stays on the active worktree"
assert_eq "$(grep '^common=' "$resolved" | cut -d= -f2-)" "$repo" "WOOSTACK_COMMON_ROOT resolves to primary checkout"


mkdir -p "$out/review"
printf '{"metrics":true}\n' > "$out/review/config.json"
cat > "$out/review/findings.metrics.json" <<'JSON'
{
  "schema_version": 3,
  "mode": "defender-only",
  "degraded": false,
  "bugs": {
    "raw_count": 1,
    "nit_count": 0,
    "kept_count": 1,
    "dropped_by_defender": 0,
    "severity": {"HIGH": 1, "MEDIUM": 0, "LOW": 0}
  }
}
JSON

(
  cd "$wt"
  env -u GITHUB_WORKSPACE OUTDIR="$out/review" bash "$METRICS_FOLD" > "$out/metrics-fold.out"
)

assert_exit 0 "$([ -f "$repo/.woostack/metrics.json" ]; echo $?)" "metrics-fold writes primary metrics aggregate"
assert_exit 1 "$([ -f "$wt/.woostack/metrics.json" ]; echo $?)" "metrics-fold does not write metrics in secondary worktree"
assert_eq "$(jq -r '.runs' "$repo/.woostack/metrics.json")" "1" "primary metrics aggregate records run"

rm -rf "$repo" "$wt" "$out"
finish
