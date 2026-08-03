#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-review/SKILL.md"
COMMANDS="$ROOT/skills/woostack-review/references/commands.md"
CONFIG="$ROOT/skills/woostack-review/references/configuration.md"

ROOT_TEXT="$(cat "$SKILL")"
COMMANDS_TEXT="$(cat "$COMMANDS")"
CONFIG_TEXT="$(cat "$CONFIG")"

assert_fixed() { # content needle message
  local content="$1" needle="$2" message="$3"
  if [[ "$content" != *"$needle"* ]]; then
    fail "$message (missing: $needle)"
  fi
}

assert_absent() { # content needle message
  local content="$1" needle="$2" message="$3"
  if [[ "$content" == *"$needle"* ]]; then
    fail "$message (unexpected: $needle)"
  fi
}

assert_matches() { # content regex message
  local content="$1" regex="$2" message="$3"
  if ! grep -Eq "$regex" <<< "$content"; then
    fail "$message (missing pattern: $regex)"
  fi
}

# Public admission is exactly one explicit existing PR.
assert_fixed "$ROOT_TEXT" '/woostack-review <PR#>' 'root documents the one exact-PR command'
assert_fixed "$COMMANDS_TEXT" '/woostack-review <PR#>' 'catalog documents the one exact-PR command'
assert_fixed "$COMMANDS_TEXT" 'only public review mode' 'catalog states the single public mode'
assert_fixed "$CONFIG_TEXT" 'one exact existing pull' 'configuration preserves exact-PR admission'
for text in "$ROOT_TEXT" "$COMMANDS_TEXT" "$CONFIG_TEXT"; do
  assert_absent "$text" 'review the local diff' 'public docs do not admit standing local diffs'
  assert_absent "$text" '/woostack-review --fast' 'public docs remove fast mode'
  assert_absent "$text" '/woostack-review --deep' 'public docs remove deep mode'
  assert_absent "$text" '/woostack-review --full' 'public docs remove full mode'
done
assert_fixed "$ROOT_TEXT" 'Internal `fast`/`standard`/`deep` tiers' 'root preserves internal worker tiers'

# The pipeline is one detected multi-angle pass followed by both validators and intersection.
assert_fixed "$ROOT_TEXT" 'The multi-angle swarm pass' 'root names one multi-angle swarm pass'
assert_fixed "$ROOT_TEXT" 'prosecutor/defender intersection' 'root names the validator intersection'
assert_fixed "$ROOT_TEXT" 'findings.prosecutor.json' 'root retains prosecutor artifact'
assert_fixed "$ROOT_TEXT" 'findings.defender.json' 'root retains defender artifact'
assert_fixed "$ROOT_TEXT" 'intersect-findings.sh' 'root retains deterministic intersection script'

# Review is advisory and posting is complete, exact-PR delivery.
assert_fixed "$ROOT_TEXT" 'Every finding in' 'root requires posting every accepted finding'
assert_fixed "$ROOT_TEXT" 'inline comment' 'root supports inline accepted findings'
assert_fixed "$ROOT_TEXT" 'general review comment' 'root supports general accepted findings'
assert_fixed "$ROOT_TEXT" 'A blocker maps to `REQUEST_CHANGES`' 'root requests changes for blockers'
assert_fixed "$ROOT_TEXT" 'including nit-only results' 'root keeps nits non-blocking'
assert_matches "$ROOT_TEXT" 'use `APPROVE`[[:space:]]+when the platform permits' 'root approves non-blocking results when permitted'
assert_fixed "$ROOT_TEXT" 'never edits' 'root forbids source edits and merges'
assert_fixed "$COMMANDS_TEXT" 'never edits source or tests' 'catalog keeps review report-only'

# Worker and validator orchestration details are linked rather than duplicated in the catalog.
assert_fixed "$COMMANDS_TEXT" '_worker-header.md' 'catalog links canonical worker contract'
assert_fixed "$COMMANDS_TEXT" '_orchestrator-header.md' 'catalog links canonical posting contract'
assert_fixed "$COMMANDS_TEXT" 'verify-receipts.sh' 'catalog links canonical pipeline scripts'

finish
