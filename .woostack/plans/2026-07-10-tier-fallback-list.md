---
type: plan
source: .woostack/specs/2026-07-10-tier-fallback-list.md
status: executing
date: 2026-07-10
branch: feature/tier-fallback
links:
  - "[[2026-07-10-tier-fallback-list]]"
---

**Source:** [[specs/2026-07-10-tier-fallback-list]]

# Tier fallback lists — Implementation Plan

**Goal:** every tier leaf accepts an ordered array of `{model, effort}`; entry 0 keeps
today's semantics everywhere; the omp generator enacts entries 1..n as project-scoped
`retry.fallbackChains` (V1-gated, non-clobbering); other hosts document the order.

## Architecture

1. **One normalization idiom, two jq homes.** `resolve-model.sh:70,75`
   (`provider_tier_model`, sourced by `load-prompt.sh:69` — CI and local share it) and
   `load-prompt.sh:74-81` (`config_effort_for`) each gain
   `if type=="array" then .[0] else . end` ahead of the existing object/string handling.
   `gen-omp-agents.sh:render_tier` (leaf read at :56) normalizes the same way in one place
   before its existing string/object case.
2. **Chain emission is a new generator stage**, downstream of def rendering: collect
   `(primary → [entries 1..n models])` per tier, dedupe by primary, error on conflicting
   orders, then non-clobbering-merge `retry.fallbackChains` into `<repo>/.omp/config.yml`.
3. **Docs follow the hosts/ taxonomy**: leaf grammar in `model-tiers.md`; per-host
   entries-1..n posture inside each existing "Host-level fallback" section (no new
   section header — the 6×6 contract loop stays untouched); site sync in
   `configuration.mdx`.

## Increment 1 — leaf grammar + entry-0 resolution (PR 1)

**Deliverable:** array leaves parse everywhere; behavior byte-identical for entry 0.
AC1, AC2, AC3, AC6.

- [x] **Step 1 (red):** add failing tests — `test-gen-omp-agents.sh`: array leaf renders
      entry-0 model+effort; empty-array leaf → tier unset + stderr warn; review script
      test (existing suite home): `resolve-model.sh` returns entry-0 for array flat and
      provider-scoped leaves.
- [x] **Step 2:** `gen-omp-agents.sh`: normalize array→first in `render_tier` (guard:
      empty array = malformed leaf branch, loud, exit 0 law unchanged).
- [x] **Step 3:** `resolve-model.sh:70,75` + `load-prompt.sh:78`: prepend array
      normalization in the jq filters (both provider-scoped and flat reads).
- [x] **Step 4:** doctor config check: leaf schema `string|object|array(1..)`; empty
      array or non-(string|object) entry → error.
- [x] **Step 5 (green):** new tests pass; full init suite + review script tests green;
      `git diff` on `prompts/` clean; existing fixtures byte-identical (AC1 proof: run
      generator on an object-leaf fixture before/after, diff defs).
- [x] **Step 6:** commit; task-scoped spec+quality review; distill if durable.

## Increment 2 — omp chain enactment (PR 2)

**Deliverable:** entries 1..n become project-scoped omp fallback chains, or the loud
degraded branch. AC4.

- [ ] **Step 1 (V1 probe):** verify `retry.fallbackChains` record merge semantics at the
      project layer + live pickup (omp docs / `omp config get` in a scratch dir).
      Negative → skip Steps 2-4, document informational-only in `hosts/omp.md`, jump to
      Step 5 with the §7-unsupported wording.
- [ ] **Step 2 (red):** generator tests — multi-entry tier emits chain keyed by primary;
      dedupe identical primaries; conflicting orders for one primary → loud error;
      pre-existing user `.omp/config.yml` content preserved (merge test); parse-failure
      file → refusal + printed block, no write.
- [ ] **Step 3:** chain-emission stage in `gen-omp-agents.sh` (jq/python-free YAML
      handling decided at implementation; refusal branch on anything unparseable);
      slug quote-or-reject reused from def rendering.
- [ ] **Step 4:** gitignore: only a generator-created `.omp/config.yml` is added to
      `.omp/.gitignore` (defs precedent); doctor warns when a fallback list exists but
      the host cannot enact it.
- [ ] **Step 5 (green):** suite green; idempotency proof (run generator twice, second run
      no-diff).
- [ ] **Step 6:** commit; task-scoped review; distill.

## Increment 3 — docs + site sync + closeout (PR 3)

**Deliverable:** taxonomy documented; site builds; plan closes. AC5, AC7.

- [ ] **Step 1 (red):** grep — array-form absent from `model-tiers.md` leaf paragraph,
      `hosts/*.md` fallback sections, `configuration.mdx`.
- [ ] **Step 2:** `model-tiers.md` leaf-shape paragraph (array form + entry-0 law +
      per-host enactment pointer); one entries-1..n sentence in each of the six
      `hosts/*.md` "Host-level fallback" sections; `configuration.mdx` array example
      (MDX escaping per memory `authored-mdx-escapes-jsx-and-table-pipes`).
- [ ] **Step 3 (green):** `test-host-references.sh` green (no contract change); provider
      table + `WOO_MODEL_TIERS_TABLE` marker byte-stable; real install +
      `pnpm -C site build` green.
- [ ] **Step 4:** commit; final task-scoped review; distill durable memory; set plan
      `status: done` (terminal transition authored by execute, conventions.md).

## Verification map (AC → proof)

| AC | Proof |
|---|---|
| AC1 | fixture defs byte-diff clean pre/post (Inc 1 Step 5) |
| AC2 | entry-0 tests in generator + resolver suites (Inc 1 Steps 1/5) |
| AC3 | empty-array tests: generator warn + doctor error (Inc 1 Steps 1/4) |
| AC4 | chain tests + idempotency no-diff, or documented degraded branch (Inc 2) |
| AC5 | hosts/*.md sentences + `test-host-references.sh` green (Inc 3) |
| AC6 | prompts/ diff-clean + marker assertion (Inc 1 Step 5, Inc 3 Step 3) |
| AC7 | site build green (Inc 3 Step 3) |

## Rollback

Graphite stack on `feature/tier-fallback` (parented on the host-references stack);
revert = drop the PR. Increment 1 is behavior-preserving normalization; Increment 2 is
the only host-config writer and carries its own refusal branch; Increment 3 is docs-only.

---

_Hardened 2026-07-10 — decomposition verified (3 PR-sized increments; Inc 1 behavior-preserving with fixture byte-diff proof; Inc 2 probe-gated with defined degraded branch and refusal-not-corruption law; Inc 3 docs-only). Test-first per increment; resolver test homes verified (`test-resolve-model.sh`, `test-load-prompt-models.sh`, `test-gen-omp-agents.sh`). Both review resolution paths move through the single sourced authority. No open branches._
