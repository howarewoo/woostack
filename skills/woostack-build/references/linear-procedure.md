# Linear project synchronization procedure

This procedure writes one canonical build or selected standalone-plan record to one exact Linear
project. It owns no workflow gate, phase, assignment, execution, acceptance, or repository
authority. Use the [Linear artifact contract](../../woostack-init/references/artifact-backends.md)
and [project context procedure](linear-context.md) for every read and write.

## Build project lifecycle

Build resolves or creates the exact project before ideation. During ideation and specification
hardening:

1. keep one evolving complete high-level specification in the same project;
2. after every material decision, re-read the exact project, preserve unrelated human-authored
   content, write the smallest complete corrected specification, and independently read it back;
3. retain stable project identity and mutation identity; and
4. never request project-spec approval until a complete hardening pass yields no new question.

After the responsible user approves the exact project fingerprint, do not rewrite the specification
silently. A material correction invalidates both build approval records and returns to project-spec
hardening.

## Increment graph synchronization

Build-delegated `woostack-plan` returns a complete candidate graph without provider mutation. Build
hardens it, then synchronizes:

1. one direct project issue per current increment;
2. complete executor-ready issue descriptions containing the approved project-spec fingerprint;
3. direct project membership and no parent/container relation; and
4. native issue-to-issue dependency relations matching the hardened DAG.

Allocate stable client-generated issue and relation mutation UUIDs before first writes and retain
them through recovery. For each issue:

1. read the exact current target when it exists;
2. preserve unrelated human-authored content;
3. write the smallest complete corrected title/description/project-membership payload;
4. independently read native identity, content, project membership, parent absence, revision, and
   mutation identity back; and
5. compute `canonicalIncrementFingerprint` only from the independently read canonical fields.

Then write missing native dependency relations. Independently read the complete relation set back
and compare normalized predecessor→successor tuples with the hardened DAG. Never simulate
dependencies in prose alone.

For a caller-supplied existing project, reconcile matching current direct issues by stable native
identity and stable task ID. Preserve historical parent plan issues and children as noncanonical
history. Never detach, migrate, archive, delete, reparent, or rewrite them. If current direct-issue
identity is ambiguous, stop rather than guess or create a replacement.

Do not create a parent plan issue, child containment, placeholder issue, duplicate relation, or
replacement resource after an unknown outcome.

## Standalone plan

When standalone `woostack-plan` explicitly selects persistence, it may create or update one project
and the same direct-issue dependency graph. It owns no build approval record and does not imply
execution authorization. Without explicit persistence, standalone planning makes no provider call.

## Approval preparation

Before build gate 1, return the exact project URL/UUID, complete independently read specification,
`canonicalProjectSpecFingerprint`, and provider revision/read time; direct the responsible user to
record a native Linear project approval comment or decision naming that exact fingerprint.

Before build gate 2:

1. re-read and match the gate-1 project fingerprint and approval record;
2. completely paginate all current direct issues and native dependency relations;
3. verify each executor contract, project membership, parent absence, stable identity, and
   fingerprint;
4. verify normalized dependencies exactly match the hardened acyclic graph; and
5. return the exact sorted increment and dependency sets plus read times; direct the responsible
   user to record a native Linear project approval comment or decision naming that exact set.

No successful mutation response, Linear status, conversation response, comment content without a
matching responsible-user event, assignment, update, or read-back alone is approval.

## Delivery notes

After repository execution, write only concise delivery evidence derived from Git/Graphite/GitHub:
canonical PR URLs, commit SHAs, changed paths, observed verification, review result, and blockers.
A note records evidence; it does not establish the fact it records. Read the exact issue/project
back after writing and report artifact and repository outcomes separately.

## Failures and resume

A missing capability, failed read, unknown mutation, incomplete pagination, conflicting revision,
foreign resource, stale approval, or mismatched fingerprint/edge blocks the required build path at
the last verified boundary. Preserve stable identities and exact retry state. Never create a
replacement, replay a verified write, or use local/conversational/alternate-provider content for
execution.

Explicit abandonment follows the shared
[project-backed workflow closure](../../woostack-init/references/artifact-backends.md#project-backed-workflow-closure).
Handoff, replan, pauses, and blockers leave project status unchanged.
