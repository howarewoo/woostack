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

# --- telemetry sidecar: per-clone, gitignored, line-based TSV ---
# <memdir>/.telemetry.tsv rows: name<TAB>recall_count<TAB>last_recalled
_tel_file() { printf '%s\n' "$1/.telemetry.tsv"; }

# tel_get <memdir> <name> <recall_count|last_recalled> -> value, empty if absent.
tel_get() {
  local f col; f="$(_tel_file "$1")"; [ -f "$f" ] || return 0
  case "$3" in recall_count) col=2 ;; last_recalled) col=3 ;; *) return 0 ;; esac
  awk -F'\t' -v n="$2" -v c="$col" '$1==n{print $c; exit}' "$f"
}

# tel_bump <memdir> <name> <iso-date> — upsert: increment count, set date.
# Atomic (temp + mv). Returns non-zero without changing the file on write failure.
tel_bump() {
  local memdir="$1" name="$2" date="$3" f tmp cur=0
  f="$(_tel_file "$memdir")"
  [ -d "$memdir" ] || return 1
  if [ -f "$f" ]; then
    cur="$(awk -F'\t' -v n="$name" '$1==n{print $2; exit}' "$f")"; cur="${cur:-0}"
    case "$cur" in (*[!0-9]*) cur=0 ;; esac
  fi
  tmp="$(mktemp "$memdir/.tel.XXXXXX")" || return 1
  { [ -f "$f" ] && awk -F'\t' -v n="$name" '$1!=n' "$f"
    printf '%s\t%s\t%s\n' "$name" "$(( cur + 1 ))" "$date"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# del_field <file> <key> — remove a frontmatter key (atomic). No-op if absent.
del_field() {
  local file="$1" key="$2" tmp dir
  dir="$(dirname "$file")"; tmp="$(mktemp "$dir/.woomem.XXXXXX")" || return 1
  awk -v key="$key" '
    /^---$/{fence++; if(fence<=2){print; next}}
    { if(fence==1 && index($0, key ":")==1) next; print }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
}
