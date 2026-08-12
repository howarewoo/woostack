#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '{}\n' > "$OUTDIR/config.json"
printf '[]\n' > "$OUTDIR/findings.adjudicator.json"
receipt() { jq -n '{angle:"adjudicator",chunk:null,runner:"local-test",model:"test-model",tier:"standard",ts:"2026-08-12T00:00:00Z",authority:"advisory-only"}'; }
receipt > "$OUTDIR/receipt.adjudicator.json"
rc=0; bash "$SCRIPT" --validators-local >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "local gate requires binding manifest"
sha() { printf 'sha256:%s' "$(shasum -a 256 "$1" | cut -d' ' -f1)"; }
fs="$(sha "$OUTDIR/findings.adjudicator.json")"; rs="$(sha "$OUTDIR/receipt.adjudicator.json")"
jq -n --arg fs "$fs" --arg rs "$rs" '{schemaVersion:2,adjudicator:{runner:"local-test",model:"test-model",tier:"standard",reviewerProfile:"profile",reviewerSessionId:"session",reviewerPrincipalId:"principal",reviewerCredentialContextId:"credential",findingsSha256:$fs,receiptSha256:$rs}}' > "$OUTDIR/validator-bindings.json"
jq '.reviewerProfile="profile"|.reviewerSessionId="session"|.reviewerPrincipalId="principal"|.reviewerCredentialContextId="credential"' "$OUTDIR/receipt.adjudicator.json" > "$OUTDIR/receipt.tmp" && mv "$OUTDIR/receipt.tmp" "$OUTDIR/receipt.adjudicator.json"
fs="$(sha "$OUTDIR/findings.adjudicator.json")"; rs="$(sha "$OUTDIR/receipt.adjudicator.json")"
jq --arg fs "$fs" --arg rs "$rs" '.adjudicator.findingsSha256=$fs|.adjudicator.receiptSha256=$rs' "$OUTDIR/validator-bindings.json" > "$OUTDIR/b.tmp" && mv "$OUTDIR/b.tmp" "$OUTDIR/validator-bindings.json"
rc=0; bash "$SCRIPT" --validators-local >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "one bound adjudicator receipt passes"
rm "$OUTDIR/receipt.adjudicator.json"; rc=0; bash "$SCRIPT" --validators-local >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing adjudicator receipt blocks"
finish
