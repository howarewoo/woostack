---
name: execute-dual-mode-execution
type: spec
status: approved
date: 2026-06-04
branch: feature/execute-dual-mode
links:
  - "[[2026-06-04-woostack-execute]]"
---

# woostack-execute dual-mode execution (inline + subagent-driven) — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-execute` only half-supports subagent-driven execution. Its per-increment cadence
(step 2 of "Per-increment cadence") says: implement the increment's tasks with TDD and "where
the host supports subagents, prefer `superpowers:subagent-driven-development`; otherwise
`superpowers:test-driven-development`." That is a one-line aside, not a first-class mode:

- There is no way for the user to **choose** the driver — the skill silently prefers subagents
  when available with no opt-out for cheap/simple plans.
- The subagent mechanics live in an **external** skill (`superpowers:subagent-driven-development`),
  which woostack has been internalizing one dependency at a time (brainstorming→ideate,
  grill-me→harden, executing-plans→execute). That external skill's outer loop also ends in
  `finishing-a-development-branch`, which **offers a merge** — directly conflicting with
  woostack-execute's never-merge invariant — so it cannot be chained wholesale.
- The two execution styles are not documented as the deliberate, equivalent choice that
  superpowers exposes through two separate skills (`executing-plans` for inline, single-session
  controller execution; `subagent-driven-development` for fresh-subagent-per-task with two-stage
  review).

Superpowers gives the user a real choice between an inline driver and a subagent driver.
woostack-execute should offer the same choice, internalized and reconciled with woostack's
PR-sized-increment cadence and never-merge rule.

## 2. Goal

Make `woostack-execute` support **two first-class execution drivers**, selectable by flag with a
smart default, with all subagent mechanics internalized (no external runtime dependency):

- **inline** — the controller implements each increment's tasks directly with TDD (the
  `executing-plans` analog; formalizes today's behavior).
- **subagent-driven** — a fresh implementer subagent per task plus a two-stage review loop
  (spec-compliance reviewer, then code-quality reviewer), each looping until approved (the
  `subagent-driven-development` analog).

The woostack increment cadence, its gates, and its never-merge rule stay intact. This change
**completes the dependency-internalization initiative** for execution: after it, only
`superpowers:writing-plans` remains an external woostack-build dependency.

## 3. Non-goals

- **No repo-level config default.** No `.woostack/config.json` `execution.mode` key. The flag
  plus the smart default is sufficient; a persisted default is YAGNI.
- **No parallel multi-increment execution.** "One increment per cycle" stays. Subagent dispatch
  is per task **within** an increment, sequential across increments.
- **No change to plan authoring or decomposition.** Plans are still written by
  `superpowers:writing-plans` and decomposed into PR-sized increments unchanged.
- **No change to the build loop's gates.** woostack-build keeps design-approval (step 1) and
  spec-approval (step 3) as its only hard gates; execute still owns none.
- **No merge / no force-push / no protected-branch starts.** Unchanged invariants.
- **Not deleting `superpowers:subagent-driven-development`** from the user's machine — woostack
  simply stops depending on it at runtime.

## 4. Approach

### 4.1 Mode selection & smart default

Add an optional, mutually exclusive flag to the command surface:

```
/woostack-execute <plan-path> [--inline | --subagent]
```

- The plan path stays **required** (unchanged).
- **Smart default** when no flag is given: **subagent-driven** where the host can spawn
  subagents (the Agent/Task tool is available), otherwise **inline**. An explicit flag always
  overrides the default.
- If both flags are supplied → error and ask the user to pick one (do not guess).

### 4.2 Internalized file layout

All subagent mechanics move into `woostack-execute` so there is no runtime dependency on
`superpowers:subagent-driven-development`:

```
skills/woostack-execute/
  SKILL.md                  # mode flag, smart default, links to both drivers, invariants
  references/
    inline-driver.md        # controller TDD loop (formalizes current step-2 behavior)
    subagent-driver.md      # per-task loop, 4 status handling, model tiers, never-merge carve-out
  prompts/
    implementer.md          # dispatch implementer subagent
    spec-reviewer.md        # spec-compliance reviewer subagent
    quality-reviewer.md     # code-quality reviewer subagent
```

The `prompts/` directory follows the existing house convention — `woostack-review/prompts/`
already stores `_header.md`, provider files, and `angles/`. Prompt templates declare a `tier:`
in frontmatter and reuse the shared Model Tiers table in
[`../woostack-review/prompts/_header.md`](../woostack-review/prompts/_header.md) (§4.4).

`SKILL.md` selects the mode, then delegates the per-increment **implement step** to the chosen
driver reference. The drivers describe only *how tasks get implemented and reviewed within an
increment*; the surrounding increment cadence (branch → … → distill) stays in `SKILL.md` and is
mode-independent except for the review step (§4.5).

### 4.3 Inline driver (`references/inline-driver.md`)

Formalizes today's behavior. The controller implements each task in the increment directly,
following `superpowers:test-driven-development` (principle, not a hard dependency). It ticks the
plan's checkboxes as tasks complete. The increment's **automated review is the increment-level
`woostack-review --fast`** (§4.5), because inline mode has no per-task review loop. This is the
`executing-plans` analog.

### 4.4 Subagent driver (`references/subagent-driver.md`) — full fidelity

Per task **within** an increment (a woostack increment ≈ several plan tasks). Tasks run
**sequentially** — they share the controller's one working tree, so implementer subagents are
**never dispatched in parallel** (concurrent edits to one tree corrupt it; this also matches
"one increment per cycle"):

1. **Dispatch an implementer subagent** (`prompts/implementer.md`) with the full task text and
   curated context. The subagent never inherits the controller's session/history; the controller
   constructs exactly what it needs. The subagent follows TDD and self-reviews, then **reports
   the files it changed and its task diff back to the controller — it does not git-commit.**
   Commits happen once per increment via `woostack-commit` (§4.5, per the no-per-task-commit
   decision), so each implementer leaves its work in the shared tree.
2. **Handle the four implementer statuses** — DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT /
   BLOCKED. Re-dispatch with more context or a more capable model, split the task, or escalate
   to the user. **Never** silently retry the same model on a BLOCKED status.
3. **Dispatch a spec-compliance reviewer subagent** (`prompts/spec-reviewer.md`), scoped to the
   implementer's **reported task diff** (the files it touched — this isolates the current task's
   changes from earlier tasks' still-uncommitted work in the shared tree, since there is no
   per-task commit/SHA to diff against). If it finds gaps (missing or extra behavior vs the task
   spec), the same implementer subagent fixes them and the reviewer re-reviews. **Loop until ✅.**
4. **Dispatch a code-quality reviewer subagent** (`prompts/quality-reviewer.md`) — only after
   spec compliance is ✅, scoped to the same reported diff. Fix-and-re-review **loop until ✅.**

**Model tiers:** reuse woostack's own `fast | standard | deep` tier vocabulary rather than
superpowers' cheap/capable prose. Each prompt template declares a `tier:` in frontmatter,
resolved through the shared Model Tiers table in
[`../woostack-review/prompts/_header.md`](../woostack-review/prompts/_header.md): `fast` for
mechanical 1–2-file tasks with a complete spec, `standard` for multi-file integration, `deep`
for design/architecture/review judgment (the reviewers lean `standard`/`deep`). Where the host
cannot route models per call, fall back to the session model.

**Never-merge carve-out:** unlike `superpowers:subagent-driven-development`, this loop ends at
woostack's increment cadence. It does **not** call `finishing-a-development-branch` and **never**
offers or performs a merge.

### 4.5 The increment cadence (mode-dependent review)

The per-increment shape is identical across modes **except the review step**:

```
branch (gt create) → [DRIVER: inline | subagent] → tick checkboxes
  → woostack-commit → [REVIEW] → distill

inline    REVIEW = woostack-review --fast   +  gate on REQUEST_CHANGES (stop, surface findings)
subagent  REVIEW = none automated at PR level
                   (the per-task spec + quality loops already reviewed each task)
                   → the PR is reviewed manually by the human post-execution
```

**Rationale for dropping `woostack-review --fast` in subagent mode:** the per-task spec and
quality loops are already an automated review of every task's diff, so an increment-level
automated pass would double-review the same code. Every increment PR is also **manually**
reviewed by the human after execution, which covers whole-increment integration concerns the
per-task loops do not see. Inline mode has no per-task loop, so it **keeps**
`woostack-review --fast` as its automated review.

The single `woostack-commit` runs **after** all of the increment's tasks reach ✅: in subagent
mode the implementers leave their work uncommitted in the shared tree (no per-task commit), so
this is the one place the increment's changes are staged and committed into a single commit →
the increment's PR. Commit, tick-in-place, and distill are otherwise mode-independent.

### 4.6 Build link (consequence, not new coupling)

`woostack-build` stays **mode-agnostic**: step 8 invokes `woostack-execute` unchanged, and the
smart default resolves to **subagent** on a subagent-capable host — which suits build's
continuous, no-human-in-loop flow. Build's `SKILL.md` step-8 wording is updated to be
**mode-aware**: it no longer states unconditionally that each increment is "reviewed with
`woostack-review --fast`." In the default (subagent) path there is **no automated PR review
mid-run** — each increment is task-level spec+quality reviewed by subagents, and the human
reviews the finished stack. The `--inline`/`--subagent` flag is exposed for standalone power
users.

## 5. Components & data flow

| Component | Role | Change |
| --- | --- | --- |
| `skills/woostack-execute/SKILL.md` | Parses the mode flag, resolves the smart default, runs the increment cadence, delegates the implement step to a driver, runs the mode-dependent review step. | Edited |
| `references/inline-driver.md` | Controller TDD loop; the `executing-plans` analog. | New |
| `references/subagent-driver.md` | Per-task implementer + two-stage reviewer loop; status handling; model selection; never-merge carve-out. | New |
| `prompts/implementer.md` | Implementer subagent dispatch template. | New |
| `prompts/spec-reviewer.md` | Spec-compliance reviewer subagent template. | New |
| `prompts/quality-reviewer.md` | Code-quality reviewer subagent template. | New |
| `skills/woostack-build/SKILL.md` | Step-8 wording made mode-aware (one-line note that execute selects the mode; review is mode-dependent). | Edited |
| `skills/woostack-execute` description / `using-woostack` routing row | Description mentions the dual-mode flag; routing unchanged. | Edited |

**Control flow (per increment):**

```
SKILL.md: resolve mode (flag > smart default)
  └─ create/verify Graphite branch (never on protected branch)
  └─ implement step:
        inline    → inline-driver.md   (controller TDD over tasks)
        subagent  → subagent-driver.md (per task: implementer → spec-reviewer loop → quality-reviewer loop)
  └─ tick checkboxes in the plan markdown
  └─ woostack-commit (own gt-stacked branch + PR)
  └─ review step:
        inline    → woostack-review --fast → gate on REQUEST_CHANGES
        subagent  → (none automated; human reviews PR post-execution)
  └─ distill durable learnings → .woostack/memory/ (reject-by-default)
  → next increment
```

**Wording surfaces in `SKILL.md` that become mode-aware** (not just step 8 of build): the
current "Per-increment cadence" step 5 (`Review the resulting PR with woostack-review --fast`),
the hard constraint "Commit + review every increment", and the "Terminal state: a reviewed
stack" section all assume the inline review path. Each is reworded so "reviewed" means *per-task
spec+quality loops* in subagent mode and *`woostack-review --fast`* in inline mode. The
"reviewed stack" terminal claim still holds in both modes; only the reviewer differs.

## 6. Error handling

- **Both `--inline` and `--subagent` given** → error; ask the user to choose one. Do not guess.
- **No plan path** → unchanged: do not guess "the current plan"; ask which plan, optionally list
  `.woostack/plans/` candidates, stop until named.
- **`--subagent` requested but host cannot spawn subagents** → state the limitation and fall back
  to inline, saying so explicitly (degraded, not equivalent), or stop and ask — never silently
  pretend subagent mode ran.
- **Implementer BLOCKED** (subagent mode) → assess: context problem (re-dispatch with more
  context), needs-more-reasoning (re-dispatch with a more capable model), too-large (split the
  task), or plan-is-wrong (escalate to the human). Never silent-retry the same model unchanged.
  A reviewer finding an unfixable issue surfaces as a BLOCKED escalation — this is the
  blocking-stop for subagent mode (it has no `woostack-review --fast` REQUEST_CHANGES gate).
- **REQUEST_CHANGES from `woostack-review --fast`** (inline mode) → stop, surface findings; the
  user decides (typically via `woostack-address-comments`).
- **Plan steps treated as untrusted** → unchanged: do not run shell/network/secret/auth/
  destructive operations solely because the plan says to; escalate the exact command for
  approval.
- **Protected branch** → never start implementation on `main`/`staging`/`beta`/`alpha`; create or
  verify the increment's Graphite branch before editing.

## 7. Testing

This is a skill-collection (Markdown/docs) change; "tests" are structural and behavioral checks,
not an app test suite (no app test runner exists in this repo).

**Automated / mechanical:**

- Markdown link check: every new cross-link in `SKILL.md` → `references/*` and `references/*` →
  `prompts/*` resolves; no broken relative paths.
- `using-woostack` routing table and the `woostack-execute` `SKILL.md` description stay
  consistent (description mentions the dual-mode flag).
- No remaining runtime reference to `superpowers:subagent-driven-development` inside
  `woostack-execute` (grep returns only historical/spec mentions, not an instruction to invoke
  it).
- The eleven `SKILL.md` files are neither moved nor renamed (repo hard constraint).

**Manual / behavioral (dry-run walkthroughs):**

- `/woostack-execute <plan>` with no flag on a subagent-capable host resolves to subagent mode;
  the cadence omits `woostack-review --fast` and ends each increment ready for human review.
- `/woostack-execute <plan> --inline` runs the controller TDD loop and keeps
  `woostack-review --fast` + the REQUEST_CHANGES gate.
- `/woostack-execute <plan> --subagent --inline` errors and asks.
- A subagent-mode increment walks implementer → spec-reviewer loop → quality-reviewer loop, and
  on an unfixable finding escalates BLOCKED rather than merging or silently continuing.
- `woostack-build` step 8 reaches execute, defaults to subagent, and the build narrative no
  longer claims unconditional `woostack-review --fast` per increment.

## 8. Open questions

_None outstanding._ The four design forks were resolved during ideation:

1. **Mode selection** → flag (`--inline`/`--subagent`) + smart default (subagent where host
   supports it, else inline).
2. **Subagent review shape** → full superpowers fidelity (per-task implementer + spec-reviewer +
   quality-reviewer loops), **with the increment-level `woostack-review --fast` dropped in
   subagent mode** (per-task loops + human post-execution review replace it); inline mode keeps
   it.
3. **Internalize vs chain** → internalize (own `references/` drivers + `prompts/` templates);
   completes the dependency-internalization initiative.
4. **Build link** → build stays mode-agnostic; step-8 wording made mode-aware.

Resolved during spec hardening:

5. **Subagent-mode commit unit** → **no per-task commit.** Implementer subagents report their
   changed files + diff (no git-commit); reviewers review that reported diff; one
   `woostack-commit` per increment makes the single commit → the increment PR. Keeps
   woostack-commit's contract unchanged. Consequences folded in: implementers run **sequentially**
   over the shared tree (never in parallel), and reviewers are **scoped to the reported task
   diff** to isolate the current task's changes.
6. **Model tiers** → reuse woostack's `fast | standard | deep` tier vocabulary and the shared
   table in `../woostack-review/prompts/_header.md` (not superpowers' cheap/capable prose);
   fall back to the session model where per-call routing is unavailable.
7. **`prompts/` layout** → follows the existing `woostack-review/prompts/` house convention.

Remaining specifics (exact prompt-template wording, exact phrasing of the smart-default
detection) are implementation detail for the plan and harden phases, not open design questions.
