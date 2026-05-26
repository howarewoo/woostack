# CLAUDE.md

This repo is a **spec**, not a codebase. It defines how new web + mobile + API projects should be built; AI agents use it to bootstrap fresh projects at the latest framework versions.

## Repo contents

```
woo-stack/
├── README.md          Public-facing overview
├── CONTRIBUTING.md    How to evolve the spec
├── LICENSE
└── spec/
    ├── architecture.md     Monorepo layout, package tiers, naming
    ├── frameworks.md       Default frameworks + catalog + gotchas
    ├── infrastructure.md   Hosting, CI/CD, env, services
    ├── patterns.md         oRPC, TanStack Query, RSC, navigation, TDD
    ├── development.md      End-to-end dev loop + branching model
    └── bootstrap.md        Step-by-step bootstrap procedure
```

No `apps/`, `packages/`, lockfiles, or build configs live here. They get generated at bootstrap into a fresh project.

## Two modes Claude may be invoked in

### Mode A — editing the spec (this repo)

User is updating the spec itself: adding a new pattern, swapping a default framework, documenting a gotcha, refining the bootstrap procedure.

Rules:
- Keep changes scoped — one spec section per PR where possible.
- Cross-link related sections (markdown `[label](path.md#anchor)`) rather than duplicating prose.
- When adding a gotcha, put it under [spec/frameworks.md](../spec/frameworks.md#known-gotchas-to-respect-at-bootstrap).
- When changing the dev workflow or branching model, update [spec/development.md](../spec/development.md).
- No code to lint or test — just markdown. Verify links resolve before declaring done.

### Mode B — bootstrapping a new project from the spec

User has pointed Claude at this repo and asked for a new project. Follow [spec/bootstrap.md](../spec/bootstrap.md) end to end. The spec files are inputs; the output is a fresh repo in a different directory.

When in this mode:
- Treat all `spec/*.md` files as binding for the scaffolded project.
- Apply [spec/development.md](../spec/development.md) for any subsequent feature work after bootstrap.
- Resolve framework versions live (`npm view <pkg> version`) — don't hard-code from memory.
- Cross-check every resolution against the gotchas list in [spec/frameworks.md](../spec/frameworks.md).
- After scaffolding, run `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev` to verify each surface boots.

## Editing conventions

- Markdown only in this repo. Code samples are illustrative — they live inside fenced blocks, not real files.
- Keep tables for option matrices; bullets for stepwise procedures.
- Reference frameworks by name, not version. Versions live in [spec/frameworks.md](../spec/frameworks.md) only — and that file specifies "latest" rather than literal numbers where possible.
- No screenshots in this repo. Old `docs/web-app.png` was tied to the deleted boilerplate.

## What this repo does **not** have

Spelled out so Claude doesn't go looking:

- No `package.json`, no `pnpm-lock.yaml`, no `tsconfig.json` at root.
- No `apps/`, no `packages/`.
- No Biome / Turborepo / Vitest configs.
- No CI workflow (no code to build or test).
- No skills under `.claude/skills/`.

If a future change needs any of these, justify it against the spec-only goal first.
