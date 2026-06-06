---
name: woostack-execute-overnight
type: spec
status: planning
date: 2026-06-06
branch: feature/woostack-execute-overnight
links:
  - "[[2026-06-04-woostack-execute]]"
  - "[[2026-06-04-build-execution-handoff-gate]]"
---

# woostack-execute-overnight: unattended autonomous plan execution — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

[`woostack-execute`](../../skills/woostack-execute/SKILL.md) drives an approved plan to a
reviewed stack, but it is built for a **supervised** session: it stops and asks the user on
every blocker — a failing verification `woostack-debug --auto` can't fix, a review that returns
REQUEST_CHANGES, an ambiguous or unsafe plan step. That discipline is correct when a human is
watching, and wrong when nobody is.

The intended workflow is different: spend the day crafting and hardening a genuinely good plan
through the normal gated build loop, then let a machine **execute the whole plan unattended
overnight** so a human can manually test the result in the morning. Today there is no
woostack-native way to do that. Running `woostack-execute` overnight would stall on the first
blocker and waste the night; a person would wake up to a run halted at increment 1 with a
question on screen and no progress behind it.

We want an execution mode that trades *stop-and-ask* for *resolve-or-log-and-continue*, makes
documented autonomous decisions, never relaxes safety, and leaves a single artifact a human
reads first thing to know what to test and what needs attention.

## 2. Goal

Ship `skills/woostack-execute-overnight/SKILL.md`: a **public command** (the thirteenth) that
takes one approved plan (**supplied as a required argument**) and drives **all** of its
PR-sized stacked increments to completion **without any user input after launch**. It reuses
`woostack-execute`'s machinery wholesale — the same per-increment cadence (branch → implement
via the inline/subagent driver → tick checkboxes → `woostack-commit` → review → distill), the
same drivers ([inline-driver.md](../../skills/woostack-execute/references/inline-driver.md) /
[subagent-driver.md](../../skills/woostack-execute/references/subagent-driver.md)), the same
smart-default driver selection, and the same hard safety invariants — and **overrides only the
three points where execute would stop**, replacing each with an autonomous policy. It ends by
writing a **morning report** to `.woostack/overnight/` and, like execute, **never merges**.

Wire it into the collection two ways:

1. As a direct command: `/woostack-execute-overnight <plan-path> [--inline | --subagent]`.
2. As a third choice at [`woostack-build`](../../skills/woostack-build/SKILL.md)'s
   **execution-handoff gate (step 8)**: **Go** (supervised execute) / **Hand off** (stop) /
   **Run overnight** (this skill).

The body stays **thin**: it documents only the deltas from execute and cross-links execute for
everything shared, honoring the repo's "cross-link, do not duplicate" rule.

## 3. Non-goals

- **Not a planner.** Input is an already-approved plan under `.woostack/plans/`. It does not
  ideate, write specs, or write plans. "Spend time making a good plan" happens by day, through
  the normal gated loop; this skill only executes one. (Scope settled in ideate: pure execute
  sibling, not plan+execute or full ideate→ship.)
- **Does not auto-partition tracks.** The track convention (§4) is **author-driven**: the human
  structures independent tracks deliberately when crafting the plan. `woostack-plan` only
  *documents and allows* the `## Track:` grouping; it does not analyze the decomposition and
  split tracks itself. Default plans have one implicit track.
- **Does not change `woostack-execute`.** Tracks are an **overnight-only** optimization.
  `woostack-execute` (supervised) ignores track headings and runs increments as one linear
  stack, stopping and asking on any blocker — unchanged by this work.
- **Does not merge.** Ends on a reviewed (or partially-reviewed) stack plus a morning report.
  Merging is always a separate human action. No force-push.
- **Does not relax safety for autonomy.** Destructive, secret-touching, auth-mutating, or
  network plan steps are **never auto-approved** just because no human is present — they become
  logged blockers. Autonomy removes *gates*, not *safety*.
- **Adds no approval gate.** There is no human to gate at runtime. The pre-flight refuse-to-start
  check (§4) is a safety check, not an approval gate. `woostack-build`'s upstream HARD GATES
  (design, spec) are unchanged.
- **Does not duplicate execute.** No copy of the drivers, cadence text, memory contract, or
  safety rules — it references them. Only the autonomy overrides, halt policy, morning report,
  and pre-flight refusal are authored here.
- **Does not change the `1 : 1 : N` invariant.** One spec, one plan, N increment PRs. Tracks
  make the N PRs **tree-stacked** (each track branches off the common base) instead of one
  linear chain, but the count and the join contracts are unchanged.

## 4. Approach

Author one self-contained `SKILL.md` plus a single `references/report-template.md` (the morning
report skeleton). Everything execute already owns is **referenced, not restated**.

### Command & invocation
- `/woostack-execute-overnight <plan-path> [--inline | --subagent]` — the plan path is a
  **required argument**. Passing both mode flags is an error: stop and ask which.
- `/woostack-execute-overnight` with no argument → ask which plan, list `.woostack/plans/`
  candidates, and stop until one is named. A no-arg launch is the **only** moment user input is
  solicited; an unattended run cannot start without a plan.
- **Driver:** inherits execute's smart default (subagent where the host can spawn subagents,
  else inline); explicit `--inline` / `--subagent` overrides. If `--subagent` is requested but
  the host cannot spawn subagents, fall back to inline and say so — never pretend.

### Pre-flight (the one check that still matters)
Because nobody is watching mid-run, the skill validates *before* going dark and **refuses to
start** rather than burning the night on a doomed run:
- Load the plan and review it critically **once** (execute's "load and review the plan" step). A
  plan with critical gaps that prevent a clean start → **do not launch**; write a short
  refusal report to `.woostack/overnight/` naming the gaps and stop.
- Confirm the current branch is not protected (`main`/`staging`/`beta`/`alpha`), `.woostack/`
  exists, and (when invoked from build) the spec+plan PR base is present.
- Create `.woostack/overnight/` if missing and open the morning-report file immediately, so the
  report is written **incrementally** and a crash still leaves a partial record.

If pre-flight is clean → go autonomous and solicit no further input.

### Autonomous per-increment cadence
Run execute's exact per-increment cadence in order, one increment per cycle. The only
differences are the three stop-points, each replaced by an autonomous policy and a decision-log
entry:

| Where `woostack-execute` stops | `woostack-execute-overnight` instead |
|---|---|
| Verification fails repeatedly | Route to `woostack-debug --auto` (execute already does this autonomously). If debug returns its **3-fixes architectural stop**, there is no present user to escalate to → mark a **blocker** and apply the halt policy. |
| Review is blocking | **Driver-specific** (see below): inline → bounded auto-address; subagent → the `BLOCKED` escalation is itself the blocker. |
| Ambiguous or unsafe plan step | **Safety is not relaxed.** A destructive/secret/auth/network step, or a genuinely ambiguous instruction, is **never auto-approved** → **blocker** → halt policy. |

**Review override is driver-specific** (grounded in how execute reviews per mode):
- **inline** — `woostack-review --fast` runs on the increment PR and **posts a batched GitHub
  Review**; a REQUEST_CHANGES leaves unresolved threads on the PR. Overnight attempts
  [`woostack-address-comments --auto`](../../skills/woostack-address-comments/SKILL.md) (it
  reads the PR's unresolved threads, fixes/replies/resolves/pushes autonomously — its
  precondition of a clean tree + branch=PR head holds right after the increment commit), then
  re-reviews, **up to 2 rounds**. Still blocking after the cap → **blocker** → halt policy.
- **subagent** — there is no PR-level `woostack-review`; the per-task spec→quality reviewer
  loops *are* the bounded review and a **`BLOCKED`** escalation is their terminal outcome. That
  `BLOCKED` is treated directly as a **blocker** → halt policy (no separate auto-address pass —
  the reviewer loop already was the iteration).

Every autonomous action (a debug fix committed, a finding auto-addressed, a `BLOCKED`
escalation, a blocker recorded, an increment not attempted) is appended to the decision log in
the report **as it happens**.

### Tracks & halt policy
A plan may group its increments under **`## Track:` headings**; each track is its own linear
`gt` stack branched off the **common base** (the spec+plan PR when invoked from build, else the
current non-protected branch). A plan with no track headings has **one implicit track** — exactly
today's linear behavior, fully backward-compatible. The convention is **author-driven**:
`woostack-plan` documents and allows it (§Wiring), but does not auto-partition; only this skill
consumes it.

Overnight processes tracks **in order, sequentially** (it is a single session — no real
concurrency); within a track, increments run in order. On a blocker:
- **End the current track** at the blocker — do not stack new work on broken work; work already
  committed stays committed (no rollback).
- **Advance to the next track**, branching its first increment off the common base (unaffected
  by the blocked track). The blocked track's remaining increments are recorded `not-attempted`.
- A single-track (default) plan therefore halts the remainder at the blocker — expected and
  reported, not an error. This rules out the "best-effort, never halt / force-build on broken
  work" option from ideate.

### Report git handling
The morning report is a **per-run artifact, not shared knowledge** — like `.woostack/visuals/`
and `metrics.json`, `.woostack/overnight/` is **gitignored**. It is never staged into an
increment PR (and being gitignored, it does not dirty the working tree, so `woostack-review`
and `woostack-address-comments` clean-tree preconditions still hold). The human reads it in
place in the morning.

### Morning report — the deliverable
Written to `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md` from
`references/report-template.md`, populated incrementally:
- **Top — needs you:** the blockers (if any) and a **morning test checklist** (what to manually
  verify, where the stack is, which branch is HEAD).
- **Run summary:** plan path, driver, start/end, overall outcome (clean stack / partial +
  blockers / refused-to-start).
- **Per-increment table:** status (`done` / `done-with-findings` / `blocked` / `not-attempted`),
  branch + PR URL, review verdict, auto-address rounds used.
- **Decision log:** every autonomous decision with its rationale.

### Wiring `woostack-build`
- **Step 8 (execution-handoff gate):** today a two-way **Go / Hand off** choice. Add a third:
  **Run overnight** → invoke `woostack-execute-overnight` with the step-4 plan path. "Run
  overnight" is an explicit go-ahead, so it does not violate "ambiguous or no answer is not a
  go"; reword the gate to present three explicit options while keeping that guard.
- **Step 10 (terminal state):** add a third terminal shape — **Overnight** → a reviewed (or
  partially reviewed) Graphite stack plus a morning report under `.woostack/overnight/`,
  possibly partial with logged blockers. Build still never merges.
- **Overview / hard constraints:** reflect the three-way handoff; the "never auto-run execute"
  constraint stays (overnight is a chosen option, not an inference).

### Wiring the track convention (lightweight)
- **`woostack-plan`:** document the **optional `## Track:` grouping** in the plan-format section
  — increments may be grouped under track headings; default (no headings) is one implicit track.
  Plans stay frontmatter-free. `woostack-plan` does **not** auto-partition; it only allows the
  shape so a human can author parallel tracks for an overnight run.
- **`woostack-status` conventions:** a one-line note that an overnight run may produce
  **tree-stacked** increment PRs (tracks branched off the common base) rather than one linear
  chain — so a spec can have several concurrent increment branches. The `1 : 1 : N` count and
  the `Spec:`-trailer join are unaffected; no new phase-enum value.
- **Root `.gitignore`:** add `.woostack/overnight/` alongside the existing
  `.woostack/visuals/` and `.woostack/metrics.json` ignores.

## 5. Components & data flow

Edit set (decomposed into PR-sized increments in the plan):

| File | Change |
|---|---|
| `skills/woostack-execute-overnight/SKILL.md` | **NEW** — the skill: scoped `description`, required `/woostack-execute-overnight <plan-path>` command + mode flags, pre-flight (refuse-to-start), the three autonomy overrides (incl. the inline/subagent review split), the `## Track:` consumption + per-track halt policy, morning-report write (incremental, gitignored), terminal state, gate boundary, hard constraints. Cross-links execute for drivers/cadence/safety/memory contract — does **not** restate them. |
| `skills/woostack-execute-overnight/references/report-template.md` | **NEW** — morning-report skeleton (needs-you / run summary / per-increment table / decision log). |
| `skills/woostack-build/SKILL.md` | Step 8: two-way → **three-way** handoff (Go / Hand off / Run overnight); step 10: add the overnight terminal shape; reword the "never auto-run execute" constraint to allow the explicit overnight choice. |
| `skills/using-woostack/SKILL.md` | Add a Command Routing row: `/woostack-execute-overnight <plan-path>` → `woostack-execute-overnight`. |
| `.claude/CLAUDE.md` (= `AGENTS.md`) | Public surface **twelve → thirteen**; add `woostack-execute-overnight` to the public-skill list and Quick file map; bump the "fourteen `SKILL.md` files (twelve public + two internal)" hard constraint to **fifteen (thirteen public + two internal)**; protect the new skill from deletion like the other shipped skills. |
| `README.md` | Skill count twelve → thirteen; add `woostack-execute-overnight` to the public list; mention the overnight option in the build-loop prose if execute is described there. |
| `CONTRIBUTING.md` | Add a "Change the overnight execute phase" pointer row → `skills/woostack-execute-overnight/SKILL.md`, parallel to the existing execute/ideate/harden rows. |
| `skills/woostack-plan/SKILL.md` | Document the **optional `## Track:` grouping** in the plan-format section (increments may be grouped under track headings; default = one implicit track). No auto-partitioning; plans stay frontmatter-free. |
| `skills/woostack-status/references/conventions.md` | Minimal note: an overnight run emits the same artifacts so the board reads it unchanged; a blocked/partial run is visible via its `.woostack/overnight/` report (not a new phase); track runs may yield **tree-stacked** increment PRs (several concurrent branches per spec) — `1 : 1 : N` count and `Spec:` join unaffected, no new enum value. |
| `.gitignore` (root) | Add `.woostack/overnight/` next to the existing `.woostack/visuals/` and `.woostack/metrics.json` ignores — the morning report is a per-run artifact. |

Data flow at runtime: `/woostack-execute-overnight <plan>` (or build step 8 → Run overnight) →
pre-flight (load + critical review + safety checks; refuse + report if gappy) → open the
(gitignored) morning report → for each track in order, branch its first increment off the
common base, then for each increment run execute's cadence with the three overrides (debug
--auto on repeated failure; inline auto-address ≤2 rounds / subagent `BLOCKED`-as-blocker on a
blocking review; blocker on unsafe/ambiguous) → append decisions to the report live → on a
blocker, end that track and advance to the next → terminal: a reviewed/partial Graphite stack
(linear, or tree-stacked across tracks) + a complete morning report, never merged.

## 6. Error handling

- **No plan argument.** Required. No-arg → ask which plan, list candidates, stop. An unattended
  run never starts without a named plan; never guess "the current plan."
- **Gappy plan at pre-flight.** Critical gaps that prevent a clean start → refuse to launch,
  write a short refusal report to `.woostack/overnight/`, stop. Better than failing all night.
- **Verification fails repeatedly.** `woostack-debug --auto`; on debug's 3-fixes architectural
  stop → blocker (no user to escalate to) → halt policy.
- **Blocking review (inline).** `woostack-review --fast` posts REQUEST_CHANGES to the PR →
  bounded auto-address via `woostack-address-comments --auto`, re-review, ≤2 rounds; still
  blocking → blocker → halt policy. Never merges a finding away.
- **Blocking review (subagent).** No PR-level review exists; a reviewer-loop `BLOCKED`
  escalation is the bounded outcome → treated directly as a blocker → halt policy.
- **Unsafe or ambiguous plan step.** Never auto-approved (untrusted-plan-step rule, unchanged
  from execute) → blocker → halt policy.
- **Memory store missing at distill.** Skip distillation (same contract as execute); distill
  never blocks an increment.
- **`.woostack/overnight/` missing.** Create it at pre-flight before opening the report; it is
  gitignored, so it never dirties the tree for the review/address-comments clean-tree checks.
- **Crash / interruption mid-run.** The report is written incrementally, so a partial report
  names the last completed increment/track and the in-flight state — recoverable by the morning
  human.
- **Single-track plan halts at a blocker.** Expected, not an error: report it as "track halted
  at increment K, no further tracks" with the blocker detail.
- **No common base (standalone run).** When not invoked from build there may be no spec+plan
  PR base; tracks branch off the current non-protected branch HEAD instead. Note it in the
  report.
- **Protected branch / host can't spawn subagents.** Never start on a protected branch; on a
  `--subagent` request the host can't satisfy, fall back to inline and say so.
- **Description over-trigger.** Scope the `description` to "execute an existing plan
  autonomously / overnight, unattended" — distinct from supervised `woostack-execute` and not a
  generic "write code" trigger, so `using-woostack` routes the two correctly.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection:

- New `SKILL.md` has valid frontmatter (`name`, `description`), a required `<plan-path>`
  argument, the pre-flight refusal, the three autonomy overrides, the halt policy, the morning
  report, the gate-boundary + terminal-state + never-merge statements.
- The body cross-links `woostack-execute` (drivers, cadence, safety, memory contract) rather
  than duplicating them — grep shows references, not copied driver text.
- `references/report-template.md` exists with the four sections.
- `woostack-build` step 8 presents **three** options (Go / Hand off / Run overnight); step 10
  lists the overnight terminal shape; the "never auto-run execute" constraint still holds for
  ambiguous/no answer.
- `using-woostack` has a `/woostack-execute-overnight` routing row.
- Command-surface count is consistent everywhere — `AGENTS.md`, `README.md`, `using-woostack`,
  CONTRIBUTING reflect **thirteen** public commands; the "do not rename" hard constraint reflects
  **fifteen** `SKILL.md` files (thirteen public + two internal).
- Cross-links resolve (`woostack-build` ↔ `woostack-execute-overnight`;
  `woostack-execute-overnight` → `woostack-execute`, `woostack-debug`,
  `woostack-address-comments`, `woostack-commit`, `woostack-review`).
- `woostack-status` conventions note the overnight report + tree-stacked PRs without adding an
  enum value.
- The blocking-review override is documented **per driver** (inline `address-comments --auto`
  ≤2 rounds; subagent `BLOCKED`-as-blocker), not as a single mode-blind rule.
- `woostack-plan` documents the optional `## Track:` grouping (default one implicit track); it
  does not auto-partition.
- `.gitignore` (root) lists `.woostack/overnight/`; grep confirms it sits beside
  `.woostack/visuals/` / `.woostack/metrics.json`.

## 8. Open questions

All resolved. Settled during ideate:

- **Scope** → **pure execute sibling**: input is an approved plan path; runs all increments
  unattended. Not plan+execute, not full ideate→ship.
- **Blocker policy** → **halt the blocked chain, attempt independent tracks if the plan declares
  them**; a linear plan halts at the blocker. Never force-build on broken work; never halt the
  whole run pre-emptively when independent work remains.
- **Review policy** → **bounded auto-address (≤2 rounds) then log + halt policy** — not
  log-only, not hard-blocker-on-first-finding.
- **Placement** → **thirteenth public command + a third build step-8 option** (Go / Hand off /
  Run overnight). Fully wired (AGENTS.md, build, README, using-woostack, CONTRIBUTING, status
  conventions).
- **Driver** → **inherit execute's smart default** (subagent where possible, else inline) with
  `--inline` / `--subagent` overrides.

Settled as approved defaults during the design review:

- **Morning-report path** → `.woostack/overnight/YYYY-MM-DD-<plan-basename>.md`, written
  incrementally from `references/report-template.md`.
- **Pre-flight on a gappy plan** → **refuse to start** and write a short refusal report, rather
  than launching a doomed run.

Settled during the spec harden pass:

- **"Independent tracks" made real, but contained** → woostack plans are linearly stacked with
  no independence marker, so the original "keep going elsewhere" needed a producer. Resolution:
  an **author-driven, top-level `## Track:` convention** (depth-1) — each track is its own
  linear `gt` stack off the common base; a blocker ends only its track. **Overnight is the only
  consumer**; `woostack-plan` merely documents/allows the shape (no auto-partitioning);
  `woostack-execute` ignores tracks (stays linear). Default = one implicit track = today's
  behavior.
- **Blocking-review override is driver-specific** → inline posts a GitHub review, so overnight
  uses `woostack-address-comments --auto` (≤2 rounds) on the PR threads; subagent has no
  PR-level review, so a reviewer-loop `BLOCKED` is the blocker directly (the loop was already the
  bounded retry). No single mode-blind auto-address rule.
- **Morning report is gitignored** → `.woostack/overnight/` joins `.woostack/visuals/` and
  `.woostack/metrics.json` as a per-run artifact, keeping it out of increment PRs and out of the
  clean-tree precondition for review/address-comments.
- **Standalone runs without a base** → tracks branch off the current non-protected branch HEAD
  when there is no spec+plan PR base; noted in the report.
