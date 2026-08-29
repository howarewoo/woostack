---
name: woostack-execute
description: Execute one approved Linear, Plane, or GitHub project increment, one exact Linear/GitHub issue or Plane work item, or an approved local run manifest as a resumable sequential Graphite PR workflow. Never reviews or merges.
---

# woostack-execute

Execute approved work through one strict sequential controller. The controller is the source of
allocation, admission, ancestry, worktree, persistence, and delivery boundaries. Git, Graphite,
and canonical GitHub reads prove repository delivery; Linear, Plane, GitHub, or the local run manifest records the
approved contract and resume evidence but never proves source-control state.

## Commands

```text
/woostack-execute --project <exact Linear or GitHub Project URL-or-UUID>
/woostack-execute <approved plan> --issue <exact canonical Linear/GitHub issue or Plane work-item reference>
/woostack-execute --run <exact-run-id> [--recheck]
```

`--project`, `--issue`, and `--run` are mutually exclusive; exactly one is required. `--recheck` is
valid only with `--run`. Execute accepts either exact provider resources (`--project`/`--issue`) or an
exact local run manifest (`--run`), with no implicit or fuzzy discovery. When `artifacts.provider: "local"` or
omitted, direct provider execution via `--project` or `--issue` fails closed before any provider access.
When `artifacts.provider: "linear"`, `--project` accepts an exact Linear project and `--issue` accepts an
exact direct Linear issue. When `artifacts.provider: "plane"`, `--project` is not an executable scope and
is rejected before any mutation; `--issue` accepts an exact Plane work-item URL or readable ID (such as
`ENG-42`), resolving and independently reading back its native UUID in the exact configured Plane
project. When `artifacts.provider: "github"`, `--project` accepts an exact canonical GitHub Project URL and
`--issue` accepts an exact canonical parentless repository issue URL (`https://github.com/owner/repo/issues/<N>`).
Every cycle admits one task or direct issue/work item, one isolated worktree, and one PR. Execute does not perform
The `--project` form is the resumable handoff from Linear or GitHub Build/Fix when mirroring
is enabled; `--issue` is the handoff for an exact Linear issue, Plane work item, or GitHub issue (top-level specification item or
individual child/increment); `--run` is the resumable handoff from a local run manifest. All forms are sufficient without chat
memory or fuzzy plan discovery.
## Admission

### Provider admission: one exact resource

In project mode (`--project`), require `artifacts.provider` to be `"linear"` or `"github"`. For Linear, require one
exact Linear project supplied by URL or UUID. For GitHub, require one exact canonical Project URL
(`https://github.com/orgs/<owner>/projects/<N>` or `/users/<owner>/projects/<N>`). Reconstruct authority from
fresh official provider reads of that project's complete specification (managed README section for GitHub), current
direct parentless repository issue graph (`parent = null`), direct Project item membership, native dependency
relations ($N-1$ strict predecessor blocks successor edges), and canonical repository association. Plane does
not accept `--project` as an executable scope; the configured project may contain multiple specification items
and cannot be executed as a whole.

In issue mode (`--issue`):

1. **Linear issue mode:** require one exact direct issue (`parent = null`) and the same complete reads for
   its owning project. Issue mode executes only that exact issue and never advances siblings.
2. **Plane work-item mode:** require one exact work-item reference (`--issue`), resolving to its native
   UUID within `artifacts.plane.project` under the configured instance `baseUrl` and `workspace`.
   Plane admission admits either:
   - **Top-level specification work item (`parent = null`):** titled `[Build] <goal>`, `[Fix] <goal>`, or
     `[Plan] <goal>`, with its full specification in its description. Execute discovers and admits its
     complete, exact single-parent child graph (`parent = <spec-item-UUID>`) and strict sequential sibling
     blocking relations (`blocks`: `ordinal 1` blocks `ordinal 2` ... `ordinal N`). Execution progresses
     strictly through the unfinished children of this specification item in ordinal order.
   - **Exact child increment work item (`parent = <spec-item-UUID>`):** an exact child of a valid specification
     work item. Issue mode executes only this exact child work item and never advances siblings.
3. **GitHub issue mode:** require one exact canonical repository issue URL (`https://github.com/owner/repo/issues/<N>`,
   `parent = null`) and the same complete reads for its owning Project. Issue mode executes only that exact issue
   and never advances siblings.

Never infer either resource or its records from chat memory, local files, titles, branch names, recent
activity, or prior transcript. Reject repository projects (`--project`), cross-parent relations (relations
between children of different specification parents or foreign items), missing, duplicate, ambiguous,
unparented children, foreign-scope, and malformed graphs before repository or provider mutation. Statuses,
labels, assignments, and comments do not authorize execution.
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
them and offer `Continue`, `Revise spec/plan`, or `Stop`. When `--recheck` encounters an already-delivered
task whose verified existing open PR lacks the exact mapped GitHub issue association, recovery reuses the
recorded delivery checkpoint and verified open PR: verify that the PR is open and matches the recorded
checkpoint identity (`prUrl`, `prHead`/`branch`, `prBase`, `commitSha`), repair and read back exactly one
matching `Resolves <canonical issue URL>` line, and stop before creating any worktree, branch, commit, or PR,
without mutating issue lifecycle. If the PR is closed or merged, or if checkpoint identity mismatches,
recovery rejects mutation with zero changes.

### Repository ancestry admission

Before any worktree or source mutation in all modes, read the approved stable parent-branch intent and
last admitted tip, then apply the shared
[repository ancestry contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
to fresh Git/Graphite/GitHub evidence. Execute carries the resulting current admitted tip and any
retained start/head into worktree discovery; it does not duplicate the shared decision matrix.

`--project` is **Linear or GitHub project mode** (repeatedly running cycles for the lowest unfinished direct issue).
`--issue` with a top-level Plane specification work item is **Plane specification mode** (repeatedly cycling
its admitted unfinished children in strict ordinal order until all children complete or a stop marker is read).
`--issue` with an exact Linear direct issue, exact Plane child work item, or exact GitHub repository issue is
**exact issue mode** (performing one cycle for the selected item only and never advancing siblings). `--run` is
**local run mode** (repeatedly running cycles for each unfinished task in the approved manifest). All modes share the same repository ancestry
admission and worker delivery loop.

### Selected-provider lifecycle gate

Before provider access, load the shared
[active Execute synchronization contract](../woostack-init/references/artifact-backends.md#active-execute-project-start-synchronization)
and only the selected [Linear](../woostack-init/references/artifact-providers/linear.md),
[Plane](../woostack-init/references/artifact-providers/plane.md), or
[GitHub](../woostack-init/references/artifact-providers/github.md) profile.

Before any worktree or source mutation in project or issue mode, resolve and independently read back
the profile-defined lifecycle mappings and allowable native categories/groups in exact provider scope.
Apply only transitions supported by that profile. Keep project-lifecycle, specification parent lifecycle,
direct-resource lifecycle, delivery-checkpoint, and resume receipts distinct.

For Plane, resolve configured `artifacts.plane.issueStates` (executing, inReview, done, blocked) by exact native
UUID or exact case-sensitive name within canonical baseUrl/workspace/project scope; reject missing, ambiguous,
duplicate, foreign-scope, or group-mismatched states before mutation. Parent lifecycle aggregates its children:
parent `executing` while active work is underway, parent `blocked` when any child blocks, and parent `done` only
when all children complete. The configured Plane project status is never mutated, synthesized, or gated.

For GitHub, resolve configured `artifacts.github.statusField` (default `"Status"`) and five options (`planned`,
`executing`, `inReview`, `done`, `blocked`) by exact case-sensitive name in exact owner/Project scope; reject missing,
ambiguous, duplicate, foreign-scope, parented issues (`parent != null`), or closed issues in nonterminal states before
issue only at `done`. Finished predicate requires item status `done`, issue state `CLOSED`, and complete delivery
checkpoint read-back. Recorded blockers set `blocked` without closing. If an increment is observed with item status
`done` and a complete delivery checkpoint but the issue remains `OPEN`, execute close-only recovery: perform and independently read back issue closure
without rerunning repository work or rewinding lifecycle state (if inReview with complete delivery checkpoint, transition and read back item `done` before close). Completing all increments leaves the Project open;
only explicit provider-backed closure closes the admitted Project after fresh read-back.

An exact current mapping is an idempotent no-op. A terminal conflict, missing/ambiguous/foreign
mapping, drift, timeout, partial output, unsupported transition, or failed/unknown read-back blocks
without reopening or continuing. Never synthesize a project transition from a direct-resource state.
Local run mode bypasses provider lifecycle synchronization.
## Execution controller

1. Read the complete approved task or direct-resource graph and classify every entry by immutable
   positive ordinal. In provider mode, resolve every lifecycle mapping required by the selected
   profile in exact scope and independently read back its native identity, name, and category/group.
2. Select the lowest-ordinal unfinished entry:
   - In provider mode, apply the selected profile's finished predicate to independently read lifecycle
     state plus the complete delivery checkpoint. Never select by activity, assignment, title, or
     unverified status alone.
   - In local run mode, a task is unfinished unless its `taskExecutions[stableTaskKey].status` is
     `delivered` and its complete delivery checkpoint is independently read back.
3. For a non-root task/issue, read its immediate predecessor's complete delivery checkpoint, canonical
   parent branch, and current head (reading available checks for observation only); for the first task/issue,
   read the canonical integration parent branch and last admitted tip. Apply the shared repository
   advancement contract and carry its admitted result into worktree discovery. No other task or issue is
   admitted in the same cycle.
4. In provider mode, apply the selected profile's supported pre-execution lifecycle transition and
   independently read it back before repository work (for Linear, project start synchronization and issue
   transition to executing; for Plane, transitioning the selected work item and its parent specification
   work item to `artifacts.plane.issueStates.executing` without project status mutation; for GitHub,
   transitioning the selected Project item to `executing` status option and independently reading back item
   status without project mutation). Apply any supported project synchronization separately and preserve
   distinct project, direct-resource, and checkpoint receipts. Unsupported project lifecycle is a required
   no-op. Local run mode bypasses this provider gate.
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
   screenshots in Linear provider mode, apply [Controller-owned screenshot evidence](references/controller.md#controller-owned-screenshot-evidence)
   before commit. For Plane and GitHub provider modes, screenshot attachment and comment evidence are Linear-only and
   explicitly skipped; continue repository delivery.
7. Commit and PR submission:
   - In Linear provider mode, invoke [`woostack-commit`](../woostack-commit/SKILL.md) with `--issue` and the
     exact selected Linear issue to commit and submit exactly one Graphite PR. Independently read back branch,
     commit, PR URL/head/base, the exact `Resolves <issue identifier>` body line, verification receipt,
     and Graphite parent.
   - In Plane provider mode, invoke [`woostack-commit`](../woostack-commit/SKILL.md) without `--issue`
     (Commit does not support Plane in this increment; no `Resolves` line). Independently read back branch,
     commit, PR URL/head/base, verification receipt, and Graphite parent, and persist/read back the PR delivery
     checkpoint through Execute's Plane work-item path.
   - In GitHub provider mode, invoke [`woostack-commit`](../woostack-commit/SKILL.md) with `--issue` and the
     exact selected canonical issue URL to commit and submit exactly one Graphite PR. Independently read back branch,
     commit, PR URL/head/base, the exact `Resolves <issue URL>` body line, verification receipt,
     and Graphite parent.
   - In local run mode:
     - If `mirror.provider` is `"github"` and `stableTaskMappings[stableTaskKey]` contains an exact bound
       canonical repository issue URL (`https://github.com/<owner>/<repo>/issues/<N>`), verify the canonical
       issue live against the admitted repository. If verified, invoke [`woostack-commit`](../woostack-commit/SKILL.md)
       with `--issue <canonical issue URL>` regardless of aggregate mirror status. Independently read back
       branch, commit, PR URL/head/base, verification receipt, Graphite parent, and exactly one matching
       `Resolves <canonical issue URL>` body line when association succeeds. If pre-Commit live issue verification
       fails (for example, missing, foreign-scope, or parented issue), warn, record the mirror failure, and continue
       repository delivery by invoking [`woostack-commit`](../woostack-commit/SKILL.md) without `--issue` and without
       blocking local checkpoint persistence. If post-submission association or read-back fails after PR creation,
       warn, record the mirror failure, rediscover and reuse the verified branch, commit, PR, and Graphite parent,
       and persist the local delivery checkpoint without replaying Commit or creating duplicate objects; `--recheck`
       remains available to repair the missing association on the existing open PR later.
     - For local runs with provider `local`, an omitted or unmapped task mapping, or a non-GitHub provider
       (Linear or Plane), invoke [`woostack-commit`](../woostack-commit/SKILL.md) without `--issue` and
       without a `Resolves` line. Independently read back branch, commit, PR URL/head/base, verification
       receipt, and Graphite parent.
8. Persist the complete delivery checkpoint:
   - In Linear provider mode, persist the delivery checkpoint to Linear and independently read back every field.
     Only after that full read-back succeeds, resolve and independently read back the configured inReview mapping
     (`artifacts.linear.issueStates.inReview`) and transition the issue from the resolved executing mapping to it,
     or read back an idempotent no-op when executing and inReview share one native status.
  - In Plane provider mode, persist the delivery checkpoint to Plane and independently read back every field.
    Only after that full read-back succeeds, resolve and independently read back the configured inReview mapping
    (`artifacts.plane.issueStates.inReview`) by exact native UUID or exact case-sensitive name with group `started`,
    and transition the work item from the resolved executing mapping to it, reading back its native state ID, name,
    and group, or read back an idempotent no-op when executing and inReview share one native status. If all child
    work items of the parent specification work item are now finished, transition the parent specification work
    item to `artifacts.plane.issueStates.done` and independently read back native ID, name, and group.
   - In GitHub provider mode, persist the delivery checkpoint to GitHub and independently read back every field.
     Only after that full read-back succeeds, transition the Project item to the configured `inReview` status option
     (or read back an idempotent no-op) and independently read back item status. On verified completion of an increment,
     transition the Project item to `done`, close the repository issue (`issueClose`), and independently read back both.
     Completing all increments leaves the Project open; only explicit provider closure closes the Project.
   - In local run mode, CAS-update `taskExecutions[stableTaskKey]` from `active` to `delivered` only
     with the complete delivery checkpoint (`{ stableTaskKey, ordinal, branch, commitSha, prUrl,
     prHead, prBase, graphiteParent, verificationReceipt, deliveredAt }`). Increment
     `manifestRevision`, reopen the manifest and plain artifacts no-follow, and verify every persisted
     field before worktree teardown or advancing to the next sibling.
   - If Linear, Plane, or GitHub mirror writes are configured in local run mode, they are best effort only: failure
     emits a warning and never invalidates, blocks, or overwrites the authoritative local checkpoint.
   Neither transition result can authorize teardown, resume, or sibling progression without the completed
   checkpoint read-back. The checkpoint must distinguish active from delivered work. Remove the worktree
   only after all required evidence is present and the exact worktree is clean.
9. Re-read the project/manifest, then continue with the next lowest unfinished ordinal unless a
   verified stop marker is encountered. A stop marker pauses before the next task and leaves the
   project/run open with exact resume evidence.

A successful cycle has no orphan worktree. At a failed, blocked, interrupted, colliding, or unknown
boundary, retain the worktree and record the first unknown boundary, branch, commit/PR if any, dirty state,
Graphite parent, verification receipt, delivery read-back, and exact safe resume action.
In Plane provider mode, transition and independently read back the selected work item and its parent
specification work item to the configured `artifacts.plane.issueStates.blocked` mapping (resolved by
exact native UUID or exact case-sensitive name with group `started`, reading back its native state ID,
name, and group) with recovery evidence before a failed Plane cycle can resume.
In GitHub provider mode, transition and independently read back the selected Project item to the configured
`artifacts.github.projectStatuses.blocked` mapping without closing the issue, retaining recovery evidence.
In local run mode, CAS-update the active task to `blocked` with that recovery evidence, increment and independently
read back the manifest revision. Retain the worktree. Resume only after fresh independent evidence proves the
same run and state and the shared repository ancestry contract admits that evidence. Rediscover existing commits
or PRs before retrying and never create a duplicate.
Linear provider-mode failures retain the same recovery evidence at their canonical project/issue boundary.

In exact issue mode (Linear direct issue, Plane exact child work item, or GitHub repository issue), Execute performs exactly the selected
issue or work item's cycle once: admit its matching project context, prove its predecessor's canonical parent
branch and compatible current head (or the integration parent branch for a root) under the repository ancestry
contract, apply the active project status gate for Linear (including the selected issue's transition to the
resolved `artifacts.linear.issueStates.executing` mapping when all direct issues are `Backlog`/`Todo`) or transition
the selected Plane child work item and its parent specification work item to `artifacts.plane.issueStates.executing`
(resolving configured issueStates by exact native UUID or case-sensitive name in exact scope, validating allowable
group semantics, and reading back native state ID, name, and group) and read back without project mutation, then
dispatch one fast-model subagent in its isolated worktree.

In Plane specification mode, Execute repeatedly runs cycles for the lowest unfinished child work item in strict
ordinal order, advancing to the next unfinished child after each verified delivery checkpoint, and transitions the
parent specification work item to `artifacts.plane.issueStates.done` only when all admitted children complete.

For Linear, the gate's project-status receipt stays separate from issue lifecycle and resume-checkpoint
evidence. Verify and validate the active issue/work item, submit and read back one PR (with `--issue` for Linear and GitHub;
without `--issue` for Plane), then persist and independently read back every field of the complete delivery checkpoint.
Only after that full read-back succeeds, move and read back the configured inReview mapping
(`artifacts.linear.issueStates.inReview` for Linear; `artifacts.plane.issueStates.inReview` for Plane). If executing and
inReview resolve to one native status, independently read the idempotent no-op instead of issuing a second mutation.
The lifecycle result authorizes removal of the clean worktree only with the completed checkpoint read-back and all
other required evidence. Exact issue mode never advances siblings, even when the selected issue succeeds. Failures
retain exact recovery evidence (transitioning both child work item and parent specification work item to
`artifacts.plane.issueStates.blocked` in Plane provider mode).

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
