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

# set_field <file> <key> <value> — set a frontmatter key (update if present, else
# insert before the closing fence). Rewrites ONLY the first frontmatter block;
# body and all other fields are preserved verbatim. Atomic: writes a temp file in
# the note's own directory, then mv's it over the original. Returns non-zero
# WITHOUT modifying the file if it lacks two '---' fences or the write fails.
set_field() {
  local file="$1" key="$2" val="$3" tmp dir
  [ "$(grep -c '^---$' "$file" 2>/dev/null)" -ge 2 ] || return 1
  dir="$(dirname "$file")"
  tmp="$(mktemp "$dir/.woomem.XXXXXX")" || return 1
  awk -v key="$key" -v val="$val" '
    {
      if ($0 == "---") {
        fence++
        if (fence == 1) { infm=1; print; next }
        if (fence == 2) { if (infm && !seen) print key ": " val; infm=0; print; next }
      }
      if (infm && !seen && index($0, key ":") == 1) { print key ": " val; seen=1; next }
      print
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
}
