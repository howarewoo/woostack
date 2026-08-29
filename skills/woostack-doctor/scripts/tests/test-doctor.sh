#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
mkdir -p "$repo/.woostack"
git -C "$repo" init -q
cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"local","linear":{"repository":"https://github.com/acme/widgets","workspace":"acme","team":"ENG","projectLabels":[],"projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}},"models":{},"review":{},"status":{"staleDays":14}}
JSON

run_doctor() {
  set +e
  OUT="$(bash "$DOCTOR" "$@" 2>&1)"
  CODE=$?
  set -e
}

run_doctor "$repo"
assert_exit 0 "$CODE" "valid static workspace exits zero"
assert_not_contains "$OUT" "linear-live" "static workspace does not claim provider validation"


mkdir -p "$TMP/missing"
run_doctor "$TMP/missing"
assert_exit 2 "$CODE" "missing workspace exits two"
assert_contains "$OUT" "run woostack-init first" "missing workspace points to init"

run_doctor --live "$repo"
assert_exit 2 "$CODE" "raw --live cannot make a shell provider call"
assert_contains "$OUT" "controller-owned" "raw live mode explains the receipt boundary"
assert_contains "$OUT" "gh for GitHub, official MCP for Linear/Plane" "raw live mode names all supported provider transports"

finish
