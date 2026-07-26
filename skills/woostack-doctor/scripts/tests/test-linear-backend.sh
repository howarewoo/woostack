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

receipt="$TMP/receipt.json"
complete_receipt >"$receipt"
chmod 600 "$receipt"
run_doctor "$repo" --live-receipt "$receipt"
assert_exit 0 "$RC" "complete normalized live receipt passes"

jq 'del(.schemaVersion,.provider,.mcpAvailable,.authenticated,.workspaceResolution,.teamResolution,.projectStatuses,.issueStates,.readBack)' \
  "$receipt" >"$TMP/partial.json"
chmod 600 "$TMP/partial.json"
run_doctor "$repo" --live-receipt "$TMP/partial.json"
assert_exit 1 "$RC" "partial live receipt fails closed"
assert_contains "$OUTPUT" "malformed, partial, or not ready" "partial receipt rejection is actionable"

jq '.workspaceResolution.name="foreign" | .teamResolution.key="OTHER"' \
  "$receipt" >"$TMP/foreign-identity.json"
chmod 600 "$TMP/foreign-identity.json"
run_doctor "$repo" --live-receipt "$TMP/foreign-identity.json"
assert_exit 1 "$RC" "foreign resolved workspace and team fail closed"
assert_contains "$OUTPUT" "malformed, partial, or not ready" "foreign identity rejection is actionable"

jq '.issueStates.resolved.done.category="started"' "$receipt" >"$TMP/invalid-state-category.json"
chmod 600 "$TMP/invalid-state-category.json"
run_doctor "$repo" --live-receipt "$TMP/invalid-state-category.json"
assert_exit 1 "$RC" "invalid semantic issue-state category fails closed"
assert_contains "$OUTPUT" "malformed, partial, or not ready" "invalid category rejection is actionable"

jq '.capabilities.commentWrite=false' "$receipt" >"$TMP/read-only.json"
chmod 600 "$TMP/read-only.json"
run_doctor "$repo" --live-receipt "$TMP/read-only.json"
assert_exit 1 "$RC" "read-only live receipt fails closed"
assert_contains "$OUTPUT" "missing Linear MCP capability: commentWrite" "missing mutation capability is exact"
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

sed -i.bak "s|$provenance_uri|linear://issue/nested/$provenance_id|" \
  "$provenance_repo/.woostack/memory/linear.md"
rm -f "$provenance_repo/.woostack/memory/linear.md.bak"
run_doctor "$provenance_repo"
assert_exit 0 "$RC" "malformed provenance remains a static warning"
assert_contains "$OUTPUT" "is malformed (expected linear://project|document|issue/<uuid>)" "local parser rejects nested provenance paths"
[ ! -e "$legacy_marker" ] || fail "malformed static provenance invoked the forbidden legacy Linear adapter"
unset WOOSTACK_LINEAR_ADAPTER

finish
