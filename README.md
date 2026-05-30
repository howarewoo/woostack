# woo-stack

**An installable skill for bootstrapping AI-built web, mobile, and API projects.**

Not a template. It's the rules an AI coding agent follows when scaffolding a fresh full-stack monorepo: frameworks, architecture, infrastructure, patterns — resolved at the latest versions every time.

## Why a skill instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a snapshot that was already stale by the time you cloned it. Coding agents are good enough now that scaffolding from scratch is cheap. What's expensive is *deciding* what to scaffold. This skill holds those decisions so the agent doesn't re-litigate them every time someone wants a new project.

## Install

```bash
npx skills add howarewoo/woo-stack
```

This installs the `woo-stack` skill (`skills/woo-stack/SKILL.md` plus its `references/`) into your agent's skill directory and records it in `skills-lock.json`. Once installed, the agent loads it automatically when you ask to bootstrap a new project.

## Use

Invoke the skill with `/woo-stack <goal>` — a plain-language description of what to build. It infers a recommended architecture from the goal, walks you through every decision (confirming defaults, resolving forks, asking about opt-in capabilities), then scaffolds.

```
/woo-stack create a new mobile app for cataloging recipes
/woo-stack a SaaS dashboard with a marketing site and a billing API
```

The skill entry point is [`skills/woo-stack/SKILL.md`](skills/woo-stack/SKILL.md); the binding rules live in [`skills/woo-stack/references/`](skills/woo-stack/references/).

## What it defines

| Reference | What it defines |
|---|---|
| [decisions.md](skills/woo-stack/references/decisions.md) | Decision catalog the agent walks the user through before scaffolding |
| [bootstrap.md](skills/woo-stack/references/bootstrap.md) | Step-by-step bootstrap procedure for AI agents |
| [architecture.md](skills/woo-stack/references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [frameworks.md](skills/woo-stack/references/frameworks.md) | Recommended frameworks per layer, catalog protocol, known gotchas |
| [infrastructure.md](skills/woo-stack/references/infrastructure.md) | Hosting, CI/CD, env, observability, auth, data layer |
| [patterns.md](skills/woo-stack/references/patterns.md) | oRPC contracts, TanStack Query, RSC, navigation, TDD, feature exposure |
| [development.md](skills/woo-stack/references/development.md) | Development workflow (brainstorm → merge) and branching model |

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

Versions are resolved at bootstrap time. See [frameworks.md](skills/woo-stack/references/frameworks.md).

## Contributing

The skill evolves here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap procedure. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Spec version

`2.0.0`. First spec-only release. The prior template lives in git history.

## License

[MIT](LICENSE) &copy; Adam Woo
