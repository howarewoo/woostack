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
