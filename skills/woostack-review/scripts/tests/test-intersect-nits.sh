#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# Defender-only mode keeps fixtures minimal: findings.defender.json becomes
# findings.json after the classifier runs. Four findings exercise every branch:
#   HIGH blocking      -> normal (at/above floor)
#   MEDIUM non-block   -> nit (below floor, nits on)
#   LOW non-block      -> nit (below floor, nits on)
#   LOW blocking       -> normal blocking (blocking overrides floor)
run() { # $1 = config json
  work="$(mktemp -d)"; export OUTDIR="$work"
  printf '%s\n' "$1" > "$work/config.json"
  cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":1,"severity":"HIGH","blocking":true,"title":"High blocker"},
  {"angle":"bugs","file":"a.ts","line":2,"severity":"MEDIUM","blocking":false,"title":"Medium thing"},
  {"angle":"bugs","file":"a.ts","line":3,"severity":"LOW","blocking":false,"title":"Low thing"},
  {"angle":"security","file":"a.ts","line":4,"severity":"LOW","blocking":true,"title":"Low but blocking"}
]
JSON
  cp "$work/findings.defender.json" "$work/raw_findings.json"
  bash "$SCRIPT" >/tmp/intersect-nits.out 2>&1
  F="$work/findings.json"
}

# --- default nits ON, floor high ---
run '{"disable_adversarial": true}'
assert_eq "$(jq 'length' "$F")" "4" "nits on: all four kept"
assert_eq "$(jq -r '.[0].nit' "$F")" "false" "HIGH at/above floor -> not nit"
assert_eq "$(jq -r '.[1].nit' "$F")" "true" "MEDIUM below floor -> nit"
assert_eq "$(jq -r '.[1].blocking' "$F")" "false" "nit forced non-blocking"
assert_eq "$(jq -r '.[2].nit' "$F")" "true" "LOW below floor -> nit"
assert_eq "$(jq -r '.[3].nit' "$F")" "false" "below-floor blocking -> normal (override)"
assert_eq "$(jq -r '.[3].blocking' "$F")" "true" "blocking override keeps blocking:true"
assert_eq "$(jq -r '.nit_count' "$work/validator-metrics.json")" "2" "validator-metrics nit_count == 2"
rm -rf "$work"

# --- nits OFF: below-floor non-blocking dropped; blocking override survives ---
run '{"disable_adversarial": true, "nits": false}'
assert_eq "$(jq 'length' "$F")" "2" "nits off: MEDIUM+LOW non-blocking dropped"
assert_eq "$(jq -r '[.[].title] | sort | join(",")' "$F")" "High blocker,Low but blocking" "kept = HIGH + below-floor blocking"
assert_eq "$(jq -r '.nit_count' "$work/validator-metrics.json")" "0" "nits off: nit_count == 0"
rm -rf "$work"

# --- floor medium: MEDIUM normal, LOW nit ---
run '{"disable_adversarial": true, "severity_floor": "medium"}'
assert_eq "$(jq -r '.[1].nit' "$F")" "false" "floor medium: MEDIUM normal"
assert_eq "$(jq -r '.[2].nit' "$F")" "true" "floor medium: LOW nit"
rm -rf "$work"

# --- floor low: nothing is a nit ---
run '{"disable_adversarial": true, "severity_floor": "low"}'
assert_eq "$(jq -r '[.[] | select(.nit == true)] | length' "$F")" "0" "floor low: no nits"
rm -rf "$work"

# --- per-angle metrics: nit_count + nonblocking redefinition + schema v3 ---
run '{"disable_adversarial": true, "metrics": true}'
M="$work/findings.metrics.json"
assert_eq "$(jq -r '.schema_version' "$M")" "3" "per-run metrics schema_version == 3"
assert_eq "$(jq -r '.angles.bugs.nit_count' "$M")" "2" "bugs nit_count == 2"
assert_eq "$(jq -r '.angles.bugs.nonblocking_count' "$M")" "0" "bugs nonblocking = kept-blocking-nit = 0"
rm -rf "$work"

# --- adversarial path: below-floor finding classified as nit through intersect ---
advwork="$(mktemp -d)"; export OUTDIR="$advwork"
printf '%s\n' '{"metrics": true}' > "$advwork/config.json"
cat > "$advwork/findings.prosecutor.json" <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":1,"severity":"HIGH","blocking":false,"title":"High normal"},
  {"angle":"bugs","file":"a.ts","line":2,"severity":"MEDIUM","blocking":false,"title":"Medium thing"}
]
JSON
cp "$advwork/findings.prosecutor.json" "$advwork/findings.defender.json"
cp "$advwork/findings.prosecutor.json" "$advwork/raw_findings.json"
bash "$SCRIPT" >/tmp/intersect-nits-adv.out 2>&1
assert_eq "$(jq -r '.mode' "$advwork/validator-metrics.json")" "adversarial" "adversarial mode engaged"
assert_eq "$(jq 'length' "$advwork/findings.json")" "2" "adversarial: both agreed findings kept"
assert_eq "$(jq -r '[.[]|select(.title=="Medium thing")][0].nit' "$advwork/findings.json")" "true" "adversarial: below-floor MEDIUM -> nit"
assert_eq "$(jq -r '.nit_count' "$advwork/validator-metrics.json")" "1" "adversarial: nit_count == 1"
assert_eq "$(jq -r '.disagreement_count' "$advwork/validator-metrics.json")" "0" "adversarial: full agreement -> disagreement 0"
rm -rf "$advwork"

# --- adversarial + nits:false: per-angle dropped_by_* NOT inflated by floor drop ---
advwork="$(mktemp -d)"; export OUTDIR="$advwork"
printf '%s\n' '{"metrics": true, "nits": false}' > "$advwork/config.json"
cat > "$advwork/findings.prosecutor.json" <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":1,"severity":"HIGH","blocking":false,"title":"High normal"},
  {"angle":"bugs","file":"a.ts","line":2,"severity":"MEDIUM","blocking":false,"title":"Medium dropped"}
]
JSON
cp "$advwork/findings.prosecutor.json" "$advwork/findings.defender.json"
cp "$advwork/findings.prosecutor.json" "$advwork/raw_findings.json"
bash "$SCRIPT" >/tmp/intersect-nits-advoff.out 2>&1
M="$advwork/findings.metrics.json"
assert_eq "$(jq 'length' "$advwork/findings.json")" "1" "nits:false adversarial: MEDIUM dropped, HIGH kept"
assert_eq "$(jq -r '.disagreement_count' "$advwork/validator-metrics.json")" "0" "nits:false: floor-drop not a top-level disagreement"
# Both passes agreed on both findings; the floor (not a pass) dropped one. The
# per-angle disagreement counts use the pre-floor snapshot, so they stay 0.
assert_eq "$(jq -r '.angles.bugs.dropped_by_prosecutor' "$M")" "0" "nits:false: per-angle dropped_by_prosecutor not inflated"
assert_eq "$(jq -r '.angles.bugs.dropped_by_defender' "$M")" "0" "nits:false: per-angle dropped_by_defender not inflated"
rm -rf "$advwork"

# --- unknown/missing severity -> MEDIUM rank -> nit under default high floor ---
uwork="$(mktemp -d)"; export OUTDIR="$uwork"
printf '%s\n' '{"disable_adversarial": true}' > "$uwork/config.json"
cat > "$uwork/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":1,"title":"No severity field","blocking":false},
  {"angle":"bugs","file":"a.ts","line":2,"severity":"BOGUS","blocking":false,"title":"Unrecognized severity"}
]
JSON
cp "$uwork/findings.defender.json" "$uwork/raw_findings.json"
bash "$SCRIPT" >/tmp/intersect-nits-unknown.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$uwork/findings.json")" "true" "missing severity -> MEDIUM -> nit (default high floor)"
assert_eq "$(jq -r '.[1].nit' "$uwork/findings.json")" "true" "unrecognized severity -> MEDIUM -> nit"
rm -rf "$uwork"

finish
