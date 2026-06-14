---
type: plan
source: .woostack/specs/2026-06-12-fumadocs-docs-site.md
status: done
branch: feature/fumadocs-docs-site
---

**Source:** .woostack/specs/2026-06-12-fumadocs-docs-site.md

# Fumadocs docs site for the woostack skills — Implementation Plan

**Goal:** Ship a Fumadocs (Next.js) documentation site at `site/` that generates one reference page per `SKILL.md` plus a few authored framing pages, deployable on the Vercel free tier.

**Architecture:** Three stacked increments. (1) Scaffold a default Fumadocs app at `site/` and carve `site/` out of the repo's no-app-code constraint. (2) Add a code-aware `SKILL.md → MDX` generator (`scripts/gen-skills.mjs`) — pure transform functions (frontmatter map, title-strip, link rewrite, pseudo-tag neutralize, render) unit-tested with `node --test` — wired into `predev`/`prebuild` so content is always fresh and gitignored. (3) Author the landing page, the `index`/`getting-started`/`concepts` docs, the nav, and a deploy note. Each increment ends on a green `pnpm build`.

**Tech Stack:** Next.js (App Router) · Fumadocs (`fumadocs-ui`, `fumadocs-mdx`) · pnpm · Node 22 · `node --test` (built-in). All package versions resolved live by the scaffolder at execute time — none pinned here.

---

## Increment 1: Scaffold the Fumadocs app + repo carve-out

> One PR: a working default Fumadocs site at `site/` (vendored scaffold) + the `AGENTS.md` exception clause. Builds green as-is. Mostly generated scaffold files — review the carve-out clause and the scaffold choices.

### Task 1: Scaffold `site/` with create-fumadocs-app

**Files:**
- Create: `site/**` (scaffolder output: `package.json`, `app/`, `content/docs/`, `source.config.ts`, `mdx-components.tsx`, `tsconfig.json`, `.gitignore`, `pnpm-lock.yaml`, …)

- [x] **Step 1: Run the scaffolder (pnpm)**

From the repo root (worktree cwd):

```bash
pnpm create fumadocs-app@latest site
```

Answer the prompts: project type **Next.js**, content source **Fumadocs MDX**, **Tailwind CSS** yes, package manager **pnpm**, install deps **yes**. (Scaffolder UX changes between versions — match these intents to whatever it asks; do not pin versions.)

- [x] **Step 2: Confirm the scaffold layout, adapt if names differ**

Run: `ls site && cat site/package.json | sed -n '1,40p'`
Expected: a `site/` containing `app/`, `content/docs/`, `source.config.ts` (or `app/source.ts` / `lib/source.ts` in newer scaffolds), `mdx-components.tsx`, `package.json` with `dev`/`build` scripts, and `pnpm-lock.yaml`. Note the actual scripts/paths — later tasks reference `site/content/docs/` and `site/mdx-components.tsx`; adapt to the real names the scaffolder emitted.

- [x] **Step 3: Verify the default scaffold builds**

Run: `pnpm --dir site build`
Expected: PASS — `next build` exits 0, emits the default docs routes.

- [x] **Step 4: Commit**

```bash
# first commit in this increment (stacks on the spec+plan base branch):
gt create -m "feat(site): scaffold fumadocs docs app"
```

### Task 2: Carve `site/` out of the no-app-code constraint

**Files:**
- Modify: `AGENTS.md` (the "What this repo is" / "Hard constraints" area; `CLAUDE.md` and `GEMINI.md` are symlinks, so this one edit covers all three)

- [x] **Step 1: Write the failing check (the clause is absent)**

Run: `grep -c 'site/' AGENTS.md`
Expected: FAIL — `0` (no mention of the `site/` subtree yet).

- [x] **Step 2: Add the carve-out clause**

In `AGENTS.md`, under the "There is no application source code…" paragraph, add:

```markdown
The second exception is the user-facing documentation site: [`site/`](site/) is a shipped
Fumadocs (Next.js) application subtree — the docs site for these skills. Like
[`action.yml`](action.yml), it is a shipped asset, not self-CI and not stray app code. Its
`package.json`, `pnpm-lock.yaml`, and build config are the one sanctioned exception to the
"no application source code / no app lockfile" rule above. Its skill reference pages are
generated from `skills/*/SKILL.md` at build time and are gitignored.
```

Also extend the Mode A constraint note so it does not read as forbidding `site/`:

```markdown
**Mode A: edit this skill collection.** … do not add application code, app build configs, or
app lockfiles **outside the sanctioned `site/` docs-app subtree**.
```

- [x] **Step 3: Confirm the clause is present and symlinks still resolve**

Run: `grep -c 'site/' AGENTS.md && readlink CLAUDE.md GEMINI.md`
Expected: PASS — a non-zero count, and both symlinks print `AGENTS.md`.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs(agents): carve site/ docs-app out of no-app-code rule"
```

---

## Increment 2: SKILL.md → MDX generator (tested) + build wiring

> One PR: the transform engine. Pure functions unit-tested with `node --test`, a file-walk shell, wired into `predev`/`prebuild`, generated output gitignored. Running it produces 18 MDX pages; the build regenerates and compiles them.

### Task 1: Pure module skeleton + `parseFrontmatter`

**Files:**
- Create: `site/scripts/gen-skills.mjs`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1: Write the failing test**

```js
// site/scripts/gen-skills.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseFrontmatter } from './gen-skills.mjs';

test('parseFrontmatter extracts name + description and returns the body', () => {
  const raw = '---\nname: woostack-build\ndescription: Use when building a feature.\n---\n\n# woostack-build\n\nbody';
  const { fm, body } = parseFrontmatter(raw, 'woostack-build');
  assert.equal(fm.name, 'woostack-build');
  assert.equal(fm.description, 'Use when building a feature.');
  assert.match(body, /# woostack-build/);
});

test('parseFrontmatter throws when name is missing', () => {
  assert.throws(() => parseFrontmatter('---\ndescription: x\n---\nbody', 'f'), /missing 'name'/);
});

test('parseFrontmatter strips surrounding YAML quotes (some SKILL.md descriptions are quoted)', () => {
  const raw = '---\nname: woostack-tdd\ndescription: "TDD home: red→green. Quoted in source."\n---\nb';
  const { fm } = parseFrontmatter(raw, 'woostack-tdd');
  assert.equal(fm.description, 'TDD home: red→green. Quoted in source.'); // no leading/trailing "
});
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: FAIL — `Cannot find module './gen-skills.mjs'` (or export missing).

- [x] **Step 3: Minimal implementation**

```js
// site/scripts/gen-skills.mjs
import { readdir, readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');       // site/scripts -> repo root
const SKILLS_DIR = path.join(REPO_ROOT, 'skills');
const OUT_DIR = path.resolve(__dirname, '..', 'content', 'docs', 'skills');
const GH_BASE = 'https://github.com/howarewoo/woostack/blob/main';
const INTERNAL = new Set(['woostack-ideate', 'woostack-harden']);

export function parseFrontmatter(raw, file = '<input>') {
  const m = /^---\n([\s\S]*?)\n---\n?/.exec(raw);
  if (!m) throw new Error(`${file}: missing frontmatter`);
  const fm = {};
  for (const line of m[1].split('\n')) {
    const mm = /^(\w+):\s*(.*)$/.exec(line);
    if (!mm) continue;
    let v = mm[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1).replace(/\\"/g, '"');   // some descriptions are YAML-quoted in source
    }
    fm[mm[1]] = v;
  }
  if (!fm.name) throw new Error(`${file}: frontmatter missing 'name'`);
  if (!fm.description) throw new Error(`${file}: frontmatter missing 'description'`);
  return { fm, body: raw.slice(m[0].length) };
}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: PASS — 2 tests.

- [x] **Step 5: Commit**

```bash
gt create -m "feat(site): gen-skills parseFrontmatter"
```

### Task 2: `stripTitleHeading`

**Files:**
- Modify: `site/scripts/gen-skills.mjs`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1: Write the failing test**

```js
import { stripTitleHeading } from './gen-skills.mjs';

test('stripTitleHeading removes the first "# <name>" H1 only', () => {
  const body = '\n# woostack-build\n\n## Overview\n\n# woostack-build (kept)\n';
  const out = stripTitleHeading(body, 'woostack-build');
  assert.equal(out.match(/^# woostack-build$/gm).length, 1); // the second one stays
  assert.match(out, /## Overview/);
});
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: FAIL — `stripTitleHeading is not a function`.

- [x] **Step 3: Minimal implementation**

```js
export function stripTitleHeading(body, name) {
  const lines = body.split('\n');
  const idx = lines.findIndex((l) => l.trim() === `# ${name}`);
  if (idx !== -1) lines.splice(idx, 1);
  return lines.join('\n');
}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): gen-skills stripTitleHeading"
```

### Task 3: `rewriteLinks`

**Files:**
- Modify: `site/scripts/gen-skills.mjs`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1: Write the failing test**

```js
import { rewriteLinks } from './gen-skills.mjs';

test('rewriteLinks maps skill links to routes, refs to GitHub, leaves absolute/anchors', () => {
  const r = (s) => rewriteLinks(s, 'woostack-build');
  assert.equal(r('see [plan](../woostack-plan/SKILL.md)'), 'see [plan](/docs/skills/woostack-plan)');
  assert.equal(r('[a](../woostack-plan/SKILL.md#x)'), '[a](/docs/skills/woostack-plan#x)');
  assert.equal(
    r('[wt](../woostack-init/references/worktrees.md)'),
    '[wt](https://github.com/howarewoo/woostack/blob/main/skills/woostack-init/references/worktrees.md)'
  );
  assert.equal(
    r('[self](references/plan-template.md)'),
    '[self](https://github.com/howarewoo/woostack/blob/main/skills/woostack-build/references/plan-template.md)'
  );
  assert.equal(r('[ext](https://example.com)'), '[ext](https://example.com)');
  assert.equal(r('[here](#section)'), '[here](#section)');
});
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: FAIL — `rewriteLinks is not a function`.

- [x] **Step 3: Minimal implementation**

```js
export function rewriteLinks(body, name) {
  return body.replace(/\]\(([^)]+)\)/g, (whole, target) => {
    if (/^https?:\/\//.test(target) || target.startsWith('#') || target.startsWith('mailto:')) return whole;
    const skill = /^\.\.\/([a-z0-9-]+)\/SKILL\.md(#.+)?$/.exec(target);
    if (skill) return `](/docs/skills/${skill[1]}${skill[2] || ''})`;
    const hash = (target.match(/#.*$/) || [''])[0];
    const clean = target.replace(/#.*$/, '');
    const rel = clean.replace(/^(\.\.\/)+/, '');             // strip leading ../
    const ghPath = clean.startsWith('../') ? `skills/${rel}` : `skills/${name}/${rel}`;
    return `](${GH_BASE}/${ghPath}${hash})`;
  });
}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): gen-skills rewriteLinks"
```

### Task 4: `neutralizeTags` (code-aware)

**Files:**
- Modify: `site/scripts/gen-skills.mjs`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1: Write the failing test**

```js
import { neutralizeTags } from './gen-skills.mjs';

test('neutralizeTags: block tag -> Callout, prose tag escaped, code-span tag preserved', () => {
  const block = '<HARD-GATE>\nDo not proceed.\n</HARD-GATE>';
  const out = neutralizeTags(block);
  assert.match(out, /<Callout type="warn" title="Hard gate">/);
  assert.match(out, /<\/Callout>/);
  assert.doesNotMatch(out, /<HARD-GATE>/);

  // bare uppercase tag in prose -> escaped
  assert.match(neutralizeTags('a bare <FOO> here'), /a bare &lt;FOO&gt; here/);

  // uppercase tag inside an inline code span -> preserved verbatim
  const code = 'POST `gh api repos/<repo>/pulls/<PR>/reviews` now';
  assert.equal(neutralizeTags(code), code);

  // uppercase tag inside a fenced block -> preserved verbatim
  const fenced = '```\n<PR> stays\n```';
  assert.equal(neutralizeTags(fenced), fenced);
});
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: FAIL — `neutralizeTags is not a function`.

- [x] **Step 3: Minimal implementation**

```js
function humanizeTag(t) {
  const s = t.replace(/-/g, ' ').toLowerCase();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function escapeBareTagsOutsideCode(line) {
  // split on inline code spans; only escape in the non-code segments
  return line
    .split(/(`[^`]*`)/)
    .map((seg) => (seg.startsWith('`') ? seg : seg.replace(/<(\/?[A-Z][A-Z-]*)>/g, '&lt;$1&gt;')))
    .join('');
}

export function neutralizeTags(body) {
  const out = [];
  let inFence = false;
  for (const line of body.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; out.push(line); continue; }
    if (inFence) { out.push(line); continue; }
    const open = /^<([A-Z][A-Z-]*)>\s*$/.exec(line);
    if (open) { out.push(`<Callout type="warn" title="${humanizeTag(open[1])}">`); continue; }
    if (/^<\/[A-Z][A-Z-]*>\s*$/.test(line)) { out.push('</Callout>'); continue; }
    out.push(escapeBareTagsOutsideCode(line));
  }
  return out.join('\n');
}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): gen-skills code-aware neutralizeTags"
```

### Task 5: `renderPage` (frontmatter + internal note + source link)

**Files:**
- Modify: `site/scripts/gen-skills.mjs`
- Test: `site/scripts/gen-skills.test.mjs`

- [x] **Step 1: Write the failing test**

```js
import { renderPage } from './gen-skills.mjs';

test('renderPage emits title/description, source link, and an internal note for sub-skills', () => {
  const fm = { name: 'woostack-build', description: 'Build a feature: end to end.' };
  const page = renderPage('woostack-build', fm, '## Overview\n\nbody');
  assert.match(page, /^---\ntitle: woostack-build\n/);
  assert.match(page, /description: "Build a feature: end to end\."/);   // JSON-quoted, safe for the colon
  assert.match(page, /\[View source on GitHub\]\(https:\/\/github\.com\/howarewoo\/woostack\/blob\/main\/skills\/woostack-build\/SKILL\.md\)/);
  assert.doesNotMatch(page, /Internal sub-skill/);

  const ideate = renderPage('woostack-ideate', { name: 'woostack-ideate', description: 'x' }, 'b');
  assert.match(ideate, /Internal sub-skill/);
});
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: FAIL — `renderPage is not a function`.

- [x] **Step 3: Minimal implementation**

```js
export function renderPage(name, fm, body) {
  const front = `---\ntitle: ${name}\ndescription: ${JSON.stringify(fm.description)}\n---\n\n`;
  const internal = INTERNAL.has(name)
    ? `<Callout type="info" title="Internal sub-skill">Building block of [woostack-build](/docs/skills/woostack-build); not a directly-invocable \`/woostack-*\` command.</Callout>\n\n`
    : '';
  const source = `[View source on GitHub](${GH_BASE}/skills/${name}/SKILL.md)\n\n`;
  return front + internal + source + body.replace(/^\n+/, '') + '\n';
}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `node --test site/scripts/gen-skills.test.mjs`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): gen-skills renderPage"
```

### Task 6: File-walk shell + run against the real skills tree

**Files:**
- Modify: `site/scripts/gen-skills.mjs`

- [x] **Step 1: Add the `main()` walk + direct-invocation guard (so tests can import without running it)**

```js
async function main() {
  if (!existsSync(SKILLS_DIR)) {
    console.error(
      `gen-skills: source dir not found: ${SKILLS_DIR}\n` +
      `On Vercel, enable "Include files outside the root directory in the Build Step".`
    );
    process.exit(1);
  }
  await rm(OUT_DIR, { recursive: true, force: true });
  await mkdir(OUT_DIR, { recursive: true });
  const names = (await readdir(SKILLS_DIR, { withFileTypes: true }))
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
  let count = 0;
  for (const name of names) {
    const file = path.join(SKILLS_DIR, name, 'SKILL.md');
    if (!existsSync(file)) continue;
    const raw = await readFile(file, 'utf8');
    const { fm, body } = parseFrontmatter(raw, name);
    let b = stripTitleHeading(body, fm.name);
    b = neutralizeTags(b);
    b = rewriteLinks(b, name);
    await writeFile(path.join(OUT_DIR, `${name}.mdx`), renderPage(name, fm, b), 'utf8');
    count++;
  }
  console.log(`gen-skills: wrote ${count} pages -> ${path.relative(process.cwd(), OUT_DIR)}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
```

- [x] **Step 2: Run the generator against the real skills tree, confirm 18 pages**

Run: `cd site && node scripts/gen-skills.mjs && ls content/docs/skills | wc -l`
Expected: PASS — `gen-skills: wrote 18 pages …` and `ls | wc -l` prints `18`.

- [x] **Step 3: Confirm no JSX-interpretable pseudo-tag survives outside code**

Run: `cd site && node scripts/gen-skills.mjs >/dev/null && ! grep -rnE '^<[A-Z][A-Z-]+>' content/docs/skills`
Expected: PASS — exit 0 (no standalone-line uppercase tag remains; block tags are now `<Callout>`).

- [x] **Step 4: Confirm idempotence**

Run: `cd site && node scripts/gen-skills.mjs && cp -r content/docs/skills /tmp/g1 && node scripts/gen-skills.mjs && diff -r /tmp/g1 content/docs/skills && echo IDEMPOTENT`
Expected: PASS — `IDEMPOTENT` (no diff).

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): gen-skills file walk over skills/*/SKILL.md"
```

### Task 7: Wire generation into the build + gitignore output + register Callout

**Files:**
- Modify: `site/package.json` (scripts)
- Modify: `site/.gitignore`
- Modify: `site/mdx-components.tsx` (ensure `Callout` is in scope for generated MDX)

- [x] **Step 1: Add `predev`/`prebuild`/`test` scripts**

In `site/package.json` `"scripts"`, add (keep the scaffolded `dev`/`build`):

```json
{
  "scripts": {
    "predev": "node scripts/gen-skills.mjs",
    "prebuild": "node scripts/gen-skills.mjs",
    "test": "node --test scripts/*.test.mjs"
  }
}
```

- [x] **Step 2: Gitignore the generated output**

Append to `site/.gitignore`:

```gitignore
# generated from skills/*/SKILL.md at build time (source of truth = skills/)
/content/docs/skills/
```

- [x] **Step 3: Ensure `Callout` is registered for MDX**

Confirm `site/mdx-components.tsx` spreads Fumadocs defaults (which include `Callout`). If it does not, add it:

```tsx
import defaultMdxComponents from 'fumadocs-ui/mdx';
import { Callout } from 'fumadocs-ui/components/callout';

export function getMDXComponents(components) {
  return { ...defaultMdxComponents, Callout, ...components };
}
```

Run: `cd site && grep -q Callout mdx-components.tsx && echo OK`
Expected: PASS — `OK`.

- [x] **Step 4: Build smoke — generation + compile of all 18 generated pages**

Run: `cd site && rm -rf content/docs/skills && pnpm build`
Expected: PASS — `prebuild` regenerates 18 pages, `next build` exits 0 and compiles every generated `skills/*.mdx` (proves the neutralization is load-bearing).

- [x] **Step 5: Confirm generated output is untracked/ignored**

Run: `git status --porcelain site/content/docs/skills | wc -l`
Expected: PASS — `0` (gitignored; not staged).

- [x] **Step 6: Run the unit suite once more, then commit**

Run: `cd site && pnpm test`
Expected: PASS — all `node --test` assertions green.

```bash
gt modify -c -m "build(site): wire gen-skills into pre(dev|build), gitignore output"
```

---

## Increment 3: Authored pages, navigation, deploy note

> One PR: the human-written surface — landing `/`, the three framing docs, the nav order, and the Vercel deploy note. Full site builds green with generated + authored content.

### Task 1: Landing page at `/`

**Files:**
- Modify: the scaffold's home route — `site/app/page.tsx` in a flat scaffold, or
  `site/app/(home)/page.tsx` if the scaffolder used a `(home)` route group. Locate it first
  (`find site/app -name 'page.tsx' -maxdepth 2`) and replace whichever renders `/`.

- [x] **Step 1: Replace the scaffold landing with a minimal woostack landing**

```tsx
// site/app/page.tsx
import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 px-4 text-center">
      <h1 className="text-4xl font-bold">woostack</h1>
      <p className="max-w-xl text-fd-muted-foreground">
        A model-agnostic collection of software-development skills covering every phase of the
        engineering process — bootstrap, build, debug, review, and iterate.
      </p>
      <pre className="rounded-md bg-fd-muted px-4 py-2 text-sm">pnpx skills add howarewoo/woostack</pre>
      <Link
        href="/docs"
        className="rounded-md bg-fd-primary px-5 py-2 font-medium text-fd-primary-foreground"
      >
        Read the docs →
      </Link>
    </main>
  );
}
```

- [x] **Step 2: Verify the landing renders (not the scaffold default) and links to /docs**

Run: `cd site && pnpm build && grep -rq 'pnpx skills add howarewoo/woostack' .next/server/app/index*.html 2>/dev/null || echo CHECK_DEV`
Expected: PASS — build exits 0. (If the static HTML grep is environment-dependent, fall back to `pnpm dev` and confirm `/` shows the woostack landing with a working "Read the docs" link to `/docs`.)

- [x] **Step 3: Commit**

```bash
gt create -m "feat(site): woostack landing page"
```

### Task 2: `index.mdx` (docs home)

**Files:**
- Modify/Create: `site/content/docs/index.mdx` (replace the scaffold sample)

- [x] **Step 1: Author the docs index**

```mdx
---
title: What is woostack?
description: A model-agnostic collection of gated software-development skills.
---

woostack packages opinionated, gated workflows into installable skills that any AI coding
agent can follow — from greenfield bootstrapping to feature building, debugging, automated
code review, and feedback iteration. It ships a local, token-efficient memory system so later
agent sessions don't repeat earlier mistakes.

```bash
pnpx skills add howarewoo/woostack
```

- **Agent- & model-agnostic** — Claude Code, Cursor, Codex, Aider, and other agents that
  respect the `skills` convention.
- **Local memory** — learnings retained and routed per clone.
- **Team-ready** — built for small-to-medium collaborative codebases.

Start with [Getting started](/docs/getting-started), then skim [Core concepts](/docs/concepts)
and the per-skill reference under **Skills**.
```

- [x] **Step 2: Verify it builds**

Run: `cd site && pnpm build`
Expected: PASS — `/docs` renders the authored index.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(site): authored docs index"
```

### Task 3: `getting-started.mdx`

**Files:**
- Create: `site/content/docs/getting-started.mdx`

- [x] **Step 1: Author getting-started (README stays canonical; link back)**

```mdx
---
title: Getting started
description: Install woostack, initialize the workspace, and wire it into your agent.
---

> The repository [`README`](https://github.com/howarewoo/woostack#getting-started) is the
> canonical install reference. This page is a concise web-native version.

## 1. Install

```bash
pnpx skills add howarewoo/woostack
```

`pnpm` (and `pnpx`) is the recommended package manager.

## 2. Initialize

```bash
/woostack-init
```

Run this **before any other woostack skill** — it sets up the `.woostack/` workspace, default
config, and gitignores.

## 3. Integrate

Add the `using-woostack` routing block to your repo's agent instructions
(`AGENTS.md` or `CLAUDE.md`) so agents pick up the pipeline automatically.

## 4. Build something

Run [`/woostack-build`](/docs/skills/woostack-build) to drive a feature from idea to a
reviewed PR stack, or [`/woostack-fix`](/docs/skills/woostack-fix) for a small change.
```

- [x] **Step 2: Verify it builds**

Run: `cd site && pnpm build`
Expected: PASS.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(site): authored getting-started"
```

### Task 4: `concepts.mdx`

**Files:**
- Create: `site/content/docs/concepts.mdx`

- [x] **Step 1: Author core-concepts**

```mdx
---
title: Core concepts
description: The build loop, its gates, and the local memory store.
---

## The build loop

[`woostack-build`](/docs/skills/woostack-build) chains the phases in a fixed, gated order:

> ideate → write spec → harden spec → **approve spec** → plan → harden plan → ship spec+plan PR
> → **execution handoff** → execute (per increment: implement → commit → review → distill)

## Three hard gates

1. **Design approval** — owned by [`woostack-ideate`](/docs/skills/woostack-ideate).
2. **Spec approval** — the written spec is presented before any planning.
3. **Execution handoff** — after the spec+plan PR, you choose Go / Run overnight / Hand off.

No phase advances past a hard gate without an explicit yes.

## One spec, one plan, N PRs

Every feature holds the `spec : plan : PRs = 1 : 1 : N` invariant — exactly one plan per spec,
and that plan owns the N stacked increment PRs. [`woostack-status`](/docs/skills/woostack-status)
derives the board from these artifacts.

## Local memory

woostack keeps a per-clone `.woostack/memory/` store. Each increment distills durable,
deduplicated learnings; [`woostack-dream`](/docs/skills/woostack-dream) curates the store over
time. A small curated store beats a large noisy one.
```

- [x] **Step 2: Verify it builds**

Run: `cd site && pnpm build`
Expected: PASS.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(site): authored core-concepts"
```

### Task 5: Navigation order (`meta.json`)

**Files:**
- Create/Modify: `site/content/docs/meta.json` (root order)
- Create: `site/content/docs/skills/meta.json` — **gitignored** with the generated pages, so emit it from the generator instead (see Step 2)

- [x] **Step 1: Root nav order**

```json
{
  "title": "Docs",
  "pages": ["index", "getting-started", "concepts", "skills"]
}
```

- [x] **Step 2: Emit `skills/meta.json` from the generator (the folder is gitignored)**

In `site/scripts/gen-skills.mjs` `main()`, after the write loop, add an ordered group meta so
public commands lead and the internal sub-skills trail:

```js
const ORDER = [
  'using-woostack', 'woostack-init', 'woostack-bootstrap', 'woostack-build', 'woostack-fix',
  'woostack-plan', 'woostack-execute', 'woostack-execute-overnight', 'woostack-commit',
  'woostack-review', 'woostack-address-comments', 'woostack-status', 'woostack-visualize',
  'woostack-debug', 'woostack-tdd', 'woostack-dream',
];
const pages = [...ORDER.filter((n) => names.includes(n)), ...names.filter((n) => !ORDER.includes(n))];
await writeFile(path.join(OUT_DIR, 'meta.json'), JSON.stringify({ title: 'Skills', pages }, null, 2) + '\n', 'utf8');
```

(The two internal sub-skills `woostack-ideate`/`woostack-harden` are absent from `ORDER`, so
they sort last — matching the spec.)

- [x] **Step 3: Verify nav order**

Run: `cd site && node scripts/gen-skills.mjs && node -e "const m=require('./content/docs/skills/meta.json'); console.log(m.pages.slice(0,1)[0], m.pages.slice(-2).join(','))"`
Expected: PASS — prints `using-woostack woostack-ideate,woostack-harden` (public lead, internals last).

- [x] **Step 4: Full build smoke**

Run: `cd site && rm -rf content/docs/skills && pnpm build`
Expected: PASS — landing + 3 framing pages + 18 skill pages all compile; nav shows framing pages then the Skills group.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(site): nav order (framing pages, then skills; internals last)"
```

### Task 6: Deploy note

**Files:**
- Create: `site/README.md`

- [x] **Step 1: Author the deploy note**

```markdown
# woostack docs site

Fumadocs (Next.js) documentation site for the woostack skills. Skill reference pages are
generated from `../skills/*/SKILL.md` at build time (`prebuild`) and are gitignored.

## Local dev

```bash
pnpm install
pnpm dev      # predev regenerates skill pages, then next dev
```

## Deploy (Vercel free tier)

- **Root Directory:** `site/`
- **Include files outside the root directory in the Build Step:** **ON** — required, because
  `prebuild` reads `../skills/*/SKILL.md`, which lives outside `site/`. Without this, generation
  fails and the deploy errors.
- Framework preset: Next.js (auto-detected). Build command: default (`pnpm build`, which runs
  `prebuild`). No server runtime needed (SSG) — fits the Hobby tier.
```

- [x] **Step 2: Verify the critical setting is documented**

Run: `grep -q 'Include files outside the root directory' site/README.md && echo OK`
Expected: PASS — `OK`.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "docs(site): deploy note (Vercel root dir + include-files setting)"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — Scaffold+carve-out (§5.1, §5.5 → Inc 1); generator transform: frontmatter map, title-strip, link rewrite, code-aware tag neutralize, source link, internal flag (§5.2 → Inc 2 Tasks 1–6); build wiring + gitignore (§5.5 → Inc 2 Task 7); landing + framing pages + nav (§5.3, §5.4 → Inc 3 Tasks 1–5); Vercel deploy note incl. include-files setting (§5.6 → Inc 3 Task 6). Every spec section maps to ≥1 task.
- [x] **AC coverage** — AC1 (18 pages, mapped frontmatter, source link, H1 dropped) → Inc2 T1/T5/T6; AC2 (block→Callout, prose-tag escaped, code-span preserved, generic scan) → Inc2 T4 + T6 S3; AC3 (link classes) → Inc2 T3; AC4 (internal flag + nav last) → Inc2 T5 + Inc3 T5; AC5 (build green, landing route) → Inc2 T7 S4 + Inc3 T1/T4; AC6 (gitignore + carve-out + symlink consistency) → Inc2 T7 S2/S5 + Inc1 T2. Each filled happy/error/edge case has a test/command.
- [x] **No placeholders** — every step has complete code/commands and expected output; no TBD/TODO.
- [x] **Type consistency** — exported names (`parseFrontmatter`, `stripTitleHeading`, `rewriteLinks`, `neutralizeTags`, `renderPage`), constants (`SKILLS_DIR`, `OUT_DIR`, `GH_BASE`, `INTERNAL`, `ORDER`), and the `(fm, body)` shapes are used identically across Tasks 1–6.

> Notes for execution: (1) the scaffolder's exact file names/scripts are resolved live in Inc 1 T1–T2 — adapt `mdx-components.tsx`/`source.config.ts`/script names to what it emits. (2) Versions are never pinned here; the scaffolder installs current ones. (3) Increments are one linear `gt` stack on the spec+plan base (no `## Track:` headings).
