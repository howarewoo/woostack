---
name: git-diff-base-omits-untracked-new-files
type: gotcha
scope: .woostack/plans/**
tags: plans, verification, git, woostack-execute
hook: A plan step that inventories changed files with `git diff --name-only <base>` under-counts by exactly the new files an earlier task created — `git diff` ignores untracked paths, and woostack-execute defers per-task `gt` commits into one commit per increment, so those new files are still untracked at a later verification task. `git add` them (or commit) before the diff.
updated: 2026-07-14
source: [[plans/2026-07-14-least-code-tenet]]
---
A no-runner woostack plan often verifies "the changed-file set equals the allowed set" with
`git diff --name-only <base> -- <paths>`. `git diff <commit>` compares that commit to the working
tree over **tracked** files only; a brand-new file is untracked and never appears. The count is a
line short and the check fails against its expected inventory.

This bites specifically because [[woostack-execute]] commits **once per increment**, not once per
plan task: the plan authors per-task `gt create`/`gt modify` steps, but execute defers them to a
single end-of-increment commit. So a file created in Task 1 is still untracked when a later
verification task diffs against the base — the exact ordering the per-task-commit plan never sees.

- **Stage first, then diff:** `git add <new files>` before the inventory check — staged (tracked)
  additions do show in `git diff --name-only <base>`. Staging is not committing, so the
  one-commit-per-increment cadence is preserved.
- **Or run the inventory after the increment commit**, when everything is tracked.
- **Modifications to already-tracked files are unaffected** — only *new* files are invisible.

Caught live executing least-code-tenet Increment 3: the AC4 sweep expected 8 changed files but
`git diff --name-only main` showed 7 — the new `least-code.mdx` page was untracked. Staging it made
the diff report all 8.
