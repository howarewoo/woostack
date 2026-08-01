#!/usr/bin/env bash
# Structural contract for documented worktree helpers and task placement.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_DIR="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$INIT_DIR/../.." && pwd)"
CONTRACT="$HERE/../worktrees.md"
AUTHORED_PAGE="$REPO_ROOT/site/content/docs/concepts/worktrees.mdx"
failures=0

while IFS= read -r reference; do
  asset="${reference#<wi>/}"
  if [ ! -f "$INIT_DIR/$asset" ]; then
    printf 'missing worktree helper asset: %s\n' "$reference" >&2
    failures=$((failures + 1))
  fi
done < <(LC_ALL=C grep -oE '<wi>/scripts/[A-Za-z0-9._/-]+' "$CONTRACT" | LC_ALL=C sort -u)

contract_paths="$(LC_ALL=C grep -oE '\.woostack/worktrees/tasks/<[A-Za-z0-9._-]+>' "$CONTRACT" | LC_ALL=C sort -u || true)"
authored_paths="$(LC_ALL=C grep -oE '\.woostack/worktrees/tasks/<[A-Za-z0-9._-]+>' "$AUTHORED_PAGE" | LC_ALL=C sort -u || true)"
if [ "$contract_paths" != "$authored_paths" ] || [ -z "$authored_paths" ]; then
  printf 'task worktree path drift:\n  worktrees.md: %s\n  authored page: %s\n' \
    "${contract_paths:-<missing>}" "${authored_paths:-<missing>}" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

printf 'PASS worktrees contract\n'
