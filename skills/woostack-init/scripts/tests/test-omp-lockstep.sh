#!/usr/bin/env bash
# Structural lockstep: every omp-host edit site must carry its pinned marker.
# Adding an omp host touches all of these in lockstep (wisdom: lockstep-edit-sites).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"          # -> repo/skills

mt="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$mt" "agent-by-tier" "site: model-tiers.md omp bucket"
assert_contains "$mt" "| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |" "site: provider table columns unchanged"
assert_contains "$(cat "$S/woostack-execute/references/subagent-driver.md")" "woostack-<effective-tier>" "site: execute dispatch"
assert_contains "$(cat "$S/woostack-commit/SKILL.md")" "woostack-fast" "site: commit fast-draft"
assert_contains "$(cat "$S/woostack-review/SKILL.md")" "woostack-<tier>" "site: review local swarm"
assert_eq "$([ -f "$S/woostack-init/scripts/gen-omp-agents.sh" ] && echo y)" "y" "site: generator present"
assert_eq "$([ -f "$S/woostack-doctor/scripts/checks/omp-agents.sh" ] && echo y)" "y" "site: doctor check present"
assert_contains "$(cat "$S/woostack-review/prompts/_orchestrator-header.md")" "<!-- WOO_MODEL_TIERS_TABLE -->" "site: CI table-inline marker intact"
finish
