# Optional Linear synchronization procedure

This procedure mirrors an already-approved design, specification, or implementation plan into one
exact Linear project. It runs only when the caller selected artifact persistence. It owns no
workflow gate, phase, assignment, execution, acceptance, or repository authority.

Use the [optional artifact contract](../../woostack-init/references/artifact-backends.md) and
[project context procedure](linear-context.md) for every read and write.

## Selection or creation

For an existing artifact, resolve only the exact caller-supplied project URL/stable UUID. For a new
artifact explicitly requested by the caller, allocate one stable project mutation UUID before the
first write and retain it through recovery. Never create a project merely because build, plan, or
execute can use one.

Before creation, read by that stable identity and prove the resource is absent. After creation,
independently read the exact project back and verify its identity, canonical repository link, and
requested initial content. An unknown outcome is recovered by re-reading the same identity; never
retry with a replacement UUID.

## Specification synchronization

After the workflow's design or specification approval gate has cleared, the caller may request that
the exact approved body be persisted to the project. Record:

- stable artifact and content revision identities;
- canonical repository and frozen source revision when relevant;
- the exact approved design/specification body;
- the approval observation as provenance, not as provider-owned authority; and
- supersession of an earlier artifact revision when one exists.

Corrections preserve the content identity, increment its revision, and identify the exact superseded
native record. Never overwrite history ambiguously or create a second current specification.
Independently read every append or update back.

## Plan synchronization

After `woostack-plan` returns a complete dependency-aware graph, synchronize only when requested.
The project may store the complete plan. Optional issues may mirror increments, but each issue must
retain the plan's stable task ID, exact scope, acceptance criteria, verification plan, ordinal, and
declared predecessors.

Reconcile idempotently:

1. allocate and retain stable mutation IDs before writes;
2. read the complete existing task/relation set;
3. match only by stable identity, never title;
4. create or update only the requested missing/stale records;
5. verify every issue and relation through independent complete read-back; and
6. preserve the same identities when an outcome is unknown.

Issue state, assignee, delegate, label, and relation fields describe the artifact. They never select
a worker, grant permission, clear the execution handoff, or prove implementation.

## Delivery notes

A caller may request concise synchronization notes after repository results have been directly
verified. Notes may reference canonical PR URLs, commit SHAs, observed verification, or review
state. Read those facts from Git/GitHub first. A note does not establish the fact it records.

## Failures and resume

A missing capability, failed read, unknown mutation, incomplete pagination, conflicting revision,
or foreign resource stops at the last verified artifact boundary. Report exact retained IDs and the
next safe artifact action. Do not create a replacement or replay an already verified write.

Artifact failure blocks the repository workflow only when successful persistence was explicitly
part of the deliverable. Otherwise, continue from the approved contract and direct repository
evidence while reporting artifact synchronization as omitted or incomplete.
