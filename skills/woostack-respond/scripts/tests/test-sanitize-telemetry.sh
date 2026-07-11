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

# Free-text phone, payment card, and AWS access-key material must be redacted inside
# arbitrary nested strings and rejected by --check when unsanitized.
printf '%s\n' '{"note":"Call +1 (415) 555-0199 about card 4111111111111111","meta":{"aws_note":"key AKIAIOSFODNN7EXAMPLE rotated"}}' >"$work/pii-input.json"
python3 "$SCRIPT" --input "$work/pii-input.json" --output "$work/pii-output.json"
for leaked in 555-0199 4111111111111111 AKIAIOSFODNN7EXAMPLE; do
  if grep -Fq "$leaked" "$work/pii-output.json"; then fail "free-text PII survived sanitization: $leaked"; fi
done
for placeholder in REDACTED_PHONE REDACTED_CARD REDACTED_TOKEN; do
  grep -Fq "[$placeholder]" "$work/pii-output.json" || fail "missing placeholder after PII redaction: $placeholder"
done
python3 "$SCRIPT" --check "$work/pii-output.json"
for residual in \
  '{"note":"card 4111111111111111"}' \
  '{"note":"reach me at +1 (415) 555-0199"}' \
  '{"note":"AKIAIOSFODNN7EXAMPLE"}' \
  '{"aws_access_key_id":"AKIAIOSFODNN7EXAMPLE"}'; do
  printf '%s\n' "$residual" >"$work/residual-pii.json"
  expect_fail python3 "$SCRIPT" --check "$work/residual-pii.json"
done

# Private/signing/PEM key-material field names must be classified token-sensitive: their
# values are redacted wholesale, and headerless PKCS#8/base64 material is rejected by --check
# under both snake_case and camelCase keys and in free text. Bare `key`-family words must not
# over-redact.
pkcs8='MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQ'
for keyed in \
  "{\"private_key\":\"$pkcs8\"}" \
  "{\"privateKey\":\"$pkcs8\"}" \
  "{\"signing_key\":\"$pkcs8\"}" \
  "{\"pem\":\"$pkcs8\"}" \
  "{\"provider\":{\"signingKey\":\"$pkcs8\"}}"; do
  printf '%s\n' "$keyed" >"$work/keymat.json"
  python3 "$SCRIPT" --input "$work/keymat.json" --output "$work/keymat-out.json"
  if grep -Fq "$pkcs8" "$work/keymat-out.json"; then fail "private-key material survived sanitization: $keyed"; fi
  grep -Fq "[REDACTED_TOKEN]" "$work/keymat-out.json" || fail "missing token placeholder for key material: $keyed"
  python3 "$SCRIPT" --check "$work/keymat-out.json"
  expect_fail python3 "$SCRIPT" --check "$work/keymat.json"
done
# Free-text headerless PKCS#8 key material is rejected and redacted.
printf '%s\n' "{\"note\":\"leaked $pkcs8 in logs\"}" >"$work/keymat-text.json"
expect_fail python3 "$SCRIPT" --check "$work/keymat-text.json"
python3 "$SCRIPT" --input "$work/keymat-text.json" --output "$work/keymat-text-out.json"
if grep -Fq "$pkcs8" "$work/keymat-text-out.json"; then fail "free-text key material survived sanitization"; fi
# Bare key-family words are not key material and must survive untouched.
printf '%s\n' '{"key":"kbd-1","keyboard":"mechanical","pemdas":"mnemonic","turnkey":"solution"}' >"$work/keybenign.json"
python3 "$SCRIPT" --input "$work/keybenign.json" --output "$work/keybenign-out.json"
for kept in kbd-1 mechanical mnemonic solution; do
  grep -Fq "$kept" "$work/keybenign-out.json" || fail "benign key-family field was redacted: $kept"
done
python3 "$SCRIPT" --check "$work/keybenign-out.json"
# A Luhn-invalid digit run and a bare numeric id are not payment/phone data and must survive.
printf '%s\n' '{"note":"order 1234567890123456 and build 1704106800"}' >"$work/benign-digits.json"
python3 "$SCRIPT" --input "$work/benign-digits.json" --output "$work/benign-output.json"
for kept in 1234567890123456 1704106800; do
  grep -Fq "$kept" "$work/benign-output.json" || fail "benign digit run was redacted: $kept"
done
python3 "$SCRIPT" --check "$work/benign-output.json"

# Personal-name and postal-address fields are PII: values are redacted under common
# normalized variants, raw name/address fields are rejected by --check, and technical
# *name fields (filename, hostname, service_name) must survive unredacted.
printf '%s\n' '{"customer_name":"Jane Doe","full_name":"Bob Roe","shipping_address":"123 Main Street","billing_address":"9 Oak Ave","postal_code":"94107","filename":"report.csv","hostname":"api-7","service_name":"checkout"}' >"$work/pii-fields.json"
python3 "$SCRIPT" --input "$work/pii-fields.json" --output "$work/pii-fields-out.json"
for leaked in 'Jane Doe' 'Bob Roe' '123 Main Street' '9 Oak Ave' 94107; do
  if grep -Fq "$leaked" "$work/pii-fields-out.json"; then fail "personal name/address survived sanitization: $leaked"; fi
done
for placeholder in REDACTED_NAME REDACTED_ADDRESS; do
  grep -Fq "[$placeholder]" "$work/pii-fields-out.json" || fail "missing placeholder after PII field redaction: $placeholder"
done
for kept in report.csv api-7 checkout; do
  grep -Fq "$kept" "$work/pii-fields-out.json" || fail "technical name/address-like field was over-redacted: $kept"
done
python3 "$SCRIPT" --check "$work/pii-fields-out.json"
for residual in \
  '{"customer_name":"Jane Doe"}' \
  '{"shipping_address":"123 Main Street"}' \
  '{"full_name":"Bob Roe"}'; do
  printf '%s\n' "$residual" >"$work/pii-residual.json"
  expect_fail python3 "$SCRIPT" --check "$work/pii-residual.json"
done
# Qualified PII labels in tracked Markdown are rejected; benign technical labels survive.
printf '%s\n' '# Report' 'Shipping Address: 123 Main Street' >"$work/pii-report.md"
expect_fail python3 "$SCRIPT" --check "$work/pii-report.md"
printf '%s\n' '# Report' 'Filename: report.csv' 'Hostname: api-7' >"$work/benign-report.md"
python3 "$SCRIPT" --check "$work/benign-report.md"

# Credentials carried in URL query/fragment parameters are redacted inside arbitrary
# strings and rejected by --check, while non-credential query keys and text survive.
printf '%s\n' '{"url":"https://example.invalid/cb?token=concrete-secret-value-123456789&code=abc123def456&page=2","note":"error_code=500 build 1704106800"}' >"$work/urlcred.json"
python3 "$SCRIPT" --input "$work/urlcred.json" --output "$work/urlcred-out.json"
for leaked in concrete-secret-value-123456789 abc123def456; do
  if grep -Fq "$leaked" "$work/urlcred-out.json"; then fail "URL query credential survived sanitization: $leaked"; fi
done
grep -Fq "[REDACTED_TOKEN]" "$work/urlcred-out.json" || fail "missing placeholder after URL credential redaction"
for kept in 'page=2' 'error_code=500' 1704106800; do
  grep -Fq "$kept" "$work/urlcred-out.json" || fail "non-credential query/text was over-redacted: $kept"
done
python3 "$SCRIPT" --check "$work/urlcred-out.json"
for residual in \
  '{"url":"https://h/x?token=concrete-secret-value-123456789"}' \
  '{"callback":"https://h/cb#access_token=concrete-secret-value-123456789"}' \
  '{"link":"https://h/x?api_key=concrete-secret-value-123456789"}'; do
  printf '%s\n' "$residual" >"$work/urlcred-residual.json"
  expect_fail python3 "$SCRIPT" --check "$work/urlcred-residual.json"
done

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
