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
        designApproved:"Backlog",specHardened:"Backlog",specApproved:"Backlog",planning:"Backlog",
        ready:"Planned",executionApproved:"Planned",executing:"Started",inReview:"Started",
        done:"Completed",abandoned:"Canceled",paused:"Paused"
      },
      issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Review",done:"Done",blocked:"Blocked"}
    }
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
capabilities='{"projectRead":true,"projectWrite":true,"projectUpdateRead":true,"projectUpdateWrite":true,"issueRead":true,"issueWrite":true,"commentRead":true,"commentWrite":true,"relationRead":true,"relationWrite":true,"ownerRead":true,"ownerWrite":true,"independentReadBack":true}'
jq -cn --argjson capabilities "$capabilities" '{ready:true,workspace:"acme",team:"ENG",repository:"https://github.com/acme/widgets",capabilities:$capabilities}' >"$receipt"
chmod 600 "$receipt"
run_doctor "$repo" --live-receipt "$receipt"
assert_exit 0 "$RC" "complete normalized live receipt passes"

jq '.capabilities.commentWrite=false' "$receipt" >"$TMP/read-only.json"
chmod 600 "$TMP/read-only.json"
run_doctor "$repo" --live-receipt "$TMP/read-only.json"
assert_exit 1 "$RC" "read-only live receipt fails closed"
assert_contains "$OUTPUT" "missing Linear MCP capability: commentWrite" "missing mutation capability is exact"
assert_not_contains "$OUTPUT" "LINEAR_API_KEY" "diagnosis never requests an API key"

run_doctor "$repo" --live-receipt "$TMP/missing.json"
assert_exit 1 "$RC" "missing live receipt fails closed"
assert_contains "$OUTPUT" "receipt is missing or unreadable" "missing receipt is actionable"

finish
