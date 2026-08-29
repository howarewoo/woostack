#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../path-args.sh
. "$SCRIPT_DIR/../path-args.sh"

usage() {
  printf 'usage: %s <repo-root>\n' "${0##*/}" >&2
  exit 2
}

fail() {
  printf 'resolve-config: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage
repo_root="$(cd "$1" 2>/dev/null && pwd -P)" || fail "repository root is unavailable"

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$common_dir" ]; then
  case "$common_dir" in
    /*) common_root="$common_dir" ;;
    *) common_root="$(cd "$repo_root/$common_dir" 2>/dev/null && pwd -P || true)" ;;
  esac
  if [ -n "$common_root" ] && [ -d "$common_root" ]; then
    primary_root="$(cd "$(dirname "$common_root")" 2>/dev/null && pwd -P)" || fail "Git common directory is invalid"
  else
    fail "Git common directory is invalid"
  fi
else
  primary_root="$repo_root"
fi

config_path="$repo_root/.woostack/config.json"
local_path="$primary_root/.woostack/config.local.json"

has_config=0
has_local=0
if [ -e "$config_path" ] || [ -L "$config_path" ]; then
  has_config=1
fi
if [ -e "$local_path" ] || [ -L "$local_path" ]; then
  has_local=1
fi

if [ "$has_config" -eq 0 ] && [ "$has_local" -eq 0 ]; then
  printf '{}\n'
  exit 0
fi

if [ "$has_config" -eq 0 ]; then
  fail ".woostack/config.json is missing"
fi

read_and_validate_file() {
  local file_path="$1"
  local display_name="$2"

  if [ -L "$file_path" ]; then
    fail "$display_name must not be a symlink"
  fi
  if [ ! -f "$file_path" ]; then
    fail "$display_name must be a regular file"
  fi
  if [ ! -r "$file_path" ]; then
    fail "$display_name is not readable"
  fi
  if [ ! -s "$file_path" ]; then
    fail "$display_name must not be empty"
  fi

  local content
  if ! content="$(jq -e -c 'if type == "object" then . else error("non-object") end' "$(tool_path_arg jq "$file_path")" 2>/dev/null)"; then
    if jq -e . "$(tool_path_arg jq "$file_path")" >/dev/null 2>&1; then
      fail "$display_name must contain a JSON object"
    else
      if [ -z "$(tr -d '[:space:]' < "$file_path")" ]; then
        fail "$display_name must not be empty"
      else
        fail "$display_name must contain valid JSON"
      fi
    fi
  fi

  local cred_key
  cred_key="$(jq -r '
    [
      paths as $p
      | ($p | map(tostring) | join(".")) as $name
      | select($name | test("api.?key|token|secret|password|authorization|credential"; "i"))
      | $name
    ] | first // empty
  ' <<<"$content" 2>/dev/null || true)"
  if [ -n "$cred_key" ]; then
    fail "$display_name contains credential-like key: $cred_key"
  fi

  printf '%s\n' "$content"
}

check_legacy() {
  local cfg="$1"
  local file_label="$2"
  if jq -e 'has("linear") and (.linear | type == "object") and (.linear | has("saveArtifacts")) or (has("artifacts") and (.artifacts | type == "object") and ((.artifacts | has("saveArtifacts")) or (.artifacts.linear? | type == "object" and has("saveArtifacts"))))' <<<"$cfg" >/dev/null 2>&1; then
    fail "$file_label linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear"
  fi
}

base_config="$(read_and_validate_file "$config_path" ".woostack/config.json")"
check_legacy "$base_config" ".woostack/config.json"

if [ "$has_local" -eq 1 ]; then
  local_config="$(read_and_validate_file "$local_path" ".woostack/config.local.json")"
  check_legacy "$local_config" ".woostack/config.local.json"
  effective="$(jq -n --argjson base "$base_config" --argjson local "$local_config" '
    def deep_merge(base; local):
      if (base | type) == "object" and (local | type) == "object" then
        reduce (local | keys_unsorted)[] as $k (
          base;
          if (base | has($k)) and (base[$k] | type) == "object" and (local[$k] | type) == "object" then
            .[$k] = deep_merge(base[$k]; local[$k])
          else
            .[$k] = local[$k]
          end
        )
      else
        local
      end;
    deep_merge($base; $local)
  ')"
else
  effective="$base_config"
fi

target_file() {
  local filter="$1"
  if [ "$has_local" -eq 1 ] && jq -e "$filter" <<<"$local_config" >/dev/null 2>&1; then
    printf '%s' ".woostack/config.local.json"
  else
    printf '%s' ".woostack/config.json"
  fi
}

if jq -e 'has("artifacts")' <<<"$effective" >/dev/null 2>&1; then
  if ! jq -e '.artifacts | type == "object"' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts | type != "object")') artifacts must be a JSON object"
  fi
  if jq -e '.artifacts | has("provider")' <<<"$effective" >/dev/null 2>&1; then
    if ! jq -e '.artifacts.provider | type == "string" and (. == "local" or . == "github" or . == "linear" or . == "plane")' <<<"$effective" >/dev/null 2>&1; then
      fail "$(target_file 'has("artifacts") and (.artifacts | has("provider")) and ((.artifacts.provider | type != "string") or (.artifacts.provider != "local" and .artifacts.provider != "github" and .artifacts.provider != "linear" and .artifacts.provider != "plane"))') artifacts.provider must be \"local\", \"github\", \"linear\", or \"plane\""
    fi
  fi
fi

provider="$(jq -r '.artifacts.provider // "local"' <<<"$effective")"
project_keys='["backlog","planned","started","completed","canceled"]'
issue_keys='["planned","executing","inReview","done","blocked"]'
linear_allowed='["repository","workspace","team","projectLabels","projectStatuses","issueStates"]'
plane_allowed='["baseUrl","workspace","repository","project","projectLabels","issueStates"]'
github_allowed='["owner","ownerType","statusField","visibility","projectStatuses"]'
if [ "$provider" = "github" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("github")) and (.artifacts.github | type == "object")' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts | has("github") and (.artifacts.github | type != "object")) or (.artifacts.provider? == "github" and (.artifacts.github? | type != "object")))') github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  fi
  if ! jq -e --argjson allowed "$github_allowed" '
    .artifacts.github | type == "object" and ((keys - $allowed) | length == 0)
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.github? | type == "object" and ((keys - ["owner","ownerType","statusField","visibility","projectStatuses"]) | length > 0))') github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  fi
  if ! jq -e '
    .artifacts.github
    and (.artifacts.github.owner | type == "string"
      and test("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$"))
    and (if .artifacts.github | has("ownerType") then (.artifacts.github.ownerType == "organization" or .artifacts.github.ownerType == "user") else true end)
    and (if .artifacts.github | has("statusField") then (.artifacts.github.statusField | type == "string" and test("\\S")) else true end)
    and (if .artifacts.github | has("visibility") then (.artifacts.github.visibility == "private" or .artifacts.github.visibility == "public") else true end)
    and (.artifacts.github.projectStatuses | type == "object")
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts.provider? == "github") or (.artifacts | has("github")))') github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  fi
  if ! jq -e --argjson keys "$issue_keys" '
    (.artifacts.github.projectStatuses | keys | sort) == ($keys | sort)
    and all(.artifacts.github.projectStatuses[]; type == "string" and test("\\S"))
    and ((.artifacts.github.projectStatuses | [.[]] | unique | length) == ($keys | length))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.github? | has("projectStatuses"))') projectStatuses mapping is incomplete or contains invalid values"
  fi
elif [ "$provider" = "linear" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("linear")) and (.artifacts.linear | type == "object")' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts | has("linear") and (.artifacts.linear | type != "object")) or (.artifacts.provider? == "linear" and (.artifacts.linear? | type != "object")))') linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  fi
  if ! jq -e --argjson allowed "$linear_allowed" '
    .artifacts.linear | type == "object" and ((keys - $allowed) | length == 0)
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.linear? | type == "object" and ((keys - ["repository","workspace","team","projectLabels","projectStatuses","issueStates"]) | length > 0))') linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  fi
  if ! jq -e '
    .artifacts.linear
    and (.artifacts.linear.repository | type == "string"
      and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
    and (.artifacts.linear.workspace | type == "string" and test("\\S"))
    and (.artifacts.linear.team | type == "string" and test("\\S"))
    and (.artifacts.linear | has("projectLabels"))
    and (.artifacts.linear.projectStatuses | type == "object")
    and (.artifacts.linear.issueStates | type == "object")
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts.linear? | type == "object" and ((has("repository") and ((.repository | type != "string") or (.repository | test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$") | not))) or (has("workspace") and ((.workspace | type != "string") or (.workspace | test("\\S") | not))) or (has("team") and ((.team | type != "string") or (.team | test("\\S") | not))) or (has("projectStatuses") and (.projectStatuses | type != "object")) or (has("issueStates") and (.issueStates | type != "object")))) or (.artifacts.provider? == "linear" and ((.artifacts.linear? | type != "object") or (.artifacts.linear.repository? | (type != "string") or (test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$") | not)) or (.artifacts.linear.workspace? | (type != "string") or (test("\\S") | not)) or (.artifacts.linear.team? | (type != "string") or (test("\\S") | not)) or (.artifacts.linear.projectStatuses? | type != "object") or (.artifacts.linear.issueStates? | type != "object"))))') linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  fi
  if ! jq -e --argjson keys "$project_keys" '
    (.artifacts.linear.projectStatuses | keys | sort) == ($keys | sort)
    and all(.artifacts.linear.projectStatuses[]; type == "string" and test("\\S"))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.linear? | has("projectStatuses"))') projectStatuses mapping is incomplete or contains invalid values"
  fi
  if ! jq -e --argjson keys "$issue_keys" '
    (.artifacts.linear.issueStates | keys | sort) == ($keys | sort)
    and all(.artifacts.linear.issueStates[]; type == "string" and test("\\S"))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.linear? | has("issueStates"))') issueStates mapping is incomplete or contains invalid values"
  fi
  if ! jq -e '
    .artifacts.linear.projectLabels | type == "array" and all(.[]; type == "string" and test("\\S"))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.linear? | has("projectLabels"))') projectLabels must be an array of non-empty strings"
  fi
elif [ "$provider" = "plane" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("plane")) and (.artifacts.plane | type == "object")' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts | has("plane") and (.artifacts.plane | type != "object")) or (.artifacts.provider? == "plane" and (.artifacts.plane? | type != "object")))') plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  fi
  if ! jq -e --argjson allowed "$plane_allowed" '
    .artifacts.plane | type == "object" and ((keys - $allowed) | length == 0)
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.plane? | type == "object" and ((keys - ["baseUrl","workspace","repository","project","projectLabels","issueStates"]) | length > 0))') plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  fi
  if ! jq -e '
    .artifacts.plane
    and (.artifacts.plane.baseUrl | type == "string" and test("^https?://[^?#\\s]+$"))
    and (.artifacts.plane.workspace | type == "string" and test("\\S"))
    and (.artifacts.plane.repository | type == "string"
      and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
    and (.artifacts.plane.project | type == "string" and test("\\S"))
    and (.artifacts.plane | has("projectLabels"))
    and (.artifacts.plane.issueStates | type == "object")
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and ((.artifacts.provider? == "plane") or (.artifacts | has("plane")))') plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  fi
  if ! jq -e --argjson keys "$issue_keys" '
    (.artifacts.plane.issueStates | keys | sort) == ($keys | sort)
    and all(.artifacts.plane.issueStates[]; type == "string" and test("\\S"))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.plane? | has("issueStates"))') issueStates mapping is incomplete or contains invalid values"
  fi
  if ! jq -e '
    .artifacts.plane.projectLabels | type == "array" and length > 0 and all(.[]; type == "string" and test("\\S"))
  ' <<<"$effective" >/dev/null 2>&1; then
    fail "$(target_file 'has("artifacts") and (.artifacts.plane? | has("projectLabels"))') projectLabels must be an array of non-empty strings"
  fi
  effective="$(jq '
    .artifacts.plane.baseUrl |= (
      sub("/+$"; "")
      | if test("^https?://(api|app)\\.plane\\.so$"; "i") then
          "https://api.plane.so"
        else
          .
        end
    )
  ' <<<"$effective")"
fi
printf '%s\n' "$effective"
