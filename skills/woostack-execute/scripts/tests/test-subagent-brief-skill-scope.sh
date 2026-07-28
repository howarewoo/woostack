#!/usr/bin/env bash
# Regression: execute workers receive a self-contained brief for exactly one verified Linear issue.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

# The dispatched template text is the content between the first four-backtick fence and its close.
fenced_brief() {
  awk 'BEGIN{f=0} /^````[[:space:]]*$/{f++; next} f==1' "$1"
}

assert_matches() {
  local content="$1" regex="$2" message="$3"
  if printf '%s' "$content" | tr '\n' ' ' | grep -Eiq -- "$regex"; then
    pass
  else
    fail "$message"
    echo "    content does not match [$regex]"
  fi
}

assert_self_contained_guard() {
  local content="$1" label="$2"
  assert_contains "$content" "self-contained" \
    "$label must declare the brief self-contained"
  assert_matches "$content" "(do not|never)[^.]*skill://woostack-review" \
    "$label must forbid loading skill://woostack-review"
  assert_contains "$content" '`using-woostack`' \
    "$label must forbid command routing through using-woostack"
}

PROMPTS="$ROOT/skills/woostack-execute/prompts"
DRIVER="$ROOT/skills/woostack-execute/references/subagent-driver.md"

driver="$(tr '\n' ' ' < "$DRIVER" | tr -s ' ')"
for f in "$PROMPTS/implementer.md" "$PROMPTS/spec-reviewer.md" "$PROMPTS/quality-reviewer.md"; do
  brief="$(fenced_brief "$f")"
  base="$(basename "$f")"
  if [ -z "$brief" ]; then
    fail "$base has no four-backtick fenced brief block"
    continue
  fi
  assert_self_contained_guard "$brief" "$base fenced brief"
done
assert_self_contained_guard "$driver" "subagent-driver.md"
spec_brief="$(fenced_brief "$PROMPTS/spec-reviewer.md")"
quality_brief="$(fenced_brief "$PROMPTS/quality-reviewer.md")"
for required in \
  "exact issue UUID/URL" \
  "complete issue contract" \
  "complete issue task set" \
  "complete issue-wide uncommitted diff" \
  "authenticated reviewer kind/ID" \
  "current byte-safe diff hash"; do
  assert_contains "$spec_brief" "$required" \
    "spec reviewer must bind its issue-wide receipt field: $required"
  assert_contains "$quality_brief" "$required" \
    "quality reviewer must bind its issue-wide receipt field: $required"
done
assert_contains "$spec_brief" "VERDICT: PASS" \
  "spec reviewer must emit a literal PASS receipt"
assert_contains "$quality_brief" "passing spec-review receipt" \
  "quality review must consume the exact passing spec receipt"
assert_contains "$quality_brief" "VERDICT: PASS" \
  "quality reviewer must emit a literal PASS receipt"

# The controller-facing driver must layer exact issue identity and authority barriers into every
# dispatched template.
assert_contains "$driver" "Every dispatched paired coder, generic implementer, or generic reviewer brief is self-contained and" \
  "driver must scope every worker to one issue"
assert_contains "$driver" "exact issue UUID/URL" \
  "driver must carry exact Linear issue identity"
assert_contains "$driver" "current issue contract revision/hash" \
  "driver must pin the verified contract revision"
assert_contains "$driver" 'verified type-aware owner kind/principal' \
  "driver must carry the type-aware owner receipt"
assert_contains "$driver" '`assignmentAccepted` event/read-back' \
  "driver must carry assignment acceptance read-back"
assert_contains "$driver" "The task text comes only from that verified issue contract" \
  "driver must derive task text only from the issue"
assert_contains "$driver" "The packet must be complete, current," \
  "driver must require one complete verified issue packet"
assert_contains "$driver" "self-consistent, and scoped to exactly one issue; otherwise do not dispatch" \
  "driver must fail closed on an unsafe brief"

# Coding and reviewing workers cannot mutate the controller's allocation, project, gate, PR, or
# acceptance boundaries even when their paired profile can reach the same providers.
for required in \
  "edit the issue description, scope, acceptance criteria" \
  "append project updates, change project phase/status, clear a gate" \
  "allocate/reassign work" \
  "accept its own evidence" \
  'request/write terminal `done`' \
  "commit, push, submit, or create/update a PR"; do
  assert_contains "$driver" "$required" \
    "driver must preserve worker authority barrier: $required"
done
assert_contains "$driver" "Implementation workers are never dispatched in parallel against that shared tree" \
  "tasks for one issue must remain sequential"
assert_contains "$driver" "There is no per-task commit" \
  "controller must retain the one-issue commit boundary"
assert_contains "$driver" "immediately before each implementer dispatch and each fix redispatch" \
  "controller must recheck ownership before worker edits"
assert_contains "$driver" "not record Linear evidence or lifecycle mutations" \
  "worker results must remain evidence for the controller"


finish
