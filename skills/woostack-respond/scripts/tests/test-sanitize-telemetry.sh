#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/../sanitize-telemetry.py"
FIXTURES="$DIR/fixtures"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() {
  if "$@" >"$work/stderr" 2>&1; then
    fail "expected failure: $*"
  fi
}

actual="$work/sanitized.json"
python3 "$SCRIPT" --input "$FIXTURES/sensitive-input.json" --output "$actual"
cmp -s "$FIXTURES/sanitized-expected.json" "$actual" || {
  diff -u "$FIXTURES/sanitized-expected.json" "$actual" >&2 || true
  fail "sanitized JSON differs byte-for-byte"
}
python3 "$SCRIPT" --input "$FIXTURES/sensitive-input.json" --output "$work/again.json"
cmp -s "$actual" "$work/again.json" || fail "repeated output is not deterministic"

for preserved in API-142 4bf92f3577b34da6a3ce929d0e0e4736 0123456789abcdef0123456789abcdef01234567 checkout@2026.07.10 PaymentTimeoutError payments.py:87 checkout-api; do
  grep -Fq "$preserved" "$actual" || fail "technical identifier was not preserved: $preserved"
done
for placeholder in REDACTED_TOKEN REDACTED_EMAIL REDACTED_IP REDACTED_USER REDACTED_BODY REDACTED_HOME; do
  grep -Fq "[$placeholder]" "$actual" || fail "missing stable placeholder: $placeholder"
done
for secret in synthetic-password alice@example.invalid 192.0.2.44 2001:db8:85a3::8a2e:370:7334 usr_123456 4111111111111111 /Users/alice /home/bob 'C:\Users\Carol'; do
  if grep -Fq "$secret" "$actual"; then fail "sensitive value remains: $secret"; fi
done

# A secret-shaped value under an unclassified key survives traversal but must be caught by
# residual validation. The pre-existing destination is an atomic-write sentinel.
printf '%s\n' '{"diagnostic":"-----BEGIN PRIVATE KEY-----"}' >"$work/residual.json"
printf '%s\n' 'DO NOT REPLACE' >"$work/existing.json"
expect_fail python3 "$SCRIPT" --input "$work/residual.json" --output "$work/existing.json"
[ "$(cat "$work/existing.json")" = "DO NOT REPLACE" ] || fail "failed validation replaced output"

printf '%s\n' '{"customCredential":"ordinary-looking-value"}' >"$work/forbidden-key.json"
expect_fail python3 "$SCRIPT" --check "$work/forbidden-key.json"
printf '%s\n' '{"message":"token ghp_abcdefghijklmnopqrstuvwxyz0123456789"}' >"$work/forbidden-value.json"
expect_fail python3 "$SCRIPT" --check "$work/forbidden-value.json"

cat >"$work/report.md" <<'EOF'
---
type: response
outcome: partial
---
# Production response: API-142

Trace `4bf92f3577b34da6a3ce929d0e0e4736` in checkout-api failed at
`[REDACTED_HOME]/work/checkout/src/payments.py:87` for `[REDACTED_USER]`.
EOF
python3 "$SCRIPT" --check "$work/report.md"

cat >"$work/dirty-report.md" <<'EOF'
# Production response
Authorization: Bearer sk_live_SYNTHETIC0123456789
EOF
expect_fail python3 "$SCRIPT" --check "$work/dirty-report.md"

cat >"$work/fix-handoff.json" <<'EOF'
{"error_class":"PaymentTimeoutError","issue":"API-142","source":"[REDACTED_HOME]/work/checkout/src/payments.py:87","user":"[REDACTED_USER]"}
EOF
python3 "$SCRIPT" --check "$work/fix-handoff.json"
printf '%s\n' '{"issue":"API-142","requestBody":{"password":"still-secret"}}' >"$work/dirty-handoff.json"
expect_fail python3 "$SCRIPT" --check "$work/dirty-handoff.json"

printf 'PASS: telemetry sanitizer\n'
