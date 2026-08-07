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
  local role="$1"
  jq -n --arg role "$role" '{
    angle: $role,
    chunk: null,
    runner: "local-test",
    model: "test-model",
    tier: "deep",
    ts: "2026-08-07T00:00:00Z",
    authority: "advisory-only"
  }' > "$OUTDIR/receipt.$role.json"
}

write_validator_receipt prosecutor
write_validator_receipt defender
rc=0; bash "$SCRIPT" --validators >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "valid prosecutor and defender role receipts pass"

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

for provider_prompt in anthropic.md google.md openai.md opencode.md; do
  assert_contains \
    "$(cat "$ROOT/skills/woostack-review/prompts/$provider_prompt")" \
    'verify-receipts.sh" --validators' \
    "$provider_prompt gates validator receipts before intersection"
done

finish
