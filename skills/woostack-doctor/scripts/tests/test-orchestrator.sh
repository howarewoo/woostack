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
  "review": {}
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

# A check that cannot complete must fail the inspection in both modes. The real
# runner is copied next to a disposable checks/ directory (never reimplemented)
# so a fixture can crash without touching the shipped checks.
make_runner() {
  local dir; dir="$(mktemp -d)"
  mkdir -p "$dir/scripts/checks"
  cp "$DOC" "$dir/scripts/doctor.sh"
  printf '%s\n' "$dir"
}
run_doctor() { bash "$1/scripts/doctor.sh" "${@:2}"; }
write_check() { printf '%s\n' "$2" >"$1/scripts/checks/$3"; }
failed="$(mktemp -d)"; mkdir -p "$failed/.woostack"
printf '%s\n' "$valid_config" >"$failed/.woostack/config.json"

crash="$(make_runner)"
write_check "$crash" 'exit 42' 'zz-crashing.sh'
out="$(run_doctor "$crash" "$failed" 2>&1)"; code=$?
assert_exit 1 "$code" "a crashing check fails normal-mode doctor"
assert_contains "$out" "zz-crashing.sh" "the failed check is named"
assert_contains "$out" "exit 42" "the failed check's status is reported"
run_doctor "$crash" --check "$failed" >/dev/null 2>&1
assert_exit 1 "$?" "--check also fails when a check cannot complete"

# Findings emitted before a failure survive it.
partial="$(make_runner)"
write_check "$partial" $'printf "warn\tkept\treport\tp\tkept finding\\n"\nexit 7' 'zz-partial.sh'
out="$(run_doctor "$partial" "$failed" 2>&1)"; code=$?
assert_exit 1 "$code" "a partially completed check fails the inspection"
assert_contains "$out" "kept finding" "findings emitted before a failure are retained"
assert_contains "$out" "zz-partial.sh" "the incomplete check is still named"

# Independent checks still run after another one fails. The crash sorts first
# (aa- before zz-) so the surviving check is genuinely evaluated after it.
continue_run="$(make_runner)"
write_check "$continue_run" 'exit 3' 'aa-crashing.sh'
write_check "$continue_run" $'printf "error\tindependent\treport\tq\tindependent finding\\n"\nexit 0' 'zz-independent.sh'
out="$(run_doctor "$continue_run" "$failed" 2>&1)"; code=$?
assert_exit 1 "$code" "the crashing check still fails the run"
assert_contains "$out" "aa-crashing.sh" "the failed check is named in the mixed run"
assert_contains "$out" "independent finding" "an independent check is still evaluated after a failure"

# Failure detail stays bounded and stays on one sanitized line.
noisy="$(make_runner)"
write_check "$noisy" 'printf "line %s\n" {1..200} >&2; exit 9' 'zz-noisy.sh'
out="$(run_doctor "$noisy" --check "$failed" 2>&1)"
assert_eq "$(grep -c 'zz-noisy.sh' <<<"$out")" "1" "a failing check's stderr is reported on one line"
assert_contains "$out" "::error:: [check-failed]" "the failure is an error finding in --check mode"

# Successful checks keep their existing exit semantics.
ok="$(make_runner)"
write_check "$ok" 'exit 0' 'aa-silent.sh'
run_doctor "$ok" "$failed" >/dev/null 2>&1; assert_exit 0 "$?" "a silent successful check stays clean"
write_check "$ok" $'printf "warn\tw\treport\tp\tadvice\\n"\nexit 0' 'aa-warn.sh'
run_doctor "$ok" "$failed" >/dev/null 2>&1; assert_exit 0 "$?" "warnings-only checks stay non-error"
write_check "$ok" $'printf "error\te\treport\tp\tbad\\n"\nexit 0' 'aa-err.sh'
run_doctor "$ok" "$failed" >/dev/null 2>&1; assert_exit 1 "$?" "a successful error finding is still unhealthy"
run_doctor "$ok" --check "$failed" >/dev/null 2>&1
assert_exit 1 "$?" "--check still fails on a successful error finding"


badflag="$(bash "$DOC" --bogus "$clean" 2>&1)"; bc=$?
assert_exit 2 "$bc" "unknown flag exits 2"
finish
