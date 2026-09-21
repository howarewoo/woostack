---
name: woostack-build
description: Prepare a multi-increment feature with plain retained artifacts and a user-controlled handoff to bounded Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the internal decision and planning phases. It always owns
persistent local runs under `.woostack/tmp/runs/<run-id>/`, supports exact `--run`, retains
success/Stop/Abandon artifacts, and stops at a verified handoff where the caller supplies one
selected complete bounded task to Execute. Local run
authority is unconditional; Linear, Plane, or GitHub is an optional mirror flow gated by
`artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`. Git
and canonical GitHub reads remain the authority for repository delivery. Git + `gh` is the default;
optional Graphite selection follows the [source-control contract](../woostack-commit/references/graphite.md).
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
| `"github"` | [GitHub](../woostack-init/references/artifact-providers/github.md) | [GitHub context](references/github-context.md) | [GitHub procedure](references/github-procedure.md) |
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
allocate or resume canonical local run `.woostack/tmp/runs/<run-id>/` (and admit baseline when mirroring) →
draft Ideate/Harden locally with zero provider calls →
writes plain Markdown `project-spec.md` (and perform optional bounded mirror sync/read-back) →
draft delegated Plan/Harden locally with zero provider calls →
writes plain Markdown `execution-plan.md` (and perform optional bounded mirror sync/read-back) →
retain run artifacts → present verified handoff and ask `Stop here`/`Execute`/`Abandon`
```

> **Retired automatic execution.** There is no automatic Execute dispatch or run-controller
> handoff. Build stops at retained artifacts; the caller selects one complete bounded task and
> supplies it to [`woostack-execute`](../woostack-execute/SKILL.md#retired-inputs) with its decisions,
> parent evidence, and exact retained state. Final orchestration automation is later work.
Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) for exhaustive user-verified decisions and
[`woostack-harden`](../woostack-harden/SKILL.md) to reconcile bounded repository evidence. Both work
only in the shared run-scoped manifest after baseline admission, make no provider call while gated,
and own no approval gate.

After `project-spec.md` is written (and optional mirror synchronization completes or records nonblocking
failure), invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the readable specification, baseline
identity, and verified run manifest. When delegated by Build, Plan returns only a candidate graph
under its [selected-provider invariants](../woostack-plan/SKILL.md#graph-invariants) and performs no
provider read or mutation. Harden admits the candidate
into the manifest and reconciles it with repository evidence. Build writes `execution-plan.md` directly
under the run directory and performs optional bounded mirror synchronization when `artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`.

Apply the [least-code doctrine](../woostack-bootstrap/references/patterns.md#7-least-code--comments)
at both boundaries. Ideate owns user verification of the complete specification, including technical
details and removal opportunities; Harden owns repository reconciliation. Neither repository evidence
nor a proposed default replaces the user's decisions.

## Readable plain artifacts

Build writes plain Markdown `project-spec.md` and `execution-plan.md` directly under `.woostack/tmp/runs/<run-id>/` under the
shared [plain artifact contract](../woostack-init/references/artifact-backends.md#readable-plain-artifact-writing):

1. **Project specification.** Write `project-spec.md` containing the complete user-verified specification.
   When `artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`, one bounded mirror synchronization writes the specification and
   records mirror status in the manifest; mirror failures are nonblocking.
2. **Execution plan.** Write `execution-plan.md` containing every ordered increment contract and
   dependency tuple. When `artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`, one bounded mirror synchronization binds stable
   local task keys to canonical provider references and records mirror status in the manifest; mirror failures
   are nonblocking.

Cross-session continuation is permitted for independently verified run state. All run artifacts in
`.woostack/tmp/runs/<run-id>/` are retained upon successful completion and upon explicit abandonment.
Any failure at shared local boundaries blocks Build; the local draft never replaces the last verified
boundary.

## Verified handoff

This handoff is shared by Build and project-backed Fix. After both complete, user-verified
`project-spec.md` and `execution-plan.md` are written (and optional mirroring completes or records
nonblocking failure), the owning workflow displays the exact run ID, readable artifact paths,
stable task mappings, dependency tuples, planning parent branch, planning parent tip, and optional mirror
mappings and status (when mirroring was enabled). It then stops at retained artifacts:

> **Retired:** `/woostack-execute --run <exact-run-id>` is retired (see
> [`woostack-execute`](../woostack-execute/SKILL.md#retired-inputs)). To continue, the caller selects
> one complete bounded task and supplies it as `/woostack-execute <bounded input>` with its
> decisions, parent evidence, and exact retained state.

A GitHub DAG outside the sequential contract is retained and mirrored without being linearized. The
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
