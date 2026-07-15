#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/resolve-intent.sh"

work="$(mktemp -d)"
repo="$work/repo"
out="$work/out"
mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans" "$repo/.woostack/fixes" "$out"

write_meta() {
  local body="$1" branch="${2:-}"
  jq -n --arg body "$body" --arg branch "$branch" '{body:$body,headRefName:$branch}' > "$out/meta.json"
}

run_resolver() {
  WOOSTACK_ROOT="$repo" OUTDIR="$out" bash "$SCRIPT" 2>"$work/stderr"
}

write_pair() {
  local spec="$1" plan="$2" branch="$3" source="$4" source_value="${5:-.woostack/specs/$1}"
  cat > "$repo/.woostack/specs/$spec" <<EOF
---
type: spec
status: approved
branch: $branch
---
# Spec
## 7. Acceptance criteria
- criterion from $spec
EOF
  cat > "$repo/.woostack/plans/$plan" <<EOF
---
type: plan
source: $source_value
status: executing
branch: $branch
---
$source
# Plan
- [x] completed from $plan
EOF
}

write_pair "2026-07-14-alpha.md" "2026-07-14-different-plan.md" "feature/alpha" \
  '**Source:** [[specs/2026-07-14-alpha]]' "unresolved"
write_meta $'Description\n\nSpec: .woostack/specs/2026-07-14-alpha.md' "feature/other"
run_resolver
intent="$(cat "$out/intent.md")"
assert_contains "$intent" "## SOURCE: .woostack/specs/2026-07-14-alpha.md" "Spec trailer includes spec"
assert_contains "$intent" "## SOURCE: .woostack/plans/2026-07-14-different-plan.md" "Spec trailer includes wikilink-joined plan"

write_pair "2026-07-14-beta.md" "2026-07-14-beta-plan.md" "feature/beta" \
  '**Source:** .woostack/specs/2026-07-14-beta.md'
write_meta 'Plan: .woostack/plans/2026-07-14-beta-plan.md' "feature/other"
run_resolver
intent="$(cat "$out/intent.md")"
assert_contains "$intent" "## SOURCE: .woostack/plans/2026-07-14-beta-plan.md" "Plan trailer includes plan"
assert_contains "$intent" "## SOURCE: .woostack/specs/2026-07-14-beta.md" "Plan trailer includes legacy-source spec"

cat > "$repo/.woostack/fixes/2026-07-14-fix.md" <<'EOF'
---
type: fix
status: executing
branch: fix/demo
---
# Fix
- [x] fixed
EOF
write_meta 'Spec: .woostack/fixes/2026-07-14-fix.md' "feature/other"
run_resolver
intent="$(cat "$out/intent.md")"
assert_contains "$intent" "## SOURCE: .woostack/fixes/2026-07-14-fix.md" "fix trailer resolves self-contained fix"
assert_eq "$(grep -c '^## SOURCE:' "$out/intent.md")" "1" "fix intent has one source"

write_meta $'  Spec: .woostack/fixes/2026-07-14-fix.md  ' "feature/other"
run_resolver
assert_contains "$(cat "$out/intent.md")" "## SOURCE: .woostack/fixes/2026-07-14-fix.md" "trimmed fix trailer resolves"

write_meta '' "fix/demo"
run_resolver
assert_contains "$(cat "$out/intent.md")" "## SOURCE: .woostack/fixes/2026-07-14-fix.md" "branch fallback resolves exact fix branch"

write_meta '' "feature/beta"
run_resolver
intent="$(cat "$out/intent.md")"
assert_contains "$intent" "## SOURCE: .woostack/specs/2026-07-14-beta.md" "shared branch includes spec"
assert_contains "$intent" "## SOURCE: .woostack/plans/2026-07-14-beta-plan.md" "shared branch includes joined plan"
assert_eq "$(grep -c '^## SOURCE:' "$out/intent.md")" "2" "shared spec-plan branch is one joined pair"

for bad in \
  'See .woostack/fixes/2026-07-14-fix.md in prose' \
  'Spec: .woostack/fixes/2026-07-14-fix.md.bak' \
  'Spec: ../.woostack/fixes/2026-07-14-fix.md' \
  'Spec: /tmp/2026-07-14-fix.md' \
  'Spec: .woostack/fixes/missing.md'; do
  write_meta "$bad" "feature/unknown"
  run_resolver
  [ ! -e "$out/intent.md" ] && pass || fail "unsafe or missing path must not resolve: $bad"
done

write_meta $'Spec: .woostack/fixes/2026-07-14-fix.md\nPlan: .woostack/plans/2026-07-14-beta-plan.md' "feature/other"
run_resolver
[ ! -e "$out/intent.md" ] && pass || fail "conflicting trailers produce no intent"
assert_contains "$(cat "$work/stderr")" "warning" "conflicting trailers warn"

cat > "$repo/.woostack/fixes/2026-07-14-other.md" <<'EOF'
---
type: fix
status: executing
branch: fix/collision
---
EOF
cat > "$repo/.woostack/fixes/2026-07-14-another.md" <<'EOF'
---
type: fix
status: executing
branch: fix/collision
---
EOF
write_meta '' "fix/collision"
run_resolver
[ ! -e "$out/intent.md" ] && pass || fail "unrelated branch matches produce no intent"
assert_contains "$(cat "$work/stderr")" "warning" "ambiguous branch matches warn"

printf 'stale\n' > "$out/intent.md"
write_meta '' "feature/unknown"
run_resolver
[ ! -e "$out/intent.md" ] && pass || fail "unresolved rerun removes stale intent"

rm -rf "$repo/.woostack"
printf 'stale\n' > "$out/intent.md"
write_meta '' ""
run_resolver
[ ! -e "$out/intent.md" ] && pass || fail "missing store and head branch no-op without stale intent"

rm -rf "$work"
finish
