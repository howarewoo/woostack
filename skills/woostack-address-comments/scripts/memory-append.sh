#!/usr/bin/env bash
# Appends one accept-by-design learning to ./.woostack/memory.md as a bullet,
# unless a whitespace-normalized identical bullet is already present. Creates
# the file (and dir) on first write. This is the deterministic safety net under
# the LLM's semantic dedup in the address-comments prompt.
#
# Inputs (env):
#   LEARNING   the pattern-phrased rule (required, non-empty)
#   MEMORY_FILE  path (default <repo-root>/.woostack/memory.md)
set -euo pipefail

# shellcheck source=skills/woostack-address-comments/scripts/resolve-root.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resolve-root.sh"

LEARNING="${LEARNING:?LEARNING env var required}"
MEMORY_FILE="${MEMORY_FILE:-$WOOSTACK_ROOT/.woostack/memory.md}"

# Normalize: collapse runs of whitespace, trim ends — for the dup comparison.
norm() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//'; }
NEW_NORM="$(norm "$LEARNING")"

if [ -z "$NEW_NORM" ]; then
  echo "memory-append: empty learning, nothing to write" >&2
  exit 0
fi

mkdir -p "$(dirname "$MEMORY_FILE")"
touch "$MEMORY_FILE"

# Skip if an existing bullet normalizes to the same text.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "- "*) existing="${line#- }" ;;
    *) continue ;;
  esac
  if [ "$(norm "$existing")" = "$NEW_NORM" ]; then
    echo "memory-append: already present, skipping" >&2
    exit 0
  fi
done < "$MEMORY_FILE"

printf -- '- %s\n' "$NEW_NORM" >> "$MEMORY_FILE"
echo "memory-append: appended 1 learning to $MEMORY_FILE"
