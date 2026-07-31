#!/usr/bin/env bash
# Regression: one-issue implementers favor fast, may escalate to standard, and never gain deep-tier authority.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

PROMPT="$ROOT/skills/woostack-execute/prompts/implementer.md"
DRIVER="$ROOT/skills/woostack-execute/references/subagent-driver.md"
SKILL="$ROOT/skills/woostack-execute/SKILL.md"

tier="$(sed -n '2s/^tier: //p' "$PROMPT")"
driver="$(tr '\n' ' ' < "$DRIVER" | tr -s ' ')"
skill="$(tr '\n' ' ' < "$SKILL" | tr -s ' ')"

assert_eq "$tier" "fast" "implementer prompt must default to fast"
assert_contains "$driver" 'implementation `fast`' \
  "driver must default implementers to fast"
assert_contains "$driver" 'spec-reviewer `standard`' \
  "driver must preserve the spec-reviewer default"
assert_contains "$driver" 'quality-reviewer `deep`' \
  "driver must preserve the quality-reviewer default"
assert_contains "$driver" '| **Implementation escalate** | `standard` |' \
  "implementation may escalate only to standard"
assert_contains "$driver" 'security / auth / crypto, data migrations, concurrency / locking, money / billing' \
  "risk-sensitive implementation must escalate to standard"
assert_contains "$driver" 'cross-cutting / architectural' \
  "cross-cutting implementation must escalate to standard"
assert_contains "$driver" 'issue task contract is highly ambiguous inside its permitted boundary' \
  "bounded ambiguity may escalate implementation"
assert_contains "$driver" 'a `fast` attempt returned **BLOCKED** specifically because it needs more reasoning' \
  "a reasoning-blocked fast implementer may escalate to standard"
assert_contains "$driver" '| **Implementation ceiling** | never `deep` |' \
  "implementation must have an explicit deep-tier ceiling"
assert_contains "$driver" '`standard` is the implementation maximum' \
  "standard must remain the implementation maximum"
assert_contains "$driver" 'send a `decisionRequest` to the responsible issue engineer/lead' \
  "a blocked standard worker must escalate through issue authority"
assert_contains "$driver" 'a `standard` implementation worker never retries at `deep`' \
  "a blocked standard implementer must not escalate to deep"
assert_not_contains "$driver" '| **Bump UP** | `deep` |' \
  "the role-agnostic deep bump must remain absent"
assert_contains "$driver" 'spec-reviewer → `fast` on a trivial diff' \
  "spec-reviewer trivial-diff downgrade must remain"
assert_contains "$driver" 'quality-reviewer → `standard` on a trivial diff' \
  "quality-reviewer trivial-diff downgrade must remain"
assert_contains "$skill" 'Implementation workers default to `fast`' \
  "execute overview must state the fast implementation default"
assert_contains "$skill" 'never use `deep`' \
  "execute overview must state the implementation ceiling"

# Tier selection changes reasoning capacity only; it cannot broaden the one-issue delegation.
assert_contains "$driver" "authority never changes with tier" \
  "model tier must not change worker authority"
assert_contains "$driver" "Every dispatched paired coder, generic implementer, or generic reviewer brief is self-contained and" \
  "every tier must keep one-issue scope"
assert_contains "$driver" "Neither route grants this driver lifecycle, acceptance, or source-control authority" \
  "tier escalation must not acquire controller authority"
assert_contains "$driver" 'request/write terminal `done`' \
  "no implementation tier may mark terminal success"

finish
