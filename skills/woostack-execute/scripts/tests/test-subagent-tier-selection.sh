#!/usr/bin/env bash
# Regression: implementation dispatches favor fast, can escalate to standard, and never use deep.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

PROMPT="$ROOT/skills/woostack-execute/prompts/implementer.md"
DRIVER="$ROOT/skills/woostack-execute/references/subagent-driver.md"
SKILL="$ROOT/skills/woostack-execute/SKILL.md"

tier="$(sed -n '2s/^tier: //p' "$PROMPT")"
driver="$(cat "$DRIVER")"
skill="$(cat "$SKILL")"

assert_eq "$tier" "fast" "implementer prompt must default to fast"
assert_contains "$driver" 'implementer `fast`,' \
  "driver must default implementers to fast"
assert_contains "$driver" 'spec-reviewer `standard`, quality-reviewer `deep`.' \
  "driver must preserve reviewer defaults"
assert_contains "$driver" '| **Implementation escalate** | `standard` |' \
  "implementation may escalate only to standard"
assert_contains "$driver" 'the task touches security / auth / crypto, data migrations, concurrency / locking, money / billing' \
  "risk-sensitive implementation must escalate to standard"
assert_contains "$driver" 'a `fast` attempt returned **BLOCKED** specifically because it needs more reasoning.' \
  "a reasoning-blocked fast implementer must escalate to standard"
assert_contains "$driver" '| **Implementation ceiling** | never `deep` |' \
  "implementation must have an explicit deep-tier ceiling"
assert_contains "$driver" 'If it remains blocked, provide missing context, split the task, or escalate the plan to the user.' \
  "a blocked standard implementer must route to non-deep recovery"
assert_contains "$driver" 'implementer never retries at `deep`' \
  "a blocked standard implementer must not escalate to deep"
assert_not_contains "$driver" '| **Bump UP** | `deep` |' \
  "the role-agnostic deep bump must be removed"
assert_contains "$driver" 'spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff' \
  "reviewer downgrades must remain unchanged"
assert_contains "$skill" 'Implementers default to `fast`, may escalate to' \
  "the execute overview must state the fast implementation default"
assert_contains "$skill" '`standard` when necessary, and never use `deep`.' \
  "the execute overview must state the standard implementation ceiling"

finish
