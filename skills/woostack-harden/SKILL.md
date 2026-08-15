---
name: woostack-harden
description: Internal workflow phase that reconciles a Build/Fix run draft against bounded repository evidence and hands back complete gate-file-ready local content. It is not a public command.
---

# woostack-harden

An internal building block of [`woostack-build`](../woostack-build/SKILL.md), also used by its
project-backed Fix wrapper. Harden reconciles the user's local draft specification and, after
delegated planning, its local direct-issue plan against bounded repository evidence. It asks before
every material correction, records only what the user validates, and stops when no inconsistency
remains. It owns no provider call, approval gate, planning, execution, review, Git mutation, or
implementation.

## Exact manifest admission

Build/Fix admits its baseline and supplies the permission-restricted run manifest defined by the shared
[gated draft contract](../woostack-init/references/artifact-backends.md#run-scoped-gated-draft-manifest).
For project-spec hardening, admit its local specification. For plan hardening, admit the complete
local set of candidate direct issues, stable task keys, and dependency tuples; a parent plan issue is
not a current plan record.

Verify run identity, owner-only permissions (`0700` directory and `0600` regular file), monotonic
revision, stable-key uniqueness, complete draft content, unresolved questions, and atomic
compare-and-swap state. The wrapper alone renders and verifies the owner-only gate file; Harden
must verify the manifest can regenerate the expected bytes and must not read or write the gate file
outside that boundary. A missing, foreign, ambiguous, conflicting, partial, stale, overly permissive,
symlinked, or malformed manifest blocks at the last verified boundary.

Harden performs zero provider reads and writes. It never creates a second project/plan, infers a
native resource, or substitutes conversation history or repository evidence for the verified local
manifest. The local run manifest is the canonical authority.

## Reconciliation loop

Work one discrepancy at a time and ask **one question per message**. Begin with the exact manifest
draft, then inspect only the bounded repository files, configuration,
tests, documentation, and conventions that can bear on its decisions. Use
[the angle pre-flight](references/angle-preflight.md) to choose relevant reconciliation prompts;
the canonical Review lenses remain authoritative.
At both specification and planning boundaries, Harden performs the removal-first check before
accepting additive work. It challenges an additive draft when bounded evidence shows the same
contract can be met by deletion or simplification, then asks the user to validate the safe
removal—or the bounded reason addition remains necessary—without dropping behavior or safety
requirements. Record that validated analysis in the manifest and link the canonical
[least-code doctrine](../woostack-bootstrap/references/patterns.md#10-least-code--comments) rather
than duplicating it.

For the first material inconsistency:

1. State the exact manifest field or stable task key and the bounded repository evidence,
   separating observation from interpretation.
2. Ask the user whether to correct the specification/plan, keep the current decision, or clarify
   the evidence. Offer a recommendation only as an explicitly unverified recommendation.
3. Wait for explicit user validation. **Never silently change a specification or plan from
   repository evidence, even when the repository convention appears unambiguous or safer.**
4. After a correction is validated, atomically replace the affected manifest draft content and
   unresolved-question state, preserving unrelated user-authored content, then recompute all
   affected canonical fingerprints and deterministic gate-render bytes before asking the next
   question.
5. For plan changes, verify the affected stable task mappings (canonical issue references for
   retained tasks and explicit `null` entries for new tasks) and complete local dependency set;
   never simulate dependencies in prose, infer issue endpoints, or infer parent absence.

A user choice to keep an inconsistency is itself a decision, not permission to rewrite it. Record a
rationale only when the user explicitly asks for that material to be part of the specification or
plan. Repository evidence can expose a question; it cannot answer one.

## Completion and single handoff

Continue until the bounded inspection finds no remaining material inconsistency, every recorded
correction agrees with explicit user validation, and the unresolved-question set is empty. Then
verify the complete manifest once more:

- for a project specification, return the baseline project identity/revision, local specification,
  `canonicalProjectSpecFingerprint`, deterministic `project-spec.md` render fingerprint, and
  run/process/manifest identity;
- for a plan, return the baseline project identity/revision, sorted stable task mappings (canonical
  issue references for retained tasks and explicit `null` entries for new tasks), issue fingerprints,
  exact local dependency set, deterministic `execution-plan.md` render fingerprint, and
  run/process/manifest identity.

Hand this one local result back to the owning Build/Fix wrapper. This is not approval and does not
transition phases. The wrapper uses the shared
[`streamed gate-file presentation and body-free approval contract`](../woostack-init/references/artifact-backends.md#deterministic-gate-file-approval-identity-and-streamed-presentation)
to stream the complete verified gate artifact and full identity (or a verified same-process
byte-complete revision diff with old/new identities) immediately before the body-free
`Accept`/`Abandon` Ask, records the local receipt, and handles optional mirror synchronization and
retention. After gate 2, it owns the `Stop here`/`Execute`/`Abandon` handoff. Harden invokes none of
those activities and never edits implementation source.
