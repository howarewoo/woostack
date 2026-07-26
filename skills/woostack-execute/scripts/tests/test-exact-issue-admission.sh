#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-execute/SKILL.md"
CONTROLLER="$ROOT/skills/woostack-execute/references/controller.md"
FIX="$ROOT/skills/woostack-fix/SKILL.md"

assert_contains "$(cat "$SKILL")" 'exact Linear role-`work-item` issue UUID/URL' \
  "execute admits an exact standalone work-item identity"
assert_contains "$(cat "$SKILL")" 'issue identifier such as `TEAM-123` is insufficient.' \
  "execute rejects display identifiers as authority"
assert_contains "$(cat "$SKILL")" '/woostack-commit --issue <exact verified issue UUID-or-URL>' \
  "standalone execution passes exact issue identity to commit"
assert_contains "$(cat "$CONTROLLER")" 'without invoking `resolve-backend.sh`' \
  "standalone execution bypasses project/backend routing"
assert_contains "$(cat "$CONTROLLER")" 'do not run the project closure cadence' \
  "standalone execution cannot mutate project lifecycle"
assert_contains "$(cat "$CONTROLLER")" 'exact issue UUID/URL. An issue identifier is never commit identity.' \
  "project execution passes exact issue identity to commit"
assert_contains "$(cat "$FIX")" '/woostack-execute <exact Linear issue UUID-or-URL> --subagent' \
  "fix hands the standalone issue to the supported execute route"

finish
