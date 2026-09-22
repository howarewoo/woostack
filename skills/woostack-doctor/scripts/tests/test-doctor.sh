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
{"models":{},"review":{}}
JSON

run_doctor() {
  set +e
  OUT="$(bash "$DOCTOR" "$@" 2>&1)"
  CODE=$?
  set -e
}

run_doctor "$repo"
assert_exit 0 "$CODE" "valid local workspace exits zero"
assert_not_contains "$OUT" "live" "static workspace does not claim live validation"
printf '%s\n' '{"models":{},"status":{"staleDays":14}}' >"$repo/.woostack/legacy-config.json"
mv "$repo/.woostack/legacy-config.json" "$repo/.woostack/config.json"
run_doctor "$repo"
assert_exit 0 "$CODE" "legacy status config remains non-blocking"
assert_contains "$OUT" "retired-status-config" "legacy status config receives retirement guidance"
assert_eq "$(jq -r '.status.staleDays' "$repo/.woostack/config.json")" "14" "legacy status config is preserved"


mkdir -p "$TMP/missing"
run_doctor "$TMP/missing"
assert_exit 2 "$CODE" "missing workspace exits two"
assert_contains "$OUT" "run woostack-init first" "missing workspace points to init"

run_doctor --live "$repo"
assert_exit 2 "$CODE" "raw live mode cannot make a provider call"

finish
