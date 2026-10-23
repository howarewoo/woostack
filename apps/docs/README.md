# woostack docs site

This documentation site uses Fumadocs and Next.js. It includes authored guides in `content/docs/`,
a landing page, and reference pages generated from `../../skills/*/SKILL.md`.
The generated pages are ignored by Git. Edit the skill source when its reference page needs a change.

## Local development

Run these commands from the repository root:

```bash
pnpm install --frozen-lockfile
pnpm dev --filter=docs      # generates skill pages, then starts Next on port 3000
```

Run `pnpm build --filter=docs` to generate skill pages and build the Cloudflare Worker through Turborepo.
`pnpm --filter docs test` checks generator rendering, frontmatter, local asset links (including
angle-bracket destinations), and installation discovery with Node's built-in test runner (`node --test`).
It does not invoke a planner, model, or GitHub. `pnpm lint --filter=docs` and `pnpm format:check --filter=docs`
run Oxlint and Oxfmt checks. `pnpm types:check --filter=docs` checks Fumadocs generation and TypeScript types.
`pnpm verify --filter=docs` runs test, typechecking, lint, and formatting checks through Turborepo's
task graph without duplicate execution; direct `pnpm --filter docs run verify` delegates
to the task graph without duplicate execution.
Both `pnpm verify --filter=docs --force` and `pnpm --filter docs run verify --force`
bypass cached results and execute the docs checks freshly.

Oxlint configuration in `.oxlintrc.json` registers `@shadcn/lint` via `jsPlugins` following upstream
SETUP.md conservative registration-only policy: no new rules or presets are enabled, and discovery
settings are scoped locally. Configure custom rules or overrides under `.oxlintrc.json` as needed.

## Deploy to Cloudflare Workers

The app uses the OpenNext Cloudflare adapter. `wrangler.jsonc` owns the `woostack-docs`
Worker, entrypoint, static assets, and Preview configuration.

1. From the repository root, install dependencies and run the default build:

   ```bash
   pnpm install --frozen-lockfile
   pnpm run build
   ```

   The docs build generates skill pages, builds Next.js once, and creates
   `apps/docs/.open-next/worker.js` and its assets. It also stages the prerendered
   cache and writes Wrangler discovery files under `.wrangler/deploy/` at the root
   and in the app. Both point to the app-owned configuration; Turborepo caches them
   with the Worker bundle. Use `pnpm build --filter=docs` to skip the design app.

2. Check the built Worker locally:

   ```bash
   npx wrangler dev
   ```

   Open the URL printed by Wrangler. Check `/docs/getting-started`, search,
   `/docs/getting-started.md`, and `/llms.txt`. Wrangler runs the Worker locally;
   `pnpm dev --filter=docs` continues to use the Next.js development server.
   To check deployment packaging without publishing, run `npx wrangler deploy --dry-run`.

3. Connect the repository to the `woostack-docs` Worker in Cloudflare Workers Builds.
   Configure both **Production** and **Previews Base** under **Settings > Builds**:

   | Setting | Value |
   | --- | --- |
   | Root directory | `/` (repository root) |
   | Build command | `pnpm run build` |
   | Production deploy command | `npx wrangler deploy` |
   | Previews Base preview command | `npx wrangler preview` |
   | Build variable | `NODE_VERSION=24.22.1` |

   These are the default build and deployment commands. The root installs the pinned
   Wrangler CLI so `npx` does not download an untracked version. Build commands also
   work from `apps/docs`; the generated redirect there resolves the same configuration.
   Dependency installation must use the root workspace lockfile, including development
   dependencies. The checkout must include `skills/` and the rest of the repository.
   Leave build watch paths unrestricted unless they also cover skills, shared assets,
   and root workspace configuration.

For a manual release, authenticate with `npx wrangler login`, then run
`npx wrangler deploy` after building. `npx wrangler preview` creates a branch Preview
without promoting it to production. `pnpm --filter docs run preview` is a local server,
not a remote Preview deployment. In external CI, store
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the CI secret store. Workers Builds
provides deployment authentication through its configured API token.
Custom domains and TLS are managed in the Cloudflare dashboard. Use Cloudflare's
deployment rollback controls to restore a previous version.

Prerendered pages use OpenNext's read-only Workers Static Assets cache. No R2 bucket,
D1 database, Durable Objects, service bindings, or runtime application secrets are needed for the current
site. Rebuild and deploy when content changes. Before adding ISR or on-demand revalidation,
replace this cache with a writable backend following the
[OpenNext caching guide](https://opennext.js.org/cloudflare/caching).

## Deploy to Vercel

Use these project settings:

- Root directory: `apps/docs/`.
- Include files outside the root directory in the build step: on. The generator reads
  `../../skills/*/SKILL.md`; the build needs access to the repository outside `apps/docs/`.
- Framework preset: Next.js.
- Install command: `cd ../.. && pnpm install --frozen-lockfile`, using the root workspace and lockfile.
- Build command: `cd ../.. && pnpm --filter docs run build:next`, which generates skill pages and builds Next.js without Worker packaging.

Use the standard Next.js deployment. The configuration does not enable a static export.
Check Vercel's current plan limits before choosing a hosting plan.

## How content is generated

`scripts/gen-skills.mjs` reads the name and description from each skill's YAML header and creates
a Fumadocs page. It converts agent-only tags such as `<HARD-GATE>` into callouts, changes links to
other skills into site routes, and points other repository links to GitHub.

The generator adds a "View source on GitHub" link and writes
`content/docs/skills/<name>.mdx` plus its `meta.json` navigation file. Both
`pnpm dev --filter=docs` and `pnpm build --filter=docs` regenerate these files. Do not edit them by hand.
