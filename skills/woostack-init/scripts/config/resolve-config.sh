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
  if jq -e 'has("artifacts") or has("linear") or has("plane")' <<<"$content" >/dev/null; then
    printf '%s: retired provider settings remain untouched on disk and are omitted from active configuration; use optional top-level github policy for direct GitHub operations.\n' "$display_name" >&2
  fi
  content="$(jq -c 'del(.artifacts, .linear, .plane)' <<<"$content")"


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

validate_github() {
  local cfg="$1"
  local file_label="$2"
  local github_allowed='["owner","ownerType","statusField","projectStatuses"]'
  local status_keys='["planned","executing","inReview","done","blocked"]'

  if ! jq -e 'if has("github") then .github | type == "object" else true end' <<<"$cfg" >/dev/null 2>&1; then
    fail "$file_label github policy must be a JSON object"
  fi
  if ! jq -e --argjson allowed "$github_allowed" '
    if has("github") then (.github | ((keys - $allowed) | length == 0)) else true end
  ' <<<"$cfg" >/dev/null 2>&1; then
    fail "$file_label github policy permits only owner, ownerType, statusField, and projectStatuses"
  fi
  if ! jq -e '
    if has("github") then
      .github
      | (if has("owner") then (.owner | type == "string"
          and test("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$")) else true end)
        and (if has("ownerType") then (.ownerType == "organization" or .ownerType == "user") else true end)
        and (if has("statusField") then (.statusField | type == "string" and test("\\S")) else true end)
        and (if has("projectStatuses") then (.projectStatuses | type == "object") else true end)
    else true end
  ' <<<"$cfg" >/dev/null 2>&1; then
    fail "$file_label github policy contains invalid values"
  fi
  if ! jq -e --argjson keys "$status_keys" '
    if has("github") and (.github | has("projectStatuses")) then
      (.github.projectStatuses | keys | sort) == ($keys | sort)
      and all(.github.projectStatuses[]; type == "string" and test("\\S"))
      and ((.github.projectStatuses | [.[]] | unique | length) == ($keys | length))
    else true end
  ' <<<"$cfg" >/dev/null 2>&1; then
    fail "$file_label github projectStatuses mapping is incomplete or contains invalid values"
  fi
}

base_config="$(read_and_validate_file "$config_path" ".woostack/config.json")"

if [ "$has_local" -eq 1 ]; then
  local_config="$(read_and_validate_file "$local_path" ".woostack/config.local.json")"
  effective="$(jq -n --argjson base "$base_config" --argjson local "$local_config" '
    def deep_merge(base; local):
      if (base | type) == "object" and (local | type) == "object" then
        reduce (local | keys_unsorted)[] as $k (
          base;
          if (base | has($k)) and (base[$k] | type) == "object" and (local[$k] | type == "object") then
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

validate_github "$effective" "canonical GitHub policy"
printf '%s\n' "$effective"
