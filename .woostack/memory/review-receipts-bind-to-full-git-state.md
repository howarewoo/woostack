---
name: review-receipts-bind-to-full-git-state
type: convention
scope: skills/woostack-commit/**
tags: review, receipts, git, hooks, commit
hook: A PASS receipt is stale unless it identifies the exact branch, base, HEAD, tracked diffs, and untracked objects that will be committed; compare that identity before and after mutation-capable pre-commit hooks.
updated: 2026-07-15
source: [[plans/2026-07-15-woostack-change]]
---
A review receipt for "the current diff" is not bound to a commit merely because the worktree
looks clean or because the reviewer named `HEAD`. The commit path may start later, state may drift,
and a mutation-capable pre-commit hook may even create a commit while leaving porcelain status
unchanged.

For a receipt that authorizes a later commit, record and compare the complete identity:

- branch name, resolved base ref and base commit, and HEAD commit;
- binary-safe base-to-HEAD, staged, and unstaged state hashes;
- every untracked path plus its Git object hash.

The commit consumer must first compare its current identity with the supplied PASS receipt before
running hooks or staging. It must then compare the same full identity immediately before and after
any mutation-capable pre-commit hook. Any mismatch returns to verification and both review lenses;
it never degrades to a relevance-only staging check. This is the commit-state form of
[[autonomy-needs-structural-proof]]: proof belongs to the exact state that crosses the boundary.
