# Delivery and authorized Git tools

Shared guidance for workflows that commit, push, or open a pull request. The owning skill defines
its own workflow and content; this file covers only what several workflows share.

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

Identify the delivery target from current evidence. An open PR for this branch is reused. A closed
or merged match is evidence about the branch's history, not a prohibition; deciding whether this
work needs a new topic branch and PR, without overwriting history or duplicating one, is ordinary
judgment. Genuine ambiguity about the target, the base, or the scope blocks and is asked about.

Verify scope before committing, the target before publishing, and the resulting state afterward.
Recheck whatever a step changed or left uncertain. A lost write response is not proof of absence:
inspect the actual result before retrying, and never recommit, create a second PR or stack, or
push around a rejection with a reset, rebase, or force-push. Preserve unrelated work throughout.

## Native stack membership

A chained PR base is not native membership. Register a dependent PR only when the request or
repository workflow requires it, such as coordinated multi-task delivery where the caller supplies
the intended parent and ordered chain. Optional registration that is unavailable does not
invalidate an otherwise verified commit and PR; required registration that cannot be verified
stays incomplete and is reported as such.

Reuse precise existing membership without mutation. Otherwise make the smallest change that
establishes the intended order: append a child to its parent's stack, or create one stack from
verified bottom-to-top PRs when none of them is registered. A child already in another stack, a
non-top parent, or uncertain membership blocks registration and leaves the verified PR alone. Use
the repository's native stack capability scoped to that membership, not a stack-wide push,
submit, or sync, and claim no membership without a verified read.

The calling workflow owns affected-set discovery, conflict gates, review invalidation, and
descendant reconciliation. GitHub evaluates stacked-PR protections against the stack's trunk
rather than each child's base and expects linear history, so a changed lower-layer head or trunk
can break that linearity. Report the human-maintenance boundary instead of restacking, cascading,
or rewriting published heads, then re-read the affected evidence. An ordinary commit or same-PR
update is not a merge-readiness audit; see [GitHub's stacked pull
requests](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests) for the
provider's own requirements.
