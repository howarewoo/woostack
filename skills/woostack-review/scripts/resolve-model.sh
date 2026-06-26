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
#                         --tier <fast|standard|deep>
# Reads $OUTDIR/config.json when present (CONFIG_PATH overrides the path).
# Safe to `source` for its functions — main only runs on direct execution.

set -euo pipefail

# canonical source: skills/using-woostack/references/model-tiers.md — keep these slugs in sync
# with that table (Bash cannot read the markdown table, so this is its executable mirror).
default_model_for() {
  local provider="$1" tier="$2"
  case "$provider" in
    anthropic)
      case "$tier" in
        fast) echo "claude-haiku-4-5" ;;
        standard) echo "claude-sonnet-4-6" ;;
        deep) echo "claude-opus-4-8" ;;
      esac
      ;;
    openai)
      case "$tier" in
        fast) echo "gpt-5.3-codex-spark" ;;
        standard) echo "gpt-5.4-mini" ;;
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
    override="$(jq -r --arg p "$provider" --arg t "$tier" '(.models[$p][$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ] && [ "$override" != "null" ]; then
      echo "$override"
      return 0
    fi
    override="$(jq -r --arg t "$tier" '(.models[$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ] && [ "$override" != "null" ]; then
      echo "$override"
      return 0
    fi
  fi
  default_model_for "$provider" "$tier"
}

main() {
  local provider="" tier=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --provider)
        [ "$#" -ge 2 ] || { echo "::error::--provider requires a value" >&2; exit 1; }
        provider="$2"; shift 2 ;;
      --tier)
        [ "$#" -ge 2 ] || { echo "::error::--tier requires a value" >&2; exit 1; }
        tier="$2"; shift 2 ;;
      -h|--help)
        grep -E '^# (Usage|Reads)' "${BASH_SOURCE[0]:-$0}" | sed 's/^# //'
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

  # Resolve OUTDIR for local runs (same path convention as the rest of the swarm).
  if [ -z "${OUTDIR:-}" ]; then
    # shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
    source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
  fi
  : "${CONFIG_PATH:=${OUTDIR}/config.json}"

  provider_tier_model "$provider" "$tier"
}

# Dual-mode: run main only on direct execution; a `source` (e.g. load-prompt.sh)
# pulls in default_model_for / provider_tier_model without executing.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
