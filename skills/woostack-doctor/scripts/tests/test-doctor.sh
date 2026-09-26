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
{"review":{}}
JSON

run_doctor() {
  set +e
  OUT="$(bash "$DOCTOR" "$@" 2>&1)"
  CODE=$?
  set -e
}

run_doctor "$repo"
assert_exit 0 "$CODE" "valid local workspace exits zero"
assert_not_contains "$OUT" "github-live" "static diagnosis does not emit live-receipt findings"

for model in '"old/provider"' '{"standard":{"model":"old/provider"},"other":{"effort":"low"}}' '{"standard":["old/provider",42],"fast":[]}' 'false'; do
  printf '{"github":{"owner":"acme"},"models":%s,"custom":{"enabled":true}}\n' "$model" >"$repo/.woostack/config.json"
  before="$(shasum -a 256 "$repo/.woostack/config.json")"
  run_doctor --check "$repo"
  assert_exit 0 "$CODE" "old model values are opaque to Doctor"
  assert_not_contains "$OUT" "models-leaf-shape" "no retired model grammar diagnostic"
  assert_eq "$(shasum -a 256 "$repo/.woostack/config.json")" "$before" "Doctor preserves user config bytes"
done

printf '{"models":{"fast":[]}}\n' >"$repo/.woostack/config.json"
printf '{"models":{"deep":{"effort":"old"}},"custom":{"enabled":true}}\n' >"$repo/.woostack/config.local.json"
run_doctor --check "$repo"
assert_exit 0 "$CODE" "local model overlay has no model-specific error"
assert_not_contains "$OUT" "models-leaf-shape" "local old values are not model-validated"
printf '{"models":{"apiKey":"not-a-real-secret"}}\n' >"$repo/.woostack/config.local.json"
run_doctor --check "$repo"
assert_exit 1 "$CODE" "generic credential-like key check remains active inside models"
assert_contains "$OUT" "credential-like key: models.apiKey" "security diagnostic remains specific"
rm "$repo/.woostack/config.local.json"

printf '%s\n' '{"models":{},"status":{"staleDays":14}}' >"$repo/.woostack/config.json"
run_doctor "$repo"
assert_exit 0 "$CODE" "legacy status configuration remains non-blocking"
assert_contains "$OUT" "retired-status-config" "legacy status configuration receives retirement guidance"
assert_eq "$(jq -r '.status.staleDays' "$repo/.woostack/config.json")" "14" "legacy status configuration is preserved"

mkdir -p "$TMP/missing"
run_doctor "$TMP/missing"
assert_exit 2 "$CODE" "missing workspace exits two"
assert_contains "$OUT" "run woostack-init first" "missing workspace points to init"

run_doctor --live "$repo"
assert_exit 2 "$CODE" "raw live mode cannot make a provider call"
assert_contains "$OUT" "controller-owned" "raw live mode explains the receipt boundary"

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
annotation=""
while IFS= read -r line; do
  case "$line" in
    "::error:: [config-policy] "*) annotation="$line" ;;
  esac
done <<<"$OUT"
assert_contains "$annotation" "$blocking_reason" "config-policy retains the resolver's blocking diagnostic"

finish
