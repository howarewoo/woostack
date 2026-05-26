# Frameworks

Default framework selections for new projects. AI agent should install **latest stable** at bootstrap time unless a known incompatibility forces a pin (call those out explicitly).

## Stack at a glance

| Layer | Default | Role |
|---|---|---|
| Package manager | **pnpm** (latest 10.x) | Workspaces + catalog protocol |
| Monorepo build | **Turborepo** | Cached build pipeline |
| Language | **TypeScript** (latest) | Strict mode; no `any`/`unknown` |
| Lint + format | **Biome** | Replaces ESLint + Prettier |
| Web framework | **Next.js** (App Router) | Server Components, React Compiler |
| Mobile framework | **Expo** + React Native | iOS / Android / web via Expo Router |
| API framework | **Hono** | Lightweight web server |
| RPC layer | **oRPC** | End-to-end typed contracts |
| Data fetching | **TanStack Query** + `@orpc/tanstack-query` | Client state + cache |
| Validation | **Zod** | Contract schemas, runtime validation |
| Web styling | **Tailwind CSS** + **shadcn/ui** (Base UI primitives) | CSS-first config |
| Mobile styling | **Tailwind CSS** via **UniWind** + **react-native-reusables** | Same theme as web |
| Unit/integration tests | **Vitest** | Everywhere except React Native |
| Mobile tests | **Jest** via `jest-expo` | Metro compatibility |
| E2E tests | **Playwright** | Web flows |
| Branch management | **Graphite** (`gt`) | Stacked PRs |

## Installation directives

When bootstrapping, the agent should:

1. **Pin only when necessary.** Use `latest` for each catalog entry unless a documented incompatibility (see gotchas below) forces an exact pin.
2. **Use exact versions in the catalog.** No `^`/`~`. Run `pnpm add -E` or write the exact resolved version after install.
3. **Catalog every shared dep.** Single source of truth in `pnpm-workspace.yaml`.
4. **Enable `pnpm.onlyBuiltDependencies`** for any package that needs a `postinstall` (e.g. `esbuild`, native modules) — pnpm 10 disables lifecycle scripts by default.

## Required catalog entries

Minimum set the bootstrap should populate. Specific versions resolved at install time.

```yaml
# pnpm-workspace.yaml
catalog:
  # React (mobile pin: see gotcha)
  react: <exact>
  react-dom: <exact>
  "@types/react": <exact>
  "@types/react-dom": <exact>

  # Next.js
  next: <exact>

  # Expo + React Native
  expo: <exact>
  react-native: <exact>
  expo-router: <exact>
  uniwind: <exact>
  react-native-gesture-handler: <exact>
  react-native-reanimated: <exact>
  react-native-safe-area-context: <exact>
  react-native-screens: <exact>
  react-native-web: <exact>

  # API
  hono: <exact>
  "@orpc/server": <exact>
  "@orpc/client": <exact>
  "@orpc/tanstack-query": <exact>
  "@tanstack/react-query": <exact>
  zod: <exact>

  # Styling
  tailwindcss: <exact>
  "@tailwindcss/postcss": <exact>
  postcss: <exact>
  "@base-ui/react": <exact>
  class-variance-authority: <exact>
  clsx: <exact>
  tailwind-merge: <exact>
  lucide-react: <exact>

  # Build
  typescript: <exact>
  "@babel/core": <exact>
  babel-plugin-react-compiler: <exact>
  "@vitejs/plugin-react": <exact>

  # Testing
  vitest: <exact>
  "@playwright/test": <exact>
  "@testing-library/react": <exact>
  "@testing-library/react-native": <exact>
  jest: <exact>
  jest-expo: <exact>
  jsdom: <exact>
```

## Known gotchas to respect at bootstrap

These are load-bearing constraints. Agent must verify each still applies against the current ecosystem before locking in versions.

- **React pin for RN.** React Native bundles its own renderer that does an exact-equality check on `react`'s version. Use the exact `react` version that the chosen `react-native` release ships against — do not float with `^`.
- **Zod v4 string API.** `z.string().email()` → `z.email()`. `z.string().datetime()` → `z.iso.datetime()`. Update contracts written against older docs.
- **oRPC v1 routers are plain objects.** Do **not** wrap with `.router()`. Old guides showing `os.router({...})` are pre-v1.
- **Package rename.** `@orpc/react-query` → `@orpc/tanstack-query`.
- **Tailwind v4 source scanning.** Each web app that consumes a shared component package must add `@source "../node_modules/<pkg>/src";` to its `app/globals.css` — Tailwind v4 does not auto-scan workspace packages.
- **Mobile theme tokens.** UniWind on React Native cannot resolve `var()` indirection in `@theme`. Hardcode HSL values in the mobile app's `global.css` and keep both `@variant light` and `@variant dark` blocks inside `@layer theme`.
- **Mobile spacing.** Avoid `space-y-*` / `space-x-*` (they compile to logical CSS properties RN cannot handle). Use `gap-*` on flex containers.
- **Metro resolver.** Do not set `config.resolver.unstable_conditionNames` — it overrides platform-aware defaults and breaks UniWind's web resolver.
- **Vitest `vi.fn` constructors.** When a mock is used with `new`, pass a `function` expression — arrow functions are not constructable.
- **pnpm self-update.** A `pnpm self-update && turbo build` pattern silently upgrades pnpm. Pin the `packageManager` field in root `package.json` and avoid auto-upgrades in CI scripts.

## Code style baselines

- Biome: 100-char line width, double quotes, semicolons, ES5 trailing commas.
- Files: `.ts` default, `.tsx` only when JSX present.
- Exports: named for infrastructure, default for features.
- No `any`, no `unknown` — narrow with schemas or generics.
- All user-facing components and procedures: JSDoc with purpose, inputs, outputs.
- Constants over magic literals (`MAX_RETRY_ATTEMPTS = 3`, not bare `3`).
