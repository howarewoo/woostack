---
name: woostack-build
description: Use when building a multi-increment feature — approve the design and specification, produce a dependency-aware plan, persist it to Linear when repository capability is available, then hand execution through exactly three gates.
---

# woostack-build

## Overview

Drive one multi-increment feature from idea to a reviewed Graphite stack or a truthful handoff or
blocker. The workflow owns three decisions: approve the design, approve the written specification,
and approve execution of the plan. When repository Linear availability is proved, the plan is
persisted as one project with a parent plan issue and one child issue per increment. Linear never
authorizes repository work.

Git and GitHub remain authoritative for source, branches, commits, PRs, reviews, and merge
evidence. Build never creates a docs-only base PR and never merges.

This skill is for multi-increment feature work. A bounded one-PR fix or change remains outside this
workflow.

## Authority and artifact context

The user's request and the three explicit gates authorize this workflow. The approved design,
specification, and implementation plan remain valid workflow contracts whether or not repository
Linear capability is available.

After specification approval and before plan synchronization, load:

1. the [Linear artifact contract](../woostack-init/references/artifact-backends.md);
2. the [repository/project context procedure](references/linear-context.md); and
3. the [Linear synchronization procedure](references/linear-procedure.md).

An exact caller-supplied project or explicit persistence request selects artifact mode directly.
Otherwise inspect validated non-secret repository policy; only when a `linear` object is configured,
preflight the authenticated official Linear MCP, including canceled project-status resolution,
project update, stable mutation identity, and independent read-back capability. A complete preflight makes plan persistence
required. Missing configuration or unavailable/incomplete capability keeps the build artifact-free
and makes no provider write. Never inspect or expose an API key.

These procedures govern artifact identity, project/issue hierarchy, dependency relations, and
read-back only. They do not grant approval, assignment, implementation permission, or acceptance.

## Fixed chain

```text
ideate → approve design → harden specification → approve specification →
plan → harden increment graph → persist available Linear plan → approve execution →
execute → review → hand back
```

The workflow may return from a ready plan to planning only before implementation begins. Explicit
abandonment may occur at any phase and follows the shared
[fix/build project-closure invariant](../woostack-init/references/artifact-backends.md#fixbuild-project-closure).

## Exactly three hard gates

Build owns exactly these three barriers, in this order:

1. **design-approval** — explicit approval freezes the complete design.
2. **spec-approval** — the current complete hardened specification is presented for explicit
   approval. Planning cannot begin before this decision.
3. **execution-handoff** — the hardened dependency-aware plan, frozen repository base evidence, and
   required Linear project/issue read-backs are presented. No implementation branch, worktree,
   commit, or PR may exist before an explicit execution choice.

Hardening, planning, required or explicit artifact synchronization, blocker handling, and
read-backs are work steps, not extra gates. Silence, implication, or a provider response never
clears a gate.

## Terminal choices at the execution handoff

- **Go** — invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the approved plan and its
  exact persisted artifact context when present.
- **Run overnight** — invoke
  [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) with the same approved plan.
- **Hand off** — return the approved specification, ordered plan, repository base, and required
  exact artifact links without creating an implementation Git artifact.

An incompatible executor is a blocker, not a reason to silently change the contract. **Replan**
returns to planning only when Git/GitHub evidence proves no implementation branch or PR exists.
**Abandon** is explicit abandonment: stop repository work and, when an exact persisted project
exists, close it through the
[Linear synchronization procedure](references/linear-procedure.md#explicit-abandonment) before
returning. If no project exists, report that there is nothing to close and never create one merely
to cancel it. **Hand off**, **Replan**, and blocker handling are not abandonment and do not close
the project.

## Hard constraints

- **One feature contract.** One approved specification maps to one dependency-aware plan whose
  increments are independently shippable and create at most one PR each.
- **Exactly three gates.** Design approval, written-spec approval, and execution handoff are the
  only hard stops. Plan hardening owns no approval gate.
- **Conditional plan persistence.** Linear is not required to run build. When repository Linear
  availability is proved, however, the complete plan must be persisted as one project, one parent
  plan issue, and one native child issue per increment before execution handoff.
- **Verified artifact mutations only.** Allocate stable identities before mutation and
  independently read every project, issue, parent-child link, and dependency relation back. Unknown
  outcomes stop artifact synchronization without fabricating a replacement.
- **Git/GitHub truth.** Verify source, ancestry, PR, review, and merge facts directly.
- **Fail closed.** Missing predecessors, illegal transitions, duplicate revisions, supersession
  errors, multiple current heads, ownership drift, relation drift, conflicting evidence, or
  incomplete read-back stops at the boundary and reports the precise blocker.
- **Stop before implementation.** No implementation Git artifact exists before an explicit `Go` or
  `Run overnight`; required artifact synchronization records the plan but never supplies approval.
- **Close persisted projects on abandonment.** At execution handoff or any earlier/later phase,
  explicit abandonment must set an existing exact fix/build project's native status to the
  validated `projectStatuses.canceled` mapping and prove it by independent read-back. A failed or
  unknown closure is a truthful artifact blocker at the retained stable retry boundary and never
  resumes repository work.
- **Never merge.** Build may deliver a reviewed stack, a handoff, abandonment, or a truthful
  blocker; merge remains human-owned.
