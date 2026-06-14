#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
# exclude this guard file itself (it names the old path in its pattern).
hits="$(grep -rn --exclude=test-no-stale-paths.sh "woostack-init/scripts/doctor" "$ROOT/skills" 2>/dev/null || true)"
assert_eq "$hits" "" "no skill references the old woostack-init/scripts/doctor.sh path"
finish
