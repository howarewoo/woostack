#!/usr/bin/env bash
# Test model routing for OpenAI/Codex in load-prompt.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-prompt.sh"

run_load_prompt() {
  local outdir="$1"
  local github_output="$2"
  shift 2

  local stdout="$outdir/stdout"
  local stderr="$outdir/stderr"
  if ! env -i \
    PATH="$PATH" \
    HOME="${HOME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    PROVIDER="openai" \
    ACTION_PATH="$ROOT/skills/woostack-review" \
    GITHUB_OUTPUT="$github_output" \
    OUTDIR="$outdir" \
    "$@" \
    bash "$SCRIPT" > "$stdout" 2> "$stderr"; then
    cat "$stdout"
    cat "$stderr" >&2
    return 1
  fi
}

run_load_prompt_expect_failure() {
  local outdir="$1"
  local github_output="$2"
  shift 2

  local stdout="$outdir/stdout"
  local stderr="$outdir/stderr"
  if env -i \
    PATH="$PATH" \
    HOME="${HOME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    PROVIDER="openai" \
    ACTION_PATH="$ROOT/skills/woostack-review" \
    GITHUB_OUTPUT="$github_output" \
    OUTDIR="$outdir" \
    "$@" \
    bash "$SCRIPT" > "$stdout" 2> "$stderr"; then
    cat "$stdout"
    echo "expected load-prompt.sh to fail" >&2
    return 1
  fi
}

run_test() {
  local tier="$1"
  local expected_model="$2"
  local expected_effort="$3"
  
  local outdir
  outdir="$(mktemp -d)"
  local github_output="$outdir/github_output"
  touch "$github_output"
  
  run_load_prompt "$outdir" "$github_output" INPUT_FORCE_TIER="$tier"
  
  local run_model
  run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
  local run_effort
  run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
  
  assert_eq "$run_model" "$expected_model" "OpenAI/Codex routing for tier '$tier' resolves to '$expected_model'"
  assert_eq "$run_effort" "$expected_effort" "OpenAI/Codex effort for tier '$tier' resolves to '$expected_effort'"
  
  rm -rf "$outdir"
}

# Run tests for each tier
run_test "fast" "gpt-5.3-codex-spark" "xhigh"
run_test "" "gpt-5.4-mini" "xhigh"
run_test "deep" "gpt-5.5" "medium"

# If FORCE_TIER is unset, standard should be the default
outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"

run_load_prompt "$outdir" "$github_output"

run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_model" "gpt-5.4-mini" "Default OpenAI/Codex routing (no FORCE_TIER) resolves to 'gpt-5.4-mini'"
assert_eq "$run_effort" "xhigh" "Default OpenAI/Codex effort (no FORCE_TIER) resolves to 'xhigh'"
rm -rf "$outdir"

# Explicit effort override should win over the tier default.
outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"

run_load_prompt "$outdir" "$github_output" INPUT_FORCE_TIER="fast" INPUT_OPENAI_EFFORT="low"

run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_effort" "low" "Explicit OpenAI/Codex effort override wins over tier default"
rm -rf "$outdir"

# Explicit model overrides derive effort from known model slugs instead of the
# placeholder standard tier.
outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"

run_load_prompt "$outdir" "$github_output" INPUT_MODEL="gpt-5.5"

run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_model" "gpt-5.5" "Explicit OpenAI/Codex model override wins"
assert_eq "$run_effort" "medium" "Explicit gpt-5.5 override resolves to medium effort"
rm -rf "$outdir"

outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"

run_load_prompt "$outdir" "$github_output" INPUT_MODEL="gpt-5.4-mini"

run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_effort" "xhigh" "Explicit gpt-5.4-mini override resolves to xhigh effort"
rm -rf "$outdir"

outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"
printf '%s\n' '{"models":{"openai":{"standard":"gpt-5.5"}}}' > "$outdir/config.json"

run_load_prompt "$outdir" "$github_output"

run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_model" "gpt-5.5" "Config model override wins for standard tier"
assert_eq "$run_effort" "medium" "Config gpt-5.5 override resolves to medium effort"
rm -rf "$outdir"

outdir="$(mktemp -d)"
github_output="$outdir/github_output"
touch "$github_output"

run_load_prompt_expect_failure "$outdir" "$github_output" INPUT_OPENAI_EFFORT="bogus"

assert_contains "$(cat "$outdir/stdout" "$outdir/stderr")" "run_effort must be one of" "Invalid effort emits validation error"
assert_eq "$(grep -c '^run_effort=bogus$' "$github_output" || true)" "0" "Invalid effort is not emitted"
rm -rf "$outdir"

# Config object-leaf effort wins over the model/tier default.
outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}' > "$outdir/config.json"
run_load_prompt "$outdir" "$github_output"
run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_model" "gpt-5.4-mini" "config object leaf model resolves"
assert_eq "$run_effort" "low" "config .effort wins over tier/model default"
rm -rf "$outdir"

# INPUT_OPENAI_EFFORT still beats config .effort.
outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}' > "$outdir/config.json"
run_load_prompt "$outdir" "$github_output" INPUT_OPENAI_EFFORT="high"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_effort" "high" "explicit INPUT_OPENAI_EFFORT beats config .effort"
rm -rf "$outdir"

# Object leaf without effort falls through to the model default (xhigh for gpt-5.4-mini).
outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini"}}}}' > "$outdir/config.json"
run_load_prompt "$outdir" "$github_output"
run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
assert_eq "$run_effort" "xhigh" "object leaf without effort uses model/tier default"
rm -rf "$outdir"

finish
