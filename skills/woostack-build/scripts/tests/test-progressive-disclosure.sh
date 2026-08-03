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
  '## Overview' \
  '## Commands' \
  '## Fixed chain' \
  '## Exactly two hard gates' \
  '## Direct increment contract' \
  '## Terminal choices at gate 2' \
  '## Hard constraints'; do
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

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 180 ]; then pass; else
  fail "root stays concise (actual: $root_lines)"
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
  'A status, lead, label, update, conversation response, agent-authored comment' \
  'context rejects non-authoritative approval signals'
assert_literal "$CONTEXT" \
  'There is no local, conversational, cached, or alternate-provider execution fallback' \
  'required build authority fails closed'
assert_literal "$AUTHORITY" \
  'Do not create a parent plan issue' \
  'shared contract forbids the retired plan wrapper'
assert_literal "$AUTHORITY" \
  'Report repository delivery and artifact synchronization as separate outcomes' \
  'shared contract separates repository and Linear results'

finish
