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

# The dispatched brief is the text between a prompt's first four-backtick fence
# and its close — exactly what the controller sends to the subagent. A guard in
# the controller-facing preamble (outside the fence) never reaches the subagent,
# so prompt assertions run against this region only, not the whole file.
fenced_brief() {
  awk 'BEGIN{f=0} /^````[[:space:]]*$/{f++; next} f==1' "$1"
}

# Newline-flattened, case-insensitive regex match. Content is flattened because
# the guard emphasizes "Do NOT" and wraps across physical lines.
assert_matches() {
  local content="$1" regex="$2" message="$3"
  if printf '%s' "$content" | tr '\n' ' ' | grep -Eiq -- "$regex"; then
    pass
  else
    fail "$message"
    echo "    content does not match [$regex]"
  fi
}

# Assert CONTENT carries the self-contained guard forbidding BOTH load paths.
assert_self_contained_guard() {
  local content="$1" label="$2"
  assert_contains "$content" "self-contained" \
    "$label must declare the brief self-contained"
  # Bind the negation to the guard sentence with [^.]*, not a greedy .* — an
  # unrelated "do not"/"never" elsewhere must not satisfy the check when the
  # guard's own negation is dropped. skill://woostack-review sits before the
  # SKILL.md inline-code period, so [^.]* still reaches it.
  assert_matches "$content" "(do not|never)[^.]*skill://woostack-review" \
    "$label must forbid loading skill://woostack-review into the subagent"
  # The guard forbids TWO paths; pin the using-woostack routing clause too (the
  # primary vector this fix addresses). Match the backtick-wrapped token so the
  # unrelated ../../using-woostack/... doc link (slash-form) cannot false-satisfy
  # it — the [^.]* form above breaks here, as the SKILL.md period precedes it.
  assert_contains "$content" '`using-woostack`' \
    "$label must forbid routing via using-woostack"
}

PROMPTS="$ROOT/skills/woostack-execute/prompts"
DRIVER="$ROOT/skills/woostack-execute/references/subagent-driver.md"

# The three dispatched prompts: the guard must live INSIDE the fenced brief.
for f in "$PROMPTS/implementer.md" "$PROMPTS/spec-reviewer.md" "$PROMPTS/quality-reviewer.md"; do
  brief="$(fenced_brief "$f")"
  base="$(basename "$f")"
  if [ -z "$brief" ]; then
    fail "$base has no four-backtick fenced brief block"
    continue
  fi
  assert_self_contained_guard "$brief" "$base fenced brief"
done

# The driver records the dispatch contract for the controller and is read whole
# (it has no dispatched fence), so assert against the entire file.
assert_self_contained_guard "$(cat "$DRIVER")" "subagent-driver.md"

finish
