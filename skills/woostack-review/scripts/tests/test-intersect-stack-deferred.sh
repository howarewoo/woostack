#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# A finding carrying stack_deferred must become a non-blocking nit regardless of
# severity_floor. Run defender-only (disable_adversarial) to isolate the floor
# classifier from the intersection logic.
setup() { # $1 = severity_floor
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '{"disable_adversarial":true,"severity_floor":"%s"}\n' "$1" > "$OUTDIR/config.json"
  cat > "$OUTDIR/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"x.ts","line":3,"severity":"HIGH","blocking":true,
   "title":"Missing call-site wiring","description":"d","fix":"f","fix_type":"prose",
   "suggestion":null,"rule_quote":null,"stack_deferred":"#225"}
]
JSON
  printf '[]\n' > "$OUTDIR/raw_findings.json"
}

# Under floor=high: HIGH would normally be a normal blocking finding; the
# stack_deferred override must still demote it to a nit.
setup "high"
bash "$SCRIPT" >/tmp/intersect-stack.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "stack_deferred -> nit (floor=high)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "stack_deferred -> non-blocking (floor=high)"
assert_eq "$(jq -r '.stack_deferred_count' "$OUTDIR/validator-metrics.json")" "1" "stack_deferred_count counted"
rm -rf "$work"

# Under floor=low: HIGH is at/above floor (would be a normal finding); the
# override must STILL force nit — proving it is floor-independent.
setup "low"
bash "$SCRIPT" >/tmp/intersect-stack.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "stack_deferred -> nit (floor=low, floor-independent)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "stack_deferred -> non-blocking (floor=low)"
rm -rf "$work"

finish
