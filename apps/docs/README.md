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
