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
{"models":{},"review":{},"status":{"staleDays":14}}
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

mkdir -p "$TMP/missing"
run_doctor "$TMP/missing"
assert_exit 2 "$CODE" "missing workspace exits two"
assert_contains "$OUT" "run woostack-init first" "missing workspace points to init"

run_doctor --live "$repo"
assert_exit 2 "$CODE" "raw live mode cannot make a provider call"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"linear"},"github":null}
JSON
if resolver_error="$(bash "$HERE/../../../woostack-init/scripts/config/resolve-config.sh" "$repo" 2>&1)"; then
  printf 'FAIL: invalid active configuration was accepted\n' >&2
  exit 1
fi
blocking_reason="${resolver_error##*$'\n'}"
run_doctor --check "$repo"
assert_exit 1 "$CODE" "invalid active policy fails the check despite a retirement notice"
for check in config-policy models-leaf-shape; do
  annotation=""
  while IFS= read -r line; do
    case "$line" in
      "::error:: [$check] "*) annotation="$line" ;;
    esac
  done <<<"$OUT"
  assert_contains "$annotation" "$blocking_reason" "$check retains the resolver's blocking diagnostic"
done

finish
