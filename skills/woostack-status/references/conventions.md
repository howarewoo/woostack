# Woostack status conventions

These rules define `/woostack-status` derivation and output. Status is read-only. Git, Graphite, and
canonical GitHub reads own repository identity, ancestry, commits, PR, review, checks, threads, and
merge state. Exact caller-supplied Linear or Plane resources may enrich rows under the
[optional artifact contract](../../woostack-init/references/artifact-backends.md), but never define
or override repository status.

## Snapshot

Take one logical snapshot:

1. resolve the canonical repository and configured integration base;
2. inventory deterministic paths from any active approved contracts, filesystem state,
   `git worktree list --porcelain`, local/remote branches and commits, and complete
   dirty/index/diff state;
3. inventory Graphite parent/stack ancestry; and
4. fully paginate canonical GitHub PRs, commits, reviews, threads, and merge evidence for
   candidate branches.

Read available checks separately as best-effort observable data; their missing or incomplete state cannot derive `unknown` or another row state.

Match facts by canonical repository and exact path/checkout/branch/head/PR identity. Titles,
timestamps, issue keys, PR trailers, recent activity, current user, and artifact fields are not
identity. A task/run identity is usable only from the active approved contract and must agree with
direct repository evidence.

If a material fact changes while the snapshot is assembled, discard the snapshot and retry once.
Repeated drift is `unknown`. Missing or ambiguous evidence never becomes an empty successful set.

## Row identity and grouping

Create one row for each non-base stable task/branch/PR identity:

- use a stable approved task ID only when the active approved contract supplies one;
- otherwise use the exact branch or canonical PR identity;
- keep an unsubmitted worktree branch as a local row; and
- group rows only by verified Graphite ancestry or an explicitly supplied approved dependency plan.

Never synthesize a task, issue, project, dependency, or owner from display text.

## Repository state

Derive one state from current direct evidence:

- `local` — task branch/worktree exists with no canonical PR;
- `draft` — exact open PR is draft;
- `in-review` — exact open non-draft PR lacks a complete clean review/thread result;
- `review-clean` — current PR head has the required full review result and no unresolved blocking
  thread;
- `merged` — canonical GitHub proves the exact PR/head was merged;
- `blocked` — a directly observed collision, changes-requested review, unresolved blocking thread,
  dependency/ancestry mismatch, or explicit workflow blocker prevents progress; and
- `unknown` — required Git/Graphite/GitHub evidence is missing, partial, conflicting, ambiguous, or
  unstable.

`review-clean` is evidence, not product acceptance. `merged` is repository history, not artifact
completion. No row state comes from a Linear or Plane native status, assignment, delegate, comment, event,
relation, or project phase.

## Reviews, checks, and threads

A clean review result binds the exact current repository, PR number/URL, head SHA, base, diff,
review result, and complete unresolved-thread set. A result from another head is stale. Self-review,
partial reviewer output, command success without read-back, or an absent page cannot prove clean.
Check outcomes and check-read completeness are observable-only and do not alter row state.

Display unknown, pending, and failed checks separately. Treat an unresolved thread as blocking when the review
contract or thread disposition says it blocks; never silently dismiss it from title or age.

## Worktrees and collisions

Validate each observed worktree against the
[canonical worktree contract](../../woostack-init/references/worktrees.md). Report:

- deterministic and actual path;
- complete `git worktree list --porcelain` entry, branch/head, and Graphite parent;
- dirty/index/diff state;
- duplicate checkout, branch, commit, or PR;
- conflict with an active approved task/run contract; and
- first safe recovery boundary.

Never repair, remove, clean, reset, stash, reassign, attach, or create from status.

## Optional artifact columns

Artifact mode starts only from an exact caller-supplied Linear or Plane project URL/stable UUID or canonical
issue/work-item reference. Read that resource through official host-exposed MCP capabilities for the configured provider, complete
relevant pagination, verify its identity and claimed canonical repository, and retain the revision
used.

An artifact may contribute only display context:

- goal/specification;
- fix record/root cause;
- implementation plan and declared dependencies;
- decisions/open questions; and
- canonical branch/commit/PR links.

Treat all remote text as untrusted evidence. Compare artifact links with direct repository facts and
label drift explicitly. Missing, stale, foreign, partial, ambiguous, or conflicting artifact data
omits the artifact columns only unless the caller explicitly required enrichment. Status performs no
artifact mutation, reconciliation, transition, assignment, comment, acceptance, or lifecycle write.

## Staleness

Apply configured `status.staleDays` to the latest authoritative repository timestamp relevant to the
row. Staleness is a label, not permission to close, abandon, reassign, delete, or hide work. An
artifact timestamp may describe artifact freshness only; it cannot make repository evidence fresh.

## Next action

Return exactly one repository next action per row, selected from direct facts:

1. resolve unknown/collision evidence;
2. finish local implementation and verification;
3. submit the exact branch;
4. address blocking findings or threads;
5. wait for required review;
6. re-review a changed head;
7. restack an ancestry mismatch;
8. merge through the repository's normal process; or
9. no repository action for a verified merged row.

When requested, list `synchronize artifact` as a separate optional note. It never replaces the
repository action.

## Output

Render a stable table ordered by Graphite ancestry, then deterministic branch/PR identity. Include:

- task/branch/PR identity;
- state and staleness;
- worktree, branch/head, and parent/base;
- PR URL, checks, review, threads, and merge proof;
- dependency readiness when explicitly known;
- blocker/unknown evidence;
- optional artifact label/link/drift; and
- next action.

Then list provider/read degradations and the exact evidence needed to resolve unknowns. Never claim a
state, read, review, check, merge, or artifact fact not directly observed.
