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
git -C "$repo" init -q && git -C "$repo" config user.email t@t && git -C "$repo" config user.name t

must_fail() { # $1=target, $2=expected_err_substring, $3=desc
  local out="$TMP/out" err="$TMP/err"
  if bash "$RESOLVER" "$1" >"$out" 2>"$err"; then fail "$3"; else pass "$3"; fi
  assert_contains "$(cat "$err")" "$2" "$3"
}

# 1. Base-only policy & 2. Recursive merge with local addition and sibling preservation
cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"local","linear":{"repository":"https://github.com/a/b","workspace":"acme","team":"DEFAULT"}},"review":{"severity_floor":"high","nits":true,"angles":{"skip":["seo"]}},"models":{"standard":"gpt-5.5"}}
JSON
git -C "$repo" add .woostack/config.json && git -C "$repo" commit -qm "init config"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.linear.team' <<<"$actual")" "DEFAULT" "committed team is used"

cat >"$repo/.woostack/config.local.json" <<'JSON'
{"artifacts":{"linear":{"team":"LOCAL"}},"review":{"severity_floor":"low","custom":"opt"},"status":{"staleDays":7}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.linear.team' <<<"$actual")" "LOCAL" "local team overrides"
assert_eq "$(jq -r '.artifacts.linear.workspace' <<<"$actual")" "acme" "sibling linear keys preserved"
assert_eq "$(jq -r '.review.severity_floor' <<<"$actual")" "low" "nested setting overridden"
assert_eq "$(jq -r '.review.nits' <<<"$actual")" "true" "sibling review keys preserved"
assert_eq "$(jq -r '.review.custom' <<<"$actual")" "opt" "local additions preserved"
assert_eq "$(jq -r '.status.staleDays' <<<"$actual")" "7" "top additions preserved"
assert_eq "$(jq -r '.models.standard' <<<"$actual")" "gpt-5.5" "base objects preserved"
# 3. Scalar/array/null replacement & 4. Linked worktrees
cat >"$repo/.woostack/config.local.json" <<'JSON'
{"review":{"angles":{"skip":["database"]}},"models":null}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -c '.review.angles.skip' <<<"$actual")" '["database"]' "local array replaces"
assert_eq "$(jq -r '.models' <<<"$actual")" "null" "local null replaces"
git -C "$repo" worktree add -q "$worktree"
actual="$(bash "$RESOLVER" "$worktree")"
assert_eq "$(jq -c '.review.angles.skip' <<<"$actual")" '["database"]' "worktree inherits local"

# 5. Both absent & 6. Orphaned local & 7. Empty base config
mkdir -p "$TMP/empty_repo" "$TMP/orphan/.woostack" "$TMP/empty_base/.woostack"
assert_eq "$(bash "$RESOLVER" "$TMP/empty_repo")" "{}" "both absent yields empty object"
printf '{"artifacts":{"linear":{"team":"O"}}}\n' >"$TMP/orphan/.woostack/config.local.json"
must_fail "$TMP/orphan" ".woostack/config.json is missing" "orphaned local fails"
: >"$TMP/empty_base/.woostack/config.json"
must_fail "$TMP/empty_base" ".woostack/config.json must not be empty" "empty base fails"

# 8. Malformed JSON & 9. Non-object JSON
b="$TMP/bad/.woostack"; mkdir -p "$b"
printf '{"l":' >"$b/config.json"; must_fail "$TMP/bad" ".woostack/config.json must contain valid JSON" "malformed base JSON fails"
printf '{}\n' >"$b/config.json"; printf '{"l":' >"$b/config.local.json"; must_fail "$TMP/bad" ".woostack/config.local.json must contain valid JSON" "malformed local JSON fails"
printf '[]\n' >"$b/config.json"; rm -f "$b/config.local.json"; must_fail "$TMP/bad" ".woostack/config.json must contain a JSON object" "non-object base JSON fails"
printf '{}\n' >"$b/config.json"; printf '1\n' >"$b/config.local.json"; must_fail "$TMP/bad" ".woostack/config.local.json must contain a JSON object" "non-object local JSON fails"

# 10. Unreadable & 11. Non-regular & 12. Symlinked files
chmod 000 "$b/config.local.json"; must_fail "$TMP/bad" ".woostack/config.local.json is not readable" "unreadable local fails"
rm -f "$b/config.local.json"; chmod 000 "$b/config.json"; must_fail "$TMP/bad" ".woostack/config.json is not readable" "unreadable base fails"
chmod 644 "$b/config.json"
mkdir -p "$TMP/dir/.woostack/config.json"; must_fail "$TMP/dir" ".woostack/config.json must be a regular file" "dir base fails"
mkdir -p "$TMP/sym/.woostack" "$TMP/st"; echo '{}' >"$TMP/st/t.json"
ln -s "$TMP/st/t.json" "$TMP/sym/.woostack/config.json"; must_fail "$TMP/sym" ".woostack/config.json must not be a symlink" "symlink base fails"
rm -f "$TMP/sym/.woostack/config.json"; echo '{}' >"$TMP/sym/.woostack/config.json"
ln -s "$TMP/st/t.json" "$TMP/sym/.woostack/config.local.json"; must_fail "$TMP/sym" ".woostack/config.local.json must not be a symlink" "symlink local fails"

# 13. Credentials & 14. Linear validation (base/local/effective)
printf '{"artifacts":{"linear":{"apiKey":"s"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json contains credential-like key: artifacts.linear.apiKey" "credential base fails"
printf '{"artifacts":{"linear":{"team":"D"}}}\n' >"$repo/.woostack/config.json"; printf '{"models":{"apiKey":"s"}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json contains credential-like key: models.apiKey" "credential local fails"

printf '{"linear":{"saveArtifacts":false}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "legacy base saveArtifacts fails"
printf '{"artifacts":{"provider":"local"}}\n' >"$repo/.woostack/config.json"; printf '{"linear":{"saveArtifacts":true}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "legacy local saveArtifacts fails"
printf '{"linear":{"saveArtifacts":false}}\n' >"$repo/.woostack/config.json"; printf '{"artifacts":{"provider":"local"}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "base legacy key shadowed by local config fails"
printf '{"linear":{"saveArtifacts":false}}\n' >"$repo/.woostack/config.json"; printf '{"linear":null}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear" "base legacy key shadowed by local null fails"
printf '{"artifacts":{"provider":"invalid"}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json artifacts.provider must be \"local\", \"github\", \"linear\", or \"plane\"" "invalid provider fails"
# 15. Selected-provider only validation
printf '{"artifacts":{"provider":"local","linear":{"workspace":"only-workspace"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "local" "local provider with partial linear config succeeds"

printf '{"artifacts":{"provider":"linear","linear":{"workspace":"only-workspace"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only" "linear provider with partial linear config fails"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"linear","linear":{"repository":"https://github.com/a/b","workspace":"acme","team":"ENG","projectLabels":["Core"],"projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "linear" "valid linear provider with projectLabels succeeds"
assert_eq "$(jq -r '.artifacts.linear.projectLabels[0]' <<<"$actual")" "Core" "projectLabels preserved"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"linear","linear":{"repository":"https://github.com/a/b","workspace":"acme","team":"ENG","projectLabels":[],"projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "linear" "valid linear provider with empty projectLabels succeeds"
assert_eq "$(jq -c '.artifacts.linear.projectLabels' <<<"$actual")" "[]" "empty projectLabels preserved"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"linear","linear":{"repository":"https://github.com/a/b","workspace":"acme","team":"ENG","projectLabels":[""],"projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
must_fail "$repo" ".woostack/config.json projectLabels must be an array of non-empty strings" "empty string in projectLabels fails"

# 15b. Plane provider validation
printf '{"artifacts":{"provider":"local","plane":{"workspace":"only-workspace"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "local" "local provider with partial plane config succeeds"

printf '{"artifacts":{"provider":"plane","plane":{"workspace":"only-workspace"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only" "plane provider with partial plane config fails"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://api.plane.so","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "plane" "valid plane provider with projectLabels succeeds"
assert_eq "$(jq -r '.artifacts.plane.baseUrl' <<<"$actual")" "https://api.plane.so" "plane baseUrl preserved"
assert_eq "$(jq -r '.artifacts.plane.projectLabels[0]' <<<"$actual")" "Core" "plane projectLabels preserved"
assert_eq "$(jq -r '.artifacts.plane.project' <<<"$actual")" "33333333-3333-4333-8333-333333333330" "Plane project preserved"
printf '{"artifacts":{"plane":{"project":""}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only" "empty Plane project fails closed"
rm -f "$repo/.woostack/config.local.json"
printf '{"artifacts":{"plane":{"projectStatuses":{}}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only" "obsolete Plane projectStatuses fails closed"
rm -f "$repo/.woostack/config.local.json"

# 15c. Plane baseUrl normalization (Cloud equivalence & self-hosted trailing slash)
cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://app.plane.so","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.plane.baseUrl' <<<"$actual")" "https://api.plane.so" "plane app.plane.so canonicalized to api.plane.so"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://api.plane.so/","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.plane.baseUrl' <<<"$actual")" "https://api.plane.so" "plane api.plane.so/ trailing slash stripped and canonicalized"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://plane.internal/","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.plane.baseUrl' <<<"$actual")" "https://plane.internal" "self-hosted plane trailing slash stripped"
cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://api.plane.so","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":[],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
must_fail "$repo" ".woostack/config.json projectLabels must be an array of non-empty strings" "empty projectLabels under plane fails"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"invalid-url","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
must_fail "$repo" ".woostack/config.json plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only" "invalid baseUrl fails"

# 16. Layered invalid overrides attribution
cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"linear","linear":{"repository":"https://github.com/a/b","workspace":"acme","team":"ENG","projectLabels":["Core"],"projectStatuses":{"backlog":"Backlog","planned":"Planned","started":"Started","completed":"Completed","canceled":"Canceled"},"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
printf '{"artifacts":{"linear":{"workspace":""}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only" "invalid local workspace override attributes to local config"

printf '{"artifacts":{"linear":{"projectLabels":[""]}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json projectLabels must be an array of non-empty strings" "invalid local projectLabels override attributes to local config"

printf '{"artifacts":{"linear":{"issueStates":{"planned":""}}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json issueStates mapping is incomplete or contains invalid values" "invalid local issueStates override attributes to local config"

cat >"$repo/.woostack/config.json" <<'JSON'
{"artifacts":{"provider":"plane","plane":{"baseUrl":"https://api.plane.so","workspace":"acme","repository":"https://github.com/a/b","project":"33333333-3333-4333-8333-333333333330","projectLabels":["Core"],"issueStates":{"planned":"Backlog","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"In Progress"}}}}
JSON
printf '{"artifacts":{"plane":{"baseUrl":""}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only" "invalid local plane baseUrl override attributes to local config"

printf '{"artifacts":{"plane":{"projectLabels":[]}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json projectLabels must be an array of non-empty strings" "empty local plane projectLabels override attributes to local config"

# 15d. GitHub provider validation
printf '{"artifacts":{"provider":"local","github":{"owner":"acme"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "local" "local provider with partial github config succeeds"

printf '{"artifacts":{"provider":"github","github":{"owner":"acme"}}}\n' >"$repo/.woostack/config.json"; rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "github provider with partial github config fails"

printf '{"artifacts":{"provider":"github","github":{"owner":"acme","ownerType":"organization","statusField":"Status","visibility":"private","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
rm -f "$repo/.woostack/config.local.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "github" "valid github provider with all fields succeeds"
assert_eq "$(jq -r '.artifacts.github.owner' <<<"$actual")" "acme" "github owner preserved"
assert_eq "$(jq -r '.artifacts.github.ownerType' <<<"$actual")" "organization" "github ownerType preserved"
assert_eq "$(jq -r '.artifacts.github.statusField' <<<"$actual")" "Status" "github statusField preserved"
assert_eq "$(jq -r '.artifacts.github.visibility' <<<"$actual")" "private" "github visibility preserved"
assert_eq "$(jq -r '.artifacts.github.projectStatuses.planned' <<<"$actual")" "Todo" "github projectStatuses preserved"

printf '{"artifacts":{"provider":"github","github":{"owner":"howarewoo","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.artifacts.provider' <<<"$actual")" "github" "valid github provider with optional fields omitted succeeds"
assert_eq "$(jq -r '.artifacts.github.owner' <<<"$actual")" "howarewoo" "github user owner preserved"

printf '{"artifacts":{"provider":"github","github":{"owner":"-invalid-","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "invalid owner fails"
printf '{"artifacts":{"provider":"github","github":{"owner":"acme","ownerType":"team","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "invalid ownerType fails"
printf '{"artifacts":{"provider":"github","github":{"owner":"acme","visibility":"internal","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "invalid visibility fails"
printf '{"artifacts":{"provider":"github","github":{"owner":"acme","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json projectStatuses mapping is incomplete or contains invalid values" "incomplete projectStatuses fails"
printf '{"artifacts":{"provider":"github","github":{"owner":"acme","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Progress","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json projectStatuses mapping is incomplete or contains invalid values" "duplicate status values in projectStatuses fails"
printf '{"artifacts":{"provider":"github","github":{"owner":"acme","extraKey":"val","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" ".woostack/config.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "unknown key in github config fails"

printf '{"artifacts":{"provider":"github","github":{"owner":"acme","projectStatuses":{"planned":"Todo","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}}}}\n' >"$repo/.woostack/config.json"
printf '{"artifacts":{"github":{"owner":""}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only" "invalid local github owner override attributes to local config"
printf '{"artifacts":{"github":{"projectStatuses":{"planned":""}}}}\n' >"$repo/.woostack/config.local.json"
must_fail "$repo" ".woostack/config.local.json projectStatuses mapping is incomplete or contains invalid values" "invalid local github projectStatuses override attributes to local config"
finish
