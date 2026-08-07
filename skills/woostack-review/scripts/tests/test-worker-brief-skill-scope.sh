#!/usr/bin/env bash
# Regression for issue #447: local review angle workers must be fresh independent
# plain/general/default workers, never skill-scoped agents or the implementing coder.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

assert_file_contains() {
  local file="$1" needle="$2" message="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass
  else
    fail "$message"
    echo "    $(basename "$file") does not contain [$needle]"
  fi
}

assert_file_matches() {
  local file="$1" regex="$2" message="$3"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if printf '%s' "$content" | grep -Eq -- "$regex"; then
    pass
  else
    fail "$message"
    echo "    $(basename "$file") does not match [$regex]"
  fi
}

REVIEW_SKILL="$ROOT/skills/woostack-review/SKILL.md"
ANTHROPIC="$ROOT/skills/woostack-review/prompts/anthropic.md"
GOOGLE="$ROOT/skills/woostack-review/prompts/google.md"
OPENCODE="$ROOT/skills/woostack-review/prompts/opencode.md"
OPENAI="$ROOT/skills/woostack-review/prompts/openai.md"

# The simplified Review surface retains the isolation and authority boundary without duplicating
# host-specific dispatch prose.
assert_file_matches "$REVIEW_SKILL" \
  "fresh read-only profiles/sessions distinct from the implementing[[:space:]]+coder" \
  "Review requires fresh worker isolation from the implementing coder"
assert_file_matches "$REVIEW_SKILL" \
  "Workers cannot edit source/tests, post to GitHub, access Linear.*accept work, or merge" \
  "Review workers remain read-only and advisory"
assert_file_contains "$REVIEW_SKILL" \
  'prompts/_worker-header.md' \
  "Review links the canonical worker contract"

# Provider templates that dispatch local subagents must carry the same boundary
# as an explicit prohibition, not merely mention the forbidden scope token.
for prompt in "$ANTHROPIC" "$GOOGLE" "$OPENCODE" "$OPENAI"; do
  assert_file_matches "$prompt" "plain/general[^[:space:]]*/default.*(subagent|reviewer)" \
    "$(basename "$prompt") selects a plain/general/default worker"
  assert_file_matches "$prompt" "(Do not|do not|never).*(skill://woostack-review|@woostack-review|woostack-review skill-scoped)" \
    "$(basename "$prompt") forbids woostack-review skill-scoped workers"
done

assert_file_contains "$ANTHROPIC" 'subagent_type: "general-purpose"' \
  "Anthropic Task example stays on the general-purpose subagent profile"

finish
