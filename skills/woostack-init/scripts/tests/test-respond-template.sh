#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
template="$HERE/../../templates/config.json"
ignore="$HERE/../../templates/gitignore"
keep="$HERE/../../templates/respond/.gitkeep"

python3 -m json.tool "$template" >/dev/null
body="$(cat "$template")"
assert_contains "$body" '"models": {}' "models namespace remains"
assert_contains "$body" '"review": {}' "review namespace remains"
assert_contains "$body" '"respond": {}' "respond namespace is scaffolded"
assert_contains "$body" '"status": {' "status namespace remains"
assert_not_contains "$body" 'token' "template contains no token key"
assert_not_contains "$body" 'api_key' "template contains no api key"
assert_not_contains "$body" 'password' "template contains no password"
assert_contains "$(cat "$ignore")" 'respond/evidence/' "response evidence is ignored"
assert_exit 1 "$(grep -qx 'respond/' "$ignore"; echo $?)" "response reports remain tracked"
assert_eq "$(test -f "$keep"; echo $?)" "0" "response scaffold marker exists"
finish
