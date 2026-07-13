#!/usr/bin/env bash
# doctor.sh — woostack workspace health orchestrator. Runs checks/*.sh, groups
# findings, exits nonzero iff any error. --check = CI annotations; --live opts into Linear API validation.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="${WOOSTACK_BACKEND_RESOLVER:-$HERE/../../woostack-init/scripts/artifacts/resolve-backend.sh}"
LINEAR="${WOOSTACK_LINEAR_ADAPTER:-$HERE/../../woostack-init/scripts/artifacts/linear.sh}"

CHECK_ONLY=0; LIVE=0; TARGET="."
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    --live) LIVE=1 ;;
    -*) echo "doctor: unknown flag: $a" >&2; exit 2 ;;
    *)  TARGET="$a" ;;
  esac
done

WOO_ROOT="$(cd "$TARGET" 2>/dev/null && pwd)" \
  || { echo "doctor: path not found: $TARGET" >&2; exit 2; }
if [ ! -d "$WOO_ROOT/.woostack" ]; then
  echo "doctor: no .woostack/ at $WOO_ROOT — run woostack-init first" >&2
  exit 2
fi

export WOOSTACK_DOCTOR_LIVE="$LIVE"

findings="$(mktemp)"
live_context="$(mktemp)"
trap 'rm -f "$findings" "$live_context"' EXIT
printf '%s\n' '{"ready":false}' >"$live_context"
export WOOSTACK_DOCTOR_LIVE_CONTEXT="$live_context"

# Authenticate exactly once, before checks. The receipt contains normalized, non-secret
# backend/preflight data for every live-aware check; checks never repeat preflight.
if [ "$LIVE" -eq 1 ] && backend="$(bash "$RESOLVER" "$WOO_ROOT" 2>/dev/null)" &&
  [ "$(jq -r '.backend' <<<"$backend")" = linear ]; then
  if [ ! -f "$LINEAR" ] || [ ! -r "$LINEAR" ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' error linear-live report ".woostack/config.json" \
      "normalized Linear adapter is unavailable" >>"$findings"
  elif live_config="$(bash "$LINEAR" preflight \
    --workspace "$(jq -r '.linear.workspace' <<<"$backend")" \
    --team "$(jq -r '.linear.team' <<<"$backend")" \
    --project-statuses "$(jq -c '.linear.projectStatuses' <<<"$backend")" \
    --issue-states "$(jq -c '.linear.issueStates' <<<"$backend")" 2>/dev/null)"; then
    jq -cn --argjson backend "$backend" --argjson preflight "$live_config" \
      '{ready:true,backend:$backend,preflight:$preflight}' >"$live_context"
  else
    printf '%s\t%s\t%s\t%s\t%s\n' error linear-live report ".woostack/config.json" \
      "authenticated Linear preflight failed (identity/active access, schema, workspace/team visibility, mappings, or required capabilities)" >>"$findings"
  fi
fi
shopt -s nullglob
for chk in "$HERE"/checks/*.sh; do
  bash "$chk" "$WOO_ROOT" >> "$findings" 2>/dev/null || true
done

errors=0; warnings=0
TAB="$(printf '\t')"
while IFS="$TAB" read -r sev code fixable path msg; do
  [ -z "${sev:-}" ] && continue
  case "$sev" in
    error) errors=$((errors+1)); echo "::error:: [$code] $path: $msg" >&2 ;;
    warn)  warnings=$((warnings+1)); echo "::warning:: [$code] $path: $msg" >&2 ;;
  esac
done < "$findings"

[ "$CHECK_ONLY" -eq 0 ] && cat "$findings"
rm -f "$findings"

echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
