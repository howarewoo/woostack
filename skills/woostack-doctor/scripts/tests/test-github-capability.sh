#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SPY_BIN="$TMP/bin"
SPY_LOG="$TMP/provider-calls.log"
mkdir -p "$SPY_BIN"
for tool in gh linear plane; do
  cat >"$SPY_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "$tool" >>"$SPY_LOG"
exit 99
EOF
  chmod +x "$SPY_BIN/$tool"
done
export PATH="$SPY_BIN:$PATH"


make_repo() {
  local name="$1"
  local repo="$TMP/$name"
  mkdir -p "$repo/.woostack"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  printf '%s\n' '{"models":{},"status":{"staleDays":14}}' >"$repo/.woostack/config.json"
  printf '%s\n' '{}' >"$repo/.woostack/.gitignore"
  printf '%s\n' "$repo"
}

run_doctor() {
  set +e
  OUTPUT="$(bash "$DOCTOR" "$@" 2>&1)"
  RC=$?
  set -e
}

complete_receipt() {
  jq -cn '{
    schemaVersion:1,
    provider:"authorized-github",
    interfaceAvailable:true,
    authenticated:true,
    ready:true,
    viewer:{login:"octocat",id:"MDQ6VXNlcjE="},
    owner:"acme",
    ownerResolution:{status:"unique",login:"acme",type:"organization",id:"MDEyOk9yZ2FuaXphdGlvbjEyMzQ1"},
    repository:"https://github.com/acme/widgets",
    projectStatuses:{complete:true,statusField:"Status",fieldId:"PVTSSF_12345",fieldType:"SINGLE_SELECT",resolved:{
      planned:{name:"Todo",id:"opt_1"},
      executing:{name:"In Progress",id:"opt_2"},
      inReview:{name:"In Review",id:"opt_3"},
      done:{name:"Done",id:"opt_4"},
      blocked:{name:"Blocked",id:"opt_5"}
    }},
    capabilities:{projectRead:true,projectWrite:false,issueRead:true,issueWrite:false,dependencyRead:false,dependencyWrite:false,statusFieldRead:true,statusFieldWrite:false,pagination:true,independentReadBack:true},
    readBack:{status:"verified",complete:true,independent:true}
  }'
}

repo="$(make_repo absent-github)"
run_doctor "$repo"
assert_exit 0 "$RC" "missing canonical GitHub config is valid"
assert_not_contains "$OUTPUT" "provider" "missing config performs no provider preflight"

repo="$(make_repo valid-github)"
git -C "$repo" remote add origin https://github.com/acme/widgets
cat >"$repo/.woostack/config.json" <<'JSON'
{
  "github": {
    "owner": "acme",
    "ownerType": "organization",
    "statusField": "Status",
    "projectStatuses": {
      "planned": "Todo",
      "executing": "In Progress",
      "inReview": "In Review",
      "done": "Done",
      "blocked": "Blocked"
    }
  },
  "models": {},
  "review": {"required": true},
  "status": {"staleDays": 14}
}
JSON
run_doctor "$repo"
assert_exit 0 "$RC" "valid canonical GitHub policy is clean"

jq '.artifacts={provider:"linear",linear:{workspace:"legacy"},plane:{workspace:"legacy-plane"}} | .linear={saveArtifacts:true}' "$repo/.woostack/config.json" >"$repo/config.tmp"
mv "$repo/config.tmp" "$repo/.woostack/config.json"
legacy_after="$(cat "$repo/.woostack/config.json")"
run_doctor "$repo"
assert_exit 0 "$RC" "legacy provider settings do not block local diagnosis"
assert_contains "$OUTPUT" "retired-provider" "legacy settings receive retirement guidance"
assert_eq "$(cat "$repo/.woostack/config.json")" "$legacy_after" "legacy config is unchanged"

repo="$(make_repo malformed-github)"
printf '%s\n' '{"github":{"visibility":"private"}}' >"$repo/.woostack/config.json"
run_doctor "$repo"
assert_exit 1 "$RC" "unknown active GitHub key fails closed"
assert_contains "$OUTPUT" "github policy permits only" "unknown key is actionable"

repo="$(make_repo retained-data)"
git -C "$repo" remote add origin https://github.com/acme/widgets
mkdir -p "$repo/.woostack/tmp/runs/old-run" "$repo/.woostack/specs"
printf '%s\n' '{"mirror":{"provider":"plane","status":"synced"},"sentinel":"retain"}' >"$repo/.woostack/tmp/runs/old-run/manifest.json"
printf '%s\n' 'historical' >"$repo/.woostack/specs/old.md"
manifest_before="$(cat "$repo/.woostack/tmp/runs/old-run/manifest.json")"
run_doctor "$repo"
assert_exit 0 "$RC" "retained mirror-era data does not block local diagnosis"
assert_contains "$OUTPUT" "retained-data" "retained data receives report-only guidance"
assert_eq "$(cat "$repo/.woostack/tmp/runs/old-run/manifest.json")" "$manifest_before" "retained manifest is not mutated"

repo="$(make_repo live-github)"
git -C "$repo" remote add origin https://github.com/acme/widgets
cat >"$repo/.woostack/config.json" <<'JSON'
{"github":{"owner":"acme","ownerType":"organization","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}},"models":{},"status":{"staleDays":14}}
JSON
receipt="$TMP/github-receipt.json"
complete_receipt >"$receipt"
chmod 600 "$receipt"
run_doctor "$repo" --live-receipt "$receipt"
assert_exit 0 "$RC" "fixed read-only GitHub receipt passes with unsupported writes"

mutated="$TMP/missing-read.json"
jq '.capabilities.projectRead=false' "$receipt" >"$mutated"
chmod 600 "$mutated"
run_doctor "$repo" --live-receipt "$mutated"
assert_exit 1 "$RC" "missing fixed project read capability fails"
assert_contains "$OUTPUT" "missing GitHub capability: projectRead" "missing fixed capability is actionable"
for missing_capability in statusFieldRead pagination independentReadBack; do
  mutated="$TMP/missing-$missing_capability.json"
  jq --arg capability "$missing_capability" '.capabilities[$capability]=false' "$receipt" >"$mutated"
  chmod 600 "$mutated"
  run_doctor "$repo" --live-receipt "$mutated"
  assert_exit 1 "$RC" "missing fixed $missing_capability capability fails"
  assert_contains "$OUTPUT" "missing GitHub capability: $missing_capability" "missing fixed capability is actionable"
done

mutated="$TMP/provider-name.json"
jq '.provider="official-gh-cli"' "$receipt" >"$mutated"
chmod 600 "$mutated"
run_doctor "$repo" --live-receipt "$mutated"
assert_exit 1 "$RC" "hard-coded transport provider is rejected"

mutated="$TMP/declared-requirements.json"
jq '.requiredCapabilities=["projectWrite"]' "$receipt" >"$mutated"
chmod 600 "$mutated"
run_doctor "$repo" --live-receipt "$mutated"
assert_exit 1 "$RC" "receipt-declared capability lists cannot alter the contract"

mutated="$TMP/owner-mismatch.json"
jq '.owner="other" | .ownerResolution.login="other"' "$receipt" >"$mutated"
chmod 600 "$mutated"
run_doctor "$repo" --live-receipt "$mutated"
assert_exit 1 "$RC" "receipt owner mismatch fails"
assert_contains "$OUTPUT" "receipt owner does not match" "owner mismatch is actionable"

repo="$(make_repo no-remote)"
run_doctor "$repo" --live-receipt "$receipt"
assert_exit 1 "$RC" "live receipt without a canonical Git remote fails closed"
assert_contains "$OUTPUT" "repository does not match target repository" "missing remote is actionable"
if [ -s "$SPY_LOG" ]; then
  fail "provider command spy was invoked: $(cat "$SPY_LOG")"
else
  pass "static and receipt checks invoke no provider executable"
fi

finish
