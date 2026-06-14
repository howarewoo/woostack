#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
source "$HERE/../../../woostack-init/scripts/lib.sh"   # field() for reading frontmatter in asserts
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# ok\n'   > "$r/.woostack/specs/ok.md"   # valid → none
printf -- '---\ntype: spec\nstatus: aproved\n---\n\n# typo\n'  > "$r/.woostack/specs/typo.md" # alias → auto
printf -- '---\ntype: plan\nstatus: in_review\n---\n\n# al\n'  > "$r/.woostack/plans/al.md"   # alias → auto
printf -- '---\ntype: fix\nstatus: frobnicate\n---\n\n# unk\n' > "$r/.woostack/fixes/unk.md"  # unknown → report

out="$(bash "$C/status-enum.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'status-enum')" "3" "three status-enum findings"
assert_contains "$out" "$(printf 'error\tstatus-enum\tauto\t.woostack/specs/typo.md')" "alias is error+auto"
assert_contains "$out" "$(printf 'error\tstatus-enum\tauto\t.woostack/plans/al.md')" "in_review alias is auto"
assert_contains "$out" "$(printf 'error\tstatus-enum\treport\t.woostack/fixes/unk.md')" "unknown is error+report"

# --- repair: alias auto-fixes ---
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/specs/typo.md"
assert_eq "$(field "$r/.woostack/specs/typo.md" status)" "approved" "aproved → approved"
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/plans/al.md"
assert_eq "$(field "$r/.woostack/plans/al.md" status)" "in-review" "in_review → in-review"
# report value is NEVER mutated, even if --fix is called on it
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/fixes/unk.md"
assert_eq "$(field "$r/.woostack/fixes/unk.md" status)" "frobnicate" "unknown status untouched by --fix"
# idempotent
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/specs/typo.md"
assert_eq "$(field "$r/.woostack/specs/typo.md" status)" "approved" "re-fix no-op"
# only the unknown (report) finding remains
res="$(bash "$C/status-enum.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain"
assert_contains "$res" ".woostack/fixes/unk.md" "report finding persists"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/status-enum.sh")" "" "status-enum calls no git/gh"
finish
