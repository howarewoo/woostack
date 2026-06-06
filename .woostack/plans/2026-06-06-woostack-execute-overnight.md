**Source:** .woostack/specs/2026-06-06-woostack-execute-overnight.md

# woostack-execute-overnight Implementation Plan

**Goal:** Ship `skills/woostack-execute-overnight/SKILL.md` (public command #13) — a sibling of `woostack-execute` that drives an approved plan to a reviewed stack **unattended**, swapping execute's stop-and-ask gates for resolve-or-log-and-continue, honoring an optional `## Track:` parallelism, and writing a morning report under `.woostack/overnight/`. Wire it as the third option at `woostack-build`'s execution-handoff gate and register it across the doc surface (twelve → thirteen public commands).

**Architecture:** One thin self-contained `SKILL.md` plus a `references/report-template.md`. The skill **reuses** `woostack-execute`'s cadence, drivers, safety, and memory contract by cross-link and documents only the deltas: pre-flight refuse-to-start, the three autonomy overrides (incl. the inline/subagent review split), the `## Track:` consumption + per-track halt, and the morning report. The author-facing track convention is added to `woostack-plan` and noted in the status conventions in the same change so the skill's track claim is true on landing. No app code, no CI — verification is by grep/inspection.

**Tech Stack:** Markdown skill files only. No code, no app build, no test harness — "failing test" steps are concrete verification commands (`grep`, `test -f`, `git check-ignore`) with exact expected output.

**Decomposition (build step 5):** **One PR-sized increment** (~320 LOC of new/changed markdown, well under 500). Hardened from an earlier 2-increment split: the skill references the `## Track:` convention that `woostack-plan` documents, so the two halves must land together — splitting them would leave an inconsistent intermediate state and a forward reference. This matches the `woostack-execute` precedent for tightly-coupled skill+doc changes. Executed as sequential, TDD-style task commits on one branch (`gt create` then `gt modify -c`) → one PR, stacked on the spec+plan PR base. `spec : plan : PRs = 1 : 1 : 1`.

**Out of scope (explicit):** Do NOT modify `woostack-execute` (tracks are overnight-only; execute stays linear). Do NOT make `woostack-plan` auto-partition tracks (author-driven only). Do NOT add a new `status:` phase-enum value. Do NOT make the skill merge, force-push, or relax the untrusted-plan-step safety rule. Do NOT add app code, lockfiles, or CI. Do NOT move/rename any existing `SKILL.md`. Do NOT rewrite historical `.woostack/` references.

---

## Increment 1: woostack-execute-overnight — the command, its wiring, and the track convention

> One independently shippable PR — the new skill, its report template, the report `.gitignore`, full registration across build + the doc surface, and the optional `## Track:` convention (producer doc + status note). Its own Graphite-stacked branch on top of the spec+plan PR base.

### Task 1: Create `skills/woostack-execute-overnight/SKILL.md`

**Files:**
- Create: `skills/woostack-execute-overnight/SKILL.md`

- [x] **Step 1: Write the skill file (complete content)**

````markdown
---
name: woostack-execute-overnight
description: Use to execute an approved woostack plan UNATTENDED overnight — one autonomous run with no user input after launch that drives every increment to a reviewed stack, swapping woostack-execute's stop-and-ask gates for resolve-or-log-and-continue (woostack-debug --auto on stuck verifications; bounded auto-address on a blocking review; halt-the-track on anything unsafe or ambiguous), honoring an optional `## Track:` parallelism in the plan, and writing a morning report under .woostack/overnight/ for a human to test in the morning. It is the third choice at woostack-build's execution-handoff gate (Go / Hand off / Run overnight); also usable standalone via /woostack-execute-overnight <plan-path> [--inline|--subagent]. One plan per spec, multiple PRs per plan. Never merges; never relaxes safety for autonomy.
---

# woostack-execute-overnight

Execute an approved plan the way [`woostack-execute`](../woostack-execute/SKILL.md) does, but
**unattended**. Same input (one plan path), same per-increment cadence, same drivers, same hard
safety invariants — this skill **reuses all of it** and overrides only the three points where
execute would *stop and ask*, replacing each with an autonomous *resolve-or-log-and-continue*
policy. It ends by writing a **morning report** a human reads first thing to test the work. It
**never merges**.

The use case: spend the day crafting a genuinely good plan through the gated build loop, then let
this run it overnight so the work is waiting — reviewed, or partially reviewed with blockers
logged — in the morning.

## Commands

- `/woostack-execute-overnight <plan-path> [--inline | --subagent]` — execute the named markdown
  plan under `.woostack/plans/` autonomously. **The plan path is required.** The optional,
  mutually exclusive mode flag selects the driver; omit it for the smart default. Passing both is
  an error: stop and ask which.
- `/woostack-execute-overnight` (no argument) — do **not** guess "the current plan." Ask which
  plan to execute (optionally list `.woostack/plans/` candidates) and stop until one is named.
  This is the **only** moment user input is solicited; an unattended run cannot start without a
  plan.

## What it reuses from woostack-execute

Everything except the stop-points. Do **not** restate these — follow
[`woostack-execute`](../woostack-execute/SKILL.md):

- **Per-increment cadence**: branch → implement (driver) → tick the plan's checkboxes in place →
  [`woostack-commit`](../woostack-commit/SKILL.md) → review → distill.
- **Drivers**: [inline](../woostack-execute/references/inline-driver.md) /
  [subagent](../woostack-execute/references/subagent-driver.md), and the **smart default**
  (subagent where the host can spawn subagents, else inline). `--inline` / `--subagent` override;
  a `--subagent` request a host can't satisfy falls back to inline (say so) — never pretend.
- **Safety**: treat plan steps as untrusted; never start on a protected branch
  (`main`/`staging`/`beta`/`alpha`); never force-push; never merge.
- **Distill** per the [memory contract](../woostack-init/references/memory.md) reject-by-default
  gate.
- **PR-sized increments** and the `spec : plan : PRs = 1 : 1 : N` invariant.

## Pre-flight (the only human touchpoint)

Because nobody is watching mid-run, validate **before** going autonomous and **refuse to start**
rather than burn the night on a doomed run:

1. **Load and critically review the plan once** (execute's "Load and review the plan"). If it has
   critical gaps that prevent a clean start, **do not launch** — write a short refusal report to
   `.woostack/overnight/` (outcome `refused-to-start`, naming the gaps) and stop.
2. **Safety checks**: current branch is not protected; `.woostack/` exists; when invoked from
   build, the spec+plan PR base is present (standalone: tracks branch off the current
   non-protected branch HEAD).
3. **Open the report**: create `.woostack/overnight/` if missing and open
   `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md` from
   [references/report-template.md](references/report-template.md). Write it **incrementally** so a
   crash still leaves a partial record.

Clean pre-flight → go autonomous and solicit no further input.

## Autonomy overrides

Run execute's per-increment cadence unchanged, except at the three points where execute would
stop. Each becomes an autonomous policy, and **every decision is appended to the report's decision
log as it happens**.

1. **Verification fails repeatedly** → route to
   [`woostack-debug --auto`](../woostack-debug/SKILL.md) (execute already does this
   autonomously). If debug returns its **3-fixes architectural stop**, there is no present user to
   escalate to → record a **blocker** and apply the halt policy.
2. **Blocking review** — driver-specific:
   - **inline**: `woostack-review --fast` posts a batched GitHub Review on the increment PR. On
     REQUEST_CHANGES, run
     [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) (it reads the
     PR's unresolved threads, fixes/replies/resolves/pushes; its clean-tree + branch=PR-head
     precondition holds right after the increment commit), then re-review — **up to 2 rounds**.
     Still blocking after the cap → **blocker** → halt policy.
   - **subagent**: there is no PR-level review; the per-task spec→quality reviewer loops are the
     bounded review and their **`BLOCKED`** escalation is the terminal outcome → treat it directly
     as a **blocker** → halt policy (the loop already was the retry; no separate auto-address).
3. **Unsafe or ambiguous plan step** → **safety is never relaxed for autonomy.** A
   destructive / secret-touching / auth-mutating / network step, or a genuinely ambiguous
   instruction, is **never auto-approved** → **blocker** → halt policy.

## Tracks & halt policy

A plan may group its increments under top-level **`## Track:` headings**. Each track is its own
linear `gt` stack branched off the **common base** (the spec+plan PR when invoked from build, else
the current non-protected branch HEAD). A plan with **no** track headings has **one implicit
track** — exactly `woostack-execute`'s linear behavior. The convention is **author-driven**:
[`woostack-plan`](../woostack-plan/SKILL.md) documents and allows it; this skill is the only
consumer.

Process tracks **in order, sequentially** (single session — no real concurrency); within a track,
increments in order. On a **blocker**:

- **End the current track** at the blocker — never stack new work on broken work; work already
  committed stays committed (no rollback).
- **Advance to the next track**, branching its first increment off the common base. Record the
  blocked track's remaining increments as `not-attempted`.
- A single-track (default) plan therefore halts the remainder at the blocker — expected and
  reported, not an error.

## Morning report

Written incrementally to `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md` from
[references/report-template.md](references/report-template.md). It is **gitignored** (a per-run
artifact, like `.woostack/visuals/`), so it never rides into an increment PR and never dirties the
tree for the review / address-comments clean-tree preconditions. Sections:

- **Needs you** (top): blockers, and a morning **test checklist** (what to verify, the HEAD branch
  per track).
- **Run summary**: plan, driver, start/end, outcome (`clean` / `partial+blockers` /
  `refused-to-start`).
- **Per-increment table**: status (`done` / `done-with-findings` / `blocked` / `not-attempted`),
  branch + PR URL, review verdict, auto-address rounds used.
- **Decision log**: every autonomous decision with its rationale.

## Terminal state

Stop when every track has either completed or halted at a blocker. The result is a Graphite stack
(linear, or tree-stacked across tracks) of reviewed / partially-reviewed increment PRs, plus a
complete morning report. Report the path. **Never merge.**

## Gate boundary

This skill owns **no approval gate** — there is no human at runtime to gate. The pre-flight
refuse-to-start is a **safety check**, not a gate. `woostack-build`'s upstream HARD GATES (design,
spec) are unchanged; "Run overnight" is an explicit chosen go-ahead at build's step-8 gate, never
an inference. It never merges and never relaxes safety for autonomy.

## Hard constraints

- **Plan path required.** Never guess "the current plan"; ask when no argument is given.
- **Unattended after launch.** Pre-flight (and the no-arg plan prompt) is the only input; once
  running, solicit nothing.
- **Refuse a doomed run.** A plan with critical gaps → refuse at pre-flight with a report; don't
  start.
- **Resolve-or-log-and-continue, never relax safety.** debug --auto / bounded auto-address /
  blocker-and-halt as above; destructive/secret/auth/network/ambiguous steps are never
  auto-approved.
- **Tracks: author-driven, overnight-only.** Honor `## Track:` headings (default one implicit
  track); a blocker ends only its track. Never force-build on broken work.
- **Morning report every run**, incremental and gitignored under `.woostack/overnight/`.
- **Reuse execute; don't restate it.** Cross-link the cadence, drivers, safety, and memory
  contract.
- **Never merge, never force-push, never start on a protected branch. Own no gate.**
````

- [x] **Step 2: Verify the file exists with valid frontmatter and required sections**

Run: `test -f skills/woostack-execute-overnight/SKILL.md && grep -c -E "^name: woostack-execute-overnight$|^## Commands$|^## Pre-flight|^## Autonomy overrides$|^## Tracks|^## Morning report$|^## Gate boundary$|^## Hard constraints$" skills/woostack-execute-overnight/SKILL.md`
Expected: `8`

- [x] **Step 3: Verify it cross-links execute (does not restate it)**

Run: `grep -c -E "woostack-execute/SKILL.md|inline-driver.md|subagent-driver.md" skills/woostack-execute-overnight/SKILL.md`
Expected: a count `>= 3` (references to execute + both drivers).

- [x] **Step 4: Commit**

```bash
gt create -m "feat(woostack-execute-overnight): add unattended overnight execute skill"
```

### Task 2: Create `skills/woostack-execute-overnight/references/report-template.md`

**Files:**
- Create: `skills/woostack-execute-overnight/references/report-template.md`

- [x] **Step 1: Write the morning-report skeleton (complete content)**

````markdown
<!-- woostack-execute-overnight morning report. Per-run artifact, gitignored. Written incrementally. -->

# Overnight run — {{PLAN_BASENAME}}

> Outcome: {{clean / partial+blockers / refused-to-start}} · Driver: {{inline / subagent}} · Started: {{START}} · Ended: {{END}}

## ⚠ Needs you

{{Blockers requiring a human, most important first. "None — clean stack." if there are none.}}

### Morning test checklist

- [ ] {{What to manually verify, and where (branch / PR / track HEAD).}}

## Run summary

- **Plan:** `.woostack/plans/{{PLAN_BASENAME}}.md`
- **Spec:** `.woostack/specs/{{SPEC_BASENAME}}.md`
- **Base:** {{spec+plan PR # / branch the tracks stack on}}
- **Driver:** {{inline / subagent}}
- **Tracks:** {{N tracks, or "1 (implicit / linear)"}}

## Per-increment

| Track | Increment | Status | Branch / PR | Review | Auto-address rounds |
|---|---|---|---|---|---|
| {{A}} | {{1}} | {{done / done-with-findings / blocked / not-attempted}} | {{branch / PR URL}} | {{verdict}} | {{0–2}} |

## Decision log

<!-- Appended live, one line per autonomous decision. -->

- {{stamp}} — {{decision (debug fix / auto-address round / BLOCKED / blocker recorded / track ended / increment not-attempted) + rationale}}
````

- [x] **Step 2: Verify the template has the four sections**

Run: `grep -c -E "^## ⚠ Needs you$|^## Run summary$|^## Per-increment$|^## Decision log$" skills/woostack-execute-overnight/references/report-template.md`
Expected: `4`

- [x] **Step 3: Commit**

```bash
gt modify -c -m "feat(woostack-execute-overnight): add morning-report template"
```

### Task 3: Gitignore the per-run report directory

**Files:**
- Modify: `.gitignore` (root, after the `.woostack/visuals/` block near line 54)

- [x] **Step 1: Add the overnight ignore (Edit)**

Find:
```
# woostack: disposable HTML renders (regenerated from source)
.woostack/visuals/
```
Replace with:
```
# woostack: disposable HTML renders (regenerated from source)
.woostack/visuals/
# woostack: per-run overnight execution reports (regenerated each run)
.woostack/overnight/
```

- [x] **Step 2: Verify it is ignored**

Run: `git check-ignore .woostack/overnight/x.md`
Expected: `.woostack/overnight/x.md`

- [x] **Step 3: Commit**

```bash
gt modify -c -m "chore(gitignore): ignore .woostack/overnight per-run reports"
```

### Task 4: Wire the three-way handoff into `woostack-build`

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (step 8, step 9 opener, step 10, the "Stop before execute" constraint)

- [x] **Step 1: Add "Run overnight" to step 8 (Edit)**

Find:
```
   - **Go** → proceed to step 9 and run `woostack-execute` in this session.
   - **Hand off** → stop here. The user takes the plan PR and executes later or elsewhere (e.g.
     Codex, or a fresh session via `/woostack-execute <plan-path>`).
   Ambiguous or no answer is **not** a "go": never auto-run execute without an explicit
   go-ahead. This is the chain's last hard gate.
```
Replace with:
```
   - **Go** → proceed to step 9 and run `woostack-execute` in this session.
   - **Run overnight** → proceed to step 9 but run
     [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) instead: it drives the
     whole plan **unattended** (autonomous, no further input) and leaves a morning report under
     `.woostack/overnight/` for you to test. Use this to let a well-made plan run overnight.
   - **Hand off** → stop here. The user takes the plan PR and executes later or elsewhere (e.g.
     Codex, or a fresh session via `/woostack-execute <plan-path>`).
   Ambiguous or no answer is **not** a "go": never auto-run execute (supervised or overnight)
   without an explicit go-ahead. This is the chain's last hard gate.
```

- [x] **Step 2: Note the overnight driver in step 9 (Edit)**

Find:
```
9. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the plan path to
   work the plan as PR-sized stacked increments on top of the spec+plan PR — each implemented
```
Replace with:
```
9. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) — or, if the user chose
   **Run overnight** at step 8, [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md)
   (unattended) — with the plan path to
   work the plan as PR-sized stacked increments on top of the spec+plan PR — each implemented
```

- [x] **Step 3: Add the overnight terminal shape to step 10 (Edit)**

Find:
```
10. **End on the chosen terminal state.** Build ends in one of two shapes, never merging either:
    - **Hand off** → only the spec+plan PR is open (no increment PRs), ready for external or
      later execute.
    - **Go** → a Graphite stack with the spec+plan PR at the base and a reviewed increment PR
      above each step.
    Build does not separately ask to open a PR (step 7 and `woostack-execute` open them as work
    steps) and **never merges**.
```
Replace with:
```
10. **End on the chosen terminal state.** Build ends in one of three shapes, never merging any:
    - **Hand off** → only the spec+plan PR is open (no increment PRs), ready for external or
      later execute.
    - **Go** → a Graphite stack with the spec+plan PR at the base and a reviewed increment PR
      above each step.
    - **Run overnight** → an autonomous `woostack-execute-overnight` run: a reviewed (or partially
      reviewed, blockers logged) stack — linear or tree-stacked across `## Track:`s — plus a
      morning report under `.woostack/overnight/`.
    Build does not separately ask to open a PR (step 7 and the execute phase open them as work
    steps) and **never merges**.
```

- [x] **Step 4: Reword the "Stop before execute" hard constraint (Edit)**

Find:
```
- **Stop before execute.** Never auto-run execute; always halt at the execution-handoff gate
  (step 8) after the spec+plan PR. The plan PR is the artifact for executing here or in another
  tool. Ambiguous or no answer is not a "go."
```
Replace with:
```
- **Stop before execute.** Never auto-run execute — supervised `woostack-execute` or unattended
  `woostack-execute-overnight`; always halt at the execution-handoff gate (step 8) after the
  spec+plan PR and let the user choose Go / Run overnight / Hand off. The plan PR is the artifact
  for executing here or in another tool. Ambiguous or no answer is not a "go."
```

- [x] **Step 5: Verify build now offers three options and references overnight**

Run: `grep -c "woostack-execute-overnight" skills/woostack-build/SKILL.md`
Expected: `4` (step 8, step 9, step 10, constraint).

Run: `grep -c -E "Run overnight" skills/woostack-build/SKILL.md`
Expected: `4` (step 8 bullet, step 9 mention, step 10 bullet, constraint).

- [x] **Step 6: Commit**

```bash
gt modify -c -m "feat(woostack-build): offer Run overnight at the execution-handoff gate"
```

### Task 5: Add the `using-woostack` routing row

**Files:**
- Modify: `skills/using-woostack/SKILL.md` (Command Routing table, after the `woostack-execute` row)

- [x] **Step 1: Insert the routing row (Edit)**

Find:
```
| `/woostack-execute <plan-path> [--inline\|--subagent]`, execute an approved plan as PR-sized stacked increments (inline or subagent-driven) | `woostack-execute` |
```
Replace with:
```
| `/woostack-execute <plan-path> [--inline\|--subagent]`, execute an approved plan as PR-sized stacked increments (inline or subagent-driven) | `woostack-execute` |
| `/woostack-execute-overnight <plan-path> [--inline\|--subagent]`, execute an approved plan unattended overnight (autonomous, morning report) | `woostack-execute-overnight` |
```

- [x] **Step 2: Verify the row exists**

Run: `grep -c "woostack-execute-overnight" skills/using-woostack/SKILL.md`
Expected: `1`

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(using-woostack): route /woostack-execute-overnight"
```

### Task 6: Register the 13th command in `AGENTS.md`

**Files:**
- Modify: `AGENTS.md` (`.claude/CLAUDE.md` is a symlink; edit `AGENTS.md`)

- [x] **Step 1: Bump the public-surface count and list (Edit)**

Find:
```
The public command/adoption surface has twelve skills:
```
Replace with:
```
The public command/adoption surface has thirteen skills:
```

- [x] **Step 2: Add the list entry (Edit)**

Find:
```
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
```
Replace with:
```
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-execute-overnight`](skills/woostack-execute-overnight/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
```

- [x] **Step 3: Fix the "twelve-skill command surface" mention (Edit)**

Find:
```
`/woostack-*` commands: they have no routing row and are absent from the twelve-skill command
```
Replace with:
```
`/woostack-*` commands: they have no routing row and are absent from the thirteen-skill command
```

- [x] **Step 4: Add the command to the Mode B list (Edit)**

Find:
```
**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-plan`, `/woostack-execute`, `/woostack-commit`,
```
Replace with:
```
**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-plan`, `/woostack-execute`, `/woostack-execute-overnight`, `/woostack-commit`,
```

- [x] **Step 5: Bump the rename hard constraint (fourteen → fifteen) (Edit)**

Find:
```
- Do not move or rename any of the fourteen `SKILL.md` files (the twelve public command/adoption
  skills plus the internal `woostack-ideate` and `woostack-harden`).
```
Replace with:
```
- Do not move or rename any of the fifteen `SKILL.md` files (the thirteen public command/adoption
  skills plus the internal `woostack-ideate` and `woostack-harden`).
```

- [x] **Step 6: Add the Quick file map entry (Edit)**

Find:
```
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
```
Replace with:
```
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
- Overnight (unattended, autonomous) plan-execution engine (public command):
  [`skills/woostack-execute-overnight/SKILL.md`](skills/woostack-execute-overnight/SKILL.md)
```

- [x] **Step 7: Verify counts and entries are consistent**

Run: `grep -c -E "thirteen skills|thirteen-skill command|fifteen \`SKILL.md\`|thirteen public command/adoption" AGENTS.md`
Expected: `3` (three matching lines: the count line, the "thirteen-skill command" line — match the unwrapped phrase, since "command" / "surface" wrap across a newline — and the rename-constraint line that carries both "fifteen `SKILL.md`" and "thirteen public command/adoption").

Run: `grep -c "woostack-execute-overnight" AGENTS.md`
Expected: `3` (three matching lines: the list entry, the Mode B list, and the Quick file map link line).

- [x] **Step 8: Commit**

```bash
gt modify -c -m "docs(agents): register woostack-execute-overnight as the 13th command"
```

### Task 7: Update `README.md`

**Files:**
- Modify: `README.md` (install count/list ~line 29, build-loop prose ~line 62, new subsection after the execute subsection ~line 70)

- [x] **Step 1: Bump the install count and list (Edit)**

Find:
```
The public command/adoption surface is twelve skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-plan, woostack-execute, woostack-commit, woostack-review, woostack-address-comments, woostack-status, woostack-visualize, and woostack-debug.
```
Replace with:
```
The public command/adoption surface is thirteen skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-plan, woostack-execute, woostack-execute-overnight, woostack-commit, woostack-review, woostack-address-comments, woostack-status, woostack-visualize, and woostack-debug.
```

- [x] **Step 2: Mention the overnight option in the build-loop prose (Edit)**

Find:
```
Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. It ends on the reviewed PR stack. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)
```
Replace with:
```
Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. The execution-handoff gate lets you Go (execute now), Hand off (execute later/elsewhere), or Run overnight (`woostack-execute-overnight`, unattended). It ends on the reviewed PR stack. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)
```

- [x] **Step 3: Add the skill subsection after the execute one (Edit)**

Find:
```
Executes an approved markdown plan from `.woostack/plans/` as a sequence of PR-sized, stacked increments — implementing each with TDD, ticking the plan's checkboxes in place, committing via `woostack-commit` on its own Graphite branch, reviewing it with `woostack-review --fast`, and distilling durable learnings — pausing only on a blocking review. One plan per spec, multiple PRs per plan. It is the execute phase `woostack-build` step 9 delegates to, and is usable standalone. Never merges. → [SKILL.md](skills/woostack-execute/SKILL.md)
```
Replace with:
```
Executes an approved markdown plan from `.woostack/plans/` as a sequence of PR-sized, stacked increments — implementing each with TDD, ticking the plan's checkboxes in place, committing via `woostack-commit` on its own Graphite branch, reviewing it with `woostack-review --fast`, and distilling durable learnings — pausing only on a blocking review. One plan per spec, multiple PRs per plan. It is the execute phase `woostack-build` step 9 delegates to, and is usable standalone. Never merges. → [SKILL.md](skills/woostack-execute/SKILL.md)

### `/woostack-execute-overnight <plan-path>`: run a plan unattended overnight

Executes an approved plan the way `woostack-execute` does, but **unattended** — one autonomous run with no input after launch. It reuses execute's per-increment cadence and drivers and overrides only the stop-points: a stuck verification routes to `woostack-debug --auto`, a blocking review is auto-addressed (`woostack-address-comments --auto`, bounded) or escalated, and anything unsafe or ambiguous becomes a logged blocker — safety is never relaxed for autonomy. A blocker ends its track (plans may group increments under optional `## Track:` headings; default is one linear stack) and the run continues. It writes a **morning report** to `.woostack/overnight/` for a human to test in the morning. It is the third choice at `woostack-build`'s execution-handoff gate (Go / Hand off / Run overnight), and is usable standalone. Never merges. → [SKILL.md](skills/woostack-execute-overnight/SKILL.md)
```

- [x] **Step 4: Verify README is consistent**

Run: `grep -c "thirteen skills" README.md`
Expected: `1`

Run: `grep -c "woostack-execute-overnight" README.md`
Expected: `4` (install list, build prose, subsection heading, subsection-body SKILL.md link).

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(readme): document woostack-execute-overnight (13th command)"
```

### Task 8: Update `CONTRIBUTING.md`

**Files:**
- Modify: `CONTRIBUTING.md` (surface list ~line 3, pointer-row table after the execute row ~line 25)

- [x] **Step 1: Add to the surface list (Edit)**

Find:
```
The public command/adoption surface is `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-plan`, `woostack-execute`, `woostack-commit`, `woostack-review`, `woostack-address-comments`, `woostack-status`, `woostack-visualize`, and `woostack-debug`.
```
Replace with:
```
The public command/adoption surface is `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-plan`, `woostack-execute`, `woostack-execute-overnight`, `woostack-commit`, `woostack-review`, `woostack-address-comments`, `woostack-status`, `woostack-visualize`, and `woostack-debug`.
```

- [x] **Step 2: Add the pointer row (Edit)**

Find:
```
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
```
Replace with:
```
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
| Change the overnight execute phase (unattended autonomous run, morning report) | `skills/woostack-execute-overnight/SKILL.md` |
```

- [x] **Step 3: Verify**

Run: `grep -c "woostack-execute-overnight" CONTRIBUTING.md`
Expected: `2` (surface list, pointer row).

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs(contributing): point at the overnight execute phase"
```

### Task 9: Document the optional `## Track:` grouping in `woostack-plan`

**Files:**
- Modify: `skills/woostack-plan/SKILL.md` (new section after "## PR-sized increments", before "## Bite-sized tasks (TDD)")

- [x] **Step 1: Insert the track-convention section (Edit)**

Find:
```
decomposition is part of planning (it folds `woostack-build`'s old decompose step into the plan
engine).

## Bite-sized tasks (TDD)
```
Replace with:
```
decomposition is part of planning (it folds `woostack-build`'s old decompose step into the plan
engine).

## Optional: parallel tracks (for overnight runs)

By default the increments form **one linear `gt` stack** — each stacks on the previous, the shape
`woostack-execute` runs. A plan **may** instead group increments under top-level **`## Track:`
headings**; each track is an independent linear stack branched off the common base (the spec+plan
PR). This is **author-driven and optional**: write tracks only when increments are genuinely
independent and you intend an unattended overnight run to parallelize them. Do **not**
auto-partition — default to one implicit track (no headings = today's behavior).

Only [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) consumes tracks (it
runs each track off the base and, on a blocker, ends only that track and advances to the next).
[`woostack-execute`](../woostack-execute/SKILL.md) ignores the headings and runs every increment
as one linear stack.

## Bite-sized tasks (TDD)
```

- [x] **Step 2: Verify the section exists and is author-driven (no auto-partition)**

Run: `grep -c -E "^## Optional: parallel tracks" skills/woostack-plan/SKILL.md`
Expected: `1`

Run: `grep -c "author-driven and optional" skills/woostack-plan/SKILL.md`
Expected: `1`

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(woostack-plan): document the optional ## Track: grouping"
```

### Task 10: Note tree-stacked PRs in the status conventions

**Files:**
- Modify: `skills/woostack-status/references/conventions.md` (Invariant section, after the `spec.branch:` bullet)

- [x] **Step 1: Append the tree-stacked note to the invariant (Edit)**

Find:
```
- `spec.branch:` names the active increment's branch.
```
Replace with:
```
- `spec.branch:` names the active increment's branch.
- An overnight run ([`woostack-execute-overnight`](../../woostack-execute-overnight/SKILL.md)) may
  produce **tree-stacked** increment PRs — multiple `## Track:`s branched off the common base, so a
  spec can have several concurrent increment branches rather than one linear chain. The
  `1 : 1 : N` count, the `**Source:**` join, and the `Spec:` PR trailer are unaffected, and this
  adds **no** new phase-enum value; a blocked/partial overnight run is visible via its
  `.woostack/overnight/` report.
```

- [x] **Step 2: Verify the note exists and adds no enum value**

Run: `grep -c "tree-stacked" skills/woostack-status/references/conventions.md`
Expected: `1`

Run: `grep -c -E "draft -> hardened -> approved -> planning -> executing -> in-review -> done" skills/woostack-status/references/conventions.md`
Expected: `1` (the phase enum is unchanged — no new value added).

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(conventions): note tree-stacked PRs from overnight track runs"
```

### Task 11: Final verification sweep

**Files:** none (read-only checks)

- [x] **Step 1: Both new files exist**

Run: `test -f skills/woostack-execute-overnight/SKILL.md && test -f skills/woostack-execute-overnight/references/report-template.md && echo OK`
Expected: `OK`

- [x] **Step 2: No stale counts remain anywhere**

Run: `grep -rn "twelve skills\|twelve-skill command surface\|fourteen \`SKILL.md\`" AGENTS.md README.md CONTRIBUTING.md`
Expected: no output (exit 1) — every count was bumped.

- [x] **Step 3: The skill is registered in every surface**

Run: `for f in AGENTS.md README.md CONTRIBUTING.md skills/using-woostack/SKILL.md skills/woostack-build/SKILL.md; do printf '%s ' "$f"; grep -c "woostack-execute-overnight" "$f"; done`
Expected: `AGENTS.md 3`, `README.md 4`, `CONTRIBUTING.md 2`, `skills/using-woostack/SKILL.md 1`, `skills/woostack-build/SKILL.md 4`.

- [x] **Step 4: Cross-links in the new skill resolve to real paths**

Run: `for p in skills/woostack-execute skills/woostack-commit skills/woostack-debug skills/woostack-address-comments skills/woostack-review skills/woostack-init skills/woostack-plan; do test -f "$p/SKILL.md" || echo "MISSING $p"; done; test -f skills/woostack-execute/references/inline-driver.md && test -f skills/woostack-execute/references/subagent-driver.md || echo "MISSING driver ref"`
Expected: no output — every cross-linked target exists.

- [x] **Step 5: Report dir is gitignored**

Run: `git check-ignore .woostack/overnight/probe.md`
Expected: `.woostack/overnight/probe.md`

- [x] **Step 6: Track convention — documented in the producer, consumed only by overnight**

Run: `grep -c "## Track:" skills/woostack-plan/SKILL.md skills/woostack-execute-overnight/SKILL.md`
Expected: both files print `>= 1` (producer doc + consumer behavior).

Run: `grep -c "## Track:" skills/woostack-execute/SKILL.md`
Expected: `0` (execute is unchanged — does not consume tracks).

- [x] **Step 7: Status conventions note present and resolves**

Run: `test -f skills/woostack-execute-overnight/SKILL.md && grep -q "tree-stacked" skills/woostack-status/references/conventions.md && echo OK`
Expected: `OK`

- [x] **Step 8:** No separate commit — this task is read-only verification; the plan's checkboxes are ticked in place by `woostack-execute` as the live record.

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec section maps to a task:
  - §4 Command & invocation, Pre-flight, Autonomy overrides (incl. driver-specific review split), Tracks & halt, Morning report, Report git handling → **Task 1** (SKILL.md) + **Task 2** (template) + **Task 3** (gitignore).
  - §4 Wiring `woostack-build` (step 8 three-way, step 9, step 10, constraint) → **Task 4**.
  - §4 Wiring the track convention (`woostack-plan` doc, status note) → **Tasks 9–10**.
  - §5 edit set (using-woostack, AGENTS, README, CONTRIBUTING) → **Tasks 5–8**; (woostack-plan, status conventions, root .gitignore) → **Tasks 9, 10, 3**.
  - §7 Testing (counts consistent, cross-links resolve, driver split documented, track doc, gitignore) → **Task 11**.
- [x] **No placeholders** — Tasks 1 & 2 carry the complete file content; every doc edit gives exact find/replace strings; every verification has an exact command and expected output. The `{{…}}` tokens inside the Task-2 code block are the *report template's own* fill-in slots (the artifact this skill ships), not plan placeholders.
- [x] **Type consistency** — skill name `woostack-execute-overnight`, command `/woostack-execute-overnight <plan-path> [--inline|--subagent]`, link path `../woostack-execute-overnight/SKILL.md` (and `../../` from `woostack-status/references/`), report path `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md`, the four report sections, and the increment-status vocabulary (`done` / `done-with-findings` / `blocked` / `not-attempted`) are used identically across the skill, the template, the build wiring, and the docs.

> woostack plan conventions (kept):
> - Frontmatter-free; opens with the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-06-woostack-execute-overnight.md` (the spec's date).
> - No required sub-skill banner — execution is `woostack-execute` / `woostack-execute-overnight`.
> - This is a docs/skills repo: "failing test" steps are concrete verification commands (`grep`, `test -f`, `git check-ignore`) with exact expected output.
