---
name: woostack-ideate
description: Internal Build/Fix phase that records only user-verified decisions in a permission-restricted run draft and hands back a complete local specification. It is not a public command.
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
Ideate verifies the manifest's run/process identity, restrictive permissions, baseline project
identity/revision/fingerprint, draft content, stable keys, unresolved questions, and atomic-update
boundary before using it.

Ideate never resolves, creates, reads, patches, or independently reads back a provider record.
Missing, stale, foreign, overly permissive, symlinked, process-mismatched, or malformed manifest
state blocks and returns to the owning wrapper for fresh baseline admission. The local draft is not
Linear authority and never replaces the last Linear-approved boundary.

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
draft specification and displayed-content fingerprints on that atomic replacement. A reply with no
verified decision causes no draft-content change.

Partial or ambiguous answers remain unresolved and stay in the manifest for a later eligible batch.
Never write placeholders, inferred defaults, recommendations, or repository-derived guesses.
Continue only from the complete current manifest content. A manifest permission, ownership,
identity, atomic-write, or process-continuity failure blocks; Ideate never repairs the boundary by
contacting Linear or using conversation history as authority.

## Single handoff

When exhaustive brainstorming is complete and the latest complete specification has no unresolved
user decision, hand back to the owning wrapper:

- the exact baseline project identity and revision;
- the complete local specification;
- its `canonicalProjectSpecFingerprint`;
- the empty unresolved-question set; and
- the exact run/process and manifest identity.

This handoff is not approval. The owning Build or project-backed Fix wrapper owns
project-specification hardening and the exact `project-spec-approval` gate, then owns planning,
execution, review, Git/Graphite mutation, and every later transition. Ideate never invokes those
phases, writes implementation source, or becomes a public command.
