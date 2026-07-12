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
# A bare JSON numeric secret under an unclassified key exercises the int/float
# redaction branch: a Luhn-valid card number written as a JSON number is redacted,
# and --check rejects the same unsanitized numeric value.
printf '%s\n' '{"card":4111111111111111}' >"$work/numeric-secret.json"
python3 "$SCRIPT" --input "$work/numeric-secret.json" --output "$work/numeric-secret-out.json"
if grep -Fq 4111111111111111 "$work/numeric-secret-out.json"; then fail "bare numeric card survived sanitization"; fi
grep -Fq "[REDACTED_CARD]" "$work/numeric-secret-out.json" || fail "missing placeholder after numeric card redaction"
python3 "$SCRIPT" --check "$work/numeric-secret-out.json"
expect_fail python3 "$SCRIPT" --check "$work/numeric-secret.json"

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

# Credentials embedded in ordinary string values must be redacted and rejected by --check.
slack_prefix=xox
slack_b="${slack_prefix}b-synthetic-token-value"
slack_p="${slack_prefix}p-synthetic-token-value"
slack_a="${slack_prefix}a-synthetic-token-value"
slack_r="${slack_prefix}r-synthetic-token-value"
printf '{"summary":"cookie=session-secret-123456","detail":"session_id=opaque-session-123456","slack":["%s","%s","%s","%s"]}\n' "$slack_b" "$slack_p" "$slack_a" "$slack_r" >"$work/inline-credentials.json"
python3 "$SCRIPT" --input "$work/inline-credentials.json" --output "$work/inline-credentials-out.json"
for leaked in session-secret-123456 opaque-session-123456 "$slack_b" "$slack_p" "$slack_a" "$slack_r"; do
  if grep -Fq "$leaked" "$work/inline-credentials-out.json"; then fail "inline credential survived sanitization: $leaked"; fi
done
grep -Fq "[REDACTED_TOKEN]" "$work/inline-credentials-out.json" || fail "missing placeholder after inline credential redaction"
python3 "$SCRIPT" --check "$work/inline-credentials-out.json"
expect_fail python3 "$SCRIPT" --check "$work/inline-credentials.json"

# Sensitive dynamic object keys are sanitized as data; residual checks reject raw keys,
# and redaction collisions fail instead of restoring either original key.
printf '{"counts":{"alice@example.invalid":1,"4111111111111111":2,"%s":3}}\n' "$slack_b" >"$work/sensitive-keys.json"
python3 "$SCRIPT" --input "$work/sensitive-keys.json" --output "$work/sensitive-keys-out.json"
for leaked in alice@example.invalid 4111111111111111 "$slack_b"; do
  if grep -Fq "$leaked" "$work/sensitive-keys-out.json"; then fail "sensitive object key survived sanitization: $leaked"; fi
done
for placeholder in REDACTED_EMAIL REDACTED_CARD REDACTED_TOKEN; do
  grep -Fq "[$placeholder]" "$work/sensitive-keys-out.json" || fail "missing placeholder after object-key redaction: $placeholder"
done
python3 "$SCRIPT" --check "$work/sensitive-keys-out.json"
expect_fail python3 "$SCRIPT" --check "$work/sensitive-keys.json"
printf '%s\n' '{"counts":{"alice@example.invalid":1,"bob@example.invalid":2}}' >"$work/colliding-keys.json"
expect_fail python3 "$SCRIPT" --input "$work/colliding-keys.json" --output "$work/colliding-keys-out.json"

# Round-2 coverage: flattened/numbered postal-address variants are PII and redacted.
printf '%s\n' '{"address1":"123 Main Street","address2":"Apt 4","address_line_3":"Building C","recipient_address":"9 Oak Ave","shipping_address_1":"5 Elm Rd"}' >"$work/addr-variants.json"
python3 "$SCRIPT" --input "$work/addr-variants.json" --output "$work/addr-variants-out.json"
for leaked in '123 Main Street' 'Apt 4' 'Building C' '9 Oak Ave' '5 Elm Rd'; do
  if grep -Fq "$leaked" "$work/addr-variants-out.json"; then fail "flattened postal-address variant survived: $leaked"; fi
done
grep -Fq "[REDACTED_ADDRESS]" "$work/addr-variants-out.json" || fail "missing placeholder after address-variant redaction"
python3 "$SCRIPT" --check "$work/addr-variants-out.json"
expect_fail python3 "$SCRIPT" --check "$work/addr-variants.json"
# Qualified address-line fields are postal PII, but unrelated technical address fields remain.
printf '%s\n' '{"shipping_address_line_1":"123 Main Street","recipient_address_line_2":"Apt 4","emergency_contact_address_line1":"9 Oak Ave","memory_address_line_1":"cache 0x10"}' >"$work/qualified-address-lines.json"
python3 "$SCRIPT" --input "$work/qualified-address-lines.json" --output "$work/qualified-address-lines-out.json"
for leaked in '123 Main Street' 'Apt 4' '9 Oak Ave'; do
  if grep -Fq "$leaked" "$work/qualified-address-lines-out.json"; then fail "qualified address-line PII survived: $leaked"; fi
done
grep -Fq '"memory_address_line_1": "cache 0x10"' "$work/qualified-address-lines-out.json" || fail "technical address-line field was over-redacted"
python3 "$SCRIPT" --check "$work/qualified-address-lines-out.json"
expect_fail python3 "$SCRIPT" --check "$work/qualified-address-lines.json"

# Vendor-prefixed signed-URL credentials (AWS X-Amz-*, Google X-Goog-*) are redacted.
printf '%s\n' '{"aws":"https://b.s3.amazonaws.com/o?X-Amz-Signature=abc123def456&X-Amz-Credential=AKIAEXAMPLE/20260101/us-east-1/s3/aws4_request&X-Amz-Security-Token=tok999sig","gcp":"https://storage.googleapis.com/o?X-Goog-Signature=zzz111aaa&X-Goog-Credential=svc%40proj"}' >"$work/signed-url.json"
python3 "$SCRIPT" --input "$work/signed-url.json" --output "$work/signed-url-out.json"
for leaked in abc123def456 'AKIAEXAMPLE/20260101' tok999sig zzz111aaa 'svc%40proj'; do
  if grep -Fq "$leaked" "$work/signed-url-out.json"; then fail "signed-URL credential survived: $leaked"; fi
done
grep -Fq "[REDACTED_TOKEN]" "$work/signed-url-out.json" || fail "missing placeholder after signed-URL redaction"
python3 "$SCRIPT" --check "$work/signed-url-out.json"
expect_fail python3 "$SCRIPT" --check "$work/signed-url.json"
# Parsed signed-URL query maps carry the same vendor signatures as URL strings.
printf '%s\n' '{"query":{"X-Amz-Signature":"parsed-aws-signature","X-Goog-Signature":"parsed-google-signature"}}' >"$work/parsed-signatures.json"
python3 "$SCRIPT" --input "$work/parsed-signatures.json" --output "$work/parsed-signatures-out.json"
for leaked in parsed-aws-signature parsed-google-signature; do
  if grep -Fq "$leaked" "$work/parsed-signatures-out.json"; then fail "parsed vendor signature survived: $leaked"; fi
done
python3 "$SCRIPT" --check "$work/parsed-signatures-out.json"
expect_fail python3 "$SCRIPT" --check "$work/parsed-signatures.json"

# Aggregate metric keys and service/resource display-name keys must not over-redact, while
# a bare personal display_name is still classified as a name.
printf '%s\n' '{"token_count":42,"session_count":7,"authentication_failures":3,"authorization_latency_ms":128,"service_display_name":"checkout","resource_display_name":"api-gw","route_display_name":"/pay","display_name":"Jane Doe"}' >"$work/dims.json"
python3 "$SCRIPT" --input "$work/dims.json" --output "$work/dims-out.json"
for kept in '"token_count": 42' '"session_count": 7' '"authentication_failures": 3' '"authorization_latency_ms": 128' '"service_display_name": "checkout"' '"resource_display_name": "api-gw"' '"route_display_name": "/pay"'; do
  grep -Fq "$kept" "$work/dims-out.json" || fail "telemetry dimension or technical display-name was over-redacted: $kept"
done
if grep -Fq "Jane Doe" "$work/dims-out.json"; then fail "personal display_name survived sanitization"; fi
grep -Fq "[REDACTED_NAME]" "$work/dims-out.json" || fail "bare personal display_name was not redacted"
python3 "$SCRIPT" --check "$work/dims-out.json"

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
