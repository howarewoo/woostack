---
name: woostack-sweep
type: spec
status: ready
date: 2026-06-13
branch: feature/woostack-sweep
links:
---

# woostack-sweep — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

The "drive a stack of stacked PRs to a clean review" loop — review → address → restack → re-review, bottom-up, bounded — lives only inside [`woostack-execute-overnight`](../../skills/woostack-execute-overnight/SKILL.md) as its **Post-implementation review sweep** section. It cannot be invoked on its own. A human with an existing Graphite stack (built by `woostack-execute`, by hand, or handed off) has no one-command way to grind that stack to clean review; their only option is to drive `woostack-review` → `woostack-address-comments` → `gt restack` per PR by hand, getting the bottom-up ordering, the verdict-not-event reading, the restack-this-stack-only scoping, and the termination bounds right each time.

The engine is also **trapped**: because it is woven into overnight's track-processing and morning-report machinery, it can only run unattended at the end of an overnight execute. The repo's "cross-link, do not duplicate" rule means the loop should have exactly one home, reusable by any caller.

## 2. Goal

Extract the per-PR drive-to-clean loop into a new standalone public skill, **`woostack-sweep`**, that is the single source of truth for the sweep engine. It:

- Sweeps a stack of stacked PRs to a clean review, bottom-up, autonomously.
- Is invokable directly by a human on any current Graphite stack (or a named one).
- Is reused by `woostack-execute-overnight` via **full delegation** — overnight invokes `woostack-sweep` once per track and keeps only its overnight-specific wrapping (tracks, morning report, leave-worktree-on-blocker).

After this change the loop mechanics, termination backstop, per-PR outcome vocabulary, and the `max_rounds` config all live once, in `woostack-sweep`; overnight links them, never restates them.

## 3. Non-goals

- **Not merging.** Like every woostack skill, `woostack-sweep` never merges and never force-pushes a protected base. "Clean" is review-clean, not a human merge-approval.
- **No new review logic.** It composes the existing [`woostack-review`](../../skills/woostack-review/SKILL.md) and [`woostack-address-comments`](../../skills/woostack-address-comments/SKILL.md); it does not re-implement reviewing or thread-resolution.
- **No tracks.** The `## Track:` concept stays overnight-owned. `woostack-sweep` operates on exactly one linear stack per invocation; overnight maps tracks → invocations.
- **No morning report / run-artifact file.** Overnight's `.woostack/overnight/` report stays overnight-owned. Standalone `woostack-sweep` prints a terminal summary; it writes no per-run file.
- **No behavior change to the swept loop.** This is an extraction: the bottom-up ordering, full-re-review-every-round, verdict-not-event reading, restack-this-stack-only scoping, `max_rounds` + no-progress guard, and `clean`/`done-with-findings`/`blocked` outcomes are preserved exactly.
- **Not a build-loop gate owner.** It owns no approval gate.

## 4. Approach

Create `skills/woostack-sweep/SKILL.md` — a single file (the loop is compact; no `references/` subdir, YAGNI). Move the per-PR loop, termination backstop, and per-PR outcome vocabulary out of `woostack-execute-overnight` into it. Rewire overnight to delegate. Promote the config key. Register the new public skill across the command surface.

**Command surface.**

- `/woostack-sweep` — infer the stack from the current Graphite branch (`gt log` / `gt stack`); sweep every increment PR strictly **above `--base`**, bottom-up to the tip. Mirrors how `woostack-review` auto-detects the current PR.
- `/woostack-sweep <PR#>` — sweep the stack **containing** that PR instead of the current branch's stack.
- `--base <ref|PR#>` — the **exclusive** lower floor of the swept range. Default **trunk** (the resolved `WOOSTACK_BASE_BRANCH` from the [worktree contract](../../skills/woostack-init/references/worktrees.md) §1). This one flag is the entire delegation seam: overnight passes `--base <spec+plan-PR-branch>` per track to keep its docs-only base PR out of scope.
- `--interactive` — gate each PR's address step (defers to `woostack-address-comments`' own per-fix gate). Default is autonomous: pass `--auto` down so the sweep never stalls per-fix.

**The engine (single home).** For each increment PR in the stack, from the base of the stack **upward**, work in a **per-PR worktree** on the existing increment branch ([worktree contract](../../skills/woostack-init/references/worktrees.md) §3 — primary tree never edited; reuse a preserved blocker worktree if its branch is already checked out, else `git worktree add "$wt" <inc-branch>` with **no** `-b`; export `WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first so any address-comments memory write lands in the primary store). Then loop, up to `max_rounds` rounds:

1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review), so a fix that breaks something outside its own diff is still caught.
2. **Clean?** — Clean = `woostack-review`'s computed verdict has **no blocking findings** (`STATUS_LINE` `APPROVED` / `APPROVED WITH SUGGESTIONS`) **and** zero unresolved threads (checked via `gh`). Read the **verdict, not the GitHub event**: self-authored stack PRs get the posted event downgraded `APPROVE`→`COMMENT`, so trust `STATUS_LINE`. Clean ⇒ teardown the worktree, advance to the next PR up.
3. **Address** — otherwise run `woostack-address-comments --auto` (or interactive, under `--interactive`) from inside the worktree: fixes / pushes back / replies / resolves / pushes (via `woostack-commit --no-pr-update`). Never force-push a protected base; never merge.
4. **Restack this track's own stack** — `gt restack` then `gt submit --stack` scoped to the **current** stack only, so the PRs above rebase onto the new tip and are pushed. **Never `gt sync` or a repo-wide restack** (worktree contract §4/§6). A restack/rebase conflict is a **blocker**.
5. **Re-review** → step 1.

Strictly bottom-up: a PR is driven to clean — or, at the cap, to approved-with-only-nits — before the sweep moves up, and a fix only restacks the PRs **above** it, so each PR is reviewed exactly once on the way up.

**Termination backstop** (whichever trips first):

- **Max rounds** — at most `review_sweep.max_rounds` review→address rounds per PR (default **3**).
- **No-progress guard (blocking only)** — stop early **only while blocking findings remain** with no headway: a re-review returns the **same** blocking findings, **or** a round resolves **no blocking** thread, **or** an `address-comments` `CLARIFY` leaves a **blocking** thread open. **Nits never trip this guard** — while only non-blocking nits remain, keep looping until the `max_rounds` cap.

At either terminus **without a clean PR**, branch on the verdict (read `STATUS_LINE`):

- **Blocking findings remain** → **blocker** (see §6).
- **Only nits remain** (`APPROVED` / `APPROVED WITH SUGGESTIONS`, open non-blocking threads) — reachable only at the cap → **not a blocker**: mark the PR `done-with-findings`, record the open nits, **move to the next PR up**.

**Per-PR outcome vocabulary (the engine owns it).** `clean` / `done-with-findings` / `blocked`. The engine returns these; callers map them — overnight into its report table + "Needs you", standalone into the terminal summary.

**Config.** Promote `overnight.review_sweep.max_rounds` → top-level **`review_sweep.max_rounds`** in `.woostack/config.json` (positive integer, default **3**). A non-positive / non-integer value warns, falls back to 3, and is reported — never a refuse-to-start. Both `woostack-sweep` and `woostack-execute-overnight` read the one key; the validation contract lives in `woostack-sweep`, overnight links it.

**Delegation seam (overnight's change).** Overnight's **Post-implementation review sweep** section collapses to: *for each track, from the track tip, invoke `woostack-sweep --base <track-base>`; log the returned per-PR outcomes to the decision log + morning-report table; on a blocker leave the worktree and advance to the next track (per Tracks & halt policy).* Overnight **keeps** tracks, track-advance, the morning report, and leave-on-blocker. Overnight **gives away** the per-PR loop mechanics, the termination backstop, and the outcome definitions — now cross-links into `woostack-sweep`.

**Registration surface.** New `skills/woostack-sweep/SKILL.md`; a `using-woostack` routing row; `AGENTS.md` public-command list + quick file map + the prose count bump; the `woostack-execute-overnight` rewire; the config-key promotion. The `site/` per-skill reference pages are generated from `SKILL.md` at build (gitignored) — verify only the authored nav/framing if it enumerates skills.

## 5. Components & data flow

```
/woostack-sweep [PR#] [--base R] [--interactive]
        │
        ▼
  resolve stack  ── current Graphite branch (gt log/stack), or the stack containing <PR#>
        │         floor = --base (default trunk, exclusive); ceiling = stack tip
        ▼
  for each increment PR, base → tip (bottom-up):
        per-PR worktree on the existing branch (no -b; reuse preserved blocker wt)
        loop ≤ review_sweep.max_rounds:
           woostack-review <PR#> --full ─▶ STATUS_LINE + gh unresolved-threads
               clean ──────────────────────────────────▶ teardown, next PR up
               not clean ─▶ woostack-address-comments --auto (or interactive)
                            └▶ gt restack + gt submit --stack (this stack only)
                               └▶ re-review
        terminus → outcome ∈ { clean, done-with-findings, blocked }
        │
        ▼
  caller maps outcomes:
     standalone  → terminal summary (printed): blocker(s), approved-with-nits PRs
     overnight   → morning-report table + decision log; blocker → leave wt, next track
```

- **Inputs:** optional `<PR#>` (which stack), `--base` (exclusive floor, default trunk), `--interactive`, and `review_sweep.max_rounds` from config.
- **Reused units:** `woostack-review` (verdict producer), `woostack-address-comments` (fixer), Graphite (`gt restack`/`gt submit --stack`), the worktree contract.
- **Output:** a stack whose increment PRs are each review-clean, or approved-with-only-nits at the cap, or halted at a blocker — plus a terminal summary (standalone) or the data overnight folds into its report (delegated).

## 6. Error handling

- **Blocker** = the cap or the no-progress guard reached with **blocking findings still present**, a `woostack-review` error/hang, a restack/rebase conflict, or an `address-comments` step that would touch the never-auto-approve set (destructive / secret / auth / network / ambiguous). Safety is never relaxed for autonomy.
- **Standalone on a blocker:** **stop** at that PR, **leave its worktree** for inspection, and print a "Needs you" terminal summary — the blocked PR + reason, plus any `done-with-findings` (approved-with-nits) PRs. PRs already swept clean below it stay clean (no rollback). No report file is written.
- **Overnight on a blocker (delegated):** the engine surfaces the blocker; overnight leaves the worktree, records the blocked PR (and `not-attempted-review` for PRs above it in that track), and **advances to the next track** per its existing Tracks & halt policy.
- **`max_rounds` cap with only nits** is **not** a blocker — that PR is `done-with-findings` and the sweep moves on.
- **Empty / single-PR / no-stack:** a `--base`-to-tip range with zero increment PRs above the floor is a clean no-op — report "nothing to sweep" and exit 0, not an error.
- **Branch in range with no open PR:** a swept-range branch that has no open PR is un-reviewable → **skip it + warn** (record it in the summary) and continue sweeping the PRs that do exist, bottom-up. Never auto-`gt submit` (no surprise PR creation), never halt the whole sweep for one un-submitted branch.
- **Run with only nits, none blocked:** exit **0** with the `done-with-findings` PRs and their open nits listed in the summary — non-blocking by definition, so not a failure exit.
- **Non-current `<PR#>` stack:** resolve the stack containing a non-current `<PR#>` from `gt`/`gh` metadata **without checking out the primary tree** ([worktree contract](../../skills/woostack-init/references/worktrees.md) §3); the exact enumeration mechanism is a plan-level detail.
- **No Graphite / raw-git host:** fall back to git ancestry for stack resolution and `gh` for PR discovery, mirroring the worktree contract's raw-git fallback; say so rather than pretend `gt` ran.
- **Bad `review_sweep.max_rounds`:** warn, fall back to 3, record it; never refuse to start.
- **Protected current branch is fine; primary tree never edited.** Unlike the execute skills (which commit to the current branch and so refuse to start on a protected branch), `woostack-sweep`'s every write lands in a per-PR worktree on an increment branch — never the current branch — so running it while sitting on `main` is safe. It still never force-pushes a protected base, never merges, and never edits the primary tree.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. (No automated runner in this markdown-skill repo → "tests" are concrete structural/grep assertions over the skill markdown + config; see §8.)

- **AC1 — `woostack-sweep` skill exists and defines the engine.**
  - happy: `skills/woostack-sweep/SKILL.md` exists with `name: woostack-sweep`, the command surface (`/woostack-sweep`, `<PR#>`, `--base`, `--interactive`), the bottom-up per-PR loop, the termination backstop, and the `clean`/`done-with-findings`/`blocked` outcome vocabulary.
  - error: a malformed/missing frontmatter `name` is caught by the store linter / review.
  - edge: the loop text cross-links the worktree contract, `woostack-review`, and `woostack-address-comments` rather than restating them.
- **AC2 — overnight delegates, does not restate.**
  - happy: `woostack-execute-overnight/SKILL.md`'s sweep section invokes `woostack-sweep --base <track-base>` per track and links it for the loop mechanics.
  - error: N/A — structural.
  - edge: `grep` finds **no** restated per-PR loop in overnight (no second copy of "review → address → restack → re-review", `max_rounds`, no-progress guard, or outcome definitions); overnight keeps only tracks / morning report / leave-on-blocker.
- **AC3 — single config key.**
  - happy: `review_sweep.max_rounds` is the canonical key, read by both skills; default 3.
  - error: a non-positive / non-integer value warns, falls back to 3, is recorded — never refuse-to-start.
  - edge: `grep` finds no lingering `overnight.review_sweep.max_rounds` reference that isn't a documented alias/migration note.
- **AC4 — standalone terminal behavior.**
  - happy: a clean stack run prints "stack swept clean"; a run with nits-at-cap reports the `done-with-findings` PRs.
  - error: on a blocker, stop at that PR, leave its worktree, print a "Needs you" summary naming the PR + reason; write no report file.
  - edge: an empty `--base`-to-tip range exits 0 with "nothing to sweep"; a branch in range with no open PR is skipped + warned (never auto-submitted), the rest swept; a nits-only run exits 0.
- **AC5 — registered on the public command surface.**
  - happy: `using-woostack` routing table has a `/woostack-sweep` row; `AGENTS.md` lists it in the command surface + quick file map and the prose count is bumped consistently.
  - error: N/A — structural.
  - edge: cross-links (routing, file map, overnight delegation, config) all resolve to real paths.
- **AC6 — safety invariants preserved.**
  - happy: SKILL states never-merge, never force-push a protected base, restack-this-stack-only (never `gt sync`), primary-tree-never-edited.
  - error: a step touching the never-auto-approve set → blocker, not auto-approved.
  - edge: self-authored PR verdict is read from `STATUS_LINE`, not the downgraded GitHub event.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

No automated test runner exists for this skill collection (it ships markdown skills, not application code), so verification is **concrete structural assertion** per [woostack-tdd](../../skills/woostack-tdd/SKILL.md)'s no-runner → concrete-verification rule:

- **Existence + structure:** assert `skills/woostack-sweep/SKILL.md` exists with the required `name`, command surface, loop, backstop, and outcome vocabulary (grep / read).
- **De-duplication:** `grep` `woostack-execute-overnight/SKILL.md` to assert the per-PR loop mechanics, `max_rounds`/no-progress text, and outcome definitions are **gone** (delegated), and that a delegation invocation + link remain.
- **Config single-source:** `grep` config + both SKILLs to assert `review_sweep.max_rounds` is the one key and no stray `overnight.review_sweep.max_rounds` survives outside a migration note.
- **Cross-link resolution:** every introduced relative link (routing row, file map, overnight delegation, worktree/review/address cross-links) resolves to a real file.
- **Count/registration consistency:** the `AGENTS.md` prose count matches the enumerated public-skill list after adding `woostack-sweep`, and the `using-woostack` routing row is present.
- **Manual smoke (optional, post-merge):** run `/woostack-sweep` against a real throwaway 2-PR Graphite stack to confirm bottom-up ordering, clean detection, and the terminal summary — not a gating CI step.

## 9. Open questions

None blocking. Resolved during ideation:

- Extraction seam → **full delegation** (overnight is single-consumer, calls `woostack-sweep` per track).
- Stack input → **current Graphite stack**, optional `<PR#>` override.
- Base floor → **`--base` flag, default trunk**; overnight passes its track base.
- Autonomy → **autonomous grind**, `--auto` down, stop + printed summary on blocker; opt-in `--interactive`.
- File layout → **single `SKILL.md`**, no `references/` (revisit only if it grows).
- Name → **`woostack-sweep`** (verb-only, matches family grammar; reuses the in-repo "sweep" term of art).
- No-PR branch in range → **skip + warn**, sweep the rest (never auto-submit, never halt on it).
- Protected current branch → **allowed** (writes are worktree-only); exit **0** on a nits-only / empty-range run.
