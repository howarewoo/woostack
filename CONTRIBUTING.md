# Contributing

This repo publishes skills for AI coding assistants, their supporting files, a documentation
site, and a standalone component catalog. The [command index](skills/using-woostack/SKILL.md#command-routing) lists Plan,
standalone Ideate and Harden, and the other public commands. Read [AGENTS.md](AGENTS.md)
for standing repository rules, the two-app boundary, and verified checks.

## What to change

| You want to... | Edit |
|---|---|
| Change shared bundled procedures or supporting assets | Canonical file under `shared/references/`, `shared/scripts/`, or `shared/templates/`, then `node shared/sync.mjs` and all affected generated copies |
| Change how bundled copies are projected or checked | `shared/sync.mjs` and `shared/mapping.json` |
| Change project adoption / optional command index | `skills/woostack-init/SKILL.md#document-responsibilities` / `skills/using-woostack/SKILL.md` |
| Change retained run handling or direct GitHub publication | `shared/references/artifact-backends.md` and the GitHub profile |
| Refine material technology-selection decisions | `skills/woostack-plan/SKILL.md` |
| Change placement, boundary, dependency, or least-code guidance | `shared/references/patterns.md` |
| Change deployment, migration, secrets, or client-lifecycle guidance | `shared/references/infrastructure.md` |
| Refine safe initial project creation | `shared/references/scaffold.md` |
| Change checkout isolation or base selection | `shared/references/worktrees.md` |
| Change explicit model/effort selection wording | `shared/references/identity.md` |
| Change the reusable delivery (commit/PR) procedure | `shared/references/delivery.md` |
| Plan work and optional GitHub issue publication | `skills/woostack-plan/SKILL.md` and its references |
| Change requirements exploration (Ideate) | `skills/woostack-ideate/SKILL.md` |
| Change read-only specification review (Harden) | `skills/woostack-harden/SKILL.md` |
| Change multi-task coordination and stacked delivery | `skills/woostack-orchestrate/SKILL.md` |
| Change the execute phase implementation step | `skills/woostack-execute/SKILL.md` |
| Change behavior-preserving code simplification | `skills/woostack-simplify/SKILL.md` |
| Change commit and pull-request delivery | `skills/woostack-commit/SKILL.md`; the reusable delivery procedure lives in `shared/references/delivery.md` |
| Change browser-based app checks (`/woostack-qa`) | `skills/woostack-qa/SKILL.md`, `skills/woostack-qa/references/` |
| Change UI design coordination and selected external-skill boundaries | `skills/woostack-design/SKILL.md` |
| Change placement of existing screen-flow frames | `skills/woostack-flow-layout/SKILL.md` |
| Change project-owned design catalog creation, adaptation, or maintenance | `skills/woostack-design-system/SKILL.md` and its references |
| Change session reflection (`/woostack-reflect`) | `skills/woostack-reflect/SKILL.md` |
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change test-writing guidance | `skills/woostack-execute/SKILL.md`, `shared/references/tdd.md` |
| Run workflow smoke checks | `skills/using-woostack/references/workflow-smoke.md` |
| Change how review comments are addressed | `skills/woostack-address-comments/SKILL.md` |
| Change workspace checks and repairs (`/woostack-doctor`) | `skills/woostack-doctor/SKILL.md` |
| Update agent instructions (Claude or any) | `AGENTS.md` (`.claude/CLAUDE.md` is a symlink to it) |
| Update reader-facing guides | `apps/docs/content/docs/` |
| Change the documentation site or skill-page generator | `apps/docs/` |
| Change the standalone component catalog | `apps/design/` |
| Change workspace orchestration or shared dependency resolution | Root pnpm/Turborepo configuration and `pnpm-lock.yaml` |

## Workflow

1. Create a Git branch from the approved base — `main` for an independent change, the approved
   predecessor branch for one layer of a planned stack — and work there; `main` is protected.
2. Edit the relevant files. Keep each PR focused on one concern where possible.
3. Check that relative links and heading links still resolve (`[label](path.md#anchor)`).
4. Select checks under the root [validation policy](AGENTS.md#validation). This repo has
   no test CI for its own PRs. Report deterministic helper results, manual instruction
   traces, and real host/model outcomes separately; never report an unrun smoke as passed.
5. Push the branch and open a draft PR with `gh`, filling out the PR template, through
   [Commit](skills/woostack-commit/SKILL.md). The reusable delivery and source-control
   safeguards live in [shared delivery](shared/references/delivery.md) and
   [shared source control](shared/references/source-control.md); requested rebases, stack
   consolidation, and readiness follow Commit's own maintenance terms. Never merge, auto-merge,
   or queue a PR.

The approved applications are the documentation site in `apps/docs/` and the standalone
catalog in `apps/design/`. Their [docs README](apps/docs/README.md) and
[catalog README](apps/design/README.md) cover app-specific development.
Root pnpm commands use Turborepo to coordinate both apps (including lint, format, test,
and verify tasks); install from the root with `pnpm install --frozen-lockfile` using the shared root lockfile.

## Editing conventions

- Keep workflow changes in skill files and their supporting Markdown, templates, scripts,
  prompts, or JSON. Every skill works without another Woostack skill installed: it owns its
  activation, workflow, approval boundaries, completion conditions, and result, and it never
  enters a sibling Woostack workflow to obtain a procedure. External workflows are not dependencies
  except for [Design's explicit exception](#external-design-skills). Reuse common procedures through
  [bundled references](#shared-canonical-references) maintained from one canonical source;
  shared guidance never expands authority or silently changes the active workflow's gates.
  Design System application/configuration sources ship as non-runnable
  `.template` assets; instantiate them only in target or disposable repositories. Runnable
  application code and app build configuration belong in `apps/docs/` or
  `apps/design/`. App manifests own their dependencies; the root owns pnpm workspace
  and Turborepo orchestration configuration and the shared `pnpm-lock.yaml`.
- Pull-request review uses [Pullfrog](https://pullfrog.com/); the shipped workflow is
  `.github/workflows/pullfrog.yml`.
- Resolve selected or changed dependency versions from authoritative current registries.
  Preserve unrelated versions and lockfiles. Name frameworks without versions; document
  necessary incompatibility pins at the consuming owner under
  `shared/references/patterns.md#6-dependencies-resolution-ownership-and-integrity`.
- Keep retained run data and direct GitHub publication in the
  [artifact contract](shared/references/artifact-backends.md). Link to the
  [GitHub profile](shared/references/artifact-providers/github.md) for resource
  identity and capability details; Plan requires neither Project configuration nor a parent issue.
- Use tables to compare options and numbered lists for steps.
- Keep the command names and fixed skill paths listed in the
  [command index](skills/using-woostack/SKILL.md#command-routing); the
  router is an optional index and adoption aid, and every skill stays executable with
  `using-woostack` absent.
- GitHub operations do not add commands.
- Keep each `SKILL.md` consistent with its references. Its `description` should explain when to
  use the skill; put the procedure in the body and linked references.
- Update affected authored site guides when behavior changes. Do not edit generated skill pages;
  they are rebuilt from `skills/*/SKILL.md`.
- `shared/mapping.json` identifies generated copies inside each consuming skill.
  Edit canonical files in `shared/` and run `node shared/sync.mjs` rather than hand-editing copies;
  a copy update without its canonical edit is a defect, and `--check` reports drifted or missing
  copies without rewriting them.

## External design skills

`woostack-design` is the sole exception to the no-external-workflow rule. It may require and invoke
selected installed external design skills under its [dependency boundary](skills/woostack-design/SKILL.md#dependency-boundary).
It still must not load or invoke sibling Woostack workflows. Installation, execution, and publication
permissions remain distinct. Other skills keep their existing independence.

## Shared canonical references

Reusable procedures live once in `shared/references/`; supporting scripts and templates live in
`shared/scripts/` and `shared/templates/`. They are projected into matching skill-local paths so
skills need no sibling installation or source checkout. `shared/mapping.json` owns the explicit source-to-consumer
mapping: a consuming skill carries only what it needs, including the complete transitive asset set.
The active skill retains workflow decisions; shared procedures grant no additional authority.
Regenerate
copies with `node shared/sync.mjs` and check them with `node shared/sync.mjs --check`
(exit code 0 clean, 1 inconsistent, 2 invalid invocation). The production asset tests validate each
skill in isolation; commit a canonical edit and all affected copies in the same change.
Installed links stay skill-local, and a shared reference never starts another workflow or imposes
its standalone lifecycle.
Canonical source and projection behavior is owned by
[shared/sync.mjs](shared/sync.mjs) and validated under the
[validation policy](AGENTS.md#validation).

## Instruction and complexity review

Before adding instructions, simplify or remove obsolete text at the narrowest existing owner and
reuse what already works. Load detailed guidance only for applicable work; keep necessary independent
safety checks, security, error handling, and recovery. A concrete gap or supported risk can justify
growth, but an isolated failure to follow a clear rule does not.

- What existing instruction or capability was removed, clarified, or reused?
- If the change grows the instructions or machinery, why is that growth necessary?

## Questions

Open a [skill issue](.github/ISSUE_TEMPLATE/bug_report.yml) or [skill proposal](.github/ISSUE_TEMPLATE/feature_request.yml).
