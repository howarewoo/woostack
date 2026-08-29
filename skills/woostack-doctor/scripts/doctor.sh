#!/usr/bin/env bash
# doctor.sh — provider-free woostack workspace health orchestrator.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ONLY=0
LIVE_RECEIPT=""
TARGET="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --live-receipt)
      [ "$#" -ge 2 ] || { echo "doctor: --live-receipt requires a path" >&2; exit 2; }
      LIVE_RECEIPT="$2"; shift 2 ;;
    --live)
      echo "doctor: --live is controller-owned; supply --live-receipt <path> after provider preflight (gh for GitHub, official MCP for Linear/Plane)" >&2
      exit 2 ;;
    -*) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

WOO_ROOT="$(cd "$TARGET" 2>/dev/null && pwd)" \
  || { echo "doctor: path not found: $TARGET" >&2; exit 2; }
if [ ! -d "$WOO_ROOT/.woostack" ]; then
  echo "doctor: no .woostack/ at $WOO_ROOT — run woostack-init first" >&2
  exit 2
fi

findings="$(mktemp)"
live_context="$(mktemp)"
trap 'rm -f "$findings" "$live_context"' EXIT
printf '%s\n' '{"ready":false}' >"$live_context"
export WOOSTACK_DOCTOR_LIVE=0
export WOOSTACK_DOCTOR_LIVE_CONTEXT="$live_context"

if [ -n "$LIVE_RECEIPT" ]; then
  if [ ! -f "$LIVE_RECEIPT" ] || [ ! -r "$LIVE_RECEIPT" ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' error linear-live report ".woostack/config.json" \
      "normalized provider live receipt is missing or unreadable" >>"$findings"
  else
    cat "$LIVE_RECEIPT" >"$live_context"
    chmod 600 "$live_context"
    export WOOSTACK_DOCTOR_LIVE=1
  fi
fi

shopt -s nullglob
for chk in "$HERE"/checks/*.sh; do
  bash "$chk" "$WOO_ROOT" >>"$findings" 2>/dev/null || true
done

errors=0
warnings=0
TAB="$(printf '\t')"
while IFS="$TAB" read -r sev code fixable path msg; do
  [ -z "${sev:-}" ] && continue
  case "$sev" in
    error) errors=$((errors+1)); echo "::error:: [$code] $path: $msg" >&2 ;;
    warn) warnings=$((warnings+1)); echo "::warning:: [$code] $path: $msg" >&2 ;;
  esac
done <"$findings"

[ "$CHECK_ONLY" -eq 0 ] && cat "$findings"
echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
