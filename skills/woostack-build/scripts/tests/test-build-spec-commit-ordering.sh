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

for file in "$BUILD_SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required build contract exists: ${file#"$ROOT/"}"; fi
done

assert_literal "$BUILD_SKILL" \
  'resolve/create canonical project' \
  'build resolves or creates its canonical project first'
assert_literal "$BUILD_SKILL" \
  'Ideate →' \
  'Build enters Ideate after project resolution'
assert_literal "$BUILD_SKILL" \
  'Harden →' \
  'Build hardens before project approval'
assert_literal "$BUILD_SKILL" \
  'project-spec approval in the active conversation' \
  'project approval is an active-conversation stop'
assert_literal "$BUILD_SKILL" \
  'projectSpecApprovalRecord' \
  'project approval is recorded in Linear'
assert_literal "$BUILD_SKILL" \
  'Plan →' \
  'planning follows project approval'
assert_literal "$BUILD_SKILL" \
  'candidate strict sequential direct-issue chain' \
  'delegated planning returns a strict candidate'
assert_literal "$BUILD_SKILL" \
  'performs no provider read or mutation' \
  'delegated planning does not mutate Linear'
assert_literal "$BUILD_SKILL" \
  'execution-plan approval in the active conversation' \
  'plan approval is an active-conversation stop'
assert_literal "$BUILD_SKILL" \
  'executionPlanApprovalRecord' \
  'plan approval is recorded in Linear'
assert_literal "$BUILD_SKILL" \
  'Build always invokes' \
  'second approval has one normal Execute path'
assert_literal "$BUILD_SKILL" \
  'Build never merges' \
  'Build never merges'

for forbidden in 'Run overnight' 'Hand off' 'Replan' 'Abandon' 'parallel roots' 'terminal choices'; do
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
  'direct project membership and no parent/container relation' \
  'increment issues have no wrapper hierarchy'
assert_literal "$PROCEDURE" \
  'complete executor-ready issue descriptions' \
  'increment issues contain executable plans'
assert_literal "$PROCEDURE" \
  'Independently read the complete relation set back' \
  'native dependencies require complete read-back'
assert_literal "$CONTEXT" \
  'Gate 1 requires an independently read complete project snapshot' \
  'project approval binds an exact canonical revision'
assert_literal "$CONTEXT" \
  'Gate 2 requires complete exact issue fingerprints' \
  'execution approval binds the complete direct issue graph'
assert_literal "$AUTHORITY" \
  'Linear projects and issues are canonical product records for `woostack-build`' \
  'shared contract makes Build records canonical'
assert_literal "$AUTHORITY" \
  'Graphite, and canonical GitHub reads prove source, ancestry, PR, review, and merge facts.' \
  'source-control truth remains separate'

finish
