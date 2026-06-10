#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# A finding carrying deferred_to must become a non-blocking nit regardless of
# severity_floor. Defender-only (disable_adversarial) isolates the floor classifier.
setup() { # $1 = severity_floor ; $2 = defer_markers ("true"/"false")
  work="$(mktemp -d)"
  export OUTDIR="$work"
  printf '{"disable_adversarial":true,"severity_floor":"%s","defer_markers":%s}\n' "$1" "$2" > "$OUTDIR/config.json"
  cat > "$OUTDIR/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"x.ts","line":3,"severity":"HIGH","blocking":true,
   "title":"Missing call-site wiring","description":"d","fix":"f","fix_type":"prose",
   "suggestion":null,"rule_quote":null,"deferred_to":"increment 3"}
]
JSON
  printf '[]\n' > "$OUTDIR/raw_findings.json"
}

# floor=high, defer on: HIGH would normally be a normal blocking finding; the
# deferred_to override must still demote it to a nit.
setup "high" "true"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "deferred_to -> nit (floor=high)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "deferred_to -> non-blocking (floor=high)"
assert_eq "$(jq -r '.deferred_count' "$OUTDIR/validator-metrics.json")" "1" "deferred_count counted"
rm -rf "$work"

# floor=low, defer on: HIGH is at/above floor (would be a normal finding); the
# override must STILL force nit — proving it is floor-independent.
setup "low" "true"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "deferred_to -> nit (floor=low, floor-independent)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "deferred_to -> non-blocking (floor=low)"
rm -rf "$work"

# Hard off-switch: defer_markers=false -> deferred_to is ignored; the HIGH blocking
# finding stays a normal blocking finding and is NOT counted.
setup "high" "false"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "false" "defer off -> not demoted"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "true" "defer off -> stays blocking"
assert_eq "$(jq -r '.deferred_count' "$OUTDIR/validator-metrics.json")" "0" "defer off -> deferred_count 0"
rm -rf "$work"

finish
