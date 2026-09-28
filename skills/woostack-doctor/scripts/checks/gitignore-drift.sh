#!/usr/bin/env bash
# gitignore-drift.sh — read-only comparison of the managed ignore file against the
# shipped template. Doctor never writes this file.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/gitignore"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

case "${1:-}" in
  -*)
    echo "gitignore-drift: '$1' is retired; drift is report-only — edit .woostack/.gitignore through the authorized editing workflow" >&2
    exit 2
    ;;
esac
GI="${1:-.}/.woostack/.gitignore"

# An absent or unreadable template proves nothing about the consumer's ignore file,
# so it is an inspection failure rather than a clean result.
if [ ! -f "$TEMPLATE" ] || [ ! -r "$TEMPLATE" ]; then
  emit error gitignore-drift report ".woostack/.gitignore" "managed ignore template is unreadable at $TEMPLATE; drift cannot be checked"
  exit 0
fi
# No-follow: report the inspection limitation instead of reading through a link that
# may resolve outside the workspace.
if [ -L "$GI" ]; then
  emit warn gitignore-drift report ".woostack/.gitignore" "managed ignore file is a symlink; inspection stopped without following it"
  exit 0
fi
if [ -e "$GI" ] && [ ! -f "$GI" ]; then
  emit error gitignore-drift report ".woostack/.gitignore" "managed ignore file is not a regular file"
  exit 0
fi
if [ -f "$GI" ] && [ ! -r "$GI" ]; then
  emit error gitignore-drift report ".woostack/.gitignore" "managed ignore file is unreadable; drift cannot be checked"
  exit 0
fi

while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  if [ -f "$GI" ]; then
    grep -qxF -- "$line" "$GI"
    case $? in
      0) continue ;;
      1) ;;
      *)
        emit error gitignore-drift report ".woostack/.gitignore" "managed ignore file could not be read; drift cannot be checked"
        exit 0
        ;;
    esac
  fi
  emit warn gitignore-drift report ".woostack/.gitignore" "missing managed line: $line"
done <"$TEMPLATE"
