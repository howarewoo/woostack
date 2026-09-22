---
name: woostack-harden
description: Public read-only phase for reconciling a supplied specification or candidate issue plan against bounded repository evidence with explicit user-owned corrections.
---

# woostack-harden

`woostack-harden` is the public repository-reconciliation phase. It is directly callable and may be
composed by [`woostack-prepare`](../woostack-prepare/SKILL.md) after Ideate or Debug. It returns a
complete plain candidate packet; it does not publish issues, create runs, edit source, or invoke a
downstream phase.

## Command and input

```text
/woostack-harden <specification-or-issue-plan>
```

Pass the complete plain packet described in
[`planning-inputs.md`](../using-woostack/references/planning-inputs.md), including an exact
repository identity, immutable baseline, and the evidence identity to inspect. The content must be
a complete specification or candidate issue plan; a prior Ideate or Debug handback may be passed.
The caller supplies the complete specification or diagnosis, exact repository/baseline and evidence
Harden may inspect bounded repository facts read-only and reconcile contradictions, missing
acceptance, risks, removal/reuse, or verification boundaries. It does not require a Prepare run,
writable checkout, GitHub configuration, or Project. Retained historical content is evidence only
until its identity and freshness are revalidated.

Resolve available repository and baseline facts through the shared input contract. Ask for missing
content or a target/evidence scope only when it remains ambiguous or inaccessible after those reads.
Do not discover a run by title, branch, recent activity, or search ranking. If a supplied handback
is stale, foreign, incomplete, or conflicting, preserve its decisions and identify the affected
evidence; revalidation does not authorize silently replacing approved content.

An exact GitHub issue or pull request may be supplied as read-only evidence when the user explicitly
selects it and the authorized host capability can read and independently verify it completely. A
GitHub Project configuration is never required for public Harden. Unsupported, unavailable, partial,
or stale selected context is a blocker for that evidence path, not permission to guess or fall back
to a different resource.

## Reconciliation invariant

Repository evidence can expose a question; it cannot answer a user-owned decision. Existing
conventions, issue text, recommendations, and apparently safer alternatives are observations or
unverified recommendations only. Harden never silently changes scope, behavior, architecture,
compatibility, security boundaries, acceptance, verification, or plan dependencies.

At both specification and candidate-plan boundaries, perform the removal-first check: verify whether
safe deletion, reuse, simplification, or generalization can satisfy the supplied contract before
accepting additive work. If evidence supports simplification, present it and ask the user to keep
or correct the content. Preserve required safety and compatibility protections.

For a specification, validate the conditional `## Data models` section against bounded schemas,
migrations, routes, and data-layer conventions. If evidence indicates storage/table or public/internal
API changes, the one section must be present and complete across all applicable entities/tables,
fields/types, constraints, relationships, indexes, migration/backfill, method/path, authorization,
request/response/error shapes, and compatibility details. If neither applies, the section must be
omitted. A missing, extra, incomplete, or conflicting section is a material discrepancy; report it
and ask for explicit user validation. Harden never synthesizes its contents.

For a candidate issue plan, reconcile each stable task key and ordinal, outcome, scope, non-goals,
affected paths/interfaces, acceptance, check and smoke scenario, risks, prerequisites, and
Git-parent-selection policy against the supplied specification and repository evidence. Preserve
real dependency edges; never infer an issue endpoint, parent, prerequisite, or publication identity.
Plan owns any later issue publication.

## Reconciliation dialogue

Inspect only bounded files, configuration, tests, documentation, and explicitly selected remote
context that can bear on the supplied content. Work one material discrepancy at a time:

1. state the exact content section, task key, or evidence identity involved;
2. separate the observed repository fact from its interpretation and recommendation;
3. ask whether to correct the content, keep the approved decision, or clarify the evidence;
4. wait for explicit user validation before changing anything; and
5. preserve unrelated user-authored content while returning to the next discrepancy.

A choice to keep an inconsistency is itself a user decision. Record its rationale only when the user
asks for that rationale in the returned content. Reusing a complete approved handback does not repeat
settled decisions; revalidate only stale, conflicting, or newly exposed evidence. Never speculate
about an unobserved check or report a command as passing because it appears in the plan.

## Read-only boundary

Harden performs no GitHub or remote writes, issue creation, source edit, implementation-worker
dispatch, commit, branch, worktree, Plan, Execute, Orchestrate, or PR action. It may perform
read-only repository inspection and an explicitly selected exact GitHub read. It does not create a
manifest, canonical planning ledger, mirror, or hidden compatibility wrapper. A user may explicitly
save the plain handback, but saving is not approval or authority.

## Complete handback

When bounded reconciliation finds no remaining material discrepancy and every correction has explicit
user validation, return the complete plain handback from
[`planning-inputs.md`](../using-woostack/references/planning-inputs.md), not a patch or delta:

- the exact repository identity and admitted baseline;
- all evidence identities, observations, and read-back limitations;
- the complete revised specification or candidate issue plan, including unchanged sections;
- confirmed corrections and preserved user decisions;
- an empty unresolved-question/discrepancy section; or, if blocked, every remaining discrepancy and
  the exact evidence or decision needed; and
- the read-only boundary plus the separate possible next consumer, such as Plan or Execute.

This handback is composable content. Harden never invokes Plan automatically, creates GitHub issues,
selects a publication destination, dispatches implementation, commits, or submits a PR. The caller
explicitly decides whether to save it, pass it to Plan, pass one already-authorized bounded task to
Execute, or stop.
