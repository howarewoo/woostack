# Contributing

This repo publishes skills for AI coding assistants, their supporting files, and a documentation
site. The [command index](skills/using-woostack/SKILL.md#command-routing) lists Plan,
standalone Ideate and Harden, and the other public commands. Read [AGENTS.md](AGENTS.md)
for standing repository rules, the sanctioned `site/` exception, and verified checks.

## What to change

| You want to... | Edit |
|---|---|
| Change project adoption / command routing guidance | `skills/using-woostack/SKILL.md` |
| Change retained run handling or direct GitHub publication | `skills/woostack-init/references/artifact-backends.md` and the GitHub profile |
| Refine material technology-selection decisions | `skills/woostack-plan/SKILL.md` |
| Change placement, boundary, dependency, or least-code guidance | `skills/woostack-execute/references/patterns.md` |
| Change deployment, migration, secrets, or client-lifecycle guidance | `skills/woostack-execute/references/infrastructure.md` |
| Refine safe initial project creation | `skills/woostack-execute/SKILL.md#initial-project-scaffold` |
| Change checkout isolation or base selection | `skills/woostack-init/references/worktrees.md` |
| Plan work and optional GitHub issue publication | `skills/woostack-plan/SKILL.md` and its references |
| Change requirements exploration (Ideate) | `skills/woostack-ideate/SKILL.md` |
| Change read-only specification review (Harden) | `skills/woostack-harden/SKILL.md` |
| Change multi-task coordination and stacked delivery | `skills/woostack-orchestrate/SKILL.md` |
| Change the execute phase implementation step | `skills/woostack-execute/SKILL.md` |
| Change behavior-preserving code simplification | `skills/woostack-simplify/SKILL.md` |
| Change commit and pull-request delivery | `skills/woostack-commit/SKILL.md` and its references |
| Change browser-based app checks (`/woostack-qa`) | `skills/woostack-qa/SKILL.md`, `skills/woostack-qa/references/` |
| Change session reflection (`/woostack-reflect`) | `skills/woostack-reflect/SKILL.md` |
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change test-writing guidance | `skills/woostack-execute/SKILL.md`, `skills/woostack-execute/references/tdd.md` |
| Run workflow smoke checks | `skills/using-woostack/references/workflow-smoke.md` |
| Change how review comments are addressed | `skills/woostack-address-comments/SKILL.md` |
| Change workspace checks and repairs (`/woostack-doctor`) | `skills/woostack-doctor/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |
| Update reader-facing guides | `site/content/docs/` |
| Change the documentation site or skill-page generator | `site/` |

## Workflow

1. Create a Git branch from the approved base — `main` for an independent change, the approved
   predecessor branch for one layer of a planned stack — and work there; `main` is protected.
2. Edit the relevant files. Keep each PR focused on one concern where possible.
3. Check that relative links and heading links still resolve (`[label](path.md#anchor)`).
4. Select verification by change risk under the root [validation policy](AGENTS.md#validation),
   which owns the shared command policy. Run the changed asset's actual command or focused
   smoke, plus relevant behavioral tests and syntax checks. Tests should check behavior, not
   exact instruction wording or a test-only copy. This repo has no universal test command or
   CI for its own PRs. A wording or link correction never triggers the full site tests or a
   production build solely because of the files it touches; broader checks apply when the
   change can break rendering, the build, or shared helpers. Report deterministic helper
   results, manual instruction traces, and real host/model outcomes separately; never report
   an unrun smoke as passed.
5. Push the branch and open a draft PR with `gh`, filling out the PR template, through
   [Commit](skills/woostack-commit/SKILL.md) and its
   [source-control reference](skills/woostack-commit/references/source-control.md), which also owns
   requested rebases, stack consolidation, and readiness. Never merge, auto-merge, or queue a PR.

For site changes, select rendering or build checks by risk under the root [validation policy](AGENTS.md#validation).
The site is the exception to this repository's no-application-code rule. Its [README](site/README.md) covers local development and deployment.

## Editing conventions

- Keep workflow changes in skill files and their supporting Markdown, templates, scripts,
  prompts, or JSON. Application code, build configuration, and lockfiles belong only in `site/`.
- Pull-request review uses [Pullfrog](https://pullfrog.com/); the shipped workflow is
  `.github/workflows/pullfrog.yml`.
- Resolve selected or changed dependency versions from authoritative current registries.
  Preserve unrelated versions and lockfiles. Name frameworks without versions; document
  necessary incompatibility pins at the consuming owner under
  `skills/woostack-execute/references/patterns.md#6-dependencies-resolution-ownership-and-integrity`.
- Keep retained run data and direct GitHub publication in the
  [artifact contract](skills/woostack-init/references/artifact-backends.md). Link to the
  [GitHub profile](skills/woostack-init/references/artifact-providers/github.md) for resource
  identity and capability details; Plan requires neither Project configuration nor a parent issue.
- Use tables to compare options and numbered lists for steps.
- Keep the command names and fixed skill paths listed in the
  [command index](skills/using-woostack/SKILL.md#command-routing).
- GitHub operations do not add commands.
- Keep each `SKILL.md` consistent with its references. Its `description` should explain when to
  use the skill; put the procedure in the body and linked references.
- Update affected authored site guides when behavior changes. Do not edit generated skill pages;
  they are rebuilt from `skills/*/SKILL.md`.

## Instruction and complexity review

Before adding instructions, simplify or remove obsolete text at the narrowest existing owner and
reuse what already works. Load detailed guidance only for applicable work; keep necessary independent
safety checks, security, error handling, and recovery. A concrete gap or supported risk can justify
growth, but an isolated failure to follow a clear rule does not.

- What existing instruction or capability was removed, clarified, or reused?
- If the change grows the instructions or machinery, why is that growth necessary?

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
