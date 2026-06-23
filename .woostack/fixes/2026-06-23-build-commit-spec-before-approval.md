---
type: fix
status: hardened
branch: fix/build-commit-spec-before-approval
---

# Fix: build loop commits the spec only after the spec-approval gate, so it can't be reviewed in a PR

## 1. Root Cause

This is an **enhancement to documented behavior, not a defect** — so there is no data-flow bug
to trace; the build loop behaves exactly as written. `woostack-debug`'s four-phase analysis does
not apply (nothing is broken). The "root cause" is a **sequencing decision** in
[`skills/woostack-build/SKILL.md`](../../skills/woostack-build/SKILL.md):

- **Step 2** writes the spec markdown in the `feature/<slug>` worktree.
- **Step 3** hardens the spec and runs the **spec-approval gate** — but the spec is presented
  **by file path** (or an on-demand `woostack-visualize` render), because nothing has been
  committed yet. `SKILL.md:68-69`: *"Point the user at the file path (offer a `woostack-visualize`
  render if it helps)."*
- The spec is **not committed until step 7** (`SKILL.md:94-102`), and only **together with the
  plan**, as the spec+plan base-of-stack PR — which happens **after** the spec gate **and after
  planning**.

So at the moment the user is asked to approve the spec, there is **no PR and no commit** to review
— only a raw markdown file inside a worktree they would have to open. The user wants to review the
spec **in the PR**, the same way `woostack-fix` already lets them: `woostack-fix` commits its
hardened plan **before** its approval gate (`woostack-fix` step 3 → 4) precisely so the artifact is
"a committed artifact instead of opening the worktree."

**Evidence.** Current build-loop order (Overview diagram, `SKILL.md:16-17`):

```
ideate → write spec → harden spec → approve spec → plan → ... → commit spec+plan as their own PR
```

`approve spec` precedes `commit spec+plan`, so the spec PR cannot exist at approval time. The
authored docs site mirrors this: [`site/content/docs/concepts/building-rules.mdx:14`](../../site/content/docs/concepts/building-rules.mdx)
shows `... → **approve spec** → plan → harden plan → ship spec+plan PR`.

## 2. Proposed Fix

Move the **spec commit + PR open before the step-3 spec-approval gate**, mirroring `woostack-fix`'s
commit-before-gate pattern. The PR is the **same** spec+plan base-of-stack PR — it simply opens
earlier, containing only the spec, and the **plan is appended to it** at step 7. No new gate, no
new PR, no new `status:` enum value, no change to the `spec : plan : PRs = 1 : 1 : N` invariant.

New step-3 / step-7 shape (everything else in the loop unchanged):

- **Step 3** — harden the spec → set `status: hardened` → **commit the spec** via
  [`woostack-commit`](../../skills/woostack-commit/SKILL.md) on the existing `feature/<slug>`
  branch, opening the spec+plan base PR (initially **spec-only**) → present **the PR** for spec
  approval → on a clear yes, set `status: approved`.
  - **Revise** → amend the spec in the still-alive worktree, **commit** the revision on the same
    branch, re-present at the gate (revisions are committed before re-presenting, exactly as
    `woostack-fix` requires).
  - **Abandon** → `git worktree remove --force` the worktree, delete the `feature/<slug>` branch,
    **and close the now-open PR** (the one wrinkle the early commit introduces).
- **Steps 4–6** — plan, verify decomposition, harden plan (unchanged, same worktree).
- **Step 7** — **append the plan** to the **same** `feature/<slug>` branch/PR via
  `woostack-commit` (the base PR now holds spec **and** plan) → tear down the worktree. Still
  "spec+plan ship as their own PR, never merged" — the spec was just committed earlier and the
  plan appended.

Why this is safe / minimal:

- **Gate count unchanged (3).** The spec commit is folded into step 3 **before** the existing
  spec-approval gate as a work step; it adds no approval stop. Design-approval (step 1),
  spec-approval (step 3), execution-handoff (step 8) are untouched.
- **No phase-enum churn.** The spec lifecycle stays `draft`→`hardened`→`approved`→`planning`→
  `ready`; only the *commit* moves earlier. (Avoids the 8-file enum wiring of
  [[woostack-add-phase-enum-value]].)
- **Worktree already spans the gate.** The `feature/<slug>` worktree is created in step 2 and
  lives through step 7 today; it now simply carries a commit at step 3 and survives the gate's
  Revise loop — same lifecycle `woostack-fix`'s worktree already has across *its* gate.
- **`woostack-commit` is append-capable.** First invocation (step 3) commits the spec and opens
  the PR; second (step 7) commits the plan and updates the same PR's title/body — the identical
  mechanism `woostack-fix` relies on when `woostack-execute` later appends code to the fix PR.

## 3. Implementation Plan

**Hardened decisions** (resolved by reading the build/fix skills + the worktree contract; no
behavior change beyond the stated reorder):

- **Same single base PR, opened earlier.** The early commit opens the *existing* spec+plan
  base-of-stack PR (spec-only at first); step 7 appends the plan. There is **no** separate
  spec-only PR and **no** second PR — the `1:1:N` invariant and "base of the stack" role hold.
- **Spec gate presents the PR.** Step 3 points the user at the **PR URL** (file path / visualize
  render become secondary), matching `woostack-fix` step 4's "point at the committed file path,
  the reviewable commit, and PR URL."
- **Abandon closes the PR.** Because the PR is now open at the spec gate, Abandon must also close
  it (in addition to `git worktree remove --force` + branch delete). Documented on the gate and in
  Hard constraints.
- **No new gate; commit is a work step.** Reinforce in Overview + Hard constraints that the
  early spec commit is a work step, not an approval stop — the loop keeps **exactly three** hard
  gates.
- **Site sync is in scope.** [`building-rules.mdx`](../../site/content/docs/concepts/building-rules.mdx)
  line 14's loop diagram and line 25's "Spec approval … when written spec presented" must reflect
  that the spec PR opens at/before approve-spec. Required by the CLAUDE.md "keep authored site
  pages in sync" constraint.
- **Verification = content-assertion test + site build** (no runner for skill markdown, per the
  [woostack-tdd kernel](../../skills/woostack-tdd/SKILL.md) "no-runner → concrete verification").
  `woostack-build` has **no** `scripts/` today (only `references/`), and `assert_contains` is
  defined **per test file inline** (e.g. `test-address-comments-ownership.sh`), not a shared lib —
  so step 1 **creates one self-contained** test file with an inline `assert_contains`, mirroring
  that house style. Assert pure-ASCII substrings (per [[skill-test-assert-ascii-token]]).

- [ ] **Step 1: Reproduce with a failing test**
  - No build SKILL content test exists today (`woostack-build` has only `references/`). Create a
    self-contained `skills/woostack-build/scripts/tests/test-build-spec-commit-ordering.sh` with an
    inline `assert_contains`, mirroring `test-address-comments-ownership.sh`.
  - Pin the new ordering with ASCII assertions that are **absent today**, e.g.:
    - SKILL Overview diagram orders the spec PR **before** approve-spec (assert a token such as
      `commit spec PR` / `ship spec PR` appears before `approve spec`).
    - A step-3 substring like `commit the spec` + `before` + `spec-approval gate`.
    - An Abandon substring like `close the` … `PR` (PR-close on abandon).
    - `building-rules.mdx` diagram shows the spec PR before `approve spec`.
  - Run it and confirm it **fails** (tokens absent in current docs).
- [ ] **Step 2: Apply the minimal fix**
  - **`skills/woostack-build/SKILL.md`:**
    - Overview diagram (`:16-17`): reorder to `... → harden spec → commit spec PR → approve spec →
      plan → harden plan → append plan to spec+plan PR → execution handoff → execute`.
    - Overview gate prose (`:21-32`): note the spec is committed (PR opened) **before** the
      step-3 gate; keep "exactly three hard gates"; the early commit + the plan-append are work
      steps, not approval stops.
    - Step 3 (`:64-71`): after `status: hardened`, **commit the spec** via `woostack-commit` on
      `feature/<slug>` (opens the spec-only base PR); present **the PR** for approval; on yes set
      `status: approved`. Document Revise = amend+commit+re-present, Abandon = remove worktree +
      delete branch + **close the PR**.
    - Step 7 (`:94-102`): reframe as **append the plan** to the already-open `feature/<slug>`
      base PR via `woostack-commit` (spec was committed at step 3); tear down the worktree after.
    - `## Hard constraints`: add a **"Commit the spec before its approval gate"** bullet (mirroring
      `woostack-fix`'s "Commit the plan before approval"); update the "Spec+plan ship as their own
      PR" bullet to say the spec is committed at the gate and the plan appended before execution;
      keep "Inherit two gates, add one" intact (still 3 gates).
  - **`site/content/docs/concepts/building-rules.mdx`:** update the line-14 loop diagram and the
    line-25 spec-approval sentence to reflect the spec PR opening at/before approve-spec.
- [ ] **Step 3: Verification**
  - Re-run the content-assertion test → passes.
  - `pnpm -C site build` → site still builds (authored page in sync).
  - `bash skills/woostack-doctor/scripts/checks/*.sh` (or `/woostack-doctor --check`) → no new
    workspace/template drift.
  - Re-read the Overview + Hard constraints to confirm the gate count is still **three** and the
    `1:1:N` invariant is intact.
