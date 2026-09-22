# Contributing

This repo publishes skills for AI coding assistants, their supporting files, and a documentation
site. [AGENTS.md](AGENTS.md#what-this-repo-is) lists the public commands, including the standalone
Ideate and Harden phases. The [command index](skills/using-woostack/SKILL.md#command-routing) explains
when to use each one.

This guide covers common edits. Read [AGENTS.md](AGENTS.md) for the full repository rules.

## What to change

| You want to... | Edit |
|---|---|
| Change project adoption / command routing guidance | `skills/using-woostack/SKILL.md` |
| Change local run storage or optional provider mirroring | `skills/woostack-init/references/artifact-backends.md` and the selected provider profile |
| Add/revise a bootstrap decision or its default | `skills/woostack-bootstrap/references/decisions.md` |
| Swap a default framework | `skills/woostack-bootstrap/references/frameworks.md` |
| Document a new gotcha | `skills/woostack-bootstrap/references/frameworks.md` (Known gotchas section) |
| Adjust the monorepo layout or naming | `skills/woostack-bootstrap/references/architecture.md` |
| Recommend a new hosting/CI/auth choice | `skills/woostack-bootstrap/references/infrastructure.md` |
| Add or revise a development pattern | `skills/woostack-bootstrap/references/patterns.md` |
| Update the branching model | `skills/woostack-bootstrap/references/development.md` |
| Refine the bootstrap procedure | `skills/woostack-bootstrap/references/bootstrap.md` |
| Change the bootstrap skill entry / discovery description | `skills/woostack-bootstrap/SKILL.md` |
| Change requirements, planning, or the choice to start execution | `skills/woostack-build/SKILL.md` |
| Change bug diagnosis, fix approval, or delivery | `skills/woostack-fix/SKILL.md` |
| Change the one-PR enhancement or refactor workflow | `skills/woostack-change/SKILL.md` |
| Change requirements gathering (Ideate) | `skills/woostack-ideate/SKILL.md` |
| Change the check of requirements against the repository (Harden) | `skills/woostack-harden/SKILL.md` |
| Change the plan phase (the build loop's planning step) | `skills/woostack-plan/SKILL.md` |
| Change GitHub issue-graph dispatch and stacked delivery | `skills/woostack-orchestrate/SKILL.md`, `skills/woostack-orchestrate/scripts/` |
| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |
| Change browser-based app checks (`/woostack-qa`) | `skills/woostack-qa/SKILL.md`, `skills/woostack-qa/references/` |
| Change skill evaluation (`/woostack-eval`) | `skills/woostack-eval/SKILL.md`, `skills/woostack-eval/references/`, `skills/woostack-eval/scripts/` |
| Change session reflection (`/woostack-reflect`) | `skills/woostack-reflect/SKILL.md`, `skills/woostack-reflect/scripts/` |
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change test-writing guidance or the add-tests command | `skills/woostack-tdd/SKILL.md` |
| Change how review comments are addressed | `skills/woostack-address-comments/SKILL.md` |
| Change the status board / feature-state conventions | `skills/woostack-status/SKILL.md`, `skills/woostack-status/references/conventions.md`, `skills/woostack-status/scripts/` |
| Change workspace checks and repairs (`/woostack-doctor`) | `skills/woostack-doctor/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |
| Update reader-facing guides | `site/content/docs/` |
| Change the documentation site or skill-page generator | `site/` |

## Workflow

1. Create a Git branch from `main`. The branch is a separate line of work;
   `main` is protected, so changes go through a pull request (PR).
2. Edit the relevant files. Keep each PR focused on one concern where possible.
3. Check that relative links and heading links still resolve (`[label](path.md#anchor)`).
4. Run the changed asset's actual command or a focused smoke check, plus relevant behavioral
   tests and syntax checks. Tests should check behavior, not exact instruction wording or a
   test-only copy of the implementation. This repo has no universal test command or CI for its own PRs.
5. Push the exact branch without force and open a draft PR with `gh`, filling out the PR template.
   Graphite is optional when explicitly selected or the task/stack is verified as already managed;
   follow the [source-control contract](skills/woostack-commit/references/graphite.md).
   Agents must not mark it ready, enable auto-merge, queue it for merging, or merge it.

For site changes, run `pnpm -C site build`. The site is the exception to this repository's
no-application-code rule. Its [README](site/README.md) covers local development and deployment.

## Editing conventions

- Keep workflow changes in skill files and their supporting Markdown, templates, scripts,
  prompts, or JSON. Application code, build configuration, and lockfiles belong only in `site/`.
- Pull-request review uses [Pullfrog](https://pullfrog.com/); the shipped workflow is
  `.github/workflows/pullfrog.yml`.
- Resolve package versions from the registry when needed (`npm view <pkg> version`).
  Name frameworks without versions, except where a known incompatibility requires a pin in
  `skills/woostack-bootstrap/references/frameworks.md`.
- Keep plan storage, optional remote copies, and recovery rules in the
  [artifact contract](skills/woostack-init/references/artifact-backends.md).
  Link to the relevant provider profile for Linear, Plane, or GitHub details.
- Use tables to compare options and numbered lists for steps.
- Keep examples short. Skills explain the workflow; project-local docs cover project details.
- Link to the document that owns a fact instead of repeating it elsewhere.
- Keep the command names and fixed skill paths listed in [AGENTS.md](AGENTS.md).
  Provider integrations do not add commands.
- Keep each `SKILL.md` consistent with its references. Its `description` should explain when to
  use the skill; put the procedure in the body and linked references.
- Update affected authored site guides when behavior changes. Do not edit generated skill pages;
  they are rebuilt from `skills/*/SKILL.md`.

## Reviewing

Reviewers should ask:

- Does this change make the skill clearer or just longer?
- Does each added instruction address a real need?
- Will an AI agent following it produce a working result, such as a project, posted review, or resolved thread?
- Does it conflict with existing guidance? Update the owning document so readers do not get two different answers.

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
