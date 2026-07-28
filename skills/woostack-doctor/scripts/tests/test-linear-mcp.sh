#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

complete_config() {
  jq -cn '{
    models:{},review:{},respond:{},status:{staleDays:14},
    linear:{
      repository:"https://github.com/acme/widgets",workspace:"acme",team:"ENG",
      projectStatuses:{
        backlog:"Backlog",planned:"Planned",started:"Started",
        paused:"Paused",completed:"Completed",canceled:"Canceled"
      },
      issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Review",done:"Done",blocked:"Blocked"}
    }
  }'
}

complete_receipt() {
  jq -cn '{
    schemaVersion:1,provider:"official-linear-mcp",mcpAvailable:true,authenticated:true,ready:true,
    repository:"https://github.com/acme/widgets",workspace:"acme",team:"ENG",
    workspaceResolution:{status:"unique",id:"11111111-1111-4111-8111-111111111111",name:"acme"},
    teamResolution:{status:"unique",id:"22222222-2222-4222-8222-222222222222",name:"Engineering",key:"ENG"},
    projectStatuses:{complete:true,resolved:{
      backlog:{name:"Backlog",category:"backlog"},
      planned:{name:"Planned",category:"planned"},
      started:{name:"Started",category:"started"},
      paused:{name:"Paused",category:"paused"},
      completed:{name:"Completed",category:"completed"},
      canceled:{name:"Canceled",category:"canceled"}
    }},
    issueStates:{complete:true,resolved:{
      planned:{name:"Backlog",category:"backlog"},
      executing:{name:"In Progress",category:"started"},
      inReview:{name:"In Review",category:"started"},
      done:{name:"Done",category:"completed"},
      blocked:{name:"Blocked",category:"started"}
    }},
    capabilities:{
      projectRead:true,projectWrite:true,projectUpdateRead:true,projectUpdateWrite:true,
      issueRead:true,issueWrite:true,commentRead:true,commentWrite:true,
      relationRead:true,relationWrite:true,ownerRead:true,ownerWrite:true,independentReadBack:true
    },
    readBack:{status:"verified",complete:true,independent:true},
    provenance:{}
  }'
}

make_repo() {
  local name="$1" repo="$TMP/$1"
  mkdir -p "$repo/.woostack/memory"
  git -C "$repo" init -q
  complete_config >"$repo/.woostack/config.json"
  printf '%s\n' "$repo"
}

run_doctor() {
  local repo="$1"; shift
  set +e
  OUTPUT="$(bash "$DOCTOR" "$@" "$repo" 2>&1)"
  RC=$?
  set -e
}

repo="$(make_repo static-success)"
run_doctor "$repo"
assert_exit 0 "$RC" "valid non-secret Linear policy passes static diagnosis"
assert_not_contains "$OUTPUT" "linear-live" "static diagnosis performs no live-provider check"

local_team="$(make_repo local-team)"
jq '.linear.team="DEFAULT"' "$local_team/.woostack/config.json" >"$local_team/config.tmp"
mv "$local_team/config.tmp" "$local_team/.woostack/config.json"
printf '%s\n' '{"linear":{"team":"ENG"}}' >"$local_team/.woostack/config.local.json"
run_doctor "$local_team"
assert_exit 0 "$RC" "valid primary-checkout local team override passes static diagnosis"

invalid_local="$(make_repo invalid-local)"
printf '%s\n' '{"linear":{"team":"ENG","workspace":"forbidden"}}' >"$invalid_local/.woostack/config.local.json"
run_doctor "$invalid_local"
assert_exit 1 "$RC" "unsupported local policy keys fail static diagnosis"
assert_contains "$OUTPUT" "may override only" "invalid local override is actionable"

blank_policy="$(make_repo blank-policy)"
jq '.linear.workspace="   "' "$blank_policy/.woostack/config.json" >"$blank_policy/config.tmp"
mv "$blank_policy/config.tmp" "$blank_policy/.woostack/config.json"
run_doctor "$blank_policy"
assert_exit 1 "$RC" "blank policy values fail static diagnosis"

noncanonical_repository="$(make_repo repository-query)"
jq '.linear.repository="https://github.com/acme/widgets?ref=main"' "$noncanonical_repository/.woostack/config.json" >"$noncanonical_repository/config.tmp"
mv "$noncanonical_repository/config.tmp" "$noncanonical_repository/.woostack/config.json"
run_doctor "$noncanonical_repository"
assert_exit 1 "$RC" "repository URLs with query text fail static diagnosis"

bad_selector="$(make_repo selector)"
jq '.artifacts={specPlan:"markdown"}' "$bad_selector/.woostack/config.json" >"$bad_selector/config.tmp"
mv "$bad_selector/config.tmp" "$bad_selector/.woostack/config.json"
run_doctor "$bad_selector"
assert_exit 1 "$RC" "backend selector fails static diagnosis"
assert_contains "$OUTPUT" "development backend selectors are not supported" "selector finding is actionable"

bad_secret="$(make_repo secret)"
jq '.linear.apiKey="secret"' "$bad_secret/.woostack/config.json" >"$bad_secret/config.tmp"
mv "$bad_secret/config.tmp" "$bad_secret/.woostack/config.json"
run_doctor "$bad_secret"
assert_exit 1 "$RC" "credential-like Linear key fails static diagnosis"
assert_contains "$OUTPUT" "credential-like configuration key" "credential finding names the violated boundary"

bad_mapping="$(make_repo mapping)"
jq 'del(.linear.issueStates.blocked)' "$bad_mapping/.woostack/config.json" >"$bad_mapping/config.tmp"
mv "$bad_mapping/config.tmp" "$bad_mapping/.woostack/config.json"
run_doctor "$bad_mapping"
assert_exit 1 "$RC" "incomplete state mapping fails static diagnosis"
assert_contains "$OUTPUT" "issueStates mapping is incomplete" "mapping finding is actionable"

legacy="$(make_repo legacy)"
mkdir -p "$legacy/.woostack/specs" "$legacy/.woostack/plans"
printf x >"$legacy/.woostack/specs/one.md"
printf x >"$legacy/.woostack/plans/one.md"
run_doctor "$legacy"
assert_exit 1 "$RC" "legacy development records block normal diagnosis"
assert_eq "$(printf '%s\n' "$OUTPUT" | grep -c '^error.*legacy-development-records')" "2" "one blocker is emitted per legacy record set"
assert_not_contains "$OUTPUT" "[doc-type]" "legacy records do not enter normal document lint"
assert_not_contains "$OUTPUT" "[status-enum]" "legacy records do not enter normal lifecycle lint"

sentinel_only="$(make_repo sentinel-only)"
mkdir -p "$sentinel_only/.woostack/fixes"
touch "$sentinel_only/.woostack/fixes/.gitkeep"
run_doctor "$sentinel_only"
assert_exit 0 "$RC" "legacy record detection ignores a sentinel-only directory"
assert_not_contains "$OUTPUT" "legacy-development-records" "sentinel files are not development records"

receipt="$TMP/receipt.json"
complete_receipt >"$receipt"
chmod 600 "$receipt"
run_doctor "$repo" --live-receipt "$receipt"
assert_exit 0 "$RC" "complete normalized live receipt passes"

while IFS='|' read -r field expected; do
  mutant="$TMP/missing-${field//./-}.json"
  jq --arg field "$field" 'delpaths([($field | split("."))])' "$receipt" >"$mutant"
  chmod 600 "$mutant"
  run_doctor "$repo" --live-receipt "$mutant"
  assert_exit 1 "$RC" "missing receipt field $field fails closed"
  assert_contains "$OUTPUT" "$expected" "missing receipt field $field reports the expected failure"
done <<'RECEIPT_FIELD_CASES'
schemaVersion|malformed, partial, or not ready
provider|malformed, partial, or not ready
mcpAvailable|malformed, partial, or not ready
authenticated|malformed, partial, or not ready
ready|malformed, partial, or not ready
repository|receipt repository does not match configured Linear policy
workspace|malformed, partial, or not ready
team|malformed, partial, or not ready
workspaceResolution|malformed, partial, or not ready
teamResolution|malformed, partial, or not ready
projectStatuses|malformed, partial, or not ready
issueStates|malformed, partial, or not ready
capabilities|missing Linear MCP capability:
readBack|malformed, partial, or not ready
readBack.status|malformed, partial, or not ready
readBack.complete|malformed, partial, or not ready
readBack.independent|malformed, partial, or not ready
RECEIPT_FIELD_CASES

while IFS= read -r capability; do
  for mutation in missing false; do
    mutant="$TMP/capability-$capability-$mutation.json"
    case "$mutation" in
      missing) jq --arg capability "$capability" 'del(.capabilities[$capability])' "$receipt" >"$mutant" ;;
      false) jq --arg capability "$capability" '.capabilities[$capability] = false' "$receipt" >"$mutant" ;;
    esac
    chmod 600 "$mutant"
    run_doctor "$repo" --live-receipt "$mutant"
    assert_exit 1 "$RC" "$mutation capability $capability fails closed"
    assert_contains "$OUTPUT" "missing Linear MCP capability: $capability" "$mutation capability $capability is exact"
  done
done <<'CAPABILITY_CASES'
projectRead
projectWrite
projectUpdateRead
projectUpdateWrite
issueRead
issueWrite
commentRead
commentWrite
relationRead
relationWrite
ownerRead
ownerWrite
independentReadBack
CAPABILITY_CASES
assert_not_contains "$OUTPUT" "LINEAR_API_KEY" "diagnosis never requests an API key"

run_doctor "$repo" --live-receipt "$TMP/missing.json"
assert_exit 1 "$RC" "missing live receipt fails closed"
assert_contains "$OUTPUT" "receipt is missing or unreadable" "missing receipt is actionable"

provenance_repo="$(make_repo provenance)"
provenance_id="55555555-5555-4555-8555-555555555555"
provenance_uri="linear://issue/$provenance_id"
cat >"$provenance_repo/.woostack/memory/linear.md" <<MD
---
name: linear-provenance
type: decision
scope: "*"
source: $provenance_uri
updated: 2026-07-26
---
receipt-only provenance
MD

legacy_marker="$TMP/legacy-adapter-invoked"
legacy_adapter="$TMP/legacy-linear.sh"
cat >"$legacy_adapter" <<SH
#!/usr/bin/env bash
: >"$legacy_marker"
exit 0
SH
chmod +x "$legacy_adapter"
export WOOSTACK_LINEAR_ADAPTER="$legacy_adapter"

run_doctor "$provenance_repo"
assert_exit 0 "$RC" "static doctor parses valid Linear provenance locally"
assert_not_contains "$OUTPUT" "memory-provenance" "valid local provenance syntax is accepted"
[ ! -e "$legacy_marker" ] || fail "static doctor invoked the forbidden legacy Linear adapter"

provenance_receipt="$TMP/provenance-receipt.json"
jq --arg uri "$provenance_uri" --arg id "$provenance_id" '
  .provenance[$uri]={
    verified:true,
    managedIdentityVerified:true,
    relationsVerified:true,
    kind:"issue",
    id:$id,
    repository:.repository,
    workspace:.workspace,
    team:.team
  }
' "$receipt" >"$provenance_receipt"
chmod 600 "$provenance_receipt"
run_doctor "$provenance_repo" --live-receipt "$provenance_receipt"
assert_exit 0 "$RC" "live doctor consumes verified provenance from the normalized receipt"
assert_not_contains "$OUTPUT" "memory-provenance-live" "verified receipt provenance passes"
[ ! -e "$legacy_marker" ] || fail "live doctor invoked the forbidden legacy Linear adapter"

jq --arg uri "$provenance_uri" '.provenance[$uri].relationsVerified=false' \
  "$provenance_receipt" >"$TMP/drifted-provenance.json"
chmod 600 "$TMP/drifted-provenance.json"
run_doctor "$provenance_repo" --live-receipt "$TMP/drifted-provenance.json"
assert_exit 1 "$RC" "partial or drifted receipt provenance fails closed"
assert_contains "$OUTPUT" "missing, partial, foreign, or drifted host-MCP provenance receipt" "receipt-only provenance failure is actionable"
[ ! -e "$legacy_marker" ] || fail "drifted live receipt invoked the forbidden legacy Linear adapter"

sed -i.bak "s|$provenance_uri|linear://document/$provenance_id|" \
  "$provenance_repo/.woostack/memory/linear.md"
rm -f "$provenance_repo/.woostack/memory/linear.md.bak"
run_doctor "$provenance_repo"
assert_exit 0 "$RC" "retired document provenance remains a static warning"
assert_contains "$OUTPUT" "is malformed (expected linear://project|issue/<uuid>)" "document provenance is rejected after cutover"

sed -i.bak "s|linear://document/$provenance_id|linear://issue/nested/$provenance_id|" \
  "$provenance_repo/.woostack/memory/linear.md"
rm -f "$provenance_repo/.woostack/memory/linear.md.bak"
run_doctor "$provenance_repo"
assert_exit 0 "$RC" "malformed provenance remains a static warning"
assert_contains "$OUTPUT" "is malformed (expected linear://project|issue/<uuid>)" "local parser rejects nested provenance paths"
[ ! -e "$legacy_marker" ] || fail "malformed static provenance invoked the forbidden legacy Linear adapter"
sed -i.bak "s|linear://issue/nested/$provenance_id|linear://document/$provenance_id|" \
  "$provenance_repo/.woostack/memory/linear.md"
rm -f "$provenance_repo/.woostack/memory/linear.md.bak"
run_doctor "$provenance_repo"
assert_exit 0 "$RC" "Linear document provenance remains a static warning"
assert_contains "$OUTPUT" "is malformed (expected linear://project|issue/<uuid>)" "local parser rejects retired Linear document provenance"
[ ! -e "$legacy_marker" ] || fail "document provenance invoked the forbidden legacy Linear adapter"
unset WOOSTACK_LINEAR_ADAPTER

checks_catalog="$(<"$HERE/../../references/checks.md")"
assert_contains "$checks_catalog" '`linear://project/<uuid>` or `linear://issue/<uuid>`' "catalog exposes only current Linear provenance forms"
assert_not_contains "$checks_catalog" 'linear://document/' "catalog does not restore retired Linear document provenance"

finish
