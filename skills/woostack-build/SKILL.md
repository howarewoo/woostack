---
name: woostack-build
description: Use when building a multi-increment feature through one repository-owned Linear project — approve the design, harden and approve its project-update specification, plan dependency-aware increment issues, then hand execution through exactly three gates.
---

# woostack-build

## Overview

Drive one multi-increment feature from idea to a reviewed Graphite stack or a truthful handoff or
blocker. Official host-exposed Linear MCP is the only development-record authority. One
repository-owned `feature` project holds the goal and coarse native status; append-only typed
project updates hold the specification, decisions, lifecycle, progress, blockers, and handoff; one
managed `increment` issue holds each independently shippable implementation contract.

Git and GitHub remain authoritative for source, branches, commits, PRs, reviews, and merge
evidence. Build never creates a docs-only base PR and never merges.

This skill is for project-backed multi-increment feature work. A bounded one-issue fix or change
has no wrapper project and remains outside this workflow; its unchanged ownership contract lives in
the canonical
[Linear MCP development authority](../woostack-init/references/artifact-backends.md).

## Authority and context

Before any development-record read, load:

1. the [canonical Linear authority](../woostack-init/references/artifact-backends.md);
2. the [repository/project context procedure](references/linear-context.md); and
3. the [Linear project lifecycle procedure](references/linear-procedure.md).

Establish exactly one canonical repository URL, configured workspace/team, complete native status
maps, and official MCP capability set. Discover MCP operations by capability rather than hard-coded
tool names. There is no backend selection, local development-record mode, Linear document
lifecycle, repository credential, custom provider transport, or fallback authority.

A project is identified by its stable client UUID, canonical repository URL, exact `woostack`
label, role `feature`, and verified native ID. Titles are never identity. Resume only from a
complete independent read that yields exactly one ownership-valid project and exactly one current
unsuperseded phase chain. Zero, duplicate, foreign, partial, stale, or conflicting matches fail
closed before mutation.

## Fixed chain

```text
ideate → designApproved → harden specification → specHardened → specApproved →
planning → harden increment graph → ready → executionApproved → execute → inReview → done
```

The only deliberate backward phase transition is evidence-backed `ready → planning`. Any active
phase may explicitly become `abandoned`; `done` and `abandoned` are terminal. Blocker events pause
the native project without changing the fine-grained phase. Corrections append revisions and never
edit or delete history.

## Exactly three hard gates

Build owns exactly these three barriers, in this order:

1. **design-approval** — an explicit approved design authorizes project creation and the first
   verified `designApproved` update. No Linear development resource exists before this gate.
2. **spec-approval** — the current complete `specHardened` update is presented for explicit
   approval. Planning cannot begin until a verified `specApproved` successor records that
   approval.
3. **execution-handoff** — the hardened issue graph, verified `ready` head, and frozen repository
   base evidence are presented. No implementation branch, worktree, commit, or PR may exist before
   an explicit execution choice and verified `executionApproved` successor.

Harden, reconciliation, lifecycle writes, corrections, read-backs, replans, blocker handling, and
native status updates are work steps, not extra gates. Silence, implication, an MCP mutation
response, or a native status name never clears a gate.

## Terminal choices at the execution handoff

- **Go** — after verifying that the current [`woostack-execute`](../woostack-execute/SKILL.md)
  contract accepts retained project-event context, append and independently verify
  `executionApproved`, then invoke it with that context.
- **Run overnight** — after the same compatibility check, append and independently verify the same
  approval, then invoke [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md).
- **Hand off** — append and independently verify a non-phase `handoff` update, leave the phase at
  `ready`, create no implementation Git artifact, and return the project URL and ordered issues.

An incompatible executor is a blocker at `ready`, not a reason to dispatch legacy
backend/document input. In that case append no `executionApproved` and create no Git artifact.

An explicit **Replan** returns `ready → planning` only after independent Linear and GitHub reads
prove that every managed increment has no branch or PR. It does not clear the handoff gate. An
explicit **Abandon** appends `abandoned`, verifies native `canceled`, preserves history, and stops;
it does not clear a gate.

## Hard constraints

- **One feature authority.** `project : project updates : increment issues : implementation PRs =
  1 : N : N : at-most-N` with exactly one current lifecycle chain.
- **Exactly three gates.** Design approval, written-spec approval, and execution handoff are the
  only hard stops. Plan hardening owns no approval gate.
- **Stable append-only events.** Allocate client UUIDs before mutation. Corrections use the same
  event UUID, the next revision, exact predecessor, and exact superseded native ID; duplicate
  revisions or multiple current heads block.
- **Verified mutations only.** Independently read every create, update, transition, assignment,
  relation, comment, and project update back. Unknown outcomes retain their UUIDs and stop; they do
  not trigger replacement resources or same-phase retries.
- **Coarse native status only.** Fine-grained phase comes from the typed chain. Native categories
  are `backlog` through planning, `planned` for ready/approval, `started` for execution/review,
  `paused` only for unresolved blockers, `completed` after verified done, and `canceled` after
  abandonment.
- **No alternate development authority.** Do not create or read local spec, plan, fix, progress,
  or overnight records as lifecycle authority; do not create Linear documents; do not call a
  custom Linear endpoint or GraphQL transport; do not obtain credentials outside official host
  MCP/OAuth.
- **Fail closed.** Missing predecessors, illegal transitions, duplicate revisions, supersession
  errors, multiple current heads, ownership drift, relation drift, conflicting evidence, or
  incomplete read-back stops at the boundary and reports the precise blocker.
- **Stop before implementation.** No implementation Git artifact exists before `Go` or
  `Run overnight` and verified `executionApproved` read-back.
- **Never merge.** Build may deliver a reviewed stack, a handoff, abandonment, or a truthful
  blocker; merge remains human-owned.
