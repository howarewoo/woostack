---
name: overnight-review-sweep
type: spec
status: approved
date: 2026-06-11
branch: feature/overnight-review-sweep
links:
  - "[[2026-06-09-review-stack-aware]]"
  - "[[2026-06-10-parallel-worktrees]]"
---

# Overnight review sweep — Design Spec

> **Plan:** [[plans/2026-06-11-overnight-review-sweep]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

`woostack-execute-overnight` drives an approved plan to a stacked set of increment PRs unattended, but it never carries any PR to a **clean approval**. Its only PR-level review today is autonomy override #2, which is:

- **Per-increment, not stack-wide** — it reviews each increment right after that increment is committed, with no pass over the finished stack.
- **inline-driver only** — in `--subagent` mode there is *no* PR-level review at all; the per-task reviewer loops stand in for it, so a subagent-built stack lands overnight with zero GitHub-level review.
- **`--fast`, 2-round capped** — a quick batched check, then on `REQUEST_CHANGES` up to two `woostack-address-comments --auto` rounds, then a blocker. It is an early correctness tripwire, not a drive-to-approval.

So the morning artifact is a stack of *implemented* PRs, each possibly still carrying open review threads, and (in subagent mode) PRs that were never PR-reviewed at all. The human's morning job still includes "review every PR from scratch," which is exactly the toil the overnight run was supposed to absorb.

The ask: after implementation, **drive the whole stack to clean approval autonomously** — start at the first PR, review it and address every comment until it has a clean approval, then do the same for the next PR, for the whole stack.

## 2. Goal

`woostack-execute-overnight` gains a **post-implementation review sweep**: once a track's increments are all implemented and committed, before advancing to the next track, it walks that track's stack **bottom-up** and drives each increment PR to a **clean approval** — full `woostack-review`, then `woostack-address-comments --auto` on any blocking findings, restack the PRs above, re-review — looping until clean or until a bounded backstop fires. It runs for **both** drivers (giving subagent stacks their first PR-level review) and is **additive**: the existing per-increment override #2 is unchanged; the sweep is a new phase layered on top.

Every sweep decision is appended to the morning report's decision log, and a new **Review sweep** report section records per-PR rounds and final verdict. The sweep **never merges** and **never relaxes safety** — it inherits every existing invariant.

## 3. Non-goals

- **No merge.** Reaching a clean approval does not merge the PR. The merge decision stays with the human (unchanged hard constraint).
- **No change to override #2.** The per-increment `--fast` review+auto-address during the build stays exactly as-is (the user chose *augment*, not *replace*). The sweep is a separate, later phase.
- **No change to the per-increment cadence, drivers, worktree contract, tracks/halt policy, distill, or pre-flight** beyond adding the sweep as a new phase and its rows to the report.
- **No unbounded loop.** "Until clean approval" is bounded by a max-rounds cap **and** a no-progress guard so an unattended run cannot churn forever (§4.4).
- **No new review angles / no change to `woostack-review` internals.** The sweep *invokes* full `woostack-review` and `woostack-address-comments --auto` as they exist; it adds no flags to them and changes neither skill.
- **No concurrency.** The sweep is sequential — one PR at a time, one track at a time — matching the single-session overnight model. No parallel review.
- **No re-sweep of already-clean lower PRs.** Strictly bottom-up: a PR is driven to clean before the sweep moves up, and a fix never reaches down into an already-cleared lower PR, so lower PRs are never re-reviewed (§4.5).
- **No relaxation of safety for autonomy.** A restack conflict, an `address-comments` action that would touch the never-auto-approve set (destructive / secret / auth / network / ambiguous), or a hung review is a **blocker → halt-the-track**, never an auto-approval.

## 4. Approach

A new autonomous phase inserted into `woostack-execute-overnight`, reusing the review and address-comments skills wholesale. Five parts.

### 4.1 Where the sweep runs

The sweep is a **per-track post-implementation phase**. For each `## Track:` (a plan with no track headings has one implicit track — `woostack-execute`'s linear behavior), the run already implements that track's increments in order via the unchanged per-increment cadence. **After the last increment of a track is committed (or the track halts mid-implementation at a blocker), and before advancing to the next track, run the review sweep over that track's committed increment PRs.**

For the default single-track plan this is exactly the user's framing: implement the whole stack, then sweep it. If a track halted mid-implementation at increment *k*, the sweep covers the increments that reached a committed PR (1…*k*−1), bottom-up; it does not invent PRs for the not-attempted remainder.

The sweep covers **increment (code) PRs only**. The docs-only **spec+plan base PR** (build step 7, the bottom of the stack, never reviewed or merged by build) is never swept — it is the common base every increment stacks on, not an increment. Standalone (no build) there is no spec+plan PR; the increments branch off the current non-protected HEAD and the sweep covers them all.

### 4.2 The per-PR loop (bottom-up, drive-to-clean)

For each increment PR in the track, from the **base of the stack upward**:

1. **Checkout in a per-PR worktree.** Do **not** edit the primary tree — the [worktree contract](../../woostack-init/references/worktrees.md) §3 makes "the primary checkout stays on the base branch, clean" a hard invariant so parallel runs branch from it. If the increment branch is already checked out in a preserved blocker worktree, reuse that worktree; otherwise add a per-PR worktree that checks out the **existing** increment branch (`git worktree add "$wt" <inc-branch>` — *no* `-b`). All review/address writes happen there; `address-comments`' precondition (clean tree + branch = PR head) holds inside it. Export `WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first (contract §5) so any `address-comments` memory write lands in the primary store. **Teardown on a clean PR; leave the worktree on a blocker** and report its path (contract §2).
2. **Review** — `woostack-review <PR#> --full` posts a batched GitHub Review. **Every** sweep review — the first and every re-review (step 6) — is forced `--full` (§9-Q10): a complete re-review of the whole PR each round, so a fix that introduces a problem *outside* its own diff is still caught, and inline-mode override #2's per-increment SHA watermark can never silently narrow the pass to an incremental one.
3. **Clean?** If the PR is **clean** (§4.3) → record clean, teardown the worktree, advance to the next PR.
4. **Address** — otherwise run [`woostack-address-comments --auto`](../../woostack-address-comments/SKILL.md) from inside the worktree: it reads the PR's unresolved threads, fixes / pushes back / replies / resolves, and pushes (via `woostack-commit --no-pr-update`). Never force-push to a protected base; never merge.
5. **Restack this track's own stack** — addressing moved this PR's branch tip, so its descendants are based on a stale commit. Restack **only this track's stack** — `gt restack` then `gt submit` scoped to the current stack — and **never `gt sync` or a repo-wide restack** (worktree contract §4/§6: a repo-wide restack collides with any parallel run in flight). This rebases *your own* stacked feature branches — not the prohibited force-push to a protected/shared base. A **restack/rebase conflict is a blocker** (§4.6).
6. **Re-review** → go to step 2 (another `--full` review of the whole PR against the pushed fix; the §4.3 verdict + explicit zero-threads check gate clean).
7. Loop until clean (step 3) or a backstop fires (§4.4).

### 4.3 "Clean approval", defined

A PR is **clean** when, after a `woostack-review` pass, **both** hold:

- **No blocking findings** in woostack-review's computed verdict — its `STATUS_LINE` is `APPROVED` or `APPROVED WITH SUGGESTIONS`, **not** `CHANGES REQUESTED`. Read the **verdict**, not the posted GitHub event: overnight increment PRs are **self-authored** (the agent commits as the user), and GitHub forbids an `APPROVE`/`REQUEST_CHANGES` review on your own PR — woostack-review detects `reviewer == author` and **downgrades the posted event to `COMMENT`** while keeping the accurate verdict in `STATUS_LINE` (see woostack-review Troubleshooting). So a literal green "Approved" badge never appears overnight; the signal is the verdict.
- **Zero unresolved review threads** on the PR, checked explicitly via `gh` (independent of the review event, robust to the self-PR downgrade and to `--full`'s event-floor behavior).

A review whose only findings are non-blocking nits (including `Deferred to <ref>` deferral nits from [[2026-06-09-review-stack-aware]]) with no open threads is clean — the sweep does not chase nits.

**"Clean" means review-clean, not a human merge-approval.** It is woostack-review finding nothing blocking and no open threads — never a human's GitHub approval and never a merge signal. The run still **never merges**; the human owns the merge decision in the morning.

### 4.4 Termination backstop (cap + no-progress)

The loop is bounded two ways, whichever trips first:

- **Max rounds** — at most `max_rounds` review→address rounds per PR. Default **3**, overridable via `.woostack/config.json` key `overnight.review_sweep.max_rounds` (positive integer).
- **No-progress guard** — stop early if a round makes no headway: an `address-comments --auto` round that resolves **no** thread (every thread `ACCEPT`/`CLARIFY`, nothing fixed) **or** a re-review that returns the **same** set of blocking findings as the previous round.

Hitting either without a clean approval is a **blocker** for that PR → halt policy (§4.6). The chosen cap and the reason for stopping are written to the decision log.

### 4.5 Why bottom-up needs no re-sweep

The sweep clears PR *i* to clean **before** touching PR *i*+1. Addressing PR *i* changes only PR *i*'s branch and forces a restack of *i*+1…*N* (which sit **above** it). It never alters any PR **below** *i*, all of which are already clean. A restacked upper PR's own diff (vs its parent) is unchanged unless the restack conflicts — so reviewing it once, after the restack, is correct. Therefore each PR is reviewed-to-clean exactly once on the way up; lower PRs are never re-swept. (Resolved in §9-Q4.)

### 4.6 Halt policy (reuses tracks & halt, unchanged)

A sweep blocker — cap-without-clean, no-progress, a restack/rebase conflict, or an `address-comments` step that would require touching the never-auto-approve set — **ends that track's remaining sweep**: the blocked PR and every PR above it in that track are recorded `blocked` / `not-attempted-review`, and the run **advances to the next track's sweep** (each track is an independent stack off the common base). For a single-track plan the remainder halts at the blocker — expected and reported, not an error. Work already committed stays committed; nothing is rolled back; nothing is merged.

## 5. Components & data flow

```
woostack-execute-overnight (per track, after that track's increments are committed)
  │
  ├─ for each increment PR, base → top of the track's stack:
  │     add per-PR worktree on the EXISTING inc branch  (primary tree untouched)
  │     export WOOSTACK_ROOT → primary store (memory writes)
  │     round r = 1..max_rounds:
  │        woostack-review <PR#> --full   (every round — posts GitHub Review)
  │        clean? (verdict has no blocking findings  AND  0 unresolved threads via gh)
  │           │     (verdict, not the event — self-PR review downgrades APPROVE→COMMENT)
  │           └─ yes → teardown worktree, next PR
  │        woostack-address-comments --auto   (fix/reply/resolve/push; never merge)
  │        gt restack + gt submit  (THIS stack only — never gt sync / repo-wide)
  │           └─ conflict → BLOCKER (leave worktree)
  │        no-progress? (0 threads resolved, or identical blocking findings,
  │                      or an open CLARIFY thread that can't auto-resolve)
  │           └─ yes → BLOCKER (leave worktree)
  │     cap reached, still not clean → BLOCKER (leave worktree)
  │
  ├─ BLOCKER → end this track's sweep (remaining PRs: not-attempted-review) → next track
  │
  └─ each decision appended to the morning-report decision log

config:  .woostack/config.json → overnight.review_sweep.max_rounds   (default 3)

morning report (.woostack/overnight/YYYY-MM-DD-<plan>.md, gitignored, incremental):
  + "Review sweep" section: per-PR rounds used, final verdict (clean | blocked), no-progress flag
  + per-increment table gains the sweep verdict
  + decision log: every sweep decision + rationale
  + "Needs you": a blocked PR (cap/no-progress/conflict) surfaces here with its branch
  + Run summary outcome: a sweep blocker feeds `partial+blockers`
```

Reused verbatim, no edits: `woostack-review` (full), `woostack-address-comments --auto`, `woostack-commit --no-pr-update` (the push path inside address-comments), and the worktree/clean-tree preconditions. New surface is entirely inside `woostack-execute-overnight/SKILL.md` plus the report template and one config key.

## 6. Error handling

- **Clean on round 1** (no findings, no threads) → no `address-comments`, no restack; record clean, advance. The common happy path costs one review per PR.
- **Cap reached, still blocking** → blocker → halt the track's sweep (§4.6); the PR is reported `blocked` with rounds used; remaining PRs `not-attempted-review`.
- **No-progress** (a round resolves nothing, or re-review repeats the same blocking findings) → blocker, same handling; the decision log names which guard tripped so the morning reader knows it wasn't a cap exhaustion.
- **Open CLARIFY thread** — `address-comments --auto` may judge a thread `CLARIFY` (genuine ambiguity), which it replies to but **leaves open** (`RESOLVE=0`). An open thread fails the §4.3 zero-threads check (and trips woostack-review's open-prior-thread event floor → `CHANGES REQUESTED`), so the PR can never go clean by churning — it surfaces as no-progress → blocker → the human resolves the ambiguity in the morning. This is the correct outcome, not a failure.
- **Self-authored-PR event downgrade** — the posted GitHub review event is `COMMENT` even on a clean verdict (you cannot `APPROVE` your own PR). The sweep reads woostack-review's `STATUS_LINE` verdict + the `gh` thread count, never the event, so this never masquerades as "not clean" (§4.3).
- **Restack/rebase conflict** when restacking the PRs above an addressed PR → blocker (a conflict needs human judgment; never auto-resolve overnight). The blocked PR's own fix is already committed/pushed; the conflict is on the *descendants*, which become `not-attempted-review`.
- **`address-comments` hits the never-auto-approve set** (a fix that is destructive / secret-touching / auth-mutating / network, or a genuinely ambiguous thread) → `address-comments --auto` must not act on it; it is a blocker → halt-the-track. Safety is never relaxed for autonomy.
- **Track halted mid-implementation** → the sweep still runs over the increments that reached a committed PR in that track (bottom-up), then the run advances to the next track. A track with **zero** committed increments has nothing to sweep.
- **`woostack-review` itself errors / hangs** (host/API failure) → treated like a verification that cannot complete: a blocker → halt-the-track, logged. No partial "clean" is ever recorded on an errored review.
- **Bad `overnight.review_sweep.max_rounds`** (non-positive / non-integer) → caught at **pre-flight**: warn, fall back to the default of 3, and note the bad value in the report; do not abort the whole run over a config typo (overnight must be resilient; §9-Q3).
- **No PRs in a track** (e.g. dry implementation produced no committable change) → the sweep is a no-op for that track; recorded as such.

## 7. Acceptance criteria

> This is a skills-markdown + report-template + config-doc change. There is no app runtime; behaviors are verified by **concrete presence checks** (`grep` / `bash -n` over the edited skill, template, and config docs) confirming each directive is present, internally consistent, and cross-linked — the existing prompt/skill-edit verification pattern (see [[2026-06-09-review-stack-aware]] §8). Each AC names the text that must exist and the property a check asserts.

- **AC1 — Sweep phase exists and is per-track, post-implementation, bottom-up**
  - happy: `woostack-execute-overnight/SKILL.md` has a dedicated sweep section stating the sweep runs after a track's increments are committed, before the next track, walking the stack base→top; a presence check finds the section heading and the "bottom-up / base of the stack upward" wording.
  - error: the section states the sweep is *additive* and does **not** remove or alter override #2; a check finds override #2 still present and a cross-reference that the sweep is separate.
  - edge: a single-track (default, no `## Track:`) plan is named as the common case ("implement the whole stack, then sweep it").

- **AC2 — Per-PR drive-to-clean loop is specified end to end**
  - happy: the loop lists, in order, per-PR worktree on the existing branch → `woostack-review <PR#> --full` (first review) → clean-check → `woostack-address-comments --auto` → restack-this-stack → re-review; a check finds each step, that the first review is `--full`, and that the work runs in a per-PR worktree (primary tree untouched).
  - error: the loop never merges, never force-pushes a protected base, and restacks **only this track's stack** (never `gt sync`); a check finds the no-merge wording and the scoped-restack / no-`gt sync` wording.
  - edge: a round-1-clean PR skips address/restack and tears its worktree down (named happy path).

- **AC3 — "Clean approval" is defined (verdict + threads, not the event)**
  - happy: the skill defines clean = no blocking findings in the computed verdict (`STATUS_LINE` `APPROVED`/`APPROVED WITH SUGGESTIONS`) **and** zero unresolved threads via `gh`; a check finds both conjuncts and the explicit "read the verdict, not the event" wording.
  - error: a `CHANGES REQUESTED` verdict or any unresolved thread is explicitly **not** clean; the self-authored-PR `APPROVE`→`COMMENT` event downgrade is named so a downgraded event is never read as "not clean."
  - edge: nit-only / `Deferred to <ref>` with no open threads is explicitly clean (sweep does not chase nits); "clean" is stated to be review-clean, not a human merge-approval.

- **AC4 — Termination backstop (cap + no-progress) is bounded and configurable**
  - happy: the skill states a `max_rounds` cap (default 3) **and** a no-progress guard, either of which without a clean approval is a blocker; a check finds both backstops and the `overnight.review_sweep.max_rounds` key with default 3.
  - error: cap-reached-without-clean and no-progress both map to **blocker → halt-the-track**; a check finds that mapping.
  - edge: a bad `max_rounds` value is caught at pre-flight, falls back to default 3, and is logged — not fatal (§9-Q3).

- **AC5 — Both drivers; halt policy reused**
  - happy: the skill states the sweep runs for **both** inline and subagent drivers (subagent's first PR-level review); a check finds the both-drivers wording.
  - error: a sweep blocker ends only that track's remaining sweep and advances to the next track, reusing the existing tracks/halt policy by reference (not a restated copy); a check finds the cross-reference to Tracks & halt and the never-auto-approve invariant.
  - edge: restack conflict and never-auto-approve-set are both named blocker sources.

- **AC6 — Morning report + description reflect the sweep**
  - happy: `references/report-template.md` gains a **Review sweep** section (per-PR rounds + final verdict + no-progress flag) and the per-increment table carries a sweep verdict; checks find both.
  - error: the decision log is stated to receive every sweep decision; the `Needs you` section surfaces a blocked PR with its branch; a check finds both.
  - edge: the SKILL frontmatter `description` and the Terminal-state / Hard-constraints sections mention the post-implementation drive-to-clean sweep; a check finds the description string updated and a hard-constraint bullet for the sweep.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

No app runtime and no script changes — this is markdown skill + template + config-doc edits, so testing follows woostack's established prompt/skill-edit verification pattern ([[2026-06-09-review-stack-aware]] §8): **concrete presence/consistency checks**, no live-LLM test.

- **Presence checks** (`grep`/`bash -n`): each AC's named directive exists in the edited `woostack-execute-overnight/SKILL.md`, `references/report-template.md`, and the config docs — sweep section, bottom-up wording, full-review (no `--fast`), clean-approval definition, both-drivers, cap + no-progress + `overnight.review_sweep.max_rounds`, never-merge, halt-the-track cross-reference, report Review-sweep section, updated `description`.
- **Cross-token / single-source consistency**: the config key name `overnight.review_sweep.max_rounds` is spelled identically wherever it appears (skill body + any config reference doc); the sweep references `woostack-review`, `woostack-address-comments --auto`, and the Tracks & halt section **by link**, not by restating them — a check greps for the link targets and for the *absence* of a duplicated halt-policy paragraph.
- **No-regression on override #2**: a check confirms override #2's `--fast` per-increment text is still present and unmodified (the augment invariant).
- **Manual smoke (documented, not automated)**: optionally dry-run the sweep prose against a small real 2-PR stack to confirm the bottom-up restack ordering reads correctly; this is a reviewer walkthrough, not a CI gate.

## 9. Resolved decisions (hardened)

All forks settled in ideation and hardening. No open questions remain — the spec is hardened.

- **Q1 (decided) — Augment, not replace.** Keep per-increment override #2 (`--fast`, 2-round) during the build **and** add the post-implementation sweep. *Why:* the early per-increment check catches gross errors before later increments stack on them; the sweep is the thorough drive-to-clean at the end. Trade accepted: an inline-mode PR gets a cheap early pass and a full late pass.
- **Q2 (decided) — Full review on the sweep.** The sweep invokes full `woostack-review`, not `--fast` (override #2 keeps `--fast`). *Why:* the sweep is the final clean-approval gate; thoroughness over speed is right for the last pass an unattended run makes.
- **Q3 (decided) — Bad-config = fallback-and-log, not refuse-to-start.** A non-positive / non-integer `overnight.review_sweep.max_rounds` is validated at **pre-flight** (the one human touchpoint): warn, use the default 3, and record the bad value in the report — never refuse the whole run. *Why:* "refuse a doomed run" is for plans with critical gaps; a sweep-cap typo isn't doomed (a sane default exists), and execute-overnight's ethos is resolve-or-log-and-continue. Surfacing it at pre-flight (vs silently mid-run) is the cheap belt-and-suspenders.
- **Q4 (decided) — Strictly bottom-up, no re-sweep.** Each PR is driven to clean before the sweep moves up; a fix only restacks PRs above and never alters a cleared lower PR, so lower PRs are reviewed exactly once (§4.5).
- **Q5 (decided) — Both drivers.** The sweep is driver-independent (it acts on the GitHub PR), so it runs in inline and subagent mode — giving subagent stacks their first PR-level review.
- **Q6 (decided) — Per-PR worktree on the existing branch; the primary tree is never edited.** The sweep does **not** check out PR heads on the primary tree (that would violate the [worktree contract](../../woostack-init/references/worktrees.md) §3 hard invariant). It reuses a preserved blocker worktree when the increment branch is already checked out there; otherwise it adds a per-PR worktree on the existing increment branch (`git worktree add "$wt" <inc-branch>`, no `-b`). It works there, and tears down on clean / leaves on a blocker — exactly the contract's lifecycle. A left-behind worktree from a halted track is inert/gitignored and doesn't block claiming a sibling branch in a fresh worktree (§4.2).
- **Q7 (decided) — Default `max_rounds` = 3**, overridable via `overnight.review_sweep.max_rounds`. Three full-ish rounds per PR is a sane unattended ceiling; the no-progress guard usually trips first.
- **Q8 (decided) — Restack this stack only; never `gt sync`.** After addressing a PR, restack just this track's own stack (`gt restack` + scoped `gt submit`), never a repo-wide `gt sync`/restack-all — the worktree contract §4/§6 forbids repo-wide restacks while any parallel run is in flight. A restack conflict is a blocker.
- **Q9 (decided) — Clean = computed verdict + zero threads, not the GitHub event; first review forced `--full`.** Overnight PRs are self-authored, so woostack-review downgrades the posted event `APPROVE`→`COMMENT`; the sweep reads the `STATUS_LINE` verdict + the `gh` unresolved-thread count instead (§4.3). The first review of each PR is forced `--full` so inline-mode override #2's incremental SHA marker can't silently narrow it to a partial pass.
- **Q10 (decided) — `--full` on every round.** Every sweep review — first pass and every re-review — is `woostack-review --full`, a complete re-review of the whole PR each round. *Why:* maximum thoroughness — a fix that introduces a problem outside its own diff is still caught, which an incremental re-review (fix-commit only) would miss. *Cost accepted:* up to `max_rounds` full reviews × every PR is the dominant new overnight cost; the cap (3) and the no-progress guard bound it, and most PRs go clean in one round.
