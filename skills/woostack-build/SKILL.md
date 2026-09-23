---
name: woostack-build
description: Prepare a multi-increment feature with plain retained artifacts and a user-controlled handoff to bounded Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the public Ideate and Harden phases plus planning. It owns
persistent local runs under `.woostack/tmp/runs/<run-id>/`, supports exact `--run`, retains
success/Stop/Abandon artifacts, and stops at a verified handoff where the caller supplies one
selected complete bounded task to Execute. Local run
authority is unconditional; Linear, Plane, or GitHub is an optional mirror flow gated by
`artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`. Git
and canonical GitHub reads remain the authority for repository delivery. Use native Git with an
authorized GitHub capability (prefer native GitHub tools when suitable; host-authenticated `gh` is
supported); discover the actual operation capabilities and read shapes. Optional Graphite selection
follows the [source-control contract](../woostack-commit/references/graphite.md).
Build adapts its retained content and baseline/evidence identity into the public phase input packet;
the run manifest is Build's persistence boundary, not an Ideate or Harden admission requirement.
Merge authority is human-only: never auto-merge, never enqueue, never merge.
## Commands

```text
/woostack-build <goal> [--project <exact Linear, Plane, or GitHub URL-or-UUID>] [--run <exact-run-id>]
/woostack-build --run <exact-run-id>
/woostack-build --project <exact Linear, Plane, or GitHub URL-or-UUID>
```

When `--run <exact-run-id>` is supplied, Build resumes only that exact run directory under
`.woostack/tmp/runs/<run-id>/` under the shared artifact contract. When omitted, Build creates a new
persistent local run under `.woostack/tmp/runs/<run-id>/`.

Default local mode makes zero provider calls. An explicit `--project` requires configured provider
mirroring; resolve or create its exact project only through the selected profile and Build context.
Before acting, load the shared
[artifact contract](../woostack-init/references/artifact-backends.md), then load only the selected
provider row:

| `artifacts.provider` | Provider profile | Build context | Synchronization |
| --- | --- | --- | --- |
| `"github"` | [GitHub](../woostack-init/references/artifact-providers/github.md) | [GitHub context](../woostack-plan/references/github-context.md) | [Plan publication](../woostack-plan/references/github-procedure.md) |
| `"linear"` | [Linear](../woostack-init/references/artifact-providers/linear.md) | [Linear context](references/linear-context.md) | [Linear procedure](references/linear-procedure.md) |
| `"plane"` | [Plane](../woostack-init/references/artifact-providers/plane.md) | [Plane context](references/plane-context.md) | [Plane procedure](references/plane-procedure.md) |

Local mode loads no provider profile or provider procedure. The shared contract is the single
authority for run allocation and resume, the permission-restricted manifest, readable plain Markdown
artifacts, optional mirror synchronization, graph ordering, drift/failure recovery, and retention.
The selected profile and Build references supply only provider-specific
scope, identities, capabilities, mutations, and read-back.
Use the canonical [run-store helper](../woostack-init/references/artifact-backends.md#owner-only-local-run-store)
for allocation, every manifest read/CAS checkpoint, and final plain-artifact writes. Build supplies
the complete admitted content; the helper owns filesystem safety, not user approval or workflow state.

The shared [repository ancestry contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
governs parent-branch intent and base movement detection; this wrapper does not restate those rules.

## Fixed chain

```text
allocate or resume canonical local run `.woostack/tmp/runs/<run-id>` (and admit baseline when a
retained provider path still requires it) →
adapt the admitted goal/specification and identity into a plain Ideate packet →
receive the complete Ideate handback and adapt it into a plain Harden packet →
receive the complete Harden handback →
write plain Markdown `project-spec.md` (and retain any still-supported project artifact) →
for an explicit GitHub parent or Project scope, invoke Plan with the complete approved specification,
evidence, and scope; Plan reconciles through public Harden once and directly publishes/read-backs the
issue graph. Record Plan's complete publication handback as `execution-plan.md` without a second
GitHub writer. Otherwise draft a local candidate against the canonical Plan issue contract and
reconcile it through public Harden; local mode makes no provider call. A remaining Linear/Plane
path may synchronize that candidate through its selected procedure without invoking Plan →
```

> **Retired automatic execution.** There is no automatic Execute dispatch or run-controller
> handoff. Build stops at retained artifacts; the caller selects one complete bounded task and
> supplies it to [`woostack-execute`](../woostack-execute/SKILL.md#retired-inputs) with its decisions,
> parent evidence, and exact retained state. Final orchestration automation is later work.
Invoke public [`woostack-ideate`](../woostack-ideate/SKILL.md) for exhaustive user-verified decisions
and public [`woostack-harden`](../woostack-harden/SKILL.md) to reconcile bounded repository
evidence. Build supplies each phase with the complete plain packet from
[`planning-inputs.md`](../using-woostack/references/planning-inputs.md), including the exact baseline
and evidence identity. While Build retains its manifest and may mirror final plain artifacts, these
phase calls make no provider call and do not admit or mutate the manifest as a phase prerequisite.

For an explicit GitHub parent or Project scope after `project-spec.md` is written, invoke
[`woostack-plan`](../woostack-plan/SKILL.md) with the complete specification, baseline/evidence
identity, and selector. Plan uses the public Harden content interface once, then owns all GitHub issue,
native parent, and dependency publication and independent read-back. Build no longer receives a
draft-only candidate and never performs a second issue or relationship synchronization. It records
Plan's complete handback in `execution-plan.md` for retained-run compatibility. Remaining non-GitHub
provider paths are transitional Build/Fix procedures until issue #741 and do not create a competing
GitHub graph.

Without a GitHub publication scope, Build retains its transitional local drafting responsibility:
draft complete tasks against [Plan's issue contract](../woostack-plan/SKILL.md#direct-issue-contract),
then pass the complete candidate and repository evidence to public Harden as plain content. Harden
returns its reconciled handback without manifest mutation; Build admits and persists that handback
as the local plan. This is not draft-only Plan, a second GitHub publisher, or permission to fabricate
remote identities.

Apply the [least-code doctrine](../woostack-bootstrap/references/patterns.md#7-least-code--comments)
at both boundaries. Ideate owns user verification of the complete specification, including technical
details and removal opportunities; Harden owns repository reconciliation. Neither repository evidence
nor a proposed default replaces the user's decisions.


## Readable plain artifacts

Build writes plain Markdown `project-spec.md` and `execution-plan.md` directly under `.woostack/tmp/runs/<run-id>/` under the
shared [plain artifact contract](../woostack-init/references/artifact-backends.md#readable-plain-artifact-writing):

1. **Project specification.** Write `project-spec.md` containing the complete user-verified
   specification. Retained provider-specific project records may follow their existing bounded path
   during the transition; they are not Plan's publication authority.
2. **Execution plan.** In a GitHub scope, write Plan's complete returned child contracts,
   identities, graph, and publication evidence without another writer. Otherwise write the complete
   locally drafted, Harden-reconciled candidate; only an explicitly selected transitional provider
   may synchronize it.

Cross-session continuation is permitted for independently verified run state. All run artifacts in
`.woostack/tmp/runs/<run-id>/` are retained upon successful completion and upon explicit abandonment.
Any failure at shared local boundaries blocks Build; the local draft never replaces the last verified
boundary.

## Verified handoff

This handoff is shared by Build and project-backed Fix. After complete, user-verified
`project-spec.md` and `execution-plan.md` are retained, display the exact run ID, readable artifact
paths, task/dependency/parent evidence, and any observed publication identities. Local mode has no
remote identities; a selected GitHub scope additionally requires Plan's complete publication
handback. Then stop at retained artifacts:

> **Retired:** `/woostack-execute --run <exact-run-id>` is retired (see
> [`woostack-execute`](../woostack-execute/SKILL.md#retired-inputs)). To continue, the caller selects
> one complete bounded task and supplies it as `/woostack-execute <bounded input>` with its
> decisions, parent evidence, and exact retained state.

A branching GitHub DAG is retained without being linearized or written by a second publisher. The
[GitHub parent-selection contract](../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph)
records the intended Orchestrate boundary and any unresolved join decision.

Ask whether to `Stop here`, `Execute`, or `Abandon`. Accept an unambiguous natural-language choice;
the user need not repeat a literal option label.

- **Stop here:** return without repository, run, or project-state mutation.
- **Execute:** the caller supplies one selected complete bounded task to
  [`woostack-execute`](../woostack-execute/SKILL.md) with the exact retained state above; Build
  performs no automatic dispatch.
- **Abandon:** record `status: "abandoned"`, retain the run, leave any mirrored project unchanged,
  and do not dispatch Execute.

Ambiguous intent asks for clarification without mutation. A response changing scope, technical
decisions, or acceptance returns to the owning Ideate/Harden/Plan boundary for explicit verification;
approval of the prior artifacts does not authorize the changed contract. In-scope verification
reminders may accompany a clear Execute choice.

A bounded Execute task applies the shared repository ancestry and base-change contract to its supplied
parent evidence and owns implementation, focused verification, and repository delivery under its own
contract. Build does not select another execution mode, create a competing authority, or merge.

Any required local manifest boundary failure blocks at the last verified boundary. Artifact records
never replace required Git/GitHub evidence (plus Graphite in that mode) or grant repository permission.
