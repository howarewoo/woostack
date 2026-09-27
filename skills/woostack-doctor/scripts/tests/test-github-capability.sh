#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/../doctor.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SPY_BIN="$TMP/bin"
SPY_LOG="$TMP/provider-calls.log"
mkdir -p "$SPY_BIN"
for tool in gh linear plane; do
  cat >"$SPY_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "$tool" >>"$SPY_LOG"
exit 99
EOF
  chmod +x "$SPY_BIN/$tool"
done
export PATH="$SPY_BIN:$PATH"


make_repo() {
  local name="$1"
  local repo="$TMP/$name"
  mkdir -p "$repo/.woostack"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  printf '%s\n' '{"models":{},"status":{"staleDays":14}}' >"$repo/.woostack/config.json"
  printf '%s\n' '{}' >"$repo/.woostack/.gitignore"
  printf '%s\n' "$repo"
}

run_doctor() {
  set +e
  OUTPUT="$(bash "$DOCTOR" "$@" 2>&1)"
  RC=$?
  set -e
}


repo="$(make_repo absent-github)"
run_doctor "$repo"
assert_exit 0 "$RC" "missing canonical GitHub config is valid"
assert_not_contains "$OUTPUT" "provider" "missing config performs no provider preflight"

repo="$(make_repo valid-github)"
git -C "$repo" remote add origin https://github.com/acme/widgets
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
  "models": {},
  "review": {"required": true},
  "status": {"staleDays": 14}
}
JSON
run_doctor "$repo"
assert_exit 0 "$RC" "valid canonical GitHub policy is clean"

jq '.artifacts={provider:"linear",linear:{workspace:"legacy"},plane:{workspace:"legacy-plane"}} | .linear={saveArtifacts:true}' "$repo/.woostack/config.json" >"$repo/config.tmp"
mv "$repo/config.tmp" "$repo/.woostack/config.json"
legacy_after="$(cat "$repo/.woostack/config.json")"
run_doctor "$repo"
assert_exit 0 "$RC" "legacy provider settings do not block local diagnosis"
assert_contains "$OUTPUT" "retired-provider" "legacy settings receive retirement guidance"
assert_eq "$(cat "$repo/.woostack/config.json")" "$legacy_after" "legacy config is unchanged"

repo="$(make_repo malformed-github)"
printf '%s\n' '{"github":{"visibility":"private"}}' >"$repo/.woostack/config.json"
run_doctor "$repo"
assert_exit 1 "$RC" "unknown active GitHub key fails closed"
assert_contains "$OUTPUT" "github policy permits only" "unknown key is actionable"

repo="$(make_repo retained-data)"
git -C "$repo" remote add origin https://github.com/acme/widgets
mkdir -p "$repo/.woostack/tmp/runs/old-run" "$repo/.woostack/specs"
printf '%s\n' '{"mirror":{"provider":"plane","status":"synced"},"sentinel":"retain"}' >"$repo/.woostack/tmp/runs/old-run/manifest.json"
printf '%s\n' 'historical' >"$repo/.woostack/specs/old.md"
manifest_before="$(cat "$repo/.woostack/tmp/runs/old-run/manifest.json")"
run_doctor "$repo"
assert_exit 0 "$RC" "retained mirror-era data does not block local diagnosis"
assert_contains "$OUTPUT" "retained-data" "retained data receives report-only guidance"
assert_eq "$(cat "$repo/.woostack/tmp/runs/old-run/manifest.json")" "$manifest_before" "retained manifest is not mutated"

if [ -s "$SPY_LOG" ]; then
  fail "provider command spy was invoked: $(cat "$SPY_LOG")"
else
  pass "static checks invoke no provider executable"
fi

finish
