---
name: woostack-sweep
description: Use to drive a stack of stacked PRs to a clean review — sweep each increment PR bottom-up (woostack-review --full → woostack-address-comments → restack this stack only → re-review), bounded by review_sweep.max_rounds plus a no-progress guard, to a clean verdict or approved-with-only-nits. Autonomous by default; stops and reports on a blocker. The single home of the review-sweep loop, reused by woostack-execute-overnight per track. Never merges.
---

# woostack-sweep

Drive a stack of stacked PRs to a **clean review**, bottom-up: for each increment PR from the
base of the stack upward, loop `woostack-review --full` → (if not clean)
`woostack-address-comments` → restack this stack only → re-review, until the PR is clean (no
blocking findings + zero unresolved threads) or the bounded loop stops. This is the single home
of woostack's **review sweep** — [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md)
delegates to it per track; a human invokes it directly on any Graphite stack. It **never merges**.

## Commands

- `/woostack-sweep` — infer the stack from the current Graphite branch (`gt log` / `gt stack`) and
  sweep every increment PR strictly **above `--base`**, bottom-up to the tip.
- `/woostack-sweep <PR#>` — sweep the stack **containing** that PR instead of the current branch's
  stack.
- `--base <ref|PR#>` — **exclusive** lower floor of the swept range; default the resolved trunk
  (`WOOSTACK_BASE_BRANCH`, [worktree contract](../woostack-init/references/worktrees.md) §1). A
  caller (e.g. overnight) passes a base PR/branch to exclude a docs-only base PR.
- `--interactive` — gate each PR's address step (defer to `woostack-address-comments`' own
  per-fix gate). Default is autonomous: pass `--auto` down so the sweep never stalls per-fix.

An unresolvable stack or an empty `--base`..tip range → report **"nothing to sweep"** and exit 0.

## Resolve the stack

- **Current stack** (no `<PR#>`): the chain of branches from `--base` (exclusive) up to the
  current branch tip, via `gt log` / `gt stack`.
- **Named `<PR#>`**: resolve the stack **containing** that PR from `gt` / `gh` metadata **without
  checking out the primary tree** ([worktree contract](../woostack-init/references/worktrees.md)
  §3 — the primary tree is never edited).
- Map each in-range branch to its open PR (`gh pr view <branch> --json number`). A branch with
  **no open PR** is un-reviewable → **skip it + warn** (record it in the summary); never
  auto-`gt submit`, never halt the sweep for it.
- Raw-git host (no `gt`): reconstruct the stack from git ancestry + `gh`; say so rather than
  pretend `gt` ran.

## The per-PR loop (bottom-up, drive-to-clean)

For each increment PR in range, from the **base of the stack upward**, work in a **per-PR
worktree** on the existing increment branch. If that branch is already checked out in a preserved
worktree, reuse it; otherwise set `wt="$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>-sweep"` and
run `git worktree add "$wt" <inc-branch>` — **no** `-b`. The **primary tree is never edited**
([worktree contract](../woostack-init/references/worktrees.md) §3). Export the primary root only
for metrics/telemetry sidecars (contract §5); tracked `address-comments` memory writes stay in the
per-PR worktree so they ride that branch's commit. Then loop the review→address→re-review
steps below, up to `max_rounds` rounds **while blocking findings remain** (see Config); a
no-blocking verdict resolves in a single pass (step 2):

> **Receipt before clean — never self-review.** A PR is marked `clean` **only** from a real
> `woostack-review --full` run on its current HEAD, evidenced by a **review receipt**: the
> woostack-review-posted verdict bearing its bot marker for the reviewed HEAD SHA — the same
> `STATUS_LINE` + marker step 2 already reads, **not a new artifact**. **Never** synthesize a
> `clean` from a structural, manual, or self-review, and **never** downgrade `woostack-review
> --full` to a cheaper check to save cost. A PR with **no review receipt for its HEAD** (the
> engine errored, hung, or was skipped) is **not clean → `blocked`** — distinct from a branch with
> no open PR (skip + warn, un-reviewable). This holds on **every** round: per the
> `fanout-empty-needs-receipt` disambiguation one level up, a clean aggregate with no execution
> receipt is ambiguous (ran-clean vs never-ran), and the receipt is what makes `clean` provably
> swarm-derived.

1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review
   of the whole PR), so a fix that breaks something *outside* its own diff is still caught.
2. **Verdict?** — Read the **verdict, not the GitHub event**: self-authored stack PRs get the
   posted event downgraded `APPROVE`→`COMMENT`, so trust `STATUS_LINE`. Branch on it:
   - **No blocking findings + zero unresolved threads** — a valid **review receipt** for this
     HEAD (the barrier above), `STATUS_LINE` `APPROVED` / `APPROVED WITH SUGGESTIONS`, and zero
     unresolved threads (checked via `gh`) ⇒ **clean** ⇒ teardown the worktree, advance to the
     next PR up. No receipt for HEAD ⇒ the review did not run ⇒ **`blocked`**, never `clean`.
     "Clean" is **review-clean, not a merge-approval** — the run never merges.
   - **No blocking findings + open nit threads** ⇒ **address the nits once** (step 3), restack
     (step 4), then **advance** to the next PR up as `done-with-findings` (record the nits
     addressed and any left open). Do **not** re-review (step 5): nits get a single address pass,
     never a loop.
   - **Blocking findings** (request-changes) ⇒ address (step 3), restack (step 4), and re-review
     (step 5), looping up to `max_rounds` (see Termination backstop).
3. **Address** — otherwise run
   [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) (or interactive,
   under `--interactive`) from inside the worktree: it fixes / pushes back / replies / resolves /
   pushes (via `woostack-commit --no-pr-update`). Never force-push a protected base; never merge.
4. **Restack this stack only** — `gt restack` then `gt submit --stack` scoped to the **current**
   stack, so the PRs above rebase onto the new tip and their rebased branches are pushed. **Never
   `gt sync` or a repo-wide restack** ([worktree contract](../woostack-init/references/worktrees.md)
   §4/§6: a repo-wide restack collides with any parallel run in flight). A restack/rebase conflict
   is a **blocker**.
5. **Re-review (blocking path only)** → back to step 1. The nits-only path never reaches here —
   it advanced in step 2 after a single address pass.

Strictly bottom-up: a PR is driven to clean — or, once its verdict has no blocking findings, to
approved-with-only-nits after a single address pass — before the sweep moves up, and a fix only
restacks the PRs **above** it, never a cleared lower PR, so each PR is handled exactly once on the
way up.

## Termination backstop

The per-PR loop is bounded — **whichever trips first**:

- **Max rounds** — at most `max_rounds` review→address rounds per PR **while blocking findings
  remain** (default **3**; see Config).
- **No-progress guard (blocking only)** — stop early **only while blocking findings remain** with
  no headway: a re-review returns the **same** blocking findings, **or** a round resolves **no
  blocking** thread, **or** an `address-comments` `CLARIFY` leaves a **blocking** thread open.
  **Nits never enter this loop** — a no-blocking verdict with open nit threads gets a single
  `address-comments` pass and the sweep advances (see the per-PR loop), so nits neither trip the
  guard nor consume rounds.

At either terminus the loop still had **blocking findings** — the guard and the cap are both
blocking-only — so read `STATUS_LINE` (not the self-downgraded event):

- **Blocking findings remain** (request-changes) → **blocker** (see Blocker & terminal state).

A **no-blocking verdict never reaches a terminus**: the moment a `woostack-review --full` returns
`APPROVED` / `APPROVED WITH SUGGESTIONS`, the PR is either clean (zero threads) or takes a single
`address-comments` pass on its open nit threads and then advances as `done-with-findings` (open
nits recorded) — **not a blocker**, and never looped to the cap.

## Per-PR outcome vocabulary

Each PR ends `clean` / `done-with-findings` (a no-blocking verdict whose nits took a single
address pass) / `blocked`. The
engine returns these; a caller maps them — a standalone run into the terminal summary,
[`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) into its morning-report
table + "Needs you".

## Blocker & terminal state

A **blocker** = the cap or no-progress guard reached with **blocking findings still present**, a
`woostack-review` error/hang **or any PR left without a review receipt for its HEAD (the review did
not run — never substitute a self/structural review)**, a restack/rebase conflict, or an
`address-comments` step that would touch the never-auto-approve set (destructive / secret / auth /
network / ambiguous). Safety is never relaxed for autonomy.

A usage-limit swarm failure is **not** an immediate blocker: `woostack-review`'s Stage 3
re-dispatches each `usage_limit_reached` / `rate_limit_error` worker onto the next configured
`models.<tier>` entry and walks that chain before its receipt gate fails. A missing HEAD
receipt therefore blocks a PR only once the configured fallback chain is **exhausted** — not
merely because the primary tier hit its usage limit. (Sweep delegates the loop to review; this
is review's mechanism, surfaced here.)

**Standalone:** on a blocker, **stop** at that PR, **leave its worktree** for inspection, and print
a "Needs you" summary — the blocked PR + reason, plus any `done-with-findings` PRs with their open
nits, and any no-PR branches skipped. PRs swept clean below it stay clean (no rollback). **No
report file is written** — a human is at the terminal. A fully clean run prints **"stack swept
clean"**; a nits-only run exits **0** with the nits listed.

**Delegated (e.g. overnight):** the engine surfaces the blocker; the caller decides what to do with
it. [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) leaves the worktree,
records the blocked PR (and `not-attempted-review` above it in that track), and advances to the
next track per its Tracks & halt policy. Overnight owns tracks, the morning report, and
leave-on-blocker; this skill owns the loop.

## Config

`review_sweep.max_rounds` in `.woostack/config.json` (positive integer, default **3**) caps the
per-PR rounds. A non-positive / non-integer value **warns, falls back to 3, and is recorded** —
never a refuse-to-start (a sweep-cap typo is not a doomed run). This is the **single key**;
[`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) reads the same
`review_sweep.max_rounds`.

## Gate boundary

Owns **no approval gate** — it is an autonomous engine. `--interactive` defers per-fix approval to
`woostack-address-comments`' own gate; it is not a sweep-level gate. A protected **current** branch
is fine — every write lands in a per-PR worktree on an increment branch, never the current branch —
but it never force-pushes a protected base, never merges, and never edits the primary tree.

## Hard constraints

- **Single home of the sweep loop.** This is the one definition of the bottom-up drive-to-clean
  loop; callers (overnight) delegate here and never restate it.
- **Bottom-up, each PR handled once on the way up.** Drive a PR to clean (or, on a no-blocking
  verdict, approved-with-only-nits after a single address pass) before moving up; a fix restacks
  only the PRs above it.
- **Read the verdict, not the event.** Clean = `STATUS_LINE` no-blocking + zero unresolved threads;
  self-authored PR events are downgraded.
- **Receipt before clean.** A PR is `clean` only with a real `woostack-review --full` receipt for
  its HEAD (the posted verdict + bot marker); never `clean` from a self/structural review, and
  never downgrade the review to save cost. No receipt for HEAD ⇒ `blocked`, per
  `fanout-empty-needs-receipt`.
- **Restack this stack only.** `gt restack` / `gt submit --stack`; never `gt sync` / repo-wide
  restack.
- **Bounded.** `review_sweep.max_rounds` (default 3) + no-progress guard scoped to **blocking**
  findings; a no-blocking verdict resolves nits in a single address pass and advances (never loops
  to the cap); only blocking findings at the cap are a blocker.
- **No-PR branch → skip + warn.** Never auto-submit, never halt the whole sweep for one
  un-submitted branch.
- **Autonomous, stop on blocker.** Default `--auto`; on a blocker stop, leave the worktree, print
  the summary. Write no report file (overnight writes its own).
- **Never merge, never force-push a protected base, never edit the primary tree, own no gate.**
