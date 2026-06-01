# woo-stack

**An installable collection of opinionated skills for building software — bootstrap, build, review, address review feedback.**

Not a template. It's the rules an AI coding agent follows when scaffolding a fresh full-stack monorepo: frameworks, architecture, infrastructure, patterns — resolved at the latest versions every time.

## Why a skill instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a snapshot that was already stale by the time you cloned it. Coding agents are good enough now that scaffolding from scratch is cheap. What's expensive is *deciding* what to scaffold. This skill holds those decisions so the agent doesn't re-litigate them every time someone wants a new project.

## Install

```bash
npx skills add howarewoo/woo-stack
```

This installs the woo-stack **collection** (skills: woo-stack-bootstrap, woo-stack-build, woo-stack-review, woo-stack-address-comments) into your agent's skill directory and records it in `skills-lock.json`.

## Commands

| Command | What it does |
|---|---|
| `/woo-stack-bootstrap <goal>` | Scaffold a new web/mobile/API monorepo at latest versions. |
| `/woo-stack-build <goal>` | Feature loop: brainstorm → HTML spec → grill → plan → execute. |
| `/woo-stack-review [PR#]` | Parallel review swarm + skeptical validation; posts a batched GitHub review. |
| `/woo-stack-address-comments [PR#]` | Address unresolved review threads autonomously. No merge. |

Artifacts land under `.woo-stack/` (HTML specs, markdown plans, review config/memory).

## What it defines

| Reference | What it defines |
|---|---|
| [decisions.md](skills/woo-stack-bootstrap/references/decisions.md) | Decision catalog the agent walks the user through before scaffolding |
| [bootstrap.md](skills/woo-stack-bootstrap/references/bootstrap.md) | Step-by-step bootstrap procedure for AI agents |
| [architecture.md](skills/woo-stack-bootstrap/references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [frameworks.md](skills/woo-stack-bootstrap/references/frameworks.md) | Recommended frameworks per layer, catalog protocol, known gotchas |
| [infrastructure.md](skills/woo-stack-bootstrap/references/infrastructure.md) | Hosting, CI/CD, env, observability, auth, data layer |
| [patterns.md](skills/woo-stack-bootstrap/references/patterns.md) | oRPC contracts, TanStack Query, RSC, navigation, TDD, feature exposure |
| [development.md](skills/woo-stack-bootstrap/references/development.md) | Development workflow and branching model |

## Default stack

| Layer | Default |
|---|---|
| Web / Landing | Next.js (App Router) + React Compiler + shadcn/ui |
| Mobile | Expo + React Native + react-native-reusables + UniWind |
| API | Hono + oRPC |
| Data | TanStack Query + Zod + Supabase (Postgres, Auth, Storage) |
| Styling | Tailwind CSS (CSS-first) with a shared theme |
| Build | Turborepo + pnpm catalog |
| Lint/format | Biome |
| Testing | Vitest, Jest (RN), Playwright |
| Hosting | Vercel (web + api) + Expo EAS (mobile) |

Versions are resolved at bootstrap time. See [frameworks.md](skills/woo-stack-bootstrap/references/frameworks.md).

**woo-review is now first-party here; the standalone `howarewoo/woo-review` repo is deprecated.**

## Contributing

The skill evolves here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap procedure. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Spec version

`2.0.0`. First spec-only release. The prior template lives in git history.

## License

[MIT](LICENSE) &copy; Adam Woo
