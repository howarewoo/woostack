#!/usr/bin/env bash
# graph.sh <memdir> <note> [--links|--backlinks]
# Note links/backlinks over the memory store. Default: grep markdown wikilinks
# (headless, always works). Opt-in: when WOOSTACK_OBSIDIAN=1 AND the `obsidian`
# CLI is present, try `obsidian eval`; on ANY failure fall back to grep + warn.
# Obsidian is never required and never fatal.
set -euo pipefail
MEM_DIR="${1:?memdir required}"; NOTE_ARG="${2:?note required}"; MODE="${3:---links}"
NOTE="${NOTE_ARG%.md}"
NOTE_FILE="$MEM_DIR/$NOTE.md"
NOTE_ESC="$(printf '%s' "$NOTE" | sed 's/[].[\^$*+?{}|()/\\]/\\&/g')"

grep_links() {
  [ -r "$NOTE_FILE" ] || { echo "graph: note not found or unreadable: $NOTE_FILE" >&2; exit 1; }
  grep -oE '\[\[[^]]+\]\]' "$NOTE_FILE" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u || true
}

grep_backlinks() {
  shopt -s nullglob
  for f in "$MEM_DIR"/*.md; do
    b="$(basename "$f" .md)"
    [ "$b" = "$NOTE" ] && continue
    grep -qE "\[\[$NOTE_ESC\]\]" "$f" 2>/dev/null && echo "$b"
  done
  return 0
}

obsidian_try() {
  command -v obsidian >/dev/null 2>&1 || return 1
  # Best-effort; any non-zero / empty result lets the caller fall back to grep.
  case "$MODE" in
    --links)     obsidian eval "this.app.metadataCache.resolvedLinks" 2>/dev/null || return 1 ;;
    --backlinks) obsidian eval "this.app.metadataCache.getBacklinksForFile" 2>/dev/null || return 1 ;;
    *) return 1 ;;
  esac
}

if [ "${WOOSTACK_OBSIDIAN:-0}" = "1" ] && command -v obsidian >/dev/null 2>&1; then
  if out="$(obsidian_try)" && [ -n "$out" ]; then printf '%s\n' "$out"; exit 0; fi
  echo "graph: obsidian eval unavailable; using grep fallback" >&2
fi

case "$MODE" in
  --links)     grep_links ;;
  --backlinks) grep_backlinks ;;
  *) echo "graph: unknown mode: $MODE (use --links or --backlinks)" >&2; exit 2 ;;
esac
