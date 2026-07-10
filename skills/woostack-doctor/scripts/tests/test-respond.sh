#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
CHECK="$HERE/../checks/respond.sh"
CONFIG_KEYS="$HERE/../checks/config-keys.sh"
DOCTOR="$HERE/../doctor.sh"

mkroot() { local r; r="$(mktemp -d)"; mkdir -p "$r/.woostack/respond/evidence"; printf '%s\n' '{"models":{},"review":{},"respond":{},"status":{"staleDays":14}}' > "$r/.woostack/config.json"; printf '%s\n' 'respond/evidence/' > "$r/.woostack/.gitignore"; echo "$r"; }

r="$(mkroot)"
assert_eq "$(bash "$CHECK" "$r")" "" "default response config is healthy"
printf '%s\n' '{"respond":{"provider":"sentry","environment":"production","window":"24h","max_groups":5,"remediation":"prepare-fix"}}' > "$r/.woostack/config.json"
assert_eq "$(bash "$CHECK" "$r")" "" "valid optional response values are healthy"

for invalid in \
  '{"respond":[]}' \
  '{"respond":{"provider":1}}' \
  '{"respond":{"environment":false}}' \
  '{"respond":{"window":"31d"}}' \
  '{"respond":{"max_groups":0}}' \
  '{"respond":{"max_groups":6}}' \
  '{"respond":{"remediation":"deploy"}}'; do
  printf '%s\n' "$invalid" > "$r/.woostack/config.json"
  assert_contains "$(bash "$CHECK" "$r")" 'respond-config' "invalid response namespace or value is reported"
done


printf '%s\n' '{"respond":{"window":"4m"}}' > "$r/.woostack/config.json"
invalid_out="$(bash "$CHECK" "$r")"
assert_contains "$invalid_out" 'respond-config' "invalid response setting is reported"
IFS=$'\t' read -r severity code fixability finding_path message <<< "$invalid_out"
assert_eq "$severity" "warn" "response finding uses doctor severity"
assert_eq "$code" "respond-config" "response finding uses stable code"
assert_eq "$fixability" "report" "response finding is report-only"
assert_eq "$finding_path" ".woostack/config.json" "response finding uses workspace-relative path"
assert_contains "$message" 'window' "response finding includes validator message"
printf '%s\n' '{"respond":{"api_key":"synthetic"}}' > "$r/.woostack/config.json"
assert_contains "$(bash "$CHECK" "$r")" 'respond-credentials' "credential-like key is reported"
printf '%s\n' '{"respond":{"unknown":true}}' > "$r/.woostack/config.json"
assert_contains "$(bash "$CHECK" "$r")" 'respond-config' "unknown response key is reported"

printf '%s\n' '{"models":{},"review":{},"status":{"staleDays":14}}' > "$r/.woostack/config.json"
if command -v jq >/dev/null 2>&1; then
  assert_contains "$(bash "$CONFIG_KEYS" "$r")" 'missing required config key: respond' "missing respond key is template drift"
  before="$(jq -c 'del(.respond)' "$r/.woostack/config.json")"
  bash "$CONFIG_KEYS" --fix "$r" respond
  assert_eq "$(jq -c '.respond' "$r/.woostack/config.json")" '{}' "repair restores empty respond namespace"
  assert_eq "$(jq -c 'del(.respond)' "$r/.woostack/config.json")" "$before" "repair preserves sibling namespaces"
fi

mkdir -p "$r/.woostack/respond/evidence/old-run" "$r/.woostack/respond/evidence/fresh-run"
printf '%s\n' 'PAYLOAD_MUST_NOT_BE_READ' > "$r/.woostack/respond/evidence/old-run/provider.json"
chmod 000 "$r/.woostack/respond/evidence/old-run/provider.json"
touch -t 202001010000 "$r/.woostack/respond/evidence/old-run"
now="$(date +%s)"
out="$(WOOSTACK_NOW_EPOCH="$now" bash "$CHECK" "$r")"
assert_contains "$out" 'respond-stale-evidence' "old run directory is reported"
assert_contains "$out" 'delete this directory manually' "stale report gives manual cleanup"
assert_not_contains "$out" 'PAYLOAD_MUST_NOT_BE_READ' "doctor never prints evidence payload"
assert_not_contains "$out" 'fresh-run' "fresh evidence is ignored"
outside="$(mktemp -d)"
mkdir -p "$outside/old-run"
touch -t 202001010000 "$outside/old-run"
assert_not_contains "$out" "$outside" "OS-temp evidence outside workspace is ignored"
rm -rf "$outside"

orchestrated="$(bash "$DOCTOR" "$r" --check 2>&1)"
assert_contains "$orchestrated" 'respond-stale-evidence' "doctor wildcard invokes response check"
source_body="$(cat "$CHECK")"
assert_not_contains "$source_body" 'curl ' "check has no network client"
assert_not_contains "$source_body" 'sentry ' "check has no provider CLI"
chmod 600 "$r/.woostack/respond/evidence/old-run/provider.json"
rm -rf "$r"
finish
