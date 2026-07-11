#!/usr/bin/env bash
# Root `models` field: relocation (clean break from review.models), string|object|array
# leaf normalization, effort enum, empty-effort-unset, host-agnostic flat leaves.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

CLEANUP_DIRS=()
cleanup() {
  for d in "${CLEANUP_DIRS[@]+"${CLEANUP_DIRS[@]}"}"; do
    rm -rf "$d"
  done
}
trap cleanup EXIT

# run_loader <config-json> : sets OUT (flat config dir), ERRLOG, RC.
run_loader() {
  local cfg="$1"
  REPO="$(mktemp -d)"; CLEANUP_DIRS+=("$REPO")
  ( cd "$REPO" && git init -q )
  local top; top="$(cd "$REPO" && git rev-parse --show-toplevel)"
  mkdir -p "$top/.woostack"
  printf '%s\n' "$cfg" > "$top/.woostack/config.json"
  local out_parent; out_parent="$(mktemp -d)"
  CLEANUP_DIRS+=("$out_parent")
  OUT="$out_parent/out"; mkdir -p "$OUT"; ERRLOG="$OUT/err"
  ( cd "$top" && env -u GITHUB_WORKSPACE OUTDIR="$OUT" bash "$SCRIPT" ) \
    >"$OUT/out.log" 2>"$ERRLOG" && RC=0 || RC=$?
}

# 1. object leaf normalized + preserved
run_loader '{"models":{"openai":{"standard":{"model":"gpt-5.5","effort":"medium"}}}}'
assert_exit 0 "$RC" "root models object leaf accepted"
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
  '{"effort":"medium","model":"gpt-5.5"}' "object leaf preserved (sorted keys)"

# 2. string leaf normalized to object
run_loader '{"models":{"openai":{"standard":"gpt-5.5"}}}'
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
  '{"model":"gpt-5.5"}' "string leaf normalized to {model}"

# 3. review.models rejected (clean break, tailored message)
run_loader '{"review":{"models":{"openai":{"standard":"x"}}}}'
assert_exit 1 "$RC" "review.models rejected"
assert_contains "$(cat "$ERRLOG")" "has moved to a top-level" "tailored relocation message"

# 4. object leaf missing model
run_loader '{"models":{"openai":{"standard":{"effort":"low"}}}}'
assert_exit 1 "$RC" "object leaf without model rejected"
assert_contains "$(cat "$ERRLOG")" "model must be a non-empty string" "names missing model"

# 5. unknown leaf key
run_loader '{"models":{"openai":{"standard":{"model":"x","bogus":1}}}}'
assert_exit 1 "$RC" "unknown leaf key rejected"
assert_contains "$(cat "$ERRLOG")" "unknown key(s): bogus" "names unknown leaf key"

# 6. invalid effort
run_loader '{"models":{"openai":{"standard":{"model":"x","effort":"turbo"}}}}'
assert_exit 1 "$RC" "invalid effort rejected"
assert_contains "$(cat "$ERRLOG")" "effort must be one of" "names effort enum"

# 7. empty effort = unset (no error, no effort key emitted)
run_loader '{"models":{"openai":{"standard":{"model":"x","effort":""}}}}'
assert_exit 0 "$RC" "empty effort accepted as unset"
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" '{"model":"x"}' \
  "empty effort dropped from normalized leaf"

# 8. host-agnostic flat tier leaf normalized
run_loader '{"models":{"standard":"flat-x"}}'
assert_eq "$(jq -c '.models.standard' "$OUT/config.json")" '{"model":"flat-x"}' \
  "flat tier leaf normalized to {model}"

# 9. root models alongside a (models-free) review block: both parsed
run_loader '{"review":{"metrics":true},"models":{"openai":{"standard":"x"}}}'
assert_exit 0 "$RC" "root models next to review block accepted"
assert_eq "$(jq -r '.metrics' "$OUT/config.json")" "true" "review.metrics still parsed"
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" '{"model":"x"}' \
  "sibling root models parsed (not silently ignored)"

# 10. flat fallback arrays normalize every tier and preserve entry order
run_loader '{"models":{"fast":[" fast-1 ",{"model":"fast-2","effort":"LOW"}],"standard":["standard-1"],"deep":[{"model":"deep-1","effort":"high"},"deep-2"]}}'
assert_exit 0 "$RC" "flat fallback arrays accepted for every tier"
assert_eq "$(jq -c '.models.fast' "$OUT/config.json")" \
  '[{"model":"fast-1"},{"effort":"low","model":"fast-2"}]' "flat array entries normalized in order"
assert_eq "$(jq -c '.models.standard' "$OUT/config.json")" \
  '[{"model":"standard-1"}]' "single-entry array shape preserved"
assert_eq "$(jq -c '.models.deep' "$OUT/config.json")" \
  '[{"effort":"high","model":"deep-1"},{"model":"deep-2"}]' "mixed deep array normalized in order"

# 11. provider-scoped fallback arrays use the same canonical representation
run_loader '{"models":{"openai":{"standard":["gpt-primary",{"model":"gpt-fallback","effort":"xhigh"}]}}}'
assert_exit 0 "$RC" "provider-scoped fallback array accepted"
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
  '[{"model":"gpt-primary"},{"effort":"xhigh","model":"gpt-fallback"}]' \
  "provider array normalized without reordering"

# 12. arrays must be non-empty
run_loader '{"models":{"deep":[]}}'
assert_exit 1 "$RC" "empty fallback array rejected"
assert_contains "$(cat "$ERRLOG")" "models.deep must be a non-empty array" "empty error names tier path"

# 13. malformed entries report their exact array index
for invalid in 'null' '42' '["nested"]' '{"effort":"low"}' '{"model":"x","bogus":true}'; do
  run_loader "{\"models\":{\"deep\":[\"primary\",$invalid]}}"
  assert_exit 1 "$RC" "malformed fallback entry rejected: $invalid"
  assert_contains "$(cat "$ERRLOG")" "models.deep[1]" "malformed entry error names array index: $invalid"
done

# 14. array object entries retain scalar leaf effort validation
run_loader '{"models":{"deep":["primary",{"model":"fallback","effort":"turbo"}]}}'
assert_exit 1 "$RC" "invalid array-entry effort rejected"
assert_contains "$(cat "$ERRLOG")" "models.deep[1].effort must be one of" \
  "invalid array-entry effort names indexed path"

run_loader '{"models":{"deep":["primary",{"model":"fallback","effort":7}]}}'
assert_exit 1 "$RC" "non-string array-entry effort rejected"
assert_contains "$(cat "$ERRLOG")" "models.deep[1].effort must be a string" \
  "non-string array-entry effort names indexed path"

run_loader '{"models":{"deep":["primary",{"model":"fallback","effort":""}]}}'
assert_exit 0 "$RC" "empty array-entry effort accepted as unset"
assert_eq "$(jq -c '.models.deep[1]' "$OUT/config.json")" '{"model":"fallback"}' \
  "empty array-entry effort dropped"

finish
