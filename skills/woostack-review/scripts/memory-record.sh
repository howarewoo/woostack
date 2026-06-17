#!/usr/bin/env bash
# Records one accept-by-design learning.
# If .woostack/memory/ exists, writes a scoped memory note and rebuilds MEMORY.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
INIT_SCRIPTS="$(cd "$HERE/../../woostack-init/scripts" 2>/dev/null && pwd || true)"
# shellcheck source=skills/woostack-review/scripts/resolve-root.sh
source "$HERE/resolve-root.sh"

LEARNING="${LEARNING:?LEARNING env var required}"
MEMORY_DIR="${MEMORY_DIR:-$WOOSTACK_COMMON_ROOT/.woostack/memory}"
MEMORY_SCOPE="${MEMORY_SCOPE:-*}"
MEMORY_TYPE="${MEMORY_TYPE:-convention}"
MEMORY_SOURCE="${MEMORY_SOURCE:-${PR_NUMBER:+pr-$PR_NUMBER}}"
MEMORY_SOURCE="${MEMORY_SOURCE:-address-comments}"

norm() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//'; }
NEW_NORM="$(norm "$LEARNING")"

if [ -z "$NEW_NORM" ]; then
  echo "memory-record: empty learning, nothing to write" >&2
  exit 0
fi

if [ ! -d "$MEMORY_DIR" ]; then
  echo "memory-record: no scoped store at $MEMORY_DIR; skipping (run /woostack-init)" >&2
  exit 0
fi

note_body_of() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

shopt -s nullglob
for f in "$MEMORY_DIR"/*.md; do
  [ "$(basename "$f")" = "MEMORY.md" ] && continue
  if [ "$(norm "$(note_body_of "$f")")" = "$NEW_NORM" ]; then
    echo "memory-record: already present, skipping"
    exit 0
  fi
done

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' \
    | cut -c1-60 \
    | sed 's/-$//'
}

name="${MEMORY_NAME:-$(slugify "$NEW_NORM")}"
[ -n "$name" ] || name="accepted-review-finding"
file="$MEMORY_DIR/$name.md"
if [ -e "$file" ]; then
  base_name="$name"
  i=2
  while [ -e "$MEMORY_DIR/$base_name-$i.md" ]; do i=$((i + 1)); done
  name="$base_name-$i"
  file="$MEMORY_DIR/$name.md"
fi

updated="${WOOSTACK_NOW:-$(date +%F)}"
cat > "$file" <<EOF
---
name: $name
type: $MEMORY_TYPE
scope: $MEMORY_SCOPE
updated: $updated
source: $MEMORY_SOURCE
---
$NEW_NORM
EOF

if [ -n "$INIT_SCRIPTS" ] && [ -x "$INIT_SCRIPTS/build-index.sh" ]; then
  bash "$INIT_SCRIPTS/build-index.sh" "$MEMORY_DIR"
else
  echo "memory-record: build-index.sh unavailable; wrote note without rebuilding index" >&2
fi

echo "memory-record: wrote scoped learning to $file"
