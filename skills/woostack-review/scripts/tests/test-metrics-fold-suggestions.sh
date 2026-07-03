#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/metrics-fold.sh"

work="$(mktemp -d)"
export OUTDIR="$work/out"
export GITHUB_WORKSPACE="$work/repo"
mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
( cd "$GITHUB_WORKSPACE" && git init -q )

printf '%s\n' '{"metrics": true}' > "$OUTDIR/config.json"
CONFIG_FILE="$GITHUB_WORKSPACE/.woostack/config.json"
printf '%s\n' '{"review":{"angles":{"skip":["existing"]}}}' > "$CONFIG_FILE"
config_before="$(cat "$CONFIG_FILE")"

ROLLING="$GITHUB_WORKSPACE/.woostack/metrics.json"
cat > "$ROLLING" <<'JSON'
{
  "schema_version": 3,
  "runs": 19,
  "angles": {
    "aeo": {
      "runs_present": 19,
      "raw_total": 0,
      "kept_total": 0,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 0,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "docs": {
      "runs_present": 19,
      "raw_total": 19,
      "kept_total": 19,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 19,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 19},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "react": {
      "runs_present": 18,
      "raw_total": 0,
      "kept_total": 0,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 0,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "api": {
      "runs_present": 19,
      "raw_total": 20,
      "kept_total": 1,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 1,
      "nit_total": 0,
      "severity_total": {"HIGH": 1, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "bugs": {
      "runs_present": 19,
      "raw_total": 0,
      "kept_total": 0,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 0,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "security": {
      "runs_present": 19,
      "raw_total": 0,
      "kept_total": 0,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 0,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    },
    "simplify": {
      "runs_present": 19,
      "raw_total": 0,
      "kept_total": 0,
      "dropped_by_defender_total": 0,
      "dropped_by_prosecutor_total": 0,
      "blocking_total": 0,
      "nit_total": 0,
      "severity_total": {"HIGH": 0, "MEDIUM": 0, "LOW": 0},
      "overlap_total": 0,
      "overlap_with": {}
    }
  }
}
JSON

cat > "$OUTDIR/findings.metrics.json" <<'JSON'
{
  "schema_version": 3,
  "mode": "defender-only",
  "degraded": false,
  "angles": {
    "aeo": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}},
    "docs": {"raw_count": 1, "kept": 1, "blocking_count": 0, "nit_count": 1, "severity": {"LOW": 1}, "overlap_total": 0, "overlap_with": {}},
    "react": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}},
    "api": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}},
    "bugs": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}},
    "security": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}},
    "simplify": {"raw_count": 0, "kept": 0, "blocking_count": 0, "nit_count": 0, "overlap_total": 0, "overlap_with": {}}
  }
}
JSON

out="$work/metrics-fold-suggestions.out"
bash "$SCRIPT" >"$out" 2>&1
out_text="$(cat "$out")"

assert_contains "$out_text" "consider review.angles.skip += [\"aeo\"]" \
  "zero-signal threshold angle emits skip advisory"
assert_contains "$out_text" "0 kept" "zero-signal advisory names zero kept findings"
assert_contains "$out_text" "consider review.angles.skip += [\"docs\"]" \
  "nit-only threshold angle emits skip advisory"
assert_contains "$out_text" "nit-only" "nit-only advisory names nit-only findings"
assert_not_contains "$out_text" "review.angles.skip += [\"react\"]" \
  "below-threshold angle emits no skip advisory"
assert_not_contains "$out_text" "review.angles.skip += [\"api\"]" \
  "angle with blocking findings emits no skip advisory"
assert_not_contains "$out_text" "review.angles.skip += [\"bugs\"]" \
  "core bugs angle emits no skip advisory"
assert_not_contains "$out_text" "review.angles.skip += [\"security\"]" \
  "core security angle emits no skip advisory"
assert_not_contains "$out_text" "review.angles.skip += [\"simplify\"]" \
  "core simplify angle emits no skip advisory"
assert_eq "$(cat "$CONFIG_FILE")" "$config_before" \
  "metrics-fold advisory does not edit .woostack/config.json"

rm -rf "$work"
finish
