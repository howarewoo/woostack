# Contributing

This repo is a **published collection of skills**, not a codebase. Contributions are edits to the skills — the Markdown under `skills/` plus the support files a skill ships (HTML templates, the review engine's shell scripts and prompts, JSON config). The public command/adoption surface is `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-fix`, `woostack-change`, `woostack-plan`, `woostack-execute`, `woostack-execute-overnight`, `woostack-commit`, `woostack-review`, `woostack-address-comments`, `woostack-status`, `woostack-visualize`, `woostack-debug`, `woostack-tdd`, `woostack-dream`, `woostack-doctor`, `woostack-sweep`, `woostack-qa`, `woostack-audit`, and `woostack-respond`. The collection also ships `woostack-ideate` and `woostack-harden` as internal sub-skills, plus the pre-existing unregistered `woostack-ask` read-only investigation utility.

See [AGENTS.md](AGENTS.md) for the full repo contract; this file is the short contributor's version.

## What to change

| You want to... | Edit |
|---|---|
| Change project adoption / command routing guidance | `skills/using-woostack/SKILL.md` |
| Change artifact-backend adoption guidance | `skills/woostack-bootstrap/references/development.md` and its consumers |
| Add/revise a bootstrap decision or its default | `skills/woostack-bootstrap/references/decisions.md` |
| Swap a default framework | `skills/woostack-bootstrap/references/frameworks.md` |
| Document a new gotcha | `skills/woostack-bootstrap/references/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `skills/woostack-bootstrap/references/architecture.md` |
| Recommend a new hosting/CI/auth choice | `skills/woostack-bootstrap/references/infrastructure.md` |
| Add or revise a development pattern | `skills/woostack-bootstrap/references/patterns.md` |
| Update the branching model | `skills/woostack-bootstrap/references/development.md` |
| Refine the bootstrap procedure | `skills/woostack-bootstrap/references/bootstrap.md` |
| Change the bootstrap skill entry / discovery description | `skills/woostack-bootstrap/SKILL.md` |
| Change the build loop (ideate→spec→harden→approve spec→plan→execute) | `skills/woostack-build/SKILL.md` |
| Change the small-change fix loop (`/woostack-fix`) | `skills/woostack-fix/SKILL.md` |
| Change the bounded non-bug one-PR workflow (`/woostack-change`) | `skills/woostack-change/SKILL.md` |
| Change the ideate phase (the build loop's first step) | `skills/woostack-ideate/SKILL.md` |
| Change the harden phase (the build loop's stress-test step) | `skills/woostack-harden/SKILL.md` |
| Change the plan phase (the build loop's planning step) | `skills/woostack-plan/SKILL.md` |
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
| Change the overnight execute phase (unattended autonomous run, morning report) | `skills/woostack-execute-overnight/SKILL.md` |
| Change the stack review-sweep engine (`/woostack-sweep`) | `skills/woostack-sweep/SKILL.md` |
| Change the commit / PR update workflow | `skills/woostack-commit/SKILL.md` |
| Change the review engine | `skills/woostack-review/SKILL.md`, `skills/woostack-review/scripts/`, `skills/woostack-review/prompts/` |
| Change the standing-code audit engine (`/woostack-audit`) | `skills/woostack-audit/SKILL.md`, `skills/woostack-audit/scripts/` |
| Change the exploratory browser QA engine (`/woostack-qa`) | `skills/woostack-qa/SKILL.md`, `skills/woostack-qa/references/` |
| Change production-error response (`/woostack-respond`) | `skills/woostack-respond/SKILL.md`, `skills/woostack-respond/references/`, `skills/woostack-respond/scripts/` |
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change the test-adder / TDD doctrine home (`/woostack-tdd`) | `skills/woostack-tdd/SKILL.md` |
| Change the memory/docs curation engine (`/woostack-dream`) | `skills/woostack-dream/SKILL.md` |
| Change the address-comments delegator | `skills/woostack-address-comments/SKILL.md` |
| Change the status board / feature-state conventions | `skills/woostack-status/SKILL.md`, `skills/woostack-status/references/conventions.md`, `skills/woostack-status/scripts/` |
| Change the workspace-health diagnose/repair (`/woostack-doctor`) | `skills/woostack-doctor/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |

## Workflow

1. Branch from `main` (`main` is protected — PRs only, never push directly).
2. Edit the relevant skill files. One concern per PR where possible.
3. Verify every cross-link still resolves (`[label](path.md#anchor)`).
4. For shell/JSON skill assets, run the static checks the asset expects (`bash -n`, `jq`). For
   artifact adoption docs, run
   `bash skills/using-woostack/tests/test-artifact-reader-contract.sh`. This repo has no universal
   app test runner or self-CI by design.
5. Open a PR — fill out the template.

## Editing conventions

- **Skill assets only.** Markdown, plus the support files a skill ships (HTML templates and specs, the review engine's shell scripts and prompts, JSON config). No *application* code, app build configs, or app lockfiles belong in this repo.
- **No fabricated versions.** When a skill needs a version, the procedure resolves it live (`npm view <pkg> version`). Reference frameworks by name, not by version, except in `skills/woostack-bootstrap/references/frameworks.md`, which may pin exact versions when a known incompatibility forces it.
- **Consumer feature artifacts are backend-selected.** Markdown remains the default, not a
  universal requirement; Linear keeps its project, spec document, and increment issues natively.
  Keep non-design consumer state under `.woostack/`, and follow the
  [artifact-backend adoption contract](skills/woostack-bootstrap/references/development.md#artifact-backend)
  rather than restating adapter or lifecycle details. Don't reintroduce the old `.woo-review/`
  paths.
- Prefer tables for option matrices, bulleted lists for stepwise procedures.
- Keep examples short. The skill describes intent; project-local docs cover the specifics.
- **Cross-link rather than duplicate.** If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- **Preserve the public surface.** Artifact backends do not create skills or command-routing rows.
  Keep the twenty-two public command/adoption skills and all twenty-five fixed `SKILL.md` files
  named in [AGENTS.md](AGENTS.md).
- Keep each `SKILL.md` in sync with its references. Its `description` must state *when* to use the skill, not summarize the workflow — a workflow summary causes agents to skip the references.

## Reviewing

Reviewers should ask:

- Does this change make the skill clearer or just longer?
- Is there a load-bearing reason this isn't already in the skill?
- Will an AI agent applying this guidance produce a working result (a bootstrapped project, a posted review, an addressed thread)?
- Does it conflict with an existing pattern? If so, update the pattern explicitly rather than letting two patterns disagree.

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
