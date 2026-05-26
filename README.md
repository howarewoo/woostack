# woo-stack

**A spec for bootstrapping AI-built web + mobile + API projects.**

Not a template. Not boilerplate. Just the rules — frameworks, architecture, infrastructure, and patterns — that an AI agent uses to scaffold a fresh project at the latest versions.

## Why a spec instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a six-month-stale snapshot. With capable coding agents, scaffolding from scratch is cheap. What's expensive is **deciding** — which frameworks, which architecture, which hosting, which patterns. This repo encodes those decisions so the AI doesn't have to re-litigate them every time.

## How to use it

Point an AI coding agent at this repo and tell it to bootstrap a new project. The agent reads [`spec/bootstrap.md`](spec/bootstrap.md), resolves the latest versions of the frameworks listed in [`spec/frameworks.md`](spec/frameworks.md), scaffolds the layout from [`spec/architecture.md`](spec/architecture.md), wires up infrastructure per [`spec/infrastructure.md`](spec/infrastructure.md), and applies the patterns in [`spec/patterns.md`](spec/patterns.md). The end-to-end development loop (brainstorm → plan → execute → review → merge) lives in [`spec/development.md`](spec/development.md).

Example prompt:

```
Bootstrap a new project called "acme" using this spec. Surfaces: web, api, mobile. Initial features: users, billing.
```

## Spec contents

| File | What it defines |
|---|---|
| [spec/architecture.md](spec/architecture.md) | Monorepo layout, package tiers, import boundaries, naming conventions |
| [spec/frameworks.md](spec/frameworks.md) | Recommended frameworks per layer, catalog protocol, known gotchas |
| [spec/infrastructure.md](spec/infrastructure.md) | Hosting, CI/CD, env management, observability, auth, data layer |
| [spec/patterns.md](spec/patterns.md) | oRPC contracts, TanStack Query, server components, navigation, TDD, feature exposure |
| [spec/development.md](spec/development.md) | End-to-end development workflow: brainstorm → grill → plan → execute → review → merge, plus branching model |
| [spec/bootstrap.md](spec/bootstrap.md) | Step-by-step bootstrap procedure for AI agents |

## Default stack

| Layer | Default |
|---|---|
| Web | Next.js (App Router) + React Compiler + shadcn/ui |
| Mobile | Expo + React Native + react-native-reusables + UniWind |
| API | Hono + oRPC |
| Data | TanStack Query + Zod + Supabase (Postgres, Auth, Storage) |
| Styling | Tailwind CSS (CSS-first config) with a shared theme |
| Build | Turborepo + pnpm catalog |
| Lint/format | Biome |
| Testing | Vitest, Jest (RN), Playwright |
| Hosting | Vercel (web + api) + Expo EAS (mobile) |

Versions are resolved at bootstrap time. See [spec/frameworks.md](spec/frameworks.md).

## Contributing

Spec evolution happens here. Open a PR against this repo to:

- Update default framework choices
- Add or revise patterns
- Document new gotchas
- Refine the bootstrap procedure

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Spec version

`2.0.0` — first spec-only release (boilerplate code removed; see git history for the prior template).

## License

[MIT](LICENSE) &copy; Adam Woo
