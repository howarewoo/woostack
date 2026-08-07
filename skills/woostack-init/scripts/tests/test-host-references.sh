#!/usr/bin/env bash
# Structural contract for host-owned routing and optional artifact access.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
S="$(cd "$HERE/../../.." && pwd)"
H="$S/using-woostack/references/hosts"

assert_eq "$([ -f "$H/README.md" ] && echo y)" "y" "hosts: README present"
allowlisted_hosts="$(python3 - "$H/README.md" <<'PY'
import re
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    match = re.fullmatch(r"- \[\x60([^\x60]+)\x60\]\(([^/)]+)\.md\)", line)
    if match and match.group(1) == match.group(2):
        print(match.group(1))
PY
)"
actual_allowlist="$(printf '%s\n' $allowlisted_hosts | sort | paste -sd, -)"
expected_allowlist="$(printf '%s\n' antigravity claude-code codex cursor omp opencode | sort | paste -sd, -)"
assert_eq "$actual_allowlist" "$expected_allowlist" \
  "hosts: canonical router exposes exactly the six supported coding hosts"

for host in $allowlisted_hosts; do
  file="$H/$host.md"
  assert_eq "$([ -f "$file" ] && echo y)" "y" "hosts: allowlisted $host.md present"
  body="$(cat "$file")"
  for heading in "## Detection" "## Subagent spawn" "## Tier routing" "## Host-level fallback" "## Per-skill notes" "## Degradation"; do
    assert_eq "$([[ "$body" == *"$heading"* ]] && echo y)" "y" "hosts: $host.md has '$heading'"
  done
done
host_index="$(cat "$H/README.md")"
assert_contains "$host_index" '[`omp`](omp.md)' "hosts: OMP is dispatchable"
assert_not_contains "$host_index" '[`hermes`](hermes.md)' "hosts: Hermes is excluded from dispatch"
assert_eq "$([ ! -e "$H/hermes.md" ] && [ ! -L "$H/hermes.md" ] && echo y)" "y" \
  "hosts: retired Hermes adapter is absent"

model_tiers="$(cat "$S/using-woostack/references/model-tiers.md")"
assert_contains "$model_tiers" "hosts/README.md" "model tiers links host adapters"
assert_contains "$model_tiers" "supported coding-host allowlist" \
  "model tiers applies the canonical supported-host gate"
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
assert_contains "$omp" "Every build resolves or creates one canonical project before ideation" "OMP requires the canonical build project"
assert_contains "$omp" "policy supplies validated non-secret defaults but never authorizes" "OMP limits policy authority"
assert_contains "$omp" "Before fix root-cause proof, make no Linear call" "OMP preserves pre-proof fix isolation"
assert_contains "$omp" "Required provider failure blocks the fix/build" "OMP fails closed for required records"

assert_not_contains "$omp" "Hermes engineer pairing" \
  "OMP does not advertise an external-engineer coder mode"
assert_not_contains "$omp" "hosts/hermes.md" \
  "OMP does not link the retired Hermes host adapter"

using="$(cat "$S/using-woostack/SKILL.md")"
assert_not_contains "$using" "engineer-agent authority protocol" \
  "using-woostack does not load the engineer-agent protocol"
assert_not_contains "$using" "hosts/hermes.md" \
  "using-woostack does not route to the Hermes host adapter"

review="$(cat "$S/woostack-review/SKILL.md")"
assert_eq "$([[ "$review" == *"Before host-dependent dispatch"* ]] && echo y)" "y" \
  "review preflights before host-dependent dispatch"
assert_eq "$([[ "$review" == *"required host selectors before launch"* ]] && echo y)" "y" \
  "review preflights the complete selector set before launch"
assert_eq "$([[ "$review" == *"blocks before the first worker"* ]] && echo y)" "y" \
  "review fails before dispatch when selectors are missing"
assert_eq "$([[ "$review" != *'agent: quick_task'* ]] && echo y)" "y" \
  "review omits the unavailable quick selector"
assert_eq "$([[ "$review" != *'agent: oracle'* ]] && echo y)" "y" \
  "review omits the unavailable deep selector"

ROOT="$(cd "$S/.." && pwd)"
DOCS="$ROOT/site/content/docs"
assert_contains "$(cat "$DOCS/meta.json")" '"hermes"' \
  "docs navigation registers the top-level Hermes guide"
assert_not_contains "$(cat "$DOCS/harnesses/meta.json")" '"hermes"' \
  "harness navigation does not register Hermes"
for page in "$DOCS/harnesses/index.mdx" "$DOCS/harnesses/omp.mdx" "$DOCS/hermes.mdx"; do
  assert_eq "$([ -f "$page" ] && echo y)" "y" "authored supported page exists"
done
assert_contains "$(cat "$DOCS/harnesses/omp.mdx")" "skills/using-woostack/references/hosts/omp.md" \
  "OMP docs link canonical adapter"
hermes="$(cat "$DOCS/hermes.mdx")"
assert_contains "$hermes" "external engineer" "Hermes docs define the external boundary"
assert_contains "$hermes" "persistent OMP" "Hermes docs require one persistent OMP process"
assert_contains "$hermes" "verbatim" "Hermes docs require verbatim approval relay"
assert_contains "$hermes" "same persistent OMP process" "Hermes docs bind approval to the same process"
assert_contains "$hermes" "restart" "Hermes docs fail closed on restart"
finish
