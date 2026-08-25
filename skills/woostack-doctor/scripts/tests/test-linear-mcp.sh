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
    artifacts:{
      provider:"linear",
      linear:{
        repository:"https://github.com/acme/widgets",workspace:"acme",team:"ENG",
        projectLabels:[],
        projectStatuses:{
          backlog:"Backlog",planned:"Planned",started:"Started",
          completed:"Completed",canceled:"Canceled"
        },
        issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Progress",done:"Done",blocked:"In Progress"}
      }
    }
  }'
}
complete_plane_config() {
  jq -cn '{
    models:{},review:{},status:{staleDays:14},
    artifacts:{
      provider:"plane",
      plane:{
        baseUrl:"https://api.plane.so",
        repository:"https://github.com/acme/widgets",workspace:"acme",
        projectLabels:["Core"],
        projectStatuses:{
          backlog:"Backlog",planned:"Planned",started:"Started",
          completed:"Completed",canceled:"Canceled"
        },
        issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Progress",done:"Done",blocked:"In Progress"}
      }
    }
  }'
}

complete_plane_receipt() {
  jq -cn '{
    schemaVersion:1,provider:"official-plane-mcp",mcpAvailable:true,authenticated:true,ready:true,
    baseUrl:"https://api.plane.so",
    repository:"https://github.com/acme/widgets",workspace:"acme",
    workspaceResolution:{status:"unique",name:"acme"},
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
      projectRead:true,projectWrite:true,
      issueRead:true,issueWrite:true,
      relationRead:true,relationWrite:true,
      projectLabelRead:true,projectLabelWrite:true,
      independentReadBack:true
    },
    readBack:{status:"verified",complete:true,independent:true}
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
jq '.artifacts.linear.team="DEFAULT"' "$local_team/.woostack/config.json" >"$local_team/config.tmp"
mv "$local_team/config.tmp" "$local_team/.woostack/config.json"
printf '%s\n' '{"artifacts":{"linear":{"team":"ENG"}}}' >"$local_team/.woostack/config.local.json"
run_doctor "$local_team"
assert_exit 0 "$RC" "valid primary-checkout local team override passes static diagnosis"

invalid_local="$(make_repo invalid-local)"
printf '%s\n' '{"artifacts":{"linear":{"team":"ENG","apiKey":"forbidden"}}}' >"$invalid_local/.woostack/config.local.json"
run_doctor "$invalid_local"
assert_exit 1 "$RC" "credential-like local policy keys fail static diagnosis"
assert_contains "$OUTPUT" ".woostack/config.local.json contains credential-like key: artifacts.linear.apiKey" "invalid local override is actionable"

blank_policy="$(make_repo blank-policy)"
jq '.artifacts.linear.workspace="   "' "$blank_policy/.woostack/config.json" >"$blank_policy/config.tmp"
mv "$blank_policy/config.tmp" "$blank_policy/.woostack/config.json"
run_doctor "$blank_policy"
assert_exit 1 "$RC" "blank policy values fail static diagnosis"

noncanonical_repository="$(make_repo repository-query)"
jq '.artifacts.linear.repository="https://github.com/acme/widgets?ref=main"' "$noncanonical_repository/.woostack/config.json" >"$noncanonical_repository/config.tmp"
mv "$noncanonical_repository/config.tmp" "$noncanonical_repository/.woostack/config.json"
run_doctor "$noncanonical_repository"
assert_exit 1 "$RC" "repository URLs with query text fail static diagnosis"

bad_provider="$(make_repo bad-provider)"
jq '.artifacts={provider:"invalid"}' "$bad_provider/.woostack/config.json" >"$bad_provider/config.tmp"
mv "$bad_provider/config.tmp" "$bad_provider/.woostack/config.json"
run_doctor "$bad_provider"
assert_exit 1 "$RC" "invalid artifacts provider fails static diagnosis"
assert_contains "$OUTPUT" "artifacts.provider must be \"local\", \"linear\", or \"plane\"" "provider finding is actionable"

plane_repo="$(make_repo plane-static)"
complete_plane_config >"$plane_repo/.woostack/config.json"
run_doctor "$plane_repo"
assert_exit 0 "$RC" "valid non-secret Plane policy passes static diagnosis"

local_with_partial_linear="$(make_repo local-partial-linear)"
jq '.artifacts={provider:"local",linear:{workspace:"only-workspace"}}' "$local_with_partial_linear/.woostack/config.json" >"$local_with_partial_linear/config.tmp"
mv "$local_with_partial_linear/config.tmp" "$local_with_partial_linear/.woostack/config.json"
run_doctor "$local_with_partial_linear"
assert_exit 0 "$RC" "local provider with partial linear block passes static diagnosis (selected-provider isolation)"

valid_labels="$(make_repo valid-labels)"
jq '.artifacts.linear.projectLabels=["Core","Infrastructure"]' "$valid_labels/.woostack/config.json" >"$valid_labels/config.tmp"
mv "$valid_labels/config.tmp" "$valid_labels/.woostack/config.json"
run_doctor "$valid_labels"
assert_exit 0 "$RC" "valid projectLabels passes static diagnosis"

invalid_labels="$(make_repo invalid-labels)"
jq '.artifacts.linear.projectLabels=[""]' "$invalid_labels/.woostack/config.json" >"$invalid_labels/config.tmp"
mv "$invalid_labels/config.tmp" "$invalid_labels/.woostack/config.json"
run_doctor "$invalid_labels"
assert_exit 1 "$RC" "empty string in projectLabels fails static diagnosis"
assert_contains "$OUTPUT" "projectLabels must be an array of non-empty strings" "invalid projectLabels finding is actionable"

legacy_save_artifacts="$(make_repo legacy-save-artifacts)"
jq '.linear={saveArtifacts:true}' "$legacy_save_artifacts/.woostack/config.json" >"$legacy_save_artifacts/config.tmp"
mv "$legacy_save_artifacts/config.tmp" "$legacy_save_artifacts/.woostack/config.json"
run_doctor "$legacy_save_artifacts"
assert_exit 1 "$RC" "legacy saveArtifacts fails static diagnosis"
assert_contains "$OUTPUT" "linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "legacy rejection finding is actionable"

bad_secret="$(make_repo secret)"
jq '.artifacts.linear.apiKey="secret"' "$bad_secret/.woostack/config.json" >"$bad_secret/config.tmp"
mv "$bad_secret/config.tmp" "$bad_secret/.woostack/config.json"
run_doctor "$bad_secret"
assert_exit 1 "$RC" "credential-like Linear key fails static diagnosis"
assert_contains "$OUTPUT" ".woostack/config.json contains credential-like key: artifacts.linear.apiKey" "credential finding names the violated boundary"

bad_mapping="$(make_repo mapping)"
jq 'del(.artifacts.linear.issueStates.blocked)' "$bad_mapping/.woostack/config.json" >"$bad_mapping/config.tmp"
mv "$bad_mapping/config.tmp" "$bad_mapping/.woostack/config.json"
run_doctor "$bad_mapping"
assert_exit 1 "$RC" "incomplete state mapping fails static diagnosis"
assert_contains "$OUTPUT" "issueStates mapping is incomplete" "mapping finding is actionable"

legacy_paused_mapping="$(make_repo legacy-paused-mapping)"
jq '.artifacts.linear.projectStatuses.paused="Paused"' "$legacy_paused_mapping/.woostack/config.json" >"$legacy_paused_mapping/config.tmp"
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

plane_receipt="$TMP/plane-receipt.json"
complete_plane_receipt >"$plane_receipt"
chmod 600 "$plane_receipt"
run_doctor "$plane_repo" --live-receipt "$plane_receipt"
assert_exit 0 "$RC" "complete normalized Plane live receipt passes"

missing_label_cap="$TMP/plane-no-label-cap.json"
jq '.capabilities.projectLabelRead=false' "$plane_receipt" >"$missing_label_cap"
chmod 600 "$missing_label_cap"
run_doctor "$plane_repo" --live-receipt "$missing_label_cap"
assert_exit 1 "$RC" "missing Plane projectLabelRead capability fails live diagnosis"
assert_contains "$OUTPUT" "missing Plane MCP capability: projectLabelRead" "missing projectLabelRead is actionable"

plane_url_mismatch="$TMP/plane-url-mismatch.json"
jq '.baseUrl="https://other.plane.so"' "$plane_receipt" >"$plane_url_mismatch"
chmod 600 "$plane_url_mismatch"
run_doctor "$plane_repo" --live-receipt "$plane_url_mismatch"
assert_exit 1 "$RC" "plane baseUrl mismatch fails live diagnosis"
assert_contains "$OUTPUT" "receipt baseUrl does not match configured Plane policy" "baseUrl mismatch is actionable"

# Plane Cloud app.plane.so config with api.plane.so receipt passes
plane_cloud_app_repo="$(make_repo plane-cloud-app)"
complete_plane_config >"$plane_cloud_app_repo/.woostack/config.json"
jq '.artifacts.plane.baseUrl="https://app.plane.so"' "$plane_cloud_app_repo/.woostack/config.json" >"$plane_cloud_app_repo/.woostack/config.json.tmp" && mv "$plane_cloud_app_repo/.woostack/config.json.tmp" "$plane_cloud_app_repo/.woostack/config.json"
run_doctor "$plane_cloud_app_repo" --live-receipt "$plane_receipt"
assert_exit 0 "$RC" "plane app.plane.so config matches api.plane.so receipt"

# Self-hosted trailing slash config with stripped receipt passes
plane_selfhosted_repo="$(make_repo plane-selfhosted)"
complete_plane_config >"$plane_selfhosted_repo/.woostack/config.json"
jq '.artifacts.plane.baseUrl="https://plane.internal/"' "$plane_selfhosted_repo/.woostack/config.json" >"$plane_selfhosted_repo/.woostack/config.json.tmp" && mv "$plane_selfhosted_repo/.woostack/config.json.tmp" "$plane_selfhosted_repo/.woostack/config.json"
plane_selfhosted_receipt="$TMP/plane-selfhosted-receipt.json"
jq '.baseUrl="https://plane.internal"' "$plane_receipt" >"$plane_selfhosted_receipt"
chmod 600 "$plane_selfhosted_receipt"
run_doctor "$plane_selfhosted_repo" --live-receipt "$plane_selfhosted_receipt"
assert_exit 0 "$RC" "self-hosted plane trailing slash config matches receipt"

finish
