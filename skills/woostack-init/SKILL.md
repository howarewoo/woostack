---
name: woostack-init
description: Choose, create, or maintain root Markdown project guidance through repository-informed discovery.
---

# woostack-init

Help the user choose and maintain useful root Markdown files. Inspect before asking, consult before
writing, preserve what works, and apply only changes the request authorizes. Keep guidance accurate,
repository-specific, concise, and maintainable. A rerun may make no changes.

## Command and scope

```text
/woostack-init [path]
```

A general run selects documents for the project's needs rather than assuming a fixed bundle.
Honor a request limited to one document or to review, planning, or drafts; architecture-only
requests do not edit other root documents. Document work requires no Woostack configuration,
GitHub access, or dependency installation.

## Guided authoring

For requested human-facing technical documents, load
[documentation guidance](references/documentation.md) before planning or drafting. Apply it within
the authoring steps and document schemas below, retaining this workflow's consultation and write
boundaries. Keep `AGENTS.md` operational.

1. **Inspect the evidence.** Resolve the target and requested scope without changing it. Read relevant
   conversation decisions, existing root and scoped agent instructions, README/contributor guidance,
   product/design/architecture documents and their canonical sources, representative source,
   entrypoints, manifests, configuration, scripts, and CI.
   Prepare a brief opening summary of the current understanding, existing document owners, and
   gaps that need the user's input. Distinguish observed implementation,
   documented intent, and proposed direction; surface contradictions rather than silently choosing
   one. Preserve the authority and scope of existing instructions.
   When verification guidance is relevant to scope, inspect the repository's actual tools, commands,
   instructions, CI, test suites, and available timing evidence, distinguishing demonstrated bottlenecks
   from unmeasured concerns. An adequate verification setup is a valid no-op.
2. **Consult and choose documents.** Present the summary, ask a small set of repository-informed
   questions, and wait for the user's response before drafting or writing. Ask about intent that
   affects document selection or content; read discoverable facts from the repository. Reuse
   supplied answers, presenting the resulting understanding and asking what should change instead
   of repeating the interview. Keep scoped updates focused on their relevant decisions.

   Use these topics where relevant, adapting follow-ups to the answers:

   | Topic | What to establish |
   | --- | --- |
   | Purpose and audience | What is being built, why, and for whom? Distinguish product users, documentation readers, contributors, and operators. |
   | Visibility and participation | Is the repository public now, expected to become public later, staying private, or undecided? Are external use, contributions, support, or community processes intended? |
   | Stack and structure | What technologies, platforms, deployment targets, and component boundaries are intended? Which existing choices should stay, and which are planned or undecided? |
   | Direction and experience | What outcomes, non-goals, constraints, and tradeoffs guide the work? Does a UI or shared design system need its own guidance? |
   | Stage and commitments | Who already depends on the project? What compatibility promises and data-preservation needs apply, separately from its release stage? |

   When `AGENTS.md` is in scope, confirm compatibility commitments, including "none" when applicable,
   and which data/environments must survive or are explicitly disposable. An unreleased label or
   `0.x` version establishes neither an absence of consumers nor disposable data. Preserve existing
   commitments unless explicitly changed; translate confirmed decisions using the
   [AGENTS.md guidance](references/document-schemas.md#agentsmd).

   Recommend the smallest useful set using [document responsibilities](#document-responsibilities).
   Briefly name what to create, update, preserve, or defer and why. Reuse equivalent documents and
   keep small topics in existing sections when sufficient. Future public availability can inform
   today's guidance without requiring every community or policy file now. Public visibility alone
   establishes no license, contribution policy, support promise, or compatibility commitment.

   Accept "undecided" and defer guidance that depends on it. Offer recommendations with reasons;
   distinguish them from confirmed choices. Follow up on material gaps or contradictions, not a
   fixed checklist. Never write in the same turn as unanswered interview questions. Honor an
   explicit request to proceed without questions; use supported facts and mark unresolved choices.
   For verification recommendations, use the [testing principles](references/tdd.md): prefer
   removing redundant work and configuring native capabilities before adding or replacing tools.
   Investigate only warranted options against current authoritative ecosystem sources; preserve
   settled viable choices and compare compatibility, correctness, execution cost, migration effort,
   and maintenance. Keep current setup, agreed direction, and unimplemented recommendations
   distinct, with tradeoffs and verification rather than unmeasured speedup claims.
3. **Draft focused guidance.** Draft from the agreed understanding, keeping current implementation,
   agreed future direction, and deferred decisions distinct, and never representing proposed or
   deferred architecture as already implemented. Product → design → agent instructions is a useful
   draft order, not a required sequence. Use the
   [document responsibilities](#document-responsibilities) and
   applicable [document schemas](references/document-schemas.md). Create selected missing guidance, replace
   empty or placeholder content with supported guidance, or make targeted revisions, preserving
   useful project-specific content.
   Identify stale, contradictory, and duplicated material for removal rather than appending another
   generated layer. Link to canonical specifications, architecture decisions, design systems, and
   contributor guidance instead of copying them; propose consolidation before replacing established
   documents. Favor terse guidance and flexible defaults; reserve restrictions for confirmed
   requirements and real invariants. Never invent commands, policies, metrics, rationale, or decisions.
   Repository manifests and CI configuration remain authoritative for adopted tooling. Record verified
   command existence, working directory, and conditions; keep current commands distinct from proposals
   under the [document schemas](references/document-schemas.md). Preserve scoped instructions.
4. **Review meaningful changes and apply authorized edits.** Present the proposed result, calling out
   changes to product direction, design or architectural constraints, and agent permissions.
   Reuse authorization already given; do not add approval ceremonies for individual headings or
   paragraphs. Review-only, draft-only, or planning requests write nothing. Unapproved scope expansion
   remains a proposal.
   Tooling and verification recommendations are advisory under [Boundaries](#boundaries).
   Preserve unrelated work, file ownership, and existing file/symlink relationships: verify a linked
   target's identity and authorization before editing it, never replace the link or write through an
   unsafe or ambiguous path. A blocked write does not prevent presenting a draft.
5. **Verify within scope.** Check the applicable schema, consistency across affected documents,
   referenced paths/links, and technical claims against current repository evidence. Verify a format
   before adding its version marker; report applicability limits and unresolved conversions. Use
   relevant safe checks authorized by the request and project rules; distinguish commands inspected
   from commands actually executed.
   Do not run unrelated setup, network operations, or side-effectful commands to validate prose.
6. **Report the result.** State what was created, updated, intentionally preserved, or blocked, the
   verification evidence, and unresolved decisions. Report any unimplemented recommendations,
   tradeoffs, and verification approaches separately from current setup and agreed direction. Leave
   good guidance unchanged rather than rewriting it for stylistic novelty.

## Document responsibilities

These are candidates, not a required file set. Use the applicable
[document formats](references/document-schemas.md) for selected files and omit irrelevant sections.
Preserve established names and an architecture-focused meaning of `DESIGN.md`.

| Document | Useful when | Content |
| --- | --- | --- |
| `README.md` | Readers need a project entry point. | [Identity, first use, representative usage, and navigation](references/document-schemas.md#readmemd), tailored to the intended reader. |
| `AGENTS.md` | Agents need repository-specific working guidance. | [Actual commands, conditional verification, boundaries, pitfalls, and contextual links](references/document-schemas.md#agentsmd). |
| `PRODUCT.md` | Purpose, audience, and scope need a durable home beyond a short README section. | The [product record](references/document-schemas.md#productmd), separating current scope from future direction. |
| `ARCHITECTURE.md` | Component relationships, data ownership, or boundaries need orientation. | [Responsibilities, paths, flows, constraints, and decision links](references/document-schemas.md#architecturemd). |
| `DESIGN.md` | A UI needs shared visual or interaction guidance. | The applicable [visual format](references/document-schemas.md#designmd), grounded in canonical tokens and components. Preserve existing system-design ownership. |
| `CONTRIBUTING.md` | Contributors need a shared development and review workflow. | Confirmed setup, contribution expectations, and verification, linking existing guidance. |
| `SECURITY.md` or `SUPPORT.md` | Users need a supported reporting or help route. | Actual channels, supported scope, and agreed expectations. |
| `CODE_OF_CONDUCT.md` | A community needs agreed participation and reporting rules. | The maintainer's chosen policy and reporting process. |
| `CHANGELOG.md` | Users need a maintained change history not already owned by release notes. | Relevant release changes and migration links. |

For other root Markdown, follow [additional-document guidance](references/document-schemas.md#other-root-markdown).
Defer files with no present use unless preparation is requested. Omit empty templates and leave
unsupported policies or license choices for the user to decide.

Keep `AGENTS.md` operational: no copied product specification, exhaustive file inventory, generic
coding advice, or duplicated Woostack workflows. When `AGENTS.md` is also in the authorized scope,
include or refine short conditional pointers to `PRODUCT.md`, `DESIGN.md`, and `ARCHITECTURE.md`
where applicable. Explain when to read architecture guidance, such as before changing component
boundaries or cross-component flows; link rather than copying content or assuming automatic loading.
When creating or updating `AGENTS.md` during Woostack adoption, write concise,
availability-aware skill guidance from this wording, replacing unconditional Woostack usage or
installation requirements and any existing router guidance. Do not add router references:

```markdown
Use woostack skills when available. Each installed skill carries its own activation,
authority, approval, and completion behavior and works independently. Missing skills
must not block ordinary repository work. If woostack skills are unavailable, follow
this file and continue ordinary work with the host's available
capabilities; installation is not required. For an explicit `/woostack-*` command whose
skill is unavailable, name the missing skill and ask whether to install it or proceed
without it before continuing.

Follow this file first when it conflicts with generic agent defaults.
```

Adoption output must not require another skill, the source checkout, or a shared runtime.
Do not copy the workflow catalog or flatten scoped instructions.

## Boundaries

Init authors authorized project guidance, not application source or a
scaffold. Tooling recommendations are advisory: Init installs no packages, writes or updates no
package manifests, lockfiles, or CI workflows, and schedules no implementation handoff; implementing
them remains separately authorized. It creates no issue, Project, branch, commit, pull request, or
lifecycle state; it never pushes, merges, reads/writes credentials, migrates retained data, or performs
destructive cleanup. It never creates assistant extensions or session-naming assets. User-owned files,
legacy settings, retained records, dirty worktrees, and reports remain preserved.
