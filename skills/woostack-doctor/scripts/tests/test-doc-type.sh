#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
source "$HERE/../../../woostack-init/scripts/lib.sh"   # field() for reading frontmatter in asserts
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
# good spec (no finding)
printf -- '---\nname: a\ntype: spec\nstatus: draft\n---\n\n# A\n' > "$r/.woostack/specs/a.md"
# plan mis-typed as spec
printf -- '---\ntype: spec\nstatus: planning\n---\n\n**Source:** [[specs/a]]\n\n# A Plan\n' > "$r/.woostack/plans/a.md"
# spec missing type:
printf -- '---\nname: b\nstatus: draft\n---\n\n# B\n' > "$r/.woostack/specs/b.md"
# fenceless doc (report, not auto)
printf -- '# C\nno frontmatter\n' > "$r/.woostack/fixes/c.md"

out="$(bash "$C/doc-type.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'doc-type')" "3" "three doc-type findings"
assert_contains "$out" "$(printf 'auto\t.woostack/plans/a.md')" "mis-typed plan is auto"
assert_contains "$out" "$(printf 'auto\t.woostack/specs/b.md')" "missing-type spec is auto"
assert_contains "$out" "$(printf 'report\t.woostack/fixes/c.md')" "fenceless doc is report"

# --- repair ---
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/plans/a.md"
assert_eq "$(field "$r/.woostack/plans/a.md" type)" "plan" "mis-typed plan repaired"
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/specs/b.md"
assert_eq "$(field "$r/.woostack/specs/b.md" type)" "spec" "missing-type spec repaired (inserted)"
# idempotent re-fix
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/plans/a.md"
assert_eq "$(grep -c '^type:' "$r/.woostack/plans/a.md")" "1" "re-fix is a no-op (single type: line)"
# only the fenceless report remains
res="$(bash "$C/doc-type.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain after repair"
assert_contains "$res" ".woostack/fixes/c.md" "fenceless report persists"
# no git/gh invocation in the check source
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/doc-type.sh")" "" "doc-type calls no git/gh"
# --fix on a fenceless file: the error path emits + exits nonzero (never silently swallowed)
out_fx="$(bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/fixes/c.md")"; rc_fx=$?
assert_exit 1 "$rc_fx" "--fix on fenceless file exits nonzero"
assert_contains "$out_fx" "no frontmatter fence" "--fix on fenceless emits the error finding"
finish
