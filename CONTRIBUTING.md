# Contributing

This repo is a published skill. Contributions are edits to the skill — the markdown under `skills/woo-stack/` and the supporting docs at the root.

## What to change

| You want to... | Edit |
|---|---|
| Add/revise a bootstrap decision or its default | `skills/woo-stack/references/decisions.md` |
| Swap a default framework | `skills/woo-stack/references/frameworks.md` |
| Document a new gotcha | `skills/woo-stack/references/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `skills/woo-stack/references/architecture.md` |
| Recommend a new hosting/CI/auth choice | `skills/woo-stack/references/infrastructure.md` |
| Add or revise a development pattern | `skills/woo-stack/references/patterns.md` |
| Change the development workflow or branching model | `skills/woo-stack/references/development.md` |
| Refine the bootstrap procedure | `skills/woo-stack/references/bootstrap.md` |
| Change the skill entry / discovery description | `skills/woo-stack/SKILL.md` |

## Workflow

1. Fork or branch from `main`.
2. Edit the relevant markdown files.
3. Verify every cross-link still resolves (`[label](path.md#anchor)`).
4. Open a PR — fill out the template.

## Editing conventions

- Markdown only. No application code, configs, or app lockfiles in this repo.
- Reference frameworks by name, not by version, except in `skills/woo-stack/references/frameworks.md`. That file may pin exact versions when a known incompatibility forces it.
- Prefer tables for option matrices, bulleted lists for stepwise procedures.
- Keep examples short. The skill describes intent; project-local docs cover the specifics.
- Cross-link rather than duplicate. If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- Keep `SKILL.md` in sync with the references. Its `description` must state *when* to use the skill, not summarize the workflow — a workflow summary causes agents to skip the references.

## Reviewing

Reviewers should ask:

- Does this change make the skill clearer or just longer?
- Is there a load-bearing reason this isn't already in the skill?
- Will an AI agent applying this guidance during bootstrap produce a working project?
- Does it conflict with an existing pattern? If so, update the pattern explicitly rather than letting two patterns disagree.

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
