#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
export WOO_REVIEW_PROVIDER=openai
printf '%s\n' aeo bugs validator > "$OUTDIR/angles.txt"
printf '{"angle":"aeo","chunk":null,"runner":"codex-subagent","model":"gpt-5.5","tier":"fast","ts":"t"}\n' > "$OUTDIR/receipt.aeo.json"
printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"gpt-5.5","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
printf '{"angle":"validator","chunk":null,"runner":"codex-subagent","model":"gpt-5.5","tier":"deep","ts":"t"}\n' > "$OUTDIR/receipt.validator.json"

rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "OpenAI receipts matching tier models pass"

printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"claude-sonnet-4-6","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "OpenAI standard worker with mismatched provider model fails"
assert_contains "$err" "bugs" "names the worker with mismatched model"

printf '{"models":{"openai":{"standard":"gpt-custom-standard"}}}\n' > "$OUTDIR/config.json"
printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"gpt-custom-standard","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "OpenAI provider-scoped config override is honored"

printf '{"models":{"standard":"gpt-flat-standard"}}\n' > "$OUTDIR/config.json"
printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"gpt-flat-standard","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "OpenAI flat config override is honored"

printf '{"models":{"openai":{"standard":{"model":"gpt-obj-standard","effort":"low"}}}}\n' > "$OUTDIR/config.json"
printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"gpt-obj-standard","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "OpenAI object-leaf {model,effort} config override resolves to .model"

unset WOO_REVIEW_PROVIDER
export WOO_REVIEW_HOST=codex
rm -f "$OUTDIR/config.json"
printf '{"angle":"bugs","chunk":null,"runner":"local-worker","model":"claude-sonnet-4-6","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "Codex host triggers model validation without provider or codex runner"
assert_contains "$err" "bugs" "names the host-triggered worker with mismatched model"

printf '{"angle":"bugs","chunk":null,"runner":"local-worker","model":"gpt-5.5","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "Codex host accepts matching model without provider or codex runner"

finish
