# Bootstrap

How an AI agent (or human) uses this spec to spin up a new project. The spec is the source of truth; the agent fills in the latest framework versions.

## Inputs the agent needs

The skill is invoked as `/woo-stack <goal>` — a plain-language description of what to build. Derive the following from the goal and confirm them in step 0; don't require the user to spell them out:

1. **Project name** (used for repo, root `package.json`, default app names).
2. **Surfaces required** — any subset of: `web`, `landing`, `mobile`, `api`.
3. **Initial features** — list of feature names to scaffold (e.g. `recipes`, `users`). Can be empty.

Everything else — hosting, data layer, auth, capabilities, repo host — is resolved with the user in step 0, not assumed.

## Steps

### 0. Interpret the goal, then confirm decisions with the user

Read the `/woo-stack` goal and infer a recommended shape — name, surfaces, candidate features, likely capabilities. Then walk the user through [decisions.md](decisions.md), presenting every relevant decision **pre-filled with the goal-aware recommendation** alongside its default and alternatives. Get explicit sign-off, resolve the genuine forks (e.g. API host), and treat capabilities (billing, email, flags, observability, …) as opt-in. **Do not scaffold any decision the user has not confirmed**, and do not silently apply a default. If the user defers ("use the defaults"), state the full set you'll apply so they can object first.

### 1. Read the spec

Load these files into context first:

- [architecture.md](architecture.md)
- [frameworks.md](frameworks.md)
- [infrastructure.md](infrastructure.md)
- [patterns.md](patterns.md)
- [development.md](development.md)

These define the binding rules. Do not deviate without a documented reason.

### 2. Resolve framework versions

**Always query the registry — never use a version from memory.** Your training data is stale by the time you run; every version you "remember" is a guess that will drift the project from current releases. Resolve live, every time.

For each catalog entry in [frameworks.md](frameworks.md):

1. Query the latest version from the registry (`npm view <pkg> version` for latest stable; `npm view <pkg> dist-tags` when you need a specific channel). Do not skip this for packages you think you know.
2. Cross-check against the **known gotchas** list — some packages (notably `react` for RN compatibility) must match a specific peer version.
3. Write the resolved versions into `pnpm-workspace.yaml` `catalog:` as exact strings.

### 3. Create repo skeleton

```
<project>/
├── apps/                     # only the surfaces requested
├── packages/
│   ├── features/             # one dir per requested feature
│   └── infrastructure/
│       ├── api-client/
│       ├── navigation/
│       ├── ui/
│       ├── ui-web/           # only if web or landing requested
│       ├── utils/
│       └── typescript-config/
├── .github/workflows/ci.yml
├── .gitignore
├── biome.json
├── package.json              # root scripts only
├── pnpm-workspace.yaml       # workspaces + catalog
├── tsconfig.json             # extends infrastructure/typescript-config
└── turbo.json
```

Match the layout in [architecture.md](architecture.md) exactly. Omit folders for surfaces not requested.

### 4. Configure root tooling

- `package.json` — `packageManager: "pnpm@<exact>"`, root scripts: `dev`, `build`, `test`, `test:changed`, `test:e2e`, `typecheck`, `lint`, `format`.
- `pnpm-workspace.yaml` — workspaces `apps/*` and `packages/**/*`, catalog populated.
- `turbo.json` — pipelines for `build`, `test`, `dev` (no cache for `dev`).
- `biome.json` — 100-char width, double quotes, semicolons, ES5 trailing commas.
- `tsconfig.json` — extends `@infrastructure/typescript-config/base.json`.
- `.gitignore` — covers `node_modules`, `.next`, `.expo`, `.turbo`, `dist`, `.env*` (except `.env.example`).

### 5. Scaffold infrastructure packages

For each `@infrastructure/*` package:

1. `package.json` with `name`, `private: true`, `exports`, `main` pointing at `src/index.ts`.
2. `tsconfig.json` extending the relevant preset (`library`, `nextjs`, or `react-native`).
3. `src/index.ts` re-exporting public surface.

**Required infrastructure contents:**

- `api-client` — `createApiClient<Router>(baseUrl)`, `createOrpcUtils(client)`, shared base Zod schemas.
- `flags` — every `flag(...)` definition (Vercel Flags SDK), the shared `identify()` reading Supabase session, and the chosen adapter wiring. See [infrastructure.md#feature-flags](infrastructure.md#feature-flags). Scaffold this for every project regardless of surface mix — it is a standing package; leave the definitions empty (just `identify()` + adapter wiring) until the first flag is added.
- `navigation` — `<Link>`, `useNavigation()`, `NavigationProvider`, platform-agnostic types.
- `ui` — design tokens (`tokens.ts`), `cn()` helper, shared `globals.css` with theme.
- `ui-web` — shadcn components shared across web apps; barrel exports.
- `utils` — cross-platform helpers (no React, no Node-only APIs).
- `typescript-config` — `base.json`, `library.json`, `nextjs.json`, `react-native.json`.

### 6. Scaffold apps

Run framework CLIs for the requested surfaces. Then **strip generated boilerplate** that conflicts with the spec (e.g. default Next.js `app/page.tsx`, default Expo welcome screen) and replace with minimal placeholders.

| App | Bootstrap command | Post-bootstrap edits |
|---|---|---|
| `web` | `pnpx create-next-app@latest --ts --app --tailwind --src-dir false` | Wire `<NavigationProvider>`, add `@source` for `ui-web`, enable React Compiler in `next.config.ts`. |
| `landing` | Same as `web` | Same. |
| `mobile` | `pnpx create-expo-app@latest` then add UniWind | Configure Metro for UniWind, hardcode theme HSL in `global.css`, add `<NavigationProvider>`. |
| `api` | Manual: Hono + oRPC scaffold | `src/router.ts` exporting `Router`, `src/index.ts` running Hono on port `3001`. |

Each app `package.json` references shared deps as `"catalog:"`.

### 7. Scaffold features (if any)

For each feature in the input:

```
packages/features/<feature>/
├── src/
│   ├── contracts/<feature>Contract.ts     # empty Zod schema stub
│   ├── routers/<feature>ORPCRouter.ts     # empty router stub
│   ├── procedures/                        # empty
│   ├── components/                        # empty
│   ├── surfaces/                          # empty
│   ├── layouts/                           # empty
│   └── schemas/                           # empty (internal domain schemas)
├── package.json
└── tsconfig.json
```

Wire the router into `apps/api/src/router.ts` if `api` is in the surfaces list.

### 8. CI workflow

Write `.github/workflows/ci.yml` per [infrastructure.md](infrastructure.md#cicd). Jobs: `biome ci`, `pnpm turbo build`, `pnpm test:changed`. Pin Node + pnpm versions. Do **not** add a `typecheck` job — it is a local-only script (step 4); CI relies on `build` to catch type errors. See [infrastructure.md](infrastructure.md#cicd).

### 9. Verify

Before declaring done:

```bash
pnpm install
pnpm typecheck
pnpm build
pnpm test
pnpm dev   # spot-check each app boots on its expected port
```

Fix every failure. A bootstrap that doesn't pass these isn't done.

### 10. Initialize repo

```bash
git init
git add .
git commit -m "chore: initial bootstrap from spec"
gh repo create <project> --private --source=. --push
```

Add Vercel project link (`vercel link`) for any web/api surfaces. Pull initial env scaffold (`vercel env pull`).

### 11. Hand off

Write a project-local `README.md` documenting:

- Which surfaces were scaffolded
- Any spec deviations and why
- Run/build/test commands
- Hosting + env setup status

The project-local docs should **reference**, not duplicate, the spec. If a rule moves into the project's own context (e.g. an organization-wide override), document the divergence explicitly.

## Maintenance

When this spec changes:

- New projects pick up changes at their next bootstrap.
- Existing projects do **not** auto-update — treat spec changes as advisory upgrades they opt into.
- Breaking changes to the spec (e.g. removing a required pattern) should bump the `SPEC_VERSION` recorded in [SKILL.md](../SKILL.md) so downstream projects can detect drift.
