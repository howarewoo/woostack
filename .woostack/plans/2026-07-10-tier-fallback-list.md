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

**Deliverable:** entries 1..n become a real omp runtime fallback chain. AC4.

**Deviation from spec §7 / §10.3 (chain artifact) — flag:** the V1 probe (Step 1) came back
**negative for the approved artifact and positive for a native mechanism**. omp's
`retry.fallbackChains` is keyed by **model role**, not model slug (settings schema:
"JSON object mapping model roles to ordered fallback model selectors"; the binary's config
validation: "retry.fallbackChains must be a mapping of role names to selector arrays") — a
slug-keyed record in `<repo>/.omp/config.yml` would never be consulted (dead config). But
omp's subagent launcher natively enacts ordered model lists: an agent-def `model:` accepts a
**comma-separated selector list** (binary: `ae0(q ?? j.model)` splits comma-string/array);
the first auth-usable entry becomes the session model and the remainder is installed
in-memory as `retry.fallbackChains["subagent:<id>"]` (`se0`/`re0` via
`modelPatternFallbackRole`) — per-tier, project-scoped, self-reverting, and selectors carry
`slug:thinkingLevel` so per-entry effort rides along (upgrades spec §4.2's "chain swaps
model only"). Enactment therefore lands **inside the already gitignored tier defs**:
`model: "primary,fb1:low,fb2"`. The config.yml merge/refusal/dedupe/conflict/gitignore
machinery of the original Steps 2-4 is dead weight and is dropped; the component's GOAL
(entries 1..n = real runtime fallback, never a broken write) is met with zero new artifacts.

- [x] **Step 1 (V1 probe):** done 2026-07-10 — result recorded in the deviation flag above
      (evidence: `omp config get retry.fallbackChains --json` schema description;
      `omp://settings.md`; omp 16.4.1 binary — chain validation is role-keyed, subagent
      `model` pattern list installs the per-spawn chain).
- [x] **Step 2 (red):** generator tests — multi-entry tier renders a comma-joined `model:`
      pattern (object entries with valid effort → `slug:effort` selector, without → bare
      slug); invalid fallback effort → warn + bare slug; unsafe/malformed fallback entry
      dropped loudly while safe siblings survive; entry-0-invalid still unsets the whole
      tier (fallbacks are never promoted); multi-entry idempotency; no `.omp/config.yml`
      is ever written.
- [x] **Step 3:** `gen-omp-agents.sh` `render_tier`: build the fallback selector suffix
      from entries 1..n (reuse `safe_slug`/`valid_effort`); emit
      `model: "<primary>[,<selector>...]"`; primary rendering byte-identical for
      string/object/single-entry leaves.
- [x] **Step 4:** doctor: no new check — `omp-agents.sh` drift regenerates via the same
      authority so chain edits surface as `omp-agents-drift`; `models-leaf-shape.sh`
      (Inc 1) already validates entry shapes. Non-omp enactment posture is Inc 3 docs.
- [x] **Step 5 (green):** suite green (gen-omp-agents 60/0; init runner 9 suites 0 failed;
      resolver suites 19/0 + 33/0); string/object/unset/single-entry-array fixtures
      byte-identical vs the HEAD generator (no-op proof for non-fallback configs).
- [x] **Step 6:** commit; task-scoped review; distill.

## Increment 3 — docs + site sync + closeout (PR 3)

**Deliverable:** taxonomy documented; site builds; plan closes. AC5, AC7.

- [ ] **Step 1 (red):** grep — array-form absent from `model-tiers.md` leaf paragraph,
      `hosts/*.md` fallback sections, `configuration.mdx`,
      `woostack-review/SKILL.md` (`models` key reference), and the review prompt
      leaf mentions (`_orchestrator-header.md`, `anthropic.md`, `openai.md`,
      `opencode.md` jq override examples).
- [ ] **Step 2:** `model-tiers.md` leaf-shape paragraph (array form + entry-0 law +
      per-host enactment pointer); one entries-1..n sentence in each of the six
      `hosts/*.md` "Host-level fallback" sections; `configuration.mdx` array example
      (MDX escaping per memory `authored-mdx-escapes-jsx-and-table-pipes`);
      `woostack-review/SKILL.md` leaf line + prompt jq examples gain the array
      branch (per review-tier-doc-sync fanout set).
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
| AC4 | def `model:` pattern tests + multi-entry idempotency + no-config.yml-write assertion (Inc 2) |
| AC5 | hosts/*.md sentences + `test-host-references.sh` green (Inc 3) |
| AC6 | prompts/ diff-clean + marker assertion (Inc 1 Step 5, Inc 3 Step 3) |
| AC7 | site build green (Inc 3 Step 3) |

## Rollback

Graphite stack on `feature/tier-fallback` (parented on the host-references stack);
revert = drop the PR. Increment 1 is behavior-preserving normalization; Increment 2 only
rewrites the already gitignored generated defs (no host-config file is written); Increment 3
is docs-only.

---

_Hardened 2026-07-10 — decomposition verified (3 PR-sized increments; Inc 1 behavior-preserving with fixture byte-diff proof; Inc 2 probe-gated with defined degraded branch and refusal-not-corruption law; Inc 3 docs-only). Test-first per increment; resolver test homes verified (`test-resolve-model.sh`, `test-load-prompt-models.sh`, `test-gen-omp-agents.sh`). Both review resolution paths move through the single sourced authority. No open branches._
