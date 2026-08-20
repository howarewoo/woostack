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
  '## Readable plain artifacts' \
  '## Verified handoff'; do
  assert_literal "$SKILL" "$heading" "root retains workflow section: $heading"
done
assert_literal "$SKILL" \
  '[Linear artifact contract](../woostack-init/references/artifact-backends.md)' \
  'root links the shared artifact contract'
assert_literal "$SKILL" \
  '[repository/project context procedure](references/linear-context.md)' \
  'root links the project context procedure'
assert_literal "$SKILL" \
  '[`Linear synchronization procedure`](references/linear-procedure.md)' \
  'root links the provider synchronization procedure'
assert_literal "$SKILL" \
  'normal [`woostack-execute`]' \
  'root has one normal Execute transition'
assert_literal "$SKILL" \
  'authority is unconditional' \
  'root names canonical local authority'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 160 ]; then pass; else
  fail "root stays thin (actual: $root_lines)"
fi

for heading in \
  '## Build project lifecycle' \
  '## Increment graph synchronization' \
  '## Standalone plan' \
  '## Delivery notes'; do
  assert_literal "$PROCEDURE" "$heading" "Linear procedure retains section: $heading"
done
for heading in \
  '## Resolution' \
  '## Project specification baseline' \
  '## Direct increment graph baseline' \
  '## Drift and failure'; do
  assert_literal "$CONTEXT" "$heading" "Linear context retains section: $heading"
done

assert_literal "$PROCEDURE" \
  'It owns no workflow gate' \
  'synchronization procedure owns no workflow gate'
assert_literal "$CONTEXT" \
  'nonblocking for local' \
  'optional mirror failure does not block local authority'
assert_literal "$AUTHORITY" \
  'Do not create a parent plan issue' \
  'shared contract forbids the retired plan wrapper'
assert_literal "$AUTHORITY" \
  '## Planning base and Execute choice' \
  'shared contract defines planning base and Execute choice'

finish
