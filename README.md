# woo-stack

**A spec for bootstrapping AI-built web, mobile, and API projects.**

Not a template. It's the rules an AI agent follows when scaffolding a fresh project: frameworks, architecture, infrastructure, patterns.

## Why a spec instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a snapshot that was already six months stale by the time you cloned it. Coding agents are good enough now that scaffolding from scratch is cheap. What's expensive is deciding what to scaffold. This repo holds those decisions so the agent doesn't re-litigate them every time someone wants a new project.

## How to use it

Point an AI coding agent at this repo and tell it to bootstrap a new project. The agent works through [`spec/bootstrap.md`](spec/bootstrap.md), which references the other spec files: [`frameworks.md`](spec/frameworks.md) for what to install, [`architecture.md`](spec/architecture.md) for the monorepo layout, [`infrastructure.md`](spec/infrastructure.md) for hosting and services, and [`patterns.md`](spec/patterns.md) for how the code should be organized. The dev loop the agent should use afterward (brainstorm, plan, execute, review, merge) is in [`spec/development.md`](spec/development.md).

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
| [spec/development.md](spec/development.md) | Development workflow (brainstorm through merge) and branching model |
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

Spec evolution happens here. Open a PR to:

- Update default framework choices
- Add or revise patterns
- Document new gotchas
- Refine the bootstrap procedure

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Spec version

`2.0.0`. First spec-only release. The prior template lives in git history.

## License

[MIT](LICENSE) &copy; Adam Woo
