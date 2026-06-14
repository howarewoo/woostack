---
name: fix-delegates-to-execute
type: convention
scope: skills/woostack-fix/**
tags: fix, execute, delegation, dry, execution-engine
hook: woostack-fix delegates execution to woostack-execute (the fix file IS the plan); never re-inline a TDD/commit/distill loop.
updated: 2026-06-10
source: [[fixes/2026-06-10-fix-delegate-to-execute]]
---
`woostack-execute` is the single execution engine for woostack. A skill that drives a plan to
implementation should **delegate** to it, not re-implement the cadence. `woostack-fix` previously
inlined its own weaker loop (TDD in step 5, standalone `woostack-commit` in step 6, standalone
distill in step 7) and never referenced `woostack-execute` at all — a `grep "woostack-execute"
skills/woostack-fix/SKILL.md` returned nothing.

The fix: step 5 hands the fix file to `/woostack-execute <fix-file> --inline`. **The fix file IS
the plan** — execute reads the named Markdown and ticks its checkboxes; it does not hard-require
`.woostack/plans/` or a `**Source:**` line, so a `.woostack/fixes/*.md` path works, and its
`## 3. Implementation Plan` is the single increment. Execute owns branch / TDD / tick / commit /
**task review** / distill, so delegation also *adds* the per-task spec+quality review the inline
loop lacked.

What stays with the wrapping skill: diagnosis, the plan file, hardening, the approval gate, and
the frontmatter `status:` lifecycle (execute ticks checkboxes but never touches frontmatter).
Default `--inline` for a one-increment fix; `--subagent` for larger. Mirrors `woostack-build`
step 9, which delegates to execute and absorbs the separate commit/distill steps. General rule:
when a skill needs to run a plan, route through `woostack-execute` rather than duplicating its
loop — two copies drift (see [[execute-inline-task-review]]).

Boundary (review nit, PR #284): the anti-duplication rule targets re-implementing the *mechanics*.
A wrapper step MAY *name* execute's cadence phases (branch → TDD → tick → commit → review →
distill) for in-context orientation as long as each mechanic is cross-linked to its canonical home
(woostack-tdd, woostack-commit, woostack-execute). Naming the stable top-level phases is not the
drift-prone duplication — re-specifying how each phase works is. Do not flag phase-naming-with-links
as a cross-link violation.
