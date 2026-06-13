#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

# gitignore-drift
r="$(mktemp -d)"; mkdir -p "$r/.woostack"; : > "$r/.woostack/.gitignore"
assert_contains "$(bash "$C/gitignore-drift.sh" "$r")" "gitignore-drift" "empty .gitignore drifts"
bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(bash "$C/gitignore-drift.sh" "$r")" "" "after fix, no drift"
before="$(wc -l < "$r/.woostack/.gitignore")"; bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(wc -l < "$r/.woostack/.gitignore")" "$before" "gitignore fix idempotent"

# config-keys (skips cleanly when jq absent)
if command -v jq >/dev/null 2>&1; then
  r2="$(mktemp -d)"; mkdir -p "$r2/.woostack"; echo '{}' > "$r2/.woostack/config.json"
  assert_contains "$(bash "$C/config-keys.sh" "$r2")" "config-key" "empty config missing keys"
  for k in $(jq -r 'keys[]' "$HERE/../../../woostack-init/templates/config.json"); do
    bash "$C/config-keys.sh" --fix "$r2" "$k"
  done
  assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "after fixing all keys, clean"
fi

# orphan-worktree
r3="$(mktemp -d)"; ( cd "$r3" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r3/.woostack/worktrees/ghost"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "orphan-worktree" "unregistered worktree dir flagged"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "report" "present unregistered dir is report (never auto-pruned)"
finish
