---
name: woostack-execute
description: Execute one approved Linear project increment, one exact Linear issue, or an approved local run manifest as a resumable sequential Graphite PR workflow. Never reviews or merges.
---

# woostack-execute

Execute approved work through one strict sequential controller. The controller is the source of
allocation, admission, ancestry, worktree, persistence, and delivery boundaries. Git, Graphite,
and canonical GitHub reads prove repository delivery; Linear or the local run manifest records the
approved contract and resume evidence but never proves source-control state.

## Commands

```text
/woostack-execute --project <exact Linear URL-or-UUID>
/woostack-execute <approved plan> --issue <exact canonical Linear issue reference>
/woostack-execute --run <exact-run-id> [--recheck]
```

`--project`, `--issue`, and `--run` are mutually exclusive; exactly one is required. `--recheck` is
valid only with `--run`. Execute accepts either exact Linear resources (`--project`/`--issue`) or an
exact local run manifest (`--run`), with no implicit or fuzzy discovery. Every cycle admits one
task or direct issue, one isolated worktree, and one PR. Execute does not perform review or merge
operations. The `--project` form is the resumable handoff from Build/Fix when mirroring is enabled;
`--run` is the resumable handoff from a local run manifest. Both are sufficient without chat memory
or fuzzy plan discovery.

## Admission

### Provider admission: one exact resource

In project mode (`--project`), require one exact project supplied by URL or UUID and reconstruct
authority from fresh official Linear reads of that project's complete specification, current
direct-issue graph, native dependency relations, and canonical repository association. In issue mode
(`--issue`), require one exact direct issue and the same complete reads for its owning project. Never
infer either resource or its records from chat memory, local files, titles, branch names, recent
activity, or prior transcript.

Independently read the selected resource, the complete project specification, every current direct
issue, all admitted native dependency relations, and the canonical repository association. In issue
mode, require the selected issue to be a current direct project issue. Missing, stale, ambiguous,
conflicting, unsupported, or incompletely paginated evidence blocks before repository mutation.
Statuses, labels, assignments, and comments do not authorize execution.

### Local run admission: exact manifest and plain artifacts

In local run mode (`--run`), require one exact run identifier corresponding only to
`<repo-root>/.woostack/tmp/runs/<exact-run-id>/`. Exact path only; fuzzy discovery, search, pattern
matching, directory traversal, or chat memory is rejected.

Admit local run files under the shared
[artifact contract](../woostack-init/references/artifact-backends.md#plain-markdown-artifacts-and-minimal-run-manifest):

1. Prove `.woostack/tmp/` is covered by Git ignore, then reopen `.woostack`, `tmp`, `runs`, and the
   exact run directory in order with no-follow semantics. Require the run directory to be owned by
   the current process user, mode exactly `0700`, and strictly beneath the admitted repository root.
2. Require `manifest.json`, `project-spec.md` (when present), `execution-plan.md` (when present), and
   `.lock` to satisfy the shared owner-only `0600` regular-file and ancestor checks; reject symlinks,
   non-regular files, broader permissions, foreign ownership, unexpected entries, and path escape.
3. Validate `manifestVersion: 1`, `manifestRevision`, `workflow`, `runId` matching `<exact-run-id>`,
   `repoRoot` matching the current canonical repository root, `status`, `planningParentBranch`,
   `planningParentTip`, empty `draft.unresolvedQuestions`, the complete stable-task/dependency graph,
   and `taskExecutions`. Reject `status: "abandoned"`; `status: "completed"` is an independently
   verified no-work result.
4. Pre-change runs whose manifests depend on removed approval receipts or fingerprints fail closed on
   admission, directing the user to regenerate plain artifacts under the owning Build/Fix workflow.

### Base-change detection and user choice

Before any worktree or source mutation in local run mode:

1. Read `planningParentBranch` and `planningParentTip` from the run manifest, and observe the current
   integration parent tip from fresh Git/Graphite/GitHub evidence.
2. If the observed parent tip equals `planningParentTip`, proceed directly to task execution.
3. If the observed parent tip differs from `planningParentTip`, report the old and current parent
   evidence plus any concrete conflict or plan risk, then ask the user before source mutation:
   - **`Continue`**: executes against the current admitted parent under existing branch/worktree safeguards.
   - **`Revise spec/plan`**: returns to the owning Build/Fix run for ordinary file updates without an
     acceptance gate.
   - **`Stop`**: makes no repository mutation.

When `--recheck` is provided with `--run`, invoke bounded [`woostack-harden`](../woostack-harden/SKILL.md)
against the current trunk / integration parent tip before execution. If discrepancies are found, report
them and offer `Continue`, `Revise spec/plan`, or `Stop`.

### Repository ancestry admission

Before any worktree or source mutation in all modes, read the approved stable parent-branch intent and
last admitted tip, then apply the shared
[repository ancestry contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
to fresh Git/Graphite/GitHub evidence. Execute carries the resulting current admitted tip and any
retained start/head into worktree discovery; it does not duplicate the shared decision matrix.

`--project` is **project mode**. `--issue` is **issue mode** and selects only that exact issue; it
never advances a sibling. `--run` is **local run mode** and executes the approved local manifest tasks
sequentially. All modes share the same repository ancestry admission and worker delivery loop.

### Active project status gate (provider modes only)

Before any worktree or source mutation in both `--project` and `--issue` modes, apply the shared
[active Execute project-start synchronization](../woostack-init/references/artifact-backends.md#active-execute-project-start-synchronization)
contract to the exact canonical nonterminal project. Independently read the complete, paginated
direct-issue set and project status, then resolve `artifacts.linear.issueStates.executing` and
`artifacts.linear.issueStates.inReview` to exactly one native issue state each and require both resolved
mappings to have native category `started` before any issue-lifecycle, worktree, or source mutation.
If any direct issue matches either resolved mapping by stable native identity and category, resolve
`artifacts.linear.projectStatuses.started`, require its native category `started`, and make the exact project
started (or record an exact started no-op) before continuing. Do not use a literal native status
name as authority. If all direct issues are
`Backlog`/`Todo`, defer the gate until the selected issue transitions to the resolved executing
mapping and reads back; then synchronize the project before repository work. Terminal project
conflict, missing/ambiguous/foreign/non-started mapping, drift, timeout, partial/foreign output, or
failed/unknown read-back blocks without reopening or continuing. The project-status receipt is
independent of the issue lifecycle receipt and resume-checkpoint evidence.

The gate mutates only the project's native status with one stable mutation identity and independently
reads back project identity, status ID/name/category, revision, and operation identity. An exact
started match is idempotent. Local run mode (`--run`) bypasses provider status synchronization.

## Execution controller

1. Read the complete approved task or direct-issue graph and classify every task/issue by its immutable
   positive ordinal.
2. Select the lowest-ordinal unfinished task or issue:
   - In provider modes, an issue is unfinished until its canonical state matches the resolved
     `artifacts.linear.issueStates.inReview` mapping and the full delivery checkpoint is independently read
     back; never select by activity, assignment, title, or status alone.
   - In local run mode, a task is unfinished unless its `taskExecutions[stableTaskKey].status` is
     `delivered` and its complete delivery checkpoint is independently read back.
3. For a non-root task/issue, read its immediate predecessor's complete delivery checkpoint, canonical
   parent branch, and current head (reading available checks for observation only); for the first task/issue,
   read the canonical integration parent branch and last admitted tip. Apply the shared repository
   advancement contract and carry its admitted result into worktree discovery. No other task or issue is
   admitted in the same cycle.
4. In provider modes, apply the active project status gate. When all direct issues are `Backlog`/`Todo`,
   persist and independently read back the selected issue's transition to the resolved
   `artifacts.linear.issueStates.executing` mapping first, then synchronize and independently read back the
   project's configured started status. Keep the project-status receipt distinct from the issue
   lifecycle receipt and project resume checkpoint. Local run mode bypasses this provider gate.
5. In local run mode, before worktree or source mutation, CAS-update
   `taskExecutions[stableTaskKey]` from `pending`/`blocked` to `active` with the exact intended task,
   worktree, branch, parent, and start tip; increment `manifestRevision` and independently reopen and
   verify it no-follow. A resumed `active` task must match that evidence exactly. Then create or resume
   exactly one deterministic isolated worktree owned by this run. Sequential within each run; distinct
   run IDs may execute concurrently in isolated worktrees only when paths and responsibility surfaces
   do not collide. Dispatch the configured fast-model subagent with the exact task scope and exclusive
   worktree ownership.
6. After the worker returns, run one focused verification and changed-path smoke scenario, then one
   bounded spec-compliance validator against the approved contract. When validation produces
   screenshots in provider mode, apply [Controller-owned screenshot evidence](references/controller.md#controller-owned-screenshot-evidence)
   before commit.
7. Commit and PR submission:
   - In provider modes, invoke [`woostack-commit`](../woostack-commit/SKILL.md) with `--issue` and the
     exact selected issue to commit and submit exactly one Graphite PR. Independently read back branch,
     commit, PR URL/head/base, the exact `Resolves <issue identifier>` body line, verification receipt,
     and Graphite parent.
   - In local run mode, invoke [`woostack-commit`](../woostack-commit/SKILL.md) without `--issue` and
     without a `Resolves` line. Independently read back branch, commit, PR URL/head/base, verification
     receipt, and Graphite parent.
8. Persist the complete delivery checkpoint:
   - In provider modes, persist the delivery checkpoint to Linear and independently read back every
     field. Only after that full read-back succeeds, resolve and independently read back the
     configured `artifacts.linear.issueStates.inReview` mapping and transition the issue from the resolved
     executing mapping to it, or read back an idempotent no-op when executing and inReview share one
     native status.
   - In local run mode, CAS-update `taskExecutions[stableTaskKey]` from `active` to `delivered` only
     with the complete delivery checkpoint (`{ stableTaskKey, ordinal, branch, commitSha, prUrl,
     prHead, prBase, graphiteParent, verificationReceipt, deliveredAt }`). Increment
     `manifestRevision`, reopen the manifest and plain artifacts no-follow, and verify every persisted
     field before worktree teardown or advancing to the next sibling.
   - If Linear mirror writes are configured in local run mode, they are best effort only: failure
     emits a warning and never invalidates, blocks, or overwrites the authoritative local checkpoint.
   Neither transition result can authorize teardown, resume, or sibling progression without the completed
   checkpoint read-back. The checkpoint must distinguish active from delivered work. Remove the worktree
   only after all required evidence is present and the exact worktree is clean.
9. Re-read the project/manifest, then continue with the next lowest unfinished ordinal unless a
   verified stop marker is encountered. A stop marker pauses before the next task and leaves the
   project/run open with exact resume evidence.

A successful cycle has no orphan worktree. At a failed, blocked, interrupted, colliding, or unknown
local boundary, CAS-update the active task to `blocked` with the first unknown boundary, branch,
commit/PR if any, dirty state, Graphite parent, verification receipt, delivery read-back, and exact
safe resume action; increment and independently read back the manifest revision. Retain the
worktree. Resume only after fresh independent evidence proves the same run and state and the shared
repository ancestry contract admits that evidence. Rediscover existing commits or PRs before
retrying and never create a duplicate.
Provider-mode failures retain the same evidence at their canonical project/issue boundary.

Issue mode performs exactly the selected issue's cycle once: admit its matching project context,
prove its predecessor's canonical parent branch and compatible current head (or the integration
parent branch for a root) under the repository ancestry contract, apply the active project status
gate (including the selected issue's transition to the resolved
`artifacts.linear.issueStates.executing` mapping when all direct issues are `Backlog`/`Todo`), then dispatch
one fast-model subagent in its isolated worktree.
The gate's project-status receipt stays separate from issue lifecycle and resume-checkpoint
evidence. Verify and validate the one issue, submit and read back one PR, then persist and
independently read back every field of the complete delivery checkpoint. Only after that full
read-back succeeds, move and read back the configured `artifacts.linear.issueStates.inReview` mapping. If
executing and inReview resolve to one native status, independently read the idempotent no-op instead
of issuing a second mutation. The lifecycle result authorizes removal of the clean worktree only
with the completed checkpoint read-back and all other required evidence. Issue mode never advances
siblings, even when the selected issue succeeds. Failures retain exact recovery evidence.

## Worker and verification boundary

Every implementation is delegated to the configured fast-model subagent; the controller must not
substitute local work or claim a dispatch it did not perform. The packet contains the exact task or
issue, task key, allowed paths, worktree path, canonical parent branch/current admitted tip,
retained start/head when resuming, Graphite parent, acceptance, and explicit prohibitions on scope
changes, credentials, source-control boundaries, provider writes, and work in another worktree.

The worker edits only its isolated worktree and returns changed paths, diff identity, focused check
and smoke observations, and one status. It does not commit, push, submit a PR, change Linear, review,
validate its own acceptance, or advance the controller. The controller owns screenshot inspection,
safe selection, attachment upload, inline comment, and fresh comment/image read-back; the worker never
receives Linear, attachment, browser, GitHub-write, commit, PR, review, acceptance, or sibling
authority. The controller runs only one focused verification/smoke and one small bounded
spec-compliance validator. Repair confirmed omissions in scope; broad quality findings, redesigns,
and unrelated cleanup return to the owning workflow.

## Lifecycle and repository delivery

For each admitted task or issue, lifecycle progression moves only through unstarted/Backlog/Todo →
executing → complete/inReview, with an independent read-back after each transition or an independently
read idempotent no-op when mappings share one native status. Persist observed branch, commit, PR,
verification, and the full delivery checkpoint, then independently read back every persisted checkpoint
field before the completion transition or idempotent no-op can authorize teardown, resume, or sibling
progression. Canonical state alone never proves delivery. Do not change the specification, task graph,
assignment, or ownership.

Successful PR submission requires all of: exact branch and commit, Graphite parent/read-back, one
canonical PR read-back with matching head/base, verification receipt, delivery checkpoint read-back,
and a clean exact worktree. Only then may the worktree be removed. Execute never reviews, merges,
marks product acceptance, or claims merged state.

`Delivered`, `complete`, `finish`, and `execute` stop at that verified open-PR boundary. They never
mean ready-for-review transition, auto-merge, merge-queue admission, retargeting for merge, or merge.
No user wording overrides this capability boundary: an explicit merge request is a conflict to
report before stopping, not authority to mutate the PR. Never run `gh pr ready`, `gh pr merge`, a
merge-queue mutation, or an equivalent Graphite/GitHub operation. A claim that the user requested
one of those operations must identify the exact current user message; absent provenance fails
closed, and proven wording still cannot override this no-merge boundary.

## Stop, interruption, and handback

A stop marker is an independently read control record that pauses selection; it is not an execution
failure. Interruptions, blocked decisions, collisions, and unknown provider or source-control
outcomes preserve the current project/run and worktree. Handback reports the exact project/run/issue
state, selected ordinal, predecessor/Graphite parent, worktree/branch, changed paths,
verification/validator results, delivery and Git evidence, known PR, first uncertain boundary, and
the next safe action. A later run resumes from independent evidence, not chat memory, local plan
files, branch names, activity, or duplicate submissions.
