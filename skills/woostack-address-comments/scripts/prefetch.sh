#!/usr/bin/env bash
# Address-comments prefetch: unresolved threads + changed paths.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# shellcheck source=skills/woostack-address-comments/scripts/resolve-outdir.sh
source "$HERE/resolve-outdir.sh"
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


echo "Address prefetch complete: $OUTDIR"
