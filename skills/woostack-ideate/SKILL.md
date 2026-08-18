---
name: woostack-ideate
description: Internal Build/Fix phase that records only user-verified decisions in a permission-restricted run draft and hands back a gate-file-ready local specification. It is not a public command.
---

# woostack-ideate

An internal building block of [`woostack-build`](../woostack-build/SKILL.md), also used by its
project-backed Fix wrapper. Ideate turns a feature request or proved fix into a complete high-level
project specification through exhaustive brainstorming. It has no approval gate, makes no provider
call, and makes no implementation or planning handoff of its own.

## Entry: admitted baseline and run manifest

The owning Build/Fix wrapper supplies the exact baseline and permission-restricted run-scoped JSON
manifest admitted under the shared
[gated draft contract](../woostack-init/references/artifact-backends.md#run-scoped-gated-draft-manifest).
Ideate verifies the manifest's run identity, restrictive permissions (`0700` directory and `0600`
regular file), draft content, monotonic revision, unresolved questions, and atomic compare-and-swap
boundary before using it.

Ideate never resolves, creates, reads, patches, or independently reads back a provider record.
Missing, stale, foreign, overly permissive, symlinked, or malformed manifest state blocks and returns
to the owning wrapper. The local run manifest is the canonical local authority and makes zero provider
calls.
## Non-negotiable content invariant

**No inferred, repository-derived, agent-preferred, or merely plausible content enters the project
specification until the user explicitly verifies it.** Repository inspection, existing Linear text,
and recommendations are evidence or prompts only. A user must verify every material goal, user,
behavior, constraint, exclusion, architecture decision, acceptance criterion, and verification
expectation before it is persisted. Silence, a plausible answer, or an agent-authored summary is
not verification.

At the specification boundary, Ideate records viable removal opportunities before additive
proposals. For each opportunity, capture the user's verified choice of safe deletion or
simplification, or the bounded reason it cannot meet the contract; never infer that addition is
necessary. Carry this removal-first analysis into the complete specification, using the canonical
[least-code doctrine](../woostack-bootstrap/references/patterns.md#10-least-code--comments) without
dropping its safety requirements.

Ideate owns the conditional collection of the specification's `## Data models` section. When the
feature or fix modifies or introduces database or storage tables, the section is required and must
capture all applicable entities/tables, fields/types, constraints, relationships, indexes, and
migration/backfill details. When the change modifies or introduces public or internal APIs, the
section is required and must capture all applicable method/path, authorization, request/response/error
shapes, and compatibility details. If both table and API changes apply, capture both in that single
`## Data models` section. When neither table nor API changes apply, omit the `## Data models` section
entirely. A table change or an API change may not omit the section. Like all other specification content,
every data model and API detail must be explicitly user-verified; never infer, synthesize, or default
schemas, migrations, or endpoints from repository inspection.

## Dialogue and local drafting

Brainstorm exhaustively within the requested feature and resolve upstream decisions first. Ask every
currently known independent question together in one clearly numbered batch, preserving exhaustive
in-scope coverage across the problem and evidence, users, desired behavior, constraints, non-goals,
interfaces/data, failure and security cases, operational effects, acceptance, and verification as
applicable. A batch may contain one question only when it is the sole currently eligible question.
Order questions by dependency layer: do not ask a
dependent question until its upstream decision is verified. A later batch may contain only questions
that become dependent after verified answers or questions that remained unresolved or ambiguous in an
earlier batch; do not defer a question that was already known to be independent. Options and an
explicit recommendation may help the user decide, but the recommendation is not a decision. Inspect
only bounded relevant repository context to find questions; never turn a convention or inconsistency
into a decision without asking.

After each user reply, persist no provider content. If it contains one or more explicit,
unambiguous verified decisions, atomically replace the manifest draft once with those decisions and
the resulting unresolved-question set before asking the next eligible batch. Recompute the exact
draft specification fingerprint and the deterministic gate-render fingerprint on that atomic
replacement. A reply with no verified decision causes no draft-content change.

Partial or ambiguous answers remain unresolved and stay in the manifest for a later eligible batch.
Never write placeholders, inferred defaults, recommendations, or repository-derived guesses.
Continue only from the complete current manifest content. A manifest permission, ownership,
identity, atomic-write, or process-continuity failure blocks; Ideate never repairs the boundary by
contacting Linear or using conversation history as authority.

When exhaustive brainstorming is complete and the latest specification has no unresolved user
decision, hand back to the owning wrapper:

- the exact baseline project identity and revision;
- the permission-restricted manifest containing the local specification (including the user-verified
  conditional `## Data models` section when table or API changes apply, or omitting it when neither
  applies);
- its `canonicalProjectSpecFingerprint` and gate-render fingerprint;
- the empty unresolved-question set; and
- the exact run/process and manifest identity.

This handoff is not approval. The owning Build or project-backed Fix wrapper owns project-spec
hardening, then uses the shared
[`streamed gate-file presentation and body-free approval contract`](../woostack-init/references/artifact-backends.md#deterministic-gate-file-approval-identity-and-streamed-presentation):
it streams the complete verified `project-spec.md` bytes and full identity (or a verified
same-process byte-complete revision diff with old/new identities) immediately before an
`Accept`/`Abandon` Ask. The wrapper then owns planning, the second streamed gate presentation,
user-controlled `Stop here`/`Execute`/`Abandon` handoff, execution, review, Git/Graphite mutation,
and every later transition. Ideate never invokes those phases, writes implementation source, or
becomes a public command.
