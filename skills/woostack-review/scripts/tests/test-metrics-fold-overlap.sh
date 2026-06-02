#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/metrics-fold.sh"

work="$(mktemp -d)"
export OUTDIR="$work/out"
export GITHUB_WORKSPACE="$work/repo"
mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE"

printf '%s\n' '{"metrics": true}' > "$OUTDIR/config.json"

# A per-run metrics doc with overlap fields (shape emitted by Task 1).
write_run() {
  cat > "$OUTDIR/findings.metrics.json" <<JSON
{
  "schema_version": 2,
  "mode": "defender-only",
  "degraded": false,
  "angles": {
    "bugs":     {"raw_count": 1, "kept": 1, "overlap_total": 2, "overlap_with": {"security": 1, "types": 1}},
    "security": {"raw_count": 1, "kept": 1, "overlap_total": 1, "overlap_with": {"bugs": 1}}
  }
}
JSON
}

ROLLING="$GITHUB_WORKSPACE/.woostack/metrics.json"

# --- v1 reseed: a stale v1 aggregate must be backed up and replaced at v2. ---
mkdir -p "$GITHUB_WORKSPACE/.woostack"
printf '%s\n' '{"schema_version": 1, "runs": 9, "angles": {}}' > "$ROLLING"

write_run
bash "$SCRIPT" >/tmp/fold-overlap-1.out 2>&1

assert_eq "$(test -f "$ROLLING.bak" && echo yes || echo no)" "yes" "stale v1 aggregate backed up to .bak"
assert_eq "$(jq -r '.schema_version' "$ROLLING")" "2" "aggregate reseeded at schema_version 2"
assert_eq "$(jq -r '.runs' "$ROLLING")" "1" "reseeded aggregate counts this run as run 1"
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$ROLLING")" "2" "bugs overlap_total folded"
assert_eq "$(jq -r '.angles.bugs.overlap_with.security' "$ROLLING")" "1" "bugs->security folded"

# --- accumulation: a second identical run doubles the sums + map values. ---
write_run
bash "$SCRIPT" >/tmp/fold-overlap-2.out 2>&1

assert_eq "$(jq -r '.runs' "$ROLLING")" "2" "second fold increments runs"
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$ROLLING")" "4" "bugs overlap_total summed across runs"
assert_eq "$(jq -r '.angles.bugs.overlap_with.types' "$ROLLING")" "2" "bugs->types summed across runs"
assert_eq "$(jq -r '.angles.security.overlap_with.bugs' "$ROLLING")" "2" "security->bugs summed across runs"

rm -rf "$work"
finish
