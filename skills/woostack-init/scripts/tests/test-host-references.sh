#!/usr/bin/env bash
# Structural contract: per-host mechanics live in using-woostack/references/hosts/,
# consuming skills carry the canonical load directive, and the provider/tier layer
# stays stable for the CI-inlined review prompt (wisdom: lockstep-edit-sites).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"          # -> repo/skills
H="$S/using-woostack/references/hosts"

# (a) host files exist and honor the six-section contract (loop, not a hardcoded list)
assert_eq "$([ -f "$H/README.md" ] && echo y)" "y" "hosts: README present"
n=0
for f in "$H"/*.md; do
  [ "$(basename "$f")" = "README.md" ] && continue
  n=$((n+1))
  body="$(cat "$f")"
  for hdr in "## Detection" "## Subagent spawn" "## Tier routing" "## Host-level fallback" "## Per-skill notes" "## Degradation"; do
    assert_contains "$body" "$hdr" "hosts: $(basename "$f") has '$hdr'"
  done
done
assert_eq "$([ "$n" -ge 6 ] && echo y)" "y" "hosts: at least six host files (found $n)"

# (b) canonical load directive in every consumer (one physical line, ASCII)
D='load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded)'
assert_contains "$(cat "$S/using-woostack/references/model-tiers.md")" "$D" "directive: model-tiers.md"
assert_contains "$(cat "$S/using-woostack/references/hosts/README.md")" "$D" "directive: hosts README"
assert_contains "$(cat "$S/woostack-execute/references/subagent-driver.md")" "$D" "directive: subagent-driver.md"
assert_contains "$(cat "$S/woostack-review/SKILL.md")" "$D" "directive: review SKILL.md"
assert_contains "$(cat "$S/woostack-commit/SKILL.md")" "$D" "directive: commit SKILL.md"
assert_contains "$(cat "$S/woostack-init/SKILL.md")" "$D" "directive: init SKILL.md"
assert_contains "$(cat "$S/woostack-execute-overnight/SKILL.md")" 'references/hosts/<current-host>.md' "directive: overnight advisory host pointer"

# (c) provider/tier layer stable for the CI-inlined blob
mt="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$mt" "| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |" "stability: provider table columns unchanged"
assert_contains "$mt" "hosts/README.md" "stability: model-tiers points at hosts/"
assert_contains "$(cat "$S/woostack-review/prompts/_orchestrator-header.md")" "<!-- WOO_MODEL_TIERS_TABLE -->" "stability: CI table-inline marker intact"

# (d) omp mechanics moved, not duplicated
omp="$(cat "$H/omp.md")"
assert_contains "$omp" "agent-by-tier" "moved: agent-by-tier in hosts/omp.md"
assert_contains "$omp" "gen-omp-agents.sh" "moved: generator invocation in hosts/omp.md"
assert_contains "$omp" "## Host-level fallback" "moved: fallback section in hosts/omp.md"
assert_contains "$omp" "usage-exhaustion" "moved: overnight advisory mechanics in hosts/omp.md"
assert_not_contains "$mt" "agent-by-tier (omp / Oh My Pi)" "dedup: omp bucket gone from model-tiers.md"
assert_not_contains "$mt" "gen-omp-agents.sh" "dedup: generator invocation gone from model-tiers.md"
assert_not_contains "$(cat "$S/woostack-execute/references/subagent-driver.md")" "gen-omp-agents.sh" "dedup: generator invocation gone from subagent-driver.md"
assert_not_contains "$(cat "$S/woostack-execute-overnight/SKILL.md")" "retry.fallbackChains" "dedup: omp mechanics gone from overnight SKILL.md"

# still-required infrastructure (inherited from test-omp-lockstep.sh)
assert_eq "$([ -f "$S/woostack-init/scripts/gen-omp-agents.sh" ] && echo y)" "y" "site: generator present"
assert_eq "$([ -f "$S/woostack-doctor/scripts/checks/omp-agents.sh" ] && echo y)" "y" "site: doctor check present"
finish
