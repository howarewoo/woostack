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
`pnpm test` runs the generator and authored planning-fixture tests with Node's built-in test runner
(`node --test`). The ChatGPT guide's bounded mock transcript can also be inspected with
`node --test scripts/chatgpt-to-codex.test.mjs`. It reads the exact canonical prompt from the authored
page and checks mock request/response evidence; it does not invoke a model or contact GitHub.

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
