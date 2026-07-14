# Spec/plan angle pre-flight

A write-time checklist that pulls `woostack-review`'s angle lenses **forward** into authoring, so
spec and plan gaps are caught while writing — not surfaced late on the docs PR. Read by
[`woostack-harden`](../SKILL.md) (run on both the spec and the plan) and by
[`woostack-plan`](../../woostack-plan/SKILL.md)'s self-review; prompted from the spec and plan
templates.

**No gate.** Harden raises a question per gap and amends in place; plan self-review fixes inline.
The actual swarm review still runs on the execution-increment **code** PRs.

**Canonical angles — link, do not restate.** The authoritative list lives in
[`woostack-review` `load-config.sh`](../../woostack-review/scripts/load-config.sh)
(`VALID_ANGLES`); each angle's full rubric lives in
[`woostack-review/prompts/angles/`](../../woostack-review/prompts/angles/). This file only
**translates** the relevant angles from "what they flag in a diff" into "what to ask before
writing."

## Premise lens — is the problem real? (never skips)

Every change rests on a premise: that the problem is real. Walk this lens first for every spec or
fix. For a plan, follow its canonical source join and verify the linked spec's §1 already records
the premise. The lens is **never** skipped by the YAGNI rule below.

- **State the problem and the evidence it is real.** If the premise is an *inference about current
  behavior* ("the tool fails to X", "the rubric misses Y"), **demonstrate it** — a reproduction
  (bug) or a baseline showing the deficiency (enhancement). **Reject assertion-as-evidence.** Lands
  in §1 Problem (spec) / §1 Root Cause (fix).
- **Evidence bar scales with the claim.** A self-evident premise (a visible bug, an explicit user
  request) is satisfied by pointing at the repro/request — no ceremony. Only a *derived* premise
  about current behavior must be demonstrated.
- **Harden records, plan re-confirms, the gate decides.** Harden amends §1 with the evidence *or
  the disproof* and hands back. When the target is a plan, verify its linked source spec's §1
  already carries that record; do not duplicate it in the plan. A disproven premise is killed at
  the caller's approve gate, not by harden.
- **Premise ≠ priority.** This lens validates that the problem *exists*, not that it is worth
  solving vs. other work (out of scope — see the caller's gate).

## Skip rule (YAGNI)

Walk only the angles **in the lenses below** (the code-derived Spec/Plan lenses) whose surface the
artifact actually implicates. A spec with no data layer skips `database`; a CLI-only change skips
`api` and `i18n`. Do not manufacture questions for angles the work does not touch.
**The premise lens above is exempt — it never skips; every change rests on a premise.**

## Spec lens — what to build (lands in §6 Error handling / §7 Acceptance criteria)

- **security** — threat surface: untrusted input, authz boundaries, secrets, injection → each
  becomes an error/edge AC.
- **observability** — failure modes: what is logged, what must not be (PII), errors propagated
  vs. swallowed.
- **bugs** (edge/error) — the non-happy classes: empty/oversized input, concurrency, partial
  failure — captured as error/edge ACs, not left to "happy" only.
- **tests** — every behavior in the body has a testable AC in §7 (AC coverage).
- **api** — contract shape: breaking changes, versioning, auth scope of any exposed surface.
- **database** — data model, migrations, row-level access, when the spec touches storage.
- **i18n** — user-facing strings are translatable, when the spec adds UI copy.
- **deps** — any new dependency the spec implies, and why it is warranted.
- **infra** — CI/runtime/deploy surface the spec assumes.

## Plan lens — how to build (lands in decomposition + self-review)

- **architecture** — file/module boundaries, increment sequencing, abstraction depth; no layer
  leaks or copy-paste.
- **tests** — each AC maps to a failing-test step; assertions on behavior, not implementation.
- **types** — signatures and invariants consistent across tasks (no `any` escape hatch).
- **security** — implementation choices close, not open, the threat surface the spec named.
- **observability** — each task's error-handling shape is concrete (no silent catch).
- **api / database** — interface-first / migration-safe task ordering.
- **deps** — install/lockfile steps where a new dependency is introduced.

## Out of scope for spec/plan

Code-only angles — `react`, `design`, `seo`, `aeo`, `comments`, `conventions` — rarely apply to a
markdown spec or plan. They fire at the execution-increment review, on the real diff. Do not force
them here.
