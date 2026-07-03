#!/usr/bin/env bash
# Regression for issue #447: local review angle workers must be plain workers,
# never woostack-review skill-scoped agents that auto-load the full orchestrator.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

assert_file_contains() {
  local file="$1" needle="$2" message="$3"
  assert_contains "$(cat "$file")" "$needle" "$message"
}

REVIEW_SKILL="$ROOT/skills/woostack-review/SKILL.md"
ANTHROPIC="$ROOT/skills/woostack-review/prompts/anthropic.md"
GOOGLE="$ROOT/skills/woostack-review/prompts/google.md"
OPENCODE="$ROOT/skills/woostack-review/prompts/opencode.md"
OPENAI="$ROOT/skills/woostack-review/prompts/openai.md"

# Generic Stage 3 is the source of truth for local hosts.
assert_file_contains "$REVIEW_SKILL" "plain/general-purpose/default" \
  "Stage 3 requires plain/general/default review workers"
assert_file_contains "$REVIEW_SKILL" "skill://woostack-review" \
  "Stage 3 forbids loading the woostack-review skill into workers"
assert_file_contains "$REVIEW_SKILL" "The worker brief is self-contained" \
  "worker brief tells auto-injected skill hosts to ignore the orchestrator"

# Provider templates that dispatch local subagents must carry the same boundary.
for prompt in "$ANTHROPIC" "$GOOGLE" "$OPENCODE" "$OPENAI"; do
  assert_file_contains "$prompt" "skill://woostack-review" \
    "$(basename "$prompt") names the forbidden skill-scope attachment"
  assert_file_contains "$prompt" "plain/general-purpose/default" \
    "$(basename "$prompt") requires plain/general/default workers"
done

assert_file_contains "$ANTHROPIC" 'subagent_type: "general-purpose"' \
  "Anthropic Task example stays on the general-purpose subagent profile"

finish
