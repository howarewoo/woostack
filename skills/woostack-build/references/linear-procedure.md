# Linear plan synchronization procedure

This procedure writes an approved fix/build plan into one exact Linear project. It runs when the
caller selects persistence or repository Linear availability is proved. It owns no workflow gate,
phase, assignment, execution, acceptance, or repository authority.

Use the [optional artifact contract](../../woostack-init/references/artifact-backends.md) and
[project context procedure](linear-context.md) for every read and write.

## Selection or creation

For an existing artifact, resolve only the exact caller-supplied project URL/stable UUID. For
automatic or explicitly requested creation, allocate one stable project mutation UUID before the
first write and retain it through recovery. Never discover or reuse a project by title or recent
activity.

Before creation, read by that stable identity and prove the resource is absent. After creation,
independently read the exact project back and verify its identity, canonical repository link, and
requested initial content. An unknown outcome is recovered by re-reading the same identity; never
retry with a replacement UUID.

## Specification synchronization

After the workflow's specification or fix-contract approval gate has cleared, persist the exact
approved context to the project. Record:

- stable artifact and content revision identities;
- canonical repository and frozen source revision when relevant;
- the exact approved design/specification body;
- the approval observation as provenance, not as provider-owned authority; and
- supersession of an earlier artifact revision when one exists.

Corrections preserve the content identity, increment its revision, and identify the exact superseded
native record. Never overwrite history ambiguously or create a second current specification.
Independently read every append or update back.

## Plan hierarchy synchronization

After `woostack-plan` or `woostack-fix` returns a complete dependency-aware graph, persist:

1. one parent plan issue in the project containing the complete ordered plan, base assumptions,
   cross-increment verification strategy, and open blockers;
2. one native child issue under that parent for every increment, containing the plan's stable task
   ID, exact scope/non-goals, acceptance criteria, implementation sequence, verification/smoke
   plan, ordinal, intended PR, and declared predecessors; and
3. native dependency relations directly between increment child issues.

The parent plan issue is a non-executable artifact container, not a dependency node or implementation
task. Do not create checklist issues, layer/file wrappers, or sub-issues beneath increments merely
to duplicate prose.

Reconcile idempotently:

1. allocate and retain stable mutation IDs before writes;
2. read the complete existing project, parent issue, child issue, and relation sets;
3. match only by stable identity, never title;
4. create or update only the selected missing/stale records;
5. verify every issue, parent-child link, and dependency relation through independent complete
   read-back; and
6. preserve the same identities when an outcome is unknown.

Issue state, assignee, delegate, label, parent, project, and relation fields describe the artifact.
They never select a worker, grant permission, clear the execution handoff, or prove implementation.


## Explicit abandonment

The shared [fix/build project-closure invariant](../../woostack-init/references/artifact-backends.md#fixbuild-project-closure)
applies at every phase. On explicit abandonment:

1. stop repository work and all artifact work except closure recovery;
2. use the retained exact project identity to determine whether a persisted project already exists;
   if none exists, report that there is nothing to close and do not create one;
3. validate `.woostack/config.json`, resolve `projectStatuses.canceled` to exactly one native
   canceled-category project status, and prove exact project update, stable mutation identity, and
   independent read-back capability;
4. immediately before mutation, re-read the exact project's native identity, current status, and
   revision, then allocate or retain one stable closure mutation identity;
5. update only that project's native status to the resolved canceled status; and
6. independently re-read the exact project and verify its identity, canceled status name/ID and
   category, revision, and stable mutation identity.

Do not archive or delete the project and do not bulk-change issue states.
Handoff, replan, and blocker handling are not abandonment; they leave project status unchanged. A
failed read, failed update, incomplete read-back, or unknown outcome becomes a truthful artifact
blocker. Retain the same project and mutation identities, re-read before retrying from the first
unproved closure boundary, and never resume repository work.

## Delivery notes

Concise synchronization notes may be appended after repository results have been directly verified.
Notes belong on the matching increment child and may reference canonical PR URLs, commit SHAs,
observed verification, or review state. Read those facts from Git/GitHub first. A note does not
establish the fact it records.

## Failures and resume

A missing capability, failed read, unknown mutation, incomplete pagination, conflicting revision,
or foreign resource stops at the last verified artifact boundary. Report exact retained IDs and the
next safe artifact action. Do not create a replacement or replay an already verified write.

An unavailable automatic preflight keeps the repository workflow artifact-free. A failure after
repository Linear availability was proved blocks the plan deliverable and execution handoff at the
last verified artifact boundary. Explicitly requested persistence fails at the same boundary.
