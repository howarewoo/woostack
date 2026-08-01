#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
AUTHORITY="$ROOT/skills/woostack-init/references/artifact-backends.md"

assert_literal() { # file literal message
  local text
  text="$(cat "$1")"
  if [[ "$text" == *"$2"* ]]; then pass; else
    fail "$3"
    echo "    ${file#"$ROOT/"} does not contain [$2]"
  fi
}

for file in "$SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required workflow reference exists: ${file#"$ROOT/"}"; fi
done

# The root keeps the complete gate sequence and discloses Linear references at the plan boundary.
for heading in \
  '## Overview' \
  '## Authority and artifact context' \
  '## Fixed chain' \
  '## Exactly three hard gates' \
  '## Terminal choices at the execution handoff' \
  '## Hard constraints'; do
  assert_literal "$SKILL" "$heading" "root retains workflow section: $heading"
done
assert_literal "$SKILL" \
  '[Linear artifact contract](../woostack-init/references/artifact-backends.md)' \
  'root links the shared artifact contract'
assert_literal "$SKILL" \
  '[repository/project context procedure](references/linear-context.md)' \
  'root links the optional project context procedure'
assert_literal "$SKILL" \
  '[Linear synchronization procedure](references/linear-procedure.md)' \
  'root links the provider synchronization procedure'
assert_literal "$SKILL" \
  'An exact caller-supplied project or explicit persistence request selects artifact mode' \
  'root requires exact or explicit selection for plan persistence'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 500 ]; then pass; else
  fail "root stays at or below approximately 500 lines (actual: $root_lines)"
fi

# Provider details remain progressively disclosed behind the plan-persistence branch.
for heading in \
  '## Selection or creation' \
  '## Specification synchronization' \
  '## Plan hierarchy synchronization' \
  '## Delivery notes' \
  '## Failures and resume'; do
  assert_literal "$PROCEDURE" "$heading" "Linear procedure retains section: $heading"
done
for heading in \
  '## Admission' \
  '## Configuration' \
  '## Artifact fields' \
  '## Trust and reads' \
  '## Handback'; do
  assert_literal "$CONTEXT" "$heading" "Linear context retains section: $heading"
done

assert_literal "$PROCEDURE" \
  'It owns no workflow gate,' \
  'synchronization procedure cannot grant workflow authority'
assert_literal "$CONTEXT" \
  'Missing, multiple, partial, foreign, stale, or conflicting results block the selected artifact' \
  'artifact context failures stay scoped'
assert_literal "$CONTEXT" \
  'A mutation response alone is not proof' \
  'artifact context preserves independent read-back'
assert_literal "$AUTHORITY" \
  'default until the caller selects artifact mode' \
  'shared contract preserves artifact-free operation'
assert_literal "$AUTHORITY" \
  'uses one project, one parent plan issue, and' \
  'shared contract declares the required plan hierarchy'
assert_literal "$AUTHORITY" \
  'Report repository delivery and artifact synchronization as separate outcomes' \
  'shared contract reports repository and artifact results separately'

finish
