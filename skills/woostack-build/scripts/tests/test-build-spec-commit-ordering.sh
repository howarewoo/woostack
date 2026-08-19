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
  'writes plain Markdown `project-spec.md`' \
  'plain project-spec writing'
assert_literal "$BUILD_SKILL" \
  'draft delegated Plan/Harden locally with zero provider calls' \
  'planning is provider-free before writing'
assert_literal "$BUILD_SKILL" \
  'writes plain Markdown `execution-plan.md`' \
  'plain execution-plan writing'
assert_literal "$BUILD_SKILL" \
  'Build then asks a body-free handoff question' \
  'ends at user-controlled handoff'
assert_literal "$BUILD_SKILL" \
  'Never merges' \
  'Build never merges'

for forbidden in 'Run overnight' 'Replan' 'parallel roots' 'terminal choices' 'projectSpecApprovalRecord' 'executionPlanApprovalRecord'; do
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
  'That exact snapshot is the baseline when mirroring is enabled' \
  'starts from one admitted exact baseline'
assert_literal "$CONTEXT" \
  'Delegated Plan and Harden then make zero provider' \
  'drafting has no intermediate provider cycle'
assert_normalized_literal "$AUTHORITY" \
  'The canonical persistent store for `woostack-build` and project-backed `woostack-fix` is `.woostack/tmp/runs/<run-id>/`.' \
  'shared contract makes the local run store canonical'
assert_normalized_literal "$AUTHORITY" \
  'Git, Graphite, and canonical GitHub reads prove source, ancestry, pull-request, review, and merge facts.' \
  'direct Git, Graphite, and canonical GitHub reads prove source facts'
assert_normalized_literal "$AUTHORITY" \
  'Merge authority remains human-only and outside every woostack workflow.' \
  'merge authority remains human-only'

finish
