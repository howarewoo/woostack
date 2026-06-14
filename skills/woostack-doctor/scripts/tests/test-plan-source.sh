#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
source "$HERE/../../../woostack-init/scripts/lib.sh"   # field() for reading frontmatter in asserts
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# A\n' > "$r/.woostack/specs/a.md"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# B\n' > "$r/.woostack/specs/b.md"
# (i) missing line, source: resolves to a.md → auto
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n# A Plan\n' > "$r/.woostack/plans/miss-auto.md"
# (ii) missing line, no source: + no same-basename spec → report
printf -- '---\ntype: plan\nstatus: planning\n---\n\n# Orphan Plan\n' > "$r/.woostack/plans/orphan.md"
# (iii) line names b but source: names a → sync mismatch (auto)
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n**Source:** [[specs/b]]\n\n# Mismatch\n' > "$r/.woostack/plans/sync.md"
# (iv) line bare-path w/ trailing text, source: same base → in sync, no finding
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n**Source:** specs/a.md (shipped #1)\n\n# OK\n' > "$r/.woostack/plans/ok.md"
# (v) missing line, source: present but names a non-existent spec → report (not auto, since source: does not resolve)
printf -- '---\ntype: plan\nsource: .woostack/specs/gone.md\nstatus: planning\n---\n\n# Gone\n' > "$r/.woostack/plans/gone.md"

out="$(bash "$C/plan-source.sh" "$r")"
assert_contains "$out" "$(printf 'warn\tplan-source\tauto\t.woostack/plans/miss-auto.md')" "missing line w/ resolvable source: is auto"
assert_contains "$out" "$(printf 'warn\tplan-source\treport\t.woostack/plans/orphan.md')" "orphan plan is report"
assert_contains "$out" "$(printf 'warn\tplan-source\treport\t.woostack/plans/gone.md')" "unresolvable source: is report, not auto"
assert_contains "$out" "$(printf 'warn\tplan-source-sync\tauto\t.woostack/plans/sync.md')" "source/line basename mismatch"
assert_not_contains "$out" ".woostack/plans/ok.md" "normalized in-sync plan has no finding"

# --- repair: insert missing line ---
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/miss-auto.md" source-line
assert_eq "$(grep -m1 -E '^\*\*Source:\*\*' "$r/.woostack/plans/miss-auto.md")" "**Source:** [[specs/a]]" "line inserted as wikilink"
# inserted line sits before the H1
assert_eq "$(grep -nE '^\*\*Source:\*\*|^# ' "$r/.woostack/plans/miss-auto.md" | head -1 | grep -c 'Source')" "1" "Source line precedes H1"
# idempotent
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/miss-auto.md" source-line
assert_eq "$(grep -cE '^\*\*Source:\*\*' "$r/.woostack/plans/miss-auto.md")" "1" "re-insert is a no-op"
# --- repair: sync source: ← line ---
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/sync.md" source-sync
assert_eq "$(field "$r/.woostack/plans/sync.md" source)" ".woostack/specs/b.md" "source: synced to the line's spec"
# clean diagnose after repairs (orphan report remains)
res="$(bash "$C/plan-source.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain"
assert_contains "$res" ".woostack/plans/orphan.md" "orphan report persists"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/plan-source.sh")" "" "plan-source calls no git/gh"
finish
