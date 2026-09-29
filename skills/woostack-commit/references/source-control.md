# Delivery and authorized Git tools

## Authorized delivery

Use native Git with an available authorized GitHub integration, preferring the host's native
GitHub tools; host-authenticated `gh` is supported. Repository policy governs which operations run
and with which permissions. An unknown or unsupported capability blocks that operation, and a
backend failure stops the work rather than switching transport or credentials.

Git and canonical GitHub reads are the only evidence of repository state. Issue or Project
status, a provider artifact, and successful command output alone never prove a commit, push, PR,
or merge.

Read what the step needs: this worktree's branch, base, and diff, plus a targeted query for the
PR or stack it acts on. Widen the read only when that target is genuinely ambiguous.

## Targets and uncertain writes

Reuse the open PR for this branch. A closed or merged match informs branch and PR selection; it
does not prohibit new work. Ask about genuinely ambiguous targets, bases, or scope. Verify before
and after each write. On a lost response, inspect actual state before retrying; never duplicate a
commit, PR, or stack or push around a rejection. Preserve unrelated work.

## Native stack membership

A chained base is not native membership. Register only when requested or required, using the
verified parent and order. Optional unavailable registration does not invalidate a verified PR;
required unverified membership stays incomplete.

Reuse correct membership. For ordinary delivery, append to the parent's stack or create a stack
from unregistered PRs in bottom-to-top order; conflicting membership or non-top parents require
explicit maintenance scope. For consolidation, inspect affected stacks and use supported native
operations. GitHub's [unstack operation](https://docs.github.com/en/rest/pulls/stacks#remove-pull-requests-from-a-pull-request-stack)
removes removable unmerged PRs, not a selected member. Resolve collateral effects on unselected
members before writing; never assume a per-PR move endpoint or claim membership without read-back.

GitHub evaluates stacked protections against the trunk and expects linear history. Changed
lower-layer heads or trunks may invalidate descendants; reconcile within authorized scope, never
as an ordinary update's implicit cascade or readiness audit. See
[GitHub's stacked pull requests](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests).

## Published head safeguard

For an authorized rewrite, retain recoverable original heads and publish only the selected refs
with `--force-with-lease=<refname>:<expect>`, where `<expect>` is the exact remote SHA inspected
before rewriting, not an implicit lease from a mutable remote-tracking ref. An unexpected remote
advance requires reconciling that writer's work, never refreshing the lease just to overwrite it.
See [Git's lease semantics](https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegtltexpectgt).
