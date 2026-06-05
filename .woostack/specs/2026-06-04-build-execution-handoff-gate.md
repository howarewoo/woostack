---
name: build-execution-handoff-gate
type: spec
status: done
date: 2026-06-04
branch: worktree-nested-wishing-hanrahan
links:
  - "[[2026-06-04-woostack-execute]]"
  - "[[2026-06-04-woostack-harden]]"
---

# woostack-build: execution-handoff gate — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-build` chains plan-harden (step 6) → commit spec+plan PR (step 7) → execute
(step 8) with **no stop** between planning and implementation. The chain auto-flows straight
into `woostack-execute` once the spec+plan PR is open.

That denies a real workflow: **plan in Claude Code, execute somewhere else** — a later
session, or a different tool (e.g. Codex). There is no boundary at which build pauses and
hands the user the just-produced plan so they can take implementation elsewhere instead of
letting the same session barrel into execute.

The current design actively forbids a stop there. The skill states **3×** that it adds no
gate of its own:

- Overview: *"inherits their gates — it adds none of its own"* and *"the chain still has
  exactly the two hard gates."*
- Step 6: *"do not invent a plan-approval gate here."*
- Hard constraints: *"Inherit gates, add none"* and *"Harden twice, gate once… Never add a
  plan-approval gate."*

So the change is not a mechanical insertion — it overturns a documented invariant and must
reconcile the doctrine honestly.

## 2. Goal

Add **one hard execution-handoff gate** to `woostack-build`, placed **after step 7 (spec+plan
PR), before execute**. On reaching it, build halts and surfaces the handoff artifacts — the
plan file path (`.woostack/plans/…`), the spec+plan PR URL, and **on demand** a
`woostack-visualize` render of the plan (audience `engineer`) — then offers two ways forward:

- **Go** → run `woostack-execute` in this session (current behavior).
- **Hand off** → stop. The user takes the plan PR and executes elsewhere (Codex, a later
  session via `/woostack-execute <plan-path>`, etc.).

The gate is a **handoff boundary, not a quality approval** — harden already owns plan quality.
Build halts and asks **every run**; the user decides per-run.

## 3. Non-goals

- **Not a plan-quality / plan-approval gate.** Harden (step 6) owns plan quality and stays
  gate-free. This gate is purely the plan→execute handoff boundary.
- **No flag or config toggle.** A gate inherently asks each run; no opt-in/opt-out. (YAGNI —
  the user did not ask for a toggle.)
- **No change to the design gate (step 1) or spec gate (step 3).**
- **No change to `woostack-execute` internals.** It is still invoked unchanged on "go," and
  remains standalone-invocable via `/woostack-execute <plan-path>` for the handoff path.
- **No Codex/other-tool integration.** The handoff target is the user's; build only stops and
  hands over the artifacts.
- **No new files or assets.** Single-file edit to `skills/woostack-build/SKILL.md`.

## 4. Approach

Edit `skills/woostack-build/SKILL.md` only. Reconcile the doctrine honestly: **build inherits
two gates (design, spec) and adds exactly one of its own — the execution handoff — because the
plan→execute boundary belongs to no sub-skill.** Hard-gate count goes **2 → 3**.

Placement detail: step 7 (commit spec+plan as a PR) **produces the handoff artifact**, so the
gate lands **after** step 7 and **before** execute — inside the user's "between harden-plan and
executing" span. Build runs harden → commit-the-plan-PR → **halt**.

Rejected alternative (**B — always-terminal at the plan PR**): build never runs execute
itself, always ending at the spec+plan PR. Simpler doctrine but kills the integrated
implement→review→distill path step 8 gives today. Rejected — keep both paths; the stop just
always asks.

## 5. Components & data flow

The "components" are the sections of `SKILL.md` that change. Updated build chain:

```
ideate → write spec → harden spec → approve spec → writing-plans → decompose
  → harden plan → commit spec+plan PR → STOP before execute (handoff gate)
  → execute (per increment) → reviewed PR stack
```

Edits, in file order:

1. **Overview prose.** Drop *"it adds none of its own"*; reword to "inherits two gates, adds
   one of its own — the execution handoff — because the plan→execute boundary belongs to no
   sub-skill." Update the ASCII chain to insert the handoff stop before execute. Change
   *"exactly two hard gates"* → **three**: design approval, spec approval, **execution
   handoff**.
2. **Hardening paragraph.** Keep "harden runs twice; neither harden feeds a gate of its own"
   — but stop asserting "exactly two hard gates." Clarify the handoff gate is **build-owned**
   and sits *after* the spec+plan PR (step 7), independent of harden.
3. **Step 6 wording.** The line *"do not invent a plan-approval gate here"* stays true (harden
   adds none) but is reworded to point forward: the new gate is not a plan-*quality* approval
   at step 6 — it is the execution-*handoff* stop placed after step 7.
4. **New step 8 — "Stop before execute (handoff gate)."** Hard stop. Present plan path +
   spec+plan PR URL; user picks **go** (invoke `woostack-execute` here) or **hand off** (stop;
   resume later/elsewhere via `/woostack-execute <plan-path>` or the plan PR). Renumber old
   step 8 (execute) → **9**, old step 9 (terminal state) → **10**, fixing internal
   cross-references ("step 7 and `woostack-execute`…").
   - **Step 10 now documents two terminal shapes:** (a) **hand off** → only the spec+plan PR
     is open, no increment PRs, ready for external/later execute; (b) **go** → the full
     reviewed stack (spec+plan PR base + a reviewed increment PR per step). **"Never merges"
     holds for both.**
   - **Gate prompt offers an on-demand `woostack-visualize` render** of the plan (audience
     `engineer`) alongside the path + PR URL. This is presentation-on-demand; the markdown
     plan stays source of truth. It does **not** contradict step 4's "plans are working
     checklists, not visualization artifacts" — that line governs *authoring* (plans are not
     authored as HTML), not whether a plan may be rendered on request. **Step 4 is left
     unchanged.**
5. **Hard constraints.** Rewrite *"Inherit gates, add none"* → "Inherit two, add one (the
   execution handoff)." Rewrite *"Harden twice, gate once"* → harden feeds one gate (spec);
   plan harden feeds none; the handoff gate is separate and build-owned. **Add a bullet:**
   *"Stop before execute. Never auto-run execute; always halt at the handoff gate after the
   spec+plan PR. The plan PR is the artifact for executing here or in another tool."*

Data flow at the gate: inputs = plan path + spec+plan PR URL (both already in hand from steps
4–7). Output = a user decision (go | hand off) that branches to execute-here vs. stop.

## 6. Error handling

- **Ambiguous / no answer at the gate → treat as stop.** Mirror the spec-gate discipline:
  silence is not a "go." Never auto-run execute without an explicit go-ahead.
- **Handoff path resumes cleanly.** "Hand off" leaves the spec+plan PR open and the plan file
  on disk; `/woostack-execute <plan-path>` already supports resuming in a fresh session, so no
  new resume machinery is needed.
- **Doctrine drift.** Risk is leaving a stale "two gates / add none / gate once" assertion
  somewhere in the file. Mitigate by grep-sweeping the file for `two hard gates`, `add none`,
  `gate once`, `adds none`, and `plan-approval` after editing, and confirming each surviving
  hit is intentional and consistent with "three gates."

## 7. Testing

No automated tests — this repo ships skills, not app code (per `AGENTS.md`: no app CI/tests).
Verification is manual review of the edited `SKILL.md`:

- **Gate-count consistency:** every "two hard gates" / "add none" / "gate once" claim updated
  to the three-gate framing or removed; grep sweep clean.
- **Chain + numbering:** ASCII chain shows the handoff stop before execute; steps renumber to
  10 with no dangling cross-references.
- **Step 6 non-contradiction:** still says harden adds no gate, now points to step 8 instead
  of forbidding the handoff gate.
- **Hard-constraints parity:** the doctrine bullets and the new "Stop before execute" bullet
  agree with Overview and the procedure.
- **Frontmatter description** left unchanged (OQ1 resolved) and still reads true.
- **Step 4 untouched:** the gate's on-demand visualize render does not contradict "plans are
  working checklists, not visualization artifacts" (that line governs authoring).

## 8. Open questions

1. **Description frontmatter.** ✅ Resolved. **Leave as-is.** The handoff gate is procedure
   detail, not a discovery signal; the current description still reads true.
2. **woostack-build's own gate-philosophy framing.** ✅ Resolved. Use the explicit,
   count-based framing: **"build inherits two gates (design, spec) and adds exactly one of its
   own — the execution handoff."** 3 hard gates, stated plainly, so every downstream "three
   gates" claim stays checkable. The softer "owns the seam" wording is rejected — it blurs the
   count and risks the same drift that made the old doctrine self-contradictory.
3. **Visualize affordance at the gate.** ✅ Resolved. **Offer it.** The gate prompt includes
   an on-demand `woostack-visualize` render of the plan (audience `engineer`) alongside the
   path + PR URL. Presentation-on-demand only; markdown plan stays source of truth; step 4
   unchanged (see Components §5.4).
4. **Installed copy.** ✅ Resolved. `~/.claude/skills/woostack-build` symlinks to
   `~/.agents/skills/woostack-build` — a separate installed copy, not this repo. Repo
   `skills/woostack-build/SKILL.md` is source of truth; the installed copy re-syncs on
   `skills add`. **Repo-only edit; installed copy out of scope.**
