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
([worktree contract](../woostack-init/references/worktrees.md) §3). Export
`WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first (contract §5) so any
`address-comments` memory write lands in the primary store. Then loop, up to `max_rounds` rounds
(see Config):

1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review
   of the whole PR), so a fix that breaks something *outside* its own diff is still caught.
2. **Clean?** — Clean = `woostack-review`'s computed verdict has **no blocking findings**
   (`STATUS_LINE` `APPROVED` / `APPROVED WITH SUGGESTIONS`) **and** zero unresolved threads
   (checked via `gh`). Read the **verdict, not the GitHub event**: self-authored stack PRs get the
   posted event downgraded `APPROVE`→`COMMENT`, so trust `STATUS_LINE`. Clean ⇒ teardown the
   worktree, advance to the next PR up. "Clean" is **review-clean, not a merge-approval** — the
   run never merges.
3. **Address** — otherwise run
   [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) (or interactive,
   under `--interactive`) from inside the worktree: it fixes / pushes back / replies / resolves /
   pushes (via `woostack-commit --no-pr-update`). Never force-push a protected base; never merge.
4. **Restack this stack only** — `gt restack` then `gt submit --stack` scoped to the **current**
   stack, so the PRs above rebase onto the new tip and their rebased branches are pushed. **Never
   `gt sync` or a repo-wide restack** ([worktree contract](../woostack-init/references/worktrees.md)
   §4/§6: a repo-wide restack collides with any parallel run in flight). A restack/rebase conflict
   is a **blocker**.
5. **Re-review** → back to step 1.

Strictly bottom-up: a PR is driven to clean — or, at the `max_rounds` cap, to
approved-with-only-nits — before the sweep moves up, and a fix only restacks the PRs **above** it,
never a cleared lower PR, so each PR is reviewed exactly once on the way up.

## Termination backstop

The per-PR loop is bounded — **whichever trips first**:

- **Max rounds** — at most `max_rounds` review→address rounds per PR (default **3**; see Config).
- **No-progress guard (blocking only)** — stop early **only while blocking findings remain** with
  no headway: a re-review returns the **same** blocking findings, **or** a round resolves **no
  blocking** thread, **or** an `address-comments` `CLARIFY` leaves a **blocking** thread open.
  **Nits never trip this guard** — while only non-blocking nits remain, keep reviewing/addressing
  them until the `max_rounds` cap.

At either terminus **without a clean PR**, branch on the verdict (read `STATUS_LINE`, not the
self-downgraded event):

- **Blocking findings remain** (request-changes) → **blocker** (see Blocker & terminal state).
- **Only nits remain** (`APPROVED` / `APPROVED WITH SUGGESTIONS`, open non-blocking threads) —
  reachable only at the `max_rounds` cap, since the guard never stops on nits → **not a blocker**:
  mark the PR `done-with-findings`, record the open nits, and **move to the next PR up**.

## Per-PR outcome vocabulary

Each PR ends `clean` / `done-with-findings` (approved-with-only-nits at the cap) / `blocked`. The
engine returns these; a caller maps them — a standalone run into the terminal summary,
[`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) into its morning-report
table + "Needs you".

## Blocker & terminal state

A **blocker** = the cap or no-progress guard reached with **blocking findings still present**, a
`woostack-review` error/hang, a restack/rebase conflict, or an `address-comments` step that would
touch the never-auto-approve set (destructive / secret / auth / network / ambiguous). Safety is
never relaxed for autonomy.

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
- **Bottom-up, each PR reviewed once on the way up.** Drive a PR to clean (or
  approved-with-only-nits at the cap) before moving up; a fix restacks only the PRs above it.
- **Read the verdict, not the event.** Clean = `STATUS_LINE` no-blocking + zero unresolved threads;
  self-authored PR events are downgraded.
- **Restack this stack only.** `gt restack` / `gt submit --stack`; never `gt sync` / repo-wide
  restack.
- **Bounded.** `review_sweep.max_rounds` (default 3) + no-progress guard scoped to **blocking**
  findings; nits loop to the cap; only blocking findings at the cap are a blocker.
- **No-PR branch → skip + warn.** Never auto-submit, never halt the whole sweep for one
  un-submitted branch.
- **Autonomous, stop on blocker.** Default `--auto`; on a blocker stop, leave the worktree, print
  the summary. Write no report file (overnight writes its own).
- **Never merge, never force-push a protected base, never edit the primary tree, own no gate.**
