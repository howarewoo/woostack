# woostack docs site

This documentation site uses Fumadocs and Next.js. It includes authored guides in `content/docs/`,
a landing page, and reference pages generated from `../skills/*/SKILL.md`.
The generated pages are ignored by Git. Edit the skill source when its reference page needs a change.

## Local development

Run these commands from the `site/` directory:

```bash
pnpm install
pnpm dev      # predev regenerates the skill pages, then next dev
```

Run `pnpm build` to generate skill pages and build the site for production.
`pnpm test` checks generator rendering, frontmatter, local asset links (including angle-bracket
destinations), and installation discovery with Node's built-in test runner (`node --test`).
It does not invoke a planner, model, or GitHub.

## Deploy to Vercel

Use these project settings:

- Root directory: `site/`.
- Include files outside the root directory in the build step: on. The generator reads
  `../skills/*/SKILL.md`; the build needs access to the repository outside `site/`.
- Framework preset: Next.js.
- Build command: the default `pnpm build`, which also runs `prebuild`.

Use the standard Next.js deployment. The configuration does not enable a static export.
Check Vercel's current plan limits before choosing a hosting plan.

## How content is generated

`scripts/gen-skills.mjs` reads the name and description from each skill's YAML header and creates
a Fumadocs page. It converts agent-only tags such as `<HARD-GATE>` into callouts, changes links to
other skills into site routes, and points other repository links to GitHub.

The generator adds a "View source on GitHub" link and writes
`content/docs/skills/<name>.mdx` plus its `meta.json` navigation file. Both `pnpm dev` and
`pnpm build` regenerate these files. Do not edit them by hand.
