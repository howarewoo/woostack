# woostack docs site

Fumadocs (Next.js) documentation site for the woostack skills. Per-skill reference pages are
**generated** from `../skills/*/SKILL.md` at build time (`prebuild`) and are gitignored; only
the app shell and the authored framing pages (`content/docs/index.mdx`, `getting-started.mdx`,
`concepts.mdx`) and the landing page are committed.

## Local development

```bash
pnpm install
pnpm dev      # predev regenerates the skill pages, then next dev
```

`pnpm test` runs the generator's unit suite (`node --test`).

## Deploy (Vercel free / Hobby tier)

- **Root Directory:** `site/`
- **Include files outside the root directory in the Build Step: ON** — required. The
  `prebuild` step reads `../skills/*/SKILL.md`, which lives outside the `site/` root
  directory. Without this setting Vercel restricts the build to `site/`, the generator finds
  no `../skills`, and the deploy fails fast with a clear message.
- **Framework preset:** Next.js (auto-detected). **Build command:** default (`pnpm build`,
  which runs `prebuild`). No server runtime is required (static generation), so it fits the
  free tier.

## How content is generated

`scripts/gen-skills.mjs` reads each `SKILL.md`, maps its frontmatter to a Fumadocs page,
neutralizes agent-only pseudo-tags (`<HARD-GATE>` etc.) into callouts, rewrites cross-links
(skill → site route, other repo paths → GitHub source), adds a "View source on GitHub"
backlink, and writes `content/docs/skills/<name>.mdx` plus its `meta.json`. The `skills/`
directory is the single source of truth — never edit the generated MDX by hand.
