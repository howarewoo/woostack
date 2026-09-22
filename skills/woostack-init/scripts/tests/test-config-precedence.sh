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
git -C "$repo" config user.email t@t
git -C "$repo" config user.name t

must_fail() {
  local target="$1" expected="$2" desc="$3"
  local output rc
  set +e
  output="$(bash "$RESOLVER" "$target" 2>&1)"
  rc=$?
  set -e
  assert_exit 1 "$rc" "$desc"
  assert_contains "$output" "$expected" "$desc is actionable"
}

cat >"$repo/.woostack/config.json" <<'JSON'
{
  "github": {
    "owner": "acme",
    "ownerType": "organization",
    "statusField": "Status",
    "projectStatuses": {
      "planned": "Todo",
      "executing": "In Progress",
      "inReview": "In Review",
      "done": "Done",
      "blocked": "Blocked"
    }
  },
  "models": {"standard": {"model": "gpt-5.5", "effort": "high", "nits": true}},
  "review": {"required": true},
  "status": {"staleDays": 14},
  "host": {"custom": "preserve-me"}
}
JSON
git -C "$repo" add .woostack/config.json
git -C "$repo" commit -qm "init config"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.github.owner' <<<"$actual")" "acme" "committed GitHub owner is used"
assert_eq "$(jq -r '.github.projectStatuses.done' <<<"$actual")" "Done" "committed Status mapping is used"
assert_eq "$(jq -r '.review.required' <<<"$actual")" "true" "unrelated review settings are preserved"
assert_eq "$(jq -r '.host.custom' <<<"$actual")" "preserve-me" "unrelated custom settings are preserved"

cat >"$repo/.woostack/config.local.json" <<'JSON'
{"github":{"owner":"local-org","projectStatuses":{"done":"Shipped"}},"models":{"standard":{"effort":"low","custom":"opt"}},"status":{"staleDays":7}}
JSON
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r '.github.owner' <<<"$actual")" "local-org" "local owner overrides"
assert_eq "$(jq -r '.github.ownerType' <<<"$actual")" "organization" "sibling GitHub keys are preserved"
assert_eq "$(jq -r '.github.projectStatuses.done' <<<"$actual")" "Shipped" "local Status mapping overrides"
assert_eq "$(jq -r '.github.projectStatuses.planned' <<<"$actual")" "Todo" "base Status options survive partial local mapping"
assert_eq "$(jq -r '.models.standard.effort' <<<"$actual")" "low" "nested setting is overridden"
assert_eq "$(jq -r '.models.standard.nits' <<<"$actual")" "true" "sibling model keys are preserved"
assert_eq "$(jq -r '.review.required' <<<"$actual")" "true" "base review settings are preserved"
assert_eq "$(jq -r '.status.staleDays' <<<"$actual")" "7" "top-level setting is overridden"
git -C "$repo" worktree add -q "$worktree"
actual="$(bash "$RESOLVER" "$worktree")"
assert_eq "$(jq -r '.github.owner' <<<"$actual")" "local-org" "linked worktree inherits local policy"

mkdir -p "$TMP/empty_repo" "$TMP/orphan/.woostack" "$TMP/empty_base/.woostack"
assert_eq "$(bash "$RESOLVER" "$TMP/empty_repo")" "{}" "both config layers absent yield an empty policy"
printf '{"github":{"owner":"orphan"}}\n' >"$TMP/orphan/.woostack/config.local.json"
must_fail "$TMP/orphan" ".woostack/config.json is missing" "orphaned local config fails"
: >"$TMP/empty_base/.woostack/config.json"
must_fail "$TMP/empty_base" ".woostack/config.json must not be empty" "empty base config fails"

bad="$TMP/bad/.woostack"
mkdir -p "$bad"
printf '{"github":' >"$bad/config.json"
must_fail "$TMP/bad" ".woostack/config.json must contain valid JSON" "malformed base JSON fails"
printf '{}\n' >"$bad/config.json"
printf '{"github":' >"$bad/config.local.json"
must_fail "$TMP/bad" ".woostack/config.local.json must contain valid JSON" "malformed local JSON fails"
printf '[]\n' >"$bad/config.json"
rm -f "$bad/config.local.json"
must_fail "$TMP/bad" ".woostack/config.json must contain a JSON object" "non-object base JSON fails"
printf '{}\n' >"$bad/config.json"
printf '1\n' >"$bad/config.local.json"

# Resolver preserves no-follow and regular-file safety for both config layers.
security="$TMP/security"
mkdir -p "$security/.woostack" "$security/store"
printf '{}\n' >"$security/store/config.json"
printf '{}\n' >"$security/.woostack/config.json"
ln -s "$security/store/config.json" "$security/.woostack/config.local.json"
must_fail "$security" ".woostack/config.local.json must not be a symlink" "symlink local config fails"
rm "$security/.woostack/config.local.json" "$security/.woostack/config.json"
ln -s "$security/store/config.json" "$security/.woostack/config.json"
must_fail "$security" ".woostack/config.json must not be a symlink" "symlink base config fails"
rm "$security/.woostack/config.json"
printf '{}\n' >"$security/.woostack/config.json"
mkdir "$security/.woostack/config.local.json"
must_fail "$security" ".woostack/config.local.json must be a regular file" "directory local config fails"
rm -rf "$security/.woostack/config.local.json"
printf '{}\n' >"$security/.woostack/config.json"
chmod 000 "$security/.woostack/config.json"
must_fail "$security" ".woostack/config.json is not readable" "unreadable base config fails"
chmod 600 "$security/.woostack/config.json"
printf '{}\n' >"$security/.woostack/config.local.json"
chmod 000 "$security/.woostack/config.local.json"
must_fail "$security" ".woostack/config.local.json is not readable" "unreadable local config fails"
chmod 600 "$security/.woostack/config.local.json"

must_fail "$TMP/bad" ".woostack/config.local.json must contain a JSON object" "non-object local JSON fails"

printf '{"models":{"apiKey":"secret"}}\n' >"$repo/.woostack/config.json"
rm -f "$repo/.woostack/config.local.json"
must_fail "$repo" "credential-like key: models.apiKey" "credential-like active config fails"

cat >"$repo/.woostack/config.json" <<'JSON'
{
  "artifacts": {
    "provider": "linear",
    "linear": {"workspace": "legacy", "team": "ENG", "token": "synthetic-retired-credential"},
    "plane": {"workspace": "legacy-plane"},
    "github": {"visibility": "private"}
  },
  "linear": {"saveArtifacts": true},
  "plane": {"workspace": "legacy-root"},
  "models": {"standard": {"model": "keep"}},
  "review": {"required": false},
  "status": {"staleDays": 3}
}
JSON
legacy_before="$(cat "$repo/.woostack/config.json")"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(cat "$repo/.woostack/config.json")" "$legacy_before" "legacy config bytes are preserved"
assert_eq "$(jq -r 'has("artifacts") or has("linear") or has("plane")' <<<"$actual")" "false" "retired settings are excluded from active configuration"
assert_not_contains "$actual" "synthetic-retired-credential" "retired credentials are not exported"
assert_eq "$(jq -r 'has("github")' <<<"$actual")" "false" "legacy nested github settings are not promoted"
assert_eq "$(jq -r '.review.required' <<<"$actual")" "false" "unrelated settings survive legacy data"

printf '{"github":null}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "github policy must be a JSON object" "null canonical GitHub policy fails"
printf '{"github":{"visibility":"private"}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "github policy permits only" "retired visibility field is rejected in active policy"
printf '{"github":{"owner":"-invalid-"}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "github policy contains invalid values" "invalid owner fails"
printf '{"github":{"owner":"acme","ownerType":"team"}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "github policy contains invalid values" "invalid ownerType fails"
printf '{"github":{"projectStatuses":{"planned":"Todo","executing":"Doing","inReview":"Review","done":"Done"}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "projectStatuses mapping is incomplete" "incomplete Status mapping fails"
printf '{"github":{"projectStatuses":{"planned":"Todo","executing":"Doing","inReview":"Doing","done":"Done","blocked":"Blocked"}}}\n' >"$repo/.woostack/config.json"
must_fail "$repo" "projectStatuses mapping is incomplete" "duplicate Status options fail"

printf '{"models":{},"status":{"staleDays":14}}\n' >"$repo/.woostack/config.json"
actual="$(bash "$RESOLVER" "$repo")"
assert_eq "$(jq -r 'has("github")' <<<"$actual")" "false" "missing canonical GitHub policy is valid"

finish
