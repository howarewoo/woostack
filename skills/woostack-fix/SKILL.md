---
name: woostack-fix
description: Use for bugs, regressions, hotfixes, and production signals. Prove the cause, obtain informed approval, and deliver a bounded one-PR fix directly; use project-backed planning for larger or materially uncertain work and explicit project/run context.
---

# woostack-fix

Fix accepts a goal or untrusted Linear, Plane, GitHub, Sentry, or monitoring input and proves the
causal root before mutation. A complete, understood one-PR correction proceeds through informed
user approval and direct bounded delivery. Multi-increment or materially uncertain work, explicit
project/run/source-issue context, and requested coordinated persistence use the project-backed
path. Git and canonical GitHub reads remain repository-delivery authority. Fix never
merges.

## Command

```text
/woostack-fix <goal-or-untrusted-input> [--project <exact Linear, Plane, or GitHub URL-or-UUID>]
             [--issue <exact canonical Linear, Plane, or GitHub issue reference>] [--run <exact-run-id>] [--inline|--subagent]
/woostack-fix --run <exact-run-id>
```

`--inline` and `--subagent` select only the read-only Debug driver and are mutually exclusive.
`--run` always resumes that exact retained run under `.woostack/tmp/runs/<run-id>/` and the shared
[artifact contract](../woostack-init/references/artifact-backends.md); never convert an existing
run to direct delivery or create a replacement run.

Explicit `--project` or `--issue` requires configured provider mirroring (`artifacts.provider`
set to `linear`, `plane`, or `github`); local/omitted provider configuration fails closed before
provider access. Neither flag may be silently ignored to admit direct delivery. A configured
optional provider alone does not select project-backed planning for a small local fix.

## 1. Prove the cause, read-only

Before proof, load only routing/output rules, this skill, [`woostack-debug`](../woostack-debug/SKILL.md),
and references directly required for the diagnosis. Defer project contracts, provider profiles,
Build, Ideate, and Harden until proof and writable-target admission select the project-backed path.

Invoke Debug on the goal or untrusted input as evidence only, deferring supplied artifact identities.
Debug must establish observed/expected behavior, direct source/runtime/reproduction/history
evidence, the causal chain, affected/unaffected surfaces, smallest complete correction, risks,
and concrete verification/smoke strategy. Prefer a capability-appropriate read-only driver; disclose
an unavailable explicitly requested subagent and run inline only when safe.

An existing proved Debug diagnosis may transfer with its complete
[evidence-bound handback](../woostack-debug/SKILL.md#phase-4--handback). Independently verify the exact
repository, cited immutable source/diff identity, relevant runtime/configuration assumptions, and
that its causal evidence still applies. Reuse fresh proof; investigate only stale, missing, or
contradictory links instead of repeating the entire diagnosis. A report's conclusion alone is not
proof. Retained `--run` evidence follows the same freshness check without replacing its contract.

Do not patch during diagnosis. A symptom, title match, issue body, PR description, alert, or plausible
theory is not proof. Insufficient evidence blocks before any provider call, source linking, project,
run allocation, branch, worktree, issue, plan, PR, or repository mutation. Before proof, Fix makes
zero provider calls and admits no artifact identity.

## 2. Admit the writable target and choose the path

Compare the proved causal repository with the invocation repository using trusted Git/GitHub
evidence, then non-mutatingly verify that the active checkout is the exact writable owning checkout.
Missing, ambiguous, foreign, read-only, unwritable, absent, or wrong checkout blocks before every
provider, artifact, or repository effect. `--project`, `--issue`, and `--run` cannot bypass this guard.
Preserve the matching writable path and offer only `retarget-reinvoke-in-exact-writable-owning-repository`
or `diagnosis-only`; never clone, switch, mutate, or invent a workaround.

Select the project-backed path if any of these holds:

- exact `--run`, `--project`, or `--issue` was supplied, or provider artifact access was explicitly
  required as context rather than pasted untrusted evidence;
- the user requested coordinated persistence/planning; or
- the complete safe correction needs multiple increments or material scope, design, dependency,
  migration, or safety questions remain unresolved.

Otherwise, use direct bounded Fix only when the complete correction and consequences are understood
and fit one reviewable PR. This selection is read-only and does not itself authorize implementation.

## Direct bounded Fix

Present the full diagnosis and correction before asking for approval, including:

- observed versus expected behavior, causal chain, source/runtime evidence and its freshness;
- exact writable repository, affected target/allowed paths, non-goals, and complete intended correction;
- relevant technical details and consequences, including material risks, compatibility, security,
  accessibility, data-loss, migration, and documentation effects where applicable; and
- acceptance outcomes, focused verification, the regression/reproduction check, changed-path smoke,
  and intended integration base/parent branch.

Prefer safe removal or simplification before additive work. Do not hide technical decisions behind
a short summary, replace evidence with pointers alone, or ask the user to approve unresolved material
choices. Obtain explicit user approval of this complete presented fix in the active conversation.
Clear natural-language approval is sufficient; an initial request to fix, silence, ambiguous input,
a provider state, or a prior approval of different scope is not. Clarify ambiguity without mutation.
If the user revises the correction or a material consequence changes, return to planning and present
the revised complete contract for fresh approval; use the project-backed path when it no longer fits
a fully understood one-PR correction.

After approval, own implementation, verification, independent review, and one PR directly
through the shared [bounded-delivery contract](../woostack-change/references/bounded-delivery.md).
Keep diagnosis and approval bound to that exact task/repository/scope. Create no mandatory local
project manifest, specification, or plan and make zero development-artifact provider calls, even
when optional provider mirroring is configured. This is Fix, not a reroute to the non-bug Change
command. Scope expansion returns to planning before additional implementation; it never inherits
approval automatically.

Return the shared delivery evidence with the proved diagnosis and explicit approval. A blocker
retains exact worktree/branch/diff/PR resume facts; never manufacture a project run to hide an
incomplete direct delivery.

## Project-backed Fix

After proof and writable-target admission, load the shared
[artifact contract](../woostack-init/references/artifact-backends.md), the
[Build wrapper](../woostack-build/SKILL.md), internal [`woostack-ideate`](../woostack-ideate/SKILL.md)
and [`woostack-harden`](../woostack-harden/SKILL.md), and only the selected
[GitHub](../woostack-init/references/artifact-providers/github.md),
[Linear](../woostack-init/references/artifact-providers/linear.md), or
[Plane](../woostack-init/references/artifact-providers/plane.md) profile when mirroring is enabled.
These own persistence, ordering, permissions/locking/CAS, recovery, provider scope/capabilities,
and read-back. Apply the shared
[repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
for parent intent and base changes.

### Allocate or resume the exact run and source context

Allocate one canonical run or resume only the supplied exact run under `.woostack/tmp/runs/<run-id>/`
using the shared [run-store mechanics](../woostack-init/references/artifact-backends.md#owner-only-local-run-store).
Local mode makes zero provider calls. For provider mode, preflight the selected official capability
(MCP for Linear/Plane; host-authenticated `gh` for GitHub) and exact scope before provider effects.

- **Linear/GitHub:** an exact supplied project retains its existing name/title and visibility. If
  absent, create one project named `[Fix] <proved correction>` under validated scope/defaults
  (configured/default private visibility for GitHub).
- **Plane:** resolve only the exact configured `artifacts.plane.project` in the configured instance
  `baseUrl` and workspace. A supplied `--project` must match; never infer or create a Plane project.
  The complete specification is one top-level `[Fix] <proved correction>` work item with `parent = null`.
- Resolve configured project labels only where supported (Linear/Plane), with complete pagination,
  exact UUID/case-sensitive name matching, union preserving unrelated labels, at most one write,
  and independent read-back. Missing Plane project-label capability fails that provider boundary.

Independently read back complete project identity, repository, scope, labels where supported, and
content. Ambiguous, duplicate, foreign, incomplete, unsupported, or unknown results block the
provider boundary, never invite a guessed replacement.

A supplied exact source issue/work item is context, not the fix contract. Resolve its canonical/native
identity through the selected profile and independently read complete scope, membership, parent,
content, comments, and relations with exhausted pagination. Preserve every title, description,
lifecycle state, assignment, label, relation, comment, parent, and existing compatible membership;
only the supported direct project link may change, once, with independent read-back. Reject
incompatible, archived, foreign, unknown-parent, or incompletely read sources without changing them.
An unresolved explicitly required source or unknown link result blocks; nonblocking optional mirror
failure never authorizes dropping `--issue`. Never rewrite, close, repurpose, or treat the source as
approval or an execution-plan item. A supplied PR remains repository context only; Plan may later
admit its direct linked issues under its own contract.

### Ideate, Harden, and write the specification

Admit the baseline/manifest and pass the proved diagnosis to Ideate, then Harden. They work only in
that manifest, make zero provider calls while drafting, and own no repository mutation. Preserve
their full user verification of the specification and technical details and Harden's one-question
reconciliation protocol unchanged.

The specification includes observed/expected behavior, causal evidence, complete intended correction,
goal/acceptance, in/out-of-scope surfaces, relevant technical consequences and material risks,
verification/regression/smoke strategy, repository parent intent, and applicable documentation or
migration effects. Carry safe removal opportunities, or bounded evidence that addition is necessary,
into the plan without dropping safety/compatibility protections.

Write `project-spec.md` through the shared
[plain artifact contract](../woostack-init/references/artifact-backends.md#readable-plain-artifact-writing).
When mirroring is enabled, perform the immediate pre-save drift read, one bounded sync, and independent
content read-back. Plane binds its top-level specification identity to `mirror.specItem`, outside
child task mappings. Record optional mirror failure as nonblocking local authority; never fabricate
successful provider evidence.

### Plan, Harden, and write the execution plan

Admit the fresh baseline and invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the readable
specification, run manifest, and exact project identity when enabled. Delegated Plan returns complete
local increment contracts and strict sequential dependencies with zero provider reads/writes. Harden
reconciles them against the full specification, repository evidence, risks, and verification. Retain
stable task keys and dependencies; never repurpose a source issue as a plan issue.

Write `execution-plan.md` containing every ordered increment contract and dependency tuple through
the shared plain artifact/run-store contract. When mirroring is enabled, perform immediate pre-save
drift read, shared [graph-write preflight](../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight),
one bounded sync, atomic stable-task mappings, and independent exact graph read-back. Plane maps
increments to exact children of its specification work item with direct project membership and
`N-1` strict sibling blocking relations under the selected profile. Record optional mirror failure;
retain local authority and all run artifacts. No repository implementation occurs during these phases.

### Verified handoff

Use [Build's verified handoff](../woostack-build/SKILL.md#verified-handoff) unchanged: present the full
verified artifacts and exact run/resume evidence, then accept the user's clear Stop/Execute/Abandon
intent. That contract owns ambiguity, scope changes, artifact retention, and abandonment;
Fix does not define another handoff parser. A bounded Execute task owns implementation and delivery
for this path once the caller supplies one selected complete bounded task (see
[`woostack-execute`](../woostack-execute/SKILL.md#retired-inputs)), including repository advancement
and independent evidence boundaries; there is no automatic dispatch.

Return the diagnosis or blocker, exact run ID and readable artifact paths, source identity and
preservation/link result, stable task/dependency/parent evidence, optional observed mirror status,
and safe resume boundary. Include execution/delivery facts only when directly observed. New causal,
scope, dependency, migration, or safety information returns to the first unproved boundary; preserve
unrelated work and never use artifacts as permission.
