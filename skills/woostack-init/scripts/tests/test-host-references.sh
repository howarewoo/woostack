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
init="$(cat "$S/woostack-init/SKILL.md")"
assert_contains "$init" '`<wi>` below means the installed `woostack-init` skill directory' \
  "init defines its installed skill directory"
assert_contains "$init" 'bash <wi>/scripts/provision-omp-agents.sh <canonical-repository>' \
  "init invokes the provisioner from its installed skill directory"
assert_not_contains "$init" 'bash skills/woostack-init/scripts/provision-omp-agents.sh' \
  "init does not assume the source repository layout"


omp="$(cat "$H/omp.md")"
for row in \
  '| `deep -> slow` | `@slow` | `agent: woostack-deep` |' \
  '| `standard -> default` | `@default` | `agent: woostack-standard` |' \
  '| `fast -> smol` | `@smol` | `agent: woostack-fast` |'; do
  assert_contains "$omp" "$row" "OMP maps $row"
done
assert_not_contains "$omp" 'agent: quick_task' "OMP never routes to the unavailable quick selector"
assert_not_contains "$omp" 'agent: oracle' "OMP never routes to the unavailable deep selector"
assert_contains "$omp" "Never generate or repair project workers during review" "OMP forbids review-time generation"
assert_contains "$omp" "Artifact-free work makes no Linear call" "OMP preserves artifact-free operation"
assert_contains "$omp" "Missing automatic capability keeps fix/build planning" "OMP degrades unavailable automatic persistence"

hermes="$(cat "$H/hermes.md")"
assert_contains "$hermes" 'native `delegate_task`' "Hermes keeps native default"
assert_contains "$hermes" "Neither route requires Linear" "Hermes does not require Linear"
assert_contains "$hermes" "omp --profile <engineer> -p --cwd <worktree> <prompt>" "Hermes pins conceptual OMP argv"
assert_contains "$hermes" "Arguments are values, not shell source" "Hermes quarantines task text"
assert_contains "$hermes" "distinct Hermes/OMP sessions and role credentials" "Hermes isolates paired roles"
assert_contains "$hermes" "fix/build plan whose repository" "Hermes supports repository-enabled plan persistence"

review="$(cat "$S/woostack-review/SKILL.md")"
assert_eq "$([[ "$review" == *"after angle detection"* ]] && echo y)" "y" \
  "review preflights after detecting planned angles"
assert_eq "$([[ "$review" == *"Before launching any summary, angle, or validator"* ]] && echo y)" "y" \
  "review preflights the complete selector set before launch"
assert_eq "$([[ "$review" == *"never creates or repairs an agent during review"* ]] && echo y)" "y" \
  "review does not generate workers at dispatch time"
assert_eq "$([[ "$review" != *'agent: quick_task'* ]] && echo y)" "y" \
  "review omits the unavailable quick selector"
assert_eq "$([[ "$review" != *'agent: oracle'* ]] && echo y)" "y" \
  "review omits the unavailable deep selector"

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
