# AGENTS.md

Instructions for AI coding agents working in this repository. Compatible with Claude Code, Codex, Cursor, Aider, and any agent that respects an `AGENTS.md` convention. `.claude/CLAUDE.md` is a symlink to this file — there is one source of truth.

## What this repo is

A **spec**, not a codebase. It defines how new web + mobile + API projects should be built. Agents use it to bootstrap fresh projects at the latest framework versions or to evolve the spec itself.

There is no source code, no lockfile, no build, no CI in this repo by design.

## Repo layout

```
woo-stack/
├── README.md          Public-facing overview
├── AGENTS.md          This file
├── CONTRIBUTING.md    How to evolve the spec
├── LICENSE
├── .claude/
│   └── CLAUDE.md      Symlink → ../AGENTS.md
├── .github/           Issue + PR templates (no workflows)
└── spec/
    ├── architecture.md     Monorepo layout, package tiers, naming
    ├── frameworks.md       Default frameworks + catalog + gotchas
    ├── infrastructure.md   Hosting, CI/CD, env, services
    ├── patterns.md         oRPC, TanStack Query, RSC, navigation, TDD
    ├── development.md      Dev loop + branching model
    └── bootstrap.md        Bootstrap procedure for AI agents
```

## Two modes

Identify which mode applies before doing anything.

### Mode A — editing the spec

The user wants to update the spec itself: add a pattern, swap a default framework, document a gotcha, refine the bootstrap procedure.

Rules:
- Markdown edits only. No code, no configs, no lockfiles belong in this repo.
- One spec section per PR where possible.
- Cross-link related sections (`[label](path.md#anchor)`) rather than duplicating prose.
- Add new gotchas under [spec/frameworks.md](spec/frameworks.md#known-gotchas-to-respect-at-bootstrap).
- Verify every cross-link resolves before declaring done.
- Follow the development loop in [spec/development.md](spec/development.md) for non-trivial changes.

### Mode B — bootstrapping a new project from this spec

The user has pointed the agent at this repo and asked for a new project somewhere else.

Procedure:
1. Read all six files in [`spec/`](spec/) — they are inputs.
2. Follow [spec/bootstrap.md](spec/bootstrap.md) step by step.
3. Resolve framework versions live (`npm view <pkg> version`) — do not hard-code from training data.
4. Cross-check every resolution against the gotchas list in [spec/frameworks.md](spec/frameworks.md).
5. After scaffolding, verify: `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev`. Every surface should boot on its expected port.
6. Apply the development workflow in [spec/development.md](spec/development.md) for any further feature work.

The output is a fresh repo in a different directory. **Do not** add code, packages, or build configs to this repo while in Mode B.

## Hard constraints

Apply in both modes:

- **No fabricated versions.** When the spec or a generated project needs a version, run `npm view <pkg> version` (or equivalent). Do not invent numbers.
- **No hidden tools.** This repo has no CI, no skills under `.claude/`, no test runner. Don't pretend they exist; don't add them back without justification.
- **Respect branch protection.** `main` is protected and requires PRs. Push spec changes to a feature branch and open a PR; never force-push to `main`.
- **Cross-link, don't duplicate.** If a fact lives in `architecture.md`, link to it from `patterns.md`; don't restate.
- **Reference frameworks by name, not version**, except in [spec/frameworks.md](spec/frameworks.md), which may pin exact versions when an incompatibility forces it.
- **Caveman mode is a personal hook**, not a repo convention — do not propagate compressed prose into spec files. Spec content is written in normal English.

## Default development loop

For any non-trivial change to the spec or a downstream project:

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

## Branching model (for projects bootstrapped from this spec)

| Branch | Role | Parent |
|---|---|---|
| `main` | Production. | — |
| `staging` | Integration / pre-prod. | `main` |
| `feature/*` | One change, one PR. | `staging` |

Feature branches are cut from `staging`, never `main`. PRs target `staging`. `staging` is merged into `main` on a release cadence after testing. Hotfixes branch from `main`, PR to `main`, then immediately back-merge to `staging` so the branches do not diverge.

## What NOT to do

- Do not regenerate `apps/`, `packages/`, `pnpm-workspace.yaml`, or root build configs in this repo. They were removed deliberately.
- Do not propose adding a working CI workflow here. The spec describes the CI a downstream project should run; this repo has nothing to test.
- Do not write to `.claude/skills/` or `.claude/commands/`. They were removed deliberately.
- Do not rename `spec/*.md` files without updating every cross-link.
- Do not commit `.env*`, secrets, or generated files.

## Quick reference

| Task | File to edit |
|---|---|
| Swap a default framework | [spec/frameworks.md](spec/frameworks.md) |
| Document a gotcha | [spec/frameworks.md](spec/frameworks.md#known-gotchas-to-respect-at-bootstrap) |
| Change the monorepo layout or naming | [spec/architecture.md](spec/architecture.md) |
| Recommend a new hosting/auth/data choice | [spec/infrastructure.md](spec/infrastructure.md) |
| Add or revise a development pattern | [spec/patterns.md](spec/patterns.md) |
| Update the dev loop or branching model | [spec/development.md](spec/development.md) |
| Refine the bootstrap procedure | [spec/bootstrap.md](spec/bootstrap.md) |
| Update agent instructions (Claude or any) | this file (`AGENTS.md`) |
