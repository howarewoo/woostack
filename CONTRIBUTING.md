# Contributing

This repo is a **published collection of skills**, not a codebase. Contributions are edits to the skills — the Markdown under `skills/` plus the support files a skill ships (HTML templates, the review engine's shell scripts and prompts, JSON config). The six skills are `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-review`, and `woostack-address-comments`.

See [AGENTS.md](AGENTS.md) for the full repo contract; this file is the short contributor's version.

## What to change

| You want to... | Edit |
|---|---|
| Change project adoption / command routing guidance | `skills/using-woostack/SKILL.md` |
| Add/revise a bootstrap decision or its default | `skills/woostack-bootstrap/references/decisions.md` |
| Swap a default framework | `skills/woostack-bootstrap/references/frameworks.md` |
| Document a new gotcha | `skills/woostack-bootstrap/references/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `skills/woostack-bootstrap/references/architecture.md` |
| Recommend a new hosting/CI/auth choice | `skills/woostack-bootstrap/references/infrastructure.md` |
| Add or revise a development pattern | `skills/woostack-bootstrap/references/patterns.md` |
| Update the branching model | `skills/woostack-bootstrap/references/development.md` |
| Refine the bootstrap procedure | `skills/woostack-bootstrap/references/bootstrap.md` |
| Change the bootstrap skill entry / discovery description | `skills/woostack-bootstrap/SKILL.md` |
| Change the build loop (brainstorm→spec→grill→plan→execute) | `skills/woostack-build/SKILL.md` |
| Change the review engine | `skills/woostack-review/SKILL.md`, `skills/woostack-review/scripts/`, `skills/woostack-review/prompts/` |
| Change the address-comments delegator | `skills/woostack-address-comments/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |

## Workflow

1. Branch from `main` (`main` is protected — PRs only, never push directly).
2. Edit the relevant skill files. One concern per PR where possible.
3. Verify every cross-link still resolves (`[label](path.md#anchor)`).
4. For shell/JSON skill assets, run the static checks the asset expects (`bash -n`, `jq`) — this repo has no app test runner or CI by design.
5. Open a PR — fill out the template.

## Editing conventions

- **Skill assets only.** Markdown, plus the support files a skill ships (HTML templates and specs, the review engine's shell scripts and prompts, JSON config). No *application* code, app build configs, or app lockfiles belong in this repo.
- **No fabricated versions.** When a skill needs a version, the procedure resolves it live (`npm view <pkg> version`). Reference frameworks by name, not by version, except in `skills/woostack-bootstrap/references/frameworks.md`, which may pin exact versions when a known incompatibility forces it.
- **Consumer state lives under `.woostack/`** in the *target* repo a skill runs against — `specs/`, `plans/`, `config.json`, `memory.md` (tracked), and `metrics.json` (gitignored). Don't reintroduce the old `.woo-review/` paths.
- Prefer tables for option matrices, bulleted lists for stepwise procedures.
- Keep examples short. The skill describes intent; project-local docs cover the specifics.
- **Cross-link rather than duplicate.** If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- Keep each `SKILL.md` in sync with its references. Its `description` must state *when* to use the skill, not summarize the workflow — a workflow summary causes agents to skip the references.

## Reviewing

Reviewers should ask:

- Does this change make the skill clearer or just longer?
- Is there a load-bearing reason this isn't already in the skill?
- Will an AI agent applying this guidance produce a working result (a bootstrapped project, a posted review, an addressed thread)?
- Does it conflict with an existing pattern? If so, update the pattern explicitly rather than letting two patterns disagree.

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
