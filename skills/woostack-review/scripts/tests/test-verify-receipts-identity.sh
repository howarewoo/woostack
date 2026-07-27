#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"

write_manifest() {
  local reviewer_profile="$1"
  local reviewer_session="$2"
  local reviewer_principal="$3"
  local reviewer_credential="$4"
  jq -n \
    --arg reviewer_profile "$reviewer_profile" \
    --arg reviewer_session "$reviewer_session" \
    --arg reviewer_principal "$reviewer_principal" \
    --arg reviewer_credential "$reviewer_credential" \
    '{
      schemaVersion: 1,
      implementingCoder: {
        profile: "omp-engineer-search",
        sessionId: "omp-coding-session-search",
        principalId: "linear-app-engineer-search",
        credentialContextId: "omp-auth-search"
      },
      decisionMaker: {
        profile: "hermes-engineer-search",
        sessionId: "hermes-controller-session-search",
        principalId: "linear-app-decision-maker-search",
        credentialContextId: "hermes-auth-search"
      },
      reviewers: [{
        angle: "bugs",
        chunk: null,
        reviewerProfile: $reviewer_profile,
        reviewerSessionId: $reviewer_session,
        reviewerPrincipalId: $reviewer_principal,
        reviewerCredentialContextId: $reviewer_credential
      }],
      validators: [
        {
          role: "prosecutor",
          reviewerProfile: "reviewer-prosecutor",
          reviewerSessionId: "reviewer-session-prosecutor",
          reviewerPrincipalId: "reviewer-native-prosecutor",
          reviewerCredentialContextId: "reviewer-auth-prosecutor"
        },
        {
          role: "defender",
          reviewerProfile: "reviewer-defender",
          reviewerSessionId: "reviewer-session-defender",
          reviewerPrincipalId: "reviewer-native-defender",
          reviewerCredentialContextId: "reviewer-auth-defender"
        }
      ]
    }' > "$OUTDIR/reviewer-identities.json"
}

write_receipt() {
  local reviewer_profile="$1"
  local reviewer_session="$2"
  local reviewer_principal="$3"
  local reviewer_credential="$4"
  jq -n \
    --arg reviewer_profile "$reviewer_profile" \
    --arg reviewer_session "$reviewer_session" \
    --arg reviewer_principal "$reviewer_principal" \
    --arg reviewer_credential "$reviewer_credential" \
    '{
      angle: "bugs",
      chunk: null,
      runner: "claude-code",
      model: "claude-sonnet-4-6",
      tier: "standard",
      ts: "t",
      reviewerProfile: $reviewer_profile,
      reviewerSessionId: $reviewer_session,
      reviewerPrincipalId: $reviewer_principal,
      reviewerCredentialContextId: $reviewer_credential,
      authority: "advisory-only"
    }' > "$OUTDIR/receipt.bugs.json"
}

write_validator_receipt() {
  local role="$1"
  jq -n --arg role "$role" '{
    validatorRole: $role,
    runner: "claude-code",
    model: "claude-opus-4-8",
    tier: "deep",
    reviewerProfile: ("reviewer-" + $role),
    reviewerSessionId: ("reviewer-session-" + $role),
    reviewerPrincipalId: ("reviewer-native-" + $role),
    reviewerCredentialContextId: ("reviewer-auth-" + $role),
    authority: "advisory-only"
  }' > "$OUTDIR/receipt.validator-$role.json"
}

# Base execution identity and advisory authority remain mandatory without a
# paired-engineer manifest.
printf '{"angle":"bugs","chunk":null,"runner":"claude-code","model":"","tier":"standard","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty model → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

printf '{"angle":"bugs","chunk":null,"runner":"","model":"m","tier":"standard","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty runner → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing authority → invalid receipt"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","ts":"t","authority":"acceptance"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "non-advisory authority → invalid receipt"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","reviewerProfile":"reviewer-quality-search","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "partial reviewer identity → invalid receipt"

# An engineer-unit run fails closed without its controller-owned manifest.
export WOO_REVIEW_ENGINEER_UNIT=true
rm -f "$OUTDIR/reviewer-identities.json"
write_receipt "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "engineer-unit receipt without identity manifest → configuration failure"

# Exact manifest binding passes.
write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "host-bound independent reviewer receipt passes"

jq '.reviewers[0].angle = "security"' \
  "$OUTDIR/reviewer-identities.json" > "$OUTDIR/reviewer-identities.tmp"
mv "$OUTDIR/reviewer-identities.tmp" "$OUTDIR/reviewer-identities.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "reviewer manifest must exactly cover the expected angle/chunk work set"
write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"

# A receipt cannot merely self-report a foreign reviewer.
write_receipt "reviewer-forged-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "receipt identity must match controller manifest"

# The manifest itself rejects the paired coder, the decision-maker session, the
# shared engineer principal, and either role's credential context.
write_manifest "omp-engineer-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "paired coding profile cannot be reviewer"

write_manifest "reviewer-quality-search" "hermes-controller-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "decision-maker session cannot be delegated reviewer session"

write_manifest "reviewer-quality-search" "reviewer-session-search" "linear-app-engineer-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "engineer principal cannot back delegated reviewer"

write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "omp-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "implementation credential context cannot be shared with reviewer"

write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
jq '.decisionMaker.principalId = .implementingCoder.principalId' \
  "$OUTDIR/reviewer-identities.json" > "$OUTDIR/reviewer-identities.tmp"
mv "$OUTDIR/reviewer-identities.tmp" "$OUTDIR/reviewer-identities.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "implementing coder and decision-maker native host principals must differ"

write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
jq '.reviewers += [(.reviewers[0] | .angle = "security")]' \
  "$OUTDIR/reviewer-identities.json" > "$OUTDIR/reviewer-identities.tmp"
mv "$OUTDIR/reviewer-identities.tmp" "$OUTDIR/reviewer-identities.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "delegated reviewers cannot share profile/session/principal/credential identity"

# The decisive validator outputs require their own independent manifest bindings and receipts.
write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
write_validator_receipt prosecutor
write_validator_receipt defender
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "independently bound prosecutor and defender receipts pass"

jq '.validators[1].reviewerPrincipalId = .validators[0].reviewerPrincipalId' \
  "$OUTDIR/reviewer-identities.json" > "$OUTDIR/reviewer-identities.tmp"
mv "$OUTDIR/reviewer-identities.tmp" "$OUTDIR/reviewer-identities.json"
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "validator bindings must be independent from each other"

write_manifest "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rm -f "$OUTDIR/receipt.validator-defender.json"
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing defender receipt blocks validator acceptance"

# CI has no engineer-unit manifest, but its single-session advisory identity is
# explicit and deterministic.
unset WOO_REVIEW_ENGINEER_UNIT
rm -f "$OUTDIR/reviewer-identities.json"
export GITHUB_ACTIONS=true
export GITHUB_RUN_ID=9001
export GITHUB_RUN_ATTEMPT=2
export GITHUB_REPOSITORY=acme/widgets
write_receipt \
  "github-actions-single-session" \
  "github-actions:9001:2" \
  "github-actions:acme/widgets" \
  "github-actions-provider-only:9001:2"
jq '.reviewerRunAttempt = 1
  | .reviewerSessionId = "github-actions:9001:1"
  | .reviewerCredentialContextId = "github-actions-provider-only:9001:1"' \
  "$OUTDIR/receipt.bugs.json" > "$OUTDIR/receipt.bugs.tmp"
mv "$OUTDIR/receipt.bugs.tmp" "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "receipt remains bound to its earlier successful producer attempt"

write_receipt \
  "github-actions-single-session" \
  "github-actions:other-run" \
  "github-actions:acme/widgets" \
  "github-actions-provider-only:9001:2"
jq '.reviewerRunAttempt = 2' "$OUTDIR/receipt.bugs.json" > "$OUTDIR/receipt.bugs.tmp"
mv "$OUTDIR/receipt.bugs.tmp" "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "foreign CI session identity fails"
unset GITHUB_ACTIONS GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_REPOSITORY
finish
