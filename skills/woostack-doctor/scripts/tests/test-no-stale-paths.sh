#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# exclude this guard file itself (it names the old path in its pattern).
hits="$(grep -rn --exclude=test-no-stale-paths.sh "woostack-init/scripts/doctor" "$ROOT/skills" 2>/dev/null || true)"
assert_eq "$hits" "" "no skill references the old woostack-init/scripts/doctor.sh path"
for obsolete in \
  "$ROOT/skills/woostack-doctor/scripts/checks/doc-type.sh" \
  "$ROOT/skills/woostack-doctor/scripts/checks/plan-source.sh" \
  "$ROOT/skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh" \
  "$ROOT/skills/woostack-doctor/scripts/checks/status-band.sh" \
  "$ROOT/skills/woostack-doctor/scripts/checks/status-enum.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-linear-backend.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-doc-type.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-plan-source.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-repair-apply.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-status-band.sh" \
  "$ROOT/skills/woostack-doctor/scripts/tests/test-status-enum.sh"; do
  [ ! -e "$obsolete" ] && pass ||
    fail "retired local development-record lint remains: $obsolete"
done
finish
