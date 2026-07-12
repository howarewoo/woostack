#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS="$(cd "$HERE/../artifacts" && pwd)"
FIXTURES="$HERE/fixtures/linear"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/responses"
cat >"$work/bin/linear-request.sh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
operation=''; document=''; variables=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --operation) operation="$2"; shift 2 ;;
    --document) document="$2"; shift 2 ;;
    --variables) variables="$2"; shift 2 ;;
    *) exit 2 ;;
  esac
done
name="$(basename "$document" .graphql)"
count_file="$LINEAR_FAKE_STATE/$name.count"
count=0; [ ! -f "$count_file" ] || count="$(cat "$count_file")"
count=$((count + 1)); printf '%s' "$count" >"$count_file"
printf '%s\t%s\t%s\n' "$operation" "$name" "$variables" >>"$LINEAR_FAKE_STATE/calls"
response="$LINEAR_FAKE_RESPONSES/$name.$count.json"
[ -f "$response" ] || { echo "missing fake response: $name.$count" >&2; exit 1; }
if [ -f "$LINEAR_FAKE_RESPONSES/$name.$count.fail" ]; then
  cat "$response"
  exit 1
fi
cat "$response"
FAKE
chmod +x "$work/bin/linear-request.sh"
export LINEAR_REQUEST_SH="$work/bin/linear-request.sh"
export LINEAR_FAKE_STATE="$work"
export LINEAR_FAKE_RESPONSES="$work/responses"

reset_fake() { rm -f "$work"/*.count "$work/calls" "$work/responses"/*; }
queue() { cp "$FIXTURES/$2" "$work/responses/$1.$3.json"; }
run_capture() {
  set +e
  OUTPUT="$("$ARTIFACTS/linear.sh" "$@" 2>&1)"
  RC=$?
  set -e
}
call_variables() {
  local name="$1" occurrence="$2"
  grep $'\t'"$name"$'\t' "$work/calls" | sed -n "${occurrence}p" | cut -f3-
}
make_document_list() {
  local output="$1" content_file="$2" updated_at="$3"
  jq -n --rawfile content "$content_file" --arg project "$project_id" --arg updated "$updated_at" '
    {data:{documents:{nodes:[{
      id:"dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      title:"Feature Alpha — Spec",
      url:"https://linear.app/acme/document/feature-alpha-spec-dddddddd",
      content:$content,
      updatedAt:$updated,
      project:{id:$project}
    }],pageInfo:{hasNextPage:false,endCursor:null}}}}
  ' >"$output"
}
status_map='{"draft":"10000000-0000-4000-8000-000000000001","hardened":"10000000-0000-4000-8000-000000000002","approved":"10000000-0000-4000-8000-000000000003","planning":"10000000-0000-4000-8000-000000000004","ready":"10000000-0000-4000-8000-000000000005","executing":"10000000-0000-4000-8000-000000000006","inReview":"10000000-0000-4000-8000-000000000007","done":"10000000-0000-4000-8000-000000000008","abandoned":"10000000-0000-4000-8000-000000000009"}'
project_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
team_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
project_status_names='{"draft":"Draft","hardened":"Hardened","approved":"Approved","planning":"Planning","ready":"Ready","executing":"In Progress","inReview":"In Review","done":"Completed","abandoned":"Canceled"}'
issue_state_names='{"planned":"Backlog","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}'

# Public preflight resolves the complete configured lifecycle, including abandoned.
reset_fake; queue preflight http-preflight-success.json 1
run_capture preflight --workspace acme --team ENG --project-statuses "$project_status_names" --issue-states "$issue_state_names"
assert_exit 0 "$RC" "preflight resolves complete mappings"
assert_eq "$(jq -r '.projectStatuses.abandoned' <<<"$OUTPUT")" "ps-abandoned" "preflight resolves required abandoned status"
reset_fake
run_capture preflight --workspace acme --team ENG --project-statuses '{"draft":"Draft"}' --issue-states "$issue_state_names"
assert_exit 1 "$RC" "preflight rejects incomplete project lifecycle before querying"
if [ -f "$work/calls" ]; then fail "invalid preflight must not query"; else pass; fi
duplicate_project_status_names="$(jq -c '.hardened=.draft' <<<"$project_status_names")"
reset_fake
run_capture preflight --workspace acme --team ENG --project-statuses "$duplicate_project_status_names" --issue-states "$issue_state_names"
assert_exit 1 "$RC" "preflight rejects aliased project statuses before querying"
if [ -f "$work/calls" ]; then fail "aliased project statuses must not query"; else pass; fi
duplicate_issue_state_names="$(jq -c '.blocked=.done' <<<"$issue_state_names")"
reset_fake
run_capture preflight --workspace acme --team ENG --project-statuses "$project_status_names" --issue-states "$duplicate_issue_state_names"
assert_exit 1 "$RC" "preflight rejects aliased issue states before querying"
if [ -f "$work/calls" ]; then fail "aliased issue states must not query"; else pass; fi


# Exact UUID and Linear URL resolve only when canonical ownership/schema markers match.
reset_fake; queue project-list project-list-one.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]' --reference "$project_id"
assert_exit 0 "$RC" "explicit UUID resolves"
assert_eq "$(jq -r '.id' <<<"$OUTPUT")" "$project_id" "explicit UUID returns stable id"
reset_fake; queue project-list project-list-one.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]' --reference "https://linear.app/acme/project/feature-alpha-abc123"
assert_exit 0 "$RC" "Linear URL resolves"
reset_fake; queue project-list project-list-foreign.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]' --reference "$project_id"
assert_exit 1 "$RC" "explicit foreign project fails closed"
assert_contains "$OUTPUT" "ownership" "foreign project diagnostic is safe"

# Repository + eligible lifecycle discovery is exact and deterministic.
reset_fake; queue project-list project-list-one.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 0 "$RC" "one eligible managed project resolves"
reset_fake; queue project-list project-list-none.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 3 "$RC" "zero eligible projects returns not-found"
reset_fake; queue project-list project-list-multiple.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft","hardened"]'
assert_exit 4 "$RC" "multiple eligible projects are ambiguous"
assert_contains "$OUTPUT" "$project_id" "candidate list includes UUID"
assert_contains "$OUTPUT" "Feature Alpha" "candidate list includes title"
first_line="$(printf '%s\n' "$OUTPUT" | grep '^candidate ' | sed -n '1p')"
assert_contains "$first_line" "$project_id" "candidate list is UUID sorted"
reset_fake; queue project-list project-list-same-title.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 3 "$RC" "same title alone is never adopted"

# Create does discovery before mutation, reads back, creates one spec, and verifies it.
printf '# Feature Alpha\n\nAcceptance body.\n' >"$work/spec.md"
reset_fake
queue project-list project-list-none.json 1
queue project-create project-create-success.json 1
queue project-list project-list-one.json 2
queue document-list document-list-none.json 1
queue document-create document-create-success.json 1
queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "project and spec create succeeds"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "create receipt is verified"
for field in attempted observed returned verified pending; do
  if jq -e --arg field "$field" 'has($field)' <<<"$OUTPUT" >/dev/null; then pass; else fail "create receipt includes $field"; fi
done
assert_eq "$(grep -c $'mutation\tproject-create' "$work/calls")" "1" "project mutation occurs once"
assert_eq "$(grep -c $'mutation\tdocument-create' "$work/calls")" "1" "document mutation occurs once"
project_create_variables="$(call_variables project-create 1)"
assert_eq "$(jq -r '.input.teamIds[0]' <<<"$project_create_variables")" "$team_id" "project create sends configured team ID"
assert_eq "$(jq -r '.input.statusId' <<<"$project_create_variables")" "$(jq -r '.draft' <<<"$status_map")" "project create sends draft status ID"
assert_contains "$(jq -r '.input.description' <<<"$project_create_variables")" '"repository":"acme/widgets"' "project create sends canonical repository ownership"
document_create_variables="$(call_variables document-create 1)"
assert_eq "$(jq -r '.input.projectId' <<<"$document_create_variables")" "$project_id" "document create sends observed project ID"
assert_contains "$(jq -r '.input.content' <<<"$document_create_variables")" "Acceptance body." "document create sends exact source content"
assert_contains "$(jq -r '.input.content' <<<"$document_create_variables")" '"repository":"acme/widgets"' "document create appends canonical spec ownership"

# Unknown mutation outcome is discovered and resumed without repeating the mutation.
reset_fake
queue project-list project-list-none.json 1
queue project-create project-create-success.json 1; touch "$work/responses/project-create.1.fail"
queue project-list project-list-one.json 2
queue document-list document-list-none.json 1
queue document-create document-create-success.json 1
queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "unknown project mutation outcome resumes by discovery"
assert_eq "$(grep -c $'mutation\tproject-create' "$work/calls")" "1" "unknown project mutation is never retried blindly"
assert_eq "$(jq -r '.observed.project' <<<"$OUTPUT")" "$project_id" "receipt records discovered project"

# Unknown document-create outcome is also discovered without a blind retry.
reset_fake
queue project-list project-list-one.json 1
queue document-list document-list-none.json 1
queue document-create document-create-success.json 1; touch "$work/responses/document-create.1.fail"
queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "unknown document mutation outcome resumes by discovery"
assert_eq "$(grep -c $'mutation\tdocument-create' "$work/calls")" "1" "unknown document mutation is never retried blindly"
assert_contains "$(jq -c '.attempted' <<<"$OUTPUT")" "documentCreate" "receipt records unknown mutation attempt"

# Failed recovery reads remain unverified and never repeat an ambiguous mutation.
reset_fake
queue project-list project-list-none.json 1
queue project-create project-create-success.json 1; touch "$work/responses/project-create.1.fail"
queue project-list project-list-one.json 2; touch "$work/responses/project-list.2.fail"
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "failed project-create read-back stays unverified"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "false" "failed project read-back is unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["project-read-back"]' "failed project read-back has a precise pending reason"
assert_not_contains "$OUTPUT" "Acceptance body." "failed project read-back receipt excludes spec content"
assert_eq "$(grep -c $'mutation\tproject-create' "$work/calls")" "1" "failed project read-back never retries project create"

reset_fake
queue project-list project-list-one.json 1
queue document-list document-list-none.json 1
queue document-create document-create-success.json 1; touch "$work/responses/document-create.1.fail"
queue document-list document-list-one.json 2; touch "$work/responses/document-list.2.fail"
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "failed document-create read-back stays unverified"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "false" "failed document read-back is unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["document-read-back"]' "failed document read-back has a precise pending reason"
assert_not_contains "$OUTPUT" "Acceptance body." "failed document read-back receipt excludes spec content"
assert_eq "$(grep -c $'mutation\tdocument-create' "$work/calls")" "1" "failed document read-back never retries document create"

# Partial completion resumes existing project and document without duplicate mutation.
reset_fake
queue project-list project-list-one.json 1
queue document-list document-list-one.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "partial completion resumes"
assert_eq "$(grep -c $'mutation\t' "$work/calls" || true)" "0" "resume performs no duplicate mutations"
reset_fake; queue project-list project-list-duplicate-managed.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 4 "$RC" "duplicate managed projects block creation"
reset_fake; queue project-list project-list-one.json 1; queue document-list document-list-duplicate-managed.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "duplicate managed spec documents block resume"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-create' "duplicate specs never trigger another create"

# Spec read emits content and optimistic revision; write checks live revision, updates, then reads back.
reset_fake; queue document-list document-list-one.json 1
run_capture spec-read --project "$project_id" --repository acme/widgets
assert_exit 0 "$RC" "spec read succeeds"
revision="$(jq -c '.revision' <<<"$OUTPUT")"
printf '# Feature Alpha\n\nRevised body.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/revised.md"
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-success.json 1; queue document-list document-list-updated.json 2
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 0 "$RC" "spec update with matching revision succeeds"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "spec update is read-back verified"
document_update_variables="$(call_variables document-update 1)"
assert_eq "$(jq -r '.id' <<<"$document_update_variables")" "dddddddd-dddd-4ddd-8ddd-dddddddddddd" "document update targets the managed spec"
assert_contains "$(jq -r '.input.content' <<<"$document_update_variables")" "Revised body." "document update sends revised content"
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-success.json 1; touch "$work/responses/document-update.1.fail"; queue document-list document-list-updated.json 2
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 0 "$RC" "unknown spec update outcome resumes by read-back"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "unknown update is verified from observed content"
assert_eq "$(grep -c $'mutation\tdocument-update' "$work/calls")" "1" "unknown spec update is never retried blindly"
reset_fake
queue document-list document-list-one.json 1
queue document-update document-update-success.json 1; touch "$work/responses/document-update.1.fail"
queue document-list document-list-updated.json 2; touch "$work/responses/document-list.2.fail"
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 1 "$RC" "failed spec-write read-back stays unverified"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "false" "failed spec read-back is unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["document-read-back"]' "failed spec read-back has a precise pending reason"
assert_not_contains "$OUTPUT" "Revised body." "failed spec read-back receipt excludes spec content"
assert_eq "$(grep -c $'mutation\tdocument-update' "$work/calls")" "1" "failed spec read-back never retries document update"

reset_fake; queue document-list document-list-updated.json 1
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 1 "$RC" "stale spec revision blocks before mutation"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-update' "stale write does not mutate"

# Forward lifecycle and explicit abandon are permitted; downgrade/archive/delete are rejected.
reset_fake; queue project-list project-list-one.json 1; queue project-update project-update-hardened.json 1; queue project-list project-list-hardened.json 2
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target hardened
assert_exit 0 "$RC" "draft to hardened transition succeeds"
assert_eq "$(jq -r '.current' <<<"$OUTPUT")" "draft" "transition receipt includes current"
assert_eq "$(jq -r '.target' <<<"$OUTPUT")" "hardened" "transition receipt includes target"
transition_variables="$(call_variables project-update 1)"
assert_eq "$(jq -r '.id' <<<"$transition_variables")" "$project_id" "transition targets the managed project"
assert_eq "$(jq -r '.input.statusId' <<<"$transition_variables")" "$(jq -r '.hardened' <<<"$status_map")" "transition sends the target status ID"
reset_fake; queue project-list project-list-hardened.json 1
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target draft
assert_exit 1 "$RC" "lifecycle downgrade is rejected"
reset_fake; queue project-list project-list-one.json 1; queue project-update project-update-abandoned.json 1; queue project-list project-list-abandoned.json 2
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target abandoned
assert_exit 0 "$RC" "explicit abandon succeeds"
reset_fake
queue project-list project-list-one.json 1
queue project-update project-update-hardened.json 1; touch "$work/responses/project-update.1.fail"
queue project-list project-list-hardened.json 2; touch "$work/responses/project-list.2.fail"
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target hardened
assert_exit 1 "$RC" "failed transition read-back stays unverified"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "false" "failed transition read-back is unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["project-read-back"]' "failed transition read-back has a precise pending reason"
assert_eq "$(grep -c $'mutation\tproject-update' "$work/calls")" "1" "failed transition read-back never retries project update"
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target archive
assert_exit 1 "$RC" "archive transition is prohibited"
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target delete
assert_exit 1 "$RC" "delete transition is prohibited"

# Pagination consumes all pages and rejects missing or repeated cursors.
reset_fake; queue project-list project-list-page1.json 1; queue project-list project-list-page2.json 2
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 0 "$RC" "project discovery consumes a second page"
assert_eq "$(jq -r '.after' <<<"$(call_variables project-list 2)")" "cursor-1" "project pagination forwards the next cursor"
reset_fake; queue project-list project-list-missing-cursor.json 1
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 1 "$RC" "project pagination rejects a missing cursor"
reset_fake; queue project-list project-list-repeat-cursor-1.json 1; queue project-list project-list-repeat-cursor-2.json 2
run_capture feature-resolve --repository acme/widgets --status-map "$status_map" --eligible-statuses '["draft"]'
assert_exit 1 "$RC" "project pagination rejects a repeated non-progress cursor"
reset_fake; queue document-list document-list-page1.json 1; queue document-list document-list-page2.json 2
run_capture spec-read --project "$project_id" --repository acme/widgets
assert_exit 0 "$RC" "document discovery consumes a second page"
assert_eq "$(jq -r '.after' <<<"$(call_variables document-list 2)")" "doc-cursor-1" "document pagination forwards the next cursor"
reset_fake; queue document-list document-list-missing-cursor.json 1
run_capture spec-read --project "$project_id" --repository acme/widgets
assert_exit 1 "$RC" "document pagination rejects a missing cursor"
reset_fake; queue document-list document-list-repeat-cursor-1.json 1; queue document-list document-list-repeat-cursor-2.json 2
run_capture spec-read --project "$project_id" --repository acme/widgets
assert_exit 1 "$RC" "document pagination rejects a repeated non-progress cursor"

# A transport-success response with success=false is still treated as an attempted,
# unknown outcome and always followed by discovery for all four mutations.
reset_fake; queue project-list project-list-none.json 1; queue project-create project-create-partial.json 1; queue project-list project-list-one.json 2; queue document-list document-list-one.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "partial project-create response resumes from read-back"
assert_eq "$(jq -r '.returned.project' <<<"$OUTPUT")" "null" "partial project-create has no claimed return"
reset_fake; queue project-list project-list-one.json 1; queue document-list document-list-none.json 1; queue document-create document-create-partial.json 1; queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "partial document-create response resumes from read-back"
assert_eq "$(jq -r '.returned.document' <<<"$OUTPUT")" "null" "partial document-create has no claimed return"
assert_not_contains "$OUTPUT" "Acceptance body." "successful create receipt excludes spec text"
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-partial.json 1; queue document-list document-list-updated.json 2
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 0 "$RC" "partial document-update response resumes from read-back"
assert_eq "$(jq -r '.returned.document' <<<"$OUTPUT")" "null" "partial document-update has no claimed return"
reset_fake; queue project-list project-list-one.json 1; queue project-update project-update-partial.json 1; queue project-list project-list-hardened.json 2
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target hardened
assert_exit 0 "$RC" "partial project-update response resumes from read-back"
assert_eq "$(jq -r '.returned.project' <<<"$OUTPUT")" "null" "partial project-update has no claimed return"

# Returned-versus-observed identity/status mismatches never verify.
reset_fake; queue project-list project-list-none.json 1; queue project-create project-create-wrong-id.json 1; queue project-list project-list-one.json 2; queue document-list document-list-one.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "project-create returned ID mismatch fails verification"
assert_contains "$OUTPUT" "project-return-mismatch" "project-create mismatch is pending"
reset_fake; queue project-list project-list-one.json 1; queue document-list document-list-none.json 1; queue document-create document-create-wrong-id.json 1; queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "document-create returned ID mismatch fails verification"
assert_contains "$OUTPUT" "document-return-mismatch" "document-create mismatch is pending"
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-wrong-id.json 1; queue document-list document-list-updated.json 2
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 1 "$RC" "document-update returned ID mismatch fails verification"
assert_contains "$OUTPUT" "document-return-mismatch" "document-update mismatch is pending"
reset_fake; queue project-list project-list-one.json 1; queue project-update project-update-wrong-id.json 1; queue project-list project-list-hardened.json 2
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target hardened
assert_exit 1 "$RC" "project-update returned ID mismatch fails verification"
reset_fake; queue project-list project-list-one.json 1; queue project-update project-update-wrong-status.json 1; queue project-list project-list-hardened.json 2
run_capture feature-transition --project "$project_id" --repository acme/widgets --status-map "$status_map" --target hardened
assert_exit 1 "$RC" "project-update returned status mismatch fails verification"

# Exact spec bytes are authoritative on create/resume, without leaking text in receipts.
printf '# Feature Alpha\n\nTOP-SECRET-SPEC-TEXT\n' >"$work/mismatch.md"
reset_fake; queue project-list project-list-one.json 1; queue document-list document-list-one.json 1
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/mismatch.md"
assert_exit 1 "$RC" "resume rejects observed spec content mismatch"
assert_contains "$OUTPUT" "document-content-verification" "spec mismatch remains pending"
assert_not_contains "$OUTPUT" "TOP-SECRET-SPEC-TEXT" "failure receipt excludes spec text"

# Exact comparisons distinguish zero, one, and multiple terminal newlines.
printf '# Feature Alpha\n\nZero newline.\n\n+++ Woostack metadata — managed, do not edit\n{\"artifactType\":\"spec\",\"projectId\":\"%s\",\"repository\":\"acme/widgets\",\"schema\":1}\n+++' "$project_id" >"$work/zero-newline.md"
make_document_list "$work/zero-list.json" "$work/zero-newline.md" '2026-07-12T10:06:00.000Z'
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-partial.json 1; cp "$work/zero-list.json" "$work/responses/document-list.2.json"
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/zero-newline.md" --expected-revision "$revision"
assert_exit 0 "$RC" "zero-terminal-newline content verifies exactly"
printf '\n' >>"$work/zero-newline.md"
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-partial.json 1; cp "$work/zero-list.json" "$work/responses/document-list.2.json"
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/zero-newline.md" --expected-revision "$revision"
assert_exit 1 "$RC" "one versus zero terminal newline mismatch fails"
printf '\n' >>"$work/zero-newline.md"
cp "$work/zero-newline.md" "$work/one-newline.md"
truncate -s -1 "$work/one-newline.md"
make_document_list "$work/one-list.json" "$work/one-newline.md" '2026-07-12T10:07:00.000Z'
reset_fake; queue document-list document-list-one.json 1; queue document-update document-update-partial.json 1; cp "$work/one-list.json" "$work/responses/document-list.2.json"
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/zero-newline.md" --expected-revision "$revision"
assert_exit 1 "$RC" "multiple terminal newlines never collapse to one"

# Terminal projects are preserved as history but do not block the next feature.
reset_fake
queue project-list project-list-done.json 1
queue project-create project-create-success.json 1
queue project-list project-list-one.json 2
queue document-list document-list-none.json 1
queue document-create document-create-success.json 1
queue document-list document-list-one.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 0 "$RC" "preserved terminal project does not block the next feature"
assert_eq "$(grep -c $'mutation\tproject-create' "$work/calls")" "1" "next feature creates one project beside terminal history"

# Duplicate resources discovered after unknown outcomes remain safe and un-retried.
reset_fake; queue project-list project-list-none.json 1; queue project-create project-create-success.json 1; touch "$work/responses/project-create.1.fail"; queue project-list project-list-duplicate-managed.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "duplicate projects after unknown outcome stay pending"
assert_eq "$(grep -c $'mutation\tproject-create' "$work/calls")" "1" "duplicate discovery never retries project create"
reset_fake; queue project-list project-list-one.json 1; queue document-list document-list-none.json 1; queue document-create document-create-success.json 1; touch "$work/responses/document-create.1.fail"; queue document-list document-list-duplicate-managed.json 2
run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
assert_exit 1 "$RC" "duplicate specs after unknown outcome stay pending"
assert_eq "$(grep -c $'mutation\tdocument-create' "$work/calls")" "1" "duplicate discovery never retries document create"

# Marker-bearing invalid metadata is never downgraded to an unmanaged document.
for invalid_fixture in document-list-malformed-metadata.json document-list-duplicate-marker.json document-list-foreign-metadata.json document-list-unsupported-schema.json; do
  reset_fake; queue project-list project-list-one.json 1; queue document-list "$invalid_fixture" 1
  run_capture feature-create --repository acme/widgets --title 'Feature Alpha' --team-id "$team_id" --status-map "$status_map" --spec-file "$work/spec.md"
  assert_exit 1 "$RC" "$invalid_fixture blocks create/resume"
  assert_contains "$OUTPUT" "managed spec metadata" "$invalid_fixture returns a safe metadata diagnostic"
  assert_not_contains "$(cat "$work/calls")" $'mutation\t' "$invalid_fixture causes zero mutation"
done
reset_fake; queue document-list document-list-foreign-metadata.json 1
run_capture spec-read --project "$project_id" --repository acme/widgets
assert_exit 1 "$RC" "foreign marker ownership blocks spec read"
assert_contains "$OUTPUT" "foreign ownership" "spec read reports safe ownership diagnostic"
reset_fake; queue document-list document-list-unsupported-schema.json 1
run_capture spec-write --project "$project_id" --repository acme/widgets --content-file "$work/revised.md" --expected-revision "$revision"
assert_exit 1 "$RC" "unsupported marker schema blocks spec write"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-update' "invalid metadata blocks update mutation"

finish
