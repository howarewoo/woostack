#!/usr/bin/env bash
# recall.sh <woostack_dir> <paths_file> — compose per-PR memory context.
# stdout: ## Scoped memory + ## Linked notes + ## Global memory.
# The global shard (flat memory.md + no-scope/`*` notes) is ALWAYS included and
# never dropped by RECALL_CAP (bytes, default 102400). Scoped/linked notes fill
# the remaining budget; lowest match-count dropped first (logged to stderr).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
SCOPE_MATCH="$HERE/scope-match.sh"

WOO="${1:?woostack_dir required}"; PATHS_FILE="${2:?paths_file required}"
CAP="${RECALL_CAP:-102400}"
MEM_DIR="$WOO/memory"; FLAT="$WOO/memory.md"
paths="$(cat "$PATHS_FILE" 2>/dev/null || true)"

is_global() { local s; s="$(printf '%s' "$1" | tr -d '[:space:]')"; [ -z "$s" ] || [ "$s" = '*' ]; }
render() { local nm; nm="$(field "$1" name)"; printf '### %s\n%s\n' "${nm:-$(basename "$1" .md)}" "$(note_body "$1")"; }

# inc_set: temp file storing one basename per line for dedup.
inc_set="$(mktemp)"
matched="$(mktemp)"; linked="$(mktemp)"; globals="$(mktemp)"
trap 'rm -f "$matched" "$linked" "$globals" "$inc_set"' EXIT

in_set() { grep -qxF -- "$1" "$inc_set" 2>/dev/null; }
add_set() { printf '%s\n' "$1" >> "$inc_set"; }

if [ -d "$MEM_DIR" ]; then
  shopt -s nullglob
  for f in "$MEM_DIR"/*.md; do
    b="$(basename "$f")"; [ "$b" = "MEMORY.md" ] && continue
    scope="$(field "$f" scope || true)"
    if is_global "$scope"; then printf '%s\n' "$f" >> "$globals"; add_set "$b"; continue; fi
    [ -z "$paths" ] && continue
    cnt="$(printf '%s\n' "$paths" | bash "$SCOPE_MATCH" "$scope" 2>/dev/null | grep -c . || true)"
    [ "${cnt:-0}" -gt 0 ] && printf '%s\t%s\n' "$cnt" "$f" >> "$matched"
  done
fi

# Read sorted matched files into array (bash 3.2 compatible: no mapfile).
matched_files=()
while IFS= read -r line; do
  [ -n "$line" ] && matched_files+=("$line")
done < <(sort -t"$(printf '\t')" -k1,1nr "$matched" | cut -f2-)

for f in "${matched_files[@]:-}"; do
  [ -n "${f:-}" ] && add_set "$(basename "$f")"
done
for f in "${matched_files[@]:-}"; do
  [ -n "${f:-}" ] || continue
  while IFS= read -r lk; do
    [ -z "$lk" ] && continue
    lf="$MEM_DIR/$lk.md"
    if [ -f "$lf" ] && ! in_set "$lk.md"; then add_set "$lk.md"; printf '%s\n' "$lf" >> "$linked"; fi
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u)
done

# Read linked files into array (bash 3.2 compatible).
linked_files=()
while IFS= read -r line; do
  [ -n "$line" ] && linked_files+=("$line")
done < "$linked"

global_out=""
[ -f "$FLAT" ] && global_out="$(cat "$FLAT")"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ -n "$global_out" ]; then global_out+=$'\n\n'; fi
  global_out+="$(render "$f")"
done < "$globals"

scoped_out=""; linked_out=""
gbytes=${#global_out}
budget=$(( CAP - gbytes ))
if [ "$budget" -le 0 ] && [ -n "$global_out" ]; then
  global_out="$(printf '%s' "$global_out" | tail -c "$CAP")"
  echo "recall: global shard exceeds cap; tail-capped, scoped notes dropped" >&2
else
  for f in "${matched_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    chunk="$(render "$f")"$'\n\n'
    if [ $(( ${#scoped_out} + ${#chunk} )) -le "$budget" ]; then scoped_out+="$chunk"
    else echo "recall: dropped $(basename "$f") (cap)" >&2; fi
  done
  rem=$(( budget - ${#scoped_out} ))
  for f in "${linked_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    chunk="$(render "$f")"$'\n\n'
    if [ $(( ${#linked_out} + ${#chunk} )) -le "$rem" ]; then linked_out+="$chunk"
    else echo "recall: dropped linked $(basename "$f") (cap)" >&2; fi
  done
fi

[ -n "$scoped_out" ] && printf '## Scoped memory (matched this PR)\n\n%s' "$scoped_out"
[ -n "$linked_out" ] && printf '## Linked notes\n\n%s' "$linked_out"
[ -n "$global_out" ] && printf '## Global memory\n\n%s\n' "$global_out"
exit 0
