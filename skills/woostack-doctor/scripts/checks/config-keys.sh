#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/config.json"
RESOLVER="${WOOSTACK_BACKEND_RESOLVER:-$HERE/../../../woostack-init/scripts/artifacts/resolve-backend.sh}"
LINEAR="${WOOSTACK_LINEAR_ADAPTER:-$HERE/../../../woostack-init/scripts/artifacts/linear.sh}"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
[ -f "$TEMPLATE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; key="${3:-}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
CFG="$WOO_ROOT/.woostack/config.json"

if [ "$FIX" -eq 1 ]; then
  # An empty key arg would make jq write a bogus "" entry into config.json
  # (silent corruption). Require a real key; the orchestrator always passes one.
  [ -n "$key" ] || { echo "config-keys.sh: --fix requires a key argument" >&2; exit 2; }
  [ -f "$CFG" ] || echo '{}' > "$CFG"
  val="$(jq -c --arg k "$key" '.[$k]' "$TEMPLATE")"
  tmp="$(mktemp)"; jq --arg k "$key" --argjson v "$val" '.[$k]=$v' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
  exit $?
fi
req_keys="$(jq -r 'keys[]' "$TEMPLATE")"
for k in $req_keys; do
  if [ ! -f "$CFG" ] || [ "$(jq --arg k "$k" 'has($k)' "$CFG" 2>/dev/null)" != "true" ]; then
    emit warn config-key auto ".woostack/config.json" "missing required config key: $k"
  fi
done

# Backend configuration is a static doctor concern. Resolution validates the selector,
# repository identity, mapping shapes, and credential-free config without touching Linear.
if [ ! -f "$RESOLVER" ] || [ ! -r "$RESOLVER" ]; then
  emit error artifact-config report ".woostack/config.json" "artifact backend resolver is unavailable"
  exit 0
fi
backend_error="$(mktemp)"
if ! backend="$(bash "$RESOLVER" "$WOO_ROOT" 2>"$backend_error")"; then
  safe_path="$(cat "$backend_error")"
  safe_path="${safe_path##* at }"
  [ -n "$safe_path" ] || safe_path=".woostack/config.json"
  rm -f "$backend_error"
  emit error artifact-config report ".woostack/config.json" "invalid artifact backend config at $safe_path"
  exit 0
fi
rm -f "$backend_error"
[ "$(jq -r '.backend' <<<"$backend")" = linear ] || exit 0

# Local specs/plans are deliberately inactive in Linear mode. Surface them for deliberate
# archival, but never reinterpret, repair, delete, migrate, or synchronize them.
shopt -s nullglob
for dir in specs plans; do
  for file in "$WOO_ROOT/.woostack/$dir"/*.md; do
    emit warn artifact-legacy-local report "${file#"$WOO_ROOT"/}" "inactive legacy local artifact; Linear is the configured spec/plan backend"
  done
done

# Remote diagnostics are explicit. Static doctor never reads credentials or makes a request.
# The controller owns the single authenticated preflight and exports its non-secret receipt.
[ "${WOOSTACK_DOCTOR_LIVE:-0}" = 1 ] || exit 0
live_context="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
[ -r "$live_context" ] || exit 0
jq -e '.ready == true' "$live_context" >/dev/null 2>&1 || exit 0
live_config="$(jq -c '.preflight' "$live_context")"
if ! bash "$LINEAR" doctor-read \
  --repository "$(jq -r '.repository' <<<"$backend")" \
  --status-map "$(jq -c '.projectStatuses' <<<"$live_config")" \
  --issue-state-map "$(jq -c '.issueStates' <<<"$live_config")" >/dev/null 2>&1; then
  emit error linear-live report ".woostack/config.json" "authenticated Linear resource validation failed (existence, ownership, managed metadata, or native relations)"
  exit 0
fi
emit warn linear-write-scope-unverifiable report ".woostack/config.json" "Linear exposes no non-mutating effective write-scope introspection; live doctor does not pre-prove future mutation authorization, and actual mutations remain fail-closed"
