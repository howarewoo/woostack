---
name: woostack-build
description: Prepare a multi-increment feature through two active-conversation approval receipts and a user-controlled handoff to normal Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the internal decision and planning phases. It owns one
canonical project, exactly two content approvals, and the user-controlled handoff into normal
[`woostack-execute`](../woostack-execute/SKILL.md). Linear is required product authority for the
build; Git, Graphite, and canonical GitHub reads remain the authority for repository delivery.
Build never merges.

## Commands

```text
/woostack-build <goal> [--project <exact Linear URL-or-UUID>]
/woostack-build --project <exact Linear URL-or-UUID>
```

Build always resolves the exact supplied project or creates exactly one project whose name starts
with `[Build] ` and otherwise derives from the accepted goal. Supplied projects retain their
existing names. Build verifies the canonical repository association, then uses validated
repository/workspace/team defaults before starting the conversation and has no artifact-free
fallback. Before acting, load and apply the shared
[Linear artifact contract](../woostack-init/references/artifact-backends.md), the
[repository/project context procedure](references/linear-context.md), and the
[`Linear synchronization procedure`](references/linear-procedure.md). The shared artifact contract is
the single authority for baseline admission, the permission-restricted run manifest, deterministic
owner-only gate-file rendering, complete streamed artifact presentation and minimal body-free Ask,
same-process byte-complete revision diffs, approval-before-save ordering, canonical
issue-reference/nullable-parent preflight, native project/team identity, drift/failure
recovery, cleanup, and unchanged Execute safety reads.
[repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-is-separate-from-approval-identity)
governs parent-branch re-admission; this wrapper does not restate those rules.

## Fixed chain

```text
resolve/create canonical project and admit gate 1 baseline →
draft Ideate/Harden locally with zero provider calls →
render and present complete `project-spec.md` followed by a body-free `Accept`/`Abandon` Ask →
pre-save drift read → one bounded sync → exact content read-back → receipt/read-back →
draft delegated Plan/Harden locally with zero provider calls →
render and present complete `execution-plan.md` followed by a body-free `Accept`/`Abandon` Ask →
pre-save drift read → one bounded sync → exact graph read-back → receipt/read-back →
gate-file and manifest cleanup → present verified handoff and ask `Stop here`/`Execute`/`Abandon`
```

Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) for exhaustive user-verified decisions and
[`woostack-harden`](../woostack-harden/SKILL.md) to reconcile bounded repository evidence. Both work
only in the shared run-scoped manifest after baseline admission, make no provider call while gated,
and own no approval gate.

After the first receipt reads back exactly, invoke
[`woostack-plan`](../woostack-plan/SKILL.md) with the exact approved project fingerprint and project
identity. When delegated by Build, Plan returns only a candidate strict sequential direct-issue
chain and performs no provider read or mutation. Harden admits the candidate into the manifest,
which deterministically renders `execution-plan.md`. The shared contract streams its complete
verified bytes (or a verified same-process byte-complete diff with old/new identities) immediately
before the body-free `Accept`/`Abandon` Ask. Only after the responsible user accepts that exact
preceding identity does Build perform the shared single bounded post-approval synchronization.
At both approval boundaries, Build requires a safe removal/simplification analysis before additive
work. Ideate records viable removal opportunities before additive proposals, and Harden challenges
an additive draft when bounded evidence shows the same contract can be met by deletion or
simplification. The complete approved specification and delegated execution plan carry the selected
removal or the executor-ready evidence for why addition is necessary. Preserve behavior and safety
parity: this analysis never drops validation, error handling, security, accessibility,
compatibility, data-loss protection, or deliberate safety redundancy. The canonical
[least-code doctrine](../woostack-bootstrap/references/patterns.md#10-least-code--comments) is the
source of truth; Execute's existing smallest-complete-change and behavior-preserving
simplification contract remains unchanged.

## Exactly two approval stops

Build owns exactly these two stops, in this order, and no other approval or routing stop:

Both stops obey the shared
[gated manifest and gate-file approval contract](../woostack-init/references/artifact-backends.md#run-scoped-gated-draft-manifest).
Build owns only these gate-specific displays and successful outcomes:

1. **Project specification.** Deterministically render `project-spec.md` from the manifest and
   stream its complete verified Markdown bytes and full identity immediately before a body-free
   `Accept`/`Abandon` Ask. Same-process revisions stream one verified byte-complete unified diff
   with old/new full-file identities; unavailable or unverifiable prior bytes fall back to the
   complete new artifact. A successful shared synchronization produces an independently verified
   `projectSpecApprovalRecord` whose referenced project matches exactly.
2. **Execution plan.** Deterministically render `execution-plan.md` containing every ordered issue
   contract and dependency tuple, then stream its complete verified bytes and full identity (or a
   verified same-process revision diff) immediately before a body-free `Accept`/`Abandon` Ask. A
   successful shared synchronization binds stable local task keys to canonical issue references and
   produces an independently verified `executionPlanApprovalRecord` whose referenced project graph
   matches exactly.

The linked shared contract owns the presentation, file replacement and no-follow checks, drift
admission, bounded-save and read-back ordering, receipts, recovery, and cleanup. Any failure at
those shared boundaries blocks Build; an unreceipted approval cannot be replayed, and the local
draft never replaces the last Linear-approved boundary.


Build compares the shared
[`providerPresentationCanonicalization`](../woostack-init/references/artifact-backends.md#canonical-content-fingerprints-and-project-approval-records)
fingerprints while retaining native provider bytes as exact read-back evidence.

The shared [approval-record contract](../woostack-init/references/artifact-backends.md#shared-approval-records)
defines record fields and content invalidation.

## Verified handoff

After the second approval has completed the ordered exact read-backs and the run manifest is
cleaned up, Build displays the exact verified project URL or UUID, both approval receipts and
canonical fingerprints, stable task-to-canonical-issue mappings, dependency tuples, approved parent
branch, last admitted tip, and the exact project-only command:

```text
/woostack-execute --project <exact Linear URL-or-UUID>
```

Build then asks a body-free handoff question whose explicit options are exactly `Stop here`,
`Execute`, and `Abandon`. `Stop here` returns the command without repository or project-state
mutation. `Execute` invokes normal [`woostack-execute`](../woostack-execute/SKILL.md) once in the
same session with the verified project identity, `projectSpecApprovalRecord`,
`executionPlanApprovalRecord`, canonical fingerprints, direct-issue set, native dependencies,
approved parent-branch intent, and last admitted tip. `Abandon` follows canonical project closure
after cleanup and does not dispatch Execute. Unknown or custom input fails closed and asks again;
it never dispatches or mutates.

Execute applies the shared repository advancement contract to those inputs and owns implementation,
focused verification, Linear progress evidence, and repository delivery under its own contract.
Build does not select another execution mode, create a local authority, or merge.

Any required provider or manifest boundary failure blocks at the last verified boundary with no
local, conversational, cached, or alternate-provider substitution. Artifact records never replace
Git/Graphite/GitHub evidence or grant repository permission.
