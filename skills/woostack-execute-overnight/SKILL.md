---
name: woostack-execute-overnight
description: Use to execute an approved woostack plan UNATTENDED overnight — one autonomous run with no user input after launch that drives every increment to a reviewed stack, swapping woostack-execute's stop-and-ask gates for resolve-or-log-and-continue (woostack-debug on stuck verifications; bounded auto-address on a blocking review; halt-the-track on anything unsafe or ambiguous), honoring optional `## Track:` grouping in the plan (independent, fault-isolated tracks run sequentially), and writing a morning report under .woostack/overnight/ for a human to test in the morning. It is the third choice at woostack-build's execution-handoff gate (Go / Hand off / Run overnight); also usable standalone via /woostack-execute-overnight <plan-path> [--inline|--subagent]. One plan per spec, multiple PRs per plan. Never merges; never relaxes safety for autonomy.
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
   `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md` from
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
- **Resolve-or-log-and-continue, never relax safety.** debug / bounded auto-address /
  blocker-and-halt as above; destructive/secret/auth/network/ambiguous steps are never
  auto-approved.
- **Tracks: author-driven, overnight-only.** Honor `## Track:` headings (default one implicit
  track); a blocker ends only its track. Never force-build on broken work.
- **Morning report every run**, incremental and gitignored under `.woostack/overnight/`.
- **Reuse execute; don't restate it.** Cross-link the cadence, drivers, safety, and memory
  contract.
- **Never merge, never force-push, never start on a protected branch. Own no gate.**
