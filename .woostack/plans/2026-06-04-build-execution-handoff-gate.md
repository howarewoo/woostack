# woostack-build Execution-Handoff Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In the woostack loop this plan is executed by [`woostack-execute`](../../skills/woostack-execute/SKILL.md).

**Goal:** Add one hard execution-handoff gate to `woostack-build` between the spec+plan PR (step 7) and execute, taking the chain from 2 hard gates to 3 and letting the user plan in Claude Code then execute later or elsewhere.

**Architecture:** Single-file documentation edit to `skills/woostack-build/SKILL.md`. Five coherent text edits (Overview, step 6, new step 8 + renumber, hard constraints) plus a grep-sweep verification. No code, no new files, no app tests — this repo ships skills.

**Tech Stack:** Markdown (skill prose). Verification via `grep`/`rg` and manual read.

**Spec:** [`.woostack/specs/2026-06-04-build-execution-handoff-gate.md`](../specs/2026-06-04-build-execution-handoff-gate.md)

**Scope:** One PR-sized increment (~60 changed lines, one file). Executed as a single stacked increment on top of the spec+plan PR.

---

## Task 1: Reframe the Overview (prose, ASCII chain, gate count, hardening paragraph)

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (Overview section, lines ~10–29)

- [ ] **Step 1: Reword the "thin glue" intro — build now adds one gate**

Replace:

```
Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills and **inherits their gates** — it adds none of
its own. The value is the order and the handoffs.
```

With:

```
Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills, **inherits their two gates** (design, spec) **and
adds exactly one of its own** — the execution handoff — because the plan→execute boundary
belongs to no sub-skill. The value is the order and the handoffs.
```

- [ ] **Step 2: Insert the handoff stop into the ASCII chain**

Replace:

```
ideate → write spec (markdown) → harden spec → approve spec → writing-plans → decompose
  → harden plan → commit spec+plan as their own PR → execute (per increment: implement →
  commit → review → distill) → reviewed PR stack
```

With:

```
ideate → write spec (markdown) → harden spec → approve spec → writing-plans → decompose
  → harden plan → commit spec+plan as their own PR → stop before execute (handoff gate)
  → execute (per increment: implement → commit → review → distill) → reviewed PR stack
```

- [ ] **Step 3: Update the "two gates" paragraph to three**

Replace:

```
Two of those gates are hard stops where the user must say yes before the chain advances:
**design approval** (owned by `woostack-ideate`, step 1) and **spec approval** (step 3).
The spec-approval gate is the "user reviews the written spec" step that
`superpowers:brainstorming` used to own; because woostack-build relocated the spec write into
its own step 2, the gate lives here now. Relocating an inherited gate is not adding one.
```

With:

```
Three of those gates are hard stops where the user must say yes before the chain advances:
**design approval** (owned by `woostack-ideate`, step 1), **spec approval** (step 3), and the
**execution handoff** (step 8). The spec-approval gate is the "user reviews the written spec"
step that `superpowers:brainstorming` used to own; because woostack-build relocated the spec
write into its own step 2, the gate lives here now — relocating an inherited gate is not adding
one. The execution-handoff gate is build's own: no sub-skill owns the plan→execute boundary, so
build adds it to let you stop after planning and execute later or elsewhere.
```

- [ ] **Step 4: Update the hardening paragraph (gate count → three)**

Replace:

```
Hardening runs **twice** — once on the spec (step 3) and once on the plan (step 6) — but only
the spec harden feeds a gate. The plan harden amends the plan in place and hands straight back,
and committing the spec+plan PR (step 7) is a work step, not an approval stop. Neither adds a
gate: the chain still has exactly the two hard gates above.
```

With:

```
Hardening runs **twice** — once on the spec (step 3) and once on the plan (step 6) — but only
the spec harden feeds a gate (the spec-approval gate, step 3). The plan harden amends the plan
in place and hands straight back, and committing the spec+plan PR (step 7) is a work step, not
an approval stop. The execution-handoff gate (step 8) is build-owned, not harden-owned, and
sits after that PR. So the chain has exactly the three hard gates above.
```

- [ ] **Step 5: Verify the Overview reads coherently**

Run: `sed -n '8,35p' skills/woostack-build/SKILL.md`
Expected: intro says "adds exactly one"; chain shows "stop before execute (handoff gate)"; gate paragraph lists three gates; hardening paragraph says "three hard gates". No remaining "adds none of its own" or "exactly the two hard gates".

---

## Task 2: Reword step 6 (plan harden points forward to the handoff gate)

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (step 6, lines ~80–85)

- [ ] **Step 1: Replace the step 6 tail**

Replace:

```
   Amend the plan markdown in place as answers land. This adds **no approval gate**: harden
   owns none and hands straight back. The spec-approval gate (step 3) remains the chain's last
   hard stop; do not invent a plan-approval gate here.
```

With:

```
   Amend the plan markdown in place as answers land. This adds **no approval gate**: harden
   owns none and hands straight back. The chain's last hard stop is the **execution-handoff
   gate (step 8)**, after the spec+plan PR — not a plan-*quality* gate here. Do not turn this
   harden into a plan-approval gate.
```

- [ ] **Step 2: Verify step 6**

Run: `sed -n '80,86p' skills/woostack-build/SKILL.md`
Expected: still says "adds **no approval gate**"; now points to step 8 as the last hard stop; no "spec-approval gate (step 3) remains the chain's last hard stop".

---

## Task 3: Insert new step 8 (handoff gate) and renumber execute → 9, terminal → 10

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (steps 8–9, lines ~86–100)

- [ ] **Step 1: Insert the new step 8 immediately after step 7**

Find the end of step 7 (the line ending `merged** by build. This is a work step, not an approval stop.`) and the start of the current step 8. Replace the current step 8 header line:

```
8. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the plan path to
```

With the new step 8, then the renumbered step 9 header:

```
8. **Stop before execute (execution-handoff gate).** After the spec+plan PR is open, **halt** —
   this is a hard gate. Surface the handoff artifacts: the plan path (`.woostack/plans/…`), the
   spec+plan PR URL, and — on request — a
   [`woostack-visualize`](../woostack-visualize/SKILL.md) render of the plan (audience
   `engineer`). Then ask the user to choose:
   - **Go** → proceed to step 9 and run `woostack-execute` in this session.
   - **Hand off** → stop here. The user takes the plan PR and executes later or elsewhere (e.g.
     Codex, or a fresh session via `/woostack-execute <plan-path>`).
   Ambiguous or no answer is **not** a "go": never auto-run execute without an explicit
   go-ahead. This is the chain's last hard gate.
9. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the plan path to
```

(The body of the old step 8 — "work the plan as PR-sized stacked increments …" through "… separate
'distill memory' and 'offer the PR' steps here." — is unchanged; only its number becomes 9.)

- [ ] **Step 2: Renumber and rewrite the terminal step (old 9 → 10, two terminal shapes)**

Replace:

```
9. **End on the reviewed stack.** The terminal state is a Graphite stack with the spec+plan PR
   at the base and a reviewed increment PR above each step. Build does not separately ask to
   open a PR (step 7 and `woostack-execute` open them as work steps) and **never merges**.
```

With:

```
10. **End on the chosen terminal state.** Build ends in one of two shapes, never merging either:
    - **Hand off** → only the spec+plan PR is open (no increment PRs), ready for external or
      later execute.
    - **Go** → a Graphite stack with the spec+plan PR at the base and a reviewed increment PR
      above each step.
    Build does not separately ask to open a PR (step 7 and `woostack-execute` open them as work
    steps) and **never merges**.
```

- [ ] **Step 3: Fix the in-prose step-number reference inside step 7**

Step 7's body points at the execute step by number ("execution increments (step 8)"); execute is now step 9, so this reference must follow. Replace:

```
increments (step 8) stack on top of it via `gt create`.
```

With:

```
increments (step 9) stack on top of it via `gt create`.
```

(This is the **only** in-prose `step 8` reference in the file — verified by grep before planning; all other `step 8` mentions are introduced by Task 1/3/4 and correctly point at the new handoff gate.)

- [ ] **Step 4: Verify the procedure numbering**

Run: `grep -nE '^[0-9]+\. \*\*' skills/woostack-build/SKILL.md`
Expected: exactly ten numbered steps, 1–10, in order; step 8 is "Stop before execute (execution-handoff gate)", step 9 is "Execute", step 10 is "End on the chosen terminal state". No duplicate or skipped numbers.

Run: `grep -noE 'step [0-9]+' skills/woostack-build/SKILL.md | sort | uniq -c`
Expected: every `step N` reference resolves to a real step 1–10; the lone `step 9` mention is step 7's body pointing at execute; no `step 8` mention points at execute (all `step 8` now mean the handoff gate).

---

## Task 4: Rewrite the hard constraints (doctrine + new "Stop before execute" bullet)

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (Hard constraints, lines ~104–117)

- [ ] **Step 1: Replace the first two doctrine bullets**

Replace:

```
- **Inherit gates, add none.** Do not insert *extra* approval stops between phases. The two
  inherited hard gates are non-negotiable: **design approval** (step 1) and **spec approval**
  (step 3). The plan harden (step 6) and the spec+plan PR (step 7) are work steps, not gates.
- **Harden twice, gate once.** Harden the spec (step 3, feeds the spec-approval gate) and the
  plan (step 6, amends in place, no gate). Never add a plan-approval gate.
```

With:

```
- **Inherit two gates, add one.** Do not insert *extra* approval stops beyond the three hard
  gates: **design approval** (step 1) and **spec approval** (step 3), both inherited, plus the
  **execution handoff** (step 8), which build owns because the plan→execute boundary belongs to
  no sub-skill. The plan harden (step 6) and the spec+plan PR (step 7) are work steps, not gates.
- **Harden twice, neither harden gates.** Harden the spec (step 3, feeds the spec-approval gate)
  and the plan (step 6, amends in place, no gate). The execution-handoff gate (step 8) is
  separate and build-owned, not a plan-*quality* gate; never turn the plan harden into a
  plan-approval gate.
```

- [ ] **Step 2: Add the "Stop before execute" bullet before the "Never merge" bullet**

Replace:

```
- **Never merge.** build ends on the reviewed PR stack, nothing further.
```

With:

```
- **Stop before execute.** Never auto-run execute; always halt at the execution-handoff gate
  (step 8) after the spec+plan PR. The plan PR is the artifact for executing here or in another
  tool. Ambiguous or no answer is not a "go."
- **Never merge.** build ends on the terminal state (handoff PR, or reviewed stack), nothing
  further.
```

- [ ] **Step 3: Verify the hard constraints**

Run: `sed -n '/## Hard constraints/,$p' skills/woostack-build/SKILL.md`
Expected: first bullet "Inherit two gates, add one"; second "Harden twice, neither harden gates"; a "Stop before execute" bullet present; "Never merge" mentions both terminal shapes. No "Inherit gates, add none" or "Harden twice, gate once".

---

## Task 5: Doctrine grep-sweep + full-file consistency read

**Files:**
- Read-only: `skills/woostack-build/SKILL.md`

- [ ] **Step 1: Grep-sweep for stale doctrine**

Run: `grep -nE 'two hard gates|add none|adds none|gate once|exactly two' skills/woostack-build/SKILL.md`
Expected: **no matches.** Any match is a stale assertion to fix.

- [ ] **Step 2: Confirm surviving "plan-approval gate" / "three" usages are intentional**

Run: `grep -nE 'plan-approval gate|three hard gates|three of those gates|adds exactly one|add one' skills/woostack-build/SKILL.md`
Expected: every "plan-approval gate" hit is in a *forbidding* sentence ("do not turn… into a plan-approval gate"); "three" hits describe the gate count; "adds exactly one / add one" hits are the doctrine reframe. No hit asserts a plan-approval gate exists.

- [ ] **Step 3: Full read for coherence**

Run: `cat skills/woostack-build/SKILL.md`
Expected (manual check against spec §7 Testing):
- Gate-count consistency: every gate-count claim says three (or names the three gates).
- Chain + numbering: ASCII chain shows the handoff stop before execute; steps numbered 1–10, no dangling cross-references (e.g. "step 7 and `woostack-execute`" still resolves; no reference to a now-wrong step number).
- Step 6 non-contradiction: says harden adds no gate, points to step 8.
- Hard-constraints parity: doctrine bullets + "Stop before execute" bullet agree with Overview and procedure.
- Frontmatter `description:` unchanged and still true.
- Step 4 untouched ("plans are working checklists, not visualization artifacts" still present).

- [ ] **Step 4: Commit**

Executed by `woostack-execute` via [`woostack-commit`](../../skills/woostack-commit/SKILL.md) on this increment's Graphite branch (stacked on the spec+plan PR). Suggested message:

```
feat(build): add execution-handoff gate before execute
```

---

## Self-Review (run by the plan author before handing off)

**1. Spec coverage** — every spec §5 edit mapped to a task:
- §5.1 Overview prose + ASCII chain → Task 1 (Steps 1–4)
- §5.2 Hardening paragraph → Task 1 (Step 4)
- §5.3 Step 6 wording → Task 2
- §5.4 New step 8 + renumber + two terminal shapes + visualize affordance → Task 3
- §5.5 Hard constraints + "Stop before execute" bullet → Task 4
- §6 Error handling (ambiguous → stop) → encoded in step 8 text (Task 3) + "Stop before execute" bullet (Task 4)
- §7 Testing (grep sweep + consistency read) → Task 5

**2. Placeholder scan** — every edit shows exact old/new text; no TBD/TODO; verification commands have expected output. Clean.

**3. Consistency** — gate naming ("execution-handoff gate" / "execution handoff"), step numbers (8 gate, 9 execute, 10 terminal), and doctrine phrasing ("adds exactly one", "three hard gates") match across all tasks and the spec.
