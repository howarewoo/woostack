#!/usr/bin/env bash
set -euo pipefail

# Legacy filename retained so existing test runners keep discovering the build ordering contract.

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
  'An exact caller-supplied project or explicit persistence request selects artifact mode' \
  'build enters artifact mode only after exact or explicit selection'
assert_literal "$BUILD_SKILL" \
  'The user'\''s request and the three explicit gates authorize this workflow' \
  'workflow gates, not artifacts, authorize work'
assert_literal "$BUILD_SKILL" \
  'make no Linear read or write' \
  'build remains artifact-free without selection'
assert_literal "$BUILD_SKILL" \
  'ideate → approve design → harden specification → approve specification →' \
  'build preserves the ordered design and specification gates'
assert_literal "$BUILD_SKILL" \
  'delegate candidate planning without provider mutation → harden increment graph →' \
  'build delegates planning before graph hardening'
assert_literal "$BUILD_SKILL" \
  'persist the selected Linear plan once → approve execution →' \
  'build persists once after hardening and before execution'
assert_literal "$BUILD_SKILL" \
  'Build owns exactly these three barriers, in this order' \
  'build retains exactly three explicit gates'
assert_literal "$BUILD_SKILL" \
  'No implementation branch, worktree,' \
  'implementation stays behind execution approval'
assert_literal "$BUILD_SKILL" \
  'Build never creates a docs-only base PR and never merges' \
  'retired docs-only approval PR remains absent'

assert_literal "$PROCEDURE" \
  'only after the caller supplies an exact resource or explicitly requests persistence' \
  'Linear procedure requires exact or explicit selection'
assert_literal "$PROCEDURE" \
  'one parent plan issue in the project' \
  'plan hierarchy has one parent issue'
assert_literal "$PROCEDURE" \
  'one native child issue under that parent for every increment' \
  'plan hierarchy has one child per increment'
assert_literal "$PROCEDURE" \
  'Independently read every append or update back' \
  'artifact writes require independent read-back'
assert_literal "$PROCEDURE" \
  'blocks the plan deliverable and execution handoff' \
  'selected persistence failure blocks plan handoff'

assert_literal "$CONTEXT" \
  'Repository policy alone never selects artifact mode or' \
  'repository policy cannot select provider access'
assert_literal "$CONTEXT" \
  'They do not assign an engineer, clear a workflow gate, authorize' \
  'provider fields remain descriptive'
assert_literal "$AUTHORITY" \
  'No woostack command requires an issue or project merely to run' \
  'shared artifact authority is optional'
assert_literal "$AUTHORITY" \
  'This substitution changes storage only, never safety' \
  'artifact-free storage preserves safety'

finish
