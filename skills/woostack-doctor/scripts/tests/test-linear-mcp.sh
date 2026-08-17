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
    models:{},review:{},status:{staleDays:14},
    linear:{
      saveArtifacts:true,
      repository:"https://github.com/acme/widgets",workspace:"acme",team:"ENG",
      projectStatuses:{
        backlog:"Backlog",planned:"Planned",started:"Started",
        completed:"Completed",canceled:"Canceled"
      },
      issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Progress",done:"Done",blocked:"In Progress"}
    }
  }'
}

complete_receipt() {
  jq -cn '{
    schemaVersion:1,provider:"official-linear-mcp",mcpAvailable:true,authenticated:true,ready:true,
    repository:"https://github.com/acme/widgets",workspace:"acme",team:"ENG",
    workspaceResolution:{status:"unique",name:"acme"},
    teamResolution:{status:"unique",id:"22222222-2222-4222-8222-222222222222",name:"Engineering",key:"ENG"},
    projectStatuses:{complete:true,resolved:{
      backlog:{name:"Backlog",category:"backlog"},
      planned:{name:"Planned",category:"planned"},
      started:{name:"Started",category:"started"},
      completed:{name:"Completed",category:"completed"},
      canceled:{name:"Canceled",category:"canceled"}
    }},
    issueStates:{complete:true,resolved:{
      planned:{name:"Backlog",category:"backlog"},
      executing:{name:"In Progress",category:"started"},
      inReview:{name:"In Progress",category:"started"},
      done:{name:"Done",category:"completed"},
      blocked:{name:"In Progress",category:"started"}
    }},
    capabilities:{
      projectRead:true,projectWrite:true,projectUpdateRead:true,projectUpdateWrite:true,
      issueRead:true,issueWrite:true,commentRead:true,commentWrite:true,
      relationRead:true,relationWrite:true,ownerRead:true,ownerWrite:true,independentReadBack:true
    },
    readBack:{status:"verified",complete:true,independent:true}
  }'
}

make_repo() {
  local name="$1" repo="$TMP/$1"
  mkdir -p "$repo/.woostack"
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
printf '%s\n' '{"linear":{"team":"ENG","apiKey":"forbidden"}}' >"$invalid_local/.woostack/config.local.json"
run_doctor "$invalid_local"
assert_exit 1 "$RC" "credential-like local policy keys fail static diagnosis"
assert_contains "$OUTPUT" ".woostack/config.local.json contains credential-like key: linear.apiKey" "invalid local override is actionable"

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
bad_selector_local="$(make_repo selector-local)"
printf '%s\n' '{"artifacts":{"specPlan":"markdown"}}' >"$bad_selector_local/.woostack/config.local.json"
run_doctor "$bad_selector_local"
assert_exit 1 "$RC" "local backend selector fails static diagnosis"
assert_contains "$OUTPUT" "development backend selectors are not supported" "local selector finding is actionable"

bad_secret="$(make_repo secret)"
jq '.linear.apiKey="secret"' "$bad_secret/.woostack/config.json" >"$bad_secret/config.tmp"
mv "$bad_secret/config.tmp" "$bad_secret/.woostack/config.json"
run_doctor "$bad_secret"
assert_exit 1 "$RC" "credential-like Linear key fails static diagnosis"
assert_contains "$OUTPUT" ".woostack/config.json contains credential-like key: linear.apiKey" "credential finding names the violated boundary"

bad_mapping="$(make_repo mapping)"
jq 'del(.linear.issueStates.blocked)' "$bad_mapping/.woostack/config.json" >"$bad_mapping/config.tmp"
mv "$bad_mapping/config.tmp" "$bad_mapping/.woostack/config.json"
run_doctor "$bad_mapping"
assert_exit 1 "$RC" "incomplete state mapping fails static diagnosis"
assert_contains "$OUTPUT" "issueStates mapping is incomplete" "mapping finding is actionable"

legacy_paused_mapping="$(make_repo legacy-paused-mapping)"
jq '.linear.projectStatuses.paused="Paused"' "$legacy_paused_mapping/.woostack/config.json" >"$legacy_paused_mapping/config.tmp"
mv "$legacy_paused_mapping/config.tmp" "$legacy_paused_mapping/.woostack/config.json"
run_doctor "$legacy_paused_mapping"
assert_exit 1 "$RC" "obsolete paused project mapping fails static diagnosis"
assert_contains "$OUTPUT" "projectStatuses mapping is incomplete" "obsolete paused mapping is actionable"

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

workspace_id="$TMP/workspace-id.json"
jq '.workspaceResolution.id="11111111-1111-4111-8111-111111111111"' "$receipt" >"$workspace_id"
chmod 600 "$workspace_id"
run_doctor "$repo" --live-receipt "$workspace_id"
assert_exit 1 "$RC" "workspace resolution rejects a fabricated native ID"

workspace_mismatch="$TMP/workspace-mismatch.json"
jq '.workspaceResolution.name="other"' "$receipt" >"$workspace_mismatch"
chmod 600 "$workspace_mismatch"
run_doctor "$repo" --live-receipt "$workspace_mismatch"
assert_exit 1 "$RC" "workspace resolution must match configured OAuth-scoped workspace"

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


finish
