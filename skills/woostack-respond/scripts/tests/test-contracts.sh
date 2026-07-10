#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=assert.sh
. "$SCRIPT_DIR/assert.sh"

providers_path="$SKILL_DIR/references/provider-discovery.md"
evidence_path="$SKILL_DIR/references/evidence-contract.md"
template_path="$SKILL_DIR/references/report-template.md"

for path in "$providers_path" "$evidence_path" "$template_path"; do
  if [ ! -f "$path" ]; then
    echo "  FAIL: required contract file is absent: $path"
    exit 1
  fi
done

providers=$(cat "$providers_path")
evidence=$(cat "$evidence_path")
template=$(cat "$template_path")

assert_contains "$providers" 'explicit request → config → repository evidence → host capability' \
  'provider precedence is singular'
assert_contains "$providers" 'never auto-selects an uncorroborated host capability' \
  'installed capability alone is not queried'
assert_contains "$evidence" 'status accepts exactly `executed`' \
  'receipt status is closed'
assert_contains "$evidence" 'regular, non-symlink file inside the current run directory' \
  'receipt path is contained'
assert_contains "$evidence" 'SHA-256' 'receipt binds output bytes'
assert_contains "$evidence" 'records_returned' 'receipt binds record count'
assert_contains "$template" 'outcome: {{OUTCOME}}' 'report uses outcome field'
assert_not_contains "$template" 'status: {{' 'report does not borrow lifecycle status'
assert_contains "$template" '## Query Coverage' 'report carries receipts'
assert_contains "$template" '## Uncovered and Blocked Evidence' 'partial coverage is explicit'

finish >/dev/null
echo 'PASS: response contracts'
