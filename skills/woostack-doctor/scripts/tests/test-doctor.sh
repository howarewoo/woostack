#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
mkdir -p "$repo/.woostack/memory"
git -C "$repo" init -q
cat >"$repo/.woostack/config.json" <<'JSON'
{"linear":{"repository":"https://github.com/acme/widgets","workspace":"acme","team":"ENG","projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}},"models":{},"review":{},"respond":{},"status":{"staleDays":14}}
JSON
cat >"$repo/.woostack/memory/good.md" <<'MD'
---
name: good
type: pattern
scope: "*"
source: pr-1
updated: 2026-07-26
---
body
MD

run_doctor() {
  set +e
  OUT="$(bash "$DOCTOR" "$@" 2>&1)"
  CODE=$?
  set -e
}

run_doctor "$repo"
assert_exit 0 "$CODE" "valid static workspace exits zero"
assert_not_contains "$OUT" "linear-live" "static workspace does not claim provider validation"

printf '%s\n' 'no frontmatter here' >"$repo/.woostack/memory/bad.md"
run_doctor --check "$repo"
assert_exit 1 "$CODE" "malformed memory fails check mode"
assert_contains "$OUT" "memory-malformed" "malformed memory finding is preserved"

mkdir -p "$TMP/missing"
run_doctor "$TMP/missing"
assert_exit 2 "$CODE" "missing workspace exits two"
assert_contains "$OUT" "run woostack-init first" "missing workspace points to init"

run_doctor --live "$repo"
assert_exit 2 "$CODE" "raw --live cannot make a shell provider call"
assert_contains "$OUT" "controller-owned" "raw live mode explains the receipt boundary"

finish
