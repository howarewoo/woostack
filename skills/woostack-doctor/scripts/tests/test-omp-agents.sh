#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../checks/omp-agents.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
mkdir -p "$REPO/.woostack"

run_check() {
  (
    cd "$REPO"
    bash "$CHECK" "$REPO"
  )
}

fix_check() {
  (
    cd "$REPO"
    bash "$CHECK" --fix "$REPO"
  )
}

implementation="$(cat "$CHECK")"
assert_not_contains "$implementation" "launch-omp" \
  "doctor does not inspect or install the external-engineer launcher"
assert_not_contains "$implementation" "bind-engineer-unit" \
  "doctor does not inspect or install the external-engineer binder"

missing="$(run_check)"
assert_contains "$missing" $'warn\tomp-agent\tauto\t' \
  "missing project OMP agents produce auto-fixable doctor findings"
for tier in fast standard deep; do
  assert_contains "$missing" "woostack-$tier.md" \
    "doctor identifies missing $tier role definition"
done

fix_check
assert_eq "$(run_check)" "" "--fix clears missing project-worker findings"
for tier in fast standard deep; do
  [ -f "$REPO/.omp/agents/woostack-$tier.md" ] \
    && pass || fail "doctor repair creates the managed $tier role definition"
done

printf '%s\n' 'consumer-owned' >"$REPO/.omp/agents/custom.md"
printf '%s\n' '---' 'name: woostack-standard' 'model: "@smol"' '---' \
  >"$REPO/.omp/agents/woostack-standard.md"
role_drift="$(run_check)"
assert_contains "$role_drift" $'warn\tomp-agent\tauto\t' \
  "doctor reports a wrong-role managed definition"
assert_contains "$role_drift" "wrong-role:" \
  "doctor distinguishes wrong-role drift"
fix_check
assert_contains "$(cat "$REPO/.omp/agents/woostack-standard.md")" 'model: "@default"' \
  "doctor restores the standard host role"
assert_eq "$(cat "$REPO/.omp/agents/custom.md")" "consumer-owned" \
  "doctor repair preserves unrelated project agents"

printf '%s\n' '# stale body' >>"$REPO/.omp/agents/woostack-fast.md"
definition_drift="$(run_check)"
assert_contains "$definition_drift" "drifted:" \
  "doctor reports stale managed definition content"
fix_check
assert_eq "$(run_check)" "" "doctor repair clears managed definition drift"

printf '%s\n' 'consumer-ignore' 'woostack-*.md' 'woostack-*.md' \
  >"$REPO/.omp/agents/.gitignore"
ignore_drift="$(run_check)"
assert_contains "$ignore_drift" ".omp/agents/.gitignore" \
  "doctor reports duplicate generated-agent ignore coverage"
fix_check
assert_eq "$(cat "$REPO/.omp/agents/.gitignore")" $'consumer-ignore\nwoostack-*.md' \
  "doctor repair preserves consumer ignore lines and one managed rule"

assert_eq "$(run_check)" "" "project-scoped OMP doctor check remains clean"
finish
