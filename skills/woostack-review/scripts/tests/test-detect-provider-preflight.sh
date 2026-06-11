#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-provider.sh"

unset INPUT_PROVIDER INPUT_ANTHROPIC_TOKEN INPUT_ANTHROPIC_API_KEY \
      INPUT_OPENAI_API_KEY INPUT_OPENAI_ACCESS_TOKEN INPUT_GOOGLE_API_KEY INPUT_GEMINI_API_KEY \
      INPUT_OPENROUTER_API_KEY 2>/dev/null || true

rc=0; err="$(bash "$SCRIPT" 2>&1)" || rc=$?
assert_exit 1 "$rc" "no provider/runner → exit 1"
assert_contains "$err" "no model provider/runner resolvable" "actionable preflight message"
assert_contains "$err" "install auth" "message names the auth remedy"

rc=0; err="$(INPUT_PROVIDER=openai bash "$SCRIPT" 2>&1)" || rc=$?
assert_exit 1 "$rc" "explicit OpenAI without credential → exit 1"
assert_contains "$err" "provider 'openai' selected" "explicit OpenAI credential error names provider"

tmp_output="$(mktemp)"
out="$(GITHUB_OUTPUT="$tmp_output" INPUT_OPENAI_ACCESS_TOKEN=codex-token bash "$SCRIPT")"
rm -f "$tmp_output"
assert_contains "$out" "Resolved provider: openai" "OpenAI access token resolves OpenAI provider"
finish
