#!/usr/bin/env bash
# Address-comments prefetch: unresolved threads + changed paths + memory context.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

# shellcheck source=skills/woostack-address-comments/scripts/resolve-outdir.sh
source "$HERE/resolve-outdir.sh"
# shellcheck source=skills/woostack-address-comments/scripts/resolve-root.sh
source "$HERE/resolve-root.sh"
WOOSTACK_DIR="$WOOSTACK_ROOT/.woostack"
mkdir -p "$OUTDIR"

PR_NUMBER="${PR_NUMBER:-$(gh pr view --json number --jq .number 2>/dev/null || echo)}"
PR_NUMBER="${PR_NUMBER:?PR_NUMBER env var required, or run from a branch with an open PR}"
export PR_NUMBER

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo)}"
export GITHUB_REPOSITORY

bash "$HERE/fetch-threads.sh"

PATHS_FILE="$OUTDIR/address-changed-paths.txt"
if [ "${WOO_REVIEW_TEST_MODE:-}" = "1" ] && [ -n "${WOO_ADDRESS_FAKE_CHANGED_PATHS:-}" ]; then
  printf '%s\n' "$WOO_ADDRESS_FAKE_CHANGED_PATHS" > "$PATHS_FILE"
else
  gh pr view "$PR_NUMBER" --json files --jq '.files[].path' > "$PATHS_FILE" 2>/dev/null || : > "$PATHS_FILE"
fi

MEMORY_OUT="$OUTDIR/memory.md"
rm -f "$MEMORY_OUT"
if [ -d "$WOOSTACK_DIR/memory" ] && [ -x "$ROOT/skills/woostack-init/scripts/recall.sh" ]; then
  bash "$ROOT/skills/woostack-init/scripts/recall.sh" "$WOOSTACK_DIR" "$PATHS_FILE" > "$MEMORY_OUT" 2>"$OUTDIR/recall.log" || : > "$MEMORY_OUT"
fi

if [ -f "$MEMORY_OUT" ]; then
  bytes="$(wc -c < "$MEMORY_OUT" | tr -d ' ')"
  echo "Composed address memory: ${bytes}B"
else
  echo "Composed address memory: none"
fi

echo "Address prefetch complete: $OUTDIR"
