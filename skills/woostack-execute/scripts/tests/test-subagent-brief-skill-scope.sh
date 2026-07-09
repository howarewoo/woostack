#!/usr/bin/env bash
# Regression: woostack-execute's dispatched subagent briefs must be self-contained.
# A fresh subagent boots inside the consumer repo and inherits its AGENTS.md, so a bare
# "review this task" brief routes through using-woostack into the full woostack-review
# orchestrator skill (~14.7K tokens) — the wrong contract for a task-scoped reviewer.
# Same bug class as woostack-review issue #447, extended to the execute subagent path.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

assert_file_contains() {
  local file="$1" needle="$2" message="$3"
  assert_contains "$(cat "$file")" "$needle" "$message"
}

# Newline-flattened, case-insensitive match (the guard emphasizes "Do NOT").
assert_file_matches() {
  local file="$1" regex="$2" message="$3"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if printf '%s' "$content" | grep -Eiq -- "$regex"; then
    pass
  else
    fail "$message"
    echo "    $(basename "$file") does not match [$regex]"
  fi
}

PROMPTS="$ROOT/skills/woostack-execute/prompts"
DRIVER="$ROOT/skills/woostack-execute/references/subagent-driver.md"

# Each dispatched brief, plus the driver that records the dispatch contract, must declare
# itself self-contained AND forbid loading the woostack-review orchestrator skill.
for f in "$PROMPTS/implementer.md" "$PROMPTS/spec-reviewer.md" "$PROMPTS/quality-reviewer.md" "$DRIVER"; do
  assert_file_contains "$f" "self-contained" \
    "$(basename "$f") must declare the subagent brief self-contained"
  assert_file_matches "$f" "(do not|never).*skill://woostack-review" \
    "$(basename "$f") must forbid loading skill://woostack-review into the subagent"
done

finish
