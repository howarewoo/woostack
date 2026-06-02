#!/usr/bin/env bash
# doctor.sh — lint the memory/ dir. Warnings exit 0; errors exit 1.
# Lints the dir only; the flat memory.md is free-form and never read.
# -e intentionally omitted: a linter must continue past per-note failures
# to report every error in one run, not abort on the first.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

MEM_DIR="${1:-.woostack/memory}"
VALID_TYPES=" decision pattern gotcha convention hotspot "
errors=0; warnings=0
seen="$(mktemp)"
paths="$(git ls-files 2>/dev/null || true)"

err()  { echo "::error:: $1" >&2; errors=$((errors+1)); }
warn() { echo "::warning:: $1" >&2; warnings=$((warnings+1)); }

shopt -s nullglob
for f in "$MEM_DIR"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue

  if [ "$(head -1 "$f")" != "---" ]; then
    err "$base: malformed — missing opening '---' frontmatter fence"; continue
  fi

  name="$(field "$f" name)"; type="$(field "$f" type)"
  body="$(note_body "$f" | tr -d '[:space:]')"

  [ -z "$name" ] && err "$base: missing required field: name"
  [ -z "$type" ] && err "$base: missing required field: type"
  [ -z "$body" ] && err "$base: empty body"
  if [ -n "$type" ] && [ "${VALID_TYPES/ $type /}" = "$VALID_TYPES" ]; then
    err "$base: unknown type: $type"
  fi

  if [ -n "$name" ]; then
    if grep -qxF "$name" "$seen"; then err "$base: duplicate name: $name"
    else echo "$name" >> "$seen"; fi
  fi

  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    if ! printf '%s\n' "$paths" | bash "$HERE/scope-match.sh" "$scope" >/dev/null 2>&1; then
      warn "$base: scope '$scope' matches no tracked files (stale)"
    fi
  fi

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    [ -f "$MEM_DIR/$link.md" ] || warn "$base: unresolved [[$link]]"
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u)

  # Dead-note signal: old (by updated:) AND never recalled → prune candidate.
  # Requires updated: (no age basis otherwise). Warning only.
  upd="$(field "$f" updated)"
  if [ -n "$upd" ]; then
    upd_e="$(_woo_epoch "$upd" || true)"
    if [ -n "$upd_e" ]; then
      now_e="$(_woo_epoch "$(_woo_now)")"
      rc="$(field "$f" recall_count)"; rc="${rc:-0}"
      case "$rc" in (*[!0-9]*) rc=0 ;; esac
      age=$(( ( now_e - upd_e ) / 86400 ))
      if [ "$age" -gt "${WOOSTACK_DEAD_DAYS:-90}" ] && [ "$rc" -eq 0 ]; then
        warn "$base: dead note — written ${age}d ago, never recalled (prune candidate)"
      fi
    fi
  fi
done
rm -f "$seen"

echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
