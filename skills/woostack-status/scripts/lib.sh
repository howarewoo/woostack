#!/usr/bin/env bash
# Minimal frontmatter + date helpers for status.sh (bundled so the skill is
# self-contained). Mirrors woostack-init/scripts/lib.sh; keep formats in sync
# with ../references/conventions.md.

# field <file> <key> -> first matching frontmatter value (trimmed), empty if absent.
field() {
  sed -n '/^---$/,/^---$/p' "$1" \
    | grep -m1 "^$2:" \
    | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*$//"
}

# note_body <file> -> everything after the closing frontmatter fence.
note_body() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

# _woo_now -> today's ISO date (YYYY-MM-DD). Override with WOOSTACK_NOW for tests.
_woo_now() { printf '%s\n' "${WOOSTACK_NOW:-$(date +%F)}"; }

# _woo_epoch <YYYY-MM-DD> -> Unix epoch seconds at 00:00:00. GNU then BSD date.
_woo_epoch() {
  local d="$1" e
  e="$(date -d "$d 00:00:00" +%s 2>/dev/null)" \
    || e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)" \
    || return 1
  printf '%s\n' "$e"
}
