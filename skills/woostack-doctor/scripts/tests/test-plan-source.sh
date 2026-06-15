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
# (vi) **Source:** line present but source: frontmatter absent → sync from the line (auto)
printf -- '---\ntype: plan\nstatus: planning\n---\n\n**Source:** [[specs/a]]\n\n# Line No Key\n' > "$r/.woostack/plans/line-no-key.md"

out="$(bash "$C/plan-source.sh" "$r")"
assert_contains "$out" "$(printf 'warn\tplan-source\tauto\t.woostack/plans/miss-auto.md')" "missing line w/ resolvable source: is auto"
assert_contains "$out" "$(printf 'warn\tplan-source\treport\t.woostack/plans/orphan.md')" "orphan plan is report"
assert_contains "$out" "$(printf 'warn\tplan-source\treport\t.woostack/plans/gone.md')" "unresolvable source: is report, not auto"
assert_contains "$out" "$(printf 'warn\tplan-source-sync\tauto\t.woostack/plans/sync.md')" "source/line basename mismatch"
assert_contains "$out" "$(printf 'warn\tplan-source-sync\tauto\t.woostack/plans/line-no-key.md')" "line present, source: absent is auto sync"
# ok.md is in sync (no plan-source-sync), but its **Source:** line is a legacy bare-path → plan-source-link
assert_contains "$out" "$(printf 'warn\tplan-source-link\tauto\t.woostack/plans/ok.md')" "bare-path Source line flagged for wikilink canonicalization"
assert_not_contains "$out" "$(printf 'plan-source-sync\tauto\t.woostack/plans/ok.md')" "in-sync bare-path plan is not a sync finding"
# wikilink-form **Source:** lines are already canonical → never plan-source-link flagged
assert_not_contains "$out" "$(printf 'plan-source-link\tauto\t.woostack/plans/line-no-key.md')" "wikilink Source line is not link-flagged"
assert_not_contains "$out" "$(printf 'plan-source-link\tauto\t.woostack/plans/sync.md')" "wikilink Source line (sync mismatch) is not link-flagged"

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
# repair: sync source: ← line when source: frontmatter was absent
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/line-no-key.md" source-sync
assert_eq "$(field "$r/.woostack/plans/line-no-key.md" source)" ".woostack/specs/a.md" "source: synced from the line when frontmatter absent"
# --- repair: canonicalize a legacy bare-path **Source:** line to the [[specs/x]] wikilink ---
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/ok.md" source-link
assert_eq "$(grep -m1 -E '^\*\*Source:\*\*' "$r/.woostack/plans/ok.md")" "**Source:** [[specs/a]] (shipped #1)" "bare-path line canonicalized, trailing text preserved"
# idempotent
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/ok.md" source-link
assert_eq "$(grep -cE '^\*\*Source:\*\*' "$r/.woostack/plans/ok.md")" "1" "re-canonicalize is a no-op"
assert_eq "$(grep -m1 -E '^\*\*Source:\*\*' "$r/.woostack/plans/ok.md")" "**Source:** [[specs/a]] (shipped #1)" "idempotent canonicalization preserves trailing text"
# clean diagnose after repairs (orphan report remains)
res="$(bash "$C/plan-source.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain"
assert_contains "$res" ".woostack/plans/orphan.md" "orphan report persists"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/plan-source.sh")" "" "plan-source calls no git/gh"
# --- repair refusals (error paths) ---
# --fix source-line with no source: to derive from → report + exit 1, no line inserted
out_orph="$(bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/orphan.md" source-line)"; rc_orph=$?
assert_exit 1 "$rc_orph" "--fix source-line with no source: exits nonzero"
assert_contains "$out_orph" "no source: frontmatter" "--fix source-line reports the missing source:"
assert_eq "$(grep -cE '^\*\*Source:\*\*' "$r/.woostack/plans/orphan.md")" "0" "no line inserted when there is nothing to derive"
# --fix source-line when source: names a non-existent spec → report + exit 1, no dead wikilink
out_gone="$(bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/gone.md" source-line)"; rc_gone=$?
assert_exit 1 "$rc_gone" "--fix source-line refuses a non-existent spec"
assert_eq "$(grep -cE '^\*\*Source:\*\*' "$r/.woostack/plans/gone.md")" "0" "no dead **Source:** wikilink inserted for a missing spec"
# --fix source-line on a plan with no closing frontmatter fence → manual + exit 1
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n# Unclosed\n' > "$r/.woostack/plans/unclosed.md"
out_nc="$(bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/unclosed.md" source-line)"; rc_nc=$?
assert_exit 1 "$rc_nc" "--fix source-line on a fenceless plan exits nonzero"
assert_contains "$out_nc" "no closing frontmatter fence" "--fix source-line reports the missing closing fence"
# --fix source-sync on a plan with a **Source:** line but no frontmatter fence to write source: into → manual + exit 1
printf -- '---\ntype: plan\nstatus: planning\n\n**Source:** [[specs/a]]\n# Sync Unclosed\n' > "$r/.woostack/plans/sync-unclosed.md"
out_su="$(bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/sync-unclosed.md" source-sync)"; rc_su=$?
assert_exit 1 "$rc_su" "--fix source-sync on a fenceless plan exits nonzero"
assert_contains "$out_su" "no frontmatter fence" "--fix source-sync reports the missing fence"
finish
