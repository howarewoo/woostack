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
  'Linear projects and issues may persist those artifacts' \
  'build admits artifact-free design, specification, and planning'
assert_literal "$BUILD_SKILL" \
  'The user'\''s request and the three explicit gates authorize this workflow' \
  'workflow gates, not artifacts, authorize work'
assert_literal "$BUILD_SKILL" \
  'Without explicit artifact' \
  'artifact-free build makes no Linear call'
assert_literal "$BUILD_SKILL" \
  'ideate → approve design → harden specification → approve specification →' \
  'build preserves the ordered design and specification gates'
assert_literal "$BUILD_SKILL" \
  'plan → harden increment graph → approve execution → execute → review → hand back' \
  'build preserves the ordered planning and execution handoff'
assert_literal "$BUILD_SKILL" \
  'Build owns exactly these three barriers, in this order' \
  'build retains exactly three explicit gates'
assert_literal "$BUILD_SKILL" \
  'No implementation branch, worktree, commit, or PR may exist before an explicit' \
  'implementation stays behind execution approval'
assert_literal "$BUILD_SKILL" \
  'Build never creates a docs-only base PR and never merges' \
  'retired docs-only approval PR remains absent'

assert_literal "$PROCEDURE" \
  'It runs only when the caller selected artifact persistence' \
  'Linear procedure is opt-in synchronization'
assert_literal "$PROCEDURE" \
  'Never create a project merely because build, plan, or' \
  'build never creates an implicit project'
assert_literal "$PROCEDURE" \
  'Independently read every append or update back' \
  'optional artifact writes require independent read-back'
assert_literal "$PROCEDURE" \
  'Artifact failure blocks the repository workflow only when successful persistence was explicitly' \
  'artifact failure is scoped to the requested deliverable'

assert_literal "$CONTEXT" \
  'Artifact-free build and planning runs skip this' \
  'project context is skipped in artifact-free mode'
assert_literal "$CONTEXT" \
  'They do not assign an engineer, clear a workflow gate, authorize execution, prove delivery' \
  'provider fields remain descriptive'
assert_literal "$AUTHORITY" \
  'No woostack command requires an issue or project merely to run' \
  'shared artifact authority is optional'
assert_literal "$AUTHORITY" \
  'This substitution changes storage only, never safety' \
  'artifact-free storage preserves safety'

finish
