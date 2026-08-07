#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"

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

# Generic local execution fields and advisory authority remain mandatory.
printf '{"angle":"bugs","chunk":null,"runner":"claude-code","model":"","tier":"standard","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty model → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

printf '{"angle":"bugs","chunk":null,"runner":"","model":"m","tier":"standard","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty runner → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "empty tier → invalid receipt"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing authority → invalid receipt"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","ts":"t","authority":"acceptance"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "non-advisory authority → invalid receipt"

printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m","tier":"standard","reviewerProfile":"reviewer-quality-search","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "partial reviewer identity → invalid receipt"

# The one generic local path accepts either a minimal receipt or a complete
# self-reported host binding, but never treats either as acceptance authority.
printf '{"angle":"bugs","chunk":null,"runner":"claude-code","model":"claude-sonnet-4-6","tier":"standard","ts":"t","authority":"advisory-only"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "minimal generic local advisory receipt passes"

write_receipt "reviewer-quality-search" "reviewer-session-search" "reviewer-native-search" "reviewer-auth-search"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "complete generic local reviewer binding passes"

rm -f "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing generic local receipt hard-fails"
assert_contains "$err" "no angle analysis executed" "missing receipt reports that review did not run"

# CI uses an explicit deterministic single-session advisory identity.
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
