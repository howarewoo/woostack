#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-execute/SKILL.md"
CONTROLLER="$ROOT/skills/woostack-execute/references/controller.md"
FIX="$ROOT/skills/woostack-fix/SKILL.md"

controller="$(tr '\n' ' ' < "$CONTROLLER" | tr -s ' ')"
assert_contains "$(cat "$SKILL")" '/woostack-execute <exact standalone issue UUID-or-URL>' \
  "execute admits an exact standalone work-item identity"
assert_contains "$(cat "$SKILL")" 'issue number, recency, branch, PR, or local file.' \
  "execute rejects display identifiers as authority"
assert_contains "$(cat "$SKILL")" '/woostack-commit --issue <exact verified issue UUID-or-URL>' \
  "standalone execution passes exact issue identity to commit"
assert_contains "$controller" 'calls no repository Linear adapter or custom HTTP/GraphQL transport' \
  "standalone execution bypasses repository adapter routing"
assert_contains "$(cat "$SKILL")" 'Standalone execution performs no project read or mutation' \
  "standalone execution cannot mutate project lifecycle"
assert_contains "$(cat "$CONTROLLER")" 'with the exact issue and optional' \
  "project execution passes exact issue identity to commit"
assert_contains "$(cat "$FIX")" '/woostack-execute <exact Linear issue UUID-or-URL> --subagent' \
  "fix hands the standalone issue to the supported execute route"

finish
