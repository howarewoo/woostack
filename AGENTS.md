# AGENTS.md

Woostack publishes coding-agent skills and supporting assets. `site/` is its only
application subtree. These instructions apply repository-wide; site work also
follows [site/AGENTS.md](site/AGENTS.md). Keep `.claude/CLAUDE.md` as a symlink here.

## Boundaries

- Keep application source, build configuration, and app lockfiles in `site/`.
  Supporting skill scripts are allowed outside it. Bootstrap new projects in a
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
When asked to run a Woostack command rather than edit its implementation, load the
matching skill through the command router before acting. That skill owns its
workflow, provider calls, and approval gates.

## Editing rules

- Simplify or remove instructions at their existing owner before adding more.
  Prefer deletion and existing capabilities over new helpers. Preserve necessary
  validation, security, accessibility, error handling, data-loss protection, and
  independent safety checks. See the [instruction review](CONTRIBUTING.md#instruction-and-complexity-review).
- Keep each `SKILL.md` description focused on when to use the skill. Keep behavior
  consistent with its references; link to canonical contracts instead of copying
  them. Renaming bootstrap references also requires updating every cross-link and
  the bootstrap skill table.
- Name frameworks without versions. Resolve a needed version from its registry;
  document required incompatibility pins in
  [frameworks.md](skills/woostack-bootstrap/references/frameworks.md).
- Update affected authored guides when behavior changes. Never edit generated
  `site/content/docs/skills/` pages; change `skills/*/SKILL.md` instead. The site
  build regenerates these pages, which remain gitignored.
- For configuration, retained-data, or publication changes, read the
  [artifact contract](skills/woostack-init/references/artifact-backends.md).
  Non-secret defaults belong in `.woostack/config.json` only after configuration
  is selected; credentials stay in the host secret store.

## Validation

There is no root application install or universal test command. Run commands from
the repository root, selecting only checks that cover the changed behavior.

| Changed area | Check |
| --- | --- |
| Skill entrypoints, catalog, parser, generator, or installation layout | `pnpm -C site test` |
| Site code/content or generated-page inputs (`skills/*/SKILL.md`) | `pnpm -C site build` |
| Init helpers | `bash skills/woostack-init/scripts/tests/run-tests.sh` |
| Doctor helpers | `bash skills/woostack-doctor/scripts/tests/run-tests.sh` |
| Material Plan, Execute, Commit, or Orchestrate behavior | The relevant [workflow smoke recipe](skills/using-woostack/references/workflow-smoke.md) |

Before a site build in a checkout without its own dependencies, run
`pnpm -C site install --frozen-lockfile`. Do not symlink `node_modules` from another
checkout; see the site instructions for the Turbopack restriction.

For reference-only edits, check affected links and claims. For changed scripts,
run the actual entrypoint or focused behavioral test and relevant syntax checks.
Test behavior, not exact instruction wording or a test-only copy. Site tests and
builds do not prove that a model followed a workflow.

## Delivery

Use an approved topic branch: `main` is the base for independent work; an approved
predecessor is the base for a stack layer. Submit changes through a draft PR using
[the PR template](.github/pull_request_template.md).

[Commit](skills/woostack-commit/SKILL.md) owns the commit and pull-request delivery
workflow, using native Git with an available authorized GitHub integration as its
[source-control reference](skills/woostack-commit/references/source-control.md)
describes. Never force-push. Backend failures stop the operation rather than trigger
a fallback.

Ready-for-review transitions, auto-merge, merge queues, and merging are human-only,
even when explicitly requested. Stop at a reviewable draft PR; do not advance it
toward merge. Issue or project status is not proof of implementation or delivery.

Report what changed, checks actually run, and checks not run with reasons. Keep
deterministic helper results, manual instruction traces, and actual host/model
outcomes separate.