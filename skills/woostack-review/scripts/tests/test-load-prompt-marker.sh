#!/usr/bin/env bash
# Regression: under `set -o pipefail`, `printf "$large_header" | grep -q`
# can report failure when grep exits early. load-prompt must detect the model
# tier marker without a pipeline.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-prompt.sh"

tmp="$(mktemp -d)"
mkdir -p "$tmp/out"
printf '%s\n' '{"severity_floor":"high"}' > "$tmp/out/config.json"

(
  cd "$ROOT"
  PROVIDER=anthropic \
    ACTION_PATH="$ROOT/skills/woostack-review" \
    OUTDIR="$tmp/out" \
    GITHUB_OUTPUT="$tmp/github-output" \
    PR_NUMBER=291 \
    GITHUB_REPOSITORY=howarewoo/woostack \
    EVENT_NAME=pull_request \
    COMMENT_BODY="" \
    MODE=review \
    ANGLE=bugs \
    ENABLED_ANGLES=bugs \
    bash "$SCRIPT"
) >"$tmp/stdout" 2>"$tmp/stderr"

assert_contains "$(cat "$tmp/github-output")" "run_model=claude-sonnet-4-6" \
  "load-prompt resolves the default Anthropic model"
set +e
grep -qF "# Model Tiers (shared, host-agnostic)" "$tmp/github-output"
table_status=$?
set -e
assert_eq "$table_status" "0" \
  "load-prompt output includes the inlined model tier table"
assert_not_contains "$(cat "$tmp/stderr")" "missing the <!-- WOO_MODEL_TIERS_TABLE --> inline marker" \
  "marker check does not false-fail under pipefail"

rm -rf "$tmp"
finish
