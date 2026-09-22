---
name: woostack-ideate
description: Public phase for turning a goal or existing specification into a complete user-verified specification with explicit repository and evidence identity; read-only and composable.
---

# woostack-ideate

`woostack-ideate` is the public specification phase. It is directly callable and is also composed by
[`woostack-prepare`](../woostack-prepare/SKILL.md) for a feature or defect whose user-owned
decisions are incomplete. It returns one complete plain packet; it does not create runs, publish
issues, edit source, or invoke another phase.

## Command and input

```text
/woostack-ideate <goal-or-specification>
```

Callers pass a complete plain input packet with the goal or diagnosis, exact repository and evidence
identity, known decisions, constraints, exclusions, and any retained content. A Prepare caller may
start here with a goal; a direct caller may provide an existing specification. No writable checkout,
provider, project, or permission-restricted run is required merely to elicit decisions. If an
existing packet is complete and its settled choices are fresh, preserve them instead of repeating
approval questions.

When content or a material decision is missing, ask for that specific input. Establish repository
and evidence identity through the shared input contract before relying on repository observations.
Resolve available checkout facts with read-only tools; do not discover a fuzzy run or replace an
explicit target with a different repository. Revalidate stale evidence without silently changing
the user's decisions, and ask only for an unresolved target or material choice.

## Decision ownership invariant

**No inferred, repository-derived, agent-preferred, or merely plausible content enters the
specification until the user explicitly verifies it.** Repository inspection, existing issue text,
conventions, and recommendations are evidence or prompts only. Silence is not verification. The
user verifies every material goal, user, behavior, constraint, exclusion, architecture decision,
acceptance criterion, verification expectation, and applicable technical detail.

At the specification boundary, identify removal, reuse, simplification, and generalization
opportunities before additive proposals. For each opportunity, ask the user to verify safe deletion
or simplification, or to state the bounded reason addition remains necessary. Keep required safety,
compatibility, accessibility, and data-loss protections while applying the
[least-code doctrine](../woostack-bootstrap/references/patterns.md#7-least-code--comments).

When the change modifies or introduces storage/tables or public/internal APIs, the specification
must contain one `## Data models` section. It must capture all applicable entities/tables,
fields/types, constraints, relationships, indexes, migration/backfill details, method/path,
authorization, request/response/error shapes, and compatibility details. When neither storage nor
API changes apply, omit that section. Every detail is explicitly user-verified; never infer a
schema, migration, endpoint, or compatibility default from repository inspection.

## Elicitation

Use the active host's supported ask/question capability when available. Load the host adapter through
the [host index](../using-woostack/references/hosts/README.md); do not assume a tool name or schema.
Submit currently independent questions together, subject only to host batch limits. If the host
cannot represent a required question, ask a clearly numbered chat batch instead. Recommendations
and preselected options help explain a choice but never settle it.

Ask only questions whose answers can affect the selected work. Resolve upstream decisions before
dependent ones, while asking all currently known independent questions together. Use this coverage
order when relevant:

1. establish the problem, users, evidence, intended outcome, and prioritized behavior;
2. quantify relevant system qualities, constraints, compatibility, and non-goals;
3. resolve removal and reuse before additive architecture;
4. define entities and the conditional `## Data models` section;
5. define meaningful request, event, or data flows and state transitions;
6. capture material user-owned architecture and interface choices, leaving repository reconciliation
to Harden and issue decomposition to Plan;
7. examine capacity, failure, security, data-loss, operational, and edge risks when they can change
the design; and
8. define observable acceptance and verification expectations.

After each answer, distinguish explicitly verified decisions from unresolved or ambiguous material.
Do not add placeholders, defaults, or summaries that the user did not verify. Reusing an approved
specification or diagnosis does not repeat settled decisions; revalidate only a stale, conflicting,
or newly exposed item.

## Read-only boundary

Ideate reads only the bounded repository and evidence needed to ask or explain a decision. It makes
no provider calls, remote writes, issue creation, source edits, implementation-worker dispatch,
commit, branch, worktree, Plan, Execute, Orchestrate, or PR action. An explicit user request to save
the plain handback may write that user-selected document through the host, but that is not a
canonical planning ledger and does not authorize later work.

## Complete handback

When every material decision is explicitly verified, return the complete plain handback from
[`planning-inputs.md`](../using-woostack/references/planning-inputs.md), not only the latest answers:

- exact repository identity and admitted baseline;
- every evidence identity and the observations used;
- the complete specification, including the removal/reuse result and the conditional `## Data
  models` section;
- confirmed user decisions;
- an empty unresolved-question section; or, if incomplete, every unresolved question and why it
  blocks completion; and
- the read-only boundary plus a separate suggested next consumer such as Harden or Plan.

This is a reusable input, not approval, issue authority, or an automatic transition. The caller
explicitly decides whether to save it, pass it to Harden, pass an approved specification to Plan,
or stop.
