---
name: woostack-execute
description: Use to execute an approved woostack plan as a sequence of PR-sized, stacked increments — implement each increment with TDD, tick the plan's checkboxes in place, commit via woostack-commit on its own Graphite branch, review it with woostack-review --fast, distill durable learnings, then continue. This is the execute phase of the woostack build loop (woostack-build step 6); also usable standalone via /woostack-execute <plan-path>. One plan per spec, multiple PRs per plan. Never merges.
---

# woostack-execute

Execute an approved plan by driving it to implementation as a sequence of PR-sized, stacked
increments. This is woostack's own execution phase — [`woostack-build`](../woostack-build/SKILL.md)
step 6. It keeps the discipline that makes plan execution reliable (load the plan, review it
critically, follow steps exactly, run verifications, stop when blocked) and adds the woostack PR
cadence: **one plan per spec, multiple stacked PRs per plan**, each increment committed,
reviewed, and distilled before the next. It never merges and owns no approval gate.

## Commands

- `/woostack-execute <plan-path>` — execute the named markdown plan under `.woostack/plans/`.
  **The plan path is required.**
- `/woostack-execute` (no argument) — do **not** guess "the current plan." Ask which plan to
  execute (optionally list `.woostack/plans/` candidates) and stop until one is named.

When `woostack-build` reaches step 6 it invokes this skill with the plan path it wrote in step 4.

## Load and review the plan

1. Read the plan file.
2. Review it critically — surface any questions or concerns about the plan, the spec it traces
   to, or the increment breakdown.
3. If there are concerns: raise them with the user before starting.
4. If none: proceed.

Never start implementation on a protected branch (`main`/`staging`/`beta`/`alpha`);
`woostack-commit` enforces this when it creates each increment's branch.

## PR-sized increments

Implement the plan as a sequence of independently shippable increments — preferably ≤500 LOC
each (a soft target, not a gate). When `woostack-build` invoked this skill, its step 5 already
decomposed the plan into increments. When run standalone, perform the same decomposition:
structure the work as increments, flag any slice that can't reasonably stay under the target,
and propose a split before executing it. Genuinely atomic changes may exceed the target.

Run **one increment per cycle**, in order.

## Per-increment cadence

For each increment:

1. **Implement** its tasks with TDD. Where the host supports subagents, prefer
   `superpowers:subagent-driven-development`; otherwise `superpowers:test-driven-development`
   (recommended enhancements, not hard dependencies — follow the principle if either is absent).
   Follow each plan step exactly and run the verifications the plan specifies.
2. **Tick the plan's checkboxes in place.** Edit the markdown plan, `[ ]` → `[x]`, as each step
   or task completes, so the plan file is the live progress record.
3. **Commit** via [`woostack-commit`](../woostack-commit/SKILL.md) on a fresh Graphite-stacked
   feature branch (`gt create`) — one branch + PR per increment. This is the "multiple PRs per
   plan" shape.
4. **Review** the resulting PR with [`woostack-review`](../woostack-review/SKILL.md)` --fast`.
5. **Gate on the review:** if it returns REQUEST_CHANGES (a blocking finding), **stop** and
   surface the findings — the user decides (typically via
   [`woostack-address-comments`](../woostack-address-comments/SKILL.md)). If it is clean or
   non-blocking, continue.
6. **Distill** the increment's durable, reusable learnings into `.woostack/memory/` per the
   [memory contract](../woostack-init/references/memory.md): one fact per file, `type` one of
   `pattern|decision|gotcha|convention`, the narrowest `scope` glob covering the touched files,
   `source` the spec/plan path. Apply the **reject-by-default distillation gate**
   ([memory contract §7](../woostack-init/references/memory.md#7-distillation-write-path)) —
   dedupe against `.woostack/memory/MEMORY.md` first, reject trivia / source-less /
   near-duplicate notes, and stamp `updated:` on every note you write. Then run `woostack-init`'s
   `build-index.sh` and `doctor.sh`; fix any error. When the store does not exist, skip (or offer
   `/woostack-init` first). Distill only cross-feature knowledge, never feature-specific trivia.

Then advance to the next increment.

## Terminal state: a reviewed stack

Stop when every increment is implemented, checked off, committed, reviewed, and distilled —
leaving a Graphite stack of reviewed PRs. Report the branches/PRs and their review verdicts.
**Never merge.**

## When to stop and ask

Stop immediately and ask — never guess — when:

- A blocker hits (missing dependency, failing verification, unclear instruction).
- The plan has critical gaps preventing a start.
- A verification fails repeatedly.
- A review returns REQUEST_CHANGES — handle the findings before continuing.

Return to the plan-review step if the plan is updated or the approach needs rethinking.

## Gate boundary

This skill owns **no approval gate**. `woostack-build` keeps the design-approval and
spec-approval HARD GATES upstream; execute inherits gates and adds none. Per-increment commit,
review, and distill are work steps; the pause on REQUEST_CHANGES is a blocker stop, not an
approval gate. The skill never merges and never auto-addresses review findings.

## Hard constraints

- **Plan path required.** Never guess "the current plan"; ask when no argument is given.
- **One increment per cycle.** Don't let a cycle balloon past a reviewable PR.
- **Multiple stacked PRs per plan.** Each increment is its own `gt`-stacked branch + PR via
  `woostack-commit`.
- **Tick checkboxes in place.** The plan file is the live progress record.
- **Commit + review every increment.** `woostack-commit`, then `woostack-review --fast`; pause on
  REQUEST_CHANGES.
- **Distill durable knowledge only.** Reject-by-default; dedupe; never feature-specific trivia.
- **Never merge, never force-push, never start on a protected branch.**
- **Own no gate; never auto-address findings.**
