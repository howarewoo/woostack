---
name: execute-authors-terminal-plan-done
type: gotcha
scope: skills/woostack-execute/**, skills/woostack-status/scripts/**
tags: execute, plan-lifecycle, status, done, frontmatter, resolve_phase, drift
hook: woostack-execute authors exactly ONE frontmatter write — the terminal plan `status: done` at the final increment (all boxes `[x]`, plan files only; skipped for `.woostack/fixes/`). Authoring `done` pre-merge fixes file-rot but does NOT make the board show `done`: `resolve_phase` returns `in-review` whenever a PR is open.
updated: 2026-06-16
source: [[fixes/2026-06-16-plan-status-done-on-final-increment]]
---
A plan's frontmatter `status:` used to rot at `executing`/`ready` forever — no
skill advanced it after the last increment shipped. The terminal transition now
lives in `woostack-execute` step 8: when the **final** increment ticks the last
checkbox (plan 100%) **and** the artifact is a plan (`type: plan`), author
`status: done` and commit the bump via `woostack-commit --no-pr-update` so it
persists to the branch tip. This is execute's **only** frontmatter write and is
**plan-scoped** — skip it for `.woostack/fixes/` files, whose lifecycle stays
owned by [[fix-delegates-to-execute]] / `woostack-fix` (it authors `in-review`
on PR-open, `done` on merge).

Crucial board gotcha — do NOT also "fix" `status.sh` to show `done` earlier.
`resolve_phase` (`status.sh`) checks `open > 0 → in-review` **first**, so an
authored `done` ahead of merge still renders as `in-review` until the stack
merges, then `done`. That is correct: `done = merged-and-landed` on the board is
a deliberate invariant (see conventions.md). Authoring `done` at the final
increment only stops the *file* from rotting; the board keeps deriving reality
and reconciles at merge. The board never rewrites authored status; it flags or
reconciles. So the fix for "plan status drift" is a one-line authored transition,
not a board-logic change. `woostack-execute-overnight` does the same but authors
`done` **once**, at whole-plan 100% (never per-track; a blocked track leaves the
status untouched).
