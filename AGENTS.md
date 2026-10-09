# AGENTS.md

Woostack publishes coding-agent skills and supporting assets. `site/` is its only
application subtree. These instructions apply repository-wide; site work also
follows [site/AGENTS.md](site/AGENTS.md). Keep `.claude/CLAUDE.md` as a symlink here.

Use woostack skills when available. At the start of work, use `using-woostack` if
available to load the project rules and route `/woostack-*` requests to the matching
installed skill. If woostack skills are unavailable, follow this file and continue
ordinary work with the host's available capabilities; installation is not required.
For an explicit `/woostack-*` command whose skill is unavailable, name the missing
skill and ask whether to install it or proceed without it before continuing.

Follow this file first when it conflicts with generic agent defaults.

## Boundaries

- Keep application source, build configuration, and app lockfiles in `site/`.
  Supporting skill scripts are allowed outside it. Create new projects in a
  different repository, not this checkout.
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
| Public command routing | [using-woostack](skills/using-woostack/SKILL.md#command-routing) |
| Authored documentation | `site/content/docs/` |
| Documentation application and generator | `site/`; follow its local instructions |

[CONTRIBUTING.md](CONTRIBUTING.md#what-to-change) has the detailed ownership map.
Read [PRODUCT.md](PRODUCT.md) when changing product scope and [DESIGN.md](DESIGN.md)
when changing workflow interaction or documentation structure. When asked to run a
Woostack command rather than edit its implementation, the selected skill owns its
workflow, provider calls, and approval gates.

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
  [patterns.md](skills/woostack-execute/references/patterns.md#6-dependencies-resolution-ownership-and-integrity).
- Update affected authored guides when behavior changes. Never edit generated
  `site/content/docs/skills/` pages; change `skills/*/SKILL.md` instead. The site
  build regenerates these pages, which remain gitignored.
- For configuration, retained-data, or publication changes, read the
  [artifact contract](skills/woostack-init/references/artifact-backends.md).
  Non-secret defaults belong in `.woostack/config.json` only after configuration
  is selected; credentials stay in the host secret store.

## Validation

There is no root application install or universal test command. Run commands from
the repository root, selecting only checks that cover what the edit can break.
A plain wording or link correction never triggers the full site test command or a
production build solely because it touches `skills/*/SKILL.md` or site content.

- Ordinary prose or reference edits: inspect changed claims, links, and anchors
  (`[label](path.md#anchor)`). When workflow semantics change, trace the relevant
  instruction path as evidence.
- Skill frontmatter, catalog, parser, generator, link-rewriting, or installation
  layout changes: run the relevant existing parser/generator/asset tests, for
  example `node --test site/scripts/gen-skills.test.mjs` and
  `node --test site/scripts/skill-assets.test.mjs`. Prefer the small complete
  relevant suite (`pnpm -C site test`, which runs `node --test scripts/*.test.mjs`)
  when that is simpler and cheaper than elaborate selection.
- MDX syntax, embedded components, generated rendering, routing, site application,
  dependency, or build-configuration changes: run the applicable rendering or build
  check. A production build (`pnpm -C site build`) remains required when the change
  can affect the production build and narrower established checks do not adequately
  cover that risk. When impact is uncertain, choose broader verification rather than
  an unsupported exemption.
- Init or Doctor helper changes: run the focused behavioral and syntax checks for the
  affected helpers, including consumers of shared helpers. Do not run those suites
  merely because a nearby instruction file changed.
- Material Plan, Execute, Commit, or Orchestrate behavior changes: run the relevant
  [workflow smoke recipe](skills/using-woostack/references/workflow-smoke.md).

When a selected site test or build needs dependencies in a checkout without its own,
run `pnpm -C site install --frozen-lockfile` first. Do not symlink `node_modules`
from another checkout; see the site instructions for the Turbopack restriction.

For changed scripts, run the actual entrypoint or focused behavioral test and relevant
syntax checks. Test behavior, not exact instruction wording or a test-only copy. Site
tests and builds do not prove that a model followed a workflow. This policy never
waives an explicit acceptance command stated in an unrelated existing issue, and no
guidance here claims that an unconfigured CI job will run deferred checks.

## Delivery

Use an approved topic branch: `main` is the base for independent work; an approved
predecessor is the base for a stack layer. Submit changes through a draft PR using
[the PR template](.github/pull_request_template.md).

[Commit](skills/woostack-commit/SKILL.md) owns delivery, requested branch rewrites, stack
consolidation, and readiness, using native Git and an available authorized GitHub integration
under its [source-control reference](skills/woostack-commit/references/source-control.md).
New PRs are drafts; existing readiness stays unchanged absent a request. Backend failures stop
the operation instead of switching transport. Merging, auto-merge, and merge queues are
human-only; issue or project status is not proof of delivery.

Report what changed, checks actually run, and checks not run with reasons. Keep
deterministic helper results, manual instruction traces, and actual host/model
outcomes separate.