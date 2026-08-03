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
  if [[ "$text" == *"$2"* ]]; then pass; else fail "$3"; fi
}

for file in "$SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required workflow reference exists: ${file#"$ROOT/"}"; fi
done

for heading in \
  '## Commands' \
  '## Fixed chain' \
  '## Exactly two approval stops' \
  '## Execute transition'; do
  assert_literal "$SKILL" "$heading" "root retains workflow section: $heading"
done
assert_literal "$SKILL" \
  '[Linear artifact contract](../woostack-init/references/artifact-backends.md)' \
  'root links the shared artifact contract'
assert_literal "$SKILL" \
  '[repository/project context procedure](references/linear-context.md)' \
  'root links the project context procedure'
assert_literal "$SKILL" \
  '[Linear synchronization procedure](references/linear-procedure.md)' \
  'root links the provider synchronization procedure'
assert_literal "$SKILL" \
  'projectSpecApprovalRecord' \
  'root names the shared project approval record'
assert_literal "$SKILL" \
  'executionPlanApprovalRecord' \
  'root names the shared execution approval record'
assert_literal "$SKILL" \
  'active conversation' \
  'root requires active-conversation approval'
assert_literal "$SKILL" \
  'normal [`woostack-execute`]' \
  'root has one normal Execute transition'
assert_literal "$SKILL" \
  'no artifact-free' \
  'root has no artifact-free fallback'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 120 ]; then pass; else
  fail "root stays thin (actual: $root_lines)"
fi

for heading in \
  '## Build project lifecycle' \
  '## Increment graph synchronization' \
  '## Standalone plan' \
  '## Approval preparation' \
  '## Delivery notes' \
  '## Failures and resume'; do
  assert_literal "$PROCEDURE" "$heading" "Linear procedure retains section: $heading"
done
for heading in \
  '## Resolution' \
  '## Project specification read' \
  '## Direct increment graph read' \
  '## Drift and failure'; do
  assert_literal "$CONTEXT" "$heading" "Linear context retains section: $heading"
done

assert_literal "$PROCEDURE" \
  'It owns no workflow gate' \
  'synchronization procedure cannot clear approval'
assert_literal "$CONTEXT" \
  'conversation response without a Linear receipt, or read-back without the matching active approval' \
  'context rejects incomplete approval evidence'
assert_literal "$CONTEXT" \
  'There is no local, cached, or alternate-provider execution fallback' \
  'required build authority fails closed'
assert_literal "$AUTHORITY" \
  'Do not create a parent plan issue' \
  'shared contract forbids the retired plan wrapper'
assert_literal "$AUTHORITY" \
  'Report repository delivery and artifact synchronization as separate outcomes' \
  'shared contract separates repository and Linear results'

finish
