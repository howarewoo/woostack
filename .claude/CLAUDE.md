# CLAUDE.md

This file provides guidance to Claude Code when working with this monorepo template.

## Project Overview

See [eng-constitution.md](../eng-constitution.md) for foundational rules. The constitution is **binding** and supersedes other instructions.

## Prerequisites

- **pnpm 10.29.3** (enforced via `packageManager` in root `package.json`)
- **Node.js 22** (CI pins v22; compatible with ES2022 target)

## Commands

```bash
pnpm install          # Install dependencies
pnpm dev              # Start all apps (web:3000, api:3001, landing:3002, mobile:8081)
pnpm build            # Build all packages/apps via Turborepo
pnpm test             # Run tests across all packages
pnpm test:changed     # Run tests for packages changed since last commit
pnpm test:e2e         # Run Playwright E2E tests
pnpm typecheck        # Type check all packages
pnpm lint             # Lint via Biome
pnpm lint:fix         # Auto-fix linting issues
pnpm format           # Format via Biome + sort package.json
pnpm format:unsafe    # Format + apply unsafe fixes (used by pre-commit)
pnpm pre-commit       # Install, format, typecheck, react-doctor, and test changed files
pnpm clean            # Remove build artifacts and node_modules
pnpm reset            # Deep clean: node_modules, .next, dist, .turbo, untracked files
pnpm gencode          # Generate Router types from apps/api into @infrastructure/api-client

# Run a single package
pnpm --filter web dev
pnpm --filter api dev
pnpm --filter @infrastructure/navigation test

# Landing page
pnpm --filter landing dev

# Mobile platform targets
pnpm --filter mobile ios
pnpm --filter mobile android
pnpm --filter mobile web
```

## Architecture

**Monorepo with three package types.** Apps use unscoped names (`web`, `api`, `landing`, `mobile`); infrastructure uses `@infrastructure/*` scope.
- **Apps** (`apps/*`): Deployable applications
  - `apps/web` — Next.js 16 (App Router) + React Compiler + shadcn/ui (Base UI) + Tailwind CSS (port 3000)
  - `apps/landing` — Next.js 16 marketing/landing page consuming shared UI components (port 3002)
  - `apps/mobile` — Expo SDK 54 + React Native 0.81 + UniWind + react-native-reusables
  - `apps/api` — Hono + oRPC API server (port 3001)
- **Features** (`packages/features/*`): Standalone business feature packages; own their contracts (`contracts/`), routers (`routers/`), and procedures (`procedures/`); can only import from infrastructure
- **Infrastructure** (`packages/infrastructure/*`): Shared utilities; can be used anywhere
  - `@infrastructure/api-client` — oRPC client utilities (`createApiClient`, `createTypedApiClient`), generated Router type, and shared base schemas
  - `@infrastructure/navigation` — Platform-agnostic navigation (Link, useNavigation, NavigationProvider)
  - `@infrastructure/ui` — Shared design tokens, CSS utilities (`cn()`, `tokens`)
  - `@infrastructure/ui-web` — Shared shadcn/ui components (Button, Card, etc.) for web apps
  - `@infrastructure/utils` — Cross-platform utility functions
  - `@infrastructure/typescript-config` — Shared TypeScript configs (base, library, nextjs, react-native)

## Key Patterns

### oRPC (Type-Safe API)

Feature packages own their contracts (`contracts/`) and routers (`routers/`). `apps/api` imports feature routers and composes the master router. `@infrastructure/api-client` provides both generic client utilities and pre-typed wrappers using a generated `Router` type. Apps import from `@infrastructure/api-client` — they never depend on `apps/api` directly. The `Router` type is generated via `pnpm gencode`. Query integration uses `@orpc/tanstack-query`.

**Gotcha**: oRPC v1 routers are plain object literals — do not wrap with `.router()`. The `@orpc/react-query` package was renamed to `@orpc/tanstack-query`.

```typescript
// Feature package: packages/features/users/src/contracts/usersContract.ts
import { z } from "zod";
export const UserSchema = z.object({ id: z.string(), name: z.string() });

// Feature package: packages/features/users/src/routers/usersORPCRouter.ts
import { os } from "@orpc/server";
import { UserSchema } from "../contracts/usersContract";
const pub = os.$context<{ requestId?: string }>();
export const usersRouter = {
  list: pub.output(UserSchema.array()).handler(() => { /* ... */ }),
};

// API app: apps/api/src/router.ts
import { usersRouter } from "@features/users/src/routers/usersORPCRouter";
export const router = { users: usersRouter };
export type Router = typeof router;

// Consuming app (web/mobile)
import { createTypedApiClient, createTypedOrpcUtils } from "@infrastructure/api-client";
const client = createTypedApiClient("http://localhost:3001/api");
const orpc = createTypedOrpcUtils(client);
const { data } = useQuery(orpc.users.list.queryOptions());
```

### Navigation

Feature packages must never import `next/navigation` or `expo-router` directly. Use `@infrastructure/navigation` instead:
- `<Link href="/path">` for declarative navigation
- `useNavigation()` for imperative (`navigate`, `replace`, `back`)
- Each app provides its adapter via `NavigationProvider` (see `apps/web/lib/navigation.tsx`, `apps/mobile/lib/navigation.tsx`)

### Cross-Platform UI

- **Web**: shadcn/ui components (Base UI primitives, `base-vega` style) + Tailwind CSS
- **Mobile**: react-native-reusables + UniWind
- **Shared**: Design tokens and CSS utilities in `@infrastructure/ui`; both platforms consume the same theme
- **Tailwind v4**: CSS-first config (no `tailwind.config.ts`); web uses `@tailwindcss/postcss`; mobile uses `uniwind/metro`
- **Web CSS**: `apps/web/app/globals.css` imports from `@infrastructure/ui/globals.css` — single source of truth
- **Mobile CSS**: `apps/mobile/global.css` hardcodes theme tokens (UniWind on RN doesn't support CSS `var()` indirection in `@theme` blocks); light/dark colors use `@layer theme { :root { @variant light {} @variant dark {} } }` — both variants are required
- **Adding components**: `pnpx shadcn@latest add <component>` from `apps/web/` or `apps/landing/`; `components.json` configures style (`base-vega`), utils alias (`@infrastructure/ui`), and icon library (`lucide`). To share a component across web apps, move it from `apps/<app>/components/ui/` to `packages/infrastructure/ui-web/src/components/` and re-export from the barrel index

**Note**: Mobile web export is enabled — Expo SDK 54 ships with RN 0.81, satisfying UniWind's `react-native>=0.81.0` requirement.

**New web app checklist**: When creating a new Next.js app that consumes `@infrastructure/ui-web`: (1) add `"@infrastructure/ui-web": "workspace:*"` to dependencies, (2) add `"@infrastructure/ui-web"` to `transpilePackages` in `next.config.ts`, (3) add `@source "../node_modules/@infrastructure/ui-web/src";` in `app/globals.css`.

**Gotcha**: Tailwind v4 does not auto-scan `@infrastructure/ui-web` for class names. Each consuming web app must add `@source "../node_modules/@infrastructure/ui-web/src";` in its `app/globals.css` (path relative to the CSS file) to ensure component styles are compiled.

**Gotcha**: Do not set `config.resolver.unstable_conditionNames` in `apps/mobile/metro.config.js` — it overrides Metro's platform-aware defaults and breaks UniWind's web resolver (causes `createOrderedCSSStyleSheet` resolution failures).

**Gotcha**: Mobile theme tokens in `apps/mobile/global.css` are hardcoded HSL values that must stay in sync with `packages/infrastructure/ui/src/globals.css` `:root` / `.dark` blocks. When updating the shared theme, update both files. UniWind requires both `@variant light` and `@variant dark` inside `@layer theme` — putting color tokens only in `@theme` without a `@variant light` block causes always-dark rendering.

**Gotcha**: Do not use `space-y-*` or `space-x-*` in mobile components — they compile to CSS logical properties (`margin-block-start`/`margin-block-end`) which React Native does not support. Use `gap-*` on flex containers instead.

**Gotcha**: React Navigation's default `Stack` header does not use UniWind theme tokens. Use `headerShown: false` with a custom header component styled via UniWind classes and `useSafeAreaInsets()` for status bar spacing.

### Dependencies

Use pnpm catalog for shared dependency versions. All versions must be exact (no `^` or `~`):
```yaml
# pnpm-workspace.yaml catalog:
react: "19.1.0"
```
```json
// package.json
"dependencies": { "react": "catalog:" }
```

**Gotcha**: React is pinned to exact `19.1.0` because React Native 0.81's bundled renderer (`react-native-renderer@19.1.0`) performs a strict equality check against the installed React version. Using `^19.2.0` causes a hard runtime crash on iOS.

**Gotcha**: Zod v4 changed string validation methods: `z.string().email()` → `z.email()`, `z.string().datetime()` → `z.iso.datetime()`. Other APIs (`z.object()`, `z.string()`, `z.string().min()`, `z.infer<>`, `.array()`, `.nullable()`) are unchanged.

**Gotcha**: `pnpm build` runs `pnpm self-update && turbo build` — this upgrades pnpm before building. If local builds behave differently from CI, check whether `pnpm --version` still matches the `packageManager` field in root `package.json`.

**Gotcha**: pnpm 10 disables dependency lifecycle scripts by default. If a new dependency has a `postinstall` script (e.g., `esbuild`, `prisma`, native modules), add it to `pnpm.onlyBuiltDependencies` in the root `package.json` or it will silently fail to build.

**Gotcha**: After changing any feature router or `apps/api/src/router.ts`, run `pnpm gencode` to regenerate the Router type in `@infrastructure/api-client`. The generated file (`packages/infrastructure/api-client/src/generated/router-types.d.ts`) must be committed — it is not regenerated during build or CI.

## Conventions

- **Never commit directly to `main` or `staging`** — all new code must go on a feature branch targeting `staging` via PR. Use `gt create` to start a new branch from `staging`.
- **Graphite** (`gt`) is the primary Git CLI — always prefer `gt` over raw `git` for branch and commit operations:
  - `gt create -m "msg"` instead of `git checkout -b` + `git commit`
  - `gt modify -m "msg"` instead of `git commit --amend`
  - `gt submit` instead of `git push` (creates PR targeting `staging`)
  - `gt log` instead of `git log` (shows stack context)
  - Only use raw `git` for operations `gt` doesn't cover (e.g., `git status`, `git diff`, `git stash`)
- **Biome**: 100-char line width, double quotes, semicolons, ES5 trailing commas
- **pnpm** exclusively (not npm/yarn); `pnpx` instead of `npx`
- `.ts` by default; `.tsx` only when file contains JSX
- Infrastructure packages use **named exports**; feature packages use **default exports**
- No `any` or `unknown` — use explicit, safely narrowed types
- Max 500 lines per non-test source file
- TDD methodology (see constitution Principle VIII)
- All user-facing components and procedures need JSDoc comments
- React Compiler is enabled in `apps/web` and `apps/landing`

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every PR:
1. `biome ci` — lint + format check
2. `pnpm turbo build` — build all packages
3. Verify generated code is up to date (`pnpm gencode` + `git diff --exit-code`)
4. `pnpm test:changed` — tests for changed packages only

**Note**: CI does not run `typecheck` — run `pnpm typecheck` locally before pushing.

**Dependabot** (`.github/dependabot.yml`) runs weekly scans for npm and GitHub Actions updates. PRs target `staging` (not `main`).

**Community files**: Issue templates (bug report, feature request), PR template, and `CONTRIBUTING.md` guide new contributors.

## Testing

- **Framework**: Vitest (unit/integration), Jest via `jest-expo` (mobile/React Native), Playwright (E2E)
- **Test locations**: in sibling `__tests__/` directories (e.g., `src/auth/__tests__/useAuth.test.ts`)
- Run `pnpm test` before committing; new procedures require tests
- Run per-app: `pnpm --filter web test`, `pnpm --filter landing test`, `pnpm --filter api test`, `pnpm --filter mobile test`

**Gotcha**: Vitest 4 requires `function` expressions (not arrow functions) in `vi.fn()` when the mock is used as a constructor with `new`. Arrow functions are not constructable — use `vi.fn(function () { return { ... }; })`.
