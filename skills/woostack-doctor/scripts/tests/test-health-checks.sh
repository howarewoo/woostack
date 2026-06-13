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

  # --fix with no key arg must refuse, not write a bogus "" entry into config.
  r2b="$(mktemp -d)"; mkdir -p "$r2b/.woostack"; echo '{}' > "$r2b/.woostack/config.json"
  bash "$C/config-keys.sh" --fix "$r2b" >/dev/null 2>&1; assert_exit 2 "$?" "config-keys --fix without a key arg refuses"
  assert_eq "$(cat "$r2b/.woostack/config.json")" "{}" "config-keys --fix without a key leaves config untouched"
fi

# orphan-worktree
r3="$(mktemp -d)"; ( cd "$r3" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r3/.woostack/worktrees/ghost"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "orphan-worktree" "unregistered worktree dir flagged"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "report" "present unregistered dir is report (never auto-pruned)"

# Prefix-collision regression: a registered worktree (app2) whose path contains an
# orphan dir's path (app) as a prefix must NOT make the orphan look registered.
git -C "$r3" worktree add -q "$r3/.woostack/worktrees/app2" -b wt-app2
mkdir -p "$r3/.woostack/worktrees/app"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "worktrees/app	" "orphan 'app' flagged despite registered prefix-sibling 'app2'"
finish
