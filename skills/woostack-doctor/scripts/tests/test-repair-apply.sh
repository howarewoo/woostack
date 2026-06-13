#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
D="$HERE/../doctor.sh"; C="$HERE/../checks"

r="$(mktemp -d)"; ( cd "$r" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/memory"
: > "$r/.woostack/.gitignore"
printf -- '---\nname: x\ntype: spec\n---\n\n# X\n## 1. Problem\n' > "$r/.woostack/specs/2026-06-13-x.md"
printf -- '**Source:** .woostack/specs/2026-06-13-x.md\n\n# X Plan\n' > "$r/.woostack/plans/2026-06-13-x.md"

bash "$D" "$r" >/dev/null 2>&1; assert_exit 0 "$?" "warn-only diagnose exits 0"
found="$(bash "$D" "$r" 2>/dev/null)"
assert_contains "$found" "spec-plan-backlink" "backlink finding present pre-repair"
assert_contains "$found" "gitignore-drift" "gitignore finding present pre-repair"

bash "$C/spec-plan-backlink.sh" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
bash "$C/gitignore-drift.sh" --fix "$r"
residue="$(bash "$D" "$r" 2>/dev/null | grep -E 'spec-plan-backlink|gitignore-drift')"
assert_eq "$residue" "" "after applying auto fixes, those findings clear"
finish
