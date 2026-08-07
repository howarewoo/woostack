#!/usr/bin/env bash
# Postflight gate: assert every expected angle (from angles.txt × chunks.txt) wrote
# a VALID execution receipt. A valid receipt binds the expected work item to its
# runner/model/tier and advisory-only authority. For repository-routed Codex/OpenAI
# workers, the model must also match the tier mapping. This is the single authority
# on "did the angle worker actually execute": empty findings are an honest clean
# review ONLY when the receipt proves the worker ran.
#
# Modes:
#   (default)       gate: emit ::error and exit 1 if any expected angle receipt is invalid.
#   --list-missing  print invalid "<angle>" or "<angle>.<chunk>" labels, exit 0.
#   --validators    gate the required prosecutor/defender role receipts before intersection.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"

mode="gate"
case "${1:-}" in
  --list-missing) mode="list" ;;
  --validators) mode="validators" ;;
  "") ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "::error::unknown argument: $1" >&2; exit 2 ;;
esac

receipt_matches_ci_identity() { # receipt
  local receipt="$1" attempt session principal credential
  [ -n "${GITHUB_RUN_ID:-}" ] &&
    [ -n "${GITHUB_RUN_ATTEMPT:-}" ] &&
    [ -n "${GITHUB_REPOSITORY:-}" ] || return 1
  case "$GITHUB_RUN_ATTEMPT" in
    *[!0-9]*|"") return 1 ;;
  esac
  attempt="$(
    jq -r '
      if (.reviewerRunAttempt | type) == "number"
        and .reviewerRunAttempt >= 1
        and .reviewerRunAttempt == (.reviewerRunAttempt | floor)
      then (.reviewerRunAttempt | tostring)
      else empty
      end
    ' "$receipt" 2>/dev/null
  )"
  [ -n "$attempt" ] && [ "$attempt" -le "$GITHUB_RUN_ATTEMPT" ] || return 1
  session="github-actions:${GITHUB_RUN_ID}:${attempt}"
  principal="github-actions:${GITHUB_REPOSITORY}"
  credential="github-actions-provider-only:${GITHUB_RUN_ID}:${attempt}"
  jq -e \
    --arg session "$session" \
    --arg principal "$principal" \
    --arg credential "$credential" \
    --argjson attempt "$attempt" '
      .reviewerProfile == "github-actions-single-session"
      and .reviewerRunAttempt == $attempt
      and .reviewerSessionId == $session
      and .reviewerPrincipalId == $principal
      and .reviewerCredentialContextId == $credential
    ' "$receipt" >/dev/null 2>&1
}

angles=()
chunks=("")
if [ "$mode" = "validators" ]; then
  if [ -s "$OUTDIR/config.json" ] &&
    jq -e 'type == "object" and .disable_adversarial == true' "$OUTDIR/config.json" >/dev/null 2>&1; then
    angles=("defender")
  else
    angles=("prosecutor" "defender")
  fi
else
  angles_file="$OUTDIR/angles.txt"
  if [ ! -s "$angles_file" ]; then
    echo "::error::missing or empty angles file: $angles_file" >&2
    exit 2
  fi

  while IFS= read -r a; do [ -n "$a" ] && angles+=("$a"); done < "$angles_file"
  if [ "${#angles[@]}" -eq 0 ]; then
    echo "::error::no angles found in $angles_file" >&2
    exit 2
  fi

  chunks_file="$OUTDIR/chunks.txt"
  if [ -s "$chunks_file" ]; then
    chunks=()
    while IFS= read -r c; do [ -n "$c" ] && chunks+=("$c"); done < "$chunks_file"
    [ "${#chunks[@]}" -eq 0 ] && chunks=("")
  fi
fi

receipt_path() { # angle chunk
  if [ -n "$2" ]; then printf '%s/receipt.%s.%s.json' "$OUTDIR" "$1" "$2"
  else printf '%s/receipt.%s.json' "$OUTDIR" "$1"; fi
}
label() { # angle chunk
  if [ -n "$2" ]; then printf '%s.%s' "$1" "$2"; else printf '%s' "$1"; fi
}

default_openai_model_for_tier() {
  case "$1" in
    fast) echo "gpt-5.5" ;;
    standard) echo "gpt-5.5" ;;
    deep) echo "gpt-5.5" ;;
    *) return 1 ;;
  esac
}

config_model_for_tier() {
  local provider="$1" tier="$2" config="$OUTDIR/config.json" override=""
  if [ -s "$config" ]; then
    override="$(jq -r --arg p "$provider" --arg t "$tier" '(.models[$p][$t] | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ]; then
      echo "$override"
      return 0
    fi
    override="$(jq -r --arg t "$tier" '(.models[$t] | if type=="array" then .[0] else . end | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
    if [ -n "$override" ]; then
      echo "$override"
      return 0
    fi
  fi
  return 1
}

expected_openai_model_for_tier() {
  local tier="$1"
  if [ -z "${FORCE_TIER:-}" ] && [ -n "${INPUT_MODEL:-}" ]; then
    echo "$INPUT_MODEL"
    return 0
  fi
  config_model_for_tier "openai" "$tier" || default_openai_model_for_tier "$tier"
}

receipt_needs_openai_model_check() { # file
  local f="$1" runner host provider
  runner="$(jq -r '.runner // ""' "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  host="$(printf '%s' "${WOO_REVIEW_HOST:-}" | tr '[:upper:]' '[:lower:]')"
  provider="$(printf '%s' "${WOO_REVIEW_PROVIDER:-}" | tr '[:upper:]' '[:lower:]')"
  [ "$host" = "omp" ] && return 1
  [ "$provider" = "openai" ] || [ "$host" = "codex" ] || [[ "$runner" == *codex* ]]
}

# Valid iff: JSON object; .angle == angle; (.chunk matches, or both empty/null);
# .runner, .model, and .tier are non-empty; .authority is advisory-only; any
# supplied reviewer identity is complete. GitHub Actions additionally requires
# its explicit single-session CI identity shape.
is_valid_receipt() { # angle chunk file
  local angle="$1" chunk="$2" f="$3" tier model expected
  [ -s "$f" ] || return 1
  jq -e --arg a "$angle" --arg c "$chunk" '
    . as $receipt
    | (type == "object")
    and (.angle == $a)
    and ( (($c == "") and ((.chunk == null) or (.chunk == ""))) or (.chunk == $c) )
    and (((.runner // "") | tostring | length) > 0)
    and (((.model  // "") | tostring | length) > 0)
    and (((.tier   // "") | tostring | length) > 0)
    and (.authority == "advisory-only")
    and (
      if (
        ($receipt | has("reviewerProfile"))
        or ($receipt | has("reviewerSessionId"))
        or ($receipt | has("reviewerPrincipalId"))
        or ($receipt | has("reviewerCredentialContextId"))
      ) then
        (($receipt.reviewerProfile // "") | type == "string" and length > 0)
        and (($receipt.reviewerSessionId // "") | type == "string" and length > 0)
        and (($receipt.reviewerPrincipalId // "") | type == "string" and length > 0)
        and (($receipt.reviewerCredentialContextId // "") | type == "string" and length > 0)
      else
        true
      end
    )
  ' "$f" >/dev/null 2>&1 || return 1

  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    receipt_matches_ci_identity "$f" || return 1
  fi

  if receipt_needs_openai_model_check "$f"; then
    tier="$(jq -r '.tier' "$f")"
    model="$(jq -r '.model' "$f")"
    expected="$(expected_openai_model_for_tier "$tier" 2>/dev/null || true)"
    [ -n "$expected" ] && [ "$model" = "$expected" ] || return 1
  fi
}

missing=()
executed=()
for angle in "${angles[@]}"; do
  for chunk in "${chunks[@]}"; do
    f="$(receipt_path "$angle" "$chunk")"
    if is_valid_receipt "$angle" "$chunk" "$f"; then
      executed+=("$(label "$angle" "$chunk")")
    else
      missing+=("$(label "$angle" "$chunk")")
    fi
  done
done
if [ "$mode" = "validators" ]; then
  if [ "${#missing[@]}" -gt 0 ]; then
    miss_csv="$(IFS=', '; echo "${missing[*]}")"
    echo "::error::woostack-review: validator role receipt(s) missing or invalid: ${miss_csv}. The adversarial validation pass is NOT complete; refusing intersection." >&2
    exit 1
  fi
  echo "verify-receipts: all ${#angles[@]} required validator role receipt(s) valid."
  exit 0
fi

if [ "$mode" = "list" ]; then
  for m in ${missing[@]+"${missing[@]}"}; do printf '%s\n' "$m"; done
  exit 0
fi

# Gate mode: record executed/expected/missing into swarm-metrics.json (best-effort).
expected_total=$(( ${#angles[@]} * ${#chunks[@]} ))
metrics="$OUTDIR/swarm-metrics.json"
to_json_array() { # items...
  if [ "$#" -eq 0 ]; then printf '[]'; return; fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}
exec_json="$(to_json_array ${executed[@]+"${executed[@]}"})"
miss_json="$(to_json_array ${missing[@]+"${missing[@]}"})"
if [ -s "$metrics" ] && jq -e . "$metrics" >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --argjson ex "$exec_json" --argjson mi "$miss_json" --argjson et "$expected_total" \
    '.executed_angles=$ex | .expected_total=$et | .missing_receipts=$mi' "$metrics" > "$tmp" && mv "$tmp" "$metrics"
else
  jq -n --argjson ex "$exec_json" --argjson mi "$miss_json" --argjson et "$expected_total" \
    '{schema_version:1, executed_angles:$ex, expected_total:$et, missing_receipts:$mi}' > "$metrics"
fi

if [ "${#missing[@]}" -gt 0 ]; then
  miss_csv="$(IFS=', '; echo "${missing[*]}")"
  if [ "${#executed[@]}" -eq 0 ]; then
    echo "::error::woostack-review: no angle analysis executed (0 of ${expected_total} angle workers produced a valid receipt): ${miss_csv}. The review did NOT run. Configure a provider/model, install auth, or set the correct runner override, then re-run." >&2
  else
    echo "::error::woostack-review: ${#missing[@]} of ${expected_total} angle worker(s) did not execute (no valid receipt): ${miss_csv}. No angle analysis ran for these, so the review is NOT complete. Configure a provider/model, install auth, or set the correct runner override, then re-run." >&2
  fi
  exit 1
fi

echo "verify-receipts: all ${expected_total} angle receipt(s) valid."
