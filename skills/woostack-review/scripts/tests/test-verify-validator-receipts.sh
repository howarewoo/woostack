#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
unset GITHUB_ACTIONS GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_REPOSITORY
printf '{}\n' > "$OUTDIR/config.json"

# These are only the prompts' crash guards; they do not prove either validator completed.
printf '[]\n' > "$OUTDIR/findings.prosecutor.json"
printf '[]\n' > "$OUTDIR/findings.defender.json"

write_validator_receipt() {
  local role="$1" attempt="$GITHUB_RUN_ATTEMPT"
  jq -n \
    --arg role "$role" \
    --arg session "github-actions:${GITHUB_RUN_ID}:${attempt}" \
    --arg principal "github-actions:${GITHUB_REPOSITORY}" \
    --arg credential "github-actions-provider-only:${GITHUB_RUN_ID}:${attempt}" \
    --argjson attempt "$attempt" '{
      angle: $role,
      chunk: null,
      runner: "github-actions",
      model: "test-model",
      tier: "deep",
      ts: "2026-08-07T00:00:00Z",
      authority: "advisory-only",
      reviewerProfile: "github-actions-single-session",
      reviewerRunAttempt: $attempt,
      reviewerSessionId: $session,
      reviewerPrincipalId: $principal,
      reviewerCredentialContextId: $credential
    }' > "$OUTDIR/receipt.$role.json"
}

write_local_validator_receipt() {
  local role="$1" session="${2:-local-$1}" credential="${3:-omp-host-owned:${2:-local-$1}}"
  jq -n --arg role "$role" --arg session "$session" --arg credential "$credential" '{
    angle: $role,
    chunk: null,
    runner: "local-test",
    model: "test-model",
    tier: "deep",
    ts: "2026-08-07T00:00:00Z",
    reviewerProfile: "woostack-deep",
    reviewerSessionId: $session,
    reviewerPrincipalId: "omp:woostack-deep",
    reviewerCredentialContextId: $credential,
    authority: "advisory-only"
  }' > "$OUTDIR/receipt.$role.json"
}

file_sha256() {
  local digest=""
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum "$1" | cut -d ' ' -f 1)"
  else
    digest="$(shasum -a 256 "$1" | cut -d ' ' -f 1)"
  fi
  printf 'sha256:%s\n' "$digest"
}

write_local_validator_bindings() {
  local prosecutor_findings_sha prosecutor_receipt_sha defender_findings_sha defender_receipt_sha
  prosecutor_findings_sha="$(file_sha256 "$OUTDIR/findings.prosecutor.json")"
  prosecutor_receipt_sha="$(file_sha256 "$OUTDIR/receipt.prosecutor.json")"
  defender_findings_sha="$(file_sha256 "$OUTDIR/findings.defender.json")"
  defender_receipt_sha="$(file_sha256 "$OUTDIR/receipt.defender.json")"
  jq -n \
    --slurpfile prosecutor "$OUTDIR/receipt.prosecutor.json" \
    --slurpfile defender "$OUTDIR/receipt.defender.json" \
    --arg prosecutor_findings_sha "$prosecutor_findings_sha" \
    --arg prosecutor_receipt_sha "$prosecutor_receipt_sha" \
    --arg defender_findings_sha "$defender_findings_sha" \
    --arg defender_receipt_sha "$defender_receipt_sha" '{
      schemaVersion: 2,
      validators: {
        prosecutor: ($prosecutor[0] | {
          runner,
          model,
          tier,
          reviewerProfile,
          reviewerSessionId,
          reviewerPrincipalId,
          reviewerCredentialContextId
        } + {
          findingsSha256: $prosecutor_findings_sha,
          receiptSha256: $prosecutor_receipt_sha
        }),
        defender: ($defender[0] | {
          runner,
          model,
          tier,
          reviewerProfile,
          reviewerSessionId,
          reviewerPrincipalId,
          reviewerCredentialContextId
        } + {
          findingsSha256: $defender_findings_sha,
          receiptSha256: $defender_receipt_sha
        })
      }
    }' > "$OUTDIR/validator-bindings.json"
}

rc=0; err="$(bash "$SCRIPT" --validators 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local callers cannot select the CI-only validator gate"
assert_contains "$err" "must use --validators-local" "local generic validator bypass is identified"

export GITHUB_ACTIONS=true
export GITHUB_RUN_ID=12345
export GITHUB_RUN_ATTEMPT=1
export GITHUB_REPOSITORY=howarewoo/woostack
write_validator_receipt prosecutor
write_validator_receipt defender
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "valid CI prosecutor and defender role receipts pass"

rm -f "$OUTDIR/receipt.prosecutor.json"
rc=0; err="$(bash "$SCRIPT" --validators 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing prosecutor receipt hard-fails despite both crash-guard arrays"
assert_contains "$err" "prosecutor" "missing validator role is identified"
assert_contains "$err" "refusing intersection" "missing validator receipt blocks intersection"

printf '{"disable_adversarial":true}\n' > "$OUTDIR/config.json"
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "valid defender-only config requires only the defender receipt"

rm -f "$OUTDIR/receipt.defender.json"
rc=0; err="$(bash "$SCRIPT" --validators 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "defender-only config still requires the defender receipt"
assert_contains "$err" "defender" "missing defender role is identified"
assert_contains "$err" "refusing intersection" "missing defender receipt blocks intersection"
unset GITHUB_ACTIONS GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_REPOSITORY

printf '{}\n' > "$OUTDIR/config.json"
write_local_validator_receipt prosecutor
write_local_validator_receipt defender
write_local_validator_bindings
rc=0; bash "$SCRIPT" --validators-local >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "local validator receipts match controller-owned bindings"

write_local_validator_receipt prosecutor shared-session
write_local_validator_receipt defender shared-session
write_local_validator_bindings
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode rejects reused adversarial sessions"
assert_contains "$err" "distinct reviewer sessions and credential contexts" "duplicate validator identity is identified"

write_local_validator_receipt prosecutor
write_local_validator_receipt defender local-defender omp-host-owned:local-prosecutor
write_local_validator_bindings
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode rejects reused credential contexts"
assert_contains "$err" "distinct reviewer sessions and credential contexts" "duplicate validator credential context is identified"
write_local_validator_receipt prosecutor
write_local_validator_receipt defender
write_local_validator_bindings
jq '.schemaVersion = 1' \
  "$OUTDIR/validator-bindings.json" > "$OUTDIR/validator-bindings.tmp"
mv "$OUTDIR/validator-bindings.tmp" "$OUTDIR/validator-bindings.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode rejects stale manifest schemas"
assert_contains "$err" "missing or invalid local validator binding manifest" "stale manifest schema is identified"
write_local_validator_bindings

jq '.validators.prosecutor.findingsSha256 = "sha256:bad"' \
  "$OUTDIR/validator-bindings.json" > "$OUTDIR/validator-bindings.tmp"
mv "$OUTDIR/validator-bindings.tmp" "$OUTDIR/validator-bindings.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode rejects malformed manifest digests"
assert_contains "$err" "prosecutor" "malformed manifest digest identifies the owning role"
write_local_validator_bindings

printf '[{"tampered":true}]\n' > "$OUTDIR/findings.defender.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "local validator findings drift blocks intersection"
assert_contains "$err" "defender" "drifted local validator findings identify the owning role"
assert_contains "$err" "refusing intersection" "local validator findings drift blocks intersection"
printf '[]\n' > "$OUTDIR/findings.defender.json"
write_local_validator_bindings

jq '.ts = "2026-08-07T00:00:01Z"' \
  "$OUTDIR/receipt.defender.json" > "$OUTDIR/receipt.defender.tmp"
mv "$OUTDIR/receipt.defender.tmp" "$OUTDIR/receipt.defender.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "local validator receipt digest drift blocks intersection"
assert_contains "$err" "defender" "drifted local validator receipt identifies the owning role"
assert_contains "$err" "refusing intersection" "local validator receipt drift blocks intersection"
write_local_validator_receipt defender
write_local_validator_bindings

jq '.reviewerPrincipalId = "omp:wrong-profile"' \
  "$OUTDIR/receipt.prosecutor.json" > "$OUTDIR/receipt.prosecutor.tmp"
mv "$OUTDIR/receipt.prosecutor.tmp" "$OUTDIR/receipt.prosecutor.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "local validator identity drift blocks intersection"
assert_contains "$err" "prosecutor" "drifted local validator role is identified"
assert_contains "$err" "refusing intersection" "local validator identity drift blocks intersection"

write_local_validator_receipt prosecutor
rm -f "$OUTDIR/validator-bindings.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode requires a controller-owned binding manifest"
assert_contains "$err" "local validator binding manifest" "missing local binding manifest is identified"

write_local_validator_bindings
jq 'del(.validators.prosecutor)' \
  "$OUTDIR/validator-bindings.json" > "$OUTDIR/validator-bindings.tmp"
mv "$OUTDIR/validator-bindings.tmp" "$OUTDIR/validator-bindings.json"
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "local validator mode rejects a missing required role binding"
assert_contains "$err" "prosecutor" "missing local validator role binding is identified"

write_local_validator_bindings
printf '{"disable_adversarial":true}\n' > "$OUTDIR/config.json"
jq 'del(.validators.prosecutor)' \
  "$OUTDIR/validator-bindings.json" > "$OUTDIR/validator-bindings.tmp"
mv "$OUTDIR/validator-bindings.tmp" "$OUTDIR/validator-bindings.json"
rc=0; bash "$SCRIPT" --validators-local >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "local defender-only mode requires only the bound defender"

export GITHUB_ACTIONS=true
rc=0; err="$(bash "$SCRIPT" --validators-local 2>&1 1>/dev/null)" || rc=$?
assert_exit 2 "$rc" "CI rejects the local validator binding mode"
assert_contains "$err" "only valid for a local coding harness" "local-only validator mode is explicit"
unset GITHUB_ACTIONS

for provider_prompt in anthropic.md google.md openai.md opencode.md; do
  assert_contains \
    "$(cat "$ROOT/skills/woostack-review/prompts/$provider_prompt")" \
    'verify-receipts.sh" --validators' \
    "$provider_prompt gates validator receipts before intersection"
  assert_contains \
    "$(cat "$ROOT/skills/woostack-review/prompts/$provider_prompt")" \
    'verify-receipts.sh" --validators-local' \
    "$provider_prompt binds local validator receipts before intersection"
done

finish
