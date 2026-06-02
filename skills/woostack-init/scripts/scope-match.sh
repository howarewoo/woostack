#!/usr/bin/env bash
# scope-match.sh — print stdin paths matching a comma-separated glob spec.
# Glob semantics: *→[^/]*  **→.*  exact→literal(dots escaped)  ""|*→global.
# Exit 0 if >=1 path matched, 1 otherwise.
set -euo pipefail

SPEC="${1:-}"

glob_to_ere() {
  local g="$1" out="" i=0 n=${#1} c
  while [ "$i" -lt "$n" ]; do
    c=${g:$i:1}
    case "$c" in
      '*')
        if [ "${g:$((i+1)):1}" = '*' ]; then out+='.*'; i=$((i+2));
        else out+='[^/]*'; i=$((i+1)); fi ;;
      '.'|'+'|'?'|'('|')'|'['|']'|'{'|'}'|'|'|'^'|'$'|'\') out+="\\$c"; i=$((i+1)) ;;
      *) out+="$c"; i=$((i+1)) ;;
    esac
  done
  printf '^%s$' "$out"
}

trimmed="$(printf '%s' "$SPEC" | tr -d '[:space:]')"
if [ -z "$trimmed" ] || [ "$trimmed" = '*' ]; then
  # global — echo all stdin, succeed if non-empty (needs >=1 char to skip blank/empty stdin)
  if grep -E '.+'; then exit 0; else exit 1; fi
fi

ERE=""
IFS=',' read -ra parts <<< "$SPEC"
for p in "${parts[@]}"; do
  g="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$g" ] && continue
  e="$(glob_to_ere "$g")"
  if [ -z "$ERE" ]; then ERE="$e"; else ERE="$ERE|$e"; fi
done
[ -z "$ERE" ] && exit 1

if grep -E "$ERE"; then exit 0; else exit 1; fi
