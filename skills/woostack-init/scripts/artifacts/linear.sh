#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPHQL="$HERE/graphql"
REQUEST="${LINEAR_REQUEST_SH:-$HERE/linear-request.sh}"
METADATA="$HERE/linear-metadata.py"
UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
REQUIRED_STATUSES='["draft","hardened","approved","planning","ready","executing","inReview","done","abandoned"]'
ACTIVE_STATUSES='["draft","hardened","approved","planning","ready","executing","inReview"]'

fail() { printf 'linear resources: %s\n' "$1" >&2; exit 1; }
usage() {
  cat >&2 <<'USAGE'
usage: linear.sh <command> [options]
commands:
  preflight --workspace NAME --team KEY --project-statuses JSON --issue-states JSON
  feature-resolve --repository OWNER/REPO --status-map JSON --eligible-statuses JSON [--reference UUID|LINEAR_URL]
  feature-create --repository OWNER/REPO --title TITLE --team-id UUID --status-map JSON --spec-file PATH
  feature-transition --project UUID --repository OWNER/REPO --status-map JSON --target STATUS
  spec-read --project UUID --repository OWNER/REPO
  spec-write --project UUID --repository OWNER/REPO --content-file PATH --expected-revision JSON
USAGE
  exit 2
}

require_uuid() { [[ "$1" =~ $UUID_RE ]] || fail "$2 is not a UUID"; }
require_repository() {
  [[ "$1" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || fail "repository identity is invalid"
}
validate_status_map() {
  local value="$1"
  jq -e --argjson required "$REQUIRED_STATUSES" '
    type == "object" and
    ((keys | sort) == ($required | sort)) and
    ([.[]] | length == (unique | length)) and
    all(.[]; type == "string" and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"))
  ' >/dev/null 2>&1 <<<"$value" || fail "project status map is incomplete or invalid"
}
project_marker() {
  jq -cnS --arg repository "$1" '{repository:$repository,schema:1}' |
    { printf '%s\n' '+++ Woostack project metadata — managed, do not edit'; cat; printf '%s\n' '+++'; }
}

request_query() { "$REQUEST" --operation query --document "$1" --variables "$2"; }
request_mutation() { "$REQUEST" --operation mutation --document "$1" --variables "$2"; }

project_list() {
  local after='' next='' response nodes='[]' page after_json seen='[]'
  while :; do
    after_json=null; [[ -z "$after" ]] || after_json="$(jq -Rn --arg value "$after" '$value')"
    response="$(request_query "$GRAPHQL/project-list.graphql" "$(jq -cn --argjson after "$after_json" '{after:$after}')")" || return 1
    jq -e 'type=="object" and (.data.projects.nodes|type=="array") and (.data.projects.pageInfo.hasNextPage|type=="boolean")' >/dev/null 2>&1 <<<"$response" || fail "project list response is invalid"
    page="$(jq -c '.data.projects.nodes' <<<"$response")"
    nodes="$(jq -cn --argjson left "$nodes" --argjson right "$page" '$left+$right')"
    [[ "$(jq -r '.data.projects.pageInfo.hasNextPage' <<<"$response")" == true ]] || break
    next="$(jq -r '.data.projects.pageInfo.endCursor // empty' <<<"$response")"
    [[ -n "$next" ]] || fail "project list pagination cursor is missing"
    jq -e --arg cursor "$next" 'index($cursor)==null' >/dev/null <<<"$seen" || fail "project list pagination cursor repeated"
    seen="$(jq -c --arg cursor "$next" '.+[$cursor]' <<<"$seen")"
    after="$next"
  done
  jq -cn --argjson nodes "$nodes" '{nodes:$nodes}'
}

document_list() {
  local project_id="$1" after='' next='' response nodes='[]' page after_json seen='[]'
  while :; do
    after_json=null; [[ -z "$after" ]] || after_json="$(jq -Rn --arg value "$after" '$value')"
    response="$(request_query "$GRAPHQL/document-list.graphql" "$(jq -cn --arg projectId "$project_id" --argjson after "$after_json" '{projectId:$projectId,after:$after}')")" || return 1
    jq -e --arg id "$project_id" 'type=="object" and (.data.documents.nodes|type=="array") and (.data.documents.pageInfo.hasNextPage|type=="boolean") and all(.data.documents.nodes[]; .project.id==$id)' >/dev/null 2>&1 <<<"$response" || fail "document list response is invalid"
    page="$(jq -c '.data.documents.nodes' <<<"$response")"
    nodes="$(jq -cn --argjson left "$nodes" --argjson right "$page" '$left+$right')"
    [[ "$(jq -r '.data.documents.pageInfo.hasNextPage' <<<"$response")" == true ]] || break
    next="$(jq -r '.data.documents.pageInfo.endCursor // empty' <<<"$response")"
    [[ -n "$next" ]] || fail "document list pagination cursor is missing"
    jq -e --arg cursor "$next" 'index($cursor)==null' >/dev/null <<<"$seen" || fail "document list pagination cursor repeated"
    seen="$(jq -c --arg cursor "$next" '.+[$cursor]' <<<"$seen")"
    after="$next"
  done
  jq -cn --argjson nodes "$nodes" '{nodes:$nodes}'
}

managed_projects() {
  local projects="$1" repository="$2" status_map="$3" eligible="$4" marker
  marker="$(project_marker "$repository")"
  jq -c --arg marker "$marker" --argjson statuses "$status_map" --argjson eligible "$eligible" '
    [.nodes[] |
      select(.archivedAt == null) |
      . as $project |
      ($statuses | to_entries[] | select(.value == $project.status.id) | .key) as $semantic |
      select(any($eligible[]; . == $semantic)) |
      select(.description == $marker) |
      {id,name,url,status:$semantic,statusId:.status.id,updatedAt}
    ] | sort_by(.id)
  ' <<<"$projects"
}

resolve_from_list() {
  local projects="$1" repository="$2" status_map="$3" eligible="$4" reference="${5:-}" candidates count wanted raw marker
  marker="$(project_marker "$repository")"
  if [[ -n "$reference" ]]; then
    if [[ "$reference" =~ $UUID_RE ]]; then
      wanted="$(printf '%s' "$reference" | tr '[:upper:]' '[:lower:]')"
      raw="$(jq -c --arg id "$wanted" '[.nodes[] | select((.id|ascii_downcase)==$id)]' <<<"$projects")"
    elif [[ "$reference" == https://linear.app/* ]]; then
      raw="$(jq -c --arg url "$reference" '[.nodes[] | select(.url==$url)]' <<<"$projects")"
      wanted="$(jq -r 'if length==1 then (.[0].id|ascii_downcase) else "" end' <<<"$raw")"
    else
      fail "feature reference must be an explicit UUID or exact Linear URL"
    fi
    count="$(jq 'length' <<<"$raw")"
    [[ "$count" -eq 1 ]] || { printf 'linear resources: feature not found\n' >&2; return 3; }
    jq -e --arg marker "$marker" '.[] | .archivedAt==null and .description==$marker' >/dev/null 2>&1 <<<"$raw" || fail "project ownership or schema marker mismatch"
    candidates="$(managed_projects "$projects" "$repository" "$status_map" "$eligible")"
    jq -e --arg id "$wanted" 'any(.[]; (.id|ascii_downcase)==$id)' >/dev/null 2>&1 <<<"$candidates" || fail "project is not in an eligible lifecycle status"
    jq -c --arg id "$wanted" '.[] | select((.id|ascii_downcase)==$id)' <<<"$candidates"
    return
  fi
  candidates="$(managed_projects "$projects" "$repository" "$status_map" "$eligible")"
  count="$(jq 'length' <<<"$candidates")"
  case "$count" in
    0) printf 'linear resources: feature not found\n' >&2; return 3 ;;
    1) jq -c '.[0]' <<<"$candidates" ;;
    *)
      jq -r '.[] | "candidate id=\(.id) title=\(.name|@json) status=\(.status) url=\(.url)"' <<<"$candidates" >&2
      return 4
      ;;
  esac
}

find_spec() {
  local project_id="$1" repository="$2" documents="$3" tmp matches='[]' parsed doc
  tmp="$(mktemp)"
  while IFS= read -r doc; do
    jq -j '.content' <<<"$doc" >"$tmp"
    if grep -qF '+++ Woostack metadata — managed, do not edit' "$tmp"; then
      if ! parsed="$(python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" <"$tmp" 2>/dev/null)"; then
        rm -f "$tmp"
        fail "managed spec metadata is invalid or has foreign ownership"
      fi
      [[ "$(jq -r '.artifactType' <<<"$parsed")" == spec ]] || { rm -f "$tmp"; fail "managed spec metadata has the wrong artifact type"; }
      matches="$(jq -cn --argjson old "$matches" --argjson doc "$doc" '$old+[$doc]')"
    fi
  done < <(jq -c '.nodes[]' <<<"$documents")
  rm -f "$tmp"
  case "$(jq 'length' <<<"$matches")" in
    0) return 3 ;;
    1) jq -c '.[0]' <<<"$matches" ;;
    *) fail "multiple managed spec documents found" ;;
  esac
}

spec_result() {
  local doc="$1" tmp revision
  tmp="$(mktemp)"; jq -j '.content' <<<"$doc" >"$tmp"
  revision="$(python3 "$METADATA" revision --updated-at "$(jq -r '.updatedAt' <<<"$doc")" <"$tmp")" || { rm -f "$tmp"; fail "spec revision could not be computed"; }
  rm -f "$tmp"
  jq -cn --argjson doc "$doc" --argjson revision "$revision" '{id:$doc.id,url:$doc.url,content:$doc.content,revision:$revision}'
}

prepare_spec() {
  local source="$1" project_id="$2" repository="$3" output="$4" parsed
  [[ -f "$source" && -r "$source" ]] || fail "spec content file is unreadable"
  if grep -qF '+++ Woostack metadata — managed, do not edit' "$source"; then
    parsed="$(python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" <"$source")" || fail "spec metadata is invalid"
    [[ "$(jq -r '.artifactType' <<<"$parsed")" == spec ]] || fail "spec metadata has the wrong artifact type"
    cat "$source" >"$output"
  else
    cat "$source" >"$output"
    [[ ! -s "$output" ]] || [[ "$(tail -c 1 "$output" | wc -l | tr -d ' ')" == 1 ]] || printf '\n' >>"$output"
    {
      printf '\n%s\n' '+++ Woostack metadata — managed, do not edit'
      jq -cnS --arg projectId "$project_id" --arg repository "$repository" '{artifactType:"spec",projectId:$projectId,repository:$repository,schema:1}'
      printf '%s\n' '+++'
    } >>"$output"
  fi
}

command_preflight() {
  local workspace='' team='' project_statuses='' issue_states='' response tmp
  while [[ $# -gt 0 ]]; do case "$1" in
    --workspace) workspace="$2"; shift 2;; --team) team="$2"; shift 2;;
    --project-statuses) project_statuses="$2"; shift 2;; --issue-states) issue_states="$2"; shift 2;; *) usage;; esac; done
  [[ -n "$workspace" && -n "$team" && -n "$project_statuses" && -n "$issue_states" ]] || usage
  jq -e --argjson required "$REQUIRED_STATUSES" '
    type=="object" and ((keys|sort)==($required|sort)) and
    all(.[]; type=="string" and length>0) and
    (([.[]]|unique|length)==([.[]]|length))
  ' >/dev/null 2>&1 <<<"$project_statuses" || fail "all project statuses must be present, nonblank, and unique"
  jq -e '
    type=="object" and ((keys|sort)==(["planned","executing","inReview","done","blocked"]|sort)) and
    all(.[]; type=="string" and length>0) and
    (([.[]]|unique|length)==([.[]]|length))
  ' >/dev/null 2>&1 <<<"$issue_states" || fail "all issue states must be present, nonblank, and unique"
  response="$(request_query "$GRAPHQL/preflight.graphql" '{}')" || fail "preflight query failed"
  tmp="$(mktemp)"; printf '%s\n' "$response" >"$tmp"
  "$HERE/linear-preflight.sh" --response "$tmp" --workspace "$workspace" --team "$team" --project-statuses "$project_statuses" --issue-states "$issue_states"
  rm -f "$tmp"
}

command_feature_resolve() {
  local repository='' status_map='' eligible='' reference='' projects
  while [[ $# -gt 0 ]]; do case "$1" in
    --repository) repository="$2"; shift 2;; --status-map) status_map="$2"; shift 2;;
    --eligible-statuses) eligible="$2"; shift 2;; --reference) reference="$2"; shift 2;; *) usage;; esac; done
  require_repository "$repository"; validate_status_map "$status_map"
  jq -e --argjson map "$status_map" 'type=="array" and length>0 and all(.[]; type=="string" and $map[.]!=null)' >/dev/null 2>&1 <<<"$eligible" || fail "eligible statuses are invalid"
  projects="$(project_list)" || fail "project discovery failed"
  resolve_from_list "$projects" "$repository" "$status_map" "$eligible" "$reference"
}

command_feature_create() {
  local repository='' title='' team_id='' status_map='' spec_file='' projects project='' project_attempted=false returned_project=null
  local documents doc='' document_attempted=false returned_document=null expected_file observed_file variables response attempted observed pending='[]' verified
  while [[ $# -gt 0 ]]; do case "$1" in
    --repository) repository="$2"; shift 2;; --title) title="$2"; shift 2;; --team-id) team_id="$2"; shift 2;;
    --status-map) status_map="$2"; shift 2;; --spec-file) spec_file="$2"; shift 2;; *) usage;; esac; done
  require_repository "$repository"; [[ -n "$title" ]] || usage; require_uuid "$team_id" "team id"; validate_status_map "$status_map"; [[ -r "$spec_file" ]] || fail "spec file is unreadable"
  projects="$(project_list)" || fail "project discovery failed"
  set +e; project="$(resolve_from_list "$projects" "$repository" "$status_map" "$ACTIVE_STATUSES" '' 2>/dev/null)"; resolve_rc=$?; set -e
  case "$resolve_rc" in
    0) ;;
    3)
      variables="$(jq -cn --arg name "$title" --arg team "$team_id" --arg status "$(jq -r '.draft' <<<"$status_map")" --arg description "$(project_marker "$repository")" '{input:{name:$name,teamIds:[$team],statusId:$status,description:$description}}')"
      project_attempted=true
      if response="$(request_mutation "$GRAPHQL/project-create.graphql" "$variables")"; then
        if jq -e '.data.projectCreate.success==true and (.data.projectCreate.project.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
          returned_project="$(jq -c '.data.projectCreate.project | {id,name,url,status}' <<<"$response")"
        fi
      fi
      if ! projects="$(project_list)"; then
        jq -cn --argjson returned "$returned_project" '{attempted:["projectCreate"],observed:{project:null,document:null},returned:{project:$returned,document:null},verified:false,pending:["project-read-back"]}'
        return 1
      fi
      set +e; project="$(resolve_from_list "$projects" "$repository" "$status_map" "$ACTIVE_STATUSES" '')"; resolve_rc=$?; set -e
      if [[ "$resolve_rc" -ne 0 ]]; then
        jq -cn --argjson returned "$returned_project" '{attempted:["projectCreate"],observed:{project:null,document:null},returned:{project:$returned,document:null},verified:false,pending:["project-discovery"]}'
        return 1
      fi
      ;;
    4) return 4;; *) return "$resolve_rc";;
  esac
  project_id="$(jq -r '.id' <<<"$project")"
  expected_file="$(mktemp)"; prepare_spec "$spec_file" "$project_id" "$repository" "$expected_file"
  documents="$(document_list "$project_id")" || { rm -f "$expected_file"; fail "spec discovery failed"; }
  set +e; doc="$(find_spec "$project_id" "$repository" "$documents")"; doc_rc=$?; set -e
  case "$doc_rc" in
    0) ;;
    3)
      variables="$(jq -cn --arg title "$title — Spec" --arg projectId "$project_id" --rawfile content "$expected_file" '{input:{title:$title,projectId:$projectId,content:$content}}')"
      document_attempted=true
      if response="$(request_mutation "$GRAPHQL/document-create.graphql" "$variables")"; then
        if jq -e '.data.documentCreate.success==true and (.data.documentCreate.document.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
          returned_document="$(jq -c '.data.documentCreate.document | {id,title,url,updatedAt,project}' <<<"$response")"
        fi
      fi
      if ! documents="$(document_list "$project_id")"; then
        rm -f "$expected_file"
        jq -cn --arg project "$project_id" --argjson returned "$returned_document" '{attempted:["documentCreate"],observed:{project:$project,document:null},returned:{project:null,document:$returned},verified:false,pending:["document-read-back"]}'
        return 1
      fi
      set +e; doc="$(find_spec "$project_id" "$repository" "$documents")"; doc_rc=$?; set -e
      [[ "$doc_rc" -eq 0 ]] || pending="$(jq -c '.+["document-discovery"]' <<<"$pending")"
      ;;
    *) rm -f "$expected_file"; return "$doc_rc";;
  esac
  attempted='[]'; [[ "$project_attempted" == true ]] && attempted="$(jq -c '.+["projectCreate"]' <<<"$attempted")"; [[ "$document_attempted" == true ]] && attempted="$(jq -c '.+["documentCreate"]' <<<"$attempted")"
  observed="$(jq -cn --arg project "$project_id" --arg document "${doc:+$(jq -r '.id' <<<"$doc")}" '{project:$project,document:(if $document=="" then null else $document end)}')"
  if [[ -n "$doc" ]]; then
    observed_file="$(mktemp)"; jq -j '.content' <<<"$doc" >"$observed_file"
    cmp -s "$expected_file" "$observed_file" || pending="$(jq -c '.+["document-content-verification"]' <<<"$pending")"
    rm -f "$observed_file"
  fi
  rm -f "$expected_file"
  if [[ "$returned_project" != null ]]; then
    if [[ "$(jq -r '.id' <<<"$returned_project")" != "$project_id" ||
          "$(jq -r '.status.id' <<<"$returned_project")" != "$(jq -r '.statusId' <<<"$project")" ]]; then
      pending="$(jq -c '.+["project-return-mismatch"]' <<<"$pending")"
    fi
  fi
  if [[ "$returned_document" != null ]]; then
    if [[ "$(jq -r '.id' <<<"$returned_document")" != "$(jq -r '.document' <<<"$observed")" ||
          "$(jq -r '.project.id' <<<"$returned_document")" != "$project_id" ]]; then
      pending="$(jq -c '.+["document-return-mismatch"]' <<<"$pending")"
    fi
  fi
  verified=false; [[ "$(jq 'length' <<<"$pending")" -eq 0 ]] && verified=true
  jq -cn --argjson attempted "$attempted" --argjson observed "$observed" --argjson rp "$returned_project" --argjson rd "$returned_document" --argjson verified "$verified" --argjson pending "$pending" '{attempted:$attempted,observed:$observed,returned:{project:$rp,document:$rd},verified:$verified,pending:$pending}'
  [[ "$verified" == true ]]
}

command_spec_read() {
  local project_id='' repository='' documents doc
  while [[ $# -gt 0 ]]; do case "$1" in --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"
  documents="$(document_list "$project_id")" || fail "spec discovery failed"
  doc="$(find_spec "$project_id" "$repository" "$documents")" || fail "managed spec document not found"
  spec_result "$doc"
}

command_spec_write() {
  local project_id='' repository='' content_file='' expected='' documents doc current expected_file response returned=null readback='' observed_file verified=false pending='[]'
  while [[ $# -gt 0 ]]; do case "$1" in --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --content-file) content_file="$2"; shift 2;; --expected-revision) expected="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; [[ -r "$content_file" && -n "$expected" ]] || usage
  documents="$(document_list "$project_id")" || fail "spec discovery failed"
  doc="$(find_spec "$project_id" "$repository" "$documents")" || fail "managed spec document not found"
  current="$(spec_result "$doc")"
  [[ "$(jq -c '.revision' <<<"$current")" == "$(jq -cS . <<<"$expected" 2>/dev/null)" ]] || fail "optimistic revision mismatch"
  expected_file="$(mktemp)"; prepare_spec "$content_file" "$project_id" "$repository" "$expected_file"
  if response="$(request_mutation "$GRAPHQL/document-update.graphql" "$(jq -cn --arg id "$(jq -r '.id' <<<"$doc")" --rawfile content "$expected_file" '{id:$id,input:{content:$content}}')")"; then
    if jq -e '.data.documentUpdate.success==true and (.data.documentUpdate.document.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
      returned="$(jq -c '.data.documentUpdate.document | {id,title,url,updatedAt,project}' <<<"$response")"
    fi
  fi
  if ! documents="$(document_list "$project_id")"; then
    rm -f "$expected_file"
    jq -cn --argjson returned "$returned" '{attempted:["documentUpdate"],observed:{document:null},returned:{document:$returned},verified:false,pending:["document-read-back"]}'
    return 1
  fi
  set +e; readback="$(find_spec "$project_id" "$repository" "$documents")"; readback_rc=$?; set -e
  if [[ "$readback_rc" -ne 0 ]]; then
    pending='["document-discovery"]'
  else
    observed_file="$(mktemp)"; jq -j '.content' <<<"$readback" >"$observed_file"
    cmp -s "$expected_file" "$observed_file" || pending="$(jq -c '.+["document-content-verification"]' <<<"$pending")"
    rm -f "$observed_file"
    [[ "$(jq -r '.id' <<<"$readback")" == "$(jq -r '.id' <<<"$doc")" ]] || pending="$(jq -c '.+["document-identity-verification"]' <<<"$pending")"
    if [[ "$returned" != null && "$(jq -r '.id' <<<"$returned")" != "$(jq -r '.id' <<<"$readback")" ]]; then pending="$(jq -c '.+["document-return-mismatch"]' <<<"$pending")"; fi
  fi
  rm -f "$expected_file"
  [[ "$(jq 'length' <<<"$pending")" -eq 0 ]] && verified=true
  jq -cn --arg id "${readback:+$(jq -r '.id' <<<"$readback")}" --argjson returned "$returned" --argjson verified "$verified" --argjson pending "$pending" \
    '{attempted:["documentUpdate"],observed:{document:(if $id=="" then null else $id end)},returned:{document:$returned},verified:$verified,pending:$pending}'
  [[ "$verified" == true ]]
}

command_feature_transition() {
  local project_id='' repository='' status_map='' target='' projects current current_name current_index target_index response returned readback verified
  while [[ $# -gt 0 ]]; do case "$1" in --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --status-map) status_map="$2"; shift 2;; --target) target="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; validate_status_map "$status_map"
  jq -e --arg target "$target" 'has($target)' >/dev/null 2>&1 <<<"$status_map" || fail "archive, delete, or unknown lifecycle transitions are prohibited"
  projects="$(project_list)" || fail "project discovery failed"; current="$(resolve_from_list "$projects" "$repository" "$status_map" "$REQUIRED_STATUSES" "$project_id")" || return $?
  current_name="$(jq -r '.status' <<<"$current")"
  if [[ "$current_name" == "$target" ]]; then jq -cn --arg current "$current_name" --arg target "$target" --arg id "$project_id" '{current:$current,target:$target,attempted:[],observed:{project:$id},returned:{project:null},verified:true,pending:[]}'; return; fi
  if [[ "$target" != abandoned ]]; then
    [[ "$current_name" != abandoned && "$current_name" != "done" ]] || fail "terminal project cannot transition"
    current_index="$(jq -n --arg current "$current_name" '$ARGS.positional|index($current)' --args draft hardened approved planning ready executing inReview "done")"
    target_index="$(jq -n --arg target "$target" '$ARGS.positional|index($target)' --args draft hardened approved planning ready executing inReview "done")"
    [[ "$current_index" != null && "$target_index" != null && "$target_index" -eq $((current_index + 1)) ]] || fail "invalid project lifecycle transition"
  else
    [[ "$current_name" != "done" ]] || fail "completed project cannot be abandoned"
  fi
  returned=null
  if response="$(request_mutation "$GRAPHQL/project-update.graphql" "$(jq -cn --arg id "$project_id" --arg statusId "$(jq -r --arg target "$target" '.[$target]' <<<"$status_map")" '{id:$id,input:{statusId:$statusId}}')")"; then
    if jq -e '.data.projectUpdate.success==true and (.data.projectUpdate.project.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
      returned="$(jq -c '.data.projectUpdate.project | {id,name,url,status}' <<<"$response")"
    fi
  fi
  if ! projects="$(project_list)"; then
    jq -cn --arg current "$current_name" --arg target "$target" --argjson returned "$returned" '{current:$current,target:$target,attempted:["projectUpdate"],observed:{project:null},returned:{project:$returned},verified:false,pending:["project-read-back"]}'
    return 1
  fi
  set +e; readback="$(resolve_from_list "$projects" "$repository" "$status_map" "$REQUIRED_STATUSES" "$project_id" 2>/dev/null)"; readback_rc=$?; set -e
  verified=false
  if [[ "$readback_rc" -eq 0 && "$(jq -r '.status' <<<"$readback")" == "$target" ]]; then
    verified=true
    if [[ "$returned" != null ]]; then
      [[ "$(jq -r '.id' <<<"$returned")" == "$project_id" ]] || verified=false
      [[ "$(jq -r '.status.id' <<<"$returned")" == "$(jq -r --arg target "$target" '.[$target]' <<<"$status_map")" ]] || verified=false
    fi
  fi
  jq -cn --arg current "$current_name" --arg target "$target" --arg id "${readback:+$(jq -r '.id' <<<"$readback")}" --argjson returned "$returned" --argjson verified "$verified" \
    '{current:$current,target:$target,attempted:["projectUpdate"],observed:{project:(if $id=="" then null else $id end)},returned:{project:$returned},verified:$verified,pending:(if $verified then [] else ["project-status-verification"] end)}'
  [[ "$verified" == true ]]
}

[[ $# -gt 0 ]] || usage
command="$1"; shift
case "$command" in
  preflight) command_preflight "$@";;
  feature-resolve) command_feature_resolve "$@";;
  feature-create) command_feature_create "$@";;
  feature-transition) command_feature_transition "$@";;
  spec-read) command_spec_read "$@";;
  spec-write) command_spec_write "$@";;
  *) usage;;
esac
