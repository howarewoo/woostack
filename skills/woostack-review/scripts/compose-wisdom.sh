#!/usr/bin/env bash
# Compose the wholesale wisdom guidance for a review.
# Usage: compose-wisdom.sh <woostack_root>
# Cats every .woostack/wisdom/*.md body to stdout, each prefixed with a
# `## SOURCE: <basename>` header (mirrors prefetch.sh's rules.md format). A no-op
# (empty output, exit 0) when the store is absent or holds no .md files. Wisdom is
# loaded WHOLESALE — there is no scope routing (that is memory's job; see recall.sh).
set -uo pipefail
ROOT="${1:-.}"
WDIR="$ROOT/.woostack/wisdom"
[ -d "$WDIR" ] || exit 0
shopt -s nullglob
for f in "$WDIR"/*.md; do
  [ -e "$f" ] || continue
  printf '## SOURCE: %s\n' "$(basename "$f")"
  cat "$f"
  printf '\n\n'
done
exit 0
