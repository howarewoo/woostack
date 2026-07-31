---
name: woostack-build
description: Use when building a multi-increment feature — approve the design, harden and approve its specification, produce a dependency-aware plan, then hand execution through exactly three gates. Linear persistence is optional.
---

# woostack-build

## Overview

Drive one multi-increment feature from idea to a reviewed Graphite stack or a truthful handoff or
blocker. The workflow owns three decisions: approve the design, approve the written specification,
and approve execution of the plan. Linear projects and issues may persist those artifacts, but are
never required and never authorize repository work.

Git and GitHub remain authoritative for source, branches, commits, PRs, reviews, and merge
evidence. Build never creates a docs-only base PR and never merges.

This skill is for multi-increment feature work. A bounded one-PR fix or change remains outside this
workflow.

## Authority and artifact context

The user's request and the three explicit gates authorize this workflow. The approved design,
specification, and implementation plan may remain in the active conversation or use a
repository-authorized artifact.

Linear persistence is opt-in. When the caller supplies an exact project URL/UUID or explicitly asks
for artifact synchronization, load:

1. the [optional artifact contract](../woostack-init/references/artifact-backends.md);
2. the [repository/project context procedure](references/linear-context.md); and
3. the [Linear synchronization procedure](references/linear-procedure.md).

Those procedures govern artifact identity, append-only updates, and read-back only. They do not
grant approval, assignment, implementation permission, or acceptance. Without explicit artifact
selection, do not contact Linear and skip every provider-specific step below.

## Fixed chain

```text
ideate → approve design → harden specification → approve specification →
plan → harden increment graph → approve execution → execute → review → hand back
```

The workflow may return from a ready plan to planning only before implementation begins. An active
run may be explicitly abandoned. When optional Linear persistence is selected, corresponding
append-only phase and blocker events may mirror these transitions.

## Exactly three hard gates

Build owns exactly these three barriers, in this order:

1. **design-approval** — explicit approval freezes the complete design.
2. **spec-approval** — the current complete hardened specification is presented for explicit
   approval. Planning cannot begin before this decision.
3. **execution-handoff** — the hardened dependency-aware plan and frozen repository base evidence
   are presented. No implementation branch, worktree, commit, or PR may exist before an explicit
   execution choice.

Hardening, planning, reconciliation, optional artifact synchronization, blocker handling, and
read-backs are work steps, not extra gates. Silence, implication, or a provider response never
clears a gate.

## Terminal choices at the execution handoff

- **Go** — invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the approved plan and any
  explicitly selected artifact context.
- **Run overnight** — invoke
  [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) with the same approved plan.
- **Hand off** — return the approved specification, ordered plan, repository base, and any exact
  artifact links without creating an implementation Git artifact.

An incompatible executor is a blocker, not a reason to silently change the contract. **Replan**
returns to planning only when Git/GitHub evidence proves no implementation branch or PR exists.
**Abandon** preserves evidence and stops. Optional artifact mode mirrors these outcomes only after
independent read-back.

## Hard constraints

- **One feature contract.** One approved specification maps to one dependency-aware plan whose
  increments are independently shippable and create at most one PR each.
- **Exactly three gates.** Design approval, written-spec approval, and execution handoff are the
  only hard stops. Plan hardening owns no approval gate.
- **Artifacts are optional.** Linear projects/issues may persist specifications and plan
  increments. They never authorize work, assign an engineer, own a branch, or override direct
  repository evidence.
- **Verified artifact mutations only.** In optional Linear mode, allocate stable identities before
  mutation and independently read every write back. Unknown outcomes stop artifact synchronization
  without fabricating a replacement.
- **Git/GitHub truth.** Verify source, ancestry, PR, review, and merge facts directly.
- **Fail closed.** Missing predecessors, illegal transitions, duplicate revisions, supersession
  errors, multiple current heads, ownership drift, relation drift, conflicting evidence, or
  incomplete read-back stops at the boundary and reports the precise blocker.
- **Stop before implementation.** No implementation Git artifact exists before an explicit `Go` or
  `Run overnight`; optional artifact synchronization may follow but never supplies that approval.
- **Never merge.** Build may deliver a reviewed stack, a handoff, abandonment, or a truthful
  blocker; merge remains human-owned.
