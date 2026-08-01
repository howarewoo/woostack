# Linear plan synchronization procedure

This procedure writes an approved fix/build/standalone plan into one exact Linear project. It runs
only after the caller supplies an exact resource or explicitly requests persistence. Repository
policy alone never selects this procedure. It owns no workflow gate, phase, assignment, execution,
acceptance, or repository authority.

Use the [optional artifact contract](../../woostack-init/references/artifact-backends.md) and
[project context procedure](linear-context.md) for every read and write.

## Selection or creation

For an existing artifact, resolve only the exact caller-supplied project URL/stable UUID. For
explicitly requested creation, allocate one stable project mutation UUID before the first write and
retain it through recovery. Never discover or reuse a project by title or recent activity.

Before creation, verify the canonical repository and caller-selected workspace/team, read by the
stable identity, and prove the resource is absent. After creation, independently read the exact
project back and verify its identity, canonical repository association, resolved workspace/team,
and requested initial content. An unknown outcome is recovered by re-reading the same identity;
never retry with a replacement UUID.

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

After `woostack-fix` returns its approved contract, standalone `woostack-plan` finishes its graph,
or `woostack-build` hardens the candidate graph returned by delegated planning, persist exactly
once:

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

Never remove, detach, or reset an increment child that carries verified implementation evidence.
Preserve its stable identity and current hierarchy membership; conflicting replans stop before
provider mutation.

Issue state, assignee, delegate, label, parent, project, and relation fields describe the artifact.
They never select a worker, grant permission, clear the execution handoff, or prove implementation.

## Explicit abandonment

Follow the neutral canonical artifact contract's
[fix/build project-closure procedure](../../woostack-init/references/artifact-backends.md#fixbuild-project-closure).
This build-owned synchronization procedure does not redefine closure steps.

## Delivery notes

Concise synchronization notes may be appended after repository results have been directly verified.
Notes belong on the matching increment child and may reference canonical PR URLs, commit SHAs,
observed verification, or review state. Read those facts from Git/GitHub first. A note does not
establish the fact it records.

## Failures and resume

A missing capability, failed read, unknown mutation, incomplete pagination, conflicting revision,
or foreign resource stops at the last verified artifact boundary. Report exact retained IDs and the
next safe artifact action. Do not create a replacement or replay an already verified write.

Missing capability blocks the selected artifact operation. A failure after persistence was selected
blocks the plan deliverable and execution handoff at the last verified artifact boundary. Repository
policy never selects persistence or authorizes a fallback provider write.
