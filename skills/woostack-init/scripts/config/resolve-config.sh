#!/usr/bin/env bash
set -euo pipefail

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
config_path="$repo_root/.woostack/config.json"
[ -f "$config_path" ] || fail ".woostack/config.json is missing"
if ! config="$(jq -c 'if type == "object" then . else error("root") end' "$config_path" 2>/dev/null)"; then
  fail ".woostack/config.json must contain an object"
fi

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$common_dir" ]; then
  case "$common_dir" in
    /*) common_root="$common_dir" ;;
    *) common_root="$repo_root/$common_dir" ;;
  esac
  primary_root="$(cd "$(dirname "$common_root")" 2>/dev/null && pwd -P)" || fail "Git common directory is invalid"
else
  primary_root="$repo_root"
fi

local_path="$primary_root/.woostack/config.local.json"
[ -e "$local_path" ] || { printf '%s\n' "$config"; exit 0; }
[ -f "$local_path" ] || fail ".woostack/config.local.json must be a regular file"
if ! local_config="$(jq -c '
  if type == "object"
    and keys == ["linear"]
    and (.linear | type == "object" and keys == ["team"])
    and (.linear.team | type == "string" and test("\\S"))
  then .
  else error("shape")
  end
' "$local_path" 2>/dev/null)"; then
  fail ".woostack/config.local.json may override only a nonblank linear.team"
fi

jq -c --arg team "$(jq -r '.linear.team' <<<"$local_config")" '.linear.team = $team' <<<"$config"
