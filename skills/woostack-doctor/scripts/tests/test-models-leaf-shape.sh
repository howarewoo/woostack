#!/usr/bin/env bash
# models-leaf-shape.sh — validate tier leaves: string | {model,...} | nonempty array
# of (string | object). Empty array or malformed entry -> error (spec
# 2026-07-10-tier-fallback-list AC3). Diagnose-only.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"
r="$(mktemp -d)"; mkdir -p "$r/.woostack"

# valid shapes -> silent
printf '%s\n' '{"models":{"standard":"a/b","deep":{"model":"c/d","effort":"high"},"fast":[{"model":"e/f","effort":"low"},"g/h"],"openai":{"deep":["i/j","k/l"]}}}' > "$r/.woostack/config.json"
assert_eq "$(bash "$C/models-leaf-shape.sh" "$r")" "" "all valid leaf shapes -> silent"

# empty array -> error
printf '%s\n' '{"models":{"fast":[]}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "$(printf 'error\tmodels-leaf-shape')" "empty array leaf -> error"
assert_contains "$out" "fast" "names the offending tier path"

# array with a non-(string|object) entry -> error
printf '%s\n' '{"models":{"deep":["a/b",42]}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "$(printf 'error\tmodels-leaf-shape')" "numeric array entry -> error"

# array entry that is an object missing .model -> error (resolver would silently default)
printf '%s\n' '{"models":{"deep":["a/b",{}]}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "$(printf 'error\tmodels-leaf-shape')" "object entry missing .model -> error"

# direct object leaf (not an array entry) missing .model -> error via the
# direct-object leaf_problem branch, distinct from the array entry_ok path above
printf '%s\n' '{"models":{"standard":{"effort":"high"}}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "object missing .model" "direct object leaf missing .model -> error"

# provider-scoped empty array -> error, path includes provider
printf '%s\n' '{"models":{"openai":{"standard":[]}}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "openai.standard" "provider-scoped path named"

# non-tier key whose value is not an object/null -> error
printf '%s\n' '{"models":{"openai":"gpt"}}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "provider value is not an object" "non-object provider value -> error"

# non-object .models -> loud error, never a silent no-op
printf '%s\n' '{"models":"oops"}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "$(printf 'error\tmodels-leaf-shape')" "non-object models -> error"

# boolean .models -> loud error (jq's // treats false like null; guard must not coalesce)
printf '%s\n' '{"models":false}' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "$(printf 'error\tmodels-leaf-shape')" "models: false -> error"

# explicit null leaf = valid unset (tools accept it) -> silent
printf '%s\n' '{"models":{"fast":null,"standard":"a/b"}}' > "$r/.woostack/config.json"
assert_eq "$(bash "$C/models-leaf-shape.sh" "$r")" "" "explicit null leaf -> silent"

# no models block / no config -> silent
printf '%s\n' '{}' > "$r/.woostack/config.json"
assert_eq "$(bash "$C/models-leaf-shape.sh" "$r")" "" "no models block -> silent"
rm -f "$r/.woostack/config.json"
assert_eq "$(bash "$C/models-leaf-shape.sh" "$r")" "" "no config -> silent"

# invalid JSON -> loud error via the jq-failure branch, never a silent pass
printf '%s\n' '{"models":' > "$r/.woostack/config.json"
out="$(bash "$C/models-leaf-shape.sh" "$r")"
assert_contains "$out" "not valid JSON" "invalid JSON config -> loud error"
rm -f "$r/.woostack/config.json"

assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/models-leaf-shape.sh")" "" \
  "shape check calls no git/gh"
rm -rf "$r"
finish
