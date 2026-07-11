---
type: plan
source: .woostack/specs/2026-07-10-host-references.md
status: executing
date: 2026-07-10
branch: feature/host-references
links:
  - "[[2026-07-10-host-references]]"
---
**Source:** [[specs/2026-07-10-host-references]]

# Centralized host references - Implementation Plan

**Goal:** move every host-specific instruction (Claude Code / Codex / Cursor / Antigravity /
opencode / omp) into one per-host home - `skills/using-woostack/references/hosts/<host>.md` -
loaded only when a skill runs under that host. Consuming skills keep their generic invariants
inline plus one canonical, grep-stable load directive; `model-tiers.md` keeps only the
provider/tier layer. Full extraction per approved spec (§2); no behavior change (§3).

## Architecture

```
consuming skill (execute / review-local / commit / init / overnight)
  inline: invariants + capability questions + canonical load directive
        |
        v
skills/using-woostack/references/hosts/<current-host>.md    (one file, on demand)
  §1 Detection  §2 Subagent spawn  §3 Tier routing
  §4 Host-level fallback  §5 Per-skill notes  §6 Degradation
        |
        +-- absent -> no-per-call-routing degradation + say so (law inline in skill)

model-tiers.md = provider table + effort semantics + precedence + pointer to hosts/
review CI path = untouched (self-contained prompts; load-prompt.sh / resolve-model.sh diff-clean)
```

## Increment order & dependencies

Linear Graphite stack on `feature/host-references` (parent: `fix/omp-host-fallback-docs`,
PR #475 - this feature relocates content #475 introduced). Three increments; the structural
test swaps in the same increment as the extraction because `test-omp-lockstep.sh` pins
phrases that move (an increment may never land red).

1. **hosts/ home** - README contract + six host files (content copied from current sites;
   sources untouched, so the old lockstep test stays green). Transient duplication is
   intentional and completes in Increment 2 - mark with `woostack-defer(increment-2)`.
2. **Extraction + site sync** - six consumer sites shrink to law + canonical directive;
   `test-host-references.sh` replaces `test-omp-lockstep.sh`; memory scope + `MEMORY.md` and
   the authored `configuration.mdx` taxonomy update ride in the same increment.
3. **Closeout** - re-run the structural test and site build against the integrated change;
   close the plan without repairing documentation drift from an earlier increment.

## Canonical load directive (single authoring form)

One physical ASCII line, identical wherever it appears (grep-assertable, memory
`grep-assertion-single-physical-line`):

`**Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load \`skills/using-woostack/references/hosts/<current-host>.md\`; no matching file -> treat the host as having no per-call routing and say so (degraded).`

## Testing note (this repo)

No app harness. "Failing test first" = a concrete command with stated expected output.
Shell tests use `skills/woostack-init/scripts/tests/assert.sh` idioms; grep tokens ASCII.

---

## Increment 1 - hosts/ home (PR 1)

**Deliverable:** `skills/using-woostack/references/hosts/` with `README.md` +
`{claude-code,codex,cursor,antigravity,opencode,omp}.md`, each carrying the six contract
sections (spec §2). Content authored by **moving text semantically** from the seven donor
sites (spec §1) - sources edited in Increment 2.

- [x] **Step 1 (red):** `ls skills/using-woostack/references/hosts/ 2>&1` -> no such
      directory; `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh` -> passes
      (baseline stays green through this increment).
- [x] **Step 2:** write `hosts/README.md` - the six-section contract, one paragraph on the
      load directive + degradation default, and the rule that host files hold *mechanics*
      while consuming skills hold *law*.
- [x] **Step 3:** write the six host files from donor content:
      - `omp.md` - agent-by-tier dispatch (`agent: woostack-<effective-tier>`), generated defs
        + `gen-omp-agents.sh` ensure-then-select (from `subagent-driver.md:136-137`,
        `model-tiers.md:35`), host-level fallback + woostack boundary (from
        `model-tiers.md:38-39`), per-skill notes: init scaffold step mechanics
        (`woostack-init/SKILL.md:61-63`), commit fast-draft (`woostack-commit/SKILL.md:54-58`),
        review local row incl. `agent: woostack-deep` validator (`woostack-review/SKILL.md:338`),
        overnight usage-exhaustion advisory (`woostack-execute-overnight/SKILL.md:72-75`).
        **New (revision 2026-07-10):** §4 additionally narrates the tier-pin/fallback
        interaction - the tier def picks the subagent session's *starting* model; omp's
        usage-limit ladder (credential rotation -> temporary `retry.fallbackChains` switch,
        announced + cooldown-reverted -> informed waiting -> loud failure) may override it
        mid-task as host-owned recovery; cooldown state is store-level so sibling spawns
        fall over at spawn time. §5 (review) adds the worker-exhaustion interplay: a
        recovered worker finishes on the fallback model (receipt `model` = configured slug,
        transcript = concrete model); an unrecovered worker never writes its receipt, so
        review's receipt gate hard-fails the run - no silently thinner review. 3-5
        sentences total; the gate law itself stays inline in review's SKILL.md.
      - `claude-code.md` - `Task` tool, per-call model+effort+cwd, `general-purpose` worker
        profile (from `model-tiers.md:27-32`, `subagent-driver.md` capability cases,
        `woostack-review/SKILL.md:332,334`).
      - `codex.md` - local subagents with `model` override (per-call bucket) **and** the
        Codex-Action single-session collapse (`woostack-review/SKILL.md:411`).
      - `cursor.md` - parallel subagent dispatch, host-scheduled (`woostack-review/SKILL.md:335`).
      - `antigravity.md` - single-session pin + dynamically orchestrated isolated subagents
        (`woostack-review/SKILL.md:336,411`).
      - `opencode.md` - `@subagent` per-call routing + `N=1` cap note
        (`model-tiers.md:27-32`, `woostack-review/SKILL.md:337`).
      Each file: `<!-- woostack-defer(increment-2): donor sites still carry this text until the extraction increment -->`.
- [x] **Step 4 (green):** `for f in skills/using-woostack/references/hosts/*.md; do ...` grep
      each non-README file for the six headers `## Detection`, `## Subagent spawn`,
      `## Tier routing`, `## Host-level fallback`, `## Per-skill notes`, `## Degradation` ->
      6 files x 6 headers, zero misses; lockstep test still green.
- [x] **Step 5:** commit via woostack-commit conventions; PR body Spec trailer ->
      `.woostack/specs/2026-07-10-host-references.md`. Task-scoped quality review (inline
      bounded); distill memory only if a durable non-obvious rule emerged.

## Increment 2 - extraction + directive + test swap (PR 2)

**Deliverable:** the six consumer sites carry law + directive only; mechanics exist solely
in `hosts/`; structural test renamed and extended; memory scope and authored site taxonomy
updated in the same change. AC2-AC6.

- [ ] **Step 1 (red):** canonical-directive grep across the six consumers -> 0 matches;
      `grep -c "agent-by-tier" skills/using-woostack/references/model-tiers.md` -> >=1
      (mechanics still in donor).
- [ ] **Step 2:** `model-tiers.md` - replace the three host buckets + omp fallback note
      (lines ~25-39) with one capability-class definition paragraph (per-call /
      single-session / agent-by-tier) + the canonical directive + pointer line. Provider
      table, provider notes, effort semantics, override precedence untouched (AC4;
      CI-inline blob keeps the table byte-stable).
- [ ] **Step 3:** `subagent-driver.md` - capability cases and dispatch law stay; omp
      paragraph (136-137) + host-fallback clause (139-140) -> canonical directive + one line
      per capability question. Inline say-so/degradation law untouched (AC3).
- [ ] **Step 4:** `woostack-review/SKILL.md` Stage 3 - five host rows (334-338) -> worker-
      profile law (328-332 stays) + canonical directive for local hosts. Host-capability
      buckets (410-411) -> directive + retained CI/single-session sentence (the
      `FORCE_TIER`/run-tier law at 411-413 is CI-load-bearing - keep the text that the CI
      blob needs; only local per-host rows leave). `prompts/*.md`, `load-prompt.sh`,
      `resolve-model.sh` diff-clean (AC5).
- [ ] **Step 5:** `woostack-commit/SKILL.md` (54-58) - keep fast-draft tier law + directive;
      omp agent mechanics leave. `woostack-init/SKILL.md` (61-63) - keep one-line "under omp,
      run the generator" step + pointer. `woostack-execute-overnight/SKILL.md` (72-75) -
      advisory becomes host-generic ("check the current host's fallback posture -
      `hosts/<host>.md` §Host-level fallback"); omp specifics already in `hosts/omp.md` §5.
      Remove the `woostack-defer(increment-2)` markers from `hosts/*.md`.
- [ ] **Step 6:** replace `skills/woostack-init/scripts/tests/test-omp-lockstep.sh` with
      `test-host-references.sh`: (a) assert the exact six required host filenames exist,
      then loop `hosts/*.md` (exclude README) -> six section headers each; (b) canonical
      directive present in the five consumer files + `model-tiers.md`; (c) provider-table
      header row + `<!-- WOO_MODEL_TIERS_TABLE -->` marker still resolve (reuse the existing
      load-prompt.sh literal-inline assertion); (d) moved-phrase greps:
      `agent-by-tier`/`Host-level fallback`/`usage-exhaustion resilience` and the omp
      generator invocation present in `hosts/omp.md`, with relocated mechanics absent from
      `model-tiers.md`, `subagent-driver.md`, `woostack-review/SKILL.md`,
      `woostack-commit/SKILL.md`, and `woostack-execute-overnight/SKILL.md`; assert
      `woostack-init/SKILL.md` retains only its intentional one-line generator step
      (anti-duplication, AC2).
- [ ] **Step 7:** memory riders - `omp-host-fallback-is-host-owned.md` scope gains
      `skills/using-woostack/references/hosts/**`; verify
      `review-host-distinct-from-model-provider` scope paths still exist; rebuild `MEMORY.md`
      (`build-index.sh`).
- [ ] **Step 8 (red):** `grep -c "hosts/" site/content/docs/configuration.mdx` -> 0.
- [ ] **Step 9:** update `configuration.mdx` - the omp example section (~155-172) keeps the
      config semantics but points host mechanics at the `hosts/` contract; MDX escaping per
      memory `authored-mdx-escapes-jsx-and-table-pipes`. `concepts.mdx` untouched (spec §9 Q1).
- [ ] **Step 10 (green):** `bash skills/woostack-init/scripts/tests/test-host-references.sh`
      -> PASS; real `pnpm -C site install --frozen-lockfile --prefer-offline` in the worktree then `pnpm -C site build` -> green
      (memory `site-build-in-worktree-needs-real-node-modules`); `git diff --stat` shows no
      `woostack-review/scripts/` or `woostack-review/prompts/` changes; walkthrough
      narrative: unknown host resolves to no-per-call-routing + say-so from inline text
      alone (AC3 edge).
- [ ] **Step 11:** commit (same PR-body conventions); task-scoped quality review; distill.

## Increment 3 - integrated closeout (PR 3)

**Deliverable:** verify the already-synchronized taxonomy in the integrated stack and close
the plan. This increment must not repair authored-site drift left by Increment 2.

- [ ] **Step 1:** verify `configuration.mdx` already points host mechanics at the `hosts/`
      contract and `concepts.mdx` remains untouched.
- [ ] **Step 2:** re-run `test-host-references.sh` and `pnpm -C site build` against the
      integrated stack; both remain green.
- [ ] **Step 3:** commit the closeout; final task-scoped review; distill durable memory; set
      plan `status: done` (terminal transition authored by execute, conventions.md).

## Verification map (AC -> proof)

| AC | Proof |
|---|---|
| AC1 | test (a): 6 files x 6 headers, loop not hardcoded list |
| AC2 | test (d): phrases in `hosts/omp.md`, absent from donors |
| AC3 | test (b) directive greps + unknown-host walkthrough (Inc 2 Step 10) |
| AC4 | test (c): table row + inline marker stable |
| AC5 | `git diff --stat` clean on review scripts/prompts (Inc 2 Step 10) |
| AC6 | configuration sync + site build green in Inc 2 Steps 9-10; closeout re-verifies both |

## Rollback

Each increment is one PR on a Graphite stack; revert = drop the PR. Increment 1 is purely
additive; Increment 2 is the only one touching load-bearing skill text and carries its test
swap plus authored-site sync in the same change; Increment 3 is integrated closeout only.

---

_Hardened 2026-07-10 - decomposition verified (3 PR-sized increments, test swap co-lands with extraction so no increment lands red); defer-marker lifecycle add(1)/remove(2); CI-load-bearing FORCE_TIER text retained in review SKILL; test (c) inherits the existing WOO_MODEL_TIERS_TABLE single-occurrence assertion. No open branches._
