#!/usr/bin/env bash
set -euo pipefail

# Legacy filename retained so existing test runners keep discovering the Build chain contract.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

BUILD_SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
AUTHORITY="$ROOT/skills/woostack-init/references/artifact-backends.md"

assert_literal() { # file literal message
  local text
  text="$(cat "$1")"
  if [[ "$text" == *"$2"* ]]; then pass; else fail "$3"; fi
}

assert_normalized_literal() { # file literal message
  local text
  text="$(tr -s '[:space:]' ' ' < "$1")"
  if [[ "$text" == *"$2"* ]]; then pass; else fail "$3"; fi
}

for file in "$BUILD_SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required build contract exists: ${file#"$ROOT/"}"; fi
done

assert_literal "$BUILD_SKILL" \
  'allocate or resume canonical local run' \
  'build allocates or resumes its canonical local run'
assert_literal "$BUILD_SKILL" \
  'draft Ideate/Harden locally with zero provider calls' \
  'Build performs local Ideate and Harden after baseline admission'
assert_literal "$BUILD_SKILL" \
  'render and present complete `project-spec.md` followed by a body-free `Accept`/`Abandon` Ask' \
  'complete project artifact stream precedes body-free approval'
assert_literal "$BUILD_SKILL" \
  'record local `projectSpecApprovalRecord`' \
  'project approval produces local projectSpecApprovalRecord'
assert_literal "$BUILD_SKILL" \
  'draft delegated Plan/Harden locally with zero provider calls' \
  'planning is provider-free before approval'
assert_literal "$BUILD_SKILL" \
  'render and present complete `execution-plan.md` followed by a body-free `Accept`/`Abandon` Ask' \
  'complete plan artifact stream precedes body-free approval'
assert_literal "$BUILD_SKILL" \
  'record local `executionPlanApprovalRecord`' \
  'plan approval produces local executionPlanApprovalRecord'
assert_literal "$BUILD_SKILL" \
  'Build then asks a body-free handoff question' \
  'second approval ends at user-controlled handoff'
assert_literal "$BUILD_SKILL" \
  'Build never merges' \
  'Build never merges'

for forbidden in 'Run overnight' 'Replan' 'parallel roots' 'terminal choices'; do
  if [[ "$(cat "$BUILD_SKILL")" == *"$forbidden"* ]]; then
    fail "Build removes retired routing menu: $forbidden"
  else
    pass
  fi
done

assert_literal "$PROCEDURE" \
  'one direct project issue per current increment' \
  'plan graph has one direct issue per increment'
assert_literal "$PROCEDURE" \
  'complete executor-ready issue descriptions' \
  'increment issues contain executable plans'
assert_literal "$PROCEDURE" \
  'Then independently read the complete relation' \
  'native dependencies require complete read-back'
assert_literal "$CONTEXT" \
  'That exact snapshot is gate 1' \
  'gate 1 starts from one admitted exact baseline'
assert_literal "$CONTEXT" \
  'Delegated Plan and Harden then make zero provider' \
  'gate 2 drafting has no intermediate provider cycle'
assert_literal "$AUTHORITY" \
  'only after that exact content read-back, record the matching' \
  'receipt creation follows exact content read-back'
assert_normalized_literal "$AUTHORITY" \
  'The canonical persistent artifact store for `woostack-build` and project-backed `woostack-fix` is local in `.woostack/tmp/runs/<run-id>/`.' \
  'shared contract makes the local run store canonical'
assert_normalized_literal "$AUTHORITY" \
  'workflow gate. Git, Graphite, and canonical GitHub reads prove source' \
  'direct Git, Graphite, and canonical GitHub reads prove source facts'
assert_normalized_literal "$AUTHORITY" \
  'artifacts are not source-control or delivery authority' \
  'source-control truth remains separate'

finish
