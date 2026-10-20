# AGENTS.md

Woostack publishes coding-agent skills and supporting assets. Applications live in
`apps/`: the documentation site in `apps/docs/` and the component catalog in
`apps/design/`. Docs work also follows
[apps/docs/AGENTS.md](apps/docs/AGENTS.md). Keep `.claude/CLAUDE.md` as a symlink here.

Use Woostack skills when available and their advertised workflow fits the work.
`using-woostack` is an optional navigation aid, not a prerequisite. Each skill owns its
activation, authority, approval, and completion behavior; neither a sibling Woostack skill nor the
source checkout is required. If Woostack skills are unavailable, follow this file and continue
ordinary work with the host's available capabilities; installation is not required.
For an explicit `/woostack-*` command whose skill is unavailable, name the missing skill
and ask whether to install it or proceed without it before continuing.

Follow this file first when it conflicts with generic agent defaults.

## Boundaries

- Skills are independent of sibling Woostack workflows. The [contributor guide](CONTRIBUTING.md#shared-canonical-references)
  owns shared assets and synchronization; its [external Design exception](CONTRIBUTING.md#external-design-skills)
  governs selected external dependencies.
- Keep application source and build configuration in the owning `apps/` package.
  Root pnpm and Turborepo configuration owns workspace orchestration and the shared
  lockfile. Published supporting assets stay inside each skill; their shared sources live in `shared/`.
- Public skill names and paths are installed interfaces. Moving, renaming, or
  retiring a public skill requires explicit approval. Approved retirements remove
  the complete skill and its references; do not add compatibility aliases.
- Never commit `.env*`, credentials, generated app artifacts, or personal
  compressed prose. Preserve unrelated work; do not silently rebase, reset, clean,
  stash, delete, or overwrite changes you have not verified as yours.
- Retained runs, drafts, and retired provider records are historical user data.
  Read them for recovery evidence; never migrate or mutate them.

## Where to work

| Change | Owner |
| --- | --- |
| Skill behavior and supporting assets | The relevant `skills/<name>/SKILL.md` and its references, scripts, or templates |
| Shared references, scripts, and templates | Canonical `shared/` files plus regenerated copies via `node shared/sync.mjs` |
| Public command routing (optional index) | [using-woostack](skills/using-woostack/SKILL.md#command-routing) |
| Authored documentation | `apps/docs/content/docs/` |
| Documentation application and generator | `apps/docs/`; follow its local instructions |
| Component catalog | `apps/design/` |
| Workspace orchestration and lockfile | Root pnpm and Turborepo configuration |

[CONTRIBUTING.md](CONTRIBUTING.md#what-to-change) has the detailed ownership map.
Read [PRODUCT.md](PRODUCT.md) when changing product scope and [DESIGN.md](DESIGN.md)
when changing workflow interaction or documentation structure. Read
[ARCHITECTURE.md](ARCHITECTURE.md) before changing component boundaries or
cross-component flows. When asked to run a Woostack command rather than edit its
implementation, the selected skill owns its workflow, provider calls, and approval gates.

## Editing rules

- Simplify or remove instructions at their existing owner before adding more.
  Prefer deletion and existing capabilities over new helpers. Preserve necessary
  validation, security, accessibility, error handling, data-loss protection, and
  independent safety checks. See the [instruction review](CONTRIBUTING.md#instruction-and-complexity-review).
- Keep each `SKILL.md` description focused on when to use the skill. Keep behavior
  consistent with its references; link to canonical contracts instead of copying
  them. Moving references requires updating every affected cross-link and anchor.
- Name frameworks without versions. Resolve a needed dependency change from its
  authoritative registry; preserve unrelated versions and lockfiles. Document
  required incompatibility pins at the dependency owner under
  [patterns.md](shared/references/patterns.md#6-dependencies-resolution-ownership-and-integrity).
- Update affected authored guides when behavior changes. Never edit generated
  `apps/docs/content/docs/skills/` pages; change `skills/*/SKILL.md` instead. The site
  build regenerates these pages, which remain gitignored.
- For configuration, retained-data, or publication changes, read the
  [artifact contract](shared/references/artifact-backends.md).
  Non-secret defaults belong in `.woostack/config.json` only after configuration
  is selected; credentials stay in the host secret store.

## Validation

Install workspace dependencies from the repository root with
`pnpm install --frozen-lockfile`. Root `pnpm dev`, `pnpm build`, `pnpm test`,
`pnpm lint`, `pnpm lint:fix`, `pnpm format`, `pnpm format:check`, `pnpm verify`,
and `pnpm types:check` run Turborepo tasks. Select only checks that
cover what the edit can break; filter an app with `--filter=docs` or
`--filter=design`. Oxlint and Oxfmt tool the workspace, with `@shadcn/lint`
registered in app configs without persistent rule enforcement.
A plain wording or link correction never triggers the full site test command or a
production build solely because it touches `skills/*/SKILL.md` or site content.

- Ordinary prose or reference edits: inspect changed claims, links, and anchors
  (`[label](path.md#anchor)`). When workflow semantics change, trace the relevant
  instruction path as evidence.
- Skill frontmatter, catalog, parser, generator, link-rewriting, or installation
  layout changes (including bundled reference copies): run the relevant existing
  parser/generator/asset tests, for
  example `node --test apps/docs/scripts/gen-skills.test.mjs`,
  `node --test apps/docs/scripts/skill-assets.test.mjs`, and
  `node --test apps/docs/scripts/shared-sync.test.mjs`. Prefer the small complete
  relevant suite (`pnpm --filter docs test`, which runs `node --test scripts/*.test.mjs`)
  when that is simpler and cheaper than elaborate selection.
- MDX syntax, embedded components, generated rendering, routing, site application,
  dependency, or build-configuration changes: run the applicable rendering or build
  check. A production build (`pnpm build --filter=docs`) remains required when the change
  can affect the production build and narrower established checks do not adequately
  cover that risk. When impact is uncertain, choose broader verification rather than
  an unsupported exemption.
- Init or Doctor helper changes: run the focused behavioral and syntax checks for the
  affected helpers, including consumers of shared helpers. Do not run those suites
  merely because a nearby instruction file changed.
- Shared-asset or projection changes: after editing a canonical `shared/` asset,
  a consuming skill's bundled copy, `shared/mapping.json`, or `shared/sync.mjs`,
  regenerate with
  `node shared/sync.mjs` and verify with `node shared/sync.mjs --check`, then run the
  relevant existing parser/generator/asset tests for the link and installation layout.
- Material Plan, Execute, Commit, or Orchestrate behavior changes: run the relevant
  [workflow smoke recipe](skills/using-woostack/references/workflow-smoke.md).

When selected checks need dependencies, install from the root shared lockfile with
`pnpm install --frozen-lockfile`. Never symlink `node_modules` from another checkout;
workspace-managed links remain within this repository's root.

For changed scripts, run the actual entrypoint or focused behavioral test and relevant
syntax checks. Test behavior, not exact instruction wording or a test-only copy. Site
tests and builds do not prove that a model followed a workflow. This policy never
waives an explicit acceptance command stated in an unrelated existing issue, and no
guidance here claims that an unconfigured CI job will run deferred checks.

## Delivery

Use an approved topic branch: `main` is the base for independent work; an approved
predecessor is the base for a stack layer. Submit changes through a draft PR using
[the PR template](.github/pull_request_template.md).

Each active workflow performs its requested delivery using the canonical
[delivery](shared/references/delivery.md) and
[source-control](shared/references/source-control.md) procedures. The standalone
[Commit](skills/woostack-commit/SKILL.md) workflow owns explicitly requested Git/PR operations,
including branch rewrites, stack consolidation, and readiness; it is not a sibling prerequisite.
New PRs are drafts; existing readiness stays unchanged absent a request. Backend failures stop
the operation instead of switching transport. Merging, auto-merge, and merge queues are
human-only; issue or project status is not proof of delivery.

Report what changed, checks actually run, and checks not run with reasons. Keep
deterministic helper results, manual instruction traces, and actual host/model
outcomes separate.