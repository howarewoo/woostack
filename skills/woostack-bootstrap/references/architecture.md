# Architecture

Reference monorepo layout for new projects bootstrapped from this spec. AI agents should reproduce this structure unless the project explicitly diverges.

## Layout

```
<project-root>/
├── apps/                      Deployable units (unscoped names)
│   ├── web/                   Next.js (App Router)
│   ├── landing/               Next.js marketing site (optional)
│   ├── mobile/                Expo + React Native
│   └── api/                   Hono + oRPC
├── packages/
│   ├── features/              Business logic packages (one per feature)
│   │   └── <feature>/
│   │       ├── contracts/     Zod schemas (oRPC contracts)
│   │       ├── routers/       oRPC routers
│   │       ├── procedures/    Business logic called by handlers
│   │       ├── components/    Internal UI
│   │       ├── surfaces/      Public UI entry points (*Surface.tsx)
│   │       ├── layouts/       Public layout components (*Layout.tsx)
│   │       └── schemas/       Domain schemas
│   └── infrastructure/        Shared utilities (scoped @infrastructure/*)
│       ├── api-client/        oRPC client factories, shared base schemas
│       ├── flags/             Vercel Flags SDK definitions + identify()
│       ├── navigation/        Platform-agnostic Link + useNavigation
│       ├── ui/                Design tokens, cn(), shared theme CSS
│       ├── ui-web/            Shared shadcn/ui components
│       ├── utils/             Cross-platform helpers
│       └── typescript-config/ Shared tsconfig presets
├── .github/workflows/         CI pipelines
├── pnpm-workspace.yaml        Workspace + catalog
├── turbo.json                 Turborepo pipeline
├── biome.json                 Lint + format
└── package.json               Root scripts only
```

## Package tiers

Three tiers with strict import direction. Violations break the architecture.

```
Apps  →  Features  →  Infrastructure
```

| Tier | Path | Naming | Exports | May import |
|---|---|---|---|---|
| **Apps** | `apps/*` | unscoped (`web`, `api`) | n/a (deployables) | Features (via surfaces/layouts only), Infrastructure |
| **Features** | `packages/features/*` | unscoped, default exports | Surfaces + Layouts only | Infrastructure |
| **Infrastructure** | `packages/infrastructure/*` | `@infrastructure/*`, named exports | Anything intentionally public | Other infrastructure |

**Exemption:** `apps/api` may import feature `contracts/` and `routers/` directly to compose the master oRPC router. This is the only app-level bypass of the Surfaces/Layouts rule.

## Naming

| Element | Convention | Example |
|---|---|---|
| Components | PascalCase, default export, one per file | `UserCard.tsx` |
| Hooks | camelCase, `use` prefix | `useUserList.ts` |
| Helpers | camelCase | `formatCurrency.ts` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_ATTEMPTS` |
| Types/Interfaces | PascalCase | `UserProfile` |
| Schemas | PascalCase | `UserSchema` |
| Procedures | camelCase verbs | `createUser.ts`, `listUsers.ts` |
| oRPC contracts | `{feature}Contract.ts` | `usersContract.ts` |
| oRPC routers | `{feature}ORPCRouter.ts` | `usersORPCRouter.ts` |
| Surface components | `*Surface.tsx` suffix | `UserListSurface.tsx` |
| Layout components | `*Layout.tsx` suffix | `DashboardLayout.tsx` |

`.ts` by default. `.tsx` only when file contains JSX.

## File organization inside a feature

Each feature package follows the same directory shape. Empty dirs are omitted; needed dirs match these names exactly.

```
packages/features/<feature>/
├── src/
│   ├── contracts/        Zod schemas for oRPC i/o
│   ├── routers/          oRPC router definitions
│   ├── procedures/       Business logic
│   ├── components/       Internal-only UI (not exported)
│   ├── surfaces/         Public UI entry points
│   ├── layouts/          Public layout components
│   └── schemas/          Internal domain schemas
├── package.json
└── tsconfig.json
```

## Dependency catalog

All shared dependency versions live in `pnpm-workspace.yaml` `catalog:`. Package `package.json` files reference `catalog:` instead of literal versions. Catalog versions are **exact** (no `^` or `~`) for deterministic installs.

See [frameworks.md](frameworks.md) for which dependencies belong in the catalog.

## Size limits

- Non-test source files: 500 lines max.
- Test files (`*.test.*`, `*.spec.*`, `__tests__/`): exempt.

Files approaching the limit signal a refactor opportunity; split before crossing.
