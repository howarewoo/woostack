#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../checks/omp-session-name.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
mkdir -p "$REPO/.woostack"

run_check() { bash "$CHECK" "$REPO"; }
fix_check() { bash "$CHECK" --fix "$REPO"; }

missing="$(run_check)"
assert_contains "$missing" $'warn\tomp-session-name\tauto\t' "missing assets produce auto findings"
assert_contains "$missing" "woostack-session-name.ts" "identifies missing extension"

fix_check >/dev/null
assert_eq "$(run_check)" "" "--fix clears missing findings"
assert_eq "$([ -f "$REPO/.omp/extensions/woostack-session-name.ts" ] && echo y)" "y" "creates extension"
assert_contains "$(cat "$REPO/.omp/settings.json")" '".omp/extensions/woostack-session-name.ts"' "creates settings entry"
assert_contains "$(cat "$REPO/.omp/.gitignore")" 'settings.json' "creates ignore entry"

printf '%s\n' 'consumer-ext' >"$REPO/.omp/extensions/custom.ts"
printf '%s\n' '{"theme": "dark", "extensions": [".omp/extensions/woostack-session-name.ts"]}' >"$REPO/.omp/settings.json"
printf '%s\n' '// stale' >"$REPO/.omp/extensions/woostack-session-name.ts"

assert_contains "$(run_check)" $'warn\tomp-session-name\tauto\t' "reports drifted extension"
fix_check >/dev/null
assert_eq "$(run_check)" "" "restores clean extension state"
assert_eq "$(cat "$REPO/.omp/extensions/custom.ts")" "consumer-ext" "preserves unrelated extensions"
assert_contains "$(cat "$REPO/.omp/settings.json")" '"theme": "dark"' "preserves settings keys"

finish
