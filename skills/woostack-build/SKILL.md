---
name: woostack-build
description: Prepare a multi-increment feature through two active-conversation approval receipts and a user-controlled handoff to normal Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the internal decision and planning phases. It always owns
persistent local runs under `.woostack/tmp/runs/<run-id>/`, supports exact `--run`, issues
raw-file-hash local receipts before optional mirrors, retains success/Stop/Abandon artifacts, and
hands off with `/woostack-execute --run <exact-run-id>`. Local run authority is unconditional; Linear
is an optional mirror flow gated by `linear.saveArtifacts: true`. Git, Graphite, and canonical
GitHub reads remain the authority for repository delivery. Build never merges.

## Commands

```text
/woostack-build <goal> [--project <exact Linear URL-or-UUID>] [--run <exact-run-id>]
/woostack-build --run <exact-run-id>
/woostack-build --project <exact Linear URL-or-UUID>
```

When `--run <exact-run-id>` is supplied, Build resumes only that exact run directory under
`.woostack/tmp/runs/<run-id>/` under the shared artifact contract. When omitted, Build creates a new
persistent local run under `.woostack/tmp/runs/<run-id>/`.

Local run creation and local receipt verification are unconditional. Default local mode makes zero
provider calls. When `linear.saveArtifacts` is false or absent in `.woostack/config.json`, an explicit
`--project` flag fails closed before any provider access with an error stating that `--project`
requires `linear.saveArtifacts: true`. When `linear.saveArtifacts: true`, Build resolves the exact
supplied project or creates exactly one project whose name starts with `[Build] ` and otherwise
derives from the accepted goal. Supplied projects retain their existing names. Build verifies the
canonical repository association, then uses validated repository/workspace/team defaults before
starting the conversation.

Before acting, load and apply the shared
[Linear artifact contract](../woostack-init/references/artifact-backends.md), the
[repository/project context procedure](references/linear-context.md), and the
[`Linear synchronization procedure`](references/linear-procedure.md). The shared artifact contract is
the single authority for run allocation and resume, the permission-restricted run manifest,
deterministic owner-only gate-file rendering, complete streamed artifact presentation and minimal
body-free Ask, same-process byte-complete revision diffs, local approval records, optional mirror
synchronization, canonical issue-reference/nullable-parent preflight, native project/team identity,
drift/failure recovery, artifact retention, and unchanged Execute safety reads.
[repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-is-separate-from-approval-identity)
governs parent-branch re-admission; this wrapper does not restate those rules.

## Fixed chain

```text
allocate or resume canonical local run `.woostack/tmp/runs/<run-id>/` (and admit gate 1 baseline when mirroring) →
draft Ideate/Harden locally with zero provider calls →
render and present complete `project-spec.md` followed by a body-free `Accept`/`Abandon` Ask →
record local `projectSpecApprovalRecord` (and perform optional bounded mirror sync/read-back) →
draft delegated Plan/Harden locally with zero provider calls →
render and present complete `execution-plan.md` followed by a body-free `Accept`/`Abandon` Ask →
record local `executionPlanApprovalRecord` (and perform optional bounded mirror sync/read-back) →
retain run artifacts → present verified handoff and ask `Stop here`/`Execute`/`Abandon`
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
   complete new artifact. Accepting produces the local `projectSpecApprovalRecord`. When
   `linear.saveArtifacts: true`, one bounded mirror synchronization writes the specification and
   records mirror status in the manifest; mirror failures are nonblocking.
2. **Execution plan.** Deterministically render `execution-plan.md` containing every ordered issue
   contract and dependency tuple, then stream its complete verified bytes and full identity (or a
   verified same-process revision diff) immediately before a body-free `Accept`/`Abandon` Ask.
   Accepting produces the local `executionPlanApprovalRecord`. When `linear.saveArtifacts: true`,
   one bounded mirror synchronization binds stable local task keys to canonical issue references
   and records mirror status in the manifest; mirror failures are nonblocking.

Cross-session continuation is permitted only for independently verified unchanged local receipts.
Receipts survive across process restarts and distinct processes when resuming the same `<run-id>`
for independently verified identical gate-file bytes and SHA-256.

The linked shared contract owns the presentation, file replacement and no-follow checks, drift
admission, local receipts, optional mirror synchronization, recovery, and artifact retention. All
run artifacts in `.woostack/tmp/runs/<run-id>/` are retained upon successful completion and upon
explicit abandonment. Any failure at shared local boundaries blocks Build; an unreceipted approval
cannot be replayed, and the local draft never replaces the last approved boundary.


Build compares the shared
[`providerPresentationCanonicalization`](../woostack-init/references/artifact-backends.md#canonical-content-fingerprints-and-project-approval-records)
fingerprints while retaining native provider bytes as exact read-back evidence.

The shared [approval-record contract](../woostack-init/references/artifact-backends.md#shared-approval-records)
defines record fields and content invalidation.

## Verified handoff

After the second approval produces `executionPlanApprovalRecord` (and optional mirror synchronization
completes or records nonblocking failure), Build displays the exact run ID, both local approval
receipts and canonical fingerprints, stable task mappings, dependency tuples, approved parent
branch, last admitted tip, optional mirror mappings and status (when mirroring was enabled), and the
exact handoff command:

```text
/woostack-execute --run <exact-run-id>
```

Build then asks a body-free handoff question whose explicit options are exactly `Stop here`,
`Execute`, and `Abandon`. `Stop here` returns the command without repository, run, or project-state
mutation. `Execute` invokes normal [`woostack-execute`](../woostack-execute/SKILL.md) once in the
same session with `--run <exact-run-id>`, the verified run identity, `projectSpecApprovalRecord`,
`executionPlanApprovalRecord`, canonical fingerprints, direct-issue set, native dependencies,
approved parent-branch intent, and last admitted tip. `Abandon` records `status: "abandoned"` in the
manifest, retains run artifacts, does not close or mutate a mirrored Linear project, and does not
dispatch Execute. Unknown or custom input fails closed and asks again; it never dispatches or
mutates.

Execute applies the shared repository advancement contract to those inputs and owns implementation,
focused verification, progress evidence, and repository delivery under its own contract. Build does
not select another execution mode, create a competing authority, or merge.

Any required local manifest boundary failure blocks at the last verified boundary. Artifact records
never replace Git/Graphite/GitHub evidence or grant repository permission.
