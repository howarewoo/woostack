# Canonical worktree contract

Worktrees isolate tracked implementation writes and make collisions/recovery explicit. They do not
own scope, allocation, dependencies, approval, acceptance, or merge authority. The approved
workflow contract owns those decisions; Git and canonical GitHub reads own repository state.
Select native Git + `gh` by default, or Graphite only when explicitly selected or verified as already
managing this task/stack, under the
[source-control contract](../../woostack-commit/references/graphite.md).
Linear is optional artifact context only.

`<wi>` below means the installed `woostack-init` skill directory. Its worktree helper is:

- `<wi>/scripts/resolve-base.sh` — resolve the configured integration base.

## 1. Identity, workspace resolution, and placement

Every active implementation task has one stable task ID, one branch, and one workspace. A planning
workflow may additionally supply a retained run ID; that ID is not executable scope. The approved
task contract supplies identity; the deterministic path plus direct Git and canonical GitHub evidence
supplies repository state. Require the ID to be one non-empty path component matching
`^[A-Za-z0-9][A-Za-z0-9._-]*$`; reject separators, whitespace, and any other encoding. Never derive
identity from a title, ordinal, recent activity, issue key, shortened hash, or disposable directory
name.

Resolve workspace isolation mode inline from the active session:

```sh
git_dir="$(cd "$(git rev-parse --git-dir)" && pwd -P)"
git_common_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)"
current_toplevel="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
primary_root="$(cd "$git_common_dir/.." && pwd -P)"
```

1. **Pre-isolated or linked worktree (`git_dir != git_common_dir`):**
   The active session already occupies an external or linked worktree (such as an Orca workspace,
   Graphite worktree, or human-created checkout). The task workspace is `$current_toplevel`. Woostack
   adopts this checkout in-place, does not create a nested worktree under `.woostack/worktrees/tasks/`,
   and marks the workspace as externally managed (`managed_worktree = false`).
2. **Primary checkout (`git_dir == git_common_dir`):**
   The active session is in the repository primary checkout (such as `main`). To protect the primary
   checkout, prevent dirty-state collisions, and keep `main` clean, Woostack creates and manages a task
   worktree at `$primary_root/.woostack/worktrees/tasks/<stable-task-id>`, marking it as managed
   (`managed_worktree = true`). Never nest a managed worktree inside another task worktree or a tracked
   source directory.

In-process subagents: all subagents spawned via the host harness (such as OMP `task` or Claude Code
`Task`) run within the host's session context and receive the resolved task workspace path
(`$current_toplevel` or the managed worktree path). They pin their working directory to that workspace
and communicate with the calling workflow through the host's in-process IPC.

Optional exact GitHub issue association may be recorded as descriptive context alongside the stable
task ID (see [`woostack-execute`](../../woostack-execute/SKILL.md#optional-exact-github-issue)), but it
replaces neither the stable task ID nor any repository identity.
## 2. Verified start point

A caller supplies one complete task-bound ancestry contract with stable approved `parentBranch`
intent, retained start/old-parent SHA, Git DAG evidence, and canonical PR base when a PR exists.
An upstream ref or merge-base alone is insufficient. Apply the shared
[repository ancestry contract](artifact-backends.md#repository-ancestry-and-base-change-detection)
to its last independently admitted parent tip. Mutable observed refs, heads, commits, and tips
remain repository evidence outside content approval identity. Never substitute the current
checkout, current branch tip, ordinal adjacency, a PR title, or inferred local ownership.

### Standalone bounded task

Resolve the integration branch with `<wi>/scripts/resolve-base.sh`; never hard-code `main` or
`staging`. Retain the exact canonical branch/ref and admitted tip from independent Git/GitHub
reads. Apply the shared repository advancement contract before using any newly observed tip for
fresh work.

### Plan dependency root

A root starts from its stable approved parent branch intent and last admitted tip. Fresh work may
start only at the latest tip after parent-tip admission. Multiple roots may
start there in parallel only when the complete approved DAG proves no dependency path and task IDs,
responsibility surfaces, runs, worktrees, branches, and PRs are disjoint.

### Plan dependency child

A child admitted to Execute declares its complete logical prerequisite set and exactly one concrete
Git parent for checkout: a declared predecessor or an explicitly approved integration branch/SHA
containing every prerequisite change. The integration parent need not represent a predecessor task.
The caller supplies the prerequisite and parent-readiness evidence; the bounded task verifies it as
ordinary evidence rather than discovering dependencies.
For every prerequisite, require its complete delivery checkpoint, branch/commit, canonical PR
identity/head/base, fully paginated current-head reviews, current PR state when a PR exists, and
approved ancestry to agree. A prerequisite PR need not be merged for Orchestrate stacked delivery:
independently verify the concrete parent's canonical branch/SHA and ancestry containing every required
predecessor change. A predecessor parent retains its prerequisite PR evidence. An approved integration
parent need not have its own delivery checkpoint or PR; verify its canonical PR head/base, reviews,
and current state whenever such a PR exists. Proven absence of an integration-parent PR is not missing
prerequisite evidence.
Read available checks for
observation only (incomplete or unavailable check reads never block). Apply the shared repository
advancement contract before using a newly observed descendant head for fresh child work. Start
retained work from its recorded state and revalidate ancestry, diff, and PR base; never silently
rebase, reset, recreate, or attach it to a different branch. Verified single-parent ancestry
containment of all prerequisite changes satisfies the parent requirement without PR merge: a
predecessor branch that already contains every required change is a permitted parent. If no single
verified parent branch contains all prerequisites, pause that task for an explicit parent/integration
decision before admission; an explicit decision alone still requires re-verified containment before
resume. Preserve the explicit decision, never invent an integration branch, and never require a merge
automatically. Reject inferred order, rewritten heads, unverified prerequisites, duplicate ancestry,
conflicts, or partial proof.

For a GitHub DAG dependent, the logical prerequisite set does not select a Git parent. Before
checkout, the caller must supply the explicit parent branch/SHA and complete readiness evidence
above. A join without that proof pauses that task before admission. Execute accepts one selected
bounded task, not its retained graph; other roots, forks, or joins in that graph do not disqualify
the task. [Orchestrate](../../woostack-orchestrate/SKILL.md) owns graph dispatch.

## 3. Direct identity and collision evidence

Before create, resume, review-reopen, handoff, commit, or teardown, take one complete snapshot of:

- the approved bounded-task contract and, when present, retained planning-run identity and workspace
  path;
- `git worktree list --porcelain`, including every checkout and its branch/HEAD;
- filesystem existence at the workspace path;
- local and remote branches/commits;
- staged, unstaged, untracked, conflict, and diff state in the relevant checkout;
- approved `parentBranch`, retained start/old-parent SHA, and Git DAG ancestry; in Graphite mode,
  also verify Graphite parent/stack metadata against that proof;
- fully paginated canonical GitHub PR head/base/state/reviews/threads and available checks; required
  checks remain delivery gates, while incomplete or unavailable non-required checks are observational.
The task identity comes from the active approved task contract or one completely verified handoff
packet. Repository reads cannot invent, replace, or transfer that identity. Branch display text, a
directory name, chat, recent activity, and artifact fields are never allocation evidence.

Require the workspace path to agree with both the filesystem and `git worktree list --porcelain`, the
branch to have at most one checkout, and every retained branch/commit/PR fact to form one consistent
ancestry. A material change while the snapshot is assembled invalidates it; repeat discovery rather
than combining observations from different states.
## 4. Discovery and recovery

Classify the complete direct-evidence snapshot:

1. **All absent:** for managed worktrees, the deterministic path is absent from the filesystem and
   worktree inventory; in all modes, no local/remote branch, commit, or canonical PR already
   represents the task.
2. **Pre-isolated workspace active:** the active checkout is an external or linked worktree, its
   branch and dirty/diff state match the approved task contract, and ancestry/parent facts agree.
3. **One exact retained state:** resume only when the deterministic path, worktree listing, branch,
   recorded start SHA/head, parent branch, ancestry, dirty/index/diff state, commits, and PR facts
   agree with the same approved task contract (and any retained planning-run evidence) or a completely
   verified handoff successor. A compatible descendant tip on the same canonical parent branch does
   not invalidate content receipts: preserve the retained start/head and freshly revalidate ancestry,
   diff, and PR base.
4. **Verified review-reopen:** the prior implementation worktree is absent (or pre-isolated workspace
   is clean), the same canonical branch and PR/head remain, the approved review-fix contract names the
   same stable task, the workspace path is free, and the branch is not checked out elsewhere.
5. **Partial or competing state:** stop. Preserve everything and report the exact conflicting
   paths, checkouts, branches, heads, ancestry, dirty state, or PRs.

Never delete, overwrite, reset, clean, stash, reassign, invent a new task ID, attach an unexplained
branch, or create around a collision.

## 5. Create, assert, or adopt

After the complete snapshot proves the intended operation collision-free:

### Pre-isolated workspace (`managed_worktree = false`)
1. verify the active checkout is `$current_toplevel` and matches `git worktree list --porcelain`;
2. if already on the approved `<branch>`, verify it is clean or matches the active task contract; if on
   the integration base or another branch, create and check out `<branch>` at
   `<latest-admitted-parent-tip>` using `git checkout -b <branch> <latest-admitted-parent-tip>`;
   in Graphite mode, use the selected backend's creation procedure at that verified start;
3. only in Graphite mode, from the task checkout use `gt track --parent <parentBranch>` with the
   approved parent branch, never the child `<branch>`;
4. verify physical path, common Git root, branch, HEAD/start, approved parent ancestry, and absence
   of another checkout; in Graphite mode also verify its parent metadata; and
5. re-read dirty/index/diff state plus canonical remote branch/PR evidence at the new boundary.

### Managed task worktree (`managed_worktree = true`)
1. verify the deterministic path is absent from both the filesystem and
   `git worktree list --porcelain`;
2. for fresh work, use `git worktree add -b <branch> <path> <latest-admitted-parent-tip>` after
   compatible parent-tip re-admission so Git exclusively rejects an existing branch, path, or
   checkout; for verified review-reopen, attach only the already verified canonical branch with
   `git worktree add <path> <branch>`;
3. only in Graphite mode, from the task checkout use `gt track --parent <parentBranch>` with the
   approved parent branch, never the child `<branch>`;
4. verify physical path, common Git root, branch, HEAD/start, approved parent ancestry, and absence
   of another checkout; in Graphite mode also verify its parent metadata; and
5. re-read dirty/index/diff state plus canonical remote branch/PR evidence at the new boundary.

A failed or partial post-create or adoption assertion is an unknown mutation boundary. Rediscover
direct repository state, preserve any observed branch/worktree, and stop; do not recreate, adopt, or
clean it automatically.

## 6. Operate only in the task workspace

Every source edit, implementation test, formatter, and task-scoped verification command runs from
the exact task workspace (`$current_toplevel` for pre-isolated checkouts or the managed worktree path).
Before the first tracked edit and every optional worker redispatch, recheck the approved bounded-task
contract and, when present, retained planning-run evidence, workspace path, `git worktree list
--porcelain`, branch, parent, allowed surface, and complete dirty/index/diff identity.

Keep one writer per overlapping task surface. A timeout or lost worker response leaves ownership
unknown: before overlapping redispatch, inline takeover, staging, or delivery, establish that the
previous writer stopped or relinquished ownership, then refresh the repository evidence above.
If liveness or ownership remains unknown, preserve the workspace and block overlapping mutation.

An optional coding worker never:

- reads or writes another task workspace or worktree;
- changes allocation, scope, plan dependencies, or acceptance;
- commits, pushes, submits, opens/updates a PR, restacks, or merges when the calling workflow owns those
  boundaries; bounded Execute's optional implementation worker may use Execute's own Commit path for
  its admitted task because Execute owns that delivery;
- accesses optional artifact credentials or mutates artifacts; or
- moves, removes, or repairs a task worktree.

A worker dispatched by Orchestrate through Execute uses only that Execute/Commit path for its own task
and never schedules siblings, modifies the parent/child hierarchy, or writes parent/Project progress.

An unexpected file, branch, checkout, worktree, dirty-state, or ancestry change blocks. Recovery is
decided only from the approved task contract, any retained planning-run evidence, and fresh direct
repository evidence.

After a completed child is delivered, the selected backend reconciles affected branches and
descendants from verified remote state. Native Git uses a local ancestry merge; Graphite uses its
guarded restack path. Neither mode force-pushes or mutates human merge authority.

Unknown commit/push/submit/reconciliation outcome requires direct rediscovery before retry. Never
duplicate a branch, commit, PR, or operation merely because a command returned unclearly, or switch
backends as error recovery.

## 8. Teardown

Teardown applies only after direct reads prove the task's workflow-owned boundary is complete:
finalized commit, clean task workspace, canonical PR/head/base when submission was requested, and no
unresolved local mutation.

1. **Managed worktrees (`managed_worktree = true`):**
   Re-resolve and verify the exact deterministic path immediately before
   `git worktree remove <path>`.
2. **Pre-isolated or external worktrees (`managed_worktree = false`):**
   Verify cleanliness, the finalized commit, and PR read-back, but **leave the workspace intact**.
   Never run `git worktree remove` on a user-owned, Orca-managed, or external checkout.

Keep branch, commits, PR, and optional artifacts. On failure, blocker, collision, handoff, or unknown
outcome, preserve the worktree and report:

- stable task/run ID and approved contract identity;
- workspace path and current `git worktree list --porcelain` entry;
- branch, start/old-parent SHA, approved `parentBranch`, and selected source-control mode;
- dirty/index/diff, commit, and PR state;
- first unverified boundary; and
- exact safe next action.

Never use teardown as cleanup for unexplained state.
## 9. Greenfield bootstrap boundary

A genuinely greenfield target has no Git repository yet, so it cannot use this worktree contract
before scaffolding. [`woostack-bootstrap`](../../woostack-bootstrap/SKILL.md) owns collision-safe
creation. Once Git exists, later bounded tasks use this contract normally.
