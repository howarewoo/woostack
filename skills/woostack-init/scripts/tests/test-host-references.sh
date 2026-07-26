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
for h in antigravity claude-code codex cursor omp opencode; do
  assert_eq "$([ -f "$H/$h.md" ] && echo y)" "y" "hosts: $h.md present"
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

# (d) omp uses fixed role-backed built-in workers, not generated project agents
omp="$(cat "$H/omp.md")"
for token in "deep -> slow" "standard -> default" "fast -> smol" "role-backed built-in workers"; do
  assert_contains "$omp" "$token" "omp roles: canonical guidance contains $token"
done
for token in "gen-omp-agents.sh" "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier" "models.<tier>"; do
  assert_not_contains "$omp" "$token" "omp roles: canonical guidance omits $token"
done

# (e) authored docs mirror the supported-host contract
ROOT="$(cd "$S/.." && pwd)"
DOCS="$ROOT/site/content/docs"
HARNESS_DOCS="$DOCS/harnesses"
assert_contains "$(cat "$DOCS/meta.json")" '"harnesses"' "docs: root navigation registers harnesses"
assert_eq "$([ -f "$HARNESS_DOCS/index.mdx" ] && echo y)" "y" "docs: harness overview present"
assert_eq "$([ -f "$HARNESS_DOCS/meta.json" ] && echo y)" "y" "docs: harness navigation present"
if [ -f "$HARNESS_DOCS/index.mdx" ] && [ -f "$HARNESS_DOCS/meta.json" ]; then
  overview="$(cat "$HARNESS_DOCS/index.mdx")"
  harness_nav="$(cat "$HARNESS_DOCS/meta.json")"
  assert_contains "$overview" "skill logic should work in any harness" "docs: portability contract"
  assert_contains "$overview" "native capabilities" "docs: unsupported-host capability caveat"
  assert_contains "$overview" "model selection" "docs: model-selection caveat"
  for f in "$H"/*.md; do
    slug="$(basename "$f" .md)"
    [ "$slug" = "README" ] && continue
    assert_contains "$harness_nav" "\"$slug\"" "docs: harness nav registers $slug"
    assert_contains "$overview" "/docs/harnesses/$slug" "docs: overview links $slug"
    assert_eq "$([ -f "$HARNESS_DOCS/$slug.mdx" ] && echo y)" "y" "docs: $slug page present"
    if [ -f "$HARNESS_DOCS/$slug.mdx" ]; then
      assert_contains "$(cat "$HARNESS_DOCS/$slug.mdx")" "references/hosts/$slug.md" "docs: $slug links canonical reference"
    fi
  done
fi
for page in "harnesses/index.mdx:$HARNESS_DOCS/index.mdx" "harnesses/omp.mdx:$HARNESS_DOCS/omp.mdx" "configuration.mdx:$DOCS/configuration.mdx" "concepts/context-management.mdx:$DOCS/concepts/context-management.mdx"; do
  label="${page%%:*}"
  path="${page#*:}"
  assert_eq "$([ -f "$path" ] && echo y)" "y" "docs: omp guidance page present: $label"
  [ -f "$path" ] || continue
  source="$(cat "$path")"
  for token in "deep -> slow" "standard -> default" "fast -> smol" "role-backed built-in workers"; do
    assert_contains "$source" "$token" "docs: $label contains $token"
  done
  for token in "gen-omp-agents.sh" "woostack-fast" "woostack-standard" "woostack-deep" "agent-by-tier" "Agent-by-tier" "models.<tier>"; do
    assert_not_contains "$source" "$token" "docs: $label omits $token"
  done
done
landing="$(cat "$DOCS/index.mdx")"
assert_not_contains "$landing" "Aider" "docs: Aider is not explicitly supported"
assert_contains "$landing" "/docs/harnesses" "docs: landing links harnesses"

# (e) review schema and host routing stay aligned on ordered fallback leaves.
review_skill="$(cat "$S/woostack-review/SKILL.md")"
review_header="$(cat "$S/woostack-review/prompts/_orchestrator-header.md")"
assert_contains "$review_skill" "non-empty ordered array" "fallback schema: review skill accepts arrays"
assert_contains "$review_skill" "entry 0 is the primary" "fallback schema: review skill defines primary"
assert_contains "$review_header" "non-empty ordered array" "fallback schema: orchestrator accepts arrays"
assert_contains "$review_header" "entry 0 is primary" "fallback schema: orchestrator defines primary"
for prompt in anthropic openai opencode; do
  assert_contains "$(cat "$S/woostack-review/prompts/$prompt.md")" 'if type=="array" then .[0]' \
    "fallback routing: $prompt selects entry 0"
done

# (f) generic review/sweep fallback recovery remains intact
assert_contains "$review_skill" "concurrent-spawn burst" "re-dispatch: review names the burst condition"
assert_contains "$review_skill" "resolve-model.sh --provider <p> --tier <t> --index N" "re-dispatch: review pins the next configured entry via resolver"
assert_contains "$review_skill" "walking the configured fallback chain" "re-dispatch: review walks the chain before the receipt gate"
sweep_skill="$(cat "$S/woostack-sweep/SKILL.md")"
assert_contains "$sweep_skill" "usage-limit swarm failure is" "re-dispatch: sweep clarifies usage-limit is not an immediate blocker"

finish
