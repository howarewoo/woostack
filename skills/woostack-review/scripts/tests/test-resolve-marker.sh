#!/usr/bin/env bash
# Test the marker-trust resolver that prefetch.sh uses to pull the incremental
# SHA watermark from prior review bodies (issue #273).
#
# resolve-marker.sh <bot-pattern> <me> <local> reads `gh --json reviews` JSON on
# stdin and prints the trusted SHA (or empty). A marker is trusted iff the review
# author is a woostack-review bot, OR — on a local run only (local==1) — the
# authenticated gh user running the review (login==me, case-insensitive). The
# self-trust clause is gated on a local run so a CI collaborator cannot forge a
# marker under a non-bot login.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/resolve-marker.sh"

BOTS="claude|openai|gemini|opencode"

# resolve <reviews-json> <bots> <me> <local> -> trusted SHA on stdout
resolve() {
  printf '%s' "$1" | bash "$SCRIPT" "$2" "$3" "$4"
}

# One review object with the current-brand marker.
review() { # login sha submittedAt
  printf '{"author":{"login":"%s"},"body":"LGTM\\n\\n<!-- woostack-review:sha=%s -->","submittedAt":"%s"}' "$1" "$2" "$3"
}

# --- (1) bot-authored marker, CI run (local=0) -> trusted (preserves CI behavior) ---
json="{\"reviews\":[$(review "claude[bot]" "223ad82" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "" "0")"
assert_eq "$got" "223ad82" "(1) bot-authored marker in CI is trusted"

# --- (2) self-authored marker, local run, me==author -> trusted (the fix) ---
json="{\"reviews\":[$(review "howarewoo" "deadbee" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "howarewoo" "1")"
assert_eq "$got" "deadbee" "(2) local self-authored marker is trusted"

# --- (2b) self-trust is case-insensitive on the login ---
json="{\"reviews\":[$(review "HowAreWoo" "abc1234" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "howarewoo" "1")"
assert_eq "$got" "abc1234" "(2b) local self-trust matches login case-insensitively"

# --- (3) third-party marker, local run, me != author -> NOT trusted (anti-forge) ---
json="{\"reviews\":[$(review "mallory" "f00ba12" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "howarewoo" "1")"
assert_eq "$got" "" "(3) local third-party marker is rejected"

# --- (4) self/non-bot marker, CI run (local=0) -> NOT trusted (CI never self-trusts) ---
json="{\"reviews\":[$(review "howarewoo" "223ad82" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "howarewoo" "0")"
assert_eq "$got" "" "(4) self-authored marker in CI is rejected"

# --- (4b) empty me disables self-trust even on a local run ---
json="{\"reviews\":[$(review "howarewoo" "223ad82" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "" "1")"
assert_eq "$got" "" "(4b) empty me disables self-trust"

# --- (5) malformed marker -> empty (silent fallback) ---
json='{"reviews":[{"author":{"login":"claude[bot]"},"body":"no marker here","submittedAt":"2026-06-01T00:00:00Z"}]}'
got="$(resolve "$json" "$BOTS" "" "0")"
assert_eq "$got" "" "(5) review without a marker yields empty"

# --- (5b) no reviews at all -> empty ---
got="$(resolve '{"reviews":[]}' "$BOTS" "howarewoo" "1")"
assert_eq "$got" "" "(5b) no reviews yields empty"

# --- (6) legacy woo-stack-review:sha= alias + trusted author -> trusted ---
json='{"reviews":[{"author":{"login":"claude[bot]"},"body":"<!-- woo-stack-review:sha=cafe123 -->","submittedAt":"2026-06-01T00:00:00Z"}]}'
got="$(resolve "$json" "$BOTS" "" "0")"
assert_eq "$got" "cafe123" "(6) legacy woo-stack-review alias is honored"

# --- (7) latest review wins when several carry a marker ---
json="{\"reviews\":[$(review "claude[bot]" "0000aaa" "2026-06-01T00:00:00Z"),$(review "claude[bot]" "1111bbb" "2026-06-02T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "" "0")"
assert_eq "$got" "1111bbb" "(7) latest submittedAt marker wins"

# --- (8) bot pattern is start-anchored: 'notclaude' is not a bot ---
json="{\"reviews\":[$(review "notclaudebot" "223ad82" "2026-06-01T00:00:00Z")]}"
got="$(resolve "$json" "$BOTS" "" "0")"
assert_eq "$got" "" "(8) login not starting with a bot prefix is rejected in CI"

finish
