#!/usr/bin/env bash
# review-models-moved.sh — diagnose-only warn when a config still nests review.models.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"
r="$(mktemp -d)"; mkdir -p "$r/.woostack"

printf '%s\n' '{"review":{"models":{"openai":{"standard":"x"}}}}' > "$r/.woostack/config.json"
out="$(bash "$C/review-models-moved.sh" "$r")"
assert_contains "$out" "$(printf 'warn\treview-models-moved')" "review.models present → warn"
assert_contains "$out" ".woostack/config.json" "names the config file"

# Local config introducing review.models -> warn
printf '%s\n' '{"review":{"metrics":true}}' > "$r/.woostack/config.json"
printf '%s\n' '{"review":{"models":{"standard":"x"}}}' > "$r/.woostack/config.local.json"
out="$(bash "$C/review-models-moved.sh" "$r")"
assert_contains "$out" "$(printf 'warn\treview-models-moved')" "local review.models present → warn"
rm -f "$r/.woostack/config.local.json"

printf '%s\n' '{"models":{"openai":{"standard":{"model":"x"}}}}' > "$r/.woostack/config.json"
assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "root models only → silent"

printf '%s\n' '{"review":{"metrics":true}}' > "$r/.woostack/config.json"
assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "review block without models → silent"

rm -f "$r/.woostack/config.json"
assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "no config → silent"

assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/review-models-moved.sh")" "" \
  "migration check calls no git/gh"
rm -rf "$r"
finish
