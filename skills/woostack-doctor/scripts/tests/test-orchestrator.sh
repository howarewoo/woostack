#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
DOC="$HERE/../doctor.sh"

empty="$(mktemp -d)"
out="$(bash "$DOC" "$empty" 2>&1)"; code=$?
assert_exit 2 "$code" "missing .woostack exits 2"
assert_contains "$out" "run woostack-init" "missing-workspace message points to init"

valid_config='{
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
  "review": {},
  "status": {"staleDays": 14}
}'
clean="$(mktemp -d)"; mkdir -p "$clean/.woostack"
printf '%s\n' "$valid_config" >"$clean/.woostack/config.json"
bash "$DOC" "$clean" >/dev/null 2>&1; assert_exit 0 "$?" "clean workspace exits 0"

warnws="$(mktemp -d)"; mkdir -p "$warnws/.woostack"
printf '%s\n' '{"artifacts":{"provider":"linear"},"models":{},"status":{"staleDays":14}}' >"$warnws/.woostack/config.json"
bash "$DOC" "$warnws" >/dev/null 2>&1; assert_exit 0 "$?" "retirement guidance exits 0"

retained="$(mktemp -d)"; mkdir -p "$retained/.woostack/plans"
printf '%s\n' "$valid_config" >"$retained/.woostack/config.json"
printf 'historical\n' >"$retained/.woostack/plans/old.md"
bash "$DOC" "$retained" >/dev/null 2>&1; assert_exit 0 "$?" "retained data is report-only"

bad="$(mktemp -d)"; mkdir -p "$bad/.woostack"
printf '%s\n' '{"github":{"visibility":"private"},"models":{},"status":{"staleDays":14}}' >"$bad/.woostack/config.json"
bash "$DOC" "$bad" >/dev/null 2>&1; assert_exit 1 "$?" "malformed canonical config exits 1"

bash "$DOC" --check "$warnws" >/dev/null 2>&1; assert_exit 0 "$?" "--check retirement guidance exits 0"
bash "$DOC" --check "$bad" >/dev/null 2>&1; assert_exit 1 "$?" "--check config errors exit 1"

badflag="$(bash "$DOC" --bogus "$clean" 2>&1)"; bc=$?
assert_exit 2 "$bc" "unknown flag exits 2"
finish
