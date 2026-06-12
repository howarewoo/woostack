---
name: woostack-execute-overnight
description: Use to execute an approved woostack plan unattended overnight, with autonomous blocker handling, optional tracks, a post-implementation review sweep that drives each increment PR to a clean review, and a morning report. Never merges.
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

- **Per-increment cadence**: create per-PR worktree → implement (driver) → tick the plan's
  checkboxes in place → [`woostack-commit`](../woostack-commit/SKILL.md) → review → distill →
  teardown worktree. Identical to [`woostack-execute`](../woostack-execute/SKILL.md)'s cadence,
  including the per-PR [worktree contract](../woostack-init/references/worktrees.md) (parent-aware
  `base_ref`, `WOOSTACK_ROOT`-anchored distill, leave-on-failure). On a track blocker the blocked
  track's last worktree is **left in place** for morning inspection, not torn down.
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
   `.woostack/overnight/<run-date>-<plan-slug>.md` — the run date (`YYYY-MM-DD`, today) plus the
   plan basename with any leading `YYYY-MM-DD-` stripped (see
   [Morning report](#morning-report)) — from
   [references/report-template.md](references/report-template.md). Write it **incrementally** so a
   crash still leaves a partial record.

Clean pre-flight → go autonomous and solicit no further input.

## Autonomy overrides

Run execute's per-increment cadence unchanged, except at the three points where execute would
stop. Each becomes an autonomous policy, and **every decision is appended to the report's decision
log as it happens**.

1. **Verification fails repeatedly** → route to
   [`/woostack-debug <target>`](../woostack-debug/SKILL.md), which runs its root-cause analysis
   autonomously and hands back a proposed minimal fix (execute already does this); execute
   implements and commits the fix. If debug **cannot establish a root cause**, there is no
   present user to escalate to → record a **blocker** and apply the halt policy.
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

   Override #2 is the **per-increment early check** during the build. The stack-wide
   **drive-to-clean** happens after implementation — see [Post-implementation review sweep](#post-implementation-review-sweep), which is additive and leaves this override unchanged.
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

## Post-implementation review sweep

After a track's increments are all implemented and committed — and **before advancing to the
next track** — drive that track's stack to a clean review. This is **additive**: the
per-increment override #2 (the `--fast` blocking-review check during the build) is unchanged;
the sweep is a separate, thorough pass over the finished stack. It runs for **both drivers**
(inline and subagent), giving a subagent-built stack its first PR-level review. It **never
merges**.

A plan with no `## Track:` headings has one implicit track, so the default is exactly: implement
the whole stack, then sweep it. The sweep covers **increment PRs only** — never the
docs-only spec+plan base PR. If a track halted mid-implementation, the sweep covers the
increments that reached a committed PR, bottom-up.

### The per-PR loop (bottom-up, drive-to-clean)

For each increment PR in the track, from the **base of the stack upward**, work in a **per-PR
worktree** on the existing increment branch. If that branch is already checked out in a preserved
blocker worktree, reuse it; otherwise set
`wt="$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>-sweep"` and run
`git worktree add "$wt" <inc-branch>` — **no** `-b`. The **primary tree is never edited**, per the
[worktree contract](../woostack-init/references/worktrees.md) §3. Export
`WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first (contract §5) so any
`address-comments` memory write lands in the primary store. Then loop, up to `max_rounds` rounds
(see Config):

1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review
   of the whole PR), so a fix that breaks something *outside* its own diff is still caught, and
   inline-mode override #2's per-increment SHA watermark can never silently narrow the pass to an
   incremental one.
2. **Clean?** Clean = woostack-review's computed verdict has **no blocking findings** (`STATUS_LINE`
   `APPROVED` / `APPROVED WITH SUGGESTIONS`) **and zero unresolved threads** (checked via `gh`).
   Read the **verdict, not the GitHub event**: overnight increment PRs are self-authored, so
   woostack-review downgrades the posted event `APPROVE`→`COMMENT` (you cannot approve your own
   PR). Clean ⇒ teardown the worktree, advance to the next PR. "Clean" is **review-clean, not a
   human merge-approval** — the run still never merges.
3. **Address** — otherwise run
   [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) from inside the
   worktree (its clean-tree + branch=PR-head precondition holds there): it fixes / pushes back /
   replies / resolves / pushes (via `woostack-commit --no-pr-update`). Never force-push a protected
   base; never merge.
4. **Restack this track's own stack** — `gt restack` then `gt submit --stack` scoped to the
   current stack, so the PRs above rebase onto the new tip and their rebased branches are pushed.
   **Never `gt sync` or a repo-wide restack** (worktree contract §4/§6: a repo-wide restack
   collides with any parallel run in flight). A restack/rebase conflict is a **blocker**.
5. **Re-review** → back to step 1.

Strictly bottom-up: a PR is driven to clean before the sweep moves up, and a fix only restacks the
PRs **above** it — never a cleared lower PR — so each PR is reviewed exactly once on the way up.

### Termination backstop

The per-PR loop is bounded — **whichever trips first**:

- **Max rounds** — at most `max_rounds` review→address rounds per PR (default **3**; see Config).
- **No-progress guard** — stop early when a round resolves **no** thread, **or** a re-review returns
  the **same** blocking findings as the prior round, **or** an `address-comments` `CLARIFY` leaves a
  thread open (an open thread fails the clean check and can never go clean by churning).

Either, without a clean PR, is a **blocker → halt** (below). The reason is written to the decision
log.

### Halt (reuses Tracks & halt policy)

A sweep blocker — cap-without-clean, no-progress, a `woostack-review` error/hang, a restack
conflict, or an `address-comments` step that would touch the never-auto-approve set (destructive /
secret / auth / network / ambiguous) — **ends that track's remaining sweep** (the blocked PR is
recorded `blocked`, and every PR above it becomes `not-attempted-review`) and the run **advances to
the next track**, exactly the existing [Tracks & halt policy](#tracks--halt-policy). Safety is never
relaxed for autonomy; the blocked PR's worktree is **left in place** for morning inspection.

### Config

`overnight.review_sweep.max_rounds` in `.woostack/config.json` (positive integer, default **3**)
caps the per-PR rounds. Validated at **pre-flight**: a non-positive / non-integer value warns, falls
back to 3, and is recorded in the report — never a refuse-to-start (a sweep-cap typo is not a doomed
plan).

## Morning report

Written incrementally to `.woostack/overnight/<run-date>-<plan-slug>.md` — the run date
(`YYYY-MM-DD`, today) joined to the plan basename **with any leading `YYYY-MM-DD-` stripped** (the
plan basename already begins with the spec's date, since `woostack-plan` reuses it, so stripping it
before prefixing the run date keeps the filename a single, run-keyed date instead of doubling it,
e.g. `2026-06-12-memory-vault.md`, not `2026-06-12-2026-06-12-memory-vault.md`) — from
[references/report-template.md](references/report-template.md). It is **gitignored** (a per-run
artifact, like `.woostack/visuals/`), so it never rides into an increment PR and never dirties the
tree for the review / address-comments clean-tree preconditions. Sections:

- **Needs you** (top): blockers, and a morning **test checklist** (what to verify, the HEAD branch
  per track).
- **Run summary**: plan, driver, start/end, outcome (`clean` / `partial+blockers` /
  `refused-to-start`).
- **Per-increment table**: status (`done` / `done-with-findings` / `blocked` / `not-attempted`),
  branch + PR URL, review verdict, auto-address rounds used, and sweep verdict.
- **Review sweep**: per-PR rounds used, final sweep verdict, no-progress flag, and blocker reason.
- **Decision log**: every autonomous decision with its rationale.

## Terminal state

Stop when every track has either completed (increments implemented **and** swept to a clean review)
or halted at a blocker. The result is a Graphite stack (linear, or tree-stacked across tracks) of
increment PRs each driven to a clean review — or partially, with blockers logged — plus a complete
morning report. Report the path. "Clean" is review-clean, never a merge. **Never merge.**

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
- **Resolve-or-log-and-continue, never relax safety.** debug / bounded auto-address /
  blocker-and-halt as above; destructive/secret/auth/network/ambiguous steps are never
  auto-approved.
- **Tracks: author-driven, overnight-only.** Honor `## Track:` headings (default one implicit
  track); a blocker ends only its track. Never force-build on broken work.
- **Drive the stack to clean review.** After a track's increments are committed, sweep its
  increment PRs bottom-up — `woostack-review --full` → `woostack-address-comments --auto` → restack
  **this stack only** (`gt restack`/`gt submit --stack`, never `gt sync`) → re-review — to a clean
  verdict (no blocking findings, read from `STATUS_LINE` not the self-downgraded event) + zero
  unresolved threads. Bounded by `overnight.review_sweep.max_rounds` (default 3) + a no-progress
  guard; a blocker halts only that track. Both drivers. Never merge.
- **Morning report every run**, incremental and gitignored under `.woostack/overnight/`.
- **Reuse execute; don't restate it.** Cross-link the cadence, drivers, safety, and memory
  contract.
- **Never merge, never force-push, never start on a protected branch. Own no gate.**
