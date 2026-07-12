#!/usr/bin/env bash
# Resolve the concrete model slug for a (provider, tier) pair, honoring per-repo
# overrides in $OUTDIR/config.json. This is the config-aware resolver the LOCAL
# Stage-3 per-call-routing path uses before each sub-agent spawn (and for the
# receipt's `model`), so `.woostack/config.json` model overrides are honored
# immediately instead of falling back to the static default table (issue #295).
#
# Owns precedence steps 3-5 for a GIVEN tier:
#   3. models.<provider>.<tier>  (from $OUTDIR/config.json)
#   4. flat models.<tier>        (from $OUTDIR/config.json)
#   5. default model table       (canonical mirror of model-tiers.md)
# Steps 1-2 (FORCE_TIER / comment override selects the tier; a global input model
# wins outright) stay with the host, mirroring load-prompt.sh, which separates
# RUN_TIER selection from provider_tier_model. This emits the model slug only;
# OpenAI `reasoning_effort` is a single-session-host knob owned by load-prompt.sh.
#
# Usage: resolve-model.sh --provider <anthropic|openai|google|openrouter> \
#                         --tier <fast|standard|deep> [--index <n>]
# Reads $OUTDIR/config.json when present (CONFIG_PATH overrides the path).
# --index N resolves the Nth entry of the winning models.<tier> fallback list
#   (N=0 = the primary, unchanged). No entry at N (out of range, or a scalar/
#   object leaf with no fallback beyond 0) exits 3 with no output, so the review
#   orchestrator can walk the configured chain on a usage/rate-limit re-dispatch
#   and tell "chain exhausted" (exit 3) from a usage error (exit 1) (issue #494).
# Safe to `source` for its functions — main only runs on direct execution.

set -euo pipefail

# canonical source: skills/using-woostack/references/model-tiers.md — keep these slugs in sync
# with that table (Bash cannot read the markdown table, so this is its executable mirror).
default_model_for() {
  local provider="$1" tier="$2"
  case "$provider" in
    anthropic)
      # Opus on every tier; tiers are differentiated by effort (fast=low,
      # standard=medium, deep=xhigh), not by model. Effort is applied per-call in
      # prompts/anthropic.md, not here (this emits the model slug only).
      case "$tier" in
        fast) echo "claude-opus-4-8" ;;
        standard) echo "claude-opus-4-8" ;;
        deep) echo "claude-opus-4-8" ;;
      esac
      ;;
    openai)
      case "$tier" in
        fast) echo "gpt-5.5" ;;
        standard) echo "gpt-5.5" ;;
        deep) echo "gpt-5.5" ;;
      esac
      ;;
    google)
      echo "gemini-3-5-flash"
      ;;
    openrouter)
      case "$tier" in
        fast) echo "openrouter/deepseek/deepseek-v4-flash" ;;
        standard) echo "openrouter/deepseek/deepseek-v4-pro" ;;
        deep) echo "openrouter/deepseek/deepseek-v4-pro" ;;
      esac
      ;;
    *)
      echo "::error::Unknown provider '$provider' while resolving run model" >&2
      exit 1
      ;;
  esac
}

# provider_tier_model <provider> <tier> → resolved model (config override → default).
# Reads CONFIG_PATH, defaulting to $OUTDIR/config.json.
provider_tier_model() {
  local provider="$1" tier="$2"
  local config="${CONFIG_PATH:-${OUTDIR:-}/config.json}"
  local override
  if [ -n "$config" ] && [ -f "$config" ]; then
    # Array leaf = ordered fallback list; entry 0 is the primary (spec 2026-07-10-tier-fallback-list).
    override="$(jq -r --arg p "$provider" --arg t "$tier" '(.models[$p][$t] | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ] && [ "$override" != "null" ]; then
      echo "$override"
      return 0
    fi
    override="$(jq -r --arg t "$tier" '(.models[$t] | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ] && [ "$override" != "null" ]; then
      echo "$override"
      return 0
    fi
  fi
  default_model_for "$provider" "$tier"
}

# fallback_model_at <provider> <tier> <index> → model at the Nth entry of the
# *winning* models.<tier> leaf (the same provider-scoped-then-flat leaf that
# provider_tier_model resolves entry 0 from), for orchestrator re-dispatch onto
# a configured fallback (issue #494). Emits nothing when that leaf has no entry
# at <index> (out of range, or a scalar/object leaf with no fallback beyond 0);
# the caller treats empty output as "chain exhausted". Reads CONFIG_PATH,
# defaulting to $OUTDIR/config.json.
fallback_model_at() {
  local provider="$1" tier="$2" index="$3"
  local config="${CONFIG_PATH:-${OUTDIR:-}/config.json}"
  [ -n "$config" ] && [ -f "$config" ] || return 0
  # Pick the winning leaf by entry 0 (provider-scoped preferred, then flat), then
  # index into *that* leaf so fallback entries never mix across leaves.
  jq -r --arg p "$provider" --arg t "$tier" --argjson i "$index" '
    def prim(v): (v | if type=="array" then .[0]  else .                       end | if type=="object" then .model else . end);
    def at(v):   (v | if type=="array" then .[$i] else (if $i==0 then . else null end) end | if type=="object" then .model else . end);
    (.models[$p][$t]) as $ps
    | (.models[$t]) as $fl
    | (if (prim($ps)) != null then $ps elif (prim($fl)) != null then $fl else null end) as $w
    | if $w == null then empty else (at($w) // empty) end
  ' "$config" 2>/dev/null || true
}

main() {
  local provider="" tier="" index="0"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --provider)
        [ "$#" -ge 2 ] || { echo "::error::--provider requires a value" >&2; exit 1; }
        provider="$2"; shift 2 ;;
      --tier)
        [ "$#" -ge 2 ] || { echo "::error::--tier requires a value" >&2; exit 1; }
        tier="$2"; shift 2 ;;
      --index)
        [ "$#" -ge 2 ] || { echo "::error::--index requires a value" >&2; exit 1; }
        index="$2"; shift 2 ;;
      -h|--help)
        grep -E '^# (Usage|Reads|--index)' "${BASH_SOURCE[0]:-$0}" | sed 's/^# //'
        exit 0 ;;
      *)
        echo "::error::unknown argument: $1" >&2
        exit 1 ;;
    esac
  done

  if [ -z "$provider" ]; then
    echo "::error::--provider is required" >&2
    exit 1
  fi
  case "$tier" in
    fast|standard|deep) ;;
    "")
      echo "::error::--tier is required" >&2
      exit 1 ;;
    *)
      echo "::error::--tier must be one of: fast, standard, deep (got '$tier')" >&2
      exit 1 ;;
  esac

  # --index must be a non-negative integer; 0 is the primary, N≥1 walks the chain.
  case "$index" in
    ''|*[!0-9]*)
      echo "::error::--index must be a non-negative integer (got '$index')" >&2
      exit 1 ;;
  esac

  # Resolve OUTDIR for local runs (same path convention as the rest of the swarm).
  if [ -z "${OUTDIR:-}" ]; then
    # shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
    source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
  fi
  : "${CONFIG_PATH:=${OUTDIR}/config.json}"

  if [ "$index" -eq 0 ]; then
    provider_tier_model "$provider" "$tier"
  else
    local fb
    fb="$(fallback_model_at "$provider" "$tier" "$index")"
    if [ -n "$fb" ]; then
      echo "$fb"
    else
      echo "::notice::no configured fallback at --index $index for $provider/$tier; chain exhausted" >&2
      exit 3
    fi
  fi
}

# Dual-mode: run main only on direct execution; a `source` (e.g. load-prompt.sh)
# pulls in default_model_for / provider_tier_model without executing.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
