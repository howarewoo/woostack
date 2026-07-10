#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/../load-respond-config.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "$3 (expected: $2; actual: $1)"
}

run_config() {
  local name="$1" content="$2"
  CONFIG="$WORK/$name.json"
  STDOUT="$WORK/$name.stdout"
  STDERR="$WORK/$name.stderr"
  printf '%s' "$content" >"$CONFIG"
  if bash "$SCRIPT" "$CONFIG" >"$STDOUT" 2>"$STDERR"; then
    STATUS=0
  else
    STATUS=$?
  fi
}

assert_valid() {
  local name="$1" content="$2" expected="$3"
  run_config "$name" "$content"
  assert_eq "$STATUS" "0" "$name succeeds"
  assert_eq "$(cat "$STDOUT")" "$expected" "$name emits normalized compact JSON"
  assert_eq "$(cat "$STDERR")" "" "$name emits no error"
}

assert_invalid() {
  local name="$1" content="$2" key="$3"
  run_config "$name" "$content"
  [ "$STATUS" -ne 0 ] || fail "$name fails"
  assert_eq "$(cat "$STDOUT")" "" "$name emits no JSON"
  case "$(cat "$STDERR")" in
    "::error file=$CONFIG::respond.$key: "*) ;;
    *) fail "$name error names respond.$key in GitHub annotation ($(cat "$STDERR"))" ;;
  esac
}

DEFAULT='{"provider":"auto","environment":"production","window":"24h","max_groups":5,"remediation":"prepare-fix"}'
assert_valid absent '{}' "$DEFAULT"
assert_valid empty '{"respond":{}}' "$DEFAULT"
assert_valid missing-file-placeholder '{}' "$DEFAULT"
rm -f "$CONFIG"
if bash "$SCRIPT" "$CONFIG" >"$STDOUT" 2>"$STDERR"; then STATUS=0; else STATUS=$?; fi
assert_eq "$STATUS" "0" "missing file succeeds"
assert_eq "$(cat "$STDOUT")" "$DEFAULT" "missing file uses defaults"
mkdir -p "$WORK/default-path/.woostack"
if (cd "$WORK/default-path" && bash "$SCRIPT") >"$STDOUT" 2>"$STDERR"; then STATUS=0; else STATUS=$?; fi
assert_eq "$STATUS" "0" "zero arguments uses default path"
assert_eq "$(cat "$STDOUT")" "$DEFAULT" "default missing path uses defaults"

assert_valid overrides '{"respond":{"provider":"honeycomb-eu","environment":"staging","window":"5m","max_groups":1,"remediation":"report-only"}}' '{"provider":"honeycomb-eu","environment":"staging","window":"5m","max_groups":1,"remediation":"report-only"}'
assert_valid arbitrary-provider '{"respond":{"provider":"custom-observability-2"}}' '{"provider":"custom-observability-2","environment":"production","window":"24h","max_groups":5,"remediation":"prepare-fix"}'
assert_valid day-bound '{"respond":{"window":"30d","max_groups":5}}' '{"provider":"auto","environment":"production","window":"30d","max_groups":5,"remediation":"prepare-fix"}'
assert_valid hour-window '{"respond":{"window":"24h"}}' "$DEFAULT"
assert_valid sibling-isolation '{"review":{"token":"sibling-is-ignored"},"respond":{},"models":{"anything":true}}' "$DEFAULT"
assert_eq "$(cat "$CONFIG")" '{"review":{"token":"sibling-is-ignored"},"respond":{},"models":{"anything":true}}' "loader does not mutate sibling namespaces"

assert_invalid root-type '[]' respond
assert_invalid respond-type '{"respond":[]}' respond
assert_invalid unknown-key '{"respond":{"bogus":1}}' bogus
assert_invalid wrong-key-type '{"respond":{"max_groups":"5"}}' max_groups
assert_invalid empty-provider '{"respond":{"provider":""}}' provider
assert_invalid uppercase-provider '{"respond":{"provider":"Sentry"}}' provider
assert_invalid empty-environment '{"respond":{"environment":""}}' environment
assert_invalid wrong-environment-type '{"respond":{"environment":7}}' environment
assert_invalid zero-minutes '{"respond":{"window":"0m"}}' window
assert_invalid short-window '{"respond":{"window":"4m"}}' window
assert_invalid long-window '{"respond":{"window":"31d"}}' window
assert_invalid wrong-window-type '{"respond":{"window":24}}' window
assert_invalid groups-zero '{"respond":{"max_groups":0}}' max_groups
assert_invalid groups-six '{"respond":{"max_groups":6}}' max_groups
assert_invalid groups-float '{"respond":{"max_groups":1.5}}' max_groups
assert_invalid groups-bool '{"respond":{"max_groups":true}}' max_groups
assert_invalid invalid-remediation '{"respond":{"remediation":"fix-now"}}' remediation
assert_invalid wrong-remediation-type '{"respond":{"remediation":false}}' remediation
assert_invalid malformed-json '{"respond":' respond

for key in token api_key password cookie authorization mutation_authority; do
  assert_invalid "credential-$key" "{\"respond\":{\"$key\":\"secret\",\"provider\":7}}" "$key"
done

# The public shell interface accepts at most one path.
if bash "$SCRIPT" "$WORK/a" "$WORK/b" >"$STDOUT" 2>"$STDERR"; then STATUS=0; else STATUS=$?; fi
[ "$STATUS" -ne 0 ] || fail "two paths fail"

printf 'PASS: respond config loader\n'
