---
name: woostack-init
description: Create or maintain a repository's README.md, AGENTS.md, DESIGN.md, and PRODUCT.md through evidence-based guidance and material user decisions; also initialize or repair local .woostack/ support when explicitly requested.
---

# woostack-init

Help the user create or improve the root README and project guidance: accurate, repository-specific,
useful for decisions, concise, and maintainable. Inspect before asking, preserve what works, and
apply only changes the request authorizes. A rerun may make no changes.

## Command and scope

```text
/woostack-init [path]
```

The default intent is guided document authoring. Honor a request limited to one document or to
review, planning, or drafts. An explicit local-support setup/repair request, including Doctor's
missing-support referral, goes directly to [Local support](#local-support) without a document
interview. When both intents are requested, keep their authorization and verification separate.

Document work requires neither `.woostack/` nor GitHub policy validation, Doctor, or GitHub access.
Missing support or an unrelated malformed setting must not block drafting. Load support helpers
and contracts only for relevant support work.

## Guided authoring

1. **Inspect the evidence.** Resolve the target and requested scope without changing it. Read relevant
   conversation decisions, existing root and scoped agent instructions, README/contributor guidance,
   product/design documents and their canonical sources, representative code, scripts, and CI.
   Summarize what needs creating, updating, or preserving. Distinguish observed implementation,
   documented intent, and unresolved decisions; surface contradictions rather than silently choosing
   one. Preserve the authority and scope of existing instructions.
2. **Resolve material gaps.** Ask repository-informed questions only where answers change a reader's
   first-use path, product behavior, design direction, or working agreements. Offer a recommendation
   and tradeoff when useful. Do not ask for repository facts or previously answered product and
   technology decisions.
   Product → design → agent instructions is a useful default, not a required sequence.
   Adapt to the project and allow decisions to remain explicitly deferred.
3. **Draft focused guidance.** Use the [document responsibilities](#document-responsibilities) and
   applicable [document schemas](references/document-schemas.md). Create missing guidance or propose
   targeted revisions, preserving useful project-specific content.
   Identify stale, contradictory, and duplicated material for removal rather than appending another
   generated layer. Link to canonical specifications, architecture decisions, design systems, and
   contributor guidance instead of copying them; propose consolidation before replacing established
   documents. Never invent commands, metrics, architectural rationale, or settled decisions.
4. **Review meaningful changes and apply authorized edits.** Present the proposed result, calling out
   changes to product direction, design constraints, and agent permissions. Reuse authorization
   already given; do not add approval ceremonies for individual headings or paragraphs. Review-only,
   draft-only, or planning requests write nothing. Unapproved scope expansion remains a proposal. Preserve
   unrelated work, file ownership, and existing file/symlink relationships: verify a linked target's
   identity and authorization before editing it, never replace the link or write through an unsafe or
   ambiguous path. A blocked write does not prevent presenting a draft.
5. **Verify within scope.** Check the applicable schema, consistency across affected documents,
   referenced paths/links, and technical claims against current repository evidence. Verify a format
   before adding its version marker; report applicability limits and unresolved conversions. Use
   relevant safe checks authorized by the request and project rules; distinguish commands inspected
   from commands actually executed.
   Do not run unrelated setup, network operations, or side-effectful commands to validate prose.
6. **Report the result.** State what was created, updated, intentionally preserved, or blocked, the
   verification evidence, and unresolved decisions. Leave good guidance unchanged rather than
   rewriting it for stylistic novelty.

## Document responsibilities

Use the current applicable [document formats](references/document-schemas.md), not an exhaustive
template or the same questionnaire for every project. Omit irrelevant sections. Preserve an
established architecture-focused meaning of `DESIGN.md`; the visual schema does not replace it.

| Document | Purpose | Useful content |
| --- | --- | --- |
| `README.md` | What is this project, and how do I start using it? | The [README contract](references/document-schemas.md#readmemd): evidence-backed identity, shortest verified first-use path, representative usage, and navigation to canonical docs and policies. |
| `PRODUCT.md` | What are we building, for whom, and why? | The [product record](references/document-schemas.md#productmd): users, purpose, operating context, capabilities, constraints, and confirmed principles. Separate current scope from future direction. |
| `DESIGN.md` | How should the product work and feel? | The [visual format](references/document-schemas.md#designmd) where applicable: observed or agreed identity, tokens, components, and usage. Preserve canonical system-design decisions where the document already owns them. |
| `AGENTS.md` | How should an agent work effectively in this repository? | [Unversioned operational Markdown](references/document-schemas.md#agentsmd): actual commands and working directories, conditional verification, boundaries, pitfalls, and links to deeper documentation. |

Keep `AGENTS.md` operational: no copied product specification, exhaustive file inventory, generic
coding advice, or duplicated Woostack workflows. Include contextual pointers to `PRODUCT.md` and
`DESIGN.md` when applicable so an agent knows when to read them; do not assume automatic loading.
When creating or updating `AGENTS.md` during Woostack adoption, use the concise, availability-aware
[routing paragraph](../using-woostack/SKILL.md#agentsmd-usage), replacing unconditional Woostack
usage or installation requirements. Use installed skills when available; missing skills must not
block ordinary repository work. Do not copy the workflow catalog or flatten scoped instructions.

## Local support

Use this secondary path only for explicit support initialization/repair. It stays local-only and
provider-free and does not require product/design decisions or document edits.

1. Resolve the canonical target repository without changing it. Verify repository root, branch,
   working state, existing `.woostack/` files, and collision/symlink/path safety.
2. Resolve effective local policy with
   [`scripts/config/resolve-config.sh`](scripts/config/resolve-config.sh). It merges tracked
   `.woostack/config.json` with the optional primary-checkout `.woostack/config.local.json`,
   validates the optional canonical `github` object, and preserves unrelated user-owned settings.
   The [artifact contract](references/artifact-backends.md#canonical-github-configuration) owns
   configuration fields, precedence, validation, and retained legacy-setting protections.
3. Create only missing support paths within the selected support scope:
   - `.woostack/config.json` from [`templates/config.json`](templates/config.json);
   - local diagnostic report roots for Doctor, audit, and QA; and
   - worktree/recovery support declared by the [worktree contract](references/worktrees.md).

   Propose repairs to existing support only within the authorized changeset; do not overwrite
   user-owned settings. Delegation uses agents the host exposes; Init never creates, validates, or
   repairs project agent definitions. The [OMP host notes](../using-woostack/references/hosts/omp.md)
   own optional cleanup guidance for unchanged definitions generated by older releases.
4. Validate JSON, canonical policy, permissions, ignore policy, report roots, and cross-links.
   Run the shipped Doctor checks through [Doctor](../woostack-doctor/SKILL.md). Fail closed on
   unsafe paths, permissions, collisions, malformed canonical configuration, or incomplete recovery
   evidence for the affected support operation, not unrelated document drafting.
5. Report created, repaired, preserved, skipped, and blocked support paths with exact validation
   results. Never infer a GitHub owner, Project, Status field, issue, or publication destination,
   contact a provider, or select remote persistence.

Existing `.woostack/tmp/runs/`, legacy drafts, manifests, locks, reports, and remote records are
historical user data. Do not import, rewrite, delete, or recreate wrappers from them. The
[artifact contract](references/artifact-backends.md#retained-data-and-retirement) owns these
protections and the optional read-only historical reader; unknown or partial outcomes stop at the
last independently read boundary.

## Boundaries

Init authors authorized project guidance and explicit local support, not application source or a
scaffold. It creates no issue, Project, branch, commit, pull request, or lifecycle state; it never
pushes, merges, reads/writes credentials, migrates retained data, or performs destructive cleanup.
It never creates host extensions or `.omp/` for session naming. User-owned files, legacy settings,
retained records, dirty worktrees, and reports remain preserved.
