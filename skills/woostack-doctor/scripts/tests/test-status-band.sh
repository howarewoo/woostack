#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
source "$HERE/../../../woostack-init/scripts/lib.sh"   # field() for reading frontmatter in asserts
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# ok\n'  > "$r/.woostack/specs/ok.md"  # in-band → none
printf -- '---\ntype: spec\nstatus: executing\n---\n\n# x\n'  > "$r/.woostack/specs/x.md"   # plan-band on spec → report
printf -- '---\ntype: plan\nstatus: executing\n---\n\n# ok\n' > "$r/.woostack/plans/ok.md"  # in-band → none
printf -- '---\ntype: plan\nstatus: hardened\n---\n\n# y\n'   > "$r/.woostack/plans/y.md"   # spec-band on plan → report
printf -- '---\ntype: fix\nstatus: executing\n---\n\n# f\n'   > "$r/.woostack/fixes/f.md"   # fixes skipped → none
printf -- '---\ntype: spec\nstatus: abandoned\n---\n\n# sa\n' > "$r/.woostack/specs/sa.md"  # terminal both bands → none
printf -- '---\ntype: plan\nstatus: abandoned\n---\n\n# pa\n' > "$r/.woostack/plans/pa.md"  # terminal both bands → none

out="$(bash "$C/status-band.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'status-band')" "2" "exactly two band findings (abandoned never flagged)"
assert_contains "$out" "$(printf 'warn\tstatus-band\treport\t.woostack/specs/x.md')" "plan-band value on spec"
assert_contains "$out" "$(printf 'warn\tstatus-band\treport\t.woostack/plans/y.md')" "spec-band value on plan"
assert_not_contains "$out" ".woostack/fixes/f.md" "fixes/ skipped"
assert_not_contains "$out" ".woostack/specs/sa.md" "abandoned spec not flagged (terminal for both bands)"
assert_not_contains "$out" ".woostack/plans/pa.md" "abandoned plan not flagged (terminal for both bands)"
# --fix is a no-op for a report check
bash "$C/status-band.sh" --fix "$r" "$r/.woostack/specs/x.md"; assert_exit 0 "$?" "--fix no-op exits 0"
assert_eq "$(field "$r/.woostack/specs/x.md" status)" "executing" "report check never mutates"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/status-band.sh")" "" "status-band calls no git/gh"
finish
