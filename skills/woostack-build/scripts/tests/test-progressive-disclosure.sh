#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
PLAN="$ROOT/skills/woostack-plan/SKILL.md"

for file in "$SKILL" "$PROCEDURE" "$CONTEXT" "$PLAN"; do
  if [ -f "$file" ]; then pass; else fail "required direct reference exists: ${file#"$ROOT"/}"; fi
done

ROOT_TEXT="$(cat "$SKILL")"
PROCEDURE_TEXT="$(cat "$PROCEDURE")"
CONTEXT_TEXT="$(cat "$CONTEXT")"
PLAN_TEXT="$(cat "$PLAN")"
WORKFLOW="$ROOT_TEXT
$PROCEDURE_TEXT
$CONTEXT_TEXT
$PLAN_TEXT"

assert_contains "$ROOT_TEXT" '(references/linear-context.md)' 'build links the retained context directly'
assert_contains "$ROOT_TEXT" '(references/linear-procedure.md)' 'build links the lifecycle procedure directly'
assert_contains "$ROOT_TEXT" 'Official host-exposed Linear MCP is the only development-record authority' 'build declares one authority'
assert_contains "$ROOT_TEXT" '## Exactly three hard gates' 'build exposes the gate contract'
assert_contains "$ROOT_TEXT" 'An incompatible executor is a blocker at `ready`' 'build blocks incompatible dispatch'

for forbidden in \
  'resolve-backend.sh' 'linear.sh' 'LINEAR_CONTEXT' 'markdown-procedure.md' \
  'managed spec document' 'selected backend' 'Markdown mode'; do
  assert_not_contains "$WORKFLOW" "$forbidden" "workflow excludes legacy token $forbidden"
done

assert_contains "$PROCEDURE_TEXT" '<!-- linear-gates: design-approval | spec-approval | execution-handoff -->' 'procedure retains the ordered gate manifest'
rest="$PROCEDURE_TEXT"
for token in \
  '<HARD-GATE name="design-approval">' '</HARD-GATE>' \
  '<HARD-GATE name="spec-approval">' '</HARD-GATE>' \
  '<HARD-GATE name="execution-handoff">' '</HARD-GATE>'; do
  if [[ "$rest" == *"$token"* ]]; then
    rest="${rest#*"$token"}"
  else
    fail "procedure gate order is missing $token"
  fi
done
count="$(grep -Ec '<HARD-GATE name="(design-approval|spec-approval|execution-handoff)">' <<< "$PROCEDURE_TEXT" || true)"
assert_eq "$count" 3 'procedure has exactly three structural barriers'

for token in \
  '`woostack-ideate` presents the complete design and obtains its explicit approval' \
  'build must not ask for design approval a second time' \
  'Immediately classify the approved design before any project mutation' \
  '[`woostack-change`](../../woostack-change/SKILL.md)' \
  'Continue from the observed current head' \
  'Never append another `designApproved`' \
  'authenticated actor must be that lead' \
  'append no `executionApproved`'; do
  assert_contains "$PROCEDURE_TEXT" "$token" "procedure retains $token"
done

for token in \
  'authenticated-actor' 'single-lead create/read verification' \
  'authenticated actor type/native ID' 'authority still agrees'; do
  assert_contains "$CONTEXT_TEXT" "$token" "context retains $token"
done

assert_contains "$PLAN_TEXT" '/woostack-plan <Linear project UUID-or-exact-URL>' 'planner has one direct public input'
assert_not_contains "$PLAN_TEXT" 'Markdown spec' 'planner does not expose the removed Markdown route'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 500 ]; then pass; else fail "root stays at or below 500 lines (actual: $root_lines)"; fi

finish
