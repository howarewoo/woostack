---
name: commit-review-artifact-before-gate
type: convention
scope: skills/woostack-build/**,skills/woostack-fix/**
tags: gate, commit, pr-review, worktree, build, fix
hook: Commit + open the PR for a gated artifact BEFORE its approval gate, so the user reviews it in the PR, not a raw worktree file.
updated: 2026-06-23
source: [[fixes/2026-06-23-build-commit-spec-before-approval]]
---
When a gated woostack skill asks the user to approve an artifact, commit that artifact and open
its PR **before** the gate — so the review happens in the PR, not against a markdown file buried
in a worktree the user would have to open. `woostack-fix` set the pattern (commit the hardened
plan before its one gate); `woostack-build` now matches it: step 3 commits the spec and opens the
spec+plan base PR (initially spec-only) before the spec-approval gate, and step 7 **appends** the
plan to that **same** PR rather than opening a fresh one.

Key property: it is the **same base PR opened earlier**, not a second PR. The branch/worktree the
caller already created carries the early commit; later phases append to the same branch (build:
plan at step 7; fix: code via `woostack-execute`). The `spec : plan : PRs = 1 : 1 : N` invariant
and "docs PR = base of the stack" role are untouched.

Three consequences to wire whenever you apply this:
- **The worktree stays alive across the gate** (it must — the post-approval phases keep writing to
  it). Teardown moves to after the appended content is committed.
- **Abandon must now close the open PR**, on top of `git worktree remove --force` + branch delete.
  A pre-commit gate had no PR to close; a commit-before gate does.
- **The early commit is a work step, not a new gate.** Keep the gate count exact (build stays at
  three) and say so in Hard constraints, or a reader will miscount. This is distinct from
  [[gate-needs-hard-barrier]] (gate *prominence*) and from [[spec-plan-quality-via-angle-preflight]]
  (do *not* add a gate) — here you add a commit, not a stop.

Skill-doc verification has no runner: pin the new ordering with a fixed-string (`rg -F`)
content-assertion test that proves order via **adjacency strings** (old `harden spec → approve
spec` must vanish; new `commit spec PR → approve spec` must appear), red before the edit. See
[[skill-test-assert-ascii-token]]. When the change touches an authored `site/` page (the build-loop
diagram lives in `concepts/building-rules.mdx`), sync it in the same PR.
