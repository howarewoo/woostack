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
make_increment_description() {
  local content="$1" stable="$2" ordinal="$3" dependencies="$4" parent="$5" metadata
  metadata="$(jq -cnS --arg projectId "$project_id" --arg repository acme/widgets --arg stable "$stable" --argjson ordinal "$ordinal" --argjson dependencies "$dependencies" --arg gitParent "$parent" '
    {artifactType:"increment",projectId:$projectId,repository:$repository,schema:1,incrementId:$stable,ordinal:$ordinal,dependencies:$dependencies,gitParent:$gitParent,branch:null,pullRequest:null}
  ')"
  printf '%s\n\n%s\n%s\n%s\n' "$content" '+++ Woostack metadata — managed, do not edit' "$metadata" '+++'
}
status_map='{"draft":"10000000-0000-4000-8000-000000000001","hardened":"10000000-0000-4000-8000-000000000002","approved":"10000000-0000-4000-8000-000000000003","planning":"10000000-0000-4000-8000-000000000004","ready":"10000000-0000-4000-8000-000000000005","executing":"10000000-0000-4000-8000-000000000006","inReview":"10000000-0000-4000-8000-000000000007","done":"10000000-0000-4000-8000-000000000008","abandoned":"10000000-0000-4000-8000-000000000009"}'
project_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
team_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
project_status_names='{"draft":"Draft","hardened":"Hardened","approved":"Approved","planning":"Planning","ready":"Ready","executing":"In Progress","inReview":"In Review","done":"Completed","abandoned":"Canceled"}'
issue_state_names='{"planned":"Backlog","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}'
issue_state_map='{"planned":"20000000-0000-4000-8000-000000000001","executing":"20000000-0000-4000-8000-000000000002","inReview":"20000000-0000-4000-8000-000000000003","done":"20000000-0000-4000-8000-000000000004","blocked":"20000000-0000-4000-8000-000000000005"}'

# Public preflight resolves the complete configured lifecycle, including abandoned.
reset_fake; queue preflight http-preflight-success.json 1
run_capture preflight --workspace acme --team ENG --project-statuses "$project_status_names" --issue-states "$issue_state_names"
assert_exit 0 "$RC" "preflight resolves complete mappings"
assert_eq "$(jq -r '.projectStatuses.abandoned' <<<"$OUTPUT")" "ps-abandoned" "preflight resolves required abandoned status"
assert_eq "$(jq -r '.viewer.id' <<<"$OUTPUT")" "viewer-1" "preflight returns authenticated viewer identity"

# Authenticated preflight identifies an active viewer; schema visibility alone is not
# effective access evidence.
reset_fake; queue preflight http-preflight-success.json 1
jq '.data.viewer.active = false' "$work/responses/preflight.1.json" >"$work/inactive-viewer.json"
mv "$work/inactive-viewer.json" "$work/responses/preflight.1.json"
run_capture preflight --workspace acme --team ENG --project-statuses "$project_status_names" --issue-states "$issue_state_names"
assert_exit 1 "$RC" "preflight rejects an inactive authenticated viewer"
assert_contains "$OUTPUT" "viewer.active" "inactive viewer diagnostic names the access field"
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
printf '# Feature Alpha\n\nRevised body.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","designState":"draft","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/revised.md"
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

# Rejected issue validation and discovery leave no temporary spec copies behind.
spec_tmp="$work/spec-temp"
mkdir -p "$spec_tmp"
reset_fake; queue document-list document-list-one.json 1
TMPDIR="$spec_tmp" run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/revised.md" --expected-revision "$revision" --issue-state-map '{}'
assert_exit 1 "$RC" "invalid issue-state map blocks spec write"
if compgen -G "$spec_tmp/*" >/dev/null; then
  fail "issue-map validation must not leak temporary spec files"
else
  pass
fi
reset_fake; queue document-list document-list-one.json 1
queue issue-list issue-list-none.json 1; touch "$work/responses/issue-list.1.fail"
TMPDIR="$spec_tmp" run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/revised.md" --expected-revision "$revision" \
  --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "failed increment discovery blocks spec write"
if compgen -G "$spec_tmp/*" >/dev/null; then
  fail "increment discovery failure must clean temporary spec files"
else
  pass
fi
# Evidence-aware spec writes carry discovered implementation evidence through the adapter.
printf '# Feature Alpha\n\nReady.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","designState":"ready","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/ready-unfrozen.md"
printf '# Feature Alpha\n\nReady.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"ready","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/ready-frozen.md"
make_document_list "$work/ready-unfrozen-list.json" "$work/ready-unfrozen.md" '2026-07-12T10:09:00.000Z'
make_document_list "$work/ready-frozen-list.json" "$work/ready-frozen.md" '2026-07-12T10:10:00.000Z'
freeze_revision="$(python3 "$ARTIFACTS/linear-metadata.py" revision \
  --updated-at '2026-07-12T10:09:00.000Z' <"$work/ready-unfrozen.md")"
reset_fake
cp "$work/ready-unfrozen-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
queue document-update document-update-success.json 1
cp "$work/ready-frozen-list.json" "$work/responses/document-list.2.json"
run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/ready-frozen.md" --expected-revision "$freeze_revision" \
  --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "evidence-free ready-state freeze succeeds through the adapter"
assert_eq "$(grep -c $'mutation\tdocument-update' "$work/calls")" "1" "evidence-free freeze mutates once"
reset_fake
cp "$work/ready-unfrozen-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-evidence.json 1
run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/ready-frozen.md" --expected-revision "$freeze_revision" \
  --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "discovered implementation evidence blocks the ready-state freeze"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-update' "evidenced freeze performs no mutation"

# Feature read emits the canonical frozen branch/SHA pair from spec metadata.
printf '# Feature Alpha\n\nFrozen.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"ready","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/frozen-spec.md"
make_document_list "$work/frozen-document-list.json" "$work/frozen-spec.md" '2026-07-12T10:08:00.000Z'
reset_fake; queue project-list project-list-one.json 1; cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"; queue issue-list issue-list-none.json 1
run_capture feature-read --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "feature read emits frozen execution base"
assert_eq "$(jq -r '.feature.baseBranch' <<<"$OUTPUT")" "main" "feature read emits canonical baseBranch"
assert_eq "$(jq -r '.feature.baseCommitSha' <<<"$OUTPUT")" "0123456789abcdef0123456789abcdef01234567" "feature read emits canonical baseCommitSha"
assert_eq "$(jq -r '.feature | has("branch")' <<<"$OUTPUT")" "false" "legacy ambiguous feature branch field is absent"

# Stable memory provenance resolves through the normalized feature reader. Document/issue
# UUIDs first resolve their parent project, then exact membership, ownership metadata, and
# native relation agreement are validated by feature-read.
project_uri="linear://project/$project_id"
document_uri='linear://document/dddddddd-dddd-4ddd-8ddd-dddddddddddd'
issue_uri='linear://issue/cccccccc-0001-4000-8000-000000000001'
run_capture provenance-parse --reference "linear://project/nested/$project_id"
assert_exit 1 "$RC" "nested Linear provenance URI is rejected rather than reduced to its final UUID"
reset_fake
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
run_capture provenance-resolve --reference "$project_uri" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "project provenance resolves through normalized feature model"
assert_eq "$(jq -r '.resource.kind' <<<"$OUTPUT")" project "project provenance preserves resource kind"

reset_fake
queue provenance-document provenance-document.json 1
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
run_capture provenance-resolve --reference "$document_uri" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "document provenance resolves through normalized managed spec"
assert_eq "$(jq -r '.resource.projectId' <<<"$OUTPUT")" "$project_id" "document provenance returns stable parent"

reset_fake
queue provenance-issue provenance-issue.json 1
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-valid.json 1
run_capture provenance-resolve --reference "$issue_uri" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "issue provenance resolves through normalized managed increments"
assert_eq "$(jq -r '.resource.id' <<<"$OUTPUT")" 'cccccccc-0001-4000-8000-000000000001' "issue provenance preserves stable UUID"

# Successful lookup is insufficient when the resource is absent from the normalized feature.
unmanaged_document_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
reset_fake
queue provenance-document provenance-document.json 1
jq --arg id "$unmanaged_document_id" '.data.document.id=$id' \
  "$work/responses/provenance-document.1.json" >"$work/unmanaged-document.json"
mv "$work/unmanaged-document.json" "$work/responses/provenance-document.1.json"
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
run_capture provenance-resolve --reference "linear://document/$unmanaged_document_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "document provenance rejects a valid lookup outside the managed spec"
assert_contains "$OUTPUT" "provenance document is not the managed spec" "document membership failure names the violated boundary"

unmanaged_issue_id='eeeeeeee-0001-4000-8000-000000000001'
reset_fake
queue provenance-issue provenance-issue.json 1
jq --arg id "$unmanaged_issue_id" '.data.issue.id=$id' \
  "$work/responses/provenance-issue.1.json" >"$work/unmanaged-issue.json"
mv "$work/unmanaged-issue.json" "$work/responses/provenance-issue.1.json"
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-valid.json 1
run_capture provenance-resolve --reference "linear://issue/$unmanaged_issue_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "issue provenance rejects a valid lookup outside the managed increments"
assert_contains "$OUTPUT" "provenance issue is not a managed increment" "issue membership failure names the violated boundary"

reset_fake
queue provenance-issue provenance-issue.json 1
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-relation-drift.json 1
run_capture provenance-resolve --reference "$issue_uri" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "issue provenance fails closed on relation or metadata drift"

second_project_id='ffffffff-ffff-4fff-8fff-ffffffffffff'
reset_fake
jq --arg id "$second_project_id" '
  .data.projects.nodes += [(.data.projects.nodes[0] |
    .id=$id | .name="Feature Beta" |
    .url="https://linear.app/acme/project/feature-beta-def456")]
' "$FIXTURES/project-list-one.json" >"$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
jq --arg old "$project_id" --arg new "$second_project_id" '
  walk(if type=="string" then gsub($old;$new) else . end) |
  .data.documents.nodes[0].id="ffffffff-dddd-4ddd-8ddd-dddddddddddd" |
  .data.documents.nodes[0].title="Feature Beta — Spec" |
  .data.documents.nodes[0].url="https://linear.app/acme/document/feature-beta-spec-ffffffff"
' "$work/frozen-document-list.json" >"$work/responses/document-list.2.json"
queue issue-list issue-list-none.json 1
queue issue-list issue-list-none.json 2
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "live doctor read validates every managed feature through normalized models"
assert_eq "$(jq -c '[.features[].feature.id]' <<<"$OUTPUT")" \
  "[\"$project_id\",\"$second_project_id\"]" "doctor read returns every managed repository feature after one discovery pass"

reset_fake
queue project-list project-list-none.json 1
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "live doctor read fails closed when no managed repository feature exists"

reset_fake
jq '.data.projects.nodes += [(.data.projects.nodes[0] |
  .id=(.id|ascii_upcase) | .archivedAt="2026-07-13T00:00:00.000Z")]' \
  "$FIXTURES/project-list-one.json" >"$work/responses/project-list.1.json"
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "live doctor read fails closed on duplicate managed project identity"
assert_contains "$OUTPUT" "doctor managed project identity is ambiguous" "duplicate project failure names the ambiguous snapshot"

reset_fake
jq '.data.projects.nodes[0].description |= sub("\"schema\":1"; "\"schema\":2")' \
  "$FIXTURES/project-list-one.json" >"$work/responses/project-list.1.json"
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "live doctor read fails closed on managed project schema drift"

reset_fake
jq '.data.projects.nodes[0].status.id = "99999999-9999-4999-8999-999999999999"' \
  "$FIXTURES/project-list-one.json" >"$work/responses/project-list.1.json"
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "live doctor read fails closed on unmapped project status"

reset_fake
queue project-list project-list-one.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-relation-drift.json 1
run_capture doctor-read --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "live doctor read fails closed on managed relation or metadata drift"

# Explicit replan may change the frozen pair only after live increment evidence is clean.
printf '# Feature Alpha\n\nReplanned.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","baseBranch":"release/next","baseCommitSha":"2123456789abcdef0123456789abcdef01234567","designState":"planning","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/replanned-spec.md"
make_document_list "$work/replanned-document-list.json" "$work/replanned-spec.md" '2026-07-12T10:09:00.000Z'
frozen_revision="$("$ARTIFACTS/linear-metadata.py" revision --updated-at '2026-07-12T10:08:00.000Z' <"$work/frozen-spec.md")"
reset_fake
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
queue document-update document-update-success.json 1
cp "$work/replanned-document-list.json" "$work/responses/document-list.2.json"
run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/replanned-spec.md" --expected-revision "$frozen_revision" \
  --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "explicit pre-artifact replan changes the frozen base"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "replan spec write is read-back verified"
reset_fake
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-evidence.json 1
run_capture spec-write --project "$project_id" --repository acme/widgets \
  --content-file "$work/replanned-spec.md" --expected-revision "$frozen_revision" \
  --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "implementation evidence blocks frozen-base replan"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-update' "evidenced replan blocks before mutation"

# Ready-to-planning first claims the revisioned managed spec, then changes the project.
jq --arg status "$(jq -r '.ready' <<<"$status_map")" '.data.projects.nodes[0].status.id=$status' \
  "$FIXTURES/project-list-one.json" >"$work/project-list-ready.json"
jq --arg status "$(jq -r '.planning' <<<"$status_map")" '.data.projects.nodes[0].status.id=$status' \
  "$FIXTURES/project-list-one.json" >"$work/project-list-planning.json"
jq --arg status "$(jq -r '.planning' <<<"$status_map")" '.data.projectUpdate.project.status.id=$status' \
  "$FIXTURES/project-update-hardened.json" >"$work/project-update-planning.json"
printf '# Feature Alpha\n\nFrozen.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"planning","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/claimed-spec.md"
make_document_list "$work/claimed-document-list.json" "$work/claimed-spec.md" '2026-07-12T10:09:00.000Z'
claimed_revision="$("$ARTIFACTS/linear-metadata.py" revision --updated-at '2026-07-12T10:09:00.000Z' <"$work/claimed-spec.md")"
reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.2.json"
queue issue-list issue-list-none.json 2
queue document-update document-update-success.json 1
cp "$work/claimed-document-list.json" "$work/responses/document-list.3.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.4.json"
cp "$work/project-update-planning.json" "$work/responses/project-update.1.json"
cp "$work/project-list-planning.json" "$work/responses/project-list.2.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 0 "$RC" "explicit evidence-free ready-to-planning replan succeeds"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "replan lifecycle transition is read-back verified"
assert_eq "$(cut -f2 "$work/calls" | tr '\n' ',')" \
  "project-list,document-list,issue-list,document-list,issue-list,document-update,document-list,document-list,project-update,project-list," \
  "valid replan claims and verifies the spec before project mutation"

# A ready project plus the revision-matched planning claim resumes only the project transition.
reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
cp "$work/project-update-planning.json" "$work/responses/project-update.1.json"
cp "$work/project-list-planning.json" "$work/responses/project-list.2.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$claimed_revision"
assert_exit 0 "$RC" "ready project with planning spec resumes the project transition"
assert_eq "$(jq -c '.attempted' <<<"$OUTPUT")" '["projectUpdate"]' \
  "split-lifecycle recovery reports only the retried project mutation"
assert_not_contains "$(cat "$work/calls")" $'mutation\tdocument-update' \
  "split-lifecycle recovery does not repeat the spec claim"

# The inverse split is never a recoverable replan state.
reset_fake
cp "$work/project-list-planning.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 1 "$RC" "planning project with ready spec blocks replan"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "planning-ready split blocks before mutation"

reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-evidence.json 1
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 1 "$RC" "implementation evidence blocks ready-to-planning transition"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "evidenced replan blocks before either mutation"

# Losing the optimistic spec claim to execution approval leaves the project untouched.
printf '# Feature Alpha\n\nApproved for execution.\n\n+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"executionApproved","projectId":"%s","repository":"acme/widgets","schema":1}\n+++\n' "$project_id" >"$work/execution-approved-spec.md"
make_document_list "$work/execution-approved-document-list.json" \
  "$work/execution-approved-spec.md" '2026-07-12T10:10:00.000Z'
reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.2.json"
queue issue-list issue-list-none.json 2
queue document-update document-update-success.json 1
cp "$work/execution-approved-document-list.json" "$work/responses/document-list.3.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 1 "$RC" "execution approval winning the spec claim race blocks project replan"
assert_not_contains "$(cat "$work/calls")" $'mutation\tproject-update' \
  "lost optimistic spec claim prevents project mutation"

# A failed project transition leaves the claimed planning spec verified for safe recovery.
reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.2.json"
queue issue-list issue-list-none.json 2
queue document-update document-update-success.json 1
cp "$work/claimed-document-list.json" "$work/responses/document-list.3.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.4.json"
queue project-update project-update-hardened.json 1
touch "$work/responses/project-update.1.fail"
cp "$work/project-list-ready.json" "$work/responses/project-list.2.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.5.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 1 "$RC" "failed project transition remains unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["project-status-verification"]' \
  "failed project transition reports only project recovery"
assert_eq "$(cut -f2 "$work/calls" | tr '\n' ',')" \
  "project-list,document-list,issue-list,document-list,issue-list,document-update,document-list,document-list,project-update,project-list,document-list," \
  "failed project transition verifies the preserved planning spec"

# A project read-back outage preserves the claimed spec and reports exact recovery state.
reset_fake
cp "$work/project-list-ready.json" "$work/responses/project-list.1.json"
cp "$work/frozen-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
cp "$work/frozen-document-list.json" "$work/responses/document-list.2.json"
queue issue-list issue-list-none.json 2
queue document-update document-update-success.json 1
cp "$work/claimed-document-list.json" "$work/responses/document-list.3.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.4.json"
cp "$work/project-update-planning.json" "$work/responses/project-update.1.json"
cp "$work/project-list-ready.json" "$work/responses/project-list.2.json"
touch "$work/responses/project-list.2.fail"
cp "$work/claimed-document-list.json" "$work/responses/document-list.5.json"
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$frozen_revision"
assert_exit 1 "$RC" "replan project read-back outage remains unverified"
assert_eq "$(jq -c '.pending' <<<"$OUTPUT")" '["project-read-back"]' \
  "replan outage reports only project read-back recovery"
assert_eq "$(grep -c $'mutation\tdocument-update' "$work/calls")" "1" \
  "replan outage never retries the verified spec claim"
assert_eq "$(grep -c $'mutation\tproject-update' "$work/calls")" "1" \
  "replan outage never retries the project transition"
reset_fake
cp "$work/project-list-planning.json" "$work/responses/project-list.1.json"
cp "$work/claimed-document-list.json" "$work/responses/document-list.1.json"
queue issue-list issue-list-none.json 1
run_capture feature-transition --project "$project_id" --repository acme/widgets \
  --status-map "$status_map" --target planning --replan --issue-state-map "$issue_state_map" \
  --expected-revision "$claimed_revision"
assert_exit 0 "$RC" "verified planning pair safely resumes without another mutation"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "safe resume does not repeat either mutation"

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
printf '# Feature Alpha\n\nZero newline.\n\n+++ Woostack metadata — managed, do not edit\n{\"artifactType\":\"spec\",\"designState\":\"draft\",\"projectId\":\"%s\",\"repository\":\"acme/widgets\",\"schema\":1}\n+++' "$project_id" >"$work/zero-newline.md"
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

# Issue GraphQL documents are explicit query/mutation contracts.
for document in issue-list issue-create issue-update relation-create relation-delete; do
  if [ -s "$ARTIFACTS/graphql/$document.graphql" ]; then pass; else fail "$document GraphQL document exists"; fi
done
assert_contains "$(cat "$ARTIFACTS/graphql/issue-list.graphql")" 'inverseRelations' "issue query reads native blocked-by ancestry"
assert_contains "$(cat "$ARTIFACTS/graphql/relation-create.graphql")" 'IssueRelationCreateInput' "relation create uses the native relation mutation"

# Managed issues normalize in stable ordinal order, not API order. Independent
# roots remain independent while explicit native blocked-by edges are mirrored.
reset_fake; queue issue-list issue-list-valid.json 1
run_capture plan-read --project "$project_id" --repository acme/widgets --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "ordered managed issue DAG normalizes"
assert_eq "$(jq -r '.increments | map(.ordinal) | join(",")' <<<"$OUTPUT")" "1,2,3" "issue presentation is deterministic by positive ordinal"
assert_eq "$(jq -r '.increments[0].incrementId' <<<"$OUTPUT")" "track-a" "API order does not control plan order"
assert_eq "$(jq -r '[.increments[] | select(.dependencies|length==0)] | length' <<<"$OUTPUT")" "2" "independent roots and tracks are preserved"
assert_eq "$(jq -r '.increments[2].dependencies[0]' <<<"$OUTPUT")" "cccccccc-0001-4000-8000-000000000001" "native blocked-by UUID is normalized"
assert_eq "$(jq -r '.increments[2].gitParent' <<<"$OUTPUT")" "cccccccc-0001-4000-8000-000000000001" "one representable Git parent is retained"

# Metadata/native relation disagreement blocks rather than guessing.
reset_fake; queue issue-list issue-list-relation-drift.json 1
run_capture plan-read --project "$project_id" --repository acme/widgets --issue-state-map "$issue_state_map"
assert_exit 1 "$RC" "relation drift fails closed"
assert_contains "$OUTPUT" "disagree" "relation drift has a safe diagnostic"

# Desired plan validation happens before transport writes.
cat >"$work/cyclic-plan.json" <<'EOF'
{"increments":[
  {"incrementId":"one","title":"One","ordinal":1,"dependencies":["two"],"gitParent":"two","content":"One"},
  {"incrementId":"two","title":"Two","ordinal":2,"dependencies":["one"],"gitParent":"one","content":"Two"}
]}
EOF
reset_fake
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/cyclic-plan.json"
assert_exit 1 "$RC" "cyclic desired plan is rejected before discovery"
if [ -f "$work/calls" ]; then fail "invalid desired plan must not query or mutate"; else pass; fi

# Reconciliation never cancels/removes an issue carrying implementation evidence.
printf '%s\n' '{"increments":[]}' >"$work/empty-plan.json"
reset_fake; queue project-list project-list-one.json 1; queue issue-list issue-list-evidence.json 1
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/empty-plan.json"
assert_exit 1 "$RC" "issue with branch and PR evidence cannot be removed"
assert_contains "$OUTPUT" "evidence" "evidenced removal refusal is actionable"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "evidenced removal performs no mutation"

# A full reconciliation retains A's UUID while updating and safely reordering
# it, creates C, removes evidence-free B, rewires B→A to A→C, and discovers
# every unknown update/removal/relation outcome without retrying.
cat >"$work/reconcile-plan.json" <<'EOF'
{"increments":[
  {"incrementId":"keep-a","title":"Updated A","ordinal":1,"dependencies":[],"gitParent":"main","content":"New A."},
  {"incrementId":"new-c","title":"New C","ordinal":2,"dependencies":["keep-a"],"gitParent":"keep-a","content":"New C."}
]}
EOF
reset_fake
jq -s '.[0] as $base | .[1].data.issues.nodes[0] as $created | $base | .data.issues.nodes += [$created]' "$FIXTURES/issue-list-reconcile-before.json" "$FIXTURES/issue-list-new-root.json" >"$work/issue-list-create-discovery-full.json"
queue project-list project-list-one.json 1
queue issue-list issue-list-reconcile-before.json 1
queue issue-create issue-create-success.json 1
for count in 1 2; do queue issue-update issue-update-success.json "$count"; touch "$work/responses/issue-update.$count.fail"; done
cp "$work/issue-list-create-discovery-full.json" "$work/responses/issue-list.2.json"
queue issue-list issue-list-reconcile-issues.json 3
queue relation-delete relation-delete-success.json 1; touch "$work/responses/relation-delete.1.fail"
queue relation-create relation-create-success.json 1; touch "$work/responses/relation-create.1.fail"
queue issue-list issue-list-reconcile-final.json 4
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/reconcile-plan.json"
assert_exit 0 "$RC" "retained/create/reorder/rewire/remove reconciliation verifies after unknown outcomes"
assert_eq "$(jq -r '.observed.issueIds[] | select(.incrementId=="keep-a") | .id' <<<"$OUTPUT")" "cccccccc-0001-4000-8000-000000000001" "retained increment preserves its Linear UUID"
assert_eq "$(jq -r '.readBack.increments | map(.ordinal) | join(",")' <<<"$OUTPUT")" "1,2" "safe reorder is read back deterministically"
assert_eq "$(jq -r '.readBack.increments[1].dependencies[0]' <<<"$OUTPUT")" "cccccccc-0001-4000-8000-000000000001" "final readback verifies rewired DAG"
assert_eq "$(jq -r '.readBack.dagVerified' <<<"$OUTPUT")" "true" "final DAG validation is explicit"
assert_eq "$(jq -r '.remainingSubsteps | length' <<<"$OUTPUT")" "0" "compound receipt has no remaining substeps"
assert_eq "$(jq -r '.returned.mutations | map(.operation) | join(",")' <<<"$OUTPUT")" "issueCreate,issueUpdate,issueRemove,issueRelationDelete,issueRelationCreate" "compound receipt records each mutation response category"
assert_not_contains "$OUTPUT" "New A." "compound receipt excludes managed issue content"
assert_eq "$(cut -f2 "$work/calls" | tr '\n' ',')" "project-list,issue-list,issue-create,issue-list,issue-update,issue-update,issue-list,relation-delete,relation-create,issue-list," "create discovery and all issue writes/readback precede relation rewiring"
assert_eq "$(grep -c $'mutation\tissue-update' "$work/calls")" "2" "unknown issue update and removal outcomes are never retried"
assert_eq "$(grep -c $'mutation\trelation-delete' "$work/calls")" "1" "unknown relation delete is never retried"
assert_eq "$(grep -c $'mutation\trelation-create' "$work/calls")" "1" "unknown relation create is never retried"

# Unknown issueCreate is discovered by managed identity before proceeding and
# never duplicated.
cat >"$work/new-root-plan.json" <<'EOF'
{"increments":[{"incrementId":"new-c","title":"New C","ordinal":1,"dependencies":[],"gitParent":"main","content":"New C."}]}
EOF
reset_fake
queue project-list project-list-one.json 1
queue issue-list issue-list-none.json 1
queue issue-create issue-create-success.json 1; touch "$work/responses/issue-create.1.fail"
queue issue-list issue-list-new-root.json 2
queue issue-list issue-list-new-root.json 3
queue issue-list issue-list-new-root.json 4
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/new-root-plan.json"
assert_exit 0 "$RC" "unknown issue create is discovered and reconciled"
assert_eq "$(grep -c $'mutation\tissue-create' "$work/calls")" "1" "unknown issue create is never retried"
assert_eq "$(jq -r '.returned.mutations[0].returnedId' <<<"$OUTPUT")" "null" "receipt distinguishes unknown mutation response"
assert_eq "$(jq -r '.returned.mutations[0].observedId' <<<"$OUTPUT")" "cccccccc-0003-4000-8000-000000000003" "receipt records discovered UUID"
# Even a successful issueCreate response is only provisional: discovery must
# prove the managed identity and returned UUID before any dependent write.
cat >"$work/dependent-create-plan.json" <<'EOF'
{"increments":[
  {"incrementId":"new-c","title":"New C","ordinal":1,"dependencies":[],"gitParent":"main","content":"New C."},
  {"incrementId":"new-d","title":"New D","ordinal":2,"dependencies":["new-c"],"gitParent":"new-c","content":"New D."}
]}
EOF
jq '.data.issueCreate.issue.id="cccccccc-0099-4000-8000-000000000099"' "$FIXTURES/issue-create-success.json" >"$work/issue-create-wrong-returned-uuid.json"
reset_fake; queue project-list project-list-one.json 1
queue issue-list issue-list-none.json 1
cp "$work/issue-create-wrong-returned-uuid.json" "$work/responses/issue-create.1.json"
queue issue-list issue-list-new-root.json 2
queue issue-list issue-list-new-root.json 3
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/dependent-create-plan.json"
assert_exit 1 "$RC" "create returned UUID mismatch remains pending"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "issue-create-return-mismatch" "create mismatch receipt is explicit"
assert_eq "$(jq -r '.returned.mutations[0].returnedId' <<<"$OUTPUT")" "cccccccc-0099-4000-8000-000000000099" "receipt records provisional returned UUID"
assert_eq "$(jq -r '.returned.mutations[0].observedId' <<<"$OUTPUT")" "cccccccc-0003-4000-8000-000000000003" "receipt records managed discovery UUID"
assert_eq "$(jq -r '.observed.issueIds | length' <<<"$OUTPUT")" "0" "mismatched create is not admitted to the UUID map"
assert_eq "$(grep -c $'mutation\tissue-create' "$work/calls")" "1" "create mismatch stops before dependent issue creation"
assert_not_contains "$(cat "$work/calls")" $'mutation\tissue-update' "create mismatch stops before issue update"
assert_not_contains "$(cat "$work/calls")" $'mutation\trelation-' "create mismatch stops before relation mutation"

# Relation repair can resume from metadata/native drift left by an unknown
# relation outcome. Initial discovery tolerates only that drift; final readback
# remains strict and keeps the failed repair pending.
jq '.data.issues.nodes[1].inverseRelations.nodes=[]' "$FIXTURES/issue-list-reconcile-final.json" >"$work/issue-list-relation-drift-resume.json"
reset_fake; queue project-list project-list-one.json 1
for count in 1 2 3; do cp "$work/issue-list-relation-drift-resume.json" "$work/responses/issue-list.$count.json"; done
queue relation-create relation-create-success.json 1; touch "$work/responses/relation-create.1.fail"
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/reconcile-plan.json"
assert_exit 1 "$RC" "failed relation repair remains pending after strict readback"
assert_eq "$(grep -c $'mutation\trelation-create' "$work/calls")" "1" "failed relation repair is attempted once"
assert_not_contains "$(cat "$work/calls")" $'mutation\tissue-' "failed relation repair does not duplicate converged issue writes"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "final-dag-verification" "relation drift fails strict final DAG verification"
reset_fake; queue project-list project-list-one.json 1
cp "$work/issue-list-relation-drift-resume.json" "$work/responses/issue-list.1.json"
cp "$work/issue-list-relation-drift-resume.json" "$work/responses/issue-list.2.json"
queue relation-create relation-create-success.json 1
queue issue-list issue-list-reconcile-final.json 3
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/reconcile-plan.json"
assert_exit 0 "$RC" "next reconciliation repairs relation drift"
assert_eq "$(grep -c $'mutation\trelation-create' "$work/calls")" "1" "resumed relation repair creates only the missing edge"
assert_not_contains "$(cat "$work/calls")" $'mutation\tissue-' "resumed relation repair does not duplicate converged issue writes"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "resumed repair passes strict final readback"

# Execution evidence is stored only in the managed metadata block. The native
# issue mutation owns only stateId and description, and readback gates inReview.
reset_fake
queue project-list project-list-one.json 1
queue issue-list issue-list-executing.json 1
queue issue-update issue-update-success.json 1
queue issue-list issue-list-evidence.json 2
run_capture issue-transition --project "$project_id" --repository acme/widgets --issue ENG-11 --issue-state-map "$issue_state_map" --target inReview --branch feature/eng-11 --pull-request https://github.com/acme/widgets/pull/11
assert_exit 0 "$RC" "inReview transition stores and verifies branch/PR evidence"
transition_variables="$(sed -n '3p' "$work/calls" | cut -f3-)"
assert_eq "$(jq -r '.input | keys | sort | join(",")' <<<"$transition_variables")" "description,stateId" "issue transition mutates no unowned native fields"
transition_metadata="$(jq -r '.input.description' <<<"$transition_variables" | python3 "$ARTIFACTS/linear-metadata.py" parse --repository acme/widgets --project-id "$project_id")"
assert_eq "$(jq -r '.branch' <<<"$transition_metadata")" "feature/eng-11" "branch is stored in managed issue metadata"
assert_eq "$(jq -r '.pullRequest' <<<"$transition_metadata")" "https://github.com/acme/widgets/pull/11" "pull request is stored in managed issue metadata"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "inReview transition receipt is read-back verified"
assert_eq "$(cut -f2 "$work/calls" | tr '\n' ',')" "project-list,issue-list,issue-update,issue-list," "issue transition discovers owned project/issue, mutates once, then reads back"

reset_fake; queue project-list project-list-one.json 1; queue issue-list issue-list-executing.json 1
run_capture issue-transition --project "$project_id" --repository acme/widgets --issue ENG-11 --issue-state-map "$issue_state_map" --target inReview
assert_exit 1 "$RC" "inReview transition without branch/PR evidence is refused"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "missing inReview evidence performs no mutation"
reset_fake
run_capture issue-transition --project "$project_id" --repository acme/widgets --issue ENG-11 --issue-state-map "$issue_state_map" --target "done"
assert_exit 1 "$RC" "direct issue done transition is refused"
if [ -f "$work/calls" ]; then fail "direct done refusal must occur before API access"; else pass; fi

# Terminal reconciliation requires one exact merged PR attribution pair, moves
# only its in-review issue, then verifies the already-all-done project.
cat >"$work/merged-prs.json" <<EOF
[{"projectId":"$project_id","issueIdentifier":"ENG-11","url":"https://github.com/acme/widgets/pull/11","merged":true}]
EOF
review_snapshot='{"projectStatus":"inReview","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"inReview"}]}'
review_eligible='["cccccccc-0001-4000-8000-000000000001"]'
done_snapshot='{"projectStatus":"done","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"done"}]}'
review_done_snapshot='{"projectStatus":"inReview","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"done"}]}'
executing_snapshot='{"projectStatus":"inReview","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"executing"}]}'
review_expect=(--expected-eligible "$review_eligible" --expected-project-transition true --expected-snapshot "$review_snapshot")
done_expect=(--expected-eligible '[]' --expected-project-transition false --expected-snapshot "$done_snapshot")
executing_expect=(--expected-eligible '[]' --expected-project-transition false --expected-snapshot "$executing_snapshot")
reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence.json 1
queue issue-update issue-update-success.json 1
queue issue-list issue-list-evidence-done.json 2
queue project-list project-list-in-review.json 2
queue project-update project-update-done.json 1
queue project-list project-list-done.json 3
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 0 "$RC" "status reconciliation accepts an exact caller preview snapshot"
reset_fake
queue project-list project-list-done.json 1
queue issue-list issue-list-evidence-done.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${done_expect[@]}"
assert_exit 0 "$RC" "done project is idempotently verified"
assert_eq "$(jq -r '.eligibleIssues | length' <<<"$OUTPUT")" "0" "done project has no eligible mutations"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "done project performs no mutation"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "done project receipt is verified"
# When the project is not done, the adapter verifies eligible issue completion
# before projectUpdate, then verifies the project readback.
reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence.json 1
queue issue-update issue-update-success.json 1
queue issue-list issue-list-evidence-done.json 2
queue project-list project-list-in-review.json 2
queue project-update project-update-done.json 1
queue project-list project-list-done.json 3
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 0 "$RC" "all-done issue readback advances and verifies a non-done project"
assert_eq "$(cut -f2 "$work/calls" | tr '\n' ',')" "project-list,issue-list,issue-update,issue-list,project-list,project-update,project-list," "project transition occurs only after ownership and issue done readback"
assert_eq "$(jq -r '.completed | join(",")' <<<"$OUTPUT")" "issueUpdate,projectUpdate" "terminal receipt records both verified mutations"
assert_eq "$(jq -r '.projectDone' <<<"$OUTPUT")" "true" "terminal receipt verifies project done"
assert_eq "$(jq -r '.pending | length' <<<"$OUTPUT")" "0" "terminal receipt has no remaining verification"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "compound terminal receipt is verified"

reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence.json 1
queue issue-update issue-update-success.json 1
queue issue-list issue-list-evidence-done.json 2
queue project-list project-list-done.json 2
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "project status drift after issue read-back fails closed"
assert_contains "$OUTPUT" "project status drifted before terminal mutation" "project drift diagnostic names the stale terminal preview"
assert_not_contains "$(cat "$work/calls")" $'mutation\tproject-update' "project status drift blocks the project mutation"

reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence.json 1
printf '%s\n' '{"errors":[{"message":"simulated issue mutation failure"}]}' >"$work/responses/issue-update.1.json"
queue issue-list issue-list-evidence-done.json 2
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "unknown issue mutation response fails closed even when read-back is done"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "issue-update-failed" "unknown mutation outcome remains explicit in the receipt"
assert_not_contains "$(cat "$work/calls")" $'mutation\tproject-update' "unknown issue mutation outcome blocks project mutation"

reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence-done.json 1
queue issue-list issue-list-evidence-done.json 2
queue project-list project-list-in-review.json 2
queue project-update project-update-done.json 1
queue project-list project-list-done.json 3
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" \
  --expected-eligible '[]' --expected-project-transition true --expected-snapshot "$review_done_snapshot"
assert_exit 0 "$RC" "retry resumes with a project-only terminal transition"
assert_not_contains "$(cat "$work/calls")" $'mutation\tissue-update' "resumable project-only retry does not repeat issue mutation"
assert_eq "$(jq -r '.completed|join(",")' <<<"$OUTPUT")" "projectUpdate" "project-only retry verifies exactly the project write"

reset_fake
queue project-list project-list-in-review.json 1
queue issue-list issue-list-evidence.json 1
queue issue-update issue-update-success.json 1
queue issue-list issue-list-evidence-done.json 2
queue project-list project-list-in-review.json 2
queue project-update project-update-partial.json 1
queue project-list project-list-done.json 3
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "project mutation API failure cannot pass despite matching read-back"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "project-update-failed" "project API failure remains explicit in the receipt"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "false" "API-failed project receipt is never verified"


printf '%s\n' '[{"projectId":"not-a-uuid","issueIdentifier":"ENG-11","url":"https://github.com/acme/widgets/pull/11","merged":true}]' >"$work/bad-prs.json"
reset_fake
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/bad-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "malformed Linear-Project attribution is rejected"
if [ -f "$work/calls" ]; then fail "invalid attribution must fail before API access"; else pass; fi

cat >"$work/wrong-project-prs.json" <<EOF
[{"projectId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","issueIdentifier":"ENG-11","url":"https://github.com/acme/widgets/pull/11","merged":true}]
EOF
cat >"$work/unknown-issue-prs.json" <<EOF
[{"projectId":"$project_id","issueIdentifier":"ENG-99","url":"https://github.com/acme/widgets/pull/11","merged":true}]
EOF
cat >"$work/duplicate-prs.json" <<EOF
[{"projectId":"$project_id","issueIdentifier":"ENG-11","url":"https://github.com/acme/widgets/pull/11","merged":true},{"projectId":"$project_id","issueIdentifier":"ENG-11","url":"https://github.com/acme/widgets/pull/11","merged":true}]
EOF
printf '%s\n' '[]' >"$work/missing-prs.json"
for pair_case in wrong-project unknown-issue duplicate missing; do
  reset_fake; queue project-list project-list-in-review.json 1; queue issue-list issue-list-evidence.json 1
  run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/$pair_case-prs.json" "${review_expect[@]}"
  assert_exit 1 "$RC" "$pair_case Linear attribution pair is rejected"
  assert_contains "$OUTPUT" "missing, duplicate, or foreign" "$pair_case attribution has a safe join diagnostic"
  assert_not_contains "$(cat "$work/calls")" $'mutation\t' "$pair_case attribution performs no mutation"
done

printf '%s\n' "[{\"projectId\":\"$project_id\",\"issueIdentifier\":\"ENG-11\",\"url\":\"https://github.com/acme/widgets/pull/11\",\"merged\":false}]" >"$work/unmerged-prs.json"
reset_fake; queue project-list project-list-done.json 1; queue issue-list issue-list-evidence-done.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/unmerged-prs.json" "${done_expect[@]}"
assert_exit 1 "$RC" "pre-existing done issue requires merged PR evidence"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "unmerged done evidence performs zero mutation"

done_executing_snapshot='{"projectStatus":"done","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"executing"}]}'
reset_fake; queue project-list project-list-done.json 1; queue issue-list issue-list-executing.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/missing-prs.json" \
  --expected-eligible '[]' --expected-project-transition false --expected-snapshot "$done_executing_snapshot"
assert_exit 1 "$RC" "done project with non-done issue is inconsistent"
assert_contains "$OUTPUT" "terminal states are inconsistent" "done/non-done inconsistency is explicit"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "done/non-done inconsistency performs zero mutation"


wrong_eligible='["dddddddd-0001-4000-8000-000000000001"]'
reset_fake; queue project-list project-list-in-review.json 1; queue issue-list issue-list-evidence.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" \
  --expected-eligible "$wrong_eligible" --expected-project-transition true --expected-snapshot "$review_snapshot"
assert_exit 1 "$RC" "same-count wrong eligible issue identity fails closed"
assert_contains "$OUTPUT" "eligible issue set drifted" "wrong eligible identity reports preview drift"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "wrong eligible identity performs zero mutation"

reset_fake; queue project-list project-list-in-review.json 1; queue issue-list issue-list-executing.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/missing-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "concurrent issue state drift fails before mutation"
assert_contains "$OUTPUT" "snapshot drifted" "concurrent drift reports snapshot mismatch"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "concurrent snapshot drift performs zero mutation"

jq --arg executing "$(jq -r '.executing' <<<"$issue_state_map")" '
  .data.issues.nodes += [(.data.issues.nodes[0] |
    .id="cccccccc-0002-4000-8000-000000000002" |
    .identifier="ENG-12" |
    .url="https://linear.app/acme/issue/ENG-12" |
    .state.id=$executing |
    .description |= (
      gsub("feature/eng-11";"feature/eng-12") |
      gsub("track-a";"track-b") |
      gsub("\"ordinal\":1";"\"ordinal\":2") |
      gsub("/pull/11";"/pull/12")
    )
  )]
' "$FIXTURES/issue-list-evidence.json" >"$work/status-two-before.json"
jq --arg done "$(jq -r '.done' <<<"$issue_state_map")" --arg blocked "$(jq -r '.blocked' <<<"$issue_state_map")" '
  .data.issues.nodes[0].state.id=$done |
  .data.issues.nodes[1].state.id=$blocked
' "$work/status-two-before.json" >"$work/status-two-after-drift.json"
two_snapshot='{"projectStatus":"inReview","issues":[{"id":"cccccccc-0001-4000-8000-000000000001","status":"inReview"},{"id":"cccccccc-0002-4000-8000-000000000002","status":"executing"}]}'
reset_fake
queue project-list project-list-in-review.json 1
cp "$work/status-two-before.json" "$work/responses/issue-list.1.json"
queue issue-update issue-update-success.json 1
cp "$work/status-two-after-drift.json" "$work/responses/issue-list.2.json"
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" \
  --expected-eligible "$review_eligible" --expected-project-transition false --expected-snapshot "$two_snapshot"
assert_exit 1 "$RC" "non-target issue status drift fails read-back"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "non-target-status-verification" "non-target drift remains pending"
assert_not_contains "$(cat "$work/calls")" $'mutation\tproject-update' "non-target drift blocks project mutation"

# Nested relation connections are paginated per issue before normalization.
jq '.data.issues.nodes[2].inverseRelations.pageInfo={hasNextPage:true,endCursor:"more"}' "$FIXTURES/issue-list-valid.json" >"$work/issue-list-nested-partial.json"
jq -n --arg project "$project_id" '{
  data:{issue:{
    id:"cccccccc-0003-4000-8000-000000000003",project:{id:$project},
    relations:{nodes:[],pageInfo:{hasNextPage:false,endCursor:null}},
    inverseRelations:{nodes:[],pageInfo:{hasNextPage:false,endCursor:null}}
  }}
}' >"$work/issue-relations-final.json"
reset_fake
cp "$work/issue-list-nested-partial.json" "$work/responses/issue-list.1.json"
cp "$work/issue-relations-final.json" "$work/responses/issue-relations.1.json"
run_capture plan-read --project "$project_id" --repository acme/widgets --issue-state-map "$issue_state_map"
assert_exit 0 "$RC" "partial nested relation connection is completed"
assert_contains "$(cat "$work/calls")" $'query\tissue-relations\t' "nested relation pagination issues a follow-up query"
assert_eq "$(jq -r '.inverseRelationsAfter' <<<"$(call_variables issue-relations 1)")" "more" "nested relation pagination uses the returned cursor"

# Canonical UUID ordering makes a valid multi-dependency plan converge regardless
# of the plan's stable-ID dependency order.
track_b_description="$(make_increment_description "Second root." track-b 2 '["cccccccc-0001-4000-8000-000000000001"]' "cccccccc-0001-4000-8000-000000000001")"
dependent_description="$(make_increment_description "Depends on the first root." dependent 3 '["cccccccc-0001-4000-8000-000000000001","cccccccc-0002-4000-8000-000000000002"]' "cccccccc-0002-4000-8000-000000000002")"
jq --arg trackB "$track_b_description" --arg dependent "$dependent_description" '
  .data.issues.nodes[0].description=$trackB |
  .data.issues.nodes[0].inverseRelations.nodes=[{
    id:"eeeeeeee-0002-4000-8000-000000000002",type:"blocks",
    issue:{id:"cccccccc-0001-4000-8000-000000000001",project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}
  }] |
  .data.issues.nodes[2].description=$dependent |
  .data.issues.nodes[2].inverseRelations.nodes += [{
    id:"eeeeeeee-0003-4000-8000-000000000003",type:"blocks",
    issue:{id:"cccccccc-0002-4000-8000-000000000002",project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}
  }]
' "$FIXTURES/issue-list-valid.json" >"$work/issue-list-multi-dependency.json"
cat >"$work/multi-dependency-plan.json" <<'EOF'
{"increments":[
  {"incrementId":"track-a","title":"First root","ordinal":1,"dependencies":[],"gitParent":"main","content":"First root."},
  {"incrementId":"track-b","title":"Independent track","ordinal":2,"dependencies":["track-a"],"gitParent":"track-a","content":"Second root."},
  {"incrementId":"dependent","title":"Dependent","ordinal":3,"dependencies":["track-b","track-a"],"gitParent":"track-b","content":"Depends on the first root."}
]}
EOF
reset_fake
queue project-list project-list-one.json 1
for count in 1 2 3; do cp "$work/issue-list-multi-dependency.json" "$work/responses/issue-list.$count.json"; done
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/multi-dependency-plan.json"
assert_exit 0 "$RC" "multi-dependency reconciliation canonicalizes UUID order"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "dependency order alone performs no mutation"
assert_eq "$(jq -r '.verified' <<<"$OUTPUT")" "true" "canonical dependency order verifies final state"

# A converged second reconciliation diffs owned fields, performs no mutation,
# and leaves an unrelated unmanaged↔unmanaged native relation untouched.
jq '.data.issues.nodes += [
  {id:"dddddddd-0001-4000-8000-000000000001",identifier:"ENG-90",title:"Unmanaged one",description:"human",url:"https://linear.app/acme/issue/ENG-90",updatedAt:"2026-07-12T12:00:00Z",canceledAt:null,archivedAt:null,project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"},state:{id:"20000000-0000-4000-8000-000000000001"},relations:{nodes:[{id:"eeeeeeee-0090-4000-8000-000000000090",type:"blocks",relatedIssue:{id:"dddddddd-0002-4000-8000-000000000002",project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}}]},inverseRelations:{nodes:[]}},
  {id:"dddddddd-0002-4000-8000-000000000002",identifier:"ENG-91",title:"Unmanaged two",description:"human",url:"https://linear.app/acme/issue/ENG-91",updatedAt:"2026-07-12T12:00:00Z",canceledAt:null,archivedAt:null,project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"},state:{id:"20000000-0000-4000-8000-000000000001"},relations:{nodes:[]},inverseRelations:{nodes:[]}}
]' "$FIXTURES/issue-list-reconcile-final.json" >"$work/issue-list-converged-unrelated.json"
reset_fake; queue project-list project-list-one.json 1
for count in 1 2 3; do cp "$work/issue-list-converged-unrelated.json" "$work/responses/issue-list.$count.json"; done
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/reconcile-plan.json"
assert_exit 0 "$RC" "identical second reconciliation is verified"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "identical plan and unrelated relation produce zero mutations"
assert_eq "$(jq -r '.attempted|length' <<<"$OUTPUT")" "0" "no-op receipt has no intended mutations"
assert_eq "$(jq -r '.completed|length' <<<"$OUTPUT")" "0" "no-op receipt has no claimed completions"
assert_eq "$(jq -r '.pending|length' <<<"$OUTPUT")" "0" "no-op receipt has no pending operations"
# A relation with exactly one managed endpoint is ambiguous ownership. Initial
# discovery fails closed before a desired title update or removal can mutate
# either issues or relations.
jq '.data.issues.nodes += [
  {id:"dddddddd-0001-4000-8000-000000000001",identifier:"ENG-90",title:"Unmanaged",description:"human",url:"https://linear.app/acme/issue/ENG-90",updatedAt:"2026-07-12T12:00:00Z",canceledAt:null,archivedAt:null,project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"},state:{id:"20000000-0000-4000-8000-000000000001"},relations:{nodes:[{id:"eeeeeeee-0091-4000-8000-000000000091",type:"blocks",relatedIssue:{id:"cccccccc-0001-4000-8000-000000000001",project:{id:"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}}]},inverseRelations:{nodes:[]}}
]' "$FIXTURES/issue-list-reconcile-final.json" >"$work/issue-list-partial-managed-relation.json"
jq '.increments[0].title="Changed before ownership check" | .increments=[.increments[0]]' "$work/reconcile-plan.json" >"$work/ownership-unsafe-plan.json"
reset_fake; queue project-list project-list-one.json 1
cp "$work/issue-list-partial-managed-relation.json" "$work/responses/issue-list.1.json"
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/ownership-unsafe-plan.json"
assert_exit 1 "$RC" "initial partial managed relation ownership fails closed"
assert_contains "$OUTPUT" "one managed endpoint" "partial managed relation has an ownership diagnostic"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "ownership ambiguity blocks issue update, removal, and relation writes"


# A failed owned-field update is not promoted to completed by an aggregate
# final check; the precise update and final-plan readbacks remain pending.
cat >"$work/failing-plan.json" <<'EOF'
{"increments":[
  {"incrementId":"keep-a","title":"Changed but unobserved","ordinal":1,"dependencies":[],"gitParent":"main","content":"Changed but unobserved."},
  {"incrementId":"new-c","title":"New C","ordinal":2,"dependencies":["keep-a"],"gitParent":"keep-a","content":"New C."}
]}
EOF
reset_fake; queue project-list project-list-one.json 1
queue issue-list issue-list-reconcile-final.json 1
queue issue-update issue-update-success.json 1; touch "$work/responses/issue-update.1.fail"
queue issue-list issue-list-reconcile-final.json 2
queue issue-list issue-list-reconcile-final.json 3
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/failing-plan.json"
assert_exit 1 "$RC" "unobserved issue update fails reconciliation"
assert_eq "$(jq -r '.completed|length' <<<"$OUTPUT")" "0" "failed update is never reported completed"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "issueUpdate-read-back" "failed update has per-operation pending truth"
assert_contains "$(jq -r '.pending|join(",")' <<<"$OUTPUT")" "final-plan-verification" "failed update retains final verification truth"

# Every mutating issue/status command gates on the canonical managed parent.
reset_fake; queue project-list project-list-foreign.json 1
run_capture plan-reconcile --project "$project_id" --repository acme/widgets --team-id "$team_id" --issue-state-map "$issue_state_map" --plan-file "$work/new-root-plan.json"
assert_exit 1 "$RC" "foreign parent blocks plan reconciliation"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "foreign parent plan performs zero mutation"
reset_fake; queue project-list project-list-foreign.json 1
run_capture issue-transition --project "$project_id" --repository acme/widgets --issue ENG-11 --issue-state-map "$issue_state_map" --target executing
assert_exit 1 "$RC" "foreign parent blocks issue transition"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "foreign parent issue transition performs zero mutation"
reset_fake; queue project-list project-list-foreign.json 1
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "foreign parent blocks status reconciliation"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "foreign parent status performs zero mutation"

# PR URLs must join exactly to the configured repository and positive pull
# number; foreign repositories and trailing junk fail before API access.
for bad_pr in 'https://github.com/other/widgets/pull/11' 'https://github.com/acme/widgets/pull/11/files'; do
  reset_fake
  run_capture issue-transition --project "$project_id" --repository acme/widgets --issue ENG-11 --issue-state-map "$issue_state_map" --target inReview --branch feature/eng-11 --pull-request "$bad_pr"
  assert_exit 1 "$RC" "foreign or trailing PR URL is rejected at evidence write"
  if [ -f "$work/calls" ]; then fail "invalid PR URL must fail before API access"; else pass; fi
done
printf '%s\n' '[{"projectId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","issueIdentifier":"ENG-11","url":"https://github.com/other/widgets/pull/11","merged":true}]' >"$work/foreign-url-prs.json"
reset_fake
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/foreign-url-prs.json" "${review_expect[@]}"
assert_exit 1 "$RC" "foreign PR URL is rejected before status API access"
if [ -f "$work/calls" ]; then fail "foreign status PR URL must fail before API access"; else pass; fi

# An in-review project with no in-review issue never advances executing work.
reset_fake; queue project-list project-list-in-review.json 1
queue issue-list issue-list-executing.json 1
queue issue-list issue-list-executing.json 2
run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/missing-prs.json" "${executing_expect[@]}"
assert_exit 0 "$RC" "executing issue remains ineligible for done"
assert_not_contains "$(cat "$work/calls")" $'mutation\t' "only inReview issues can transition to done"
assert_eq "$(jq -r '.eligibleIssues|length' <<<"$OUTPUT")" "0" "terminal receipt reports no eligible issue"

# Terminal status semantics: abandoned is immutable and pre-inReview projects
# are premature; both stop after the ownership read and perform no mutation.
for project_case in abandoned one; do
  reset_fake; queue project-list "project-list-$project_case.json" 1
  run_capture status-reconcile --project "$project_id" --repository acme/widgets --status-map "$status_map" --issue-state-map "$issue_state_map" --pull-requests-file "$work/merged-prs.json" "${review_expect[@]}"
  assert_exit 1 "$RC" "$project_case project is not terminal-reconcile eligible"
  assert_not_contains "$(cat "$work/calls")" $'mutation\t' "$project_case project performs zero mutation"
done

finish
