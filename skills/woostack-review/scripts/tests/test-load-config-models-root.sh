#!/usr/bin/env bash
# Root `models` field: relocation (clean break from review.models), string|object
# leaf normalization, effort enum, empty-effort-unset, host-agnostic flat leaves.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

# run_loader <config-json> : sets OUT (flat config dir), ERRLOG, RC.
run_loader() {
  local cfg="$1"
  REPO="$(mktemp -d)"; ( cd "$REPO" && git init -q )
  local top; top="$(cd "$REPO" && git rev-parse --show-toplevel)"
  mkdir -p "$top/.woostack"
  printf '%s\n' "$cfg" > "$top/.woostack/config.json"
  OUT="$(mktemp -d)/out"; mkdir -p "$OUT"; ERRLOG="$OUT/err"
  ( cd "$top" && env -u GITHUB_WORKSPACE OUTDIR="$OUT" bash "$SCRIPT" ) \
    >"$OUT/out.log" 2>"$ERRLOG" && RC=0 || RC=$?
}

# 1. object leaf normalized + preserved
run_loader '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}'
assert_exit 0 "$RC" "root models object leaf accepted"
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
  '{"effort":"low","model":"gpt-5.4-mini"}' "object leaf preserved (sorted keys)"

# 2. string leaf normalized to object
run_loader '{"models":{"openai":{"standard":"gpt-5.4-mini"}}}'
assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
  '{"model":"gpt-5.4-mini"}' "string leaf normalized to {model}"

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

finish
