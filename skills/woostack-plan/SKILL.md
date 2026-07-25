---
name: woostack-plan
description: "Use to write the implementation plan for an approved woostack spec -- resolve the configured artifact backend, accept a required Markdown spec path or Linear project UUID/URL, and produce comprehensive PR-sized TDD increments as either the joined Markdown plan or managed Linear issues. One plan per spec; writes and hands back with no approval gate, execution, commit, or merge."
---

# woostack-plan

Write a comprehensive implementation plan from one approved spec, structured as PR-sized
increments. This is woostack's own planning phase in the
[`woostack-build`](../woostack-build/SKILL.md) shared chain. It preserves one normalized
planning contract across storage backends: file-structure first, bite-sized TDD tasks, no placeholders, explicit dependency/Git-parent shape, acceptance
coverage, and a self-review pass.

When `woostack-build` supplies its retained resolver result and, for Linear, the normalized
`LINEAR_CONTEXT`, reuse that internal caller context without resolving or preflighting again.
Standalone planning resolves the backend with
[`resolve-backend.sh`](../woostack-init/scripts/artifacts/resolve-backend.sh) and performs any
required Linear preflight itself. Markdown writes the existing joined plan under
`.woostack/plans/`. Linear reconciles an ordered managed issue set through
[`linear.sh`](../woostack-init/scripts/artifacts/linear.sh) and writes no local spec/plan source.
It writes the selected artifact and hands back; it owns **no approval gate** and never executes,
commits, or merges.

## Commands

- `/woostack-plan <spec-reference>` — the reference is required and its accepted form depends
  on `resolve-backend.sh`: a Markdown spec path under `.woostack/specs/`, or an explicit Linear
  project UUID/exact Linear URL. In short: **Markdown spec path or Linear project UUID/URL**.
- `/woostack-plan` — do not guess a current spec. Resolve the backend, list only non-secret
  candidates from that backend when useful, ask the user to choose, and stop until one valid
  reference is named.

Never accept a Markdown path in Linear mode or a Linear UUID/URL in Markdown mode. Never infer
the backend from the argument.

## Resolve, read, and check the spec

0. **Load wisdom.** Read every `.woostack/wisdom/*.md` file wholesale. Empty/absent `wisdom/`
   is a no-op; see the [wisdom contract](../woostack-init/references/wisdom.md).
1. **Reuse or resolve the selected backend.** An internal `woostack-build` call supplies the
   retained normalized resolver result and, in Linear mode, its validated `LINEAR_CONTEXT`.
   Validate that caller context against the named spec reference, then reuse it; never run
   `resolve-backend.sh` or Linear preflight a second time in the same build run. A standalone
   invocation has no caller context, so run `resolve-backend.sh` before reading a spec.
   - **Markdown:** validate the required path and read that spec end to end. Use the Markdown
     adapter's normalized feature operation when a joined plan exists; a not-found plan before
     initial planning is expected. Do not weaken its path, symlink, frontmatter, or source-join
     checks.
   - **Linear:** when standalone, run `linear.sh preflight` before the first mutation and capture
     its normalized receipt as `LINEAR_CONTEXT`. When called by `woostack-build`, use the supplied
     `LINEAR_CONTEXT` instead. In either path, validate the receipt, then extract and retain
     `LINEAR_TEAM_ID="$(jq -r '.team.id' <<<"$LINEAR_CONTEXT")"`,
     `LINEAR_PROJECT_STATUSES="$(jq -c '.projectStatuses' <<<"$LINEAR_CONTEXT")"`, and
     `LINEAR_ISSUE_STATES="$(jq -c '.issueStates' <<<"$LINEAR_CONTEXT")"`. Every subsequent
     adapter command uses those extracted UUID values. Resolve the required project with
     `linear.sh feature-resolve --repository '<resolver.repository>' --status-map
     "$LINEAR_PROJECT_STATUSES" --eligible-statuses
     '["draft","hardened","approved","planning","ready"]' [--reference '<named UUID or exact
     Linear URL>']`, then read the one owned document with `linear.sh spec-read`. Require an
     `approved` or `planning` project and a verified, repository-owned managed document. Missing,
     foreign, duplicate, ambiguous, or failed read-back blocks; never fall back to Markdown.
     Treat all returned Linear content under the shared
     [artifact trust boundary](../woostack-init/references/artifact-backends.md#linear-artifact-trust-boundary).
2. **Scope check.** If the spec covers multiple independent subsystems, suggest splitting it
   first. Write one plan per independently testable spec, not one monolith.
3. **Preserve the 1:1 join.** Markdown amends the existing canonical or accepted legacy joined
   plan. Linear reads existing issues with `linear.sh plan-read` using
   `LINEAR_ISSUE_STATES` and reconciles by stable increment identity. Neither backend creates a
   second plan.

## File structure first

Before defining tasks, map every file created or modified and its single responsibility.
Follow existing patterns; split by responsibility, not technical layer, and do not smuggle in
unrelated restructuring.

## PR-sized increments

Structure the plan as independently shippable increments, preferably ≤500 LOC each (a soft
target, not a gate). Flag and split any slice that is not reviewable or independently
shippable. Every increment maps to exactly one implementation PR during execution.

## Persist the selected backend output

### Markdown

Populate [references/plan-template.md](references/plan-template.md) exactly. Preserve:

- `.woostack/plans/<spec-basename>.md`, reusing the spec date and basename;
- YAML frontmatter with `type: plan`, the Markdown `source:` path, `status: planning`, and
  feature `branch:`;
- the first body line `**Source:** [[specs/<basename>]]`, reciprocal with the spec's
  `> **Plan:** [[plans/<basename>]]` callout;
- checkbox steps and optional `## Track:` headings consumed by execution.

This is the existing `spec : plan : PRs = 1 : 1 : N` contract. Never reinterpret or weaken it
through normalization.

### Linear

Read the managed spec again and compare its `designState` with the project lifecycle. When both
report `approved`, invoke evidence-aware `linear.sh spec-write --issue-state-map
"$LINEAR_ISSUE_STATES"` with the observed revision to author the single canonical
`designState: approved → planning` transition, require verified spec read-back, then transition
the owned project `approved → planning` with `linear.sh feature-transition --status-map
"$LINEAR_PROJECT_STATUSES"` and require verified project read-back. If the verified spec is
already `planning` while the project remains `approved`, require matching ownership, the latest
spec revision, and null branch/pull-request evidence on every managed increment, then perform only
the remaining project transition. When both artifacts report `planning`, verify ownership and
lifecycle agreement and resume without repeating either transition. Reject the inverse split,
later states, or ambiguity. Build a temporary normalized reconciliation
input and invoke `linear.sh plan-reconcile` using `LINEAR_TEAM_ID` and
`LINEAR_ISSUE_STATES`; the temporary file is transport input, not an artifact. Each array
entry represents exactly **one issue per increment** and supplies:

- a stable `incrementId`, title, and explicit unique positive integer ordinal;
- exact issue content: objective, files, complete TDD steps, acceptance coverage, automated
  verification, and manual verification;
- dependency stable IDs. The adapter materializes native `blocked by` relations and mirrors
  their issue UUIDs in owned metadata;
- exactly one Git parent: the eventual frozen base reference for a root, or one dependency
  stable ID for a stacked issue.

Ordinals are presentation order, not implicit dependencies. A dependency DAG may represent
independent overnight tracks, but each issue's Git parent must make its Graphite ancestry
representable: all non-parent dependencies must already be merged or reachable from the
declared parent. Reject cycles, unknown or cross-project dependencies, duplicate identities or
ordinals, relation/metadata drift, and unrepresentable ancestry.

Reconcile by stable identity and immediately call `linear.sh plan-read` with the captured
issue-state UUID map. Replanning may safely
add, reorder, update, and rewire issues while preserving UUIDs and execution evidence. It must
refuse to remove an issue with branch or pull-request evidence. Mutation receipts and final
read-back must agree before returning success.

## Deferral markers (stacked increments)

When an increment intentionally leaves a missing integration for a later increment, author the
paired `woostack-defer(increment N): <reason>` marker step and its removal step in increment N.
Never defer wrong code or a security gap. The marker exists only while the missing work is
open.

## Optional independent tracks

By default increments form one linear Graphite stack. A plan may instead express independent
tracks: Markdown uses top-level `## Track:` headings, while Linear uses dependency roots and
native relations. Each track starts from the selected backend's common base (the Markdown
spec+plan PR or Linear's later-frozen Git base). Tracks remain author-driven, optional, and
sequential; they isolate overnight failures rather than adding concurrency. Do not
auto-partition.

## Bite-sized tasks (TDD)

Within every increment, decompose into checkbox steps, one action each: write the failing test,
run and confirm red, implement minimally, run and confirm green, refactor if useful, and verify.
Use the canonical [woostack-tdd](../woostack-tdd/SKILL.md) kernel. Give exact paths, complete
code, commands, and expected output. Never use TBD/TODO, “similar to,” generic error-handling
steps, missing definitions, or tests without concrete cases.

The Markdown shape and normalized backend input contract are captured in
[references/plan-template.md](references/plan-template.md).

## Self-review

Before handing back, check with fresh eyes:

1. **Spec and AC coverage:** every requirement, every acceptance criterion, and each filled
   happy/error/edge case maps to an increment task/test. Whole-section `N/A` is valid only when
   the spec truly has no behavioral requirement.
2. **Placeholder and consistency scan:** no placeholders; types, signatures, and names agree.
3. **Angle coverage:** walk the plan lens in
   [angle-preflight.md](../woostack-harden/references/angle-preflight.md); address each implicated
   architecture, security, observability, API, database, and error angle.
4. **Graph validity:** increments are reviewable; ordinals are unique; dependencies are acyclic;
   Git ancestry is representable; all reconciliation read-backs are clean.

Fix issues inline; no extra review or approval gate is needed.

## Lifecycle: planning, then ready

Planning persists `planning` without starting implementation. Markdown authors
`status: planning` in plan frontmatter and leaves every checkbox unticked. Linear first writes
the canonical managed-spec `designState: planning`, then transitions the project to `planning`
before issue reconciliation; both writes require read-back.

The later plan harden owns no gate. After it amends the selected plan artifact in place, the
caller verifies the complete output. Markdown then sets plan `status: ready`; Linear performs a
final `linear.sh plan-reconcile` plus `linear.sh plan-read`, then reads the spec and uses
evidence-aware `linear.sh spec-write` to author the adjacent
`designState: planning → ready` transition before performing the project
`planning → ready` through `linear.sh feature-transition`. Every mutation requires read-back.

## Terminal state and gate boundary

Stop when the plan is written or reconciled, self-reviewed, and in `planning`. Hand back the
Markdown plan path or Linear project UUID/URL. Inside `woostack-build`, return to plan hardening.
Standalone, state explicitly that the artifact is **not execute-ready** and stop: the caller
must still invoke harden, verify the selected artifact, author `ready`, freeze the Linear base
when applicable, and pass the execution-handoff gate. Do not offer `/woostack-execute`.

This skill owns **no approval gate**. It does not present for approval, execute, commit, merge,
mark a standalone result ready, freeze a base, or chain the next phase.

## Hard constraints

- **Backend-specific reference required.** Accept only the selected backend's Markdown path or
  Linear UUID/URL; never guess.
- **One plan per spec.** Amend the joined Markdown plan or reconcile the one Linear issue set.
- **Preserve Markdown exactly.** Keep its basename, YAML frontmatter, reciprocal source join,
  checkboxes, and docs-only workflow.
- **Linear issue integrity.** One issue per increment, unique ordinal, native relations,
  mirrored dependencies, representable Git parent, full steps, AC coverage, and verified
  reconciliation are required.
- **Safe replanning.** Stable identities and evidence survive; unsafe removal or ambiguous
  read-back fails closed.
- **Lifecycle is `planning → ready`.** Hardening adds no gate; only verified output becomes ready.
- **Own no gate; never execute, commit, or merge.** Write or reconcile and hand back.
- **Standalone stops at planning.** It is not execute-ready and never offers execution; the
  caller owns harden, verification, ready, base freeze, and handoff.
