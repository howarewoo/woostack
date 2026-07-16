#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

USING="$ROOT/skills/using-woostack/SKILL.md"
DISCIPLINE="$ROOT/skills/using-woostack/references/output-discipline.md"
WORKER="$ROOT/skills/woostack-review/prompts/_worker-header.md"
ORCHESTRATOR="$ROOT/skills/woostack-review/prompts/_orchestrator-header.md"
DEFENDER="$ROOT/skills/woostack-review/prompts/validator.md"
PROSECUTOR="$ROOT/skills/woostack-review/prompts/validator-prosecutor.md"

assert_contains "$(cat "$USING")" "Load and apply the shared" "using-woostack loads the shared output discipline"
assert_contains "$(cat "$USING")" "to every user-facing reply" "using-woostack applies the discipline to user replies"
assert_contains "$(cat "$DISCIPLINE")" "## User-facing replies" "shared discipline governs user replies"
assert_contains "$(cat "$DISCIPLINE")" "Lead with the conclusion" "user replies lead with the result"
assert_contains "$(cat "$DISCIPLINE")" "State each fact once" "user replies do not repeat facts"
assert_contains "$(cat "$DISCIPLINE")" "User requests for more detail override" "explicit detail requests override terseness"
assert_not_contains "$(cat "$DISCIPLINE")" "user-facing replies — including" "user replies are no longer excluded"

assert_contains "$(cat "$WORKER")" "One evidence-bearing sentence" "worker descriptions are concise"
assert_contains "$(cat "$WORKER")" "One imperative sentence" "worker fixes are concise"
assert_contains "$(cat "$WORKER")" "Do not repeat the title" "worker comments avoid repetition"
assert_contains "$(cat "$DEFENDER")" "Conciseness Check" "defender enforces concise comments"
assert_contains "$(cat "$PROSECUTOR")" "Conciseness Check" "prosecutor enforces concise comments"
assert_contains "$(cat "$ORCHESTRATOR")" "One evidence-bearing sentence" "orchestrator mirrors concise descriptions"
assert_contains "$(cat "$ORCHESTRATOR")" '<code><angle></code></sub>' "orchestrator documents the compact footer"
assert_not_contains "$(cat "$ORCHESTRATOR")" 'flagged by the <code><angle></code> agent' "orchestrator removes footer filler"

finish
