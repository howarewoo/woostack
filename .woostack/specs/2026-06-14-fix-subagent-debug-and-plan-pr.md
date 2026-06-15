---
name: 2026-06-14-fix-subagent-debug-and-plan-pr
type: spec
status: approved
date: 2026-06-14
branch: feature/fix-subagent-debug-and-plan-pr
links:
---

# Tighten the woostack-fix loop: subagent debug + plan PR before the execute gate — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-14-fix-subagent-debug-and-plan-pr]]

## 1. Problem

The `woostack-fix` loop carries two structural rough edges, both in `skills/woostack-fix/SKILL.md`:

1. **Debug bloats the orchestrator context.** Step 1 runs `woostack-debug` **inline** in the fix-loop session. Debug is a big read fan-out — read errors completely, `git diff`, trace data flow backward across components, pattern-compare working vs broken (`woostack-debug/SKILL.md:41-66`) — but its useful output is the small Phase 4 handback (root-cause summary + proposed minimal fix + TDD context, `woostack-debug/SKILL.md:78-82`). Running it inline leaves all the raw investigation material — file reads, greps, stack traces — resident in the orchestrator that owns the approval gate and the lifecycle, for no further use.

2. **The fix plan is not committed before the execute gate.** Today fix's single hard gate (fix-plan approval, `woostack-fix/SKILL.md:62-63`) sits **before** any commit; the fix markdown stays uncommitted in the fix worktree until `woostack-execute` commits it together with the implementation code. There is no committed, reviewable record of the plan that was approved, and the shape diverges from `woostack-build`, where the spec+plan ship as their own docs-only PR (the stack base) *before* the execution-handoff gate (`woostack-build` steps 7-8).

## 2. Goal

Edit `skills/woostack-fix/SKILL.md` so the fix loop:

1. Can dispatch its step-1 debug investigation to a **read-only investigator subagent** that returns only the Phase 4 handback, keeping the orchestrator context small — selected by a smart default that mirrors `woostack-execute`'s `--inline`/`--subagent` driver.
2. **Commits the fix plan as its own docs-only PR** (the stack base) **before** the approval-to-execute gate, with the code increment stacking on top — mirroring `woostack-build` steps 7-8.

Mode A change (skill-collection edit). No application code. The two changes are independent and ship as two increments under one plan.

## 3. Non-goals

- **Not** changing `woostack-debug` itself — it stays investigative-only, autonomous, no flag (`woostack-debug/SKILL.md:88-93`, `141-142`). Fix decides *where* debug runs; debug's own contract is untouched.
- **Not** delegating `harden` (fix step 3, interactive + writes the fix file) or the lifecycle frontmatter — those stay orchestrator-owned.
- **Not** re-inlining a TDD/commit/distill loop — execution still delegates to `woostack-execute` ([[fix-delegates-to-execute]]).
- **Not** introducing a new shared mode-selection reference file — cross-link `woostack-execute`'s existing prose.
- **Not** expanding fix's single gate into build's full Go / Overnight / Hand off triad — fix keeps one simple approve-to-execute gate.
- **Never** merges.

## 4. Approach

### Increment 1 — delegate debug to a read-only subagent

Rewrite fix step 1 so the debug investigation runs through one of two drivers, selecting with the **same vocabulary** as `woostack-execute`:

- **Flags:** `--inline` / `--subagent`, mutually exclusive; explicit flag wins. **Smart default (no flag):** subagent where the host can spawn (an `Agent`/`Task` tool is available), else inline — the *same* rule as `woostack-execute`, chosen because the whole point is to keep the orchestrator context small (a trivial one-file bug pays a little spawn overhead; the user passes `--inline` to opt out). If `--subagent` is requested but the host cannot spawn, fall back to inline (degraded, say so) or stop — never pretend subagent mode ran. Cross-link `woostack-execute`'s [Execution mode](../woostack-execute/SKILL.md) prose rather than restating the selection logic.
- **inline:** the orchestrator runs `/woostack-debug` itself, as today.
- **subagent:** dispatch a fresh `general-purpose` investigator subagent that runs the `woostack-debug` four-phase analysis and returns **only** the Phase 4 handback (root-cause summary + proposed minimal fix + TDD context). The orchestrator carries that handback into the fix plan's `## 2. Proposed Fix`. `general-purpose` (not `Explore`) because debug must *read errors completely* and trace data flow — `Explore` is excerpt-only and would undercut that.
- **Read-only / no worktree:** state explicitly that the debug subagent never writes code, commits, or `.woostack/` artifacts (governed by `woostack-debug`'s investigative-only contract), so — unlike `woostack-execute`'s implementer subagent — it needs **no worktree and no cwd-pin**. Step 1 runs *before* the fix worktree is created (fix step 2), so there is nothing to pin to. Contrast with [[subagent-self-pins-to-worktree]].
- **No-root-cause wrinkle:** `woostack-debug` stops and asks the user for hints when it cannot find a root cause (`woostack-fix/SKILL.md:27`). A subagent cannot prompt mid-run, so the dispatched investigator must instead **return a blocked status plus what it investigated**, and the orchestrator surfaces that to the user (mirroring `woostack-execute`'s BLOCKED escalation, `woostack-execute/SKILL.md:214-215`).

### Increment 2 — commit the fix plan before the execute gate (build-style docs PR)

Reorder and rewrite the fix procedure so the committed plan PR is the stack base:

```
diagnose → write fix plan → harden
  → commit fix plan as a docs-only PR (stack base) via woostack-commit
  → approval-to-execute GATE
  → execute: code increment stacks as a 2nd PR on top
```

- The fix-plan **docs-only PR** is committed (in the fix-plan worktree, on `fix/<slug>`) and opened *before* the gate. The gate stays fix's single hard gate, with semantics shifted to build's step-8 "approve to execute" (after the docs PR), not pre-commit plan approval.
- **Worktree teardown happens after the gate clears, not right after the docs PR.** Because the approve-to-execute gate sits after the docs PR, the fix-plan worktree must stay **alive across the gate** so a reject/revise can amend the plan cheaply. Lifecycle:
  - **Go** → teardown the fix-plan worktree; `woostack-execute` then **creates a fresh code-increment worktree** off the `fix/<slug>` branch tip (it no longer "verifies and reuses" the step-2 worktree), per the [worktree contract](../woostack-init/references/worktrees.md) §4 (stacked increment k → increment k-1 branch tip).
  - **Revise** → amend the fix plan in the still-alive worktree, re-push the docs PR, re-present at the gate.
  - **Abandon** → close the docs PR, `git worktree remove --force` the worktree, delete the `fix/<slug>` branch.
  This is a deliberate, documented divergence from build's literal "teardown right after the PR" (build can teardown immediately because its gate — spec approval — is *upstream* of the docs PR, whereas fix's single gate is *downstream* of it).
- **Branch shape.** `fix/<slug>` is the docs-PR stack base (holds only the fix markdown). The code-increment branch is created by `woostack-execute` under its normal per-increment naming, stacked on `fix/<slug>`. The fix markdown's `## 3. Implementation Plan` checkboxes are ticked by `woostack-execute` in the **code-increment** worktree (which branches off `fix/<slug>` and so *has* the committed plan), so the ticks ride the **code** PR while the docs PR carries the unticked plan — exactly as build commits the plan in the docs PR and ticks ride increment PRs.
- A fix becomes **2 PRs**: docs base (fix plan) + code increment.

## 5. Components & data flow

Single file edited: `skills/woostack-fix/SKILL.md` (Overview diagram, step 1, steps 2-6 reorder, Hard constraints). Cross-links only — `woostack-execute` SKILL ([Execution mode]) and the worktree contract — no new files, no edits to `woostack-debug` or `woostack-execute`.

Data flow (subagent debug): fix orchestrator → dispatch investigator subagent (target + recalled gotchas) → subagent runs debug Phases 1-4 → returns Phase 4 handback **or** blocked+findings → orchestrator writes Proposed Fix / surfaces blocker.

Data flow (docs PR): fix plan markdown → `woostack-commit` on `fix/<slug>` (docs-only PR, base = resolved base) → approval gate → `woostack-execute` cuts code-increment worktree off `fix/<slug>` tip → code increment PR stacked on the docs PR.

## 6. Error handling

- **`--subagent` on a host that cannot spawn** → fall back to inline and say so, or stop; never silently pretend.
- **Both flags passed** → error, stop and ask which (mirror execute).
- **Debug subagent finds no root cause** → returns blocked + investigated-list; orchestrator surfaces to user and does not proceed to write a guessed fix plan.
- **Docs-PR commit / push fails** → leave the fix-plan worktree, report its path (worktree contract §2 leave-on-failure); do not advance to the gate.
- **Gate rejected → revise** → amend the plan in the still-alive fix-plan worktree, re-push the docs PR, re-present (do not teardown).
- **Gate rejected → abandon** → close the docs PR, `git worktree remove --force` the fix-plan worktree, delete the `fix/<slug>` branch; no code was ever implemented.

## 7. Acceptance criteria

This is a SKILL.md markdown edit; ACs are grep-checkable assertions over `skills/woostack-fix/SKILL.md` plus a clean `woostack-doctor`/`build-index`.

- **AC1 — fix step 1 offers an inline/subagent debug driver with a smart default**
  - happy: the SKILL names both `--inline` and `--subagent` for the debug investigation and the no-flag smart default (subagent where the host can spawn, else inline — the same rule as `woostack-execute`).
  - error: requesting `--subagent` where the host cannot spawn is documented to fall back to inline (stated) or stop — never pretend.
  - edge: passing both flags is documented as an error (stop and ask).
- **AC2 — the debug subagent is documented as read-only, no-worktree, returning only the handback**
  - happy: SKILL states the debug subagent returns only the Phase 4 handback (root-cause + proposed fix + TDD context) and that it needs no worktree / no cwd-pin (runs before the fix worktree).
  - error: SKILL states the no-root-cause case returns a blocked status + what-was-investigated and the orchestrator surfaces it to the user.
  - edge: N/A — mode selection cross-links execute rather than restating (asserted by AC1 + a link presence check).
- **AC3 — the fix procedure commits the fix plan before the approval-to-execute gate**
  - happy: in the SKILL procedure, the "commit the fix plan" step appears **before** the approval-to-execute gate, and the gate is described as approve-to-execute after the docs PR.
  - error: N/A — ordering is a static document property.
  - edge: SKILL states a fix is 2 PRs (docs base + code increment); that the fix-plan worktree is torn down **after the gate clears (on Go)**, not right after the docs PR, with revise/abandon paths documented; and that `woostack-execute` cuts a fresh code-increment worktree off the `fix/<slug>` tip (no longer reuses the step-2 worktree).
- **AC4 — invariants preserved**
  - happy: SKILL still delegates execution to `woostack-execute`, keeps harden + lifecycle frontmatter orchestrator-owned, and states "never merge."
  - error: N/A.
  - edge: `woostack-debug` and `woostack-execute` SKILLs are unchanged by this work (no edits outside `woostack-fix/SKILL.md` except cross-link targets that already exist).

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

No code runner (markdown skills repo). Verification is grep-based assertions over `skills/woostack-fix/SKILL.md` for the tokens/orderings in §7, run as explicit shell checks per plan task, plus `woostack-init`'s `build-index.sh` and `woostack-doctor` (or `doctor.sh`) ending clean. Ordering ACs (AC3) verified by comparing line numbers of the "commit fix plan" step vs the gate via `grep -n`.

## 9. Open questions

Resolved during ideate: flag vocabulary = execute's `--inline`/`--subagent`; cross-link not a new ref file; `general-purpose` investigator; build-style 2-PR docs base.

Resolved during spec harden:
- **Worktree teardown timing** → teardown **after the gate clears (on Go)**, keeping the fix-plan worktree alive across the gate so reject/revise/abandon are cheap (a documented divergence from build's "teardown right after the PR", because fix's single gate is *downstream* of the docs PR while build's is upstream). See §4 increment 2 and §6.
- **No-flag smart default** → **subagent where the host can spawn, else inline** — the same rule as `woostack-execute` (serves the context-bloat goal; `--inline` opts out). See §4 increment 1 and AC1.

None remaining. Sequencing nuances are for the plan harden (build step 6).
