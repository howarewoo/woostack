#!/usr/bin/env bash
# Detects which provider to use based on inputs.
# Precedence: explicit INPUT_PROVIDER → first non-empty credential (anthropic → openai → google → openrouter).
# Writes `provider=...` to $GITHUB_OUTPUT, or exits 1 if none resolvable.

set -euo pipefail

PROVIDER="${INPUT_PROVIDER:-}"

if [ -z "$PROVIDER" ]; then
  if [ -n "${INPUT_ANTHROPIC_TOKEN:-}" ] || [ -n "${INPUT_ANTHROPIC_API_KEY:-}" ]; then
    PROVIDER="anthropic"
  elif [ -n "${INPUT_OPENAI_API_KEY:-}" ] || [ -n "${INPUT_OPENAI_ACCESS_TOKEN:-}" ]; then
    PROVIDER="openai"
  elif [ -n "${INPUT_GOOGLE_API_KEY:-}" ] || [ -n "${INPUT_GEMINI_API_KEY:-}" ]; then
    PROVIDER="google"
  elif [ -n "${INPUT_OPENROUTER_API_KEY:-}" ]; then
    PROVIDER="openrouter"
  fi
fi

case "$PROVIDER" in
  anthropic|openai|google|openrouter) ;;
  "")
    echo "::error::woostack-review preflight: no model provider/runner resolvable, so no angle worker can execute. Configure a provider/model (set the 'provider' input), install auth (one of: anthropic_token, openai_api_key, openai_access_token, google_api_key, openrouter_api_key), or set the correct runner override. Refusing to run a review that cannot analyze the diff."
    exit 1
    ;;
  *)
    echo "::error::Unknown provider '$PROVIDER'. Must be one of: anthropic, openai, google, openrouter."
    exit 1
    ;;
esac

case "$PROVIDER" in
  anthropic)
    if [ -z "${INPUT_ANTHROPIC_TOKEN:-}" ] && [ -z "${INPUT_ANTHROPIC_API_KEY:-}" ]; then
      echo "::error::woostack-review preflight: provider 'anthropic' selected but no anthropic_token or anthropic_api_key was provided."
      exit 1
    fi
    ;;
  openai)
    if [ -z "${INPUT_OPENAI_API_KEY:-}" ] && [ -z "${INPUT_OPENAI_ACCESS_TOKEN:-}" ]; then
      echo "::error::woostack-review preflight: provider 'openai' selected but no openai_api_key or openai_access_token was provided."
      exit 1
    fi
    ;;
  google)
    if [ -z "${INPUT_GOOGLE_API_KEY:-}" ] && [ -z "${INPUT_GEMINI_API_KEY:-}" ]; then
      echo "::error::woostack-review preflight: provider 'google' selected but no google_api_key or gemini_api_key was provided."
      exit 1
    fi
    ;;
  openrouter)
    if [ -z "${INPUT_OPENROUTER_API_KEY:-}" ]; then
      echo "::error::woostack-review preflight: provider 'openrouter' selected but no openrouter_api_key was provided."
      exit 1
    fi
    ;;
esac

echo "provider=$PROVIDER" >> "$GITHUB_OUTPUT"
echo "Resolved provider: $PROVIDER"
