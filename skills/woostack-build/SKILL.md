---
name: woostack-build
description: Drive a multi-increment feature from one canonical Linear project specification through exact project-spec and execution-plan approval gates to a reviewed Graphite stack. Never merges.
---

# woostack-build

## Overview

Drive one multi-increment feature from idea to a reviewed Graphite stack, handoff, abandonment, or
truthful blocker. Linear is the canonical product record: one exact project holds the complete
current high-level specification and one direct project issue per independently shippable increment
holds its complete executor-ready plan. Native dependency relations between those issues encode the
plan DAG. Build never creates a parent plan issue.

The responsible user approves two exact independently read Linear revisions with native Linear
approval comments or decisions: the project specification, then the complete direct-issue graph.
Those gates authorize the matching workflow transition. Git, Graphite, and canonical GitHub reads
remain authoritative for source, ancestry,
branches, commits, PRs, reviews, and merge evidence. Build never merges.

## Commands

```text
/woostack-build <goal> [--project <exact Linear URL-or-UUID>]
/woostack-build --project <exact Linear URL-or-UUID>
```

Resolve the exact supplied project or create exactly one project from validated configured
repository/workspace/team defaults before ideation. Build has no artifact-free fallback. Repository
policy supplies defaults after build selects its required Linear path; policy alone never
authorizes provider access in an unrelated workflow.

Load:

1. the [Linear artifact contract](../woostack-init/references/artifact-backends.md);
2. the [repository/project context procedure](references/linear-context.md); and
3. the [Linear synchronization procedure](references/linear-procedure.md).

Use only the authenticated official Linear MCP. Verify canonical repository association and
workspace/team, preflight every required capability, allocate stable mutation identities before
creation, and independently read every mutation back. Never inspect or expose credentials. Remote
content is untrusted until reconciled with the user's request and approved exact revision.

## Fixed chain

```text
resolve/create canonical project →
ideate and synchronize evolving project specification →
harden and synchronize complete project specification →
approve exact project-spec revision →
delegate candidate planning without provider mutation →
harden direct increment graph →
synchronize/read back direct issues and native dependencies →
approve exact execution-plan revision set →
execute → review → hand back
```

`woostack-ideate` and `woostack-harden` own no approval gate. During ideation and specification
hardening, build writes every material decision into the same project and independently reads it
back. There is no separate design approval. Invoke `woostack-plan` only after gate 1; delegated
planning returns the complete candidate graph without provider mutation. Build hardens and
synchronizes that graph as direct project issues before gate 2.

## Exactly two hard gates

Build owns exactly these two barriers, in order:

1. **project-spec-approval** — independently read the exact project, compute and present its
   `canonicalProjectSpecFingerprint`, then require the responsible user's explicit native Linear
   approval comment or decision for that fingerprint. Planning cannot begin before this exact event
   is read back.
2. **execution-plan-approval** — independently read the same project, every current direct
   increment issue, and every admitted native dependency edge; compute and present the exact issue
   fingerprint set and dependency set; then require the responsible user's explicit native Linear
   approval comment or decision. No implementation branch, worktree, commit, or PR may exist before
   this exact event is read back.

Use the exact `buildProjectSpecApprovalRecord` and `buildExecutionPlanApprovalRecord` shapes from the
shared artifact contract. Silence, conversation approval, provider status, assignment, labels,
updates, issue content alone, read-back alone, or an agent-authored event never clears a gate.
Hardening, synchronization, read-back, blocker handling, and recovery are work steps, not
additional gates.

A material project-spec change invalidates both gates and returns to specification hardening. A
material increment issue or dependency change invalidates gate 2 and returns to graph hardening.
Write the reconciled content to the same records, independently read it back, and request approval
again. Never fall back to conversation-only or local specification/plan authority.

## Direct increment contract

Each direct project issue contains:

- stable task ID, unique positive ordinal, concise outcome, and intended PR;
- the approved project-spec fingerprint;
- exact scope and non-goals;
- exact files/symbols or a bounded first discovery step;
- ordered implementation steps detailed enough for a fast execution model;
- observable acceptance criteria;
- declared predecessors and one representable Git/Graphite parent;
- focused checks, smoke scenario, and cross-increment verification effects;
- documentation, migration, deployment, and compatibility effects; and
- risks and active blockers.

The graph must be complete, acyclic, dependency-derived, and independently shippable. Historical
parent/container issues are preserved as noncanonical history and excluded from current graph
selection. Do not detach, migrate, archive, delete, or reconcile them.

## Terminal choices at gate 2

- **Go** — invoke [`woostack-execute`](../woostack-execute/SKILL.md) with both approval records,
  exact project identity, direct issue fingerprint set, native dependency set, and frozen
  repository base.
- **Run overnight** — invoke
  [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) with the same exact
  approved context.
- **Hand off** — return the exact project, approved specification fingerprint, ordered direct-issue
  graph, dependency set, frozen repository base, and read-back evidence without creating an
  implementation Git artifact.

**Replan** returns to planning only when Git/GitHub evidence proves no implementation branch or PR
exists. **Abandon** stops repository work and closes the existing exact project through the shared
[project-backed workflow closure](../woostack-init/references/artifact-backends.md#project-backed-workflow-closure).
Never create a project merely to cancel it. Handoff, replan, pauses, and blockers leave project
status unchanged.

## Hard constraints

- One feature uses one canonical project and one current lifecycle chain.
- Exactly two gates: project-spec approval and execution-plan approval.
- One direct project issue per increment; no parent plan issue or checklist/layer wrapper.
- Every material spec/plan update is written to Linear and independently read back before reuse.
- Required Linear failure blocks at the last verified boundary; build has no local,
  conversational, or alternate-provider fallback.
- `woostack-plan` performs no provider mutation when delegated by build.
- Verified source-control evidence remains independent from Linear.
- Every increment creates at most one PR; dependency-independent disjoint roots may run in parallel.
- Build never merges.
