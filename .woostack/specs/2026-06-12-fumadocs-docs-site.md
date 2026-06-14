---
name: fumadocs-docs-site
type: spec
status: approved
date: 2026-06-12
branch: feature/fumadocs-docs-site
links:
---

# Fumadocs docs site for the woostack skills — Design Spec

> **Plan:** [[plans/2026-06-12-fumadocs-docs-site]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

woostack ships eighteen `SKILL.md` files (sixteen public `/woostack-*` commands plus the
internal `woostack-ideate` and `woostack-harden` building blocks). The only human-facing
documentation today is the root `README.md`. There is no browsable, navigable site where a
user adopting woostack can read what each skill does, how the build loop and its gates fit
together, and how to install/initialize the collection.

The `SKILL.md` files are the source of truth, but they are written **for agents**: imperative
voice, hard-constraint pseudo-tag blocks (`<HARD-GATE>`, `<IRON-LAW>`, …), and relative
cross-links (`../woostack-x/SKILL.md`) that only resolve on a local clone. Pasting them into a
web docs site verbatim would (a) fail to render — the uppercase pseudo-tags parse as JSX
components and break MDX compilation — and (b) produce dead links.

## 2. Goal

A Fumadocs (Next.js App Router) documentation site, living at `site/` in this repo, that:

- Presents **one generated reference page per skill** (all 18), derived from each `SKILL.md`
  so the site never forks skill content and cannot drift.
- Adds **a few hand-authored framing pages** (home, getting-started, core concepts) for human
  onboarding.
- Deploys to the **Vercel free (hobby) tier** with Root Directory = `site/`, regenerating
  skill pages at build time so deployed content is always fresh.
- Is the first shipped **application subtree** in this repo, carved out as an explicit
  exception to the "no app code" hard constraint in `AGENTS.md`/`CLAUDE.md`.

## 3. Non-goals

YAGNI — explicitly out of scope for this increment:

- Search, doc versioning, i18n/localization.
- Custom branding / bespoke design system / dark-mode tuning (default Fumadocs theme only).
- Generated pages for bootstrap's `references/*.md` (frameworks, patterns, architecture,
  infrastructure, development, procedure) — agent-facing deep detail, linked to GitHub source
  instead.
- Analytics, custom domain, auth.
- Migrating the README into the site (the README stays the repo's canonical entry; the site
  links back to GitHub for source).
- Any change to the skills' own content or behavior. This work only *reads* `SKILL.md`.

## 4. Approach

Five pieces, each independently reviewable:

1. **Scaffold** a Fumadocs app at `site/` via `create-fumadocs-app` (Next.js App Router,
   `fumadocs-ui` + `fumadocs-mdx`). All package versions resolved **live** at plan/execute
   time (`npm view <pkg> version`) — none fabricated in this spec.
2. **Generation script** `site/scripts/gen-skills.mjs`: reads every `../skills/*/SKILL.md`,
   transforms it (frontmatter mapping, pseudo-tag neutralization, link rewriting, a "View
   source on GitHub" backlink), and writes `site/content/docs/skills/<name>.mdx`. The transform
   is the heart of the work.
3. **Authored pages**: a minimal landing page at `/` (`site/app/page.tsx`, replacing the
   scaffolded default — tagline + install one-liner + CTA into the docs) plus framing pages
   under `site/content/docs/`: `index.mdx`, `getting-started.mdx`, `concepts.mdx`. Hand-written,
   committed (not generated).
4. **Navigation** (`meta.json`): framing pages first, then a "Skills" group; internal
   sub-skills (ideate, harden) sorted last and flagged.
5. **Wiring**: `predev`/`prebuild` npm scripts run the generator so local dev and Vercel builds
   always regenerate; `.gitignore` excludes generated MDX + `node_modules` + `.next`; the
   `AGENTS.md` carve-out documents `site/` as a shipped subtree.

### Source-of-truth & drift posture

- `SKILL.md` files are the **only** source for skill page bodies. Generated MDX is gitignored
  and rebuilt every `dev`/`build`, so it can never be stale or hand-edited into divergence.
- Framing pages are **original prose** with no upstream source, so they are committed normally
  and carry no drift risk.

## 5. Components & data flow

```
skills/<name>/SKILL.md ──(gen-skills.mjs)──▶ site/content/docs/skills/<name>.mdx  (gitignored)
                                                          │
site/content/docs/index.mdx        (authored, committed) │
site/content/docs/getting-started.mdx (authored)         ├─▶ Fumadocs (fumadocs-mdx loader)
site/content/docs/concepts.mdx     (authored)            │        │
site/content/docs/meta.json        (nav order)           │        ▼
                                                          └──▶ Next.js App Router ──▶ Vercel (Root Dir = site/)
```

### 5.1 Scaffold (`site/`)

- Next.js App Router + Fumadocs UI/MDX, default theme.
- `source.config.ts` (or scaffolder equivalent) points the docs collection at
  `content/docs`.
- `site/package.json` scripts:
  - `predev` → `node scripts/gen-skills.mjs`
  - `dev` → `next dev`
  - `prebuild` → `node scripts/gen-skills.mjs`
  - `build` → `next build`
- The real scaffolder output shape is resolved at execute time; the plan adapts script names
  to whatever `create-fumadocs-app` emits rather than assuming.
- **Package manager: pnpm** (repo convention; [[prefer-pnpx]]). `site/` is a standalone pnpm
  project (the repo root has no workspace), with its own committed `site/pnpm-lock.yaml` — the
  app lockfile the carve-out (§5.5) explicitly permits, required for reproducible Vercel builds.

### 5.2 Generation script `site/scripts/gen-skills.mjs`

Pure Node, no network. For each `skills/*/SKILL.md` (resolved relative to repo root, i.e.
`../skills` from `site/`):

**a. Frontmatter mapping.** Parse the YAML frontmatter (`name`, `description`). Emit Fumadocs
frontmatter `title` (= `name`) and `description` (= the `description`, collapsed to a single
line). Drop the `# <name>` H1 that follows in the body (Fumadocs renders `title` as the H1) to
avoid a duplicate heading.

**b. Internal-skill flagging.** For `woostack-ideate` and `woostack-harden`, inject a callout at
the top of the body: an "Internal sub-skill" note stating it is a building block of
`woostack-build`, not a directly-invocable `/woostack-*` command.

**c. Pseudo-tag neutralization** (the MDX-breakers). The known set is
`<HARD-GATE>`, `<IRON-LAW>`, `<EXTREMELY-IMPORTANT>`, `<CHARACTERIZATION-CARVE-OUT>`,
`<SUBAGENT-STOP>`, `<PR>` (resolved by scanning, not hardcoded blindly — the script greps for
`<[A-Z][A-Z-]*>` so a newly-added pseudo-tag is also caught):
  - **Code-aware.** Neutralization runs only on content **outside** fenced code blocks and
    inline code spans. Angle-bracket tokens inside `` `…` `` / fences are literal-and-safe in
    MDX and are left verbatim — e.g. `<PR>` / `<repo>` inside
    `` `gh api repos/<repo>/pulls/<PR>/reviews` `` (woostack-review) must survive untouched.
  - **Block form** (an open `<TAG>` … `</TAG>` pair on their own lines, outside code) → convert
    to a Fumadocs `<Callout type="warn">` with the tag name as a human title (e.g. `HARD-GATE`
    → "Hard gate"), inner content preserved.
  - **Inline / unpaired form outside code** (a bare `<TAG>` mid-prose) → escape the angle
    brackets to literal text (`&lt;TAG&gt;`) so it renders verbatim, not as JSX.
  - **Invariant:** no uppercase pseudo-tag is left to be interpreted as JSX — every `<UPPER>`
    outside code spans/fences is either a `<Callout>` or escaped; the build smoke (AC5) is the
    backstop that proves nothing un-neutralized reaches the MDX compiler.

**d. Link rewriting.** Markdown links `](...)`:
  - `../woostack-x/SKILL.md` (optionally `#anchor`) → site route
    `/docs/skills/woostack-x` (`#anchor` preserved).
  - `../using-woostack/SKILL.md` → `/docs/skills/using-woostack`.
  - Any other relative link into the repo (`*/references/*.md`, `scripts/*.sh`, `*.html`,
    `action.yml`, etc.) → absolute GitHub source URL
    `https://github.com/howarewoo/woostack/blob/main/<path-from-repo-root>`.
  - Already-absolute (`http(s)://`) links → left untouched.

**e. View-source backlink.** Inject, just under the title, a small link to the page's source:
`https://github.com/howarewoo/woostack/blob/main/skills/<name>/SKILL.md` ("View source on
GitHub"). Reinforces that `SKILL.md` is the source of truth.

**f. Write.** Output `site/content/docs/skills/<name>.mdx`. Deterministic ordering; idempotent
(re-running yields byte-identical output). Creates the `skills/` output dir if missing.

### 5.3 Authored pages

- **Landing** `site/app/page.tsx` — replaces the scaffolded Fumadocs home: a minimal landing
  (tagline, `pnpx skills add howarewoo/woostack` one-liner, CTA button into `/docs`). Default
  theme components; no bespoke design.
- `index.mdx` — what woostack is (distilled from README intro), the install one-liner, a link
  into getting-started.
- `getting-started.mdx` — install (`pnpx skills add howarewoo/woostack`) → `/woostack-init` →
  AGENTS.md integration → first command. A concise web-native restatement of README's Getting
  Started; the **README stays canonical** for install (accept minor drift — both are short and
  install steps change rarely). Link back to the README on GitHub for the authoritative copy.
- `concepts.mdx` — the build loop and its three gates, the spec→plan→PRs `1:1:N` invariant, the
  local memory store. Links to the relevant generated skill pages.

### 5.4 Navigation (`meta.json`)

- Root order: `index`, `getting-started`, `concepts`, then the `skills` folder.
- `skills/meta.json`: public commands first (a sensible reading order — using-woostack, init,
  bootstrap, build, plan, execute, …), the two internal sub-skills (ideate, harden) last.

### 5.5 Repo wiring

- `site/.gitignore` (scaffolder-generated; extended) ignores: `node_modules`, `.next`, and the
  generated `content/docs/skills/`. `site/pnpm-lock.yaml` is **committed** (reproducible builds).
- `AGENTS.md` carve-out: a clause stating `site/` is a shipped application subtree (like
  `action.yml`), not stray app code — so the "no application source code / no app lockfile"
  constraint explicitly excepts it. `CLAUDE.md`/`GEMINI.md` are symlinks, so editing
  `AGENTS.md` covers all three.

### 5.6 Vercel deploy

- Root Directory = `site/`; framework auto-detected (Next.js); build command runs `build`
  (which fires `prebuild` → generation). No server runtime cost (SSG) → fits free tier.
- **Required setting — "Include files outside the root directory in the Build Step" = ON.**
  The prebuild generator reads `../skills/*/SKILL.md`, which lives *outside* the `site/` root
  directory. Vercel clones the whole repo but, with Root Directory set, restricts the build's
  visible files to that root unless this option is enabled. Without it, `prebuild` finds no
  `../skills` and the deploy fails. This is the one non-default Vercel config the site depends
  on; it is documented in the site deploy note.
- Documented in the site README / a short deploy note; the Vercel project itself is created by
  the user via the dashboard (out of code scope).

## 6. Error handling

- **Missing/malformed SKILL.md frontmatter** → the generator fails loudly (non-zero exit) with
  the offending path, rather than emitting a page with an empty title. A broken source must
  break the build, not ship silently.
- **Unknown new pseudo-tag** → caught by the generic `<[A-Z][A-Z-]*>` scan and neutralized
  (block→callout / inline→escaped); it never reaches MDX raw. If a tag is ambiguous
  (open without close), default to inline-escape (safe, non-breaking).
- **Link to a non-existent local path** → still rewritten to a GitHub source URL (the script
  does not stat targets; GitHub 404s are acceptable and visible, unlike a hard build break).
- **Generator output dir absent** → created automatically; re-run is idempotent.
- **`../skills` source dir absent** (e.g. Vercel without "include files outside root dir") →
  the generator exits non-zero with a clear message naming the expected path, so the deploy
  fails fast and visibly rather than building an empty docs tree. See §5.6.
- **MDX parse failure at build** → surfaces as a Next/Fumadocs build error naming the file;
  the build smoke test (AC5) is the backstop that catches any un-neutralized construct.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — Generator emits one MDX per skill with mapped frontmatter**
  - happy: running `gen-skills.mjs` produces exactly 18 files under
    `site/content/docs/skills/`, each with `title` = the skill `name`, a single-line
    `description` from the source frontmatter, and a "View source on GitHub" backlink to its
    `SKILL.md`; the duplicate `# <name>` H1 is removed.
  - error: a `SKILL.md` with missing/empty frontmatter `name` or `description` causes a
    non-zero exit naming the file; no partial/empty-title page is written.
  - edge: re-running the generator yields byte-identical output (idempotent); a pre-existing
    stale file in the output dir is overwritten, not appended.

- **AC2 — No raw pseudo-tag survives; block tags become callouts**
  - happy: for `woostack-ideate` (`<HARD-GATE>`) and `woostack-debug` (`<IRON-LAW>`), the
    emitted MDX contains a `<Callout …>` with a human title and the original inner text, and no
    `<UPPER>` tag remains **outside** code spans/fences in any generated file.
  - error: a bare uppercase pseudo-tag in prose (outside code) is escaped to literal text, not
    left as a JSX tag; but a `<PR>` already inside an inline code span is preserved verbatim
    (regression guard both ways).
  - edge: a newly-introduced uppercase pseudo-tag (not in the known list) is still neutralized
    by the generic scan when it sits outside code.

- **AC3 — Cross-links are rewritten correctly**
  - happy: `](../woostack-plan/SKILL.md)` → `](/docs/skills/woostack-plan)`; a `#anchor` is
    preserved; `](../woostack-init/references/worktrees.md)` →
    `](https://github.com/howarewoo/woostack/blob/main/skills/woostack-init/references/worktrees.md)`.
  - error: an already-absolute `https://…` link is left unchanged (not double-rewritten).
  - edge: a SKILL.md→SKILL.md link with both a path and a fragment keeps the fragment on the
    site route.

- **AC4 — Internal sub-skills are flagged**
  - happy: `woostack-ideate.mdx` and `woostack-harden.mdx` open with an "internal sub-skill"
    callout; the 16 public pages do not.
  - edge: meta ordering places ideate/harden after the public commands.

- **AC5 — The site builds (all MDX parses, landing renders)**
  - happy: `pnpm --dir site build` (which runs `prebuild` generation first) exits 0 and emits
    routes for the landing page `/`, the 18 skill pages, and 3 framing pages.
  - error: if any generated or authored MDX fails to parse, the build exits non-zero and names
    the file (proves the neutralization is load-bearing).
  - edge: `/` serves the authored landing (not the scaffolded Fumadocs default); a link/CTA
    reaches `/docs`.

- **AC6 — Repo hygiene & carve-out**
  - happy: `.gitignore` excludes `site/node_modules`, `site/.next`, and the generated
    `site/content/docs/skills/`; `git status` after a build shows no generated MDX or build
    artifacts as untracked.
  - error/edge: `AGENTS.md` contains a clause excepting `site/` from the no-app-code
    constraint; the three symlinked instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`)
    stay consistent (single source).

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

- **Unit (generator).** Test `gen-skills.mjs` with Node's built-in test runner
  (`node --test`, zero extra deps) against small inline fixtures: a frontmatter sample, a block
  pseudo-tag, an inline pseudo-tag, each link class. Assert the AC1–AC4 invariants — most
  importantly the "no raw `<UPPER>` tag survives" and the link-rewrite mappings. Factor the
  transform into pure exported functions (`mapFrontmatter`, `neutralizeTags`, `rewriteLinks`)
  so they unit-test without filesystem I/O; the file-walk wrapper is the thin shell.
- **Integration / build smoke.** A test (or CI/script step) runs the generator against the real
  `skills/` tree then `next build` and asserts exit 0 — the end-to-end proof that every real
  SKILL.md neutralizes and every page compiles (AC5).
- **No app CI added to this repo's push/PR events** beyond what executing the plan needs;
  the build smoke is run locally during execution. (Any future site CI is out of scope here.)
- TDD per the [woostack-tdd kernel](../../skills/woostack-tdd/SKILL.md): the generator's pure
  functions are written red-first; the scaffold is characterized by the build-smoke pass.

## 9. Open questions

**Resolved during hardening (2026-06-12):**

- **Site root `/`** → a minimal hand-authored landing page (tagline + install + CTA), not a
  redirect. (§5.3)
- **Per-page provenance** → yes, each generated page carries a "View source on GitHub"
  backlink to its `SKILL.md`. (§5.2e)
- **Package manager** → pnpm; `site/pnpm-lock.yaml` committed. (§5.1, §5.5)
- **GitHub link base** → confirmed `github.com/howarewoo/woostack` @ `main` (from the live
  remote). (§5.2d)
- **Vercel `../skills` access** → requires "Include files outside the root directory" = ON;
  documented as a deploy requirement, generator fails fast if absent. (§5.6, §6)
- **getting-started drift** → README stays canonical for install; the page is a concise
  web-native restatement that links back. (§5.3)

**Still open (deferred, non-blocking):**

- Exact `create-fumadocs-app` output layout (`source.config.ts` vs `app/source.ts`, default
  script names) — resolved at execute time against the real scaffolder, not assumed here.
- Heading-anchor fidelity across rewritten `#anchor` links (Fumadocs slug vs source anchor) —
  accepted as best-effort, non-blocking.
