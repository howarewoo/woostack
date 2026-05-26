# Contributing

This repo is a spec. Contributions are edits to the spec — markdown files in `spec/` and the supporting docs at the root.

## What to change

| You want to... | Edit |
|---|---|
| Swap a default framework | `spec/frameworks.md` |
| Document a new gotcha | `spec/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `spec/architecture.md` |
| Recommend a new hosting/CI/auth choice | `spec/infrastructure.md` |
| Add or revise a development pattern | `spec/patterns.md` |
| Change the development workflow or branching model | `spec/development.md` |
| Refine the bootstrap procedure | `spec/bootstrap.md` |

## Workflow

1. Fork or branch from `main`.
2. Edit the relevant markdown files.
3. Verify every cross-link still resolves (`[label](path.md#anchor)`).
4. Open a PR — fill out the template.

## Editing conventions

- Markdown only. No code, no configs, no lockfiles in this repo.
- Reference frameworks by name, not by version, except in `spec/frameworks.md`. That file may pin exact versions when a known incompatibility forces it.
- Prefer tables for option matrices, bulleted lists for stepwise procedures.
- Keep examples short. The spec describes intent; project-local docs cover the specifics.
- Cross-link rather than duplicate. If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.

## Reviewing

Reviewers should ask:

- Does this change make the spec clearer or just longer?
- Is there a load-bearing reason this isn't already in the spec?
- Will an AI agent applying this guidance during bootstrap produce a working project?
- Does it conflict with an existing pattern? If so, update the pattern explicitly rather than letting two patterns disagree.

## Questions

Open a [spec issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [spec proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
