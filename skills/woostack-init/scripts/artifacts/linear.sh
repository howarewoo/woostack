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
  identity-resolve --source UUID|LINEAR_URL|linear://project|document|issue/UUID --repository OWNER/REPO --status-map JSON --issue-state-map JSON
  feature-create --repository OWNER/REPO --title TITLE --team-id UUID --status-map JSON --spec-file PATH
  feature-transition --project UUID --repository OWNER/REPO --status-map JSON --target STATUS [--replan --issue-state-map JSON --expected-revision JSON]
  spec-read --project UUID --repository OWNER/REPO
  spec-write --project UUID --repository OWNER/REPO --content-file PATH --expected-revision JSON [--issue-state-map JSON]
  plan-read --project UUID --repository OWNER/REPO --issue-state-map JSON
  plan-reconcile --project UUID --repository OWNER/REPO --team-id UUID --issue-state-map JSON --plan-file PATH
  issue-transition --project UUID --repository OWNER/REPO --issue UUID|TEAM-NUMBER --issue-state-map JSON --target STATUS [--branch NAME] [--pull-request URL]
  feature-read --project UUID --repository OWNER/REPO --status-map JSON --issue-state-map JSON
  doctor-read --repository OWNER/REPO --status-map JSON --issue-state-map JSON
  provenance-parse --reference linear://project|document|issue/UUID
  provenance-resolve --reference linear://project|document|issue/UUID --repository OWNER/REPO --status-map JSON --issue-state-map JSON
  status-reconcile --project UUID --repository OWNER/REPO --status-map JSON --issue-state-map JSON --pull-requests-file PATH --expected-eligible JSON --expected-project-transition BOOLEAN --expected-snapshot JSON
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
owned_project() {
  local project_id="$1" repository="$2" projects marker matches
  projects="$(project_list)" || fail "parent project discovery failed"
  marker="$(project_marker "$repository")"
  matches="$(jq -c --arg id "$project_id" --arg marker "$marker" '[.nodes[] | select(.id==$id and .archivedAt==null and .description==$marker)]' <<<"$projects")"
  [[ "$(jq 'length' <<<"$matches")" -eq 1 ]] || fail "parent project ownership or schema marker mismatch"
  jq -c '.[0]' <<<"$matches"
}

normalize_repository_pr_url() {
  local repository="$1" url="$2"
  python3 "$METADATA" normalize-pr --repository "$repository" <<<"$url" 2>/dev/null ||
    fail "pull request evidence is foreign or invalid"
}

require_repository_pr_url() {
  normalize_repository_pr_url "$1" "$2" >/dev/null
}

content_files_equivalent() {
  python3 "$METADATA" compare --expected-file "$1" --observed-file "$2"
}

content_json_equivalent() {
  local expected="$1" observed="$2" expected_file observed_file result
  expected_file="$(mktemp)"
  observed_file="$(mktemp)"
  jq -j '.content' <<<"$expected" >"$expected_file"
  jq -j '.content' <<<"$observed" >"$observed_file"
  set +e
  content_files_equivalent "$expected_file" "$observed_file"
  result=$?
  set -e
  rm -f "$expected_file" "$observed_file"
  return "$result"
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
    python3 "$METADATA" replace --metadata "$parsed" --repository "$repository" --project-id "$project_id" <"$source" >"$output" || fail "spec metadata could not be normalized"
  else
    cat "$source" >"$output"
    [[ ! -s "$output" ]] || [[ "$(tail -c 1 "$output" | wc -l | tr -d ' ')" == 1 ]] || printf '\n' >>"$output"
    {
      printf '\n%s\n\n' '+++ Woostack metadata — managed, do not edit'
      jq -cnS --arg projectId "$project_id" --arg repository "$repository" '{artifactType:"spec",designState:"draft",projectId:$projectId,repository:$repository,schema:1}'
      printf '\n%s\n' '+++'
    } >>"$output"
  fi
}

validate_issue_state_map() {
  local value="$1"
  jq -e '
    type=="object" and
    ((keys|sort)==(["planned","executing","inReview","done","blocked"]|sort)) and
    ([.[]]|length==(unique|length)) and
    all(.[]; type=="string" and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"))
  ' >/dev/null 2>&1 <<<"$value" || fail "issue state map is incomplete or invalid"
}

complete_issue_relations() {
  local node="$1" project_id="$2" issue_id rel_done inverse_done rel_after='' inverse_after='' rel_seen='[]' inverse_seen='[]'
  local rel_nodes inverse_nodes rel_after_json inverse_after_json response next
  issue_id="$(jq -r '.id' <<<"$node")"
  rel_done="$(jq -r '(.relations.pageInfo.hasNextPage // false) | not' <<<"$node")"
  inverse_done="$(jq -r '(.inverseRelations.pageInfo.hasNextPage // false) | not' <<<"$node")"
  rel_nodes="$(jq -c '.relations.nodes' <<<"$node")"
  inverse_nodes="$(jq -c '.inverseRelations.nodes' <<<"$node")"
  if [[ "$rel_done" != true ]]; then
    rel_after="$(jq -r '.relations.pageInfo.endCursor // empty' <<<"$node")"
    [[ -n "$rel_after" ]] || fail "issue relation pagination cursor is missing"
    rel_seen="$(jq -cn --arg cursor "$rel_after" '[$cursor]')"
  fi
  if [[ "$inverse_done" != true ]]; then
    inverse_after="$(jq -r '.inverseRelations.pageInfo.endCursor // empty' <<<"$node")"
    [[ -n "$inverse_after" ]] || fail "inverse issue relation pagination cursor is missing"
    inverse_seen="$(jq -cn --arg cursor "$inverse_after" '[$cursor]')"
  fi
  while [[ "$rel_done" != true || "$inverse_done" != true ]]; do
    rel_after_json=null; [[ "$rel_done" == true ]] || rel_after_json="$(jq -Rn --arg value "$rel_after" '$value')"
    inverse_after_json=null; [[ "$inverse_done" == true ]] || inverse_after_json="$(jq -Rn --arg value "$inverse_after" '$value')"
    response="$(request_query "$GRAPHQL/issue-relations.graphql" "$(jq -cn --arg issueId "$issue_id" --argjson relationsAfter "$rel_after_json" --argjson inverseRelationsAfter "$inverse_after_json" \
      '{issueId:$issueId,relationsAfter:$relationsAfter,inverseRelationsAfter:$inverseRelationsAfter}')")" || return 1
    jq -e --arg issue "$issue_id" --arg project "$project_id" '
      type=="object" and .data.issue.id==$issue and .data.issue.project.id==$project and
      (.data.issue.relations.nodes|type=="array") and
      (.data.issue.relations.pageInfo.hasNextPage|type=="boolean") and
      (.data.issue.inverseRelations.nodes|type=="array") and
      (.data.issue.inverseRelations.pageInfo.hasNextPage|type=="boolean")
    ' >/dev/null 2>&1 <<<"$response" || fail "issue relation page response is invalid"
    if [[ "$rel_done" != true ]]; then
      rel_nodes="$(jq -cn --argjson left "$rel_nodes" --argjson right "$(jq -c '.data.issue.relations.nodes' <<<"$response")" '$left+$right')"
      if [[ "$(jq -r '.data.issue.relations.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        next="$(jq -r '.data.issue.relations.pageInfo.endCursor // empty' <<<"$response")"
        [[ -n "$next" ]] || fail "issue relation pagination cursor is missing"
        jq -e --arg cursor "$next" 'index($cursor)==null' >/dev/null <<<"$rel_seen" || fail "issue relation pagination cursor repeated"
        rel_seen="$(jq -c --arg cursor "$next" '.+[$cursor]' <<<"$rel_seen")"; rel_after="$next"
      else rel_done=true; fi
    fi
    if [[ "$inverse_done" != true ]]; then
      inverse_nodes="$(jq -cn --argjson left "$inverse_nodes" --argjson right "$(jq -c '.data.issue.inverseRelations.nodes' <<<"$response")" '$left+$right')"
      if [[ "$(jq -r '.data.issue.inverseRelations.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        next="$(jq -r '.data.issue.inverseRelations.pageInfo.endCursor // empty' <<<"$response")"
        [[ -n "$next" ]] || fail "inverse issue relation pagination cursor is missing"
        jq -e --arg cursor "$next" 'index($cursor)==null' >/dev/null <<<"$inverse_seen" || fail "inverse issue relation pagination cursor repeated"
        inverse_seen="$(jq -c --arg cursor "$next" '.+[$cursor]' <<<"$inverse_seen")"; inverse_after="$next"
      else inverse_done=true; fi
    fi
  done
  jq -c --argjson relations "$rel_nodes" --argjson inverse "$inverse_nodes" '
    .relations={nodes:$relations,pageInfo:{hasNextPage:false,endCursor:null}} |
    .inverseRelations={nodes:$inverse,pageInfo:{hasNextPage:false,endCursor:null}}
  ' <<<"$node"
}

issue_list() {
  local project_id="$1" after='' next='' response nodes='[]' page after_json seen='[]' node
  while :; do
    after_json=null; [[ -z "$after" ]] || after_json="$(jq -Rn --arg value "$after" '$value')"
    response="$(request_query "$GRAPHQL/issue-list.graphql" "$(jq -cn --arg projectId "$project_id" --argjson after "$after_json" '{projectId:$projectId,after:$after}')")" || return 1
    jq -e --arg id "$project_id" '
      type=="object" and (.data.issues.nodes|type=="array") and
      (.data.issues.pageInfo.hasNextPage|type=="boolean") and
      all(.data.issues.nodes[];
        .project.id==$id and
        (.relations.nodes|type=="array") and
        (((.relations.pageInfo.hasNextPage // false))|type=="boolean") and
        (.inverseRelations.nodes|type=="array") and
        (((.inverseRelations.pageInfo.hasNextPage // false))|type=="boolean") and
        (.attachments == null or (
          (.attachments.nodes|type)=="array" and
          .attachments.pageInfo.hasNextPage==false
        ))
      )
    ' >/dev/null 2>&1 <<<"$response" || fail "issue list response is invalid"
    page='[]'
    while IFS= read -r node; do
      node="$(complete_issue_relations "$node" "$project_id")" || return 1
      page="$(jq -cn --argjson left "$page" --argjson item "$node" '$left+[$item]')"
    done < <(jq -c '.data.issues.nodes[]' <<<"$response")
    nodes="$(jq -cn --argjson left "$nodes" --argjson right "$page" '$left+$right')"
    [[ "$(jq -r '.data.issues.pageInfo.hasNextPage' <<<"$response")" == true ]] || break
    next="$(jq -r '.data.issues.pageInfo.endCursor // empty' <<<"$response")"
    [[ -n "$next" ]] || fail "issue list pagination cursor is missing"
    jq -e --arg cursor "$next" 'index($cursor)==null' >/dev/null <<<"$seen" || fail "issue list pagination cursor repeated"
    seen="$(jq -c --arg cursor "$next" '.+[$cursor]' <<<"$seen")"
    after="$next"
  done
  jq -cn --argjson nodes "$nodes" '{nodes:$nodes}'
}

raw_managed_increments() {
  local issues="$1" project_id="$2" repository="$3" issue_map="$4" enforce_ordinal_cardinality="${5:-true}"
  local tmp result='[]' node description metadata body native_refs semantic item pr branch
  local attachment_url normalized_attachment attachment_prs effective_pr
  tmp="$(mktemp -d)"
  while IFS= read -r node; do
    description="$(jq -r '.description // ""' <<<"$node")"
    grep -qF '+++ Woostack metadata — managed, do not edit' <<<"$description" || continue
    printf '%s' "$description" >"$tmp/description"
    metadata="$(python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" <"$tmp/description" 2>/dev/null)" || { rm -rf "$tmp"; fail "managed increment metadata is invalid or foreign"; }
    [[ "$(jq -r '.artifactType' <<<"$metadata")" == increment ]] || { rm -rf "$tmp"; fail "managed issue metadata has the wrong artifact type"; }
    pr="$(jq -r '.pullRequest // empty' <<<"$metadata")"
    branch="$(jq -r '.branch // empty' <<<"$metadata")"
    attachment_prs='[]'
    while IFS= read -r attachment_url; do
      [[ "$attachment_url" == *github.com/*/pull/* ]] || continue
      normalized_attachment="$(normalize_repository_pr_url "$repository" "$attachment_url")"
      attachment_prs="$(jq -cn --argjson urls "$attachment_prs" --arg url "$normalized_attachment" '$urls+[$url]|unique|sort')"
    done < <(jq -r '.attachments.nodes[]?.url? // empty' <<<"$node")
    if [[ -n "$pr" ]]; then
      [[ -n "$branch" ]] || { rm -rf "$tmp"; fail "pull request metadata requires a branch"; }
      if ! jq -e --arg pr "$pr" 'all(.[]; .==$pr)' >/dev/null <<<"$attachment_prs"; then
        [[ "$(jq 'length' <<<"$attachment_prs")" -eq 0 ]] || { rm -rf "$tmp"; fail "managed issue pull request metadata conflicts with native attachment evidence"; }
      fi
      effective_pr="$pr"
    else
      case "$(jq 'length' <<<"$attachment_prs")" in
        0) effective_pr='' ;;
        1) effective_pr="$(jq -r '.[0]' <<<"$attachment_prs")" ;;
        *) rm -rf "$tmp"; fail "managed issue has ambiguous native pull request attachment evidence" ;;
      esac
    fi
    python3 "$METADATA" body --repository "$repository" --project-id "$project_id" <"$tmp/description" >"$tmp/body" 2>/dev/null ||
      { rm -rf "$tmp"; fail "managed increment content is invalid"; }
    body="$(cat "$tmp/body")"
    printf '%s' "$body" | python3 "$METADATA" normalize-content >"$tmp/body-normalized" ||
      { rm -rf "$tmp"; fail "managed increment content normalization failed"; }
    native_refs="$(jq -c '
      [
        (.blockedBy.nodes[]?.id),
        (.relations.nodes[]? | select(.type=="blocked_by" or .type=="blockedBy") | .relatedIssue.id),
        (.inverseRelations.nodes[]? | select(.type=="blocks") | .issue.id)
      ] | map(select(type=="string")) | unique | sort
    ' <<<"$node")"
    jq -e --arg project "$project_id" '
      all([
        (.relations.nodes[]? | .relatedIssue.project.id),
        (.inverseRelations.nodes[]? | .issue.project.id)
      ][]; .==$project)
    ' >/dev/null 2>&1 <<<"$node" || { rm -rf "$tmp"; fail "managed issue has a cross-project relation"; }
    semantic="$(jq -r --arg state "$(jq -r '.state.id' <<<"$node")" 'to_entries | map(select(.value==$state)) | if length==1 then .[0].key else "" end' <<<"$issue_map")"
    [[ -n "$semantic" ]] || { rm -rf "$tmp"; fail "managed issue has an unmapped state"; }
    item="$(jq -cn --argjson issue "$node" --argjson metadata "$metadata" --argjson native "$native_refs" --arg status "$semantic" --arg content "$body" --rawfile normalizedContent "$tmp/body-normalized" --arg pullRequest "$effective_pr" '
      {
        id:$issue.id,
        identifier:$issue.identifier,
        projectId:$issue.project.id,
        ordinal:$metadata.ordinal,
        status:$status,
        dependencies:($metadata.dependencies|sort),
        nativeDependencies:$native,
        gitParent:$metadata.gitParent,
        branch:($metadata.branch // null),
        pullRequest:(if $pullRequest=="" then null else $pullRequest end),
        content:$content,
        contentNormalized:$normalizedContent,
        title:$issue.title,
        url:$issue.url,
        incrementId:$metadata.incrementId
      }
    ')"
    result="$(jq -cn --argjson old "$result" --argjson item "$item" '$old+[$item]')"
  done < <(jq -c '.nodes[] | select((.archivedAt // null)==null and (.canceledAt // null)==null)' <<<"$issues")
  rm -rf "$tmp"
  jq -ce --arg project "$project_id" --argjson enforceOrdinal "$enforce_ordinal_cardinality" '
    sort_by(.ordinal,.id) |
    if any(.[]; .projectId!=$project or
      (.id|type)!="string" or (.id|test("^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$")|not) or
      (.identifier|type)!="string" or (.identifier|test("^[A-Z][A-Z0-9]*-[1-9][0-9]*$")|not))
    then error("managed issue ownership or identity is invalid") else . end |
    if (map(.id)|length)!=(map(.id)|unique|length) then error("duplicate issue UUID") else . end |
    if (map(.identifier)|length)!=(map(.identifier)|unique|length) then error("duplicate issue identifier") else . end |
    if (map(.incrementId)|length)!=(map(.incrementId)|unique|length) then error("duplicate managed increment identity") else . end |
    if $enforceOrdinal and (map(.ordinal)|length)!=(map(.ordinal)|unique|length) then error("duplicate managed increment ordinal") else . end
  ' <<<"$result" || fail "managed issue ownership, identities, or ordinals are invalid"
}

normalized_increments() {
  local project_id="$1" repository="$2" issue_map="$3" include_content="${4:-false}" issues raw
  issues="$(issue_list "$project_id")" || fail "issue discovery failed"
  raw="$(raw_managed_increments "$issues" "$project_id" "$repository" "$issue_map")"
  jq -ce --argjson includeContent "$include_content" '
    if any(.[]; .dependencies!=.nativeDependencies)
    then error("native blocked-by relations disagree with managed metadata")
    else map(del(.nativeDependencies,.projectId) | if $includeContent then . else del(.contentNormalized) end)
    end
  ' <<<"$raw" || fail "native blocked-by relations disagree with managed metadata"
}

command_plan_read() {
  local project_id='' repository='' issue_map='' increments model
  while [[ $# -gt 0 ]]; do case "$1" in
    --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --issue-state-map) issue_map="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; validate_issue_state_map "$issue_map"
  increments="$(normalized_increments "$project_id" "$repository" "$issue_map")"
  model="$(jq -cn --arg project "$project_id" --argjson increments "$increments" '
    {backend:"linear",feature:{id:$project,url:"https://linear.invalid",title:"validation",status:"planning",baseBranch:null,baseCommitSha:null},
     spec:{id:"00000000-0000-4000-8000-000000000000",url:"https://linear.invalid",content:"",revision:{contentHash:"0000000000000000000000000000000000000000000000000000000000000000",updatedAt:"validation"}},
     increments:$increments}
  ')"
  python3 "$METADATA" validate-feature --project-id "$project_id" <<<"$model" >/dev/null || fail "managed increment graph is invalid"
  jq -cn --arg project "$project_id" --argjson increments "$increments" '{projectId:$project,increments:$increments}'
}

feature_model_from_project() {
  local project="$1" repository="$2" issue_map="$3" project_id documents doc spec increments model metadata base_branch base_commit_sha
  project_id="$(jq -r '.id' <<<"$project")"
  require_uuid "$project_id" "project id"
  documents="$(document_list "$project_id")" || fail "spec discovery failed"
  doc="$(find_spec "$project_id" "$repository" "$documents")" || fail "managed spec document not found"
  spec="$(spec_result "$doc")"
  increments="$(normalized_increments "$project_id" "$repository" "$issue_map")"
  metadata="$(jq -r '.content' <<<"$doc" | python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" 2>/dev/null)" || fail "spec metadata is invalid"
  base_branch="$(jq -c '.baseBranch // null' <<<"$metadata")"
  base_commit_sha="$(jq -c '.baseCommitSha // null' <<<"$metadata")"
  model="$(jq -cn --argjson project "$project" --argjson spec "$spec" --argjson increments "$increments" --argjson baseBranch "$base_branch" --argjson baseCommitSha "$base_commit_sha" '
    {backend:"linear",feature:{id:$project.id,url:$project.url,title:$project.name,status:$project.status,baseBranch:$baseBranch,baseCommitSha:$baseCommitSha},spec:$spec,increments:$increments}
  ')"
  python3 "$METADATA" validate-feature --project-id "$project_id" <<<"$model" >/dev/null || fail "normalized feature model is invalid"
  jq -cS . <<<"$model"
}

command_feature_read() {
  local project_id='' repository='' status_map='' issue_map='' projects project
  while [[ $# -gt 0 ]]; do case "$1" in
    --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --status-map) status_map="$2"; shift 2;; --issue-state-map) issue_map="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; validate_status_map "$status_map"; validate_issue_state_map "$issue_map"
  projects="$(project_list)" || fail "project discovery failed"
  project="$(resolve_from_list "$projects" "$repository" "$status_map" "$REQUIRED_STATUSES" "$project_id")" || return $?
  feature_model_from_project "$project" "$repository" "$issue_map"
}

command_provenance_parse() {
  local reference='' kind id canonical
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reference) reference="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  if [[ "$reference" =~ ^linear://([^/]+)/([^/]+)$ ]]; then
    kind="${BASH_REMATCH[1]}"
    id="${BASH_REMATCH[2]}"
  else
    fail "provenance reference must be linear://project|document|issue/UUID"
  fi
  case "$kind" in
    project|document|issue) ;;
    *) fail "provenance reference must be linear://project|document|issue/UUID" ;;
  esac
  [[ "$id" =~ $UUID_RE ]] || fail "provenance reference must be linear://project|document|issue/UUID"
  id="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
  canonical="linear://$kind/$id"
  jq -cn --arg uri "$canonical" --arg kind "$kind" --arg id "$id" '{uri:$uri,kind:$kind,id:$id}'
}

identity_connection_candidates() {
  local kind="$1" document="$2" root="$3" variable="$4" value="$5" response
  response="$(request_query "$GRAPHQL/$document.graphql" \
    "$(jq -cn --arg key "$variable" --arg value "$value" '{($key):$value}')")" ||
    fail "identity $kind lookup failed"
  jq -ce --arg root "$root" --arg kind "$kind" '
    .data[$root].nodes as $nodes |
    if ($nodes|type)!="array" or any($nodes[]; (.id|type)!="string")
    then error("invalid identity response")
    elif $kind=="project" then
      [$nodes[] | {
        kind:$kind,
        id:(.id|ascii_downcase),
        uri:("linear://"+$kind+"/"+(.id|ascii_downcase)),
        projectId:(.id|ascii_downcase),
        url
      }]
    else
      if any($nodes[]; (.project.id|type)!="string")
      then error("invalid identity owner")
      else [$nodes[] |
        select($kind!="issue" or
          ((.archivedAt // null)==null and (.canceledAt // null)==null)) |
        {
          kind:$kind,
          id:(.id|ascii_downcase),
          uri:("linear://"+$kind+"/"+(.id|ascii_downcase)),
          projectId:(.project.id|ascii_downcase),
          url
        }]
      end
    end
  ' <<<"$response" || fail "identity $kind response is invalid"
}

identity_issue_key_candidate() {
  local key="$1" response
  response="$(request_query "$GRAPHQL/identity-issue-key.graphql" \
    "$(jq -cn --arg id "$key" '{id:$id}')")" || fail "identity issue lookup failed"
  jq -ce '
    if .data.issue==null then []
    elif (.data.issue.id|type)!="string" or (.data.issue.project.id|type)!="string"
    then error("invalid identity response")
    elif ((.data.issue.archivedAt // null)!=null or
      (.data.issue.canceledAt // null)!=null) then []
    else [.data.issue | {
      kind:"issue",
      id:(.id|ascii_downcase),
      uri:("linear://issue/"+(.id|ascii_downcase)),
      projectId:(.project.id|ascii_downcase),
      url
    }]
    end
  ' <<<"$response" || fail "identity issue response is invalid"
}

discover_identity_reference() {
  local source="$1" repository="$2" status_map="$3"
  local kind='' mode='' wanted='' lookup='' canonical_source='' candidates='[]' matches count

  if [[ "$source" == linear://* ]]; then
    command_provenance_parse --reference "$source"
    return
  elif [[ "$source" =~ $UUID_RE ]]; then
    mode='uuid'
    wanted="$(printf '%s' "$source" | tr '[:upper:]' '[:lower:]')"
  elif [[ "$source" =~ ^https://linear\.app/([^/?#]+)/(project|document|issue)/([^/?#]+)(/[^/?#]+)*/?$ ]]; then
    mode='url'
    kind="${BASH_REMATCH[2]}"
    lookup="${BASH_REMATCH[3]}"
    canonical_source="https://linear.app/${BASH_REMATCH[1]}/$kind/$lookup"
  else
    fail "identity source must be a UUID, Linear project/document/issue URL, or canonical linear:// reference"
  fi

  if [[ "$mode" == uuid ]]; then
    matches="$(identity_connection_candidates project identity-project projects id "$wanted")"
    candidates="$(jq -cn --argjson left "$candidates" --argjson right "$matches" '$left+$right')"
    matches="$(identity_connection_candidates document identity-document documents id "$wanted")"
    candidates="$(jq -cn --argjson left "$candidates" --argjson right "$matches" '$left+$right')"
    matches="$(identity_connection_candidates issue identity-issue issues id "$wanted")"
    candidates="$(jq -cn --argjson left "$candidates" --argjson right "$matches" '$left+$right')"
  else
    case "$kind" in
      project)
        if [[ "$lookup" =~ $UUID_RE ]]; then
          matches="$(identity_connection_candidates project identity-project projects id "$lookup")"
        else
          matches="$(identity_connection_candidates project identity-project-slug projects slugId "$lookup")"
        fi
        ;;
      document)
        if [[ "$lookup" =~ $UUID_RE ]]; then
          matches="$(identity_connection_candidates document identity-document documents id "$lookup")"
        else
          matches="$(identity_connection_candidates document identity-document-slug documents slugId "$lookup")"
        fi
        ;;
      issue) matches="$(identity_issue_key_candidate "$lookup")" ;;
    esac
    candidates="$(jq -c --arg source "$canonical_source" '[.[] | select(.url==$source)]' <<<"$matches")"
  fi

  count="$(jq 'length' <<<"$candidates")"
  case "$count" in
    0)
      printf 'linear resources: identity not found\n' >&2
      return 3
      ;;
    1)
      jq -cS '.[0] | del(.url)' <<<"$candidates"
      ;;
    *)
      printf 'linear resources: identity is ambiguous across managed resource kinds\n' >&2
      jq -r 'sort_by(.kind,.id)[] | "candidate kind=\(.kind) id=\(.id) url=\(.url)"' <<<"$candidates" >&2
      return 4
      ;;
  esac
}

command_identity_resolve() {
  local source='' repository='' status_map='' issue_map='' parsed
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      --repository) repository="$2"; shift 2 ;;
      --status-map) status_map="$2"; shift 2 ;;
      --issue-state-map) issue_map="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$source" ]] || usage
  require_repository "$repository"
  validate_status_map "$status_map"
  validate_issue_state_map "$issue_map"
  parsed="$(discover_identity_reference "$source" "$repository" "$status_map")"
  command_provenance_resolve --reference "$(jq -r '.uri' <<<"$parsed")" \
    --repository "$repository" --status-map "$status_map" --issue-state-map "$issue_map"
}



command_doctor_read() {
  local repository='' status_map='' issue_map='' projects managed marker results='[]' project model
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repository) repository="$2"; shift 2 ;;
      --status-map) status_map="$2"; shift 2 ;;
      --issue-state-map) issue_map="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  require_repository "$repository"
  validate_status_map "$status_map"
  validate_issue_state_map "$issue_map"
  projects="$(project_list)" || fail "doctor project discovery failed"
  jq -e '[.nodes[].id | ascii_downcase] | group_by(.) | all(.[]; length==1)' \
    >/dev/null 2>&1 <<<"$projects" || fail "doctor managed project identity is ambiguous"
  marker="$(project_marker "$repository")"
  managed="$(jq -ce --arg repository "$repository" --arg marker "$marker" --argjson statuses "$status_map" '
    [
      .nodes[] |
      select(.archivedAt==null) |
      . as $project |
      (try (.description | split("\n")[1] | fromjson) catch null) as $metadata |
      select(($metadata|type)=="object" and $metadata.repository==$repository) |
      {project:$project,metadata:$metadata}
    ] |
    if any(.[]; .project.description!=$marker or .metadata!={repository:$repository,schema:1})
    then error("managed project metadata drift") else map(.project) end |
    if any(.[]; (.status.id|type)!="string" or
      ([.status.id as $id | $statuses[] | select(.==$id)]|length)!=1)
    then error("managed project status mapping drift") else . end
  ' <<<"$projects")" || fail "doctor managed project ownership, schema, or status mapping drift"
  [ "$(jq -r 'length' <<<"$managed")" -gt 0 ] ||
    fail "doctor managed feature not found"
  managed="$(jq -c --argjson statuses "$status_map" '
    [.[] | . as $project |
      ($statuses | to_entries[] | select(.value==$project.status.id) | .key) as $semantic |
      {id,name,url,status:$semantic,statusId:.status.id,updatedAt}
    ] | sort_by(.id)
  ' <<<"$managed")"
  while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    model="$(feature_model_from_project "$project" "$repository" "$issue_map")" ||
      fail "doctor managed resource validation failed"
    results="$(jq -cn --argjson results "$results" --argjson model "$model" '$results+[$model]')"
  done < <(jq -c '.[]' <<<"$managed")
  jq -cnS --argjson features "$results" '{backend:"linear",features:$features}'
}
command_provenance_resolve() {
  local reference='' repository='' status_map='' issue_map='' parsed kind id project_id response model
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reference) reference="$2"; shift 2 ;;
      --repository) repository="$2"; shift 2 ;;
      --status-map) status_map="$2"; shift 2 ;;
      --issue-state-map) issue_map="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  require_repository "$repository"
  validate_status_map "$status_map"
  validate_issue_state_map "$issue_map"
  parsed="$(command_provenance_parse --reference "$reference")"
  kind="$(jq -r '.kind' <<<"$parsed")"
  id="$(jq -r '.id' <<<"$parsed")"

  case "$kind" in
    project)
      project_id="$id"
      ;;
    document)
      response="$(request_query "$GRAPHQL/provenance-document.graphql" "$(jq -cn --arg id "$id" '{id:$id}')")" ||
        fail "provenance document lookup failed"
      jq -e --arg id "$id" '
        type=="object" and (.data.document|type)=="object" and
        ((.data.document.id|ascii_downcase)==$id) and
        (.data.document.project.id|type)=="string"
      ' >/dev/null 2>&1 <<<"$response" || fail "provenance document is missing or invalid"
      project_id="$(jq -r '.data.document.project.id | ascii_downcase' <<<"$response")"
      require_uuid "$project_id" "provenance document project id"
      ;;
    issue)
      response="$(request_query "$GRAPHQL/provenance-issue.graphql" "$(jq -cn --arg id "$id" '{id:$id}')")" ||
        fail "provenance issue lookup failed"
      jq -e --arg id "$id" '
        type=="object" and (.data.issue|type)=="object" and
        ((.data.issue.id|ascii_downcase)==$id) and
        (.data.issue.project.id|type)=="string"
      ' >/dev/null 2>&1 <<<"$response" || fail "provenance issue is missing or invalid"
      project_id="$(jq -r '.data.issue.project.id | ascii_downcase' <<<"$response")"
      require_uuid "$project_id" "provenance issue project id"
      ;;
  esac

  model="$(command_feature_read --project "$project_id" --repository "$repository" \
    --status-map "$status_map" --issue-state-map "$issue_map")" ||
    fail "provenance parent feature is missing, foreign, or drifted"
  case "$kind" in
    project)
      jq -e --arg id "$id" '(.feature.id|ascii_downcase)==$id' >/dev/null <<<"$model" ||
        fail "provenance project does not match the normalized feature"
      ;;
    document)
      jq -e --arg id "$id" '(.spec.id|ascii_downcase)==$id' >/dev/null <<<"$model" ||
        fail "provenance document is not the managed spec"
      ;;
    issue)
      jq -e --arg id "$id" 'any(.increments[]; (.id|ascii_downcase)==$id)' >/dev/null <<<"$model" ||
        fail "provenance issue is not a managed increment"
      ;;
  esac
  jq -cnS --argjson reference "$parsed" --arg projectId "$project_id" --argjson feature "$model" \
    '{backend:"linear",resource:($reference+{projectId:$projectId}),feature:$feature}'
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
  local documents doc='' document_attempted=false returned_document=null expected_file observed_file variables response attempted observed pending='[]' verified normalized=false
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
        jq -cn --argjson returned "$returned_project" '{attempted:["projectCreate"],observed:{project:null,document:null},returned:{project:$returned,document:null},outcome:"attemptedWithUnknown",verified:false,pending:["project-read-back"]}'
        return 1
      fi
      set +e; project="$(resolve_from_list "$projects" "$repository" "$status_map" "$ACTIVE_STATUSES" '')"; resolve_rc=$?; set -e
      if [[ "$resolve_rc" -ne 0 ]]; then
        jq -cn --argjson returned "$returned_project" '{attempted:["projectCreate"],observed:{project:null,document:null},returned:{project:$returned,document:null},outcome:"attemptedWithUnknown",verified:false,pending:["project-discovery"]}'
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
        jq -cn --arg project "$project_id" --argjson returned "$returned_document" '{attempted:["documentCreate"],observed:{project:$project,document:null},returned:{project:null,document:$returned},outcome:"attemptedWithUnknown",verified:false,pending:["document-read-back"]}'
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
    if ! cmp -s "$expected_file" "$observed_file"; then
      content_files_equivalent "$expected_file" "$observed_file" && normalized=true ||
        pending="$(jq -c '.+["document-content-verification"]' <<<"$pending")"
    fi
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
  jq -cn --argjson attempted "$attempted" --argjson observed "$observed" --argjson rp "$returned_project" --argjson rd "$returned_document" --argjson verified "$verified" --argjson normalized "$normalized" --argjson pending "$pending" '{attempted:$attempted,observed:$observed,returned:{project:$rp,document:$rd},outcome:(if $verified and $normalized then "writtenButNormalized" elif $verified then "verified" elif ($attempted|length)>0 then "attemptedWithUnknown" else "attempted" end),verified:$verified,pending:$pending}'
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
  local project_id='' repository='' content_file='' expected='' issue_map='' documents doc current expected_file current_file replacement_metadata increments evidence response returned=null readback='' observed_file verified=false normalized=false pending='[]'
  while [[ $# -gt 0 ]]; do case "$1" in --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --content-file) content_file="$2"; shift 2;; --expected-revision) expected="$2"; shift 2;;
    --issue-state-map) issue_map="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; [[ -r "$content_file" && -n "$expected" ]] || usage
  documents="$(document_list "$project_id")" || fail "spec discovery failed"
  doc="$(find_spec "$project_id" "$repository" "$documents")" || fail "managed spec document not found"
  current="$(spec_result "$doc")"
  [[ "$(jq -c '.revision' <<<"$current")" == "$(jq -cS . <<<"$expected" 2>/dev/null)" ]] || fail "optimistic revision mismatch"
  if [[ -n "$issue_map" ]]; then validate_issue_state_map "$issue_map"; fi
  expected_file="$(mktemp)"
  prepare_spec "$content_file" "$project_id" "$repository" "$expected_file" \
    || { rm -f "$expected_file"; fail "replacement spec preparation failed"; }
  current_file="$(mktemp)" || { rm -f "$expected_file"; fail "temporary spec allocation failed"; }
  jq -j '.content' <<<"$doc" >"$current_file" \
    || { rm -f "$current_file" "$expected_file"; fail "current spec content is invalid"; }
  replacement_metadata="$(python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" <"$expected_file")" \
    || { rm -f "$current_file" "$expected_file"; fail "replacement spec metadata is invalid"; }
  if [[ -n "$issue_map" ]]; then
    increments="$(normalized_increments "$project_id" "$repository" "$issue_map")" \
      || { rm -f "$current_file" "$expected_file"; fail "increment discovery failed"; }
    evidence="$(jq -c '[.[] | {branch,pullRequest}]' <<<"$increments")" \
      || { rm -f "$current_file" "$expected_file"; fail "increment evidence is invalid"; }
    python3 "$METADATA" replace --metadata "$replacement_metadata" \
      --repository "$repository" --project-id "$project_id" \
      --increment-evidence "$evidence" <"$current_file" >/dev/null \
      || { rm -f "$current_file" "$expected_file"; fail "spec metadata replacement is unsafe"; }
  else
    python3 "$METADATA" replace --metadata "$replacement_metadata" \
      --repository "$repository" --project-id "$project_id" <"$current_file" >/dev/null \
      || { rm -f "$current_file" "$expected_file"; fail "spec metadata replacement is unsafe"; }
  fi
  rm -f "$current_file"
  if response="$(request_mutation "$GRAPHQL/document-update.graphql" "$(jq -cn --arg id "$(jq -r '.id' <<<"$doc")" --rawfile content "$expected_file" '{id:$id,input:{content:$content}}')")"; then
    if jq -e '.data.documentUpdate.success==true and (.data.documentUpdate.document.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
      returned="$(jq -c '.data.documentUpdate.document | {id,title,url,updatedAt,project}' <<<"$response")"
    fi
  fi
  if ! documents="$(document_list "$project_id")"; then
    rm -f "$expected_file"
    jq -cn --argjson returned "$returned" '{attempted:["documentUpdate"],observed:{document:null},returned:{document:$returned},outcome:(if $returned==null then "attemptedWithUnknown" else "attempted" end),verified:false,pending:["document-read-back"]}'
    return 1
  fi
  set +e; readback="$(find_spec "$project_id" "$repository" "$documents")"; readback_rc=$?; set -e
  if [[ "$readback_rc" -ne 0 ]]; then
    pending='["document-discovery"]'
  else
    observed_file="$(mktemp)"; jq -j '.content' <<<"$readback" >"$observed_file"
    if ! cmp -s "$expected_file" "$observed_file"; then
      content_files_equivalent "$expected_file" "$observed_file" && normalized=true ||
        pending="$(jq -c '.+["document-content-verification"]' <<<"$pending")"
    fi
    rm -f "$observed_file"
    [[ "$(jq -r '.id' <<<"$readback")" == "$(jq -r '.id' <<<"$doc")" ]] || pending="$(jq -c '.+["document-identity-verification"]' <<<"$pending")"
    if [[ "$returned" != null && "$(jq -r '.id' <<<"$returned")" != "$(jq -r '.id' <<<"$readback")" ]]; then pending="$(jq -c '.+["document-return-mismatch"]' <<<"$pending")"; fi
  fi
  rm -f "$expected_file"
  [[ "$(jq 'length' <<<"$pending")" -eq 0 ]] && verified=true
  jq -cn --arg id "${readback:+$(jq -r '.id' <<<"$readback")}" --argjson returned "$returned" --argjson verified "$verified" --argjson normalized "$normalized" --argjson pending "$pending" \
    '{attempted:["documentUpdate"],observed:{document:(if $id=="" then null else $id end)},returned:{document:$returned},outcome:(if $verified and $normalized then "writtenButNormalized" elif $verified then "verified" elif $returned==null then "attemptedWithUnknown" else "attempted" end),verified:$verified,pending:$pending}'
  [[ "$verified" == true ]]
}

command_replan_transition() {
  local project_id="$1" repository="$2" status_map="$3" target="$4" issue_map="$5" expected="$6"
  local projects current current_name documents doc spec metadata design_state increments claim_file claim_metadata
  local claim_receipt claimed claimed_revision response returned=null readback readback_rc verified=false
  local attempted='["documentUpdate","projectUpdate"]'
  [[ "$target" == planning && -n "$issue_map" && -n "$expected" ]] \
    || fail "explicit replan requires a planning target, issue evidence, and an expected spec revision"
  validate_issue_state_map "$issue_map"
  projects="$(project_list)" || fail "project discovery failed"
  current="$(resolve_from_list "$projects" "$repository" "$status_map" "$REQUIRED_STATUSES" "$project_id")" || return $?
  current_name="$(jq -r '.status' <<<"$current")"
  [[ "$current_name" == ready || "$current_name" == planning ]] \
    || fail "explicit replan requires a ready or planning project"
  documents="$(document_list "$project_id")" || fail "spec discovery failed during replan"
  doc="$(find_spec "$project_id" "$repository" "$documents")" \
    || fail "managed spec document not found during replan"
  spec="$(spec_result "$doc")" || fail "managed spec revision is invalid during replan"
  [[ "$(jq -c '.revision' <<<"$spec")" == "$(jq -cS . <<<"$expected" 2>/dev/null)" ]] \
    || fail "optimistic revision mismatch"
  metadata="$(jq -j '.content' <<<"$doc" | python3 "$METADATA" parse \
    --repository "$repository" --project-id "$project_id" 2>/dev/null)" \
    || fail "managed spec lifecycle is invalid during replan"
  design_state="$(jq -r '.designState // ""' <<<"$metadata")"
  if [[ "$design_state" != "$current_name" \
      && ! ("$current_name" == ready && "$design_state" == planning) ]]; then
    fail "project and managed spec lifecycle mismatch blocks replanning"
  fi
  [[ "$design_state" == ready || "$design_state" == planning ]] \
    || fail "managed spec lifecycle blocks replanning"
  increments="$(normalized_increments "$project_id" "$repository" "$issue_map")" \
    || fail "increment discovery failed during replan"
  jq -e 'all(.[]; .branch==null and .pullRequest==null)' >/dev/null <<<"$increments" \
    || fail "implementation evidence blocks replanning"
  if [[ "$design_state" == planning ]]; then
    if [[ "$current_name" == planning ]]; then
      jq -cn --arg current "$current_name" --arg target "$target" --arg id "$project_id" \
        '{current:$current,target:$target,attempted:[],observed:{project:$id},returned:{project:null},verified:true,pending:[]}'
      return
    fi
    claimed_revision="$(jq -c '.revision' <<<"$spec")"
    attempted='["projectUpdate"]'
  else
    claim_file="$(mktemp)"
    claim_metadata="$(jq -cS '.designState="planning"' <<<"$metadata")" \
      || { rm -f "$claim_file"; fail "replan claim metadata is invalid"; }
    jq -j '.content' <<<"$doc" | python3 "$METADATA" replace --metadata "$claim_metadata" \
      --repository "$repository" --project-id "$project_id" \
      --increment-evidence "$(jq -c '[.[] | {branch,pullRequest}]' <<<"$increments")" \
      --expected-revision "$expected" --updated-at "$(jq -r '.updatedAt' <<<"$doc")" >"$claim_file" \
      || { rm -f "$claim_file"; fail "managed spec replan claim is unsafe"; }
    if ! claim_receipt="$(command_spec_write --project "$project_id" --repository "$repository" \
        --content-file "$claim_file" --expected-revision "$expected" --issue-state-map "$issue_map")"; then
      rm -f "$claim_file"
      printf '%s\n' "$claim_receipt"
      return 1
    fi
    rm -f "$claim_file"
    claimed="$(command_spec_read --project "$project_id" --repository "$repository")" \
      || fail "claimed planning spec could not be read back"
    [[ "$(jq -j '.content' <<<"$claimed" | python3 "$METADATA" parse \
        --repository "$repository" --project-id "$project_id" 2>/dev/null | jq -r '.designState // ""')" == planning ]] \
      || fail "claimed planning spec failed lifecycle verification"
    claimed_revision="$(jq -c '.revision' <<<"$claimed")"
  fi

  if response="$(request_mutation "$GRAPHQL/project-update.graphql" "$(jq -cn --arg id "$project_id" --arg statusId "$(jq -r '.planning' <<<"$status_map")" '{id:$id,input:{statusId:$statusId}}')")"; then
    if jq -e '.data.projectUpdate.success==true and (.data.projectUpdate.project.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
      returned="$(jq -c '.data.projectUpdate.project | {id,name,url,status}' <<<"$response")"
    fi
  fi
  projects="$(project_list)" || {
    claimed="$(command_spec_read --project "$project_id" --repository "$repository")" \
      || fail "project transition and planning spec read-back are both unverified"
    [[ "$(jq -c '.revision' <<<"$claimed")" == "$claimed_revision" ]] \
      || fail "failed project transition did not preserve the claimed spec revision"
    [[ "$(jq -j '.content' <<<"$claimed" | python3 "$METADATA" parse \
        --repository "$repository" --project-id "$project_id" 2>/dev/null | jq -r '.designState // ""')" == planning ]] \
      || fail "failed project transition did not preserve a verified planning spec"
    jq -cn --arg current "$current_name" --arg target "$target" --argjson attempted "$attempted" --argjson returned "$returned" \
      '{current:$current,target:$target,attempted:$attempted,observed:{project:null},returned:{project:$returned},verified:false,pending:["project-read-back"]}'
    return 1
  }
  set +e; readback="$(resolve_from_list "$projects" "$repository" "$status_map" "$REQUIRED_STATUSES" "$project_id" 2>/dev/null)"; readback_rc=$?; set -e
  if [[ "$readback_rc" -eq 0 && "$(jq -r '.status' <<<"$readback")" == planning ]]; then
    verified=true
    if [[ "$returned" != null ]]; then
      [[ "$(jq -r '.id' <<<"$returned")" == "$project_id" ]] || verified=false
      [[ "$(jq -r '.status.id' <<<"$returned")" == "$(jq -r '.planning' <<<"$status_map")" ]] || verified=false
    fi
  fi
  if [[ "$verified" != true ]]; then
    claimed="$(command_spec_read --project "$project_id" --repository "$repository")" \
      || fail "failed project transition did not preserve a readable planning spec"
    [[ "$(jq -c '.revision' <<<"$claimed")" == "$claimed_revision" ]] \
      || fail "failed project transition did not preserve the claimed spec revision"
    [[ "$(jq -j '.content' <<<"$claimed" | python3 "$METADATA" parse \
        --repository "$repository" --project-id "$project_id" 2>/dev/null | jq -r '.designState // ""')" == planning ]] \
      || fail "failed project transition did not preserve a verified planning spec"
  fi
  jq -cn --arg current "$current_name" --arg target "$target" --arg id "${readback:+$(jq -r '.id' <<<"$readback")}" \
    --argjson attempted "$attempted" --argjson returned "$returned" --argjson verified "$verified" \
    '{current:$current,target:$target,attempted:$attempted,observed:{project:(if $id=="" then null else $id end)},returned:{project:$returned},verified:$verified,pending:(if $verified then [] else ["project-status-verification"] end)}'
  [[ "$verified" == true ]]
}

command_feature_transition() {
  local project_id='' repository='' status_map='' target='' replan=false issue_map='' expected='' projects current current_name current_index target_index response returned readback verified
  while [[ $# -gt 0 ]]; do case "$1" in --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --status-map) status_map="$2"; shift 2;; --target) target="$2"; shift 2;;
    --replan) replan=true; shift;; --issue-state-map) issue_map="$2"; shift 2;; --expected-revision) expected="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; validate_status_map "$status_map"
  if [[ "$replan" == true ]]; then
    command_replan_transition "$project_id" "$repository" "$status_map" "$target" "$issue_map" "$expected"
    return
  fi
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

find_raw_issue() {
  local issues="$1" wanted="$2" matches
  matches="$(jq -c --arg wanted "$wanted" '[.nodes[] | select(.id==$wanted or .identifier==$wanted)]' <<<"$issues")"
  [[ "$(jq 'length' <<<"$matches")" -eq 1 ]] || fail "managed issue reference is missing or ambiguous"
  jq -c '.[0]' <<<"$matches"
}

command_issue_transition() {
  local project_id='' repository='' issue_ref='' issue_map='' target='' branch='' pull_request=''
  local issues issue description metadata current allowed input response returned=null readback increments observed verified=false pending='[]'
  while [[ $# -gt 0 ]]; do case "$1" in
    --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --issue) issue_ref="$2"; shift 2;; --issue-state-map) issue_map="$2"; shift 2;;
    --target) target="$2"; shift 2;; --branch) branch="$2"; shift 2;;
    --pull-request) pull_request="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; validate_issue_state_map "$issue_map"
  [[ -n "$issue_ref" && -n "$target" ]] || usage
  jq -e --arg target "$target" 'has($target)' >/dev/null 2>&1 <<<"$issue_map" || fail "unknown issue state"
  [[ "$target" != "done" ]] || fail "done requires verified merge attribution through status-reconcile"
  if [[ -n "$pull_request" ]]; then
    pull_request="$(normalize_repository_pr_url "$repository" "$pull_request")"
  fi
  [[ -z "$pull_request" || -n "$branch" ]] || fail "pull request attribution requires a branch"
  owned_project "$project_id" "$repository" >/dev/null
  issues="$(issue_list "$project_id")" || fail "issue discovery failed"
  issue="$(find_raw_issue "$issues" "$issue_ref")"
  description="$(jq -r '.description // ""' <<<"$issue")"
  metadata="$(python3 "$METADATA" parse --repository "$repository" --project-id "$project_id" <<<"$description" 2>/dev/null)" || fail "managed increment metadata is invalid or foreign"
  [[ "$(jq -r '.artifactType' <<<"$metadata")" == increment ]] || fail "issue is not a managed increment"
  current="$(jq -r --arg state "$(jq -r '.state.id' <<<"$issue")" 'to_entries | map(select(.value==$state)) | if length==1 then .[0].key else "" end' <<<"$issue_map")"
  [[ -n "$current" ]] || fail "managed issue has an unmapped state"
  if [[ "$current" == "$target" && -z "$branch" && -z "$pull_request" ]]; then
    jq -cn --arg current "$current" --arg target "$target" --arg id "$(jq -r '.id' <<<"$issue")" '{current:$current,target:$target,attempted:[],completed:[],observed:{issue:$id},returned:{issue:null},verified:true,pending:[]}'
    return
  fi
  allowed=false
  case "$current:$target" in
    planned:executing|planned:blocked|blocked:executing|executing:blocked|executing:inReview|inReview:inReview) allowed=true;;
  esac
  [[ "$allowed" == true ]] || fail "invalid issue lifecycle transition"
  if [[ "$target" == inReview ]]; then
    [[ -n "$branch" && -n "$pull_request" ]] || fail "in-review transition requires branch and pull request evidence"
  fi
  metadata="$(jq -c --arg branch "$branch" --arg pr "$pull_request" '
    if $branch!="" then .branch=$branch else . end |
    if $pr!="" then .pullRequest=$pr else . end
  ' <<<"$metadata")"
  if [[ -n "$branch" || -n "$pull_request" ]]; then
    description="$(python3 "$METADATA" replace --metadata "$metadata" --repository "$repository" --project-id "$project_id" <<<"$description")" || fail "issue evidence metadata update failed"
  fi
  input="$(jq -cn --arg stateId "$(jq -r --arg target "$target" '.[$target]' <<<"$issue_map")" --arg description "$description" --argjson evidence "$([[ -n "$branch" || -n "$pull_request" ]] && printf true || printf false)" '
    {stateId:$stateId} + (if $evidence then {description:$description} else {} end)
  ')"
  if response="$(request_mutation "$GRAPHQL/issue-update.graphql" "$(jq -cn --arg id "$(jq -r '.id' <<<"$issue")" --argjson input "$input" '{id:$id,input:$input}')")"; then
    if jq -e '.data.issueUpdate.success==true and (.data.issueUpdate.issue.id|type=="string")' >/dev/null 2>&1 <<<"$response"; then
      returned="$(jq -c '.data.issueUpdate.issue | {id,identifier,state,project}' <<<"$response")"
    fi
  fi
  increments="$(normalized_increments "$project_id" "$repository" "$issue_map")"
  readback="$(jq -c --arg id "$(jq -r '.id' <<<"$issue")" '.[] | select(.id==$id)' <<<"$increments")"
  observed="$(jq -r '.status // ""' <<<"$readback")"
  if [[ "$observed" == "$target" ]]; then
    verified=true
    [[ -z "$branch" || "$(jq -r '.branch // ""' <<<"$readback")" == "$branch" ]] || verified=false
    [[ -z "$pull_request" || "$(jq -r '.pullRequest // ""' <<<"$readback")" == "$pull_request" ]] || verified=false
    if [[ "$returned" != null ]]; then
      [[ "$(jq -r '.id' <<<"$returned")" == "$(jq -r '.id' <<<"$issue")" ]] || verified=false
      [[ "$(jq -r '.project.id' <<<"$returned")" == "$project_id" ]] || verified=false
    fi
  fi
  [[ "$verified" == true ]] || pending='["issue-status-or-evidence-verification"]'
  jq -cn --arg current "$current" --arg target "$target" --arg id "$(jq -r '.id // empty' <<<"$readback")" --argjson returned "$returned" --argjson verified "$verified" --argjson pending "$pending" \
    '{current:$current,target:$target,attempted:["issueUpdate"],completed:(if $verified then ["issueUpdate"] else [] end),observed:{issue:(if $id=="" then null else $id end)},returned:{issue:$returned},outcome:(if $verified then "verified" elif $returned==null then "attemptedWithUnknown" else "attempted" end),verified:$verified,pending:$pending}'
  [[ "$verified" == true ]]
}

command_status_reconcile() {
  local project_id='' repository='' status_map='' issue_map='' prs_file='' prs_json=''
  local expected_eligible='' expected_project_transition='' expected_snapshot=''
  local increments eligible eligible_ids inc response after projects project project_semantic current_project_semantic
  local observed_snapshot all_done should_project project_verified=false non_target_ok
  local attempted='[]' completed='[]' pending='[]'
  while [[ $# -gt 0 ]]; do case "$1" in
    --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --status-map) status_map="$2"; shift 2;; --issue-state-map) issue_map="$2"; shift 2;;
    --pull-requests-file) prs_file="$2"; shift 2;;
    --expected-eligible) expected_eligible="$2"; shift 2;;
    --expected-project-transition) expected_project_transition="$2"; shift 2;;
    --expected-snapshot) expected_snapshot="$2"; shift 2;;
    *) usage;;
  esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"
  validate_status_map "$status_map"; validate_issue_state_map "$issue_map"
  [[ -r "$prs_file" ]] || fail "pull request evidence file is unreadable"
  prs_json="$(python3 "$METADATA" normalize-prs --repository "$repository" <"$prs_file")" ||
    fail "pull request evidence is invalid or foreign"
  jq -e '
    type=="array" and length==(unique|length) and
    all(.[]; type=="string" and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"))
  ' >/dev/null 2>&1 <<<"$expected_eligible" || fail "expected eligible issue set is invalid"
  [[ "$expected_project_transition" == true || "$expected_project_transition" == false ]] \
    || fail "expected project transition must be boolean"
  jq -e --argjson issue_map "$issue_map" --argjson status_map "$status_map" '
    type=="object" and
    (.projectStatus|type=="string") and $status_map[.projectStatus]!=null and
    (.issues|type=="array") and
    (.issues|length)==([.issues[].id]|unique|length) and
    all(.issues[]; (.id|type=="string") and (.status|type=="string") and $issue_map[.status]!=null)
  ' >/dev/null 2>&1 <<<"$expected_snapshot" || fail "expected status snapshot is invalid"
  jq -e --arg prefix "https://github.com/$repository/pull/" '
    type=="array" and all(.[];
      type=="object" and
      (.projectId|type=="string") and
      (.projectId|test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")) and
      (.issueIdentifier|type=="string") and
      (.issueIdentifier|test("^[A-Z][A-Z0-9]*-[1-9][0-9]*$")) and
      (.url|type=="string") and
      (.url|startswith($prefix)) and
      (.url|ltrimstr($prefix)|test("^[1-9][0-9]*$")) and
      (.merged|type=="boolean")
    )
  ' >/dev/null 2>&1 <<<"$prs_json" || fail "pull request evidence is invalid or foreign"

  project="$(owned_project "$project_id" "$repository")"
  project_semantic="$(jq -r --arg state "$(jq -r '.status.id' <<<"$project")" \
    'to_entries | map(select(.value==$state)) | if length==1 then .[0].key else "" end' <<<"$status_map")"
  [[ -n "$project_semantic" ]] || fail "parent project has an unmapped status"
  [[ "$project_semantic" != "abandoned" ]] || fail "abandoned project is immutable"
  [[ "$project_semantic" == "inReview" || "$project_semantic" == "done" ]] \
    || fail "project is not eligible for terminal reconciliation"
  increments="$(normalized_increments "$project_id" "$repository" "$issue_map")"
  observed_snapshot="$(jq -cn --arg status "$project_semantic" --argjson increments "$increments" \
    '{projectStatus:$status,issues:($increments|map({id,status})|sort_by(.id))}')"
  jq -e --argjson expected "$expected_snapshot" \
    '(.projectStatus==$expected.projectStatus) and ((.issues|sort_by(.id))==($expected.issues|sort_by(.id)))' \
    >/dev/null 2>&1 <<<"$observed_snapshot" || fail "status snapshot drifted before mutation"

  jq -e --arg project "$project_id" --argjson increments "$increments" '
    . as $evidence |
    (group_by(.projectId,.issueIdentifier) | all(.[]; length==1)) and
    all($evidence[]; . as $item |
      $item.projectId==$project and
      ([$increments[] | select(.identifier==$item.issueIdentifier and .pullRequest==$item.url)] | length)==1
    ) and
    all($increments[] | select(.status=="inReview" and .pullRequest!=null); . as $issue |
      ([$evidence[] | select(.projectId==$project and .issueIdentifier==$issue.identifier and .url==$issue.pullRequest)] | length)==1
    ) and
    all($increments[] | select(.status=="done"); . as $issue |
      ([$evidence[] | select(
        .projectId==$project and .issueIdentifier==$issue.identifier and
        .url==$issue.pullRequest and .merged==true
      )] | length)==1
    )
  ' >/dev/null 2>&1 <<<"$prs_json" \
    || fail "pull request attribution pair is missing, duplicate, or foreign; or done evidence is unmerged"
  eligible="$(jq -cn --arg project "$project_id" --argjson increments "$increments" --argjson evidence "$prs_json" '
    [$increments[] | select(.status=="inReview") | . as $issue |
      [$evidence[] | select(
        .projectId==$project and .issueIdentifier==$issue.identifier and
        .url==$issue.pullRequest and .merged==true
      )] | select(length==1) | $issue]
  ')"
  eligible_ids="$(jq -c '[.[].id]|sort' <<<"$eligible")"
  jq -e --argjson actual "$eligible_ids" '(sort)==$actual' >/dev/null 2>&1 <<<"$expected_eligible" \
    || fail "eligible issue set drifted before mutation"
  all_done=false
  if [[ "$(jq 'length' <<<"$increments")" -gt 0 ]] &&
     jq -e 'all(.[]; .status=="done")' >/dev/null <<<"$increments"; then all_done=true; fi
  [[ "$project_semantic" != "done" || "$all_done" == true ]] \
    || fail "project and managed issue terminal states are inconsistent"
  should_project=false
  if [[ "$project_semantic" == inReview && "$(jq 'length' <<<"$increments")" -gt 0 ]] &&
     jq -e --argjson eligible "$eligible_ids" '
       all(.[]; . as $issue | .status=="done" or any($eligible[]; .==$issue.id))
     ' >/dev/null <<<"$increments"; then should_project=true; fi
  [[ "$should_project" == "$expected_project_transition" ]] \
    || fail "project transition preview drifted before mutation"

  if [[ "$project_semantic" == "done" ]]; then
    [[ "$(jq 'length' <<<"$eligible_ids")" -eq 0 && "$expected_project_transition" == false ]] \
      || fail "done project cannot carry pending terminal writes"
    jq -cn --arg id "$project_id" \
      '{eligibleIssues:[],attempted:[],completed:[],pending:[],projectDone:true,observed:{project:$id},verified:true}'
    return
  fi

  while IFS= read -r inc; do
    attempted="$(jq -c '.+["issueUpdate"]' <<<"$attempted")"
    if response="$(request_mutation "$GRAPHQL/issue-update.graphql" \
      "$(jq -cn --arg id "$(jq -r '.id' <<<"$inc")" --arg stateId "$(jq -r '.done' <<<"$issue_map")" \
        '{id:$id,input:{stateId:$stateId}}')")" &&
       jq -e --arg id "$(jq -r '.id' <<<"$inc")" --arg state "$(jq -r '.done' <<<"$issue_map")" \
         '.data.issueUpdate.success==true and .data.issueUpdate.issue.id==$id and .data.issueUpdate.issue.state.id==$state' \
         >/dev/null 2>&1 <<<"$response"; then
      :
    else
      pending="$(jq -c '.+["issue-update-failed"]' <<<"$pending")"
    fi
  done < <(jq -c '.[]' <<<"$eligible")
  after="$(normalized_increments "$project_id" "$repository" "$issue_map")"
  while IFS= read -r inc; do
    if jq -e --arg id "$(jq -r '.id' <<<"$inc")" \
      'any(.[]; .id==$id and .status=="done")' >/dev/null <<<"$after"; then
      completed="$(jq -c '.+["issueUpdate"]' <<<"$completed")"
    else
      pending="$(jq -c '.+["issue-done-verification"]' <<<"$pending")"
    fi
  done < <(jq -c '.[]' <<<"$eligible")
  non_target_ok="$(jq -n --argjson before "$increments" --argjson after "$after" --argjson targets "$eligible_ids" '
    def untouched:
      map(select(.id as $id | ($targets|index($id)|not))) | map({id,status}) | sort_by(.id);
    ($before|untouched)==($after|untouched) and
    ([$before[].id]|sort)==([$after[].id]|sort)
  ')"
  [[ "$non_target_ok" == true ]] \
    || pending="$(jq -c '.+["non-target-status-verification"]' <<<"$pending")"

  if [[ "$expected_project_transition" == true ]] &&
     [[ "$(jq 'length' <<<"$pending")" -eq 0 ]] &&
     [[ "$(jq 'length' <<<"$after")" -gt 0 ]] &&
     jq -e 'all(.[]; .status=="done")' >/dev/null <<<"$after"; then
    projects="$(project_list)" || fail "project discovery failed before terminal write"
    current_project_semantic="$(jq -r --arg id "$project_id" --argjson statuses "$status_map" '
      [.nodes[] | select(.id==$id)] |
      if length==1 then .[0].status.id as $state |
        ($statuses|to_entries|map(select(.value==$state))|if length==1 then .[0].key else "" end)
      else "" end
    ' <<<"$projects")"
    [[ "$current_project_semantic" == inReview ]] \
      || fail "project status drifted before terminal mutation"
    attempted="$(jq -c '.+["projectUpdate"]' <<<"$attempted")"
    if response="$(request_mutation "$GRAPHQL/project-update.graphql" \
      "$(jq -cn --arg id "$project_id" --arg statusId "$(jq -r '.done' <<<"$status_map")" \
        '{id:$id,input:{statusId:$statusId}}')")" &&
       jq -e --arg id "$project_id" --arg status "$(jq -r '.done' <<<"$status_map")" \
         '.data.projectUpdate.success==true and .data.projectUpdate.project.id==$id and .data.projectUpdate.project.status.id==$status' \
         >/dev/null 2>&1 <<<"$response"; then
      :
    else
      pending="$(jq -c '.+["project-update-failed"]' <<<"$pending")"
    fi
    projects="$(project_list)" || fail "project status read-back failed"
    if jq -e --arg id "$project_id" --arg status "$(jq -r '.done' <<<"$status_map")" \
      'any(.nodes[]; .id==$id and .status.id==$status)' >/dev/null <<<"$projects"; then
      project_verified=true
      completed="$(jq -c '.+["projectUpdate"]' <<<"$completed")"
    else
      pending="$(jq -c '.+["project-done-verification"]' <<<"$pending")"
    fi
  fi
  jq -cn --argjson eligible "$eligible_ids" --argjson attempted "$attempted" \
    --argjson completed "$completed" --argjson pending "$pending" \
    --argjson projectDone "$project_verified" \
    '{eligibleIssues:$eligible,attempted:$attempted,completed:$completed,pending:$pending,projectDone:$projectDone,verified:($pending|length==0)}'
  [[ "$(jq 'length' <<<"$pending")" -eq 0 ]]
}

managed_native_relations() {
  local issues="$1" uuid_map="$2" ids relations
  ids="$(jq -c '[.[]]' <<<"$uuid_map")"
  relations="$(jq -c '
    [.nodes[] as $node |
      ($node.relations.nodes[]? |
        if (.type=="blocked_by" or .type=="blockedBy") then {id:.id,issue:$node.id,dependency:.relatedIssue.id}
        elif .type=="blocks" then {id:.id,issue:.relatedIssue.id,dependency:$node.id} else empty end),
      ($node.inverseRelations.nodes[]? | select(.type=="blocks") | {id:.id,issue:$node.id,dependency:.issue.id})
    ] | unique_by(.id)
  ' <<<"$issues")"
  jq -e --argjson ids "$ids" '
    all(.[]; . as $relation | (($ids|index($relation.issue))!=null) == (($ids|index($relation.dependency))!=null))
  ' >/dev/null <<<"$relations" || fail "relation has only one managed endpoint"
  jq -c --argjson ids "$ids" '
    [.[] | . as $relation | select(($ids|index($relation.issue))!=null and ($ids|index($relation.dependency))!=null)]
  ' <<<"$relations"
}

compose_increment_description() {
  local content="$1" metadata="$2"
  printf '%s' "$content"
  [[ -z "$content" || "$content" == *$'\n' ]] || printf '\n'
  printf '\n%s\n%s\n%s\n' '+++ Woostack metadata — managed, do not edit' "$(jq -cS . <<<"$metadata")" '+++'
}


command_plan_reconcile() {
  local project_id='' repository='' team_id='' issue_map='' plan_file='' desired current issues uuid_map observed match removed inc stable id dep_ids parent old metadata description variables response returned response_valid
  local attempted='[]' completed='[]' pending='[]' mutation_responses='[]' current_relations desired_relations rel key final expected verified=false normalized=false
  while [[ $# -gt 0 ]]; do case "$1" in
    --project) project_id="$2"; shift 2;; --repository) repository="$2"; shift 2;;
    --team-id) team_id="$2"; shift 2;; --issue-state-map) issue_map="$2"; shift 2;;
    --plan-file) plan_file="$2"; shift 2;; *) usage;; esac; done
  require_uuid "$project_id" "project id"; require_repository "$repository"; require_uuid "$team_id" "team id"; validate_issue_state_map "$issue_map"
  [[ -r "$plan_file" ]] || fail "plan file is unreadable"
  desired="$(jq -ce '
    (if type=="array" then . else .increments end) |
    if type!="array" then error("increments must be an array") else . end |
    map({
      incrementId:.incrementId,title:.title,ordinal:.ordinal,
      dependencies:(.dependencies // []),gitParent:.gitParent,content:.content
    }) | sort_by(.ordinal,.incrementId) |
    if any(.[]; (.incrementId|type)!="string" or .incrementId=="" or (.title|type)!="string" or .title=="" or
      (.ordinal|type)!="number" or (.ordinal|floor)!=.ordinal or .ordinal<1 or
      (.dependencies|type)!="array" or any(.dependencies[]; type!="string" or .=="") or
      (.dependencies|length)!=(.dependencies|unique|length) or
      (.gitParent|type)!="string" or .gitParent=="" or (.content|type)!="string")
    then error("invalid increment") else . end |
    if (map(.incrementId)|length)!=(map(.incrementId)|unique|length) or
       (map(.ordinal)|length)!=(map(.ordinal)|unique|length)
    then error("duplicate increment identity or ordinal") else . end |
    . as $plan |
    def item($id): $plan[] | select(.incrementId==$id);
    def reaches($from;$wanted;$seen):
      if ($seen|index($from))!=null then error("dependency cycle")
      elif $from==$wanted then true
      else any(item($from).dependencies[]; reaches(.;$wanted;$seen+[$from]))
      end;
    if any(.[]; . as $item | any($item.dependencies[]; . as $dependency | ([ $plan[].incrementId ]|index($dependency))==null))
    then error("unknown dependency") else . end |
    if any(.[]; . as $item |
      (($item.dependencies|length)==0 and ([ $plan[].incrementId ]|index($item.gitParent))!=null)
      or (($item.dependencies|length)>0 and ($item.dependencies|index($item.gitParent))==null)
      or (($item.dependencies|length)>0 and any($item.dependencies[]; . as $dependency | (reaches($item.gitParent;$dependency;[] )|not))))
    then error("unrepresentable Git ancestry") else . end |
    if any(.[]; . as $item | any($item.dependencies[]; . as $dependency | item($dependency).ordinal >= $item.ordinal))
    then error("dependency must precede dependent ordinal") else . end
  ' "$plan_file" 2>/dev/null | python3 "$METADATA" normalize-plan)" || fail "desired increment plan is invalid"

  owned_project "$project_id" "$repository" >/dev/null
  issues="$(issue_list "$project_id")" || fail "issue discovery failed"
  current="$(raw_managed_increments "$issues" "$project_id" "$repository" "$issue_map" | jq -c 'map(del(.nativeDependencies,.projectId))')"
  removed="$(jq -cn --argjson current "$current" --argjson desired "$desired" '
    [$current[] | select(.incrementId as $id | any($desired[]; .incrementId==$id)|not)]
  ')"
  jq -e 'all(.[]; .branch==null and .pullRequest==null)' >/dev/null <<<"$removed" || fail "cannot remove an increment with branch or pull request evidence"
  uuid_map="$(jq -c 'map({key:.incrementId,value:.id})|from_entries' <<<"$current")"
  managed_native_relations "$issues" "$uuid_map" >/dev/null

  # Create all missing issues first, in topological ordinal order. An unknown
  # result is discovered by managed identity before execution continues.
  while IFS= read -r inc; do
    stable="$(jq -r '.incrementId' <<<"$inc")"
    jq -e --arg stable "$stable" 'has($stable)' >/dev/null <<<"$uuid_map" && continue
    dep_ids="$(jq -cn --argjson item "$inc" --argjson ids "$uuid_map" '[$item.dependencies[] | $ids[.]] | sort')"
    jq -e 'all(.[]; type=="string")' >/dev/null <<<"$dep_ids" || fail "dependency issue has not been created"
    parent="$(jq -r --argjson ids "$uuid_map" 'if $ids[.gitParent] then $ids[.gitParent] else .gitParent end' <<<"$inc")"
    metadata="$(jq -cn --arg projectId "$project_id" --arg repository "$repository" --arg stable "$stable" --argjson ordinal "$(jq '.ordinal' <<<"$inc")" --argjson dependencies "$dep_ids" --arg gitParent "$parent" \
      '{artifactType:"increment",projectId:$projectId,repository:$repository,schema:1,incrementId:$stable,ordinal:$ordinal,dependencies:$dependencies,gitParent:$gitParent,branch:null,pullRequest:null}')"
    description="$(compose_increment_description "$(jq -r '.content' <<<"$inc")" "$metadata")"
    variables="$(jq -cn --arg teamId "$team_id" --arg projectId "$project_id" --arg stateId "$(jq -r '.planned' <<<"$issue_map")" --arg title "$(jq -r '.title' <<<"$inc")" --arg description "$description" \
      '{input:{teamId:$teamId,projectId:$projectId,stateId:$stateId,title:$title,description:$description}}')"
    attempted="$(jq -c '.+["issueCreate"]' <<<"$attempted")"; returned=null; response_valid=true
    if response="$(request_mutation "$GRAPHQL/issue-create.graphql" "$variables")"; then
      returned="$(jq -r '.data.issueCreate.issue.id // empty' <<<"$response" 2>/dev/null || true)"
      if ! jq -e --arg project "$project_id" '
        .data.issueCreate.success==true and
        .data.issueCreate.issue.project.id==$project and
        (.data.issueCreate.issue.id|type=="string")
      ' >/dev/null 2>&1 <<<"$response"; then
        response_valid=false
      fi
    fi
    issues="$(issue_list "$project_id")" || { pending="$(jq -c '.+["issue-create-discovery"]' <<<"$pending")"; break; }
    observed="$(raw_managed_increments "$issues" "$project_id" "$repository" "$issue_map" false)"
    match="$(jq -c --arg stable "$stable" '[.[] | select(.incrementId==$stable)]' <<<"$observed")"
    [[ "$(jq 'length' <<<"$match")" -eq 1 ]] || { pending="$(jq -c '.+["issue-create-discovery"]' <<<"$pending")"; break; }
    id="$(jq -r '.[0].id' <<<"$match")"
    mutation_responses="$(jq -cn --argjson old "$mutation_responses" --arg operation issueCreate --arg stable "$stable" --arg returnedId "$([[ "$returned" == null ]] || printf '%s' "$returned")" --arg observedId "$id" \
      '$old+[{operation:$operation,incrementId:$stable,returnedId:(if $returnedId=="" then null else $returnedId end),observedId:$observedId}]')"
    if [[ "$response_valid" != true ]]; then
      pending="$(jq -c '.+["issue-create-response-verification"]' <<<"$pending")"
      break
    fi
    if [[ "$returned" != null && "$returned" != "$id" ]]; then
      pending="$(jq -c '.+["issue-create-return-mismatch"]' <<<"$pending")"
      break
    fi
    uuid_map="$(jq -c --arg stable "$stable" --arg id "$id" '.+{($stable):$id}' <<<"$uuid_map")"
  done < <(jq -c '.[]' <<<"$desired")

  # Reconcile every desired issue's owned fields while preserving execution evidence.
  if [[ "$(jq 'length' <<<"$pending")" -eq 0 ]]; then
    while IFS= read -r inc; do
      stable="$(jq -r '.incrementId' <<<"$inc")"; id="$(jq -r --arg stable "$stable" '.[$stable]' <<<"$uuid_map")"
      dep_ids="$(jq -cn --argjson item "$inc" --argjson ids "$uuid_map" '[$item.dependencies[] | $ids[.]] | sort')"
      parent="$(jq -r --argjson ids "$uuid_map" 'if $ids[.gitParent] then $ids[.gitParent] else .gitParent end' <<<"$inc")"
      old="$(jq -c --arg stable "$stable" '[.[]|select(.incrementId==$stable)] | if length==1 then .[0] else null end' <<<"$current")"
      [[ "$old" != null ]] || continue
      if jq -e --argjson old "$old" --argjson desired "$inc" --argjson dependencies "$dep_ids" --arg parent "$parent" '
        $old.title==$desired.title and $old.contentNormalized==$desired.content and
        $old.ordinal==$desired.ordinal and $old.dependencies==$dependencies and
        $old.gitParent==$parent
      ' >/dev/null; then continue; fi
      metadata="$(jq -cn --arg projectId "$project_id" --arg repository "$repository" --arg stable "$stable" --argjson ordinal "$(jq '.ordinal' <<<"$inc")" --argjson dependencies "$dep_ids" --arg gitParent "$parent" --argjson old "$old" '
        {artifactType:"increment",projectId:$projectId,repository:$repository,schema:1,incrementId:$stable,ordinal:$ordinal,dependencies:$dependencies,gitParent:$gitParent,
         branch:($old.branch // null),pullRequest:($old.pullRequest // null)}
      ')"
      description="$(compose_increment_description "$(jq -r '.content' <<<"$inc")" "$metadata")"
      variables="$(jq -cn --arg id "$id" --arg title "$(jq -r '.title' <<<"$inc")" --arg description "$description" '{id:$id,input:{title:$title,description:$description}}')"
      attempted="$(jq -c '.+["issueUpdate"]' <<<"$attempted")"
      if response="$(request_mutation "$GRAPHQL/issue-update.graphql" "$variables")"; then :; fi
      mutation_responses="$(jq -cn --argjson old "$mutation_responses" --arg operation issueUpdate --arg incrementId "$stable" --arg intendedId "$id" --arg returnedId "$(jq -r '.data.issueUpdate.issue.id // empty' <<<"${response:-{}}" 2>/dev/null)" \
        '$old+[{operation:$operation,incrementId:$incrementId,intendedId:$intendedId,returnedId:(if $returnedId=="" then null else $returnedId end)}]')"
    done < <(jq -c '.[]' <<<"$desired")
    while IFS= read -r inc; do
      attempted="$(jq -c '.+["issueUpdate:remove"]' <<<"$attempted")"
      if response="$(request_mutation "$GRAPHQL/issue-update.graphql" "$(jq -cn --arg id "$(jq -r '.id' <<<"$inc")" '{id:$id,input:{trashed:true}}')")"; then :; fi
      mutation_responses="$(jq -cn --argjson old "$mutation_responses" --arg operation issueRemove --arg incrementId "$(jq -r '.incrementId' <<<"$inc")" --arg intendedId "$(jq -r '.id' <<<"$inc")" --arg returnedId "$(jq -r '.data.issueUpdate.issue.id // empty' <<<"${response:-{}}" 2>/dev/null)" \
        '$old+[{operation:$operation,incrementId:$incrementId,intendedId:$intendedId,returnedId:(if $returnedId=="" then null else $returnedId end)}]')"
    done < <(jq -c '.[]' <<<"$removed")

    # Issue writes always precede relation rewiring.
    issues="$(issue_list "$project_id")" || fail "issue read-back failed"
    current_relations="$(managed_native_relations "$issues" "$uuid_map")"
    desired_relations="$(jq -cn --argjson desired "$desired" --argjson ids "$uuid_map" '
      [$desired[] as $item | $item.dependencies[] | {issue:$ids[$item.incrementId],dependency:$ids[.]}] | sort_by(.issue,.dependency)
    ')"
    while IFS= read -r rel; do
      key="$(jq -r '.issue+":"+ .dependency' <<<"$rel")"
      if ! jq -e --arg key "$key" 'any(.[]; (.issue+":"+ .dependency)==$key)' >/dev/null <<<"$desired_relations"; then
        attempted="$(jq -c '.+["issueRelationDelete"]' <<<"$attempted")"
        if response="$(request_mutation "$GRAPHQL/relation-delete.graphql" "$(jq -cn --arg id "$(jq -r '.id' <<<"$rel")" '{id:$id}')")"; then :; fi
        mutation_responses="$(jq -cn --argjson old "$mutation_responses" --arg operation issueRelationDelete --arg intendedId "$(jq -r '.id' <<<"$rel")" --arg issueId "$(jq -r '.issue' <<<"$rel")" --arg dependencyId "$(jq -r '.dependency' <<<"$rel")" --arg returnedId "$(jq -r '.data.issueRelationDelete.issueRelation.id // empty' <<<"${response:-{}}" 2>/dev/null)" \
          '$old+[{operation:$operation,intendedId:$intendedId,issueId:$issueId,dependencyId:$dependencyId,returnedId:(if $returnedId=="" then null else $returnedId end)}]')"
      fi
    done < <(jq -c '.[]' <<<"$current_relations")
    while IFS= read -r rel; do
      key="$(jq -r '.issue+":"+ .dependency' <<<"$rel")"
      if ! jq -e --arg key "$key" 'any(.[]; (.issue+":"+ .dependency)==$key)' >/dev/null <<<"$current_relations"; then
        attempted="$(jq -c '.+["issueRelationCreate"]' <<<"$attempted")"
        if response="$(request_mutation "$GRAPHQL/relation-create.graphql" "$(jq -cn --arg issueId "$(jq -r '.dependency' <<<"$rel")" --arg relatedIssueId "$(jq -r '.issue' <<<"$rel")" '{input:{issueId:$issueId,relatedIssueId:$relatedIssueId,type:"blocks"}}')")"; then :; fi
        mutation_responses="$(jq -cn --argjson old "$mutation_responses" --arg operation issueRelationCreate --arg issueId "$(jq -r '.issue' <<<"$rel")" --arg dependencyId "$(jq -r '.dependency' <<<"$rel")" --arg returnedId "$(jq -r '.data.issueRelationCreate.issueRelation.id // empty' <<<"${response:-{}}" 2>/dev/null)" \
          '$old+[{operation:$operation,issueId:$issueId,dependencyId:$dependencyId,returnedId:(if $returnedId=="" then null else $returnedId end)}]')"
      fi
    done < <(jq -c '.[]' <<<"$desired_relations")
  fi

  set +e
  final="$(normalized_increments "$project_id" "$repository" "$issue_map" true 2>/dev/null)"
  final_rc=$?
  set -e
  if [[ "$final_rc" -eq 0 ]]; then
    expected="$(jq -cn --argjson desired "$desired" --argjson ids "$uuid_map" '
      [$desired[] | . as $item | {
        id:$ids[.incrementId],incrementId,ordinal,title,content,contentNormalized:.content,
        dependencies:([.dependencies[] | $ids[.]] | sort),
        gitParent:(if $ids[.gitParent] then $ids[.gitParent] else .gitParent end)
      }] | sort_by(.ordinal,.id)
    ')"
    if jq -e --argjson expected "$expected" '
      map({id,incrementId,ordinal,title,contentNormalized,dependencies,gitParent}) ==
      ($expected | map({id,incrementId,ordinal,title,contentNormalized,dependencies,gitParent}))
    ' >/dev/null <<<"$final"; then
      verified=true
      if jq -e --argjson desired "$desired" '
        any(.[]; . as $got | any($desired[]; .incrementId==$got.incrementId and .content!=$got.content))
      ' >/dev/null <<<"$final"; then normalized=true; fi
    else pending="$(jq -c '.+["final-plan-verification"]' <<<"$pending")"; fi
  else pending="$(jq -c '.+["final-dag-verification"]' <<<"$pending")"; fi
  operation_status="$(jq -cn --argjson mutations "$mutation_responses" --argjson final "${final:-[]}" --argjson desired "$desired" --argjson ids "$uuid_map" '
    def issue_ok($stable):
      ([ $desired[] | select(.incrementId==$stable) ][0]) as $want |
      ([ $final[] | select(.incrementId==$stable) ][0]) as $got |
      ($got != null and $got.title==$want.title and $got.contentNormalized==$want.content and
       $got.ordinal==$want.ordinal and
       $got.dependencies==([$want.dependencies[] | $ids[.]] | sort) and
       $got.gitParent==(if $ids[$want.gitParent] then $ids[$want.gitParent] else $want.gitParent end));
    def observed($mutation):
      if $mutation.operation=="issueCreate" then
        ($mutation.returnedId==null or $mutation.returnedId==$mutation.observedId) and issue_ok($mutation.incrementId)
      elif $mutation.operation=="issueUpdate" then issue_ok($mutation.incrementId)
      elif $mutation.operation=="issueRemove" then all($final[]; .incrementId!=$mutation.incrementId)
      elif $mutation.operation=="issueRelationCreate" then
        any($final[]; .id==$mutation.issueId and (.dependencies|index($mutation.dependencyId))!=null)
      elif $mutation.operation=="issueRelationDelete" then
        all($final[]; .id!=$mutation.issueId or (.dependencies|index($mutation.dependencyId))==null)
      else false end;
    reduce $mutations[] as $mutation ({completed:[],pending:[]};
      if observed($mutation) then
        .completed += [if $mutation.operation=="issueRemove" then "issueUpdate:remove" else $mutation.operation end]
      else .pending += [($mutation.operation+"-read-back")] end)
  ')"
  completed="$(jq -c '.completed' <<<"$operation_status")"
  pending="$(jq -cn --argjson existing "$pending" --argjson operations "$(jq -c '.pending' <<<"$operation_status")" '$existing+$operations|unique')"
  jq -cn --argjson desired "$desired" --argjson uuidMap "$uuid_map" --argjson attempted "$attempted" --argjson completed "$completed" --argjson pending "$pending" --argjson mutations "$mutation_responses" --argjson final "${final:-null}" --argjson relations "${desired_relations:-[]}" --argjson verified "$verified" --argjson normalized "$normalized" '
    {
      intended:{operations:$attempted,increments:[$desired[]|{incrementId,ordinal,dependencies,gitParent}]},
      observed:{issueIds:($uuidMap|to_entries|map({incrementId:.key,id:.value})),relations:$relations},
      returned:{mutations:$mutations},
      readBack:{increments:(if ($final|type)=="array" then [$final[]|{id,incrementId,ordinal,dependencies,gitParent,status}] else null end),dagVerified:$verified},
      attempted:$attempted,completed:$completed,pending:$pending,remainingSubsteps:$pending,
      outcome:(if $verified and $normalized then "writtenButNormalized" elif $verified then "verified" elif ($attempted|length)>0 then "attemptedWithUnknown" else "attempted" end),
      verified:$verified
    }'
  [[ "$verified" == true && "$(jq 'length' <<<"$pending")" -eq 0 ]]
}

[[ $# -gt 0 ]] || usage
command="$1"; shift
case "$command" in
  preflight) command_preflight "$@";;
  feature-resolve) command_feature_resolve "$@";;
  identity-resolve) command_identity_resolve "$@";;
  feature-create) command_feature_create "$@";;
  feature-transition) command_feature_transition "$@";;
  spec-read) command_spec_read "$@";;
  spec-write) command_spec_write "$@";;
  plan-read) command_plan_read "$@";;
  plan-reconcile) command_plan_reconcile "$@";;
  issue-transition) command_issue_transition "$@";;
  feature-read) command_feature_read "$@";;
  doctor-read) command_doctor_read "$@";;
  status-reconcile) command_status_reconcile "$@";;
  provenance-parse) command_provenance_parse "$@";;
  provenance-resolve) command_provenance_resolve "$@";;
  *) usage;;
esac
