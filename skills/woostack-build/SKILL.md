---
name: woostack-build
description: Prepare a multi-increment feature with plain retained artifacts and a user-controlled handoff to normal Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the internal decision and planning phases. It always owns
persistent local runs under `.woostack/tmp/runs/<run-id>/`, supports exact `--run`, retains
success/Stop/Abandon artifacts, and hands off with `/woostack-execute --run <exact-run-id>`. Local run
authority is unconditional; Linear or Plane is an optional mirror flow gated by `artifacts.provider: "linear"`
or `artifacts.provider: "plane"`. Git, Graphite, and canonical GitHub reads remain the authority for repository delivery. Merge authority
is human-only: never auto-merge, never enqueue, never merge.
## Commands

```text
/woostack-build <goal> [--project <exact Linear or Plane URL-or-UUID>] [--run <exact-run-id>]
/woostack-build --run <exact-run-id>
/woostack-build --project <exact Linear or Plane URL-or-UUID>
```

When `--run <exact-run-id>` is supplied, Build resumes only that exact run directory under
`.woostack/tmp/runs/<run-id>/` under the shared artifact contract. When omitted, Build creates a new
persistent local run under `.woostack/tmp/runs/<run-id>/`.

Local run creation is unconditional. Default local mode makes zero provider calls. When `artifacts.provider`
is "local" or omitted in effective repository configuration, an explicit `--project` flag fails closed before
any provider access with an error stating that `--project` requires configured provider mirroring (`artifacts.provider: "linear"` or `artifacts.provider: "plane"`).
When `artifacts.provider: "linear"`, `--project` is optional. Build resolves the exact caller-supplied Linear project
or creates exactly one canonical project prefixed with `[Build] ` and otherwise derived from the accepted
goal. Supplied projects retain their existing names. Each independently shippable increment is one direct
issue in that project. Do not create a parent plan issue. Build verifies the canonical repository association,
then uses validated repository/workspace/team defaults before starting the conversation.
When `artifacts.provider: "plane"`, Build resolves the exact existing `artifacts.plane.project` under
the configured `baseUrl` and workspace and verifies its canonical repository association. An optional
`--project` must identify that same project; a mismatch fails closed. Build never infers or creates a
Plane project. It creates one top-level specification work item prefixed with `[Build] ` with
`parent = null` containing the complete specification, and creates each independently shippable
increment as an exact child work item of that specification (`parent = <spec-item-UUID>`) with direct
project membership and `N-1` sibling blocking relations.
Before acting, load the shared
[artifact contract](../woostack-init/references/artifact-backends.md), then load only the selected
provider row:

| `artifacts.provider` | Provider profile | Build context | Synchronization |
| --- | --- | --- | --- |
| `"linear"` | [Linear](../woostack-init/references/artifact-providers/linear.md) | [Linear context](references/linear-context.md) | [Linear procedure](references/linear-procedure.md) |
| `"plane"` | [Plane](../woostack-init/references/artifact-providers/plane.md) | [Plane context](references/plane-context.md) | [Plane procedure](references/plane-procedure.md) |

Local mode loads no provider profile or provider procedure. The shared contract is the single
authority for run allocation and resume, the permission-restricted manifest, readable plain Markdown
artifacts, optional mirror synchronization, graph ordering, drift/failure recovery, retention, and
unchanged Execute safety reads. The selected profile and Build references supply only provider-specific
scope, identities, capabilities, mutations, and read-back.
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
Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) for exhaustive user-verified decisions and
[`woostack-harden`](../woostack-harden/SKILL.md) to reconcile bounded repository evidence. Both work
only in the shared run-scoped manifest after baseline admission, make no provider call while gated,
and own no approval gate.

After `project-spec.md` is written (and optional mirror synchronization completes or records nonblocking
failure), invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the readable specification, baseline
identity, and verified run manifest. When delegated by Build, Plan returns only a candidate strict
sequential direct-issue chain and performs no provider read or mutation. Harden admits the candidate
into the manifest and reconciles it with repository evidence. Build writes `execution-plan.md` directly
under the run directory and performs optional bounded mirror synchronization when `artifacts.provider: "linear"` or `artifacts.provider: "plane"`.

At both specification and planning boundaries, Build requires a safe removal/simplification analysis
before additive work. Ideate records viable removal opportunities before additive proposals, and Harden
challenges an additive draft when bounded evidence shows the same contract can be met by deletion or
simplification. The complete specification and delegated execution plan carry the selected removal or
the executor-ready evidence for why addition is necessary. Preserve behavior and safety parity: this
analysis never drops validation, error handling, security, accessibility, compatibility, data-loss
protection, or deliberate safety redundancy. The canonical
[least-code doctrine](../woostack-bootstrap/references/patterns.md#10-least-code--comments) is the
source of truth; Execute's existing smallest-complete-change and behavior-preserving simplification
contract remains unchanged.

## Readable plain artifacts

Build writes plain Markdown `project-spec.md` and `execution-plan.md` directly under `.woostack/tmp/runs/<run-id>/` under the
shared [plain artifact contract](../woostack-init/references/artifact-backends.md#readable-plain-artifact-writing):

1. **Project specification.** Write `project-spec.md` containing the complete user-verified specification.
   When `artifacts.provider: "linear"` or `artifacts.provider: "plane"`, one bounded mirror synchronization writes the specification and
   records mirror status in the manifest; mirror failures are nonblocking.
2. **Execution plan.** Write `execution-plan.md` containing every ordered increment contract and
   dependency tuple. When `artifacts.provider: "linear"` or `artifacts.provider: "plane"`, one bounded mirror synchronization binds stable
   local task keys to canonical provider references and records mirror status in the manifest; mirror failures
   are nonblocking.

Cross-session continuation is permitted for independently verified run state. All run artifacts in
`.woostack/tmp/runs/<run-id>/` are retained upon successful completion and upon explicit abandonment.
Any failure at shared local boundaries blocks Build; the local draft never replaces the last verified
boundary.

## Verified handoff

After `project-spec.md` and `execution-plan.md` are written (and optional mirror synchronization
completes or records nonblocking failure), Build displays the exact run ID, readable artifact paths,
stable task mappings, dependency tuples, planning parent branch, planning parent tip, optional mirror
mappings and status (when mirroring was enabled), and the exact handoff command:

```text
/woostack-execute --run <exact-run-id>
```

Build then asks a body-free handoff question whose explicit options are exactly `Stop here`,
`Execute`, and `Abandon`. `Stop here` returns the command without repository, run, or project-state
mutation. `Execute` invokes normal [`woostack-execute`](../woostack-execute/SKILL.md) once in the
same session with `--run <exact-run-id>`. `Abandon` records `status: "abandoned"` in the manifest,
retains run artifacts, does not close or mutate a mirrored provider project, and does not dispatch
Execute. Unknown or custom input fails closed and asks again; it never dispatches or mutates.

Execute applies the shared repository ancestry and base-change contract to those inputs and owns
implementation, focused verification, progress evidence, and repository delivery under its own
contract. Build does not select another execution mode, create a competing authority, or merge.

Any required local manifest boundary failure blocks at the last verified boundary. Artifact records
never replace Git/Graphite/GitHub evidence or grant repository permission.
