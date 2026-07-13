#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
CHECKS="$HERE/../checks"
LINEAR="$HERE/../../../woostack-init/scripts/artifacts/linear.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

complete_linear_config() {
  jq -cn '{
    artifacts:{specPlan:"linear"},
    linear:{
      repository:"acme/widgets",
      workspace:"acme",
      team:"ENG",
      projectStatuses:{draft:"Draft",hardened:"Hardened",approved:"Approved",planning:"Planning",ready:"Ready",executing:"In Progress",inReview:"In Review",done:"Completed",abandoned:"Canceled"},
      issueStates:{planned:"Backlog",executing:"In Progress",inReview:"In Review",done:"Done",blocked:"Blocked"}
    }
  }'
}

make_repo() {
  local name="$1" repo
  repo="$TMP/$name"
  mkdir -p "$repo/.woostack/memory" "$repo/.woostack/specs" "$repo/.woostack/plans" "$repo/.woostack/fixes"
  git -C "$repo" init -q
  complete_linear_config >"$repo/.woostack/config.json"
  printf '%s\n' "$repo"
}

write_note() {
  local repo="$1" file="$2" source="$3"
  cat >"$repo/.woostack/memory/$file" <<EOF
---
name: ${file%.md}
type: pattern
scope: *
source: $source
updated: 2026-07-13
---
body
EOF
}

run_doctor() {
  local repo="$1"; shift
  set +e
  OUTPUT="$(bash "$DOCTOR" "$repo" "$@" 2>&1)"
  RC=$?
  set -e
}

# Static Linear diagnostics must resolve config without credentials, skip local spec/plan
# authoring checks, preserve fixes checks, and report coexisting local docs as inactive legacy.
repo="$(make_repo static)"
cat >"$repo/.woostack/specs/legacy.md" <<'EOF'
---
type: wrong
status: wip
---
# Legacy spec
EOF
cat >"$repo/.woostack/plans/legacy.md" <<'EOF'
---
type: wrong
status: approved
---
# Legacy plan
EOF
cat >"$repo/.woostack/fixes/active.md" <<'EOF'
---
type: wrong
status: wip
---
# Active fix
EOF
run_doctor "$repo"
assert_exit 1 "$RC" "Linear static doctor keeps active fix errors"
assert_contains "$OUTPUT" "artifact-legacy-local" "Linear mode reports inactive local spec/plan artifacts"
assert_contains "$OUTPUT" ".woostack/specs/legacy.md" "inactive spec is identified"
assert_contains "$OUTPUT" ".woostack/plans/legacy.md" "inactive plan is identified"
assert_not_contains "$OUTPUT" "[doc-type] .woostack/specs/legacy.md" "Linear mode skips local spec type checks"
assert_not_contains "$OUTPUT" "[status-enum] .woostack/specs/legacy.md" "Linear mode skips local spec status checks"
assert_not_contains "$OUTPUT" "[doc-type] .woostack/plans/legacy.md" "Linear mode skips local plan type checks"
assert_not_contains "$OUTPUT" "[status-band]" "Linear mode skips local spec/plan status-band checks"
assert_not_contains "$OUTPUT" "[plan-source" "Linear mode skips local plan source checks"
assert_not_contains "$OUTPUT" "[spec-plan-backlink]" "Linear mode skips local spec/plan backlink checks"
assert_contains "$OUTPUT" "[doc-type] .woostack/fixes/active.md" "Linear mode still checks backend-neutral fixes"
assert_contains "$OUTPUT" "[status-enum] .woostack/fixes/active.md" "Linear mode still checks fix status values"

# Invalid selector/config is a static error, and the static run never requests credentials.
bad="$(make_repo bad-config)"
jq '.artifacts.specPlan="sqlite"' "$bad/.woostack/config.json" >"$bad/.woostack/config.json.tmp"
mv "$bad/.woostack/config.json.tmp" "$bad/.woostack/config.json"
run_doctor "$bad"
assert_exit 1 "$RC" "invalid backend config fails static doctor"
assert_contains "$OUTPUT" "artifact-config" "invalid selector is a backend config finding"
assert_contains "$OUTPUT" "artifacts.specPlan" "invalid selector finding names the safe config path"
assert_not_contains "$OUTPUT" "LINEAR_API_KEY" "static config diagnostics do not ask for credentials"

# The adapter owns strict, stable Linear provenance URI parsing without authentication.
project_uri='linear://project/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
document_uri='linear://document/dddddddd-dddd-4ddd-8ddd-dddddddddddd'
issue_uri='linear://issue/11111111-1111-4111-8111-111111111111'
for uri in "$project_uri" "$document_uri" "$issue_uri"; do
  parsed="$(bash "$LINEAR" provenance-parse --reference "$uri")"
  assert_eq "$(jq -r '.uri' <<<"$parsed")" "$uri" "adapter preserves canonical Linear provenance URI"
  assert_eq "$(jq -r '.id' <<<"$parsed")" "${uri##*/}" "adapter parses stable resource UUID"
done
parsed="$(bash "$LINEAR" provenance-parse --reference 'linear://project/AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA')"
assert_eq "$(jq -r '.uri' <<<"$parsed")" "$project_uri" "adapter canonicalizes UUID case without changing identity"
for uri in \
  'linear://project/not-a-uuid' \
  'linear://project/nested/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' \
  'linear://documents/dddddddd-dddd-4ddd-8ddd-dddddddddddd' \
  'linear://issue/11111111-1111-4111-8111-111111111111?x=1' \
  'https://linear.app/acme/project/example'; do
  if bash "$LINEAR" provenance-parse --reference "$uri" >/dev/null 2>&1; then
    fail "adapter must reject malformed provenance URI: $uri"
  else
    pass
  fi
done

prov="$(make_repo provenance)"
write_note "$prov" project.md "$project_uri"
write_note "$prov" document.md "$document_uri"
write_note "$prov" issue.md "$issue_uri"
write_note "$prov" malformed.md 'linear://project/not-a-uuid'
write_note "$prov" nested.md 'linear://project/nested/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
run_doctor "$prov"
assert_exit 0 "$RC" "Linear provenance shape warnings do not fail static doctor"
assert_not_contains "$OUTPUT" "project.md: source" "valid project URI passes static provenance validation"
assert_not_contains "$OUTPUT" "document.md: source" "valid document URI passes static provenance validation"
assert_not_contains "$OUTPUT" "issue.md: source" "valid issue URI passes static provenance validation"
assert_contains "$OUTPUT" "malformed.md: source 'linear://project/not-a-uuid' is malformed" "malformed Linear URI is reported statically"
assert_contains "$OUTPUT" "nested.md: source" "nested Linear URI is reported statically"

# Fake normalized adapter proves live mode is explicit, authenticated, fail-closed, and
# resolves each provenance kind without allowing any remote repair path.
FAKE="$TMP/fake-linear.sh"
cat >"$FAKE" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_LINEAR_LOG"
command="$1"; shift
case "$command" in
  preflight)
    [ -n "${LINEAR_API_KEY:-}" ] || { echo 'linear request: LINEAR_API_KEY is required' >&2; exit 1; }
    [ "${FAKE_LINEAR_MODE:-ok}" = ok ] || { echo "linear preflight: ${FAKE_LINEAR_MODE}" >&2; exit 1; }
    printf '%s\n' '{"workspace":{"id":"w"},"team":{"id":"t"},"projectStatuses":{"draft":"1"},"issueStates":{"planned":"2"}}'
    ;;
  doctor-read)
    [ -n "${LINEAR_API_KEY:-}" ] || exit 1
    [ "${FAKE_LINEAR_RESOURCE_MODE:-ok}" = ok ] || { echo 'linear resources: missing or drifted' >&2; exit 1; }
    printf '%s\n' '{"backend":"linear","features":[]}'
    ;;
  provenance-parse)
    reference="$2"
    [[ "$reference" =~ ^linear://(project|document|issue)/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
    ;;
  provenance-resolve)
    [ -n "${LINEAR_API_KEY:-}" ] || exit 1
    [ "${FAKE_LINEAR_RESOURCE_MODE:-ok}" = ok ] || { echo 'linear resources: missing or drifted' >&2; exit 1; }
    printf '%s\n' '{"backend":"linear","resource":{"exists":true},"feature":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}'
    ;;
  *) exit 2 ;;
esac
FAKE
chmod +x "$FAKE"
export WOOSTACK_LINEAR_ADAPTER="$FAKE"
export FAKE_LINEAR_LOG="$TMP/fake-linear.log"
: >"$FAKE_LINEAR_LOG"

unset LINEAR_API_KEY
run_doctor "$prov" --live
assert_exit 1 "$RC" "live doctor fails closed without authentication"
assert_contains "$OUTPUT" "linear-live" "missing live authentication is an error finding"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "preflight" "live doctor invokes normalized adapter preflight"
assert_not_contains "$(cat "$FAKE_LINEAR_LOG")" "provenance-resolve" "resource reads stop when preflight fails"

: >"$FAKE_LINEAR_LOG"
export LINEAR_API_KEY='test-only-secret'
export FAKE_LINEAR_MODE=ok
export FAKE_LINEAR_RESOURCE_MODE=ok
run_doctor "$prov" --live
assert_exit 0 "$RC" "authenticated live doctor succeeds on valid remote state"
assert_contains "$OUTPUT" "linear-write-scope-unverifiable" "live doctor reports the non-mutating write-scope introspection limit"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "preflight" "live doctor validates schema workspace team mappings and capabilities"
assert_eq "$(grep -c '^preflight' "$FAKE_LINEAR_LOG")" 1 "live doctor performs authenticated preflight exactly once"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "doctor-read" "live doctor validates all managed resources through normalized adapter"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "provenance-resolve --reference $project_uri" "live doctor resolves project provenance through adapter"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "provenance-resolve --reference $document_uri" "live doctor resolves document provenance through adapter"
assert_contains "$(cat "$FAKE_LINEAR_LOG")" "provenance-resolve --reference $issue_uri" "live doctor resolves issue provenance through adapter"
assert_not_contains "$(cat "$FAKE_LINEAR_LOG")" "provenance-resolve --reference linear://project/not-a-uuid" "malformed provenance is parsed but never resolved remotely"

for mode in authentication schema workspace team mappings access; do
  : >"$FAKE_LINEAR_LOG"
  export FAKE_LINEAR_MODE="$mode"
  run_doctor "$prov" --live
  assert_exit 1 "$RC" "live doctor fails closed on $mode validation failure"
  assert_contains "$OUTPUT" "linear-live" "$mode failure is surfaced as a live error"
done

export FAKE_LINEAR_MODE=ok
export FAKE_LINEAR_RESOURCE_MODE=drift
run_doctor "$prov" --live
assert_exit 1 "$RC" "live doctor fails closed on resource relation or metadata drift"
assert_contains "$OUTPUT" "memory-provenance-live" "remote provenance drift is surfaced"

: >"$FAKE_LINEAR_LOG"
bash "$CHECKS/config-keys.sh" --fix "$prov" artifacts >/dev/null 2>&1 || true
bash "$CHECKS/doc-type.sh" --fix "$prov" "$prov/.woostack/specs/legacy.md" >/dev/null 2>&1 || true
assert_eq "$(cat "$FAKE_LINEAR_LOG")" "" "doctor repair paths never call or mutate Linear"

finish
