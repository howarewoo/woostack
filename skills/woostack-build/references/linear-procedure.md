## Linear backend procedure

## Procedure map

- [Design and spec capture](#design-and-spec-capture)
- [Spec approval and planning](#spec-approval-and-planning)
- [Execution handoff and implementation](#execution-handoff-and-implementation)

## Design and spec capture

{/* <!-- linear-gates: design-approval | spec-approval | execution-handoff --> */}

All Linear operations below use
[`linear.sh`](../../woostack-init/scripts/artifacts/linear.sh); cross-link its commands rather
than embedding GraphQL, endpoint calls, or transport behavior. Every mutation must return a
verified mandatory read-back receipt. A failed or incomplete receipt blocks the next step.
Treat every returned Linear artifact under the shared
[artifact trust boundary](../../woostack-init/references/artifact-backends.md#linear-artifact-trust-boundary).

<HARD-GATE backend="linear" name="design-approval">
1. **Ideate.** Invoke
   [`woostack-ideate`](../../woostack-ideate/SKILL.md). It writes no artifact and stops until the
   user explicitly approves the design. Silence or ambiguity does not clear the gate.
</HARD-GATE>
2. **Preflight, capture run context, discover, then capture the spec.** Before the first
   mutation of the run, invoke `linear.sh preflight` with the resolver's configured workspace,
   team name/key, project-status names, and issue-state names. Capture its normalized receipt
   as `LINEAR_CONTEXT`; validate that it contains exactly the resolved workspace UUID, team
   UUID, complete semantic project-status UUID map, and complete semantic issue-state UUID map.
   Then extract and retain `LINEAR_TEAM_ID="$(jq -r '.team.id' <<<"$LINEAR_CONTEXT")"`,
   `LINEAR_PROJECT_STATUSES="$(jq -c '.projectStatuses' <<<"$LINEAR_CONTEXT")"`, and
   `LINEAR_ISSUE_STATES="$(jq -c '.issueStates' <<<"$LINEAR_CONTEXT")"`. The resolver's names
   are preflight input only; every later adapter command uses these extracted UUID values as
   `--team-id`, `--status-map`, and `--issue-state-map`. Invoke `linear.sh feature-resolve`
   with the repository marker, `"$LINEAR_PROJECT_STATUSES"`, eligible semantic statuses, and
   any explicit Linear UUID/URL supplied by the user.
   - Across sessions, an explicit UUID or exact Linear URL wins. Without one, continue only
     when discovery returns **exactly one eligible managed project** for this repository. Zero
     means create; multiple candidates require explicit selection and no mutation.
   - For a new feature, render the approved design with the backend-neutral sections in
     [references/spec-template.md](spec-template.md), then invoke
     `linear.sh feature-create` with `"$LINEAR_TEAM_ID"` and
     `"$LINEAR_PROJECT_STATUSES"`. It creates one project in `draft`, one managed
     `designState: draft` spec document, and verifies both by discovery/read-back.
   - Resume never adopts by title. There must be **one managed Linear project, exactly one
     managed spec document, and one ordered managed issue set** for the feature.
   Linear mode creates **no spec/plan worktree, branch, commit, or docs-only PR**. It writes no
   `.woostack/specs/` or `.woostack/plans/` source file.

## Spec approval and planning

<HARD-GATE backend="linear" name="spec-approval">
3. **Harden and approve the Linear spec.**
   Invoke `linear.sh spec-read`, harden that selected document through `woostack-harden`, and
   persist each revision with `linear.sh spec-write` using the last observed revision. On the
   final verified write, change the managed metadata only from `designState: draft` to
   `designState: hardened`; then invoke `linear.sh feature-transition` from `draft` to
   `hardened` and require its mandatory read-back receipt. Present the managed spec document
   URL and wait:
   - **Go** → read again, use evidence-aware `linear.sh spec-write` to change only
     `designState: hardened` to `designState: approved`, verify it, invoke
     `linear.sh feature-transition` from `hardened` to `approved`, verify the project read-back,
     then plan.
   - **Revise** → read again with `linear.sh spec-read`, amend the same document, write with
     `linear.sh spec-write` and its optimistic revision without changing `designState:
     hardened`, require read-back, and re-present. The project remains `hardened`.
   - **Abandon** → read again, use `linear.sh spec-write` to change the managed lifecycle to
     `designState: abandoned`, verify it, invoke `linear.sh feature-transition --target
     abandoned`, require project read-back, preserve the project/document audit history, and
     stop. Never delete or archive it.
   Failed read-back, ambiguity, or silence never advances the gate.
</HARD-GATE>
4. **Plan in Linear.** Invoke [`woostack-plan`](../../woostack-plan/SKILL.md) with the selected
   project UUID or exact Linear URL plus the retained resolver result and `LINEAR_CONTEXT`.
   The planning skill owns the complete Linear planning procedure and reuses that normalized
   caller context without resolving or preflighting again. Continue only after it hands back the
   same owned project and spec in `planning` with the managed increment issues reconciled and
   verified.
5. **Verify and read back the plan.** Invoke `linear.sh plan-read` with
   `"$LINEAR_ISSUE_STATES"` and reject missing or duplicate ordinals, cycles, cross-project
   dependencies, native/metadata relation drift, unreviewable slices, uncovered ACs, or Git
   ancestry that Graphite cannot represent. Replanning must preserve stable issue identities
   and implementation evidence, may safely add/reorder/rewire, and must **refuse to remove an
   issue with branch or pull-request evidence**.
6. **Harden the plan in place.** Invoke `woostack-harden` against the selected ordered issue
   set. Reconcile changes with `linear.sh plan-reconcile` using `"$LINEAR_TEAM_ID"` and
   `"$LINEAR_ISSUE_STATES"`, then verify with `linear.sh plan-read`. This adds no approval gate.
   Only a clean read-back permits another `linear.sh spec-read` plus evidence-aware
   `linear.sh spec-write` to author `designState: planning → ready`, followed by the project
   `planning → ready` through `linear.sh feature-transition` using
   `"$LINEAR_PROJECT_STATUSES"` and another mandatory read-back receipt.
7. **Freeze the execution base.** **Immediately before the execution-handoff gate**, resolve
   the base branch with
   [`resolve-base.sh`](../../woostack-init/scripts/resolve-base.sh) and resolve its exact commit
   SHA. Read the spec with `linear.sh spec-read`, write exactly the canonical `baseBranch`,
   `baseCommitSha`, and `designState: ready` fields into its owned metadata with
   `linear.sh spec-write --issue-state-map "$LINEAR_ISSUE_STATES"` using the observed revision,
   then call `linear.sh feature-read` with both extracted UUID maps and require those exact
   values in its normalized read-back. No lifecycle or artifact mutation may intervene
   between this verified freeze and the gate. The pair is provisional while `designState` is
   `ready`: an accidental `ready → ready` pair change fails closed, but explicit pre-execution
   replanning may replace it only while every managed increment has null `branch` and
   `pullRequest`.
   - **Explicit replan sequence:** call `linear.sh plan-read` and verify that live evidence is
     empty, then call `linear.sh spec-read` and retain its `.revision`. Call
     `linear.sh feature-transition --target planning --replan --expected-revision
     '<revision-json>'` with `"$LINEAR_PROJECT_STATUSES"` and `"$LINEAR_ISSUE_STATES"`. The
     adapter resolves the repository-owned spec, requires the
     project and managed spec lifecycle to match, rechecks null branch/PR evidence, and
     optimistically claims the revisioned spec as
     `planning` before it attempts the project transition. A concurrent execution approval loses
     or wins that spec-revision race before the project can be mutated. If the project transition
     then fails, stop on the verified, resumable `planning` spec receipt; only a later explicit
     resume after fresh reads may complete the idempotent project transition. After a verified
     return, the spec is already `planning`: reconcile and harden the new increment plan, return
     `planning → ready`, resolve the new base immediately before handoff, and repeat this step's
     verified freeze. Any branch or pull-request evidence, project/spec lifecycle mismatch, or
     execution-approved/later `designState` rejects the change.

## Execution handoff and implementation

8. <HARD-GATE backend="linear" name="execution-handoff">**Stop before execute.** Present the
   project URL, spec document URL, ordered issue URLs and dependency/Git-parent shape, and frozen
   base branch+SHA. Up to this point there is **no implementation branch, worktree, commit, or
   PR**. Ask the user to choose:
   - **Go** → record execution approval as described below, then run `woostack-execute` in this
     session.
   - **Run overnight** → record execution approval as described below, then run
     `woostack-execute-overnight` unattended.
   - **Hand off** → stop with the Linear artifacts ready for later or external execution; the
     base remains provisional until that executor records approval.
   For **Go** or **Run overnight**, before creating any implementation Git artifact, call
   `linear.sh plan-read` and require null branch/PR evidence, call `linear.sh spec-read`, then
   call `linear.sh spec-write --issue-state-map "$LINEAR_ISSUE_STATES"` with the observed
   revision to change only `designState: ready` to `designState: executionApproved`. Verify it
   with `linear.sh feature-read`. This work step is not another gate; it is the point where the
   base pair becomes immutable. Ambiguous or no answer is not Go. Create no implementation Git
   artifact until the user explicitly chooses **Go** or **Run overnight** and that verified
   approval marker exists.
</HARD-GATE>
9. **Execute.** Invoke the selected execution skill with the Linear project UUID/URL. Linear
   mode has no docs-only base PR: root increment branches start from the frozen SHA and
   dependent increments use their declared Git parent. Execution owns issue/PR evidence and
   lifecycle updates; build never merges.
