# AGENTS.md

Instructions for AI coding agents working in this repository. Compatible with Claude Code, Codex, Cursor, Aider, and any agent that respects an `AGENTS.md` convention. `.claude/CLAUDE.md` is a symlink to this file — there is one source of truth.

## What this repo is

A **published skill**, not a codebase. It packages the decisions for building new web + mobile + API projects so any agent can install it (`npx skills add howarewoo/woo-stack`) and bootstrap fresh projects at the latest framework versions. The skill entry point is [`skills/woo-stack/SKILL.md`](skills/woo-stack/SKILL.md); the binding rules are its references.

There is no application source code, no app lockfile, no build, no CI in this repo by design. (`skills-lock.json` pins the *dev* skills this repo consumes to review itself — see [Skills](#skills) — it is not an app lockfile.)

## Repo layout

```
woo-stack/
├── README.md          Public-facing overview + install
├── AGENTS.md          This file
├── CONTRIBUTING.md    How to evolve the skill
├── LICENSE
├── skills/
│   └── woo-stack/
│       ├── SKILL.md           Skill entry point (frontmatter + procedure)
│       └── references/        Binding rules, loaded on demand
│           ├── decisions.md        Decision catalog + pre-scaffold confirmation gate
│           ├── architecture.md     Monorepo layout, package tiers, naming
│           ├── frameworks.md       Default frameworks + catalog + gotchas
│           ├── infrastructure.md   Hosting, CI/CD, env, services
│           ├── patterns.md         oRPC, TanStack Query, RSC, navigation, TDD
│           ├── development.md      Dev loop + branching model
│           └── bootstrap.md        Bootstrap procedure for AI agents
├── .agents/skills/    Dev skills this repo consumes (managed by skills-lock.json)
├── .claude/           CLAUDE.md symlink + skill symlinks
├── skills-lock.json   Pins the dev skills above
└── .github/           Issue + PR templates (no workflows)
```

## Two modes

Identify which mode applies before doing anything.

### Mode A — editing the skill

The user wants to update the skill itself: add a pattern, swap a default framework, document a gotcha, refine the bootstrap procedure or the SKILL.md entry.

Rules:
- Markdown edits only. No application code, configs, or app lockfiles belong in this repo.
- One reference section per PR where possible.
- Cross-link related sections (`[label](path.md#anchor)`) rather than duplicating prose.
- Add new gotchas under [references/frameworks.md](skills/woo-stack/references/frameworks.md#known-gotchas-to-respect-at-bootstrap).
- Keep [SKILL.md](skills/woo-stack/SKILL.md) in sync — its `description` drives discovery; do not let it summarize the workflow (that causes agents to skip the references).
- Verify every cross-link resolves before declaring done.
- Follow the development loop in [references/development.md](skills/woo-stack/references/development.md) for non-trivial changes.

### Mode B — bootstrapping a new project with the skill

The agent has the skill installed (or is pointed at this repo) and is asked for a new project somewhere else — typically via `/woo-stack <goal>` (e.g. `/woo-stack create a mobile app for cataloging recipes`). Infer a recommended shape from the goal, then confirm.

Procedure:
1. Read [SKILL.md](skills/woo-stack/SKILL.md), then the files in [`references/`](skills/woo-stack/references/) — they are inputs.
2. Walk the user through [references/decisions.md](skills/woo-stack/references/decisions.md) and get explicit sign-off on every relevant decision before scaffolding anything.
3. Follow [references/bootstrap.md](skills/woo-stack/references/bootstrap.md) step by step.
4. Resolve framework versions live (`npm view <pkg> version`) — your training memory is stale; do not hard-code from it.
5. Cross-check every resolution against the gotchas list in [references/frameworks.md](skills/woo-stack/references/frameworks.md).
6. After scaffolding, verify: `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev`. Every surface should boot on its expected port.
7. Apply the development workflow in [references/development.md](skills/woo-stack/references/development.md) for any further feature work.

The output is a fresh repo in a different directory. **Do not** add code, packages, or build configs to this repo while in Mode B.

## Hard constraints

Apply in both modes:

- **No fabricated versions.** When the skill or a generated project needs a version, run `npm view <pkg> version` (or equivalent). Do not invent numbers.
- **No hidden tools.** This repo has no CI and no app test runner. Don't pretend they exist; don't add them without justification.
- **Respect branch protection.** `main` is protected and requires PRs. Push changes to a feature branch and open a PR; never force-push to `main`.
- **Cross-link, don't duplicate.** If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- **Reference frameworks by name, not version**, except in [references/frameworks.md](skills/woo-stack/references/frameworks.md), which may pin exact versions when an incompatibility forces it.
- **Caveman mode is a personal hook**, not a repo convention — do not propagate compressed prose into the skill. Skill content is written in normal English.

## Default development loop

For any non-trivial change to the skill or a downstream project:

```
brainstorm → write spec → grill-me → plan → execute (TDD) → PR → review → address → loop → merge
```

Skills referenced in the loop (when available in the agent's environment):

- `obra/superpowers:brainstorming` — explore the problem space
- `grill-me` — adversarial spec review
- `obra/superpowers:writing-plans` — turn spec into executable plan
- `obra/superpowers:executing-plans` — work the plan with TDD
- `obra/superpowers:verification-before-completion` — confirm each step
- `obra/superpowers:requesting-code-review` — write a tight reviewer brief
- `howarewoo/woo-review` — automated PR review
- `obra/superpowers:receiving-code-review` — apply review feedback systematically

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
- Do not propose adding a working CI workflow here. The skill describes the CI a downstream project should run; this repo has nothing to test.
- Do not rename files under `skills/woo-stack/references/` without updating every cross-link and the SKILL.md table.
- Do not move or rename `skills/woo-stack/SKILL.md` — `npx skills add` resolves the skill by that path.
- Do not commit `.env*`, secrets, or generated files.

### Skills

The skills referenced in [references/development.md](skills/woo-stack/references/development.md) are checked into this repo so PRs can be reviewed and refined with the same tooling the skill recommends:

- `howarewoo/woo-review` — automated PR review
- `obra/superpowers:*` — brainstorming, writing-plans, executing-plans, receiving-code-review, verification-before-completion, test-driven-development, etc.
- `grill-me` — adversarial spec review

All sources live under `.agents/skills/<name>/` with symlinks at `.claude/skills/<name>`. Versions are pinned in `skills-lock.json`. Install / upgrade through whatever tool produced `skills-lock.json` (typically `skills.sh` from the `howarewoo/woo-review` repo); do not hand-edit lock entries.

## Quick reference

| Task | File to edit |
|---|---|
| Add/revise a bootstrap decision or its default | [references/decisions.md](skills/woo-stack/references/decisions.md) |
| Swap a default framework | [references/frameworks.md](skills/woo-stack/references/frameworks.md) |
| Document a gotcha | [references/frameworks.md](skills/woo-stack/references/frameworks.md#known-gotchas-to-respect-at-bootstrap) |
| Change the monorepo layout or naming | [references/architecture.md](skills/woo-stack/references/architecture.md) |
| Recommend a new hosting/auth/data choice | [references/infrastructure.md](skills/woo-stack/references/infrastructure.md) |
| Add or revise a development pattern | [references/patterns.md](skills/woo-stack/references/patterns.md) |
| Update the dev loop or branching model | [references/development.md](skills/woo-stack/references/development.md) |
| Refine the bootstrap procedure | [references/bootstrap.md](skills/woo-stack/references/bootstrap.md) |
| Change the skill entry / discovery description | [SKILL.md](skills/woo-stack/SKILL.md) |
| Update agent instructions (Claude or any) | this file (`AGENTS.md`) |
