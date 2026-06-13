#!/usr/bin/env bash
# orphan-worktree.sh — flag worktree drift under .woostack/worktrees/. SAFE: the only
# auto repair is `git worktree prune` (clears git's admin entries for already-gone dirs);
# a present unregistered dir may hold uncommitted work, so it is always `report` (manual).
set -uo pipefail
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  ( cd "${2:-.}" && git worktree prune ) 2>/dev/null || true
  exit 0
fi
WOO_ROOT="${1:-.}"
wt_dir="$WOO_ROOT/.woostack/worktrees"
[ -d "$wt_dir" ] || exit 0

registered="$(cd "$WOO_ROOT" && git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')"
shopt -s nullglob
for d in "$wt_dir"/*/; do
  d="${d%/}"; abs="$(cd "$d" 2>/dev/null && pwd)" || continue
  case "$registered" in *"$abs"*) continue ;; esac
  emit warn orphan-worktree report "${d#$WOO_ROOT/}" "unregistered worktree dir (manual review/remove — may hold work)"
done
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in "$wt_dir"/*) [ -d "$p" ] || emit warn orphan-worktree auto "${p#$WOO_ROOT/}" "stale worktree registration (git worktree prune)" ;; esac
done <<< "$registered"
