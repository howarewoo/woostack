# AGENTS.md

Instructions for AI coding agents working in this repository. Compatible with Claude Code, Codex, Cursor, Aider, and any agent that respects an `AGENTS.md` convention. `.claude/CLAUDE.md` is a symlink to this file — there is one source of truth.

## What this repo is

A **published collection of skills**, not a codebase. It packages the decisions for building new web + mobile + API projects so any agent can install it (`npx skills add howarewoo/woostack`) and bootstrap fresh projects at the latest framework versions. The five skills are: `woostack-init` (sets up the `.woostack/` workspace and memory store the other skills rely on), `woostack-bootstrap`, `woostack-build`, `woostack-review`, and `woostack-address-comments`.

There is no application source code, no app lockfile, no build, and no CI that runs on this repo's own events, by design. (`skills-lock.json` is the manifest for any *dev* skills this repo bundles for its own use — see [Skills](#skills) — it is not an app lockfile. It is currently empty: the repo bundles no external dev skills and relies on the agent's global install.)

The one exception is the `woostack-review` cloud delivery: `action.yml` (a composite GitHub Action) and `.github/workflows/reusable-review.yml` (a `workflow_call`-only reusable workflow) ship from this repo so consumers can run the review in their own CI via `uses: howarewoo/woostack@<ref>`. Neither runs on this repo's push/PR events — they are *shipped assets*, not CI for woostack. Both drive the same `skills/woostack-review/` scripts and prompts as the chat-host skill. Do not delete them as stray workflows.

## Repo layout

```
woostack/
├── README.md          Public-facing overview + install
├── AGENTS.md          This file
├── CONTRIBUTING.md    How to evolve the skill collection
├── LICENSE
├── skills/
│   ├── woostack-init/
│   │   ├── SKILL.md           Init skill entry point
│   │   ├── references/
│   │   │   └── memory.md          Memory-store contract (schema, lifecycle, conventions)
│   │   ├── scripts/           Runtime scripts
│   │   │   ├── build-index.sh     Rebuild MEMORY.md from individual notes
│   │   │   ├── scope-match.sh     Surface notes relevant to current task
│   │   │   └── doctor.sh          Validate workspace + memory-store health
│   │   └── templates/         Starter templates for new workspaces (includes obsidian/ — Obsidian vault config)
│   ├── woostack-bootstrap/
│   │   ├── SKILL.md           Bootstrap skill entry point
│   │   └── references/        Binding rules, loaded on demand
│   │       ├── decisions.md        Decision catalog + pre-scaffold confirmation gate
│   │       ├── architecture.md     Monorepo layout, package tiers, naming
│   │       ├── frameworks.md       Default frameworks + catalog + gotchas
│   │       ├── infrastructure.md   Hosting, CI/CD, env, services
│   │       ├── patterns.md         oRPC, TanStack Query, RSC, navigation, TDD
│   │       ├── development.md      Branching model (loop owned by skills)
│   │       └── bootstrap.md        Bootstrap procedure for AI agents
│   ├── woostack-build/
│   │   ├── SKILL.md           Feature-loop skill (brainstorm → spec → grill → plan → execute)
│   │   └── references/
│   │       ├── spec-template.md    Markdown spec scaffold (authored source)
│   │       └── spec-template.html  HTML render target (on-demand visualization)
│   ├── woostack-review/
│   │   ├── SKILL.md           Review skill (review + address verbs)
│   │   ├── scripts/           Review engine scripts
│   │   └── prompts/           Review angle prompts
│   └── woostack-address-comments/
│       └── SKILL.md           Thin delegator to woostack-review address verb
├── action.yml         Composite GitHub Action — cloud delivery of woostack-review
├── .agents/skills/    Empty — bundled dev skills removed; rely on the agent's global install
├── .claude/           CLAUDE.md symlink + first-party skill symlinks
├── skills-lock.json   Dev-skill manifest (currently empty)
└── .github/           Issue + PR templates + reusable-review.yml (workflow_call only)
```

## Two modes

Identify which mode applies before doing anything.

### Mode A — editing a skill in the collection

The user wants to update one of the skills: add a pattern, swap a default framework, document a gotcha, refine the bootstrap procedure, the build loop, the review engine, or any SKILL.md entry.

Rules:
- Skill assets only — Markdown, plus the support files a skill ships (HTML templates and specs, the review engine's shell scripts and prompts, JSON config). No *application* code, app build configs, or app lockfiles belong in this repo.
- One reference section per PR where possible.
- Cross-link related sections (`[label](path.md#anchor)`) rather than duplicating prose.
- Add new gotchas under [references/frameworks.md](skills/woostack-bootstrap/references/frameworks.md#known-gotchas-to-respect-at-bootstrap).
- Keep each SKILL.md in sync — its `description` drives discovery; do not let it summarize the workflow (that causes agents to skip the references).
- Verify every cross-link resolves before declaring done.
- Follow the development loop in [references/development.md](skills/woostack-bootstrap/references/development.md) for non-trivial changes.

### Mode B — running a collection command

The agent has the collection installed (or is pointed at this repo) and is asked to run one of the five commands. The five commands are:

| Command | What it does |
|---|---|
| `/woostack-init [path]` | Scaffold/repair the `.woostack/` workspace + memory store. |
| `/woostack-bootstrap <goal>` | Scaffold a new web/mobile/API monorepo at latest versions. |
| `/woostack-build <goal>` | Feature loop: brainstorm → markdown spec → grill → plan → execute. |
| `/woostack-review [PR#]` | Parallel review swarm + skeptical validation; posts a batched GitHub review. |
| `/woostack-address-comments [PR#]` | Address unresolved review threads autonomously. No merge. |

Bootstrap procedure (for `/woostack-bootstrap`):
1. Read [SKILL.md](skills/woostack-bootstrap/SKILL.md), then the files in [`references/`](skills/woostack-bootstrap/references/) — they are inputs.
2. Walk the user through [references/decisions.md](skills/woostack-bootstrap/references/decisions.md) and get explicit sign-off on every relevant decision before scaffolding anything.
3. Follow [references/bootstrap.md](skills/woostack-bootstrap/references/bootstrap.md) step by step.
4. Resolve framework versions live (`npm view <pkg> version`) — your training memory is stale; do not hard-code from it.
5. Cross-check every resolution against the gotchas list in [references/frameworks.md](skills/woostack-bootstrap/references/frameworks.md).
6. After scaffolding, verify: `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev`. Every surface should boot on its expected port.
7. Apply the development workflow in [references/development.md](skills/woostack-bootstrap/references/development.md) for any further feature work.

The output is a fresh repo in a different directory. **Do not** add code, packages, or build configs to this repo while in Mode B.

## Hard constraints

Apply in both modes:

- **No fabricated versions.** When the skill or a generated project needs a version, run `npm view <pkg> version` (or equivalent). Do not invent numbers.
- **No hidden tools.** This repo has no CI that runs on its own events and no app test runner. Don't pretend they exist; don't add them without justification. (`action.yml` + `.github/workflows/reusable-review.yml` are consumer-facing shipped assets, not self-CI — see [What this repo is](#what-this-repo-is).)
- **Respect branch protection.** `main` is protected and requires PRs. Push changes to a feature branch and open a PR; never force-push to `main`.
- **Use Graphite for source control.** Prefer `gt` for branch, stack, commit-amend, sync, submit, and PR operations (`gt create`, `gt modify`, `gt sync`, `gt submit`, `gt track`, `gt log`). Use raw `git` for read-only inspection and low-level operations only when Graphite does not cover the task, and do not bypass the Graphite stack state casually.
- **Cross-link, don't duplicate.** If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- **Reference frameworks by name, not version**, except in [references/frameworks.md](skills/woostack-bootstrap/references/frameworks.md), which may pin exact versions when an incompatibility forces it.
- **Caveman mode is a personal hook**, not a repo convention — do not propagate compressed prose into the skill. Skill content is written in normal English.

## Default development loop

For any non-trivial change to the skill or a downstream project:

```
brainstorm → write spec → grill-me → plan → execute (TDD) → PR → review → address → loop → merge
```

Skills referenced in the loop (when available in the agent's environment):

- `woostack-build` — brainstorm → spec → grill → plan → execute
- `woostack-review` — automated PR review
- `woostack-address-comments` — address review feedback
- `obra/superpowers:*` — brainstorming, writing-plans, executing-plans, receiving-code-review, verification-before-completion, etc. (used internally by the collection)
- `grill-me` — adversarial spec review (used by woostack-build)

When a skill is unavailable, the agent should follow the principle behind the step manually.

## Branching model (for projects bootstrapped from this skill)

| Branch | Role | Parent |
|---|---|---|
| `main` | Production. | — |
| `staging` | Integration / pre-prod. | `main` |
| `feature/*` | One change, one PR. | `staging` |

Feature branches are cut from `staging`, never `main`. PRs target `staging`. `staging` is merged into `main` on a release cadence after testing. Hotfixes branch from `main`, PR to `main`, then immediately back-merge to `staging` so the branches do not diverge.

## What NOT to do

- Do not regenerate `apps/`, `packages/`, `pnpm-workspace.yaml`, or root build configs in this repo. They were removed deliberately.
- Do not add a CI workflow that runs on this repo's own push/PR events — woostack has nothing to test. (The shipped `reusable-review.yml` is `workflow_call`-only and `action.yml` is a composite action consumers reference; neither triggers on this repo. Leave them in place.)
- Do not rename files under `skills/woostack-bootstrap/references/` without updating every cross-link and the SKILL.md table.
- Do not move or rename any of the five SKILL.md files (`skills/woostack-init/SKILL.md`, `skills/woostack-bootstrap/SKILL.md`, `skills/woostack-build/SKILL.md`, `skills/woostack-review/SKILL.md`, `skills/woostack-address-comments/SKILL.md`) — `npx skills add` resolves skills by those paths.
- Do not commit `.env*`, secrets, or generated files.

### Skills

This repo bundles **no** external dev skills. The development loop references `obra/superpowers:*` and `grill-me`, but they are no longer checked in — the agent picks them up from its own global install, and falls back to following each step's principle manually when one is unavailable. `skills-lock.json` is therefore empty.

Note: `woostack-review` is **first-party** in this repo (`skills/woostack-review/`), not a consumed external skill. The standalone `howarewoo/woo-review` repo is deprecated.

To bundle a dev skill again, use the `skills` CLI (`pnpx skills add <source>`) rather than hand-editing `skills-lock.json` or creating symlinks by hand. The CLI writes the files under `.agents/skills/<name>/`, the symlinks at `.claude/skills/<name>`, and the lock entry together.

## Quick reference

| Task | File to edit |
|---|---|
| Add/revise a bootstrap decision or its default | [references/decisions.md](skills/woostack-bootstrap/references/decisions.md) |
| Swap a default framework | [references/frameworks.md](skills/woostack-bootstrap/references/frameworks.md) |
| Document a gotcha | [references/frameworks.md](skills/woostack-bootstrap/references/frameworks.md#known-gotchas-to-respect-at-bootstrap) |
| Change the monorepo layout or naming | [references/architecture.md](skills/woostack-bootstrap/references/architecture.md) |
| Recommend a new hosting/auth/data choice | [references/infrastructure.md](skills/woostack-bootstrap/references/infrastructure.md) |
| Add or revise a development pattern | [references/patterns.md](skills/woostack-bootstrap/references/patterns.md) |
| Update the branching model | [references/development.md](skills/woostack-bootstrap/references/development.md) |
| Refine the bootstrap procedure | [references/bootstrap.md](skills/woostack-bootstrap/references/bootstrap.md) |
| Change the bootstrap skill entry / description | [SKILL.md](skills/woostack-bootstrap/SKILL.md) |
| Change the build skill (brainstorm→spec→execute) | [SKILL.md](skills/woostack-build/SKILL.md) |
| Change the review skill (review engine) | [SKILL.md](skills/woostack-review/SKILL.md) |
| Change the address-comments skill | [SKILL.md](skills/woostack-address-comments/SKILL.md) |
| Initialize the .woostack workspace | [SKILL.md](skills/woostack-init/SKILL.md) |
| Change the memory contract | [references/memory.md](skills/woostack-init/references/memory.md) |
| Update agent instructions (Claude or any) | this file (`AGENTS.md`) |
