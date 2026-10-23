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

Run `pnpm build --filter=docs` to generate skill pages and build the site through Turborepo.
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

The app uses the OpenNext Cloudflare adapter. `wrangler.jsonc` owns the Worker name,
entrypoint, static assets, and bindings. Keep the dashboard Worker name set to `woostack`;
if renaming it, update both `name` and the `WORKER_SELF_REFERENCE` service in that file.

1. From the repository root, install dependencies and build the Worker:

   ```bash
   pnpm install --frozen-lockfile
   pnpm --filter docs run build:worker
   ```

   This runs skill generation and the Next.js build, then creates `.open-next/worker.js`
   and `.open-next/assets/` inside `apps/docs/`. Keep the root `pnpm-lock.yaml` as the only
   dependency lockfile. Do not run the OpenNext migration or install packages with npm during CI.

2. Check the built Worker locally:

   ```bash
   pnpm --filter docs run preview
   ```

   Open the URL printed by Wrangler. Check `/docs/getting-started`, search,
   `/docs/getting-started.md`, and `/llms.txt`. The preview uses the Workers runtime,
   while `pnpm dev --filter=docs` continues to use the Next.js development server.
   To check deployment packaging without publishing, run
   `pnpm --filter docs run deploy --dry-run`.

3. Connect the repository to the `woostack` Worker in Cloudflare Workers Builds and set:

   | Setting | Value |
   | --- | --- |
   | Root directory | `apps/docs` |
   | Build command | `pnpm run build:worker` |
   | Deploy command | `pnpm run deploy` |
   | Preview command, if non-production builds are enabled | `pnpm exec opennextjs-cloudflare upload` |
   | Build variable | `NODE_VERSION=24.22.1` |

   Dependency installation must use `pnpm install --frozen-lockfile` against the root
   workspace lockfile, including development dependencies. The checkout must include
   `../../skills/` and the rest of the repository. Leave build watch paths unrestricted
   unless they also cover skills, shared assets, and root workspace configuration.
   The build command creates the Worker bundle once; the deploy command publishes that bundle.
   The preview command uploads a version without promoting it to production.

For a manual release, authenticate with `pnpm --filter docs exec wrangler login`, then
run `pnpm --filter docs run deploy` after building. In external CI, store
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the CI secret store. Workers Builds
provides deployment authentication through its configured API token.
Custom domains and TLS are managed in the Cloudflare dashboard. Use Cloudflare's
deployment rollback controls to restore a previous version.

Prerendered pages use OpenNext's read-only Workers Static Assets cache. No R2 bucket,
D1 database, Durable Objects, or runtime application secrets are needed for the current
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
- Build command: `cd ../.. && pnpm build --filter=docs`, which generates skill pages before building.

Use the standard Next.js deployment. The configuration does not enable a static export.
Check Vercel's current plan limits before choosing a hosting plan.

## How content is generated

`scripts/gen-skills.mjs` reads the name and description from each skill's YAML header and creates
a Fumadocs page. It converts agent-only tags such as `<HARD-GATE>` into callouts, changes links to
other skills into site routes, and points other repository links to GitHub.

The generator adds a "View source on GitHub" link and writes
`content/docs/skills/<name>.mdx` plus its `meta.json` navigation file. Both
`pnpm dev --filter=docs` and `pnpm build --filter=docs` regenerate these files. Do not edit them by hand.
