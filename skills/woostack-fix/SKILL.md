---
name: woostack-fix
description: Use for bugs, regressions, hotfixes, and production signals that require root-cause proof before a project-backed implementation and user-controlled Execute handoff.
---

# woostack-fix

Fix is a bounded bug-fix workflow that owns one canonical local run under `.woostack/tmp/runs/<run-id>/`.
It accepts a goal or untrusted Linear, GitHub, Sentry, or monitoring input, proves the causal root,
manages plain specification and direct-issue planning, retains artifacts, and hands off to Execute.
Local run authority is unconditional; Linear is an optional mirror flow gated by `artifacts.provider: "linear"`.
Git, Graphite, and canonical GitHub reads remain the authority for repository delivery. Fix never merges.

```text
Debug → admit writable target → allocate or resume canonical local run `.woostack/tmp/runs/<run-id>/` →
local Ideate/Harden → write `project-spec.md` (and optional bounded sync/read-back) →
local Plan/Harden → write `execution-plan.md` (and optional bounded sync/read-back) →
retain run artifacts → verified `Stop here`/`Execute`/`Abandon` handoff
```

Fix owns one canonical local run. Git, Graphite, and canonical GitHub reads remain the authority
for repository delivery. Fix never creates a competing issue plan, performs implementation, or owns
delivery review.

The shared artifact contract is the sole authority for plain Markdown artifact files, optional mirror
synchronization, read-back, artifact retention, and the unchanged Execute safety contract.

## Command

```text
/woostack-fix <goal-or-untrusted-input> [--project <exact Linear URL-or-UUID>]
             [--issue <exact canonical Linear issue reference>] [--run <exact-run-id>] [--inline|--subagent]
/woostack-fix --run <exact-run-id>
```

When `--run <exact-run-id>` is supplied, Fix resumes only that exact run directory under
`.woostack/tmp/runs/<run-id>/` under the shared artifact contract. When omitted, post-diagnosis Fix
creates a new persistent local run under `.woostack/tmp/runs/<run-id>/`.

Local run creation is unconditional. Default local mode makes zero provider calls. When `artifacts.provider`
is "local" or omitted in effective repository configuration, an explicit `--project` or Linear `--issue`
flag fails closed before any provider access with an error stating that provider arguments require
configured provider mirroring (`artifacts.provider: "linear"`).

When `artifacts.provider: "plane"`, Fix fails closed before any provider access or post-diagnosis run
with an error stating that Plane mirroring is unsupported for Fix in this increment (supported for Build
and Plan only). Any supplied `--project` or `--issue` under `artifacts.provider: "plane"` fails closed
immediately.

When `artifacts.provider: "linear"`, `--project` is optional: when supplied it is one exact canonical
project URL or stable UUID and retains its existing name. When omitted, Fix creates exactly one
project after root-cause proof whose name starts with `[Fix] ` and otherwise derives from the proved
correction, using validated repository, workspace, and team defaults. `--issue` is optional source
context, not the fix contract. It may identify one exact Linear issue or a source issue associated
with the supplied input; it is never repurposed as the canonical project, rewritten as a plan, closed,
or treated as approval. A source issue is left unchanged except for the supported link to the
canonical project. A supplied PR is read as repository context only; multiple direct PR-linked
issues may be admitted later by Plan. `--inline` and `--subagent` select only the read-only Debug
driver and are mutually exclusive.

## Context-loading boundary

Before root-cause proof, load only the routing and output rules, this skill, [`woostack-debug`](../woostack-debug/SKILL.md), and the references that Debug directly requires. Do not load the Linear artifact contract, [`woostack-build`](../woostack-build/SKILL.md), [`woostack-ideate`](../woostack-ideate/SKILL.md), or [`woostack-harden`](../woostack-harden/SKILL.md) before proof.

## Fixed sequence

```text
Debug → admit writable target → allocate or resume canonical local run → local Ideate/Harden → writes plain Markdown project-spec.md → local Plan/Harden → writes plain Markdown execution-plan.md → retain run artifacts → present verified handoff and ask Stop here/Execute/Abandon
```

### 1. Debug, read-only
Invoke [`woostack-debug`](../woostack-debug/SKILL.md) against the goal or untrusted input. The
Fix-origin dispatch passes the prompt/input as evidence only and defers any supplied issue or
project identity until Debug proves the root cause. Debug must establish observed and expected
behavior, direct source/runtime/reproduction/history evidence, the causal root, affected and
unaffected surfaces, the smallest complete correction, risks, and a concrete verification/smoke
strategy.

Do not patch during Debug. A symptom, title match, issue body, PR description, Sentry event, log,
monitoring alert, or plausible theory is not proof. If reproduction or evidence is insufficient,
return a blocker and stop: do not create or update a project, link a source issue, create a branch,
worktree, issue, plan, or PR, mutate the repository, or invoke a provider. Before root-cause proof,
Fix makes no provider call and carries no artifact identity. Use a subagent when available by
default; if an explicitly requested subagent is unavailable, disclose the degradation and run
inline only when safe.

### 1.5. Target-repository admission

After Debug proves the root cause, compare the proved causal target repository with the invocation repository using trusted Git/GitHub evidence, then non-mutatingly verify that the active checkout is the exact writable owning checkout. Missing, ambiguous, foreign, read-only, unwritable, absent, or wrong checkout blocks before every provider, artifact, or repository effect. A supplied `--project` or `--issue` cannot bypass this guard. Preserve the matching writable path and offer only `retarget-reinvoke-in-exact-writable-owning-repository` or `diagnosis-only`; never clone, switch, mutate, or invent a workaround.
Immediately after Debug returns root-cause proof and exact writable target-repository admission
succeeds, load the [Linear artifact contract](../woostack-init/references/artifact-backends.md), the
[Build project wrapper](../woostack-build/SKILL.md), and the internal
[`woostack-ideate`](../woostack-ideate/SKILL.md) and
[`woostack-harden`](../woostack-harden/SKILL.md) contracts. This downstream loading occurs before
canonical run allocation/resolution and before any provider effect. The shared artifact contract is
the single authority for run allocation and resume, the permission-restricted run manifest,
readable plain Markdown artifacts, optional mirror synchronization, canonical issue-reference/nullable-parent
preflight, stable-key/canonical-reference mapping, drift/recovery, artifact retention, and unchanged
Execute reads.
The shared [repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
separately governs parent-branch intent and base-change detection; Fix does not restate or weaken it.
### 2. Allocate or resume canonical run, then Ideate and Harden

After Debug returns root-cause proof, allocate or resume the canonical run store under
`.woostack/tmp/runs/<run-id>/`. When `artifacts.provider: "linear"`, preflight official Linear MCP
capabilities (including workspace project label capabilities when labels are configured). When
`artifacts.linear.projectLabels` is configured, completely paginate all workspace project labels through official Linear
MCP, flatten every page, require null terminal cursors, resolve each configured label string by exact native ID or exact
case-sensitive name (rejecting missing, ambiguous, duplicate, or incomplete matches before mutation), and union configured labels with
existing project labels (preserving unrelated labels). Resolve the exact supplied project or create
exactly one canonical project whose name starts with `[Fix] ` from validated repository/workspace/team
defaults, applying the union of labels in at most one write alongside admission/creation, and
independently read back the complete label set and project. Verify the canonical repository association.
If an exact canonical issue reference was supplied, independently verify it through the official MCP,
including selectable identity, workspace/team/project scope, complete pagination, exact endpoint round trip,
and nullable-parent state, then add only the supported project link; preserve its title, description,
status, assignment, labels, relations, comments, and lifecycle. Reject an ambiguous, foreign, archived,
incompatible, unknown-parent, or incompletely read source without changing it.

Admit the baseline and manifest, then invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) with the
proved diagnosis. Ideate and [`woostack-harden`](../woostack-harden/SKILL.md) work only in that manifest,
perform zero provider reads and writes while drafting, and own no approval gate or repository mutation.

The project specification must include the observed and expected behavior, root-cause chain and
evidence, goal and acceptance criteria, in/out-of-scope surfaces, ordered implementation intent,
risks and blockers, validation/security/data-loss/accessibility/compatibility considerations,
Red → Green → Refactor and changed-path smoke strategy, repository parent-branch intent, and
documentation or migration effects. Keep it self-contained and executor-ready; ask only decisions
that materially change scope or safety.

At both specification and planning steps, Fix requires a safe removal/simplification analysis before
additive work. Ideate records viable removal opportunities before additive proposals; Harden challenges
an additive draft when bounded evidence shows the same contract can be met by deletion or simplification.
Carry the selected removal, or executor-ready bounded evidence for why addition is necessary, from the
project specification into the delegated execution plan. Preserve behavior and safety parity: never drop
validation, error handling, security, accessibility, compatibility, data-loss protection, or deliberate
safety redundancy.

### 3. Project-spec writing

Fix writes plain Markdown `project-spec.md` and `execution-plan.md` directly under `.woostack/tmp/runs/<run-id>/`.
Obey the shared [plain artifact contract](../woostack-init/references/artifact-backends.md#readable-plain-artifact-writing).
When `artifacts.provider: "linear"`, Fix performs the immediate pre-save drift read, runs one bounded
synchronization, and independently reads back the exact content before recording mirror status in the manifest.
Mirror failure is recorded in the manifest and is nonblocking.
No draft provider cycle occurs while drafting. Abandon records `status: "abandoned"` in the manifest,
retains run artifacts, and does not close a mirrored Linear project. No repository mutation occurs
before Execute.

### 4. Plan and Harden

After `project-spec.md` is written (and optional mirror synchronization completes or records nonblocking
failure), admit the fresh baseline and invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the
readable specification, run manifest, and exact canonical project identity when mirroring is enabled.
Delegated Plan returns a complete local candidate direct-issue set and strict native-dependency intent
without any provider read or write.

Invoke Harden again to reconcile that manifest-backed plan with the project specification, repository
evidence, dependencies, risks, and verification. Keep the final complete issue contracts, stable task
keys, and dependencies in the manifest. Never repurpose a supplied source issue as a plan issue.
No provider or repository mutation occurs during planning or hardening.

### 5. Execution-plan writing

Fix writes plain Markdown `execution-plan.md` directly under `.woostack/tmp/runs/<run-id>/`, containing every ordered
increment contract and dependency tuple. When `artifacts.provider: "linear"`, Fix performs the immediate
pre-save drift read, shared
[graph-write preflight](../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight),
and one bounded synchronization. Atomically bind stable task keys to canonical issue references,
independently read back the exact graph, and update mirror status in the manifest. Mirror failure is
recorded in the manifest and is nonblocking.

After plain `project-spec.md` and `execution-plan.md` are written (and optional mirror synchronization
completes or records nonblocking failure), all run artifacts in `.woostack/tmp/runs/<run-id>/` are
retained upon completion and upon explicit abandonment. Fix then displays the exact run ID, readable
artifact paths, stable task mappings, dependency tuples, planning parent branch, planning parent tip,
optional mirror mappings and status (when mirroring was enabled), and:

```text
/woostack-execute --run <exact-run-id>
```

Ask a body-free handoff question whose explicit options are exactly `Stop here`, `Execute`, and
`Abandon`. `Stop here` returns the command without repository, run, or project-state mutation.
`Execute` invokes normal [`woostack-execute`](../woostack-execute/SKILL.md) once in the same session
with `--run <exact-run-id>`. `Abandon` records `status: "abandoned"` in the manifest, retains run
artifacts, does not close or mutate a mirrored Linear project, and does not dispatch Execute. Unknown
or custom input fails closed and asks again; it never dispatches or mutates.

Execute applies the shared repository ancestry and base-change contract and owns implementation,
focused verification, progress evidence, and repository delivery under its own contract.

Any new root cause, scope, dependency, migration, unsafe edge, or failed required read-back returns
to the first unproved boundary. Preserve unrelated work and do not use source artifacts as permission.

## Return

Return the proved root cause or blocker; exact run ID; readable artifact paths; source-input identity
and the unchanged-except-for-project-link result; stable task, worktree, branch, planning parent
branch/tip, and increment identities; exact changed paths; concrete verification and smoke results;
risks, blockers, and the safe resume boundary. Include canonical project identity and read-back
evidence only when Linear mirroring was enabled and observed. Never claim a diagnosis, approval,
repository mutation, execution, delivery, or provider state not directly observed.
