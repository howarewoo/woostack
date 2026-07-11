#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-audit-config.sh"

EC=0
run() { # $1=config json, $2=lens (optional). Sets OUTDIR + ERR (parent-visible) + EC.
  work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
  printf '%s' "$1" > "$work/config.json"
  ERR="$work/stderr"
  AUDIT_CONFIG_FILE="$work/config.json" AUDIT_LENS="${2:-}" bash "$SCRIPT" >/dev/null 2>"$ERR" && EC=0 || EC=$?
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

# Lens flag prod narrows production-readiness but still keeps simplify.
run '{}' 'prod'; assert_eq "$EC" "0" "lens prod ok"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "production-readiness" "lens prod forces production-readiness"
assert_contains "$cfg" "simplify" "lens prod keeps simplify"

# angles:null is coerced to {} by the `or {}` guard, not treated as an error.
run '{"audit":{"angles":null}}'; assert_eq "$EC" "0" "angles:null coerced, not an error"

# User-supplied angles.force/skip merge onto the audit defaults (append, not replace).
run '{"audit":{"angles":{"force":["bugs"],"skip":["docs"]}}}'; assert_eq "$EC" "0" "user angles merge ok"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "bugs" "user angles.force merged onto defaults"
assert_contains "$cfg" "docs" "user angles.skip merged onto architecture"

# simplify is invariant for audit and cannot be disabled through user skip config.
run '{"audit":{"angles":{"skip":["simplify","docs"]}}}'; assert_eq "$EC" "0" "simplify skip ignored"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "simplify" "simplify remains forced"
assert_eq "$(jq -r '.angles.skip | index("simplify") == null' "$OUTDIR/config.json")" "true" "simplify removed from skip"
assert_contains "$cfg" "docs" "other user skips remain"

# Unknown lens flag falls back to running both audit angles, not an error.
run '{}' 'bogus'; assert_eq "$EC" "0" "unknown lens falls back, no error"
cfg="$(cat "$OUTDIR/config.json")"
assert_contains "$cfg" "simplify" "unknown lens keeps simplify"
assert_contains "$cfg" "production-readiness" "unknown lens keeps production-readiness"

# Root provider tiers are shared config and survive beside audit settings.
run '{"models":{"openai":{"standard":{"model":"gpt-5.5","effort":"medium"}}},"audit":{"severity_floor":"medium"}}'
assert_eq "$EC" "0" "root provider model accepted"
assert_eq "$(jq -c '.models.openai.standard' "$OUTDIR/config.json")" '{"model":"gpt-5.5","effort":"medium"}' "root provider model forwarded"
assert_eq "$(jq -r '.severity_floor' "$OUTDIR/config.json")" "medium" "audit settings coexist with root models"

# Flat provider-agnostic tiers are normalized to the shared canonical leaf shape.
run '{"models":{"standard":"provider/model"}}'
assert_eq "$EC" "0" "flat root model accepted"
assert_eq "$(jq -c '.models.standard' "$OUTDIR/config.json")" '{"model":"provider/model"}' "flat root model normalized"

# Shared fallback arrays are normalized and forwarded without losing order.
run '{"models":{"standard":["provider/primary",{"model":"provider/fallback","effort":"high"}]}}'
assert_eq "$EC" "0" "shared fallback array accepted by audit loader"
assert_eq "$(jq -c '.models.standard' "$OUTDIR/config.json")" \
  '[{"model":"provider/primary"},{"model":"provider/fallback","effort":"high"}]' \
  "shared fallback array forwarded canonically"

# Malformed shared fallback arrays fail before audit work starts.
run '{"models":{"standard":["provider/primary",null]}}'
assert_eq "$EC" "1" "malformed shared fallback array rejected"
assert_contains "$(cat "$ERR")" "models.standard[1]" "malformed shared array names indexed path"

# Invalid root model configuration fails before audit work starts.
run '{"models":"gpt-5.5"}'
assert_eq "$EC" "1" "non-object root models rejected"
assert_contains "$(cat "$ERR")" "must be an object with fast/standard/deep keys" "non-object error names models contract"

run '{"models":{"standrd":"gpt-5.5"}}'
assert_eq "$EC" "1" "unknown root model tier rejected"
assert_contains "$(cat "$ERR")" "unknown models key" "unknown tier error names valid model keys"

run '{"models":{"openai":{"standard":{"model":"gpt-5.5","effort":"turbo"}}}}'
assert_eq "$EC" "1" "invalid root model effort rejected"
assert_contains "$(cat "$ERR")" "effort must be one of" "invalid effort error names allowed values"

# models is shared root config, not an audit-local key.
run '{"audit":{"models":{"standard":"legacy/model"}}}'
assert_eq "$EC" "1" "nested audit.models rejected"
assert_contains "$(cat "$ERR")" "root models" "nested model error names valid root location"

# Invalid JSON in the config file -> loud non-zero exit (JSONDecodeError path).
run '{invalid'; assert_eq "$EC" "1" "invalid JSON rejected"

# Unknown audit key -> loud non-zero.
run '{"audit":{"bogus":1}}'; assert_eq "$EC" "1" "unknown audit key rejected"
finish
