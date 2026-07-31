#!/usr/bin/env bash
# Structural contract for host-owned routing and optional artifact access.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"
H="$S/using-woostack/references/hosts"

assert_eq "$([ -f "$H/README.md" ] && echo y)" "y" "hosts: README present"
count=0
for file in "$H"/*.md; do
  [ "$(basename "$file")" = "README.md" ] && continue
  count=$((count + 1))
  body="$(cat "$file")"
  for heading in "## Detection" "## Subagent spawn" "## Tier routing" "## Host-level fallback" "## Per-skill notes" "## Degradation"; do
    assert_eq "$([[ "$body" == *"$heading"* ]] && echo y)" "y" "hosts: $(basename "$file") has '$heading'"
  done
done
for host in antigravity claude-code codex cursor hermes omp opencode; do
  assert_eq "$([ -f "$H/$host.md" ] && echo y)" "y" "hosts: $host.md present"
done
assert_eq "$([ "$count" -ge 7 ] && echo y)" "y" "hosts: at least seven host files"

model_tiers="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$model_tiers" "hosts/README.md" "model tiers links host adapters"
assert_contains "$model_tiers" "| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |" "provider table remains stable"
assert_contains "$(cat "$S/woostack-review/prompts/_orchestrator-header.md")" "<!-- WOO_MODEL_TIERS_TABLE -->" "review inline marker remains stable"

omp="$(cat "$H/omp.md")"
for row in \
  '| `deep -> slow` | `slow` | `agent: oracle` |' \
  '| `standard -> default` | `default` | `agent: task` |' \
  '| `fast -> smol` | `smol` | `agent: quick_task` |'; do
  assert_contains "$omp" "$row" "OMP maps $row"
done
assert_contains "$omp" "Artifact-free work makes no Linear call" "OMP keeps artifacts optional"
assert_contains "$omp" "Missing Linear capability blocks only explicitly requested" "OMP degrades artifact work independently"

hermes="$(cat "$H/hermes.md")"
assert_contains "$hermes" 'native `delegate_task`' "Hermes keeps native default"
assert_contains "$hermes" "Neither route requires Linear" "Hermes does not require Linear"
assert_contains "$hermes" "omp --profile <engineer> -p --cwd <worktree> <prompt>" "Hermes pins conceptual OMP argv"
assert_contains "$hermes" "Arguments are values, not shell source" "Hermes quarantines task text"
assert_contains "$hermes" "distinct Hermes/OMP sessions and role credentials" "Hermes isolates paired roles"
assert_contains "$hermes" "Without an artifact request, do not" "Hermes avoids implicit Linear calls"

for consumer in \
  "$S/woostack-init/SKILL.md" \
  "$S/woostack-commit/SKILL.md" \
  "$S/woostack-execute/references/subagent-driver.md" \
  "$S/woostack-review/SKILL.md"; do
  body="$(cat "$consumer")"
  for stale in "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier"; do
    assert_not_contains "$body" "$stale" "consumer omits stale generated-worker guidance"
  done
done

ROOT="$(cd "$S/.." && pwd)"
DOCS="$ROOT/site/content/docs"
assert_contains "$(cat "$DOCS/meta.json")" '"harnesses"' "docs navigation registers harnesses"
for page in "$DOCS/harnesses/index.mdx" "$DOCS/harnesses/omp.mdx" "$DOCS/harnesses/hermes.mdx"; do
  assert_eq "$([ -f "$page" ] && echo y)" "y" "authored harness page exists"
done
assert_contains "$(cat "$DOCS/harnesses/omp.mdx")" "skills/using-woostack/references/hosts/omp.md" "OMP docs link canonical adapter"
assert_contains "$(cat "$DOCS/harnesses/hermes.mdx")" "skills/using-woostack/references/hosts/hermes.md" "Hermes docs link canonical adapter"
assert_contains "$(cat "$DOCS/harnesses/omp.mdx")" "Neither profile requires a Linear principal or issue" "OMP docs keep artifacts optional"
assert_contains "$(cat "$DOCS/harnesses/hermes.mdx")" "Neither route requires Linear" "Hermes docs keep artifacts optional"

finish
