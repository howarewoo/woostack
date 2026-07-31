#!/usr/bin/env bash
# Postflight gate: assert every expected angle (from angles.txt × chunks.txt) wrote
# a VALID execution receipt. A valid receipt binds the expected work item to its
# runner/model/tier, advisory-only authority, and (for an engineer-unit run) the
# controller-owned reviewer identity manifest. For repository-routed Codex/OpenAI
# workers, the model must also match the tier mapping. This is the single authority
# on "did the independently bound angle worker actually execute": empty findings
# are an honest clean review ONLY when the receipt proves the worker ran.
#
# Modes:
#   (default)       gate: emit ::error and exit 1 if any expected angle receipt is invalid.
#   --list-missing  print invalid "<angle>" or "<angle>.<chunk>" labels, exit 0.
#   --validators    gate the engineer-unit prosecutor and defender identity receipts.
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

identity_manifest="${WOO_REVIEW_IDENTITY_MANIFEST:-$OUTDIR/reviewer-identities.json}"
identity_manifest_required=false
case "${WOO_REVIEW_ENGINEER_UNIT:-}" in
  1|true|yes) identity_manifest_required=true ;;
  0|false|no|"") ;;
  *)
    echo "::error::WOO_REVIEW_ENGINEER_UNIT must be true/false (or 1/0)" >&2
    exit 2
    ;;
esac

if [ "$identity_manifest_required" = true ] && [ ! -s "$identity_manifest" ]; then
  echo "::error::engineer-unit review requires a non-empty controller-owned reviewer identity manifest: $identity_manifest" >&2
  exit 2
fi

if [ -e "$identity_manifest" ]; then
  if [ ! -s "$identity_manifest" ] || ! jq -e '
    def nonempty: type == "string" and length > 0;
    . as $m
    | (type == "object")
    and (.schemaVersion == 1)
    and ($m.implementingCoder | type == "object"
      and (.profile | nonempty)
      and (.sessionId | nonempty)
      and (.principalId | nonempty)
      and (.credentialContextId | nonempty))
    and ($m.decisionMaker | type == "object"
      and (.profile | nonempty)
      and (.sessionId | nonempty)
      and (.principalId | nonempty)
      and (.credentialContextId | nonempty))
    and ($m.implementingCoder.profile != $m.decisionMaker.profile)
    and ($m.implementingCoder.sessionId != $m.decisionMaker.sessionId)
    and ($m.implementingCoder.principalId != $m.decisionMaker.principalId)
    and ($m.implementingCoder.credentialContextId != $m.decisionMaker.credentialContextId)
    and ($m.reviewers | type == "array" and length > 0)
    and (all($m.reviewers[];
      (type == "object")
      and (.angle | nonempty)
      and ((.chunk == null) or (.chunk | type == "string"))
      and (.reviewerProfile | nonempty)
      and (.reviewerSessionId | nonempty)
      and (.reviewerPrincipalId | nonempty)
      and (.reviewerCredentialContextId | nonempty)
      and (.reviewerProfile != $m.implementingCoder.profile)
      and (.reviewerProfile != $m.decisionMaker.profile)
      and (.reviewerSessionId != $m.implementingCoder.sessionId)
      and (.reviewerSessionId != $m.decisionMaker.sessionId)
      and (.reviewerPrincipalId != $m.implementingCoder.principalId)
      and (.reviewerPrincipalId != $m.decisionMaker.principalId)
      and (.reviewerCredentialContextId != $m.implementingCoder.credentialContextId)
      and (.reviewerCredentialContextId != $m.decisionMaker.credentialContextId)
    ))
    and (($m.reviewers | map([.angle, (.chunk // "")] | join("\u0000")) | unique | length)
      == ($m.reviewers | length))
    and (($m.reviewers | map(.reviewerProfile) | unique | length) == ($m.reviewers | length))
    and (($m.reviewers | map(.reviewerSessionId) | unique | length) == ($m.reviewers | length))
    and (($m.reviewers | map(.reviewerPrincipalId) | unique | length) == ($m.reviewers | length))
    and (($m.reviewers | map(.reviewerCredentialContextId) | unique | length)
      == ($m.reviewers | length))
  ' "$identity_manifest" >/dev/null 2>&1; then
    echo "::error::invalid reviewer identity manifest: $identity_manifest" >&2
    exit 2
  fi
fi

receipt_matches_identity_manifest() { # angle chunk receipt
  local angle="$1" chunk="$2" receipt="$3"
  jq -e --arg a "$angle" --arg c "$chunk" --slurpfile receipt "$receipt" '
    . as $m
    | [
        $m.reviewers[]
        | select(
            .angle == $a
            and (
              (($c == "") and ((.chunk == null) or (.chunk == "")))
              or (.chunk == $c)
            )
          )
      ] as $bindings
    | ($bindings | length) == 1
      and ($receipt | length) == 1
      and ($receipt[0].reviewerProfile == $bindings[0].reviewerProfile)
      and ($receipt[0].reviewerSessionId == $bindings[0].reviewerSessionId)
      and ($receipt[0].reviewerPrincipalId == $bindings[0].reviewerPrincipalId)
      and ($receipt[0].reviewerCredentialContextId == $bindings[0].reviewerCredentialContextId)
  ' "$identity_manifest" >/dev/null 2>&1
}

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

if [ "$mode" = "validators" ]; then
  [ "$identity_manifest_required" = true ] || {
    echo "::error::validator identity receipts are required only for an engineer-unit review" >&2
    exit 2
  }
  if ! jq -e '
    def nonempty: type == "string" and length > 0;
    . as $m
    | ($m.validators | type == "array" and length == 2)
    and (($m.validators | map(.role) | sort) == ["defender", "prosecutor"])
    and (all($m.validators[];
      (type == "object")
      and (.reviewerProfile | nonempty)
      and (.reviewerSessionId | nonempty)
      and (.reviewerPrincipalId | nonempty)
      and (.reviewerCredentialContextId | nonempty)
    ))
    and (
      (
        [
          $m.implementingCoder | {
            reviewerProfile: .profile,
            reviewerSessionId: .sessionId,
            reviewerPrincipalId: .principalId,
            reviewerCredentialContextId: .credentialContextId
          },
          $m.decisionMaker | {
            reviewerProfile: .profile,
            reviewerSessionId: .sessionId,
            reviewerPrincipalId: .principalId,
            reviewerCredentialContextId: .credentialContextId
          }
        ] + $m.reviewers + $m.validators
      ) as $all
      | (($all | map(.reviewerProfile) | unique | length) == ($all | length))
      and (($all | map(.reviewerSessionId) | unique | length) == ($all | length))
      and (($all | map(.reviewerPrincipalId) | unique | length) == ($all | length))
      and (($all | map(.reviewerCredentialContextId) | unique | length) == ($all | length))
    )
  ' "$identity_manifest" >/dev/null 2>&1; then
    echo "::error::invalid or non-independent validator identity bindings" >&2
    exit 2
  fi

  validator_failed=false
  for validator_role in prosecutor defender; do
    validator_receipt="$OUTDIR/receipt.validator-${validator_role}.json"
    if [ ! -s "$validator_receipt" ] || ! jq -e \
      --arg role "$validator_role" \
      --slurpfile receipt "$validator_receipt" '
        . as $m
        | [.validators[] | select(.role == $role)] as $bindings
        | ($bindings | length) == 1
        and ($receipt | length) == 1
        and ($receipt[0] | type == "object")
        and ($receipt[0].validatorRole == $role)
        and (($receipt[0].runner // "") | type == "string" and length > 0)
        and (($receipt[0].model // "") | type == "string" and length > 0)
        and ($receipt[0].tier == "deep")
        and ($receipt[0].authority == "advisory-only")
        and ($receipt[0].reviewerProfile == $bindings[0].reviewerProfile)
        and ($receipt[0].reviewerSessionId == $bindings[0].reviewerSessionId)
        and ($receipt[0].reviewerPrincipalId == $bindings[0].reviewerPrincipalId)
        and ($receipt[0].reviewerCredentialContextId == $bindings[0].reviewerCredentialContextId)
      ' "$identity_manifest" >/dev/null 2>&1; then
      echo "::error::invalid or missing validator identity receipt: validator-${validator_role}" >&2
      validator_failed=true
    fi
  done
  [ "$validator_failed" = false ] || exit 1
  exit 0
fi

angles_file="$OUTDIR/angles.txt"
if [ ! -s "$angles_file" ]; then
  echo "::error::missing or empty angles file: $angles_file" >&2
  exit 2
fi

angles=()
while IFS= read -r a; do [ -n "$a" ] && angles+=("$a"); done < "$angles_file"
if [ "${#angles[@]}" -eq 0 ]; then
  echo "::error::no angles found in $angles_file" >&2
  exit 2
fi

chunks=("")
chunks_file="$OUTDIR/chunks.txt"
if [ -s "$chunks_file" ]; then
  chunks=()
  while IFS= read -r c; do [ -n "$c" ] && chunks+=("$c"); done < "$chunks_file"
  [ "${#chunks[@]}" -eq 0 ] && chunks=("")
fi

if [ -s "$identity_manifest" ]; then
  manifest_expected_total=$(( ${#angles[@]} * ${#chunks[@]} ))
  manifest_binding_total="$(jq -r '.reviewers | length' "$identity_manifest")"
  [ "$manifest_binding_total" -eq "$manifest_expected_total" ] || {
    echo "::error::reviewer identity manifest does not exactly cover the expected angle/chunk work set" >&2
    exit 2
  }
  for manifest_angle in "${angles[@]}"; do
    for manifest_chunk in "${chunks[@]}"; do
      manifest_binding_count="$(
        jq -r --arg a "$manifest_angle" --arg c "$manifest_chunk" '
          [.reviewers[] | select(
            .angle == $a
            and (
              (($c == "") and ((.chunk == null) or (.chunk == "")))
              or (.chunk == $c)
            )
          )] | length
        ' "$identity_manifest"
      )"
      [ "$manifest_binding_count" -eq 1 ] || {
        echo "::error::reviewer identity manifest lacks one exact binding for ${manifest_angle}${manifest_chunk:+.$manifest_chunk}" >&2
        exit 2
      }
    done
  done
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
# supplied reviewer identity is complete. An engineer-unit manifest additionally
# binds that identity to the host-selected reviewer and excludes the implementing
# coder and decision-maker identities/credential contexts. GitHub Actions uses
# its explicit single-session CI identity shape when no manifest is present.
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

  if [ -s "$identity_manifest" ]; then
    receipt_matches_identity_manifest "$angle" "$chunk" "$f" || return 1
  elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
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
