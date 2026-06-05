**Source:** .woostack/specs/2026-06-05-woostack-plan.md

# woostack-plan Implementation Plan

**Goal:** Ship `woostack-plan` — the eleventh public woostack command — internalizing `superpowers:writing-plans` as the build loop's first-party plan phase, and rewire `woostack-build` (dropping its now-empty dependency preflight) plus all count/routing surfaces.

**Architecture:** Two stacked PRs. Increment 1 adds the standalone skill (`skills/woostack-plan/SKILL.md` + `references/plan-template.md`) — complete and usable on its own, referenced by nothing yet. Increment 2 wires it into `woostack-build` step 4, removes the dependency-preflight section (writing-plans was the only external dep), updates the status script + its test, and bumps the command-surface counts and routing across AGENTS.md, README, CONTRIBUTING, and using-woostack.

**Tech Stack:** Markdown skill files; `bash` + `jq` for the status engine; `grep`/`bash -n` and the existing `skills/woostack-status/scripts/tests/test-status.sh` for verification (this repo is a skills collection — no app test runner).

---

> **Verification model:** This repo has no app test runner. "Write the failing test" therefore means: write/adjust a concrete verification command (a `grep`, a `bash -n`, or the real `test-status.sh` assertion) and confirm it fails before the change, passes after. The one genuinely executable test is `test-status.sh`; the rest are inspection commands with exact expected output.
>
> **Edits are content-matched, not line-matched.** Line numbers in the tasks are navigational hints against the pre-change files; apply each edit by matching the exact `old → new` block shown (the deletions in Task 3 shift later line numbers, but the find/replace text stays authoritative).
>
> **Cadence:** each Increment is one Graphite-stacked branch → one PR. The first commit of an Increment uses `gt create` (cuts its branch, stacked on the prior Increment); later commits within the same Increment use `gt modify -c`. `woostack-execute` drives this via `woostack-commit`; the explicit `gt` lines below are the intended commit boundaries.

---

## Increment 1: Add the woostack-plan skill (standalone)

> One independently shippable PR. Adds a complete, usable skill that nothing references yet — harmless to ship alone. Its own Graphite-stacked branch.

### Task 1: Create the plan-template skeleton

**Files:**
- Create: `skills/woostack-plan/references/plan-template.md`

- [x] **Step 1: Write the failing check**

The file must not exist yet, and once created must be frontmatter-free, open with the `**Source:**` line, and carry no `REQUIRED SUB-SKILL` banner.

Run: `test ! -e skills/woostack-plan/references/plan-template.md && echo MISSING`
Expected: `MISSING`

- [x] **Step 2: Create the file**

Create `skills/woostack-plan/references/plan-template.md` with exactly this content:

````markdown
**Source:** .woostack/specs/{{SPEC_BASENAME}}.md

# {{FEATURE_NAME}} Implementation Plan

**Goal:** {{ONE_SENTENCE_WHAT_THIS_BUILDS}}

**Architecture:** {{TWO_OR_THREE_SENTENCES_ON_THE_APPROACH}}

**Tech Stack:** {{KEY_TECHNOLOGIES}}

---

## Increment 1: {{PR_SIZED_SLICE_NAME}}

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch.

### Task 1: {{COMPONENT_NAME}}

**Files:**
- Create: `{{exact/path/to/new.ext}}`
- Modify: `{{exact/path/to/existing.ext}}:{{LINES}}`
- Test: `{{exact/path/to/test.ext}}`

- [ ] **Step 1: Write the failing test**

```{{lang}}
{{actual test code — never a placeholder}}
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `{{exact command}}`
Expected: FAIL — `{{exact expected failure}}`

- [ ] **Step 3: Minimal implementation**

```{{lang}}
{{actual implementation code}}
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `{{exact command}}`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
gt create -m "{{type}}: {{subject}}"
```

<!-- Repeat Task N for each unit in this increment. Add Increment 2, 3, … for each PR-sized slice. -->

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above.
- [ ] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
- [ ] **Type consistency** — types, signatures, and names match across tasks.

> woostack plan conventions (keep them):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/<spec-basename>.md` (the spec's date, not today's).
> - **No** `REQUIRED SUB-SKILL` banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - In a target without a test runner, a "failing test" step is a concrete verification command (grep, `bash -n`, an existing test) with exact expected output.
````

- [x] **Step 3: Run the check, confirm it passes**

Run: `head -1 skills/woostack-plan/references/plan-template.md; grep -c 'REQUIRED SUB-SKILL' skills/woostack-plan/references/plan-template.md`
Expected: first line is `**Source:** .woostack/specs/{{SPEC_BASENAME}}.md`, and the grep count is `0`.

- [x] **Step 4: Commit**

```bash
gt create -m "feat(woostack-plan): add plan-template skeleton"
```

### Task 2: Create the woostack-plan SKILL.md

**Files:**
- Create: `skills/woostack-plan/SKILL.md`

- [x] **Step 1: Write the failing check**

Run: `test ! -e skills/woostack-plan/SKILL.md && echo MISSING`
Expected: `MISSING`

- [x] **Step 2: Create the file**

Create `skills/woostack-plan/SKILL.md` with exactly this content:

````markdown
---
name: woostack-plan
description: Use to write the implementation plan for an approved woostack spec — a comprehensive, bite-sized TDD plan structured as PR-sized increments, saved frontmatter-free to .woostack/plans/<spec-basename>.md, opening with a **Source: line that joins it 1:1 to the spec, and setting the spec's status: planning. This is the plan phase of the woostack build loop (woostack-build step 4); also usable standalone via /woostack-plan <spec-path>. One plan per spec. Writes the plan and hands back — never executes, commits, or merges.
---

# woostack-plan

Write a comprehensive implementation plan from one approved spec, structured as PR-sized
increments. This is woostack's own planning phase — [`woostack-build`](../woostack-build/SKILL.md)
step 4. It keeps the discipline that makes plans worth executing (file-structure first,
bite-sized TDD tasks, no placeholders, a self-review pass) and adds the woostack conventions:
markdown plans under `.woostack/plans/`, an opening `**Source:**` line that joins the plan 1:1 to
its spec, frontmatter-free, decomposed into independently shippable increments, and a
`status: planning` transition on the spec. It writes the plan and hands back; it owns no approval
gate and never executes, commits, or merges.

It internalizes `superpowers:writing-plans` — the same move
[`woostack-ideate`](../woostack-ideate/SKILL.md),
[`woostack-harden`](../woostack-harden/SKILL.md), and
[`woostack-execute`](../woostack-execute/SKILL.md) made on the phases around it. With this skill
the build loop has **no external skill dependencies**. It pairs with `woostack-execute` as
produce-plan / consume-plan: `/woostack-plan <spec>` writes the plan, `/woostack-execute <plan>`
runs it.

## Commands

- `/woostack-plan <spec-path>` — write the plan for the named markdown spec under
  `.woostack/specs/`. **The spec path is required.**
- `/woostack-plan` (no argument) — do **not** guess "the current spec." Ask which spec to plan
  (optionally list `.woostack/specs/` candidates) and stop until one is named.

When `woostack-build` reaches step 4 it invokes this skill with the approved spec path from
step 2/3.

## Read and check the spec

1. Read the spec file end to end — it is the source of truth for *what* to build; the plan is
   *how*.
2. **Scope check.** If the spec covers multiple independent subsystems, suggest splitting into
   separate plans — one per subsystem, each producing working, testable software on its own.
   Don't write a monolithic plan over a multi-subsystem spec.
3. **One plan per spec.** If a plan already resolves to this spec (a `.woostack/plans/` file with
   a matching `**Source:**` line or the same basename), **amend that plan in place** — never write
   a second (`spec : plan : PRs = 1 : 1 : N`; a second plan breaks the board join). Say you are
   amending.

## File structure first

Before defining tasks, map which files are created or modified and each one's single
responsibility. This locks in decomposition.

- Design units with clear boundaries; one responsibility per file. Prefer small, focused files.
- Files that change together live together. Split by responsibility, not by technical layer.
- In an existing codebase, follow established patterns; don't unilaterally restructure. If a file
  you must touch has grown unwieldy, folding a split into the plan is reasonable.

## PR-sized increments

Structure the plan as a sequence of **independently shippable increments** — preferably ≤500 LOC
each (a soft target, not a gate) — so the plan is execute-ready: `woostack-execute` runs one
increment per cycle as its own Graphite-stacked PR. Flag any slice that can't reasonably stay
under the target and propose a further split; genuinely atomic changes may exceed it. This
decomposition is part of planning (it folds `woostack-build`'s old decompose step into the plan
engine).

## Bite-sized tasks (TDD)

Within each increment, decompose into bite-sized tasks; each **step** is one action
(~2-5 minutes): write the failing test → run it, confirm it fails → minimal implementation → run
it, confirm it passes → commit. Use checkbox (`- [ ]`) syntax for every step so
`woostack-execute` ticks them in place as the live progress record. DRY, YAGNI, TDD, frequent
commits throughout.

In a target without a test runner (e.g. a docs/skills repo), "the failing test" becomes a
concrete **verification command** — a `grep`, a `bash -n`, a link check, or an existing script's
test — with exact expected output. Never a vague "verify it works."

The output shape (header, `**Source:**` line, task/step structure) is captured in
[references/plan-template.md](references/plan-template.md) — populate it; don't reinvent it.

## No placeholders

Every step carries the actual content an engineer needs. These are plan failures — never write
them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" without the actual test
- "Similar to Task N" — repeat the code; tasks may be read out of order
- A step that says *what* without showing *how* (code/command blocks required)
- References to types/functions/methods defined in no task

Exact file paths always. Complete code in every code step. Exact commands with expected output.

## Board join: Source line, frontmatter-free, filename

- **Filename:** save to `.woostack/plans/<spec-basename>.md` — the **same** `YYYY-MM-DD-<slug>`
  basename as the spec (reuse the spec's date; **not** today's). The shared basename is the
  slug-match fallback join.
- **Opening line:** the plan **opens with** `**Source:** .woostack/specs/<file>.md` in its first
  ~5 lines — the primary spec→plan join the `/woostack-status` board reads.
- **Frontmatter-free:** plans carry no YAML frontmatter and no `REQUIRED SUB-SKILL` banner. The
  header is the `**Source:**` line plus Goal / Architecture / Tech Stack.

The phase enum and join contracts are defined once in
[`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md) —
link, never restate.

## Self-review

After writing the plan, check it against the spec with fresh eyes — a checklist you run yourself,
not a subagent dispatch:

1. **Spec coverage** — every section/requirement maps to a task. List and fill any gap.
2. **Placeholder scan** — search for the red flags above; fix them.
3. **Type consistency** — types, signatures, and property names match across tasks (a method
   called one name in Task 3 and another in Task 7 is a bug).

Fix issues inline; no re-review needed.

## Status: planning

When the plan file exists, set the spec's `status: planning` (the conventions.md value for "plan
exists, 0 boxes done"). Doing it here means a standalone `/woostack-plan` also advances the board.
Do not tick any plan checkbox yet — execution owns checkbox progress.

## Terminal state: plan written, handed back

Stop when the plan is written, self-reviewed, and the spec is `planning`. Then hand back and name
the next step:

- Inside `woostack-build`: return to **step 6** (harden the plan).
- Standalone: tell the user the plan is ready and offer `/woostack-execute <plan-path>`. Stop.

Chain nothing yourself.

## Gate boundary

This skill owns **no approval gate**. The spec-approval gate (`woostack-build` step 3) is
upstream; the execution-handoff gate (step 8) is downstream. It does not present-for-approval,
execute, commit, or merge. It writes the plan and hands back — preserving `woostack-build`'s
"inherit gates, add none."

## Hard constraints

- **Spec path required.** Never guess "the current spec"; ask when no argument is given.
- **One plan per spec.** A plan already resolves to the spec → amend it; never write a second
  (breaks the 1:1 board join).
- **Markdown plan under `.woostack/plans/`, basename = spec basename.** Frontmatter-free, opening
  `**Source:**` line.
- **PR-sized increments.** Decompose into independently shippable slices (≤500 LOC soft target);
  flag and split oversized ones.
- **Bite-sized TDD tasks, no placeholders.** One action per step; complete code, exact commands,
  expected output.
- **Set `status: planning`; tick no checkbox.** Execution owns checkbox progress.
- **Own no gate; never execute, commit, or merge.** Write the plan and hand back.
````

- [x] **Step 3: Run the checks, confirm they pass**

Run: `head -2 skills/woostack-plan/SKILL.md | grep -c 'name: woostack-plan'; grep -c 'references/plan-template.md' skills/woostack-plan/SKILL.md`
Expected: first count `1` (valid frontmatter `name`), second count `≥1` (cross-link to the template present).

- [x] **Step 4: Verify the cross-links resolve**

Run: `test -e skills/woostack-plan/references/plan-template.md && test -e skills/woostack-build/SKILL.md && test -e skills/woostack-execute/SKILL.md && test -e skills/woostack-status/references/conventions.md && echo LINKS_OK`
Expected: `LINKS_OK` (every relative link target in SKILL.md exists).

- [x] **Step 5: Commit (same Increment-1 branch)**

```bash
gt modify -c -m "feat(woostack-plan): add SKILL.md (plan phase, internalizes writing-plans)"
```

---

## Increment 2: Wire woostack-plan into the loop & update surfaces

> Stacks on Increment 1. Rewires `woostack-build`, removes the dependency-preflight section, updates the status script + test, and bumps command-surface counts/routing everywhere. Its own Graphite-stacked branch on top of Increment 1.

### Task 3: Rewire woostack-build (drop preflight, use woostack-plan)

**Files:**
- Modify: `skills/woostack-build/SKILL.md`

- [x] **Step 1: Write the failing checks**

Run: `grep -n 'Dependency preflight\|superpowers:writing-plans\|→ writing-plans →' skills/woostack-build/SKILL.md`
Expected (before the change): matches on the `## Dependency preflight` heading, the `superpowers:writing-plans` bullet, and the overview-diagram `→ writing-plans →` — all of which must be gone after.

- [x] **Step 2: Update the frontmatter description**

Replace (line 3):

```
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, harden the plan, ship the spec and plan as their own PR, then implement it. Chains woostack-ideate, woostack-harden, woostack-commit, woostack-execute, and superpowers writing-plans in a fixed, gated order; writes markdown specs and plans under .woostack/.
```

with:

```
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, harden the plan, ship the spec and plan as their own PR, then implement it. Chains woostack-ideate, woostack-harden, woostack-plan, woostack-commit, and woostack-execute in a fixed, gated order; writes markdown specs and plans under .woostack/.
```

- [x] **Step 3: Update the overview diagram**

Replace (the first line of the ``` fenced diagram, line 16):

```
ideate → write spec (markdown) → harden spec → approve spec → writing-plans → decompose
```

with:

```
ideate → write spec (markdown) → harden spec → approve spec → plan → decompose
```

- [x] **Step 4: Remove the entire Dependency preflight section**

Delete this whole block (the `## Dependency preflight` heading through the degraded-run paragraph, lines 35–49, including the blank line after it):

```
## Dependency preflight

The ideate, hardening (spec and plan), spec+plan-commit, and execution phases use
[`woostack-ideate`](../woostack-ideate/SKILL.md),
[`woostack-harden`](../woostack-harden/SKILL.md),
[`woostack-commit`](../woostack-commit/SKILL.md), and
[`woostack-execute`](../woostack-execute/SKILL.md), which ship in this collection — no install
needed. Only the plan phase chains an external skill. At the start, check that it is installed:

- `superpowers:writing-plans`

If it is missing: name exactly what's missing and **offer to install it inline**
(`pnpx skills add obra/superpowers`) and continue. If the user declines, fall back to
following the skill's principle manually and **say so explicitly** — the run is degraded, not
equivalent.

```

Result: `## Overview` (and its trailing prose) is immediately followed by `## Procedure`. The build loop now has no external dependencies and nothing to preflight.

- [x] **Step 5: Rewrite step 4 (Plan) to invoke woostack-plan**

Replace step 4 (lines 79–84):

```
4. **Plan.** Once the spec is approved, invoke `superpowers:writing-plans`, saving the plan as
   **markdown** to
   `.woostack/plans/YYYY-MM-DD-<slug>.md` (plans are working checklists, not visualization
   artifacts). The plan **must open with** a `**Source:** .woostack/specs/<file>.md` line in
   its first ~5 lines so the board joins it 1:1 to the spec; keep plans frontmatter-free. Set
   the spec's `status: planning`.
```

with:

```
4. **Plan.** Once the spec is approved, invoke [`woostack-plan`](../woostack-plan/SKILL.md) with
   the approved spec path. It writes the **markdown** plan to `.woostack/plans/<spec-basename>.md`
   (same basename as the spec), opening with the `**Source:** .woostack/specs/<file>.md` line so
   the board joins it 1:1, frontmatter-free, structured as PR-sized increments, and it sets the
   spec's `status: planning`. It writes the plan and hands back — owning no gate. `woostack-plan`
   ships in this collection (no install), so the build loop has no external skill dependencies.
```

- [x] **Step 6: Reword step 5 (Decompose) — plan now owns decomposition**

Replace step 5 (lines 85–91):

```
5. **Decompose to PR-sized increments.** Steer work toward well-scoped PRs of **preferably
   ≤500 lines of code** — a soft target, not a gate. When the spec implies more than one
   reviewable PR, structure the plan as a sequence of independently shippable increments and
   run **one increment per build cycle**. Flag any slice that can't reasonably stay under the
   target and propose a further split before executing. Genuinely atomic changes may exceed
   the target. The `spec : plan : PRs = 1 : 1 : N` invariant holds throughout: exactly one
   plan per spec, and that one plan owns the N increment PRs.
```

with:

```
5. **Verify the increment decomposition.** `woostack-plan` (step 4) already structures the plan
   as PR-sized increments — well-scoped PRs of **preferably ≤500 lines of code** (a soft target,
   not a gate). Confirm the increment boundaries are sound and feed `woostack-execute`: each
   slice independently shippable, **one increment per build cycle**, oversized slices flagged and
   split (genuinely atomic changes may exceed the target). The `spec : plan : PRs = 1 : 1 : N`
   invariant holds throughout: exactly one plan per spec, and that one plan owns the N increment
   PRs.
```

- [x] **Step 7: Update the two hard-constraint references**

Replace (in the "Always get explicit spec approval before planning" constraint, line 145):

```
  written spec and wait for the user's clear yes. Never advance to `writing-plans` on assumed
```

with:

```
  written spec and wait for the user's clear yes. Never advance to `woostack-plan` on assumed
```

Then replace (in the "Author `status:`" constraint, line 157):

```
  2), `hardened` then `approved` (step 3), `planning` (step 4); the execute phase advances the
```

with:

```
  2), `hardened` then `approved` (step 3), `planning` (step 4, authored by `woostack-plan`); the
  execute phase advances the
```

- [x] **Step 8: Confirm the checks pass**

Run: `grep -c 'Dependency preflight\|superpowers:writing-plans\|→ writing-plans →' skills/woostack-build/SKILL.md; grep -c 'woostack-plan' skills/woostack-build/SKILL.md`
Expected: first count `0` (all three removed), second count `≥4` (description, step 4 link, step 4 prose, hard-constraint, status-constraint).

- [x] **Step 9: Commit (first commit of Increment 2 — creates its branch, stacked on Increment 1)**

```bash
gt create -m "refactor(woostack-build): use woostack-plan, drop dependency preflight"
```

### Task 4: Add the using-woostack routing row

**Files:**
- Modify: `skills/using-woostack/SKILL.md`

- [x] **Step 1: Write the failing check**

Run: `grep -c 'woostack-plan' skills/using-woostack/SKILL.md`
Expected: `0`.

- [x] **Step 2: Insert the routing row**

In the Command Routing table, insert a new row immediately **after** the `/woostack-build` row and **before** the `/woostack-execute` row. Replace:

```
| `/woostack-build <goal>`, build a feature through the woostack loop | `woostack-build` |
| `/woostack-execute <plan-path> [--inline\|--subagent]`, execute an approved plan as PR-sized stacked increments (inline or subagent-driven) | `woostack-execute` |
```

with:

```
| `/woostack-build <goal>`, build a feature through the woostack loop | `woostack-build` |
| `/woostack-plan <spec-path>`, write the implementation plan for an approved spec as PR-sized increments | `woostack-plan` |
| `/woostack-execute <plan-path> [--inline\|--subagent]`, execute an approved plan as PR-sized stacked increments (inline or subagent-driven) | `woostack-execute` |
```

- [x] **Step 3: Confirm the check passes**

Run: `grep -c '`/woostack-plan <spec-path>`.*`woostack-plan`' skills/using-woostack/SKILL.md`
Expected: `1`.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs(using-woostack): route /woostack-plan to woostack-plan"
```

### Task 5: Fix the woostack-ideate chain-nothing example

**Files:**
- Modify: `skills/woostack-ideate/SKILL.md:34`

- [x] **Step 1: Write the failing check**

Run: `grep -n 'Do not invoke `writing-plans`' skills/woostack-ideate/SKILL.md`
Expected (before): matches line 34.

- [x] **Step 2: Update the example list**

Replace (line 34):

```
- **Chain nothing.** Do not invoke `writing-plans`, `woostack-execute`, or any implementation
```

with:

```
- **Chain nothing.** Do not invoke `woostack-plan`, `woostack-execute`, or any implementation
```

- [x] **Step 3: Confirm the check passes**

Run: `grep -c 'Do not invoke `woostack-plan`, `woostack-execute`' skills/woostack-ideate/SKILL.md`
Expected: `1`.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs(woostack-ideate): reference woostack-plan in chain-nothing example"
```

### Task 6: Update the status engine next-action strings (real TDD cycle)

**Files:**
- Modify: `skills/woostack-status/scripts/tests/test-status.sh:62`
- Modify: `skills/woostack-status/scripts/status.sh:177`
- Modify: `skills/woostack-status/scripts/status.sh:227`

- [x] **Step 1: Update the test assertion FIRST (red)**

Replace (in `test-status.sh`, line 62):

```
assert_contains "$OUT" "writing-plans" "approved next-action"
```

with:

```
assert_contains "$OUT" "woostack-plan" "approved next-action"
```

- [x] **Step 2: Run the test, confirm it now FAILS**

Run: `bash skills/woostack-status/scripts/tests/test-status.sh`
Expected: FAIL on the `approved next-action` assertion — the harness still emits `write the plan (writing-plans)`, so `"woostack-plan"` is not found in `$OUT`.

- [x] **Step 3: Update status.sh next-action string (green)**

Replace (line 177):

```
    approved)   echo "write the plan (writing-plans)" ;;
```

with:

```
    approved)   echo "write the plan (woostack-plan)" ;;
```

- [x] **Step 4: Update status.sh no-plan flag string**

Replace (line 227):

```
    case "$phase" in draft|hardened|approved|abandoned) : ;; *) flag "$name: no plan resolves to this spec (writing-plans)" ;; esac
```

with:

```
    case "$phase" in draft|hardened|approved|abandoned) : ;; *) flag "$name: no plan resolves to this spec (woostack-plan)" ;; esac
```

- [x] **Step 5: Run the test, confirm it PASSES; lint the script**

Run: `bash skills/woostack-status/scripts/tests/test-status.sh && bash -n skills/woostack-status/scripts/status.sh && echo OK`
Expected: the test suite passes (including `approved next-action`) and `OK` prints (no syntax errors).

- [x] **Step 6: Commit**

```bash
gt modify -c -m "fix(woostack-status): point plan next-action at woostack-plan"
```

### Task 7: Bump AGENTS.md counts, list, routing, and file map

**Files:**
- Modify: `AGENTS.md` (`.claude/CLAUDE.md` is a symlink — editing `AGENTS.md` updates both)

- [x] **Step 1: Write the failing check**

Run: `grep -n 'ten skills\|ten-skill command surface\|twelve `SKILL.md` files\|the ten public' AGENTS.md`
Expected (before): matches the "ten skills" line, the "ten-skill command surface" line, and the "twelve `SKILL.md` files (the ten public …)" constraint.

- [x] **Step 2: Update the surface count and add woostack-plan to the list**

Replace:

```
The public command/adoption surface has ten skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-build`](skills/woostack-build/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
```

with:

```
The public command/adoption surface has eleven skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-build`](skills/woostack-build/SKILL.md)
- [`woostack-plan`](skills/woostack-plan/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
```

- [x] **Step 3: Update the "ten-skill command surface" mention**

Replace (in the internal-sub-skill paragraph):

```
`/woostack-*` commands: they have no routing row and are absent from the ten-skill command
surface above. Like [`action.yml`](action.yml), they are shipped assets — do not delete them as
strays.
```

with:

```
`/woostack-*` commands: they have no routing row and are absent from the eleven-skill command
surface above. Like [`action.yml`](action.yml), they are shipped assets — do not delete them as
strays.
```

- [x] **Step 4: Add /woostack-plan to the Mode B command list**

Replace (in the Mode B paragraph):

```
**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-execute`, `/woostack-commit`,
`/woostack-review`, `/woostack-address-comments`, `/woostack-status`, or `/woostack-visualize`,
```

with:

```
**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-plan`, `/woostack-execute`, `/woostack-commit`,
`/woostack-review`, `/woostack-address-comments`, `/woostack-status`, or `/woostack-visualize`,
```

- [x] **Step 5: Update the SKILL.md-count hard constraint**

Replace:

```
- Do not move or rename any of the twelve `SKILL.md` files (the ten public command/adoption
  skills plus the internal `woostack-ideate` and `woostack-harden`).
```

with:

```
- Do not move or rename any of the thirteen `SKILL.md` files (the eleven public command/adoption
  skills plus the internal `woostack-ideate` and `woostack-harden`).
```

- [x] **Step 6: Add the woostack-plan Quick file map entry**

Replace:

```
- Build loop:
  [`skills/woostack-build/SKILL.md`](skills/woostack-build/SKILL.md)
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
```

with:

```
- Build loop:
  [`skills/woostack-build/SKILL.md`](skills/woostack-build/SKILL.md)
- Plan-writing engine for the build loop (public command):
  [`skills/woostack-plan/SKILL.md`](skills/woostack-plan/SKILL.md)
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
```

- [x] **Step 7: Confirm the checks pass**

Run: `grep -c 'eleven skills\|eleven-skill command surface\|thirteen `SKILL.md` files\|skills/woostack-plan/SKILL.md\|`/woostack-plan`' AGENTS.md; grep -c 'ten skills\|ten-skill command surface\|twelve `SKILL.md`' AGENTS.md`
Expected: first count `≥5` (all new mentions present), second count `0` (no stale ten/twelve counts remain).

- [x] **Step 8: Commit**

```bash
gt modify -c -m "docs(agents): add woostack-plan to surface (eleven public, thirteen SKILL.md)"
```

### Task 8: Update README counts, list, build-loop prose, and add a command subsection

**Files:**
- Modify: `README.md:29`
- Modify: `README.md:62`
- Modify: `README.md` (How it works — add a woostack-plan subsection before woostack-execute)

- [x] **Step 1: Write the failing check**

Run: `grep -c 'surface is ten skills\|woostack-plan' README.md`
Expected: a match on `surface is ten skills` and `0` matches on `woostack-plan`.

- [x] **Step 2: Update the Install-section surface count and list**

Replace (line 29):

```
This installs the woostack **collection** into your agent's skill directory and records it in `skills-lock.json`. The public command/adoption surface is ten skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-execute, woostack-commit, woostack-review, woostack-address-comments, woostack-status, and woostack-visualize. The collection also installs two internal sub-skills used by `woostack-build` — `woostack-ideate` and `woostack-harden`; neither is a `/woostack-*` command. Works in any agent that respects the `skills` convention: Claude Code, Cursor, Codex, Aider, and others.
```

with:

```
This installs the woostack **collection** into your agent's skill directory and records it in `skills-lock.json`. The public command/adoption surface is eleven skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-plan, woostack-execute, woostack-commit, woostack-review, woostack-address-comments, woostack-status, and woostack-visualize. The collection also installs two internal sub-skills used by `woostack-build` — `woostack-ideate` and `woostack-harden`; neither is a `/woostack-*` command. Works in any agent that respects the `skills` convention: Claude Code, Cursor, Codex, Aider, and others.
```

- [x] **Step 3: Update the build-loop sequencing prose**

Replace (line 62):

```
It sequences woostack's own ideate, harden, and execute phases (`woostack-ideate`, `woostack-harden`, `woostack-execute`) with the proven superpowers `writing-plans` sub-skill, inheriting the ideate design gate and hosting the relocated spec-approval gate before planning. Specs and plans are both written as markdown under `.woostack/`; an HTML render is available on demand for a richer view but is never the authored format. Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. It ends on the reviewed PR stack. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)
```

with:

```
It sequences woostack's own ideate, harden, plan, and execute phases (`woostack-ideate`, `woostack-harden`, `woostack-plan`, `woostack-execute`), inheriting the ideate design gate and hosting the relocated spec-approval gate before planning — the build loop has no external skill dependencies. Specs and plans are both written as markdown under `.woostack/`; an HTML render is available on demand for a richer view but is never the authored format. Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. It ends on the reviewed PR stack. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)
```

- [x] **Step 4: Add a `/woostack-plan` command subsection**

Insert a new subsection immediately **before** the `### `/woostack-execute <plan-path>`: run a plan as stacked PRs` heading. Replace:

```
### `/woostack-execute <plan-path>`: run a plan as stacked PRs
```

with:

```
### `/woostack-plan <spec-path>`: write a plan from a spec

Writes a comprehensive implementation plan for an approved markdown spec from `.woostack/specs/` — file-structure first, bite-sized TDD tasks with no placeholders, structured as PR-sized increments — saved frontmatter-free to `.woostack/plans/<spec-basename>.md` with an opening `**Source:**` line that joins it 1:1 to the spec, and sets the spec's `status: planning`. It is the plan phase `woostack-build` step 4 delegates to, and is usable standalone. Pairs with `woostack-execute` (produce-plan / consume-plan). Writes the plan and hands back; never executes or merges. → [SKILL.md](skills/woostack-plan/SKILL.md)

### `/woostack-execute <plan-path>`: run a plan as stacked PRs
```

- [x] **Step 5: Confirm the checks pass**

Run: `grep -c 'is eleven skills\|woostack-plan <spec-path>`: write a plan\|`woostack-plan`' README.md; grep -c 'is ten skills\|proven superpowers `writing-plans`' README.md`
Expected: first count `≥3` (new count, new subsection, prose mention), second count `0` (stale count and the writing-plans dependency phrasing gone).

- [x] **Step 6: Commit**

```bash
gt modify -c -m "docs(readme): document woostack-plan; eleven public skills, no external deps"
```

### Task 9: Update CONTRIBUTING surface list and add a plan-phase row

**Files:**
- Modify: `CONTRIBUTING.md:3`
- Modify: `CONTRIBUTING.md` (What to change table — add plan row)

- [x] **Step 1: Write the failing check**

Run: `grep -c 'woostack-plan' CONTRIBUTING.md`
Expected: `0`.

- [x] **Step 2: Add woostack-plan to the surface sentence**

Replace (line 3):

```
This repo is a **published collection of skills**, not a codebase. Contributions are edits to the skills — the Markdown under `skills/` plus the support files a skill ships (HTML templates, the review engine's shell scripts and prompts, JSON config). The public command/adoption surface is `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-execute`, `woostack-commit`, `woostack-review`, `woostack-address-comments`, `woostack-status`, and `woostack-visualize`. The collection also ships `woostack-ideate` and `woostack-harden` as internal sub-skills used by `woostack-build`.
```

with:

```
This repo is a **published collection of skills**, not a codebase. Contributions are edits to the skills — the Markdown under `skills/` plus the support files a skill ships (HTML templates, the review engine's shell scripts and prompts, JSON config). The public command/adoption surface is `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-plan`, `woostack-execute`, `woostack-commit`, `woostack-review`, `woostack-address-comments`, `woostack-status`, and `woostack-visualize`. The collection also ships `woostack-ideate` and `woostack-harden` as internal sub-skills used by `woostack-build`.
```

- [x] **Step 3: Add the "Change the plan phase" row**

In the "What to change" table, insert a new row immediately **after** the harden-phase row and **before** the execute-phase row. Replace:

```
| Change the harden phase (the build loop's stress-test step) | `skills/woostack-harden/SKILL.md` |
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
```

with:

```
| Change the harden phase (the build loop's stress-test step) | `skills/woostack-harden/SKILL.md` |
| Change the plan phase (the build loop's planning step) | `skills/woostack-plan/SKILL.md` |
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
```

- [x] **Step 4: Confirm the check passes**

Run: `grep -c 'woostack-plan' CONTRIBUTING.md`
Expected: `2` (the surface sentence and the new table row).

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(contributing): list woostack-plan and its change-here row"
```

### Task 10: Repo-wide consistency sweep

**Files:**
- Verify only (no new edits unless a stray is found).

- [x] **Step 1: Confirm no stale writing-plans wiring remains**

Run: `grep -rn 'writing-plans\|superpowers:writing' skills/ AGENTS.md README.md CONTRIBUTING.md action.yml .github/ | grep -v '.woostack/'`
Expected: the **only** remaining match is the single lineage-credit line inside `skills/woostack-plan/SKILL.md` ("It internalizes `superpowers:writing-plans` …"), exactly as `woostack-execute/SKILL.md` still credits `executing-plans`. No matches in `woostack-build`, `status.sh`, `test-status.sh`, `using-woostack`, `woostack-ideate`, README, CONTRIBUTING, or AGENTS.md. If anything else matches, fix it.

- [x] **Step 2: Confirm the surface counts agree everywhere**

Run: `grep -rn 'eleven skills\|eleven-skill\|thirteen `SKILL.md`\|is eleven skills' AGENTS.md README.md; grep -rn 'ten skills\|ten-skill\|twelve `SKILL.md`' AGENTS.md README.md CONTRIBUTING.md`
Expected: the first grep shows the eleven/thirteen counts present in AGENTS.md and README; the second grep returns nothing (no stale ten/twelve counts anywhere).

- [x] **Step 3: Re-run the status test and lint all touched scripts**

Run: `bash skills/woostack-status/scripts/tests/test-status.sh && bash -n skills/woostack-status/scripts/status.sh && echo ALL_GREEN`
Expected: the suite passes and `ALL_GREEN` prints.

- [x] **Step 4: Commit (only if Step 1 surfaced a stray to fix; otherwise skip)**

```bash
gt modify -c -m "docs: sweep stray writing-plans references"
```

---

## Self-Review

**1. Spec coverage** — every spec requirement maps to a task:

- New `skills/woostack-plan/SKILL.md` (description, required `<spec-path>`, core loop, increments, board join, `status: planning`, hand-back, gate boundary, hard constraints) → **Task 2**.
- New `references/plan-template.md` (frontmatter-free, `**Source:**` line, no banner, TDD task structure) → **Task 1**.
- Remove build's Dependency preflight + rewire step 4 / reword step 5 + description + diagram + hard-constraint mentions → **Task 3**.
- using-woostack routing row → **Task 4**.
- woostack-ideate chain-nothing example → **Task 5**.
- status.sh two strings + test-status.sh assertion → **Task 6**.
- AGENTS.md counts/list/routing/file-map → **Task 7**.
- README counts/list/prose/subsection → **Task 8**.
- CONTRIBUTING list + plan-phase row → **Task 9**.
- Repo-wide grep (no stale writing-plans wiring; lineage credit allowed), count consistency, status test green → **Task 10** (spec §7 Testing).

No gaps.

**2. Placeholder scan** — the only `{{…}}` tokens live inside the `plan-template.md` body (Task 1), which is a fill-in skeleton by design; they are the template's intended placeholders, not plan placeholders. Every plan step has exact paths, full file content or exact find/replace blocks, and exact verification commands with expected output.

**3. Type consistency** — names are stable across tasks: the skill is `woostack-plan` throughout; the template path is `skills/woostack-plan/references/plan-template.md` in both Task 1 and Task 2's cross-link; counts are uniformly "eleven public skills" / "thirteen `SKILL.md` files"; next-action string `write the plan (woostack-plan)` matches between status.sh (Task 6 Step 3) and the test assertion (Task 6 Step 1). The lineage-credit allowance in Task 10 matches the exact string written in Task 2.
</content>
