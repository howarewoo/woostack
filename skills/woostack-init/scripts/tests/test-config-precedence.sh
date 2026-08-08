#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$HERE/../config/resolve-config.sh"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
worktree="$TMP/worktree"
mkdir -p "$repo/.woostack"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name Test
cat >"$repo/.woostack/config.json" <<'JSON'
{"linear":{"repository":"https://github.com/acme/widgets","workspace":"acme","team":"DEFAULT","projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}
JSON
git -C "$repo" add .woostack/config.json
git -C "$repo" commit -qm init

actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.linear.team' <<<"$actual")" "DEFAULT" "committed team is used without a local override"

cat >"$repo/.woostack/config.local.json" <<'JSON'
{"linear":{"team":"LOCAL"}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.linear.team' <<<"$actual")" "LOCAL" "primary checkout local team overrides committed policy"

git -C "$repo" worktree add -q "$worktree"
actual="$(bash "$RESOLVER" "$worktree")"
assert_eq "$(jq -r '.linear.team' <<<"$actual")" "LOCAL" "linked worktree inherits the primary checkout local team"

printf '%s\n' '{"linear":{"team":"LOCAL","workspace":"forbidden"}}' >"$repo/.woostack/config.local.json"
if bash "$RESOLVER" "$worktree" >"$TMP/out" 2>"$TMP/err"; then
  fail "unsupported local override should fail"
else
  pass
fi
assert_contains "$(cat "$TMP/err")" "may override only" "unsupported local keys fail closed"

printf '%s\n' '{"linear":{"team":"   "}}' >"$repo/.woostack/config.local.json"
if bash "$RESOLVER" "$repo" >"$TMP/out" 2>"$TMP/err"; then
  fail "blank local team should fail"
else
  pass
fi
assert_contains "$(cat "$TMP/err")" "nonblank linear.team" "blank local team fails closed"

assert_contains "$(cat "$HERE/../../templates/gitignore")" "*.local.*" "local config is ignored by the workspace template"
finish
