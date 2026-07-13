#!/usr/bin/env bash
set -euo pipefail
unset LINEAR_API_KEY

usage() {
  echo 'usage: linear-preflight.sh --response <path> --workspace <name-or-key> --team <name-or-key> --project-statuses <json> --issue-states <json>' >&2
  exit 2
}

fail_preflight() {
  local classification="$1"
  local path="$2"
  echo "linear-preflight: classification=$classification path=$path" >&2
  exit 1
}

response=''
workspace=''
team=''
project_statuses=''
issue_states=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --response)
      [ "$#" -ge 2 ] || usage
      response="$2"
      shift 2
      ;;
    --workspace)
      [ "$#" -ge 2 ] || usage
      workspace="$2"
      shift 2
      ;;
    --team)
      [ "$#" -ge 2 ] || usage
      team="$2"
      shift 2
      ;;
    --project-statuses)
      [ "$#" -ge 2 ] || usage
      project_statuses="$2"
      shift 2
      ;;
    --issue-states)
      [ "$#" -ge 2 ] || usage
      issue_states="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

[ -n "$response" ] && [ -f "$response" ] && [ -r "$response" ] || fail_preflight invalid_input response
[ -n "$workspace" ] || fail_preflight invalid_input linear.workspace
[ -n "$team" ] || fail_preflight invalid_input linear.team
if ! jq -e 'type == "object" and length > 0 and all(.[]; type == "string" and test("[^[:space:]]")) and all(keys[]; test("^[A-Za-z][A-Za-z0-9]*$"))' >/dev/null 2>&1 <<<"$project_statuses"; then
  fail_preflight invalid_input linear.projectStatuses
fi
if ! jq -e 'type == "object" and length > 0 and all(.[]; type == "string" and test("[^[:space:]]")) and all(keys[]; test("^[A-Za-z][A-Za-z0-9]*$"))' >/dev/null 2>&1 <<<"$issue_states"; then
  fail_preflight invalid_input linear.issueStates
fi
if ! jq -e '
  type == "object" and
  ((.errors? // []) | length == 0) and
  (.data.viewer.id | type == "string" and length > 0) and
  (.data.viewer.active | type == "boolean") and
  (.data.viewer.organization | type == "object") and
  (.data.teams.nodes | type == "array") and
  (.data.teams.pageInfo.hasNextPage | type == "boolean") and
  (.data.projectStatuses.nodes | type == "array") and
  (.data.projectStatuses.pageInfo.hasNextPage | type == "boolean") and
  (.data.workflowStates.nodes | type == "array") and
  (.data.workflowStates.pageInfo.hasNextPage | type == "boolean") and
  (.data.mutationCapabilities.fields | type == "array")
' "$response" >/dev/null 2>&1; then
  fail_preflight invalid_preflight_response response
fi
for connection in teams projectStatuses workflowStates; do
  if [ "$(jq -r --arg connection "$connection" '.data[$connection].pageInfo.hasNextPage' "$response")" = true ]; then
    fail_preflight incomplete_preflight_response "data.$connection.pageInfo.hasNextPage"
  fi
done

[ "$(jq -r '.data.viewer.active' "$response")" = true ] ||
  fail_preflight access_denied data.viewer.active
viewer_id="$(jq -r '.data.viewer.id' "$response")"

workspace_count="$(jq -r --arg wanted "$workspace" '[.data.viewer.organization | select(.name == $wanted or .urlKey == $wanted)] | length' "$response")"
case "$workspace_count" in
  1) ;;
  0) fail_preflight missing_mapping linear.workspace ;;
  *) fail_preflight ambiguous_mapping linear.workspace ;;
esac
workspace_id="$(jq -r --arg wanted "$workspace" '.data.viewer.organization | select(.name == $wanted or .urlKey == $wanted) | .id' "$response")"
[ -n "$workspace_id" ] && [ "$workspace_id" != null ] || fail_preflight invalid_preflight_response data.viewer.organization.id

team_count="$(jq -r --arg wanted "$team" '[.data.teams.nodes[] | select(.name == $wanted or .key == $wanted)] | length' "$response")"
case "$team_count" in
  1) ;;
  0) fail_preflight missing_mapping linear.team ;;
  *) fail_preflight ambiguous_mapping linear.team ;;
esac
team_id="$(jq -r --arg wanted "$team" '.data.teams.nodes[] | select(.name == $wanted or .key == $wanted) | .id' "$response")"
[ -n "$team_id" ] && [ "$team_id" != null ] || fail_preflight invalid_preflight_response data.teams.nodes.id

resolved_project_statuses='{}'
while IFS= read -r semantic; do
  configured="$(jq -r --arg semantic "$semantic" '.[$semantic]' <<<"$project_statuses")"
  match_count="$(jq -r --arg configured "$configured" '[.data.projectStatuses.nodes[] | select(.name == $configured)] | length' "$response")"
  case "$match_count" in
    1) ;;
    0) fail_preflight missing_mapping "linear.projectStatuses.$semantic" ;;
    *) fail_preflight ambiguous_mapping "linear.projectStatuses.$semantic" ;;
  esac
  resolved_id="$(jq -r --arg configured "$configured" '.data.projectStatuses.nodes[] | select(.name == $configured) | .id' "$response")"
  [ -n "$resolved_id" ] && [ "$resolved_id" != null ] || fail_preflight invalid_preflight_response data.projectStatuses.nodes.id
  resolved_project_statuses="$(jq -c --arg semantic "$semantic" --arg id "$resolved_id" '.[$semantic] = $id' <<<"$resolved_project_statuses")"
done < <(jq -r 'keys[]' <<<"$project_statuses")

resolved_issue_states='{}'
while IFS= read -r semantic; do
  configured="$(jq -r --arg semantic "$semantic" '.[$semantic]' <<<"$issue_states")"
  match_count="$(jq -r --arg configured "$configured" --arg team_id "$team_id" '[.data.workflowStates.nodes[] | select(.team.id == $team_id and .name == $configured)] | length' "$response")"
  case "$match_count" in
    1) ;;
    0) fail_preflight missing_mapping "linear.issueStates.$semantic" ;;
    *) fail_preflight ambiguous_mapping "linear.issueStates.$semantic" ;;
  esac
  resolved_id="$(jq -r --arg configured "$configured" --arg team_id "$team_id" '.data.workflowStates.nodes[] | select(.team.id == $team_id and .name == $configured) | .id' "$response")"
  [ -n "$resolved_id" ] && [ "$resolved_id" != null ] || fail_preflight invalid_preflight_response data.workflowStates.nodes.id
  resolved_issue_states="$(jq -c --arg semantic "$semantic" --arg id "$resolved_id" '.[$semantic] = $id' <<<"$resolved_issue_states")"
done < <(jq -r 'keys[]' <<<"$issue_states")

for capability in projectCreate projectUpdate documentCreate documentUpdate issueCreate issueUpdate issueRelationCreate; do
  if ! jq -e --arg capability "$capability" 'any(.data.mutationCapabilities.fields[]; .name == $capability)' "$response" >/dev/null 2>&1; then
    fail_preflight missing_capability "schema.mutation.$capability"
  fi
done

jq -cnS \
  --arg viewer_id "$viewer_id" \
  --arg workspace_id "$workspace_id" \
  --arg team_id "$team_id" \
  --argjson project_statuses "$resolved_project_statuses" \
  --argjson issue_states "$resolved_issue_states" \
  '{viewer: {id: $viewer_id}, workspace: {id: $workspace_id}, team: {id: $team_id}, projectStatuses: $project_statuses, issueStates: $issue_states}'
