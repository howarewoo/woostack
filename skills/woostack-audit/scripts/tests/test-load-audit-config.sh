#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-audit-config.sh"

EC=0
run() { # $1=config json, $2=lens (optional). Sets OUTDIR (parent-visible) + EC.
  work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
  printf '%s' "$1" > "$work/config.json"
  AUDIT_CONFIG_FILE="$work/config.json" AUDIT_LENS="${2:-}" bash "$SCRIPT" >/dev/null 2>&1 && EC=0 || EC=$?
}

# No audit block -> defaults: force simplify+production-readiness, skip architecture.
run '{}'; assert_eq "$EC" "0" "empty config ok"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "simplify" "force includes simplify"
assert_contains "$cfg" "production-readiness" "force includes production-readiness"
assert_contains "$cfg" "architecture" "skip includes architecture"

# Sibling review block is ignored, not an error.
run '{"review":{"severity_floor":"low"},"audit":{"severity_floor":"medium"}}'
assert_eq "$EC" "0" "sibling review block ignored"
assert_contains "$(cat "$OUTDIR/config.json")" "medium" "audit severity_floor applied"

# Lens flag simplify keeps the floor, drops production-readiness from force.
run '{}' 'simplify'; assert_eq "$EC" "0" "lens ok"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "simplify" "lens simplify forces simplify"
assert_not_contains "$cfg" "production-readiness" "lens simplify drops prod-readiness"

# Unknown audit key -> loud non-zero.
run '{"audit":{"bogus":1}}'; assert_eq "$EC" "1" "unknown audit key rejected"
finish
