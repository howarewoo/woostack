# Linear project lifecycle procedure

<!-- linear-gates: design-approval | spec-approval | execution-handoff -->

<!-- <LINEAR-ONLY-AUTHORITY> -->
Use only the official host-exposed Linear MCP capabilities established by
[linear-context.md](linear-context.md). The canonical
[authority contract](../../woostack-init/references/artifact-backends.md) owns the managed metadata
schema and trust boundary. The procedure below owns one multi-increment `feature` project; a
standalone one-issue fix or change is not part of this lifecycle.
<!-- </LINEAR-ONLY-AUTHORITY> -->

## Event write discipline

Every project update has one readable body and one `projectEvent` envelope containing the canonical
`schema`, stable event `clientId`, canonical `repository`, exact `label` and `role`, native
`projectId`, canonical `event`, positive `revision`, `predecessorId`, sorted `relatedIds`, and
nullable `supersedesId` fields.

Allocate the event UUID before mutation. A new event starts at revision 1 with no supersession. A
phase event points to the immediately preceding current phase update; only `designApproved` has a
null predecessor. A non-phase event points to the current phase head for context but does not join
or advance the phase chain. Independently read back every append before doing the work it
authorizes.

A phase event correction may target only the current phase head. Append the same stable event UUID
at exactly the next revision, preserve its event kind, project identity, and predecessor, and set
`supersedesId` to that current phase update's exact native ID. Before any further action,
independently read back the corrected event and the complete one-head phase chain. A historical or
non-head phase correction stops before mutation and requires explicit human-directed recovery; it
never cascades descendant revisions or implies a multi-write transaction.

A non-phase project event correction may target only that event's current revision, whether or not
it is the phase head. Append the same stable event UUID at exactly the next revision, preserve its
event kind, project identity, and contextual phase `predecessorId`, and set `supersedesId` to that
current event revision's exact native update ID. Independently read the corrected record back before
further action. It does not advance, replace, or rewrite the phase chain and never cascades
descendant revisions.

A managed issue comment/event correction may target only that issue event's current revision.
Append the same stable event UUID at exactly the next revision, preserve its event kind and exact
project-plus-issue identity, and set `supersedesId` to that current comment/event revision's exact
native ID. Independently read the corrected record back before further action. It has no phase-head
requirement and never rewrites descendants.

For every correction class, a missing or stale superseded record, wrong identity, event kind, or
context, skipped or duplicate revision, competing current revisions, missing receipt, or ambiguity
fails closed before further mutation.

For a phase whose required native category differs from the current category, append and verify the
typed phase first, then change the native status and read that mutation back. If the second mutation
has an unknown outcome, resume only that exact pending status mutation after re-verifying the phase;
never append a duplicate phase. When the category is unchanged, verify it without a needless write.

## Design, shape classification, and project creation

1. Establish the repository context and capability preflight. Resolve the authenticated actor.
   Generate and retain a feature resource UUID for new work, but do not create a Linear development
   resource yet. Repository policy, reversible capability discovery, and read-only lookup by an
   explicit project reference are allowed before design approval; development-record mutation is
   not.
2. For a new request, invoke [`woostack-ideate`](../../woostack-ideate/SKILL.md) inside the build's
   named design gate:

<HARD-GATE name="design-approval">
`woostack-ideate` presents the complete design and obtains its explicit approval. Its approved
return clears this gate; build must not ask for design approval a second time. Silence, ambiguity,
partial agreement, a native status, or a pre-existing title clears nothing.
</HARD-GATE>

3. Immediately classify the approved design before any project mutation. A bounded fix routes to
   [`woostack-fix`](../../woostack-fix/SKILL.md); any other bounded change that fits one reviewable
   PR routes to [`woostack-change`](../../woostack-change/SKILL.md). Hand off the approved design
   and stop this workflow without creating a project. Only a coherent multi-increment feature
   continues.
<!-- <LIFECYCLE-TRANSITION phase="designApproved"> -->
4. Perform repository-scoped discovery by the retained feature UUID and complete managed identity.
   For new work, zero matches permits creation of one project with the UUID already embedded in its
   managed overview, the canonical repository URL, exact `woostack` label, role `feature`, approved
   goal/scope, configured workspace/team, authenticated actor as its single lead, and native
   `backlog` status. Independently read the project and lead back, then append `designApproved` at
   revision 1 with a new stable event UUID, null `predecessorId`, no supersession, and a readable
   body containing the complete approved design and approval evidence. Independently verify the
   event envelope, project identity, lead, configured `backlog` category, and one-head chain. An
   unknown append is retried only by rediscovering that exact event UUID.
<!-- </LIFECYCLE-TRANSITION> -->

   For resume, require exactly one ownership-valid project with exactly one lead and one valid
   current phase chain. The authenticated actor must be that lead before any gate decision or
   project-update mutation. Continue from the observed current head and skip every completed gate
   and phase step. Never append another `designApproved`, replay ideation, or create a replacement
   project. Multiple or foreign matches, an absent or different lead, a missing chain, or
   conflicting evidence blocks; titles never choose a project.

## Specification hardening and approval

5. Invoke [`woostack-harden`](../../woostack-harden/SKILL.md) against the verified project and its
   current specification record. Persist durable questions and resolutions as append-only
   `decision` or `progress` updates, each related to the current phase head and independently read
   back. Those updates do not advance phase and add no gate.
<!-- <LIFECYCLE-TRANSITION phase="specHardened"> -->
6. When the grill completes, append `specHardened` with a new stable event UUID, revision 1,
   `predecessorId` equal to the current `designApproved` native update, related decision/update IDs,
   and the complete written specification in the readable body. Verify the event, one current
   chain, and unchanged native `backlog` category. If revision is requested before approval,
   harden again and append a correction of this same `specHardened` event UUID at revision + 1,
   superseding the exact current native update.
<!-- </LIFECYCLE-TRANSITION> -->

<HARD-GATE name="spec-approval">
Present the current verified `specHardened` body and project URL. Only explicit **Go** approves it.
**Revise** returns to hardening and append-only correction of the same event. **Abandon** records the
terminal transition below and stops. Silence, ambiguity, an unverified revision, or a conflicting
read-back does not clear this barrier. No planning event or increment issue may exist before Go.
</HARD-GATE>

<!-- <LIFECYCLE-TRANSITION phase="specApproved"> -->
7. On **Go**, append `specApproved` with a new stable event UUID, revision 1, the current
   `specHardened` native update as predecessor, and that update ID in `relatedIds`. Its readable body
   records the exact approved revision and explicit approval evidence. Independently verify the
   update, one current chain, and native `backlog` category before planning.
<!-- </LIFECYCLE-TRANSITION> -->

## Planning, hardening, and ready

<!-- <LIFECYCLE-TRANSITION phase="planning"> -->
8. Invoke [`woostack-plan`](../../woostack-plan/SKILL.md) with the retained context and exact project
   UUID or URL. Planning appends the single `planning` successor to `specApproved`, creates or
   reconciles one stable managed issue per increment and native dependency relations, and returns
   only after an independent complete read proves the current `planning` chain and issue graph.
<!-- </LIFECYCLE-TRANSITION> -->
9. Invoke `woostack-harden` against that issue graph. It may reconcile content and relations under
   stable issue identities and append non-phase decisions, but it owns no phase transition or
   approval gate. Re-read the full project, updates, issues, comments, owners, native relations,
   and GitHub evidence after hardening. Reject missing AC coverage, dependency cycles, duplicate
   ordinals, cross-project relations, unrepresentable Git ancestry, or any unexplained branch/PR.
<!-- <LIFECYCLE-TRANSITION phase="ready"> -->
10. Immediately before ready, resolve the canonical repository base branch and exact commit SHA
    from Git/GitHub authority. Reconcile every dependency-root issue's typed unresolved future-base
    Git parent to that exact frozen branch/SHA, independently read each changed issue and the
    complete graph back, and fail closed before `ready` if any root remains pending, names another
    SHA, or has a missing/partial receipt. Non-root issues retain their one native dependency issue
    as Git parent. Only then append `ready` with a new stable event UUID, revision 1, the current
    `planning` native update as predecessor, and every ordered increment native ID in `relatedIds`.
    Its readable body freezes the same exact base branch/SHA and summarizes the verified issue graph.
    Independently read the event and complete issue graph back, then set and verify the configured
    native `planned` status. No lifecycle, issue, source, branch, or PR mutation may intervene before
    the execution-handoff presentation.
<!-- </LIFECYCLE-TRANSITION> -->

### Explicit replan

**Replan** through `ready → planning` is the only backward phase transition and does not clear the third gate.
Before it, independently read every managed issue, native relation, Linear branch/PR link, and the
canonical GitHub repository. Require explicitly empty implementation branch and PR evidence for
every issue. Append a new `planning` event UUID at revision 1 with the current `ready` update as
predecessor, every issue native ID in `relatedIds`, and readable evidence naming the complete issue
snapshot and empty Linear/GitHub branch/PR result. Verify it, then restore and verify native
`backlog`.

Reconcile and harden through the existing stable issue identities, freeze a fresh base, and append a
new `ready` successor. Do not delete or silently detach an increment. Missing evidence, an
unpaginated result, any branch/PR, or a phase at or after `executionApproved` blocks replan.

## Execution handoff

<HARD-GATE name="execution-handoff">
Present the verified current specification, ordered hardened issue graph, exact frozen base, and
project URL. Only explicit **Go**, **Run overnight**, or **Hand off** selects a terminal path.
**Replan** follows the evidence-backed loop above without clearing this gate. **Abandon** records the
terminal transition below. Silence, ambiguity, stale state, or a mutation response without
independent read-back clears nothing. No implementation Git artifact may exist before a verified Go
or overnight approval.
</HARD-GATE>

11. On **Go** or **Run overnight**, refresh all mutable state and require the same `ready` head,
    issue graph, work owners, frozen base, and empty implementation evidence. Before presenting
    either executable choice, verify that the selected executor's current contract explicitly
    accepts this retained project-event context and uses official host MCP without backend
    resolution, a local adapter, or a managed document lifecycle. If that compatibility is absent,
    leave the project at verified `ready`, append no `executionApproved`, create no Git artifact,
    and report the executor migration as the precise blocker.

<!-- <LIFECYCLE-TRANSITION phase="executionApproved"> -->
    When compatibility is verified, append `executionApproved` with a new stable event UUID,
    revision 1, the current `ready` native update as predecessor, all increment native IDs in
    `relatedIds`, and readable evidence naming the explicit choice and frozen base. Independently
    verify the event, one chain, unchanged native `planned` category, and unchanged issue/Git
    evidence. Only then call the selected executor with the retained context.
<!-- </LIFECYCLE-TRANSITION> -->
12. On **Hand off**, append a non-phase `handoff` update with a new stable event UUID, revision 1,
    `predecessorId` equal to the current `ready` update, and every increment native ID in
    `relatedIds`. Independently verify it, leave phase `ready` and native category `planned`, return
    the project and ordered issue URLs, and create no implementation Git artifact.

## Abandonment and blockers

An explicit **Abandon** from any active phase appends a new `abandoned` phase event with the current
phase update as predecessor, all affected issue IDs in `relatedIds`, and readable authority/reason
evidence. Independently verify the event, then set and verify native `canceled`. Preserve the
project, issues, updates, comments, and relations; never delete or archive history. `done` and
`abandoned` have no successor.

A newly discovered blocker appends `blockerOpened` with a stable event UUID, the unchanged current
phase head as predecessor, exact affected native IDs in `relatedIds`, and readable owner, impact,
and resolution conditions. Verify it, then set native `paused` and read that back. A resolution
appends `blockerResolved` with a new UUID, the unchanged phase head as predecessor, and the exact
open blocker update ID plus resolution evidence in `relatedIds`. Restore the category implied by
the unchanged phase only after an independent complete read proves no unresolved blocker remains;
otherwise keep `paused`. A correction uses the non-phase project event rule above, not the phase
event rule. A missing, multiply resolved, or ambiguously related blocker remains open and stops
affected work.
