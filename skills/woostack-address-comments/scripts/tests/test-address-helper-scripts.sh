#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPTS="$ROOT/skills/woostack-address-comments/scripts"

for script in prefetch.sh fetch-threads.sh resolve-thread.sh memory-record.sh memory-append.sh resolve-outdir.sh; do
  bash -n "$SCRIPTS/$script"
done

work="$(mktemp -d)"
OUTDIR="$work/out" \
GITHUB_REPOSITORY="owner/repo" \
PR_NUMBER=123 \
WOO_REVIEW_TEST_MODE=1 \
WOO_REVIEW_FAKE_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"thread-1","isResolved":false,"path":"src/a.ts","line":7,"diffHunk":"@@ -1 +1 @@","comments":{"nodes":[{"author":{"login":"reviewer"},"body":"fix this"}]}}]}}}}}' \
  bash "$SCRIPTS/fetch-threads.sh" >/tmp/address-fetch-threads.out

assert_contains "$(cat /tmp/address-fetch-threads.out)" "Unresolved threads to address: 1" "fetch reports unresolved thread count"
assert_contains "$(jq -r '.[0].threadId' "$work/out/address-threads.json")" "thread-1" "fetch writes thread id"

mkdir -p "$work/repo/.woostack/memory"
cat > "$work/repo/.woostack/memory/address-rule.md" <<'NOTE'
---
name: address-rule
type: convention
scope: src/**
updated: 2026-06-03
source: address-comments
---
Address-comments scoped memory is loaded before analysis.
NOTE

pushd "$work/repo" >/dev/null
OUTDIR="$work/prefetch-out" \
GITHUB_REPOSITORY="owner/repo" \
PR_NUMBER=123 \
WOO_REVIEW_TEST_MODE=1 \
WOO_ADDRESS_FAKE_CHANGED_PATHS="src/a.ts" \
WOO_REVIEW_FAKE_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
  bash "$SCRIPTS/prefetch.sh" >/tmp/address-prefetch.out
popd >/dev/null

assert_contains "$(cat /tmp/address-prefetch.out)" "Address prefetch complete" "prefetch reports completion"
assert_contains "$(cat "$work/prefetch-out/address-changed-paths.txt")" "src/a.ts" "prefetch writes changed paths"
assert_contains "$(cat "$work/prefetch-out/memory.md")" "Address-comments scoped memory" "prefetch composes scoped memory"

MEMORY_FILE="$work/memory.md" \
LEARNING="Accepted address-comments pattern: do not re-flag." \
  bash "$SCRIPTS/memory-append.sh" >/tmp/address-memory-append.out
assert_contains "$(cat "$work/memory.md")" "Accepted address-comments pattern" "memory append writes learning"

rm -rf "$work"
finish
