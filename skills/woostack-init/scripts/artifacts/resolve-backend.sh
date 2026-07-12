#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s <repo-root>\n' "${0##*/}" >&2
  exit 2
}

error_path() {
  printf 'resolve-backend: invalid config at %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage
repo_root="$1"
config_path="$repo_root/.woostack/config.json"

if [ -e "$config_path" ]; then
  if ! config="$(jq -c 'if type == "object" then . else error("root must be an object") end' "$config_path" 2>/dev/null)"; then
    error_path '.woostack/config.json'
  fi
else
  config='{}'
fi

secret_path="$(jq -r '
  first(
    .linear? // {} |
    paths as $path |
    ($path[-1] |
      if type == "string"
      then ascii_downcase | gsub("[^a-z0-9]"; "")
      else ""
      end
    ) as $key |
    select(
      ($key | test("(apikey|token|credentials?(file|path)|authorization|password|secret|privatekey|accesskey)"))
    ) |
    $path | map(if type == "number" then "[\(.)]" else . end) | join(".")
  ) // empty
' <<<"$config")"
if [ -n "$secret_path" ]; then
  error_path "linear.$secret_path"
fi

unknown_linear_path="$(jq -r '
  first(
    (.linear? | objects | keys[] as $key |
      select(["workspace", "team", "repository", "projectStatuses", "issueStates"] | index($key) | not) |
      ["linear", $key]),
    (.linear?.projectStatuses? | objects | keys[] as $key |
      select(["draft", "hardened", "approved", "planning", "ready", "executing", "inReview", "done", "abandoned"] | index($key) | not) |
      ["linear", "projectStatuses", $key]),
    (.linear?.issueStates? | objects | keys[] as $key |
      select(["planned", "executing", "inReview", "done", "blocked"] | index($key) | not) |
      ["linear", "issueStates", $key])
  ) // empty |
  join(".")
' <<<"$config")"
if [ -n "$unknown_linear_path" ]; then
  error_path "$unknown_linear_path"
fi

if ! jq -e '
  (has("artifacts") | not) or
  ((.artifacts | type) == "object")
' >/dev/null 2>&1 <<<"$config"; then
  error_path 'artifacts'
fi
if ! jq -e '
  ((.artifacts // {}) | has("specPlan") | not) or
  ((.artifacts.specPlan | type) == "string")
' >/dev/null 2>&1 <<<"$config"; then
  error_path 'artifacts.specPlan'
fi

backend="$(jq -r '.artifacts.specPlan // "markdown"' <<<"$config")"
case "$backend" in
  markdown)
    printf '%s\n' '{"backend":"markdown","repository":null,"linear":null}'
    exit 0
    ;;
  linear)
    ;;
  *)
    error_path 'artifacts.specPlan'
    ;;
esac

if ! jq -e '.linear | type == "object"' >/dev/null 2>&1 <<<"$config"; then
  error_path 'linear'
fi

require_string() {
  local path="$1"
  if ! jq -e --arg path "$path" '
    getpath($path | split(".")) as $value |
    ($value | type) == "string" and ($value | test("\\S"))
  ' >/dev/null 2>&1 <<<"$config"; then
    error_path "$path"
  fi
}

require_string 'linear.workspace'
require_string 'linear.team'

project_mappings=(draft hardened approved planning ready executing inReview "done" abandoned)
for mapping in "${project_mappings[@]}"; do
  require_string "linear.projectStatuses.$mapping"
done

issue_mappings=(planned executing inReview "done" blocked)
for mapping in "${issue_mappings[@]}"; do
  require_string "linear.issueStates.$mapping"
done

valid_repository_identity() {
  local identity="$1"
  local name="${identity#*/}"
  [[ "$identity" =~ ^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])/[A-Za-z0-9._-]+$ ]] &&
    [ "$name" != '.' ] &&
    [ "$name" != '..' ]
}

if jq -e '.linear | has("repository")' >/dev/null <<<"$config"; then
  if ! jq -e '.linear.repository | type == "string"' >/dev/null 2>&1 <<<"$config"; then
    error_path 'linear.repository'
  fi
  repository="$(jq -r '.linear.repository' <<<"$config")"
  if ! valid_repository_identity "$repository"; then
    error_path 'linear.repository'
  fi
else
  remote="$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null || true)"
  case "$remote" in
    git@github.com:*) repository="${remote#git@github.com:}" ;;
    https://github.com/*) repository="${remote#https://github.com/}" ;;
    http://github.com/*) repository="${remote#http://github.com/}" ;;
    ssh://git@github.com/*) repository="${remote#ssh://git@github.com/}" ;;
    git://github.com/*) repository="${remote#git://github.com/}" ;;
    *) repository='' ;;
  esac
  repository="${repository%/}"
  repository="${repository%.git}"
  if ! valid_repository_identity "$repository"; then
    error_path 'linear.repository'
  fi
fi

jq -c --arg repository "$repository" '{
  backend: "linear",
  repository: $repository,
  linear: {
    workspace: .linear.workspace,
    team: .linear.team,
    projectStatuses: {
      draft: .linear.projectStatuses.draft,
      hardened: .linear.projectStatuses.hardened,
      approved: .linear.projectStatuses.approved,
      planning: .linear.projectStatuses.planning,
      ready: .linear.projectStatuses.ready,
      executing: .linear.projectStatuses.executing,
      inReview: .linear.projectStatuses.inReview,
      done: .linear.projectStatuses.done,
      abandoned: .linear.projectStatuses.abandoned
    },
    issueStates: {
      planned: .linear.issueStates.planned,
      executing: .linear.issueStates.executing,
      inReview: .linear.issueStates.inReview,
      done: .linear.issueStates.done,
      blocked: .linear.issueStates.blocked
    }
  }
}' <<<"$config"
