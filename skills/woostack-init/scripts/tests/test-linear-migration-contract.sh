#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
REFERENCE="$ROOT/skills/woostack-init/references/migration.md"
FIXTURES="$ROOT/skills/woostack-init/evals/fixtures"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

[ -f "$REFERENCE" ] || fail "migration reference is missing"
contract="$(cat "$REFERENCE")"
for phrase in \
  "No local development-record file is deleted" \
  "localDeletions: []" \
  "never matches a remote resource by title" \
  "Git blob ID" \
  "all-or-nothing" \
  "linear://project/<uuid>" \
  "linear://issue/<uuid>"; do
  assert_contains "$contract" "$phrase" "migration contract pins $phrase"
done

for name in active historical ambiguous partial foreign; do
  file="$FIXTURES/migration-$name.json"
  [ -f "$file" ] || fail "missing migration fixture: $name"
  assert_eq "$(jq -r '.schemaVersion' "$file")" "1" "$name fixture uses schema version 1"
  assert_eq "$(jq -r '.classification' "$file")" "$name" "$name fixture names its classification"
  assert_eq "$(jq -r '.local.paths | length > 0' "$file")" "true" "$name fixture retains local paths"
  assert_eq "$(jq -r '(.local.gitBlobs | length) == (.local.paths | length)' "$file")" "true" "$name fixture retains one Git blob per local path"
  assert_eq "$(jq -r '.local.originalProvenance | length > 0' "$file")" "true" "$name fixture retains original provenance"
done

assert_eq "$(jq -r '.receipts.complete and .receipts.independentReadBack and .receipts.ownershipVerified and .receipts.relationsVerified and .receipts.provenanceVerified' "$FIXTURES/migration-active.json")" "true" "active deletion requires a complete verified receipt set"
assert_eq "$(jq -r '.result.localDeletions | length > 0' "$FIXTURES/migration-active.json")" "true" "fully migrated active records may cross the deletion gate"
assert_eq "$(jq -r '.evidence.acceptanceVerified and (.evidence.mergeCommit | length == 40) and (.remote.created == false)' "$FIXTURES/migration-historical.json")" "true" "historical cleanup requires Git and acceptance recovery proof without remote import"

for name in ambiguous partial foreign; do
  file="$FIXTURES/migration-$name.json"
  assert_eq "$(jq -c '.result.localDeletions' "$file")" "[]" "$name evidence never deletes local records"
  assert_eq "$(jq -c '.result.provenanceRewrites' "$file")" "[]" "$name evidence never rewrites provenance"
done
assert_eq "$(jq -r '.remote.clientId' "$FIXTURES/migration-partial.json")" "44444444-4444-4444-8444-444444444444" "partial migration preserves its stable client UUID for resume"
assert_eq "$(jq -r '.remote.projectId' "$FIXTURES/migration-partial.json")" "55555555-5555-4555-8555-555555555555" "partial migration preserves its verified native project ID"
finish
