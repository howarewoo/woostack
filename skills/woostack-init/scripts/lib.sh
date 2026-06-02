#!/usr/bin/env bash
# Shared frontmatter helpers for the woostack-init scripts.
# Frontmatter is line-oriented: between two `---` fences, one `key: value` per line.

# field <file> <key> → first matching value (trimmed), empty if absent.
field() {
  sed -n '/^---$/,/^---$/p' "$1" \
    | grep -m1 "^$2:" \
    | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*$//"
}

# note_body <file> → everything after the closing frontmatter fence.
note_body() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

# first_body_line <file> → first non-empty body line, trimmed.
first_body_line() {
  note_body "$1" | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# _woo_now → today's ISO date (YYYY-MM-DD). Override with WOOSTACK_NOW for tests.
_woo_now() { printf '%s\n' "${WOOSTACK_NOW:-$(date +%F)}"; }

# _woo_epoch <YYYY-MM-DD> → Unix epoch seconds at 00:00:00 of that date.
# Time-of-day is zeroed so age math and tests are deterministic. Tries GNU
# `date -d` first, falls back to BSD `date -j -f`. Non-zero on unparseable input.
_woo_epoch() {
  local d="$1" e
  e="$(date -d "$d 00:00:00" +%s 2>/dev/null)" \
    || e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)" \
    || return 1
  printf '%s\n' "$e"
}
