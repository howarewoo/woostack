#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
CHK="$HERE/../checks/spec-plan-backlink.sh"

mk() { local root; root="$(mktemp -d)"; mkdir -p "$root/.woostack/specs" "$root/.woostack/plans"
  printf -- '---\nname: x\ntype: spec\n---\n\n# X — Design Spec\n\n## 1. Problem\n' > "$root/.woostack/specs/2026-06-13-x.md"
  printf -- '**Source:** .woostack/specs/2026-06-13-x.md\n\n# X Plan\n' > "$root/.woostack/plans/2026-06-13-x.md"
  printf '%s\n' "$root"; }

r="$(mk)"
out="$(bash "$CHK" "$r")"
assert_contains "$out" "spec-plan-backlink" "isolated spec is flagged"
assert_contains "$out" "[[plans/2026-06-13-x]]" "message names the expected backlink"

bash "$CHK" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
assert_contains "$(cat "$r/.woostack/specs/2026-06-13-x.md")" "> **Plan:** [[plans/2026-06-13-x]]" "fix inserts the callout"
assert_eq "$(bash "$CHK" "$r")" "" "after fix, no finding"
bash "$CHK" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
assert_eq "$(grep -cF "[[plans/2026-06-13-x]]" "$r/.woostack/specs/2026-06-13-x.md")" "1" "fix is idempotent"

r2="$(mktemp -d)"; mkdir -p "$r2/.woostack/specs" "$r2/.woostack/plans"
printf -- '---\nname: y\ntype: spec\n---\n\n# Y\n' > "$r2/.woostack/specs/2026-06-13-y-long.md"
printf -- '**Source:** .woostack/specs/2026-06-13-y-long.md\n\n# Y Plan\n' > "$r2/.woostack/plans/2026-06-13-y.md"
assert_contains "$(bash "$CHK" "$r2")" "y-long.md" "slug-mismatch resolves via Source line"

r3="$(mktemp -d)"; mkdir -p "$r3/.woostack/specs" "$r3/.woostack/plans"
printf -- '**Source:** .woostack/specs/missing.md\n\n# Z Plan\n' > "$r3/.woostack/plans/2026-06-13-z.md"
assert_eq "$(bash "$CHK" "$r3")" "" "spec-less plan is not flagged"

# --fix on a spec with no H1 cannot anchor the callout; it must fail loudly
# (exit non-zero + error finding) rather than report a phantom-successful repair.
r4="$(mktemp -d)"; mkdir -p "$r4/.woostack/specs"
printf -- '---\nname: w\ntype: spec\n---\n\nBody only, no H1 heading.\n' > "$r4/.woostack/specs/2026-06-13-w.md"
out4="$(bash "$CHK" --fix "$r4" "$r4/.woostack/specs/2026-06-13-w.md" "2026-06-13-w")"; rc4=$?
assert_exit 1 "$rc4" "--fix on a no-H1 spec exits non-zero"
assert_contains "$out4" "no H1 heading to anchor" "--fix on a no-H1 spec emits an error finding"
finish
