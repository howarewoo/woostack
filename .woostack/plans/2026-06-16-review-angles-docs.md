---
type: plan
source: .woostack/specs/2026-06-16-review-angles-docs.md
status: ready
branch: feature/review-angles-docs
---

**Source:** [[specs/2026-06-16-review-angles-docs]]

# Review angles — Docs page Implementation Plan

**Goal:** Add one authored docs page, `site/content/docs/review-angles.mdx`, that catalogs every review angle (what it audits, when it auto-fires, its tier), wire it into nav, and collapse configuration.mdx's inline angle-name list into a cross-link.

**Architecture:** Pure authored MDX content for the Fumadocs docs site. The new page uses the globally-available `Callout` / `Cards` / `Card` primitives (no imports, matching sibling pages) and Markdown tables. Three lockstep edits keep the site consistent: `meta.json` nav order, `configuration.mdx` list-to-link, and the `site/AGENTS.md` authored-pages enumeration. No application logic, no generator, no review-script changes. The build (`pnpm -C site build`) is the gate. Because there is no test runner for site content, each task is verified with concrete shell checks (grep / python3 / build) that fail before the edit and pass after.

**Tech Stack:** MDX, Fumadocs (Next.js), pnpm.

## Increment 1: Review-angles catalog page + lockstep wiring

> One independently shippable PR (<=500 LOC soft target) -- its own Graphite-stacked branch. The whole change is one cohesive docs addition, so it ships as a single increment.

### Task 1: Author the review-angles page

**Files:**
- Create: `site/content/docs/review-angles.mdx`

- [ ] **Step 1: Confirm the page does not yet exist (red)**
  Run: `test -f site/content/docs/review-angles.mdx && echo EXISTS || echo MISSING`
  Expected: `MISSING`

- [ ] **Step 2: Write the page**
  Create `site/content/docs/review-angles.mdx` with exactly this content:
  ````mdx
  ---
  title: Review angles
  description: The lenses woostack-review fans out across a diff: what each angle audits, when it auto-fires, and the model tier it runs at.
  ---

  woostack-review reviews a pull request through a set of **angles**. Each angle is one lens (correctness, security, SQL, accessibility, and so on), and the review fans out one subagent per active angle in parallel, then validates their findings. This page is the catalog of every angle. To turn angles on or off, see [Choosing angles](/docs/configuration#choosing-angles) in the configuration reference.

  ## How angles get chosen

  Three rules decide which angles run on a given pull request:

  1. **`bugs` and `security` always run.** They are on for every review and can never be skipped.
  2. **The other angles auto-detect from the diff.** Each one looks at the files the PR touches and the content of the diff, and turns itself on when it sees something relevant. A `.sql` file pulls in `database`; a `.tsx` file pulls in `react`.
  3. **You can override detection.** `review.angles.force` runs an angle whatever the diff looks like, and `review.angles.skip` keeps one off. `force` wins a tie, and `bugs` / `security` ignore `skip`. See [Choosing angles](/docs/configuration#choosing-angles).

  ## The catalog

  Every angle, what it reviews, a plain-language summary of when it auto-fires, and its model tier.

  | Angle | Audits | Fires when | Tier |
  | --- | --- | --- | --- |
  | `aeo` | Answer-engine optimization: AI-crawler access and structured data for answer engines | `robots.txt`, `llms.txt`, Markdown or HTML content, or AI-crawler / JSON-LD tokens in the diff | fast |
  | `api` | API contracts: routes, OpenAPI / GraphQL / proto schemas, HTTP handlers | OpenAPI / GraphQL / proto files, route trees, or HTTP-verb route bindings in the diff | standard |
  | `architecture` | Structural quality of source: boundaries, coupling, code health | any general-purpose source file changes (skips doc-only and config-only PRs) | standard |
  | `bugs` | Correctness: logic errors and broken behavior | always (cannot be skipped) | standard |
  | `comments` | Comment rot: whether code comments still match the code the PR changed | any general-purpose source file changes. Always non-blocking | fast |
  | `conventions` | Project rules: adherence to the repo's own AGENTS.md / CLAUDE.md and similar | the repo carries a rule file (AGENTS.md, CLAUDE.md, .cursorrules, .windsurfrules, GEMINI.md) along the changed paths | standard |
  | `database` | SQL correctness, row-level security, indexes, query plans | `.sql`, migration trees, ORM schema files, or SQL DDL / RLS / raw-SQL tokens in the diff | standard |
  | `deps` | Dependency hygiene: manifests and lockfiles | a dependency manifest or lockfile changes (package.json, pnpm-lock.yaml, go.mod, Cargo.toml, and the like) | fast |
  | `design` | Visual and UX heuristics for front-end changes | a styling or markup file changes (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, and similar) | standard |
  | `docs` | Documentation hygiene: READMEs, changelogs, Markdown | README, CHANGELOG, `docs/`, or `.md` / `.mdx` files change (a SKILL.md routes to `skills`) | fast |
  | `i18n` | Internationalization: translation catalogs and message usage | `locales/`, `messages/`, `i18n/`, `.po` files, or translation tokens in the diff | fast |
  | `infra` | Infrastructure: CI, containers, IaC, Kubernetes | workflow files, Dockerfiles, Terraform / Pulumi / CDK, k8s or helm trees, or IaC tokens in the diff | standard |
  | `observability` | Logging and error handling: silent failures and swallowed errors | logging or error-handling tokens in the diff (console / logger / Sentry / OpenTelemetry, swallowed catches, production mock fallbacks) | standard |
  | `react` | React correctness: Rules of Hooks and render behavior | a `.tsx` or `.jsx` file changes | standard |
  | `security` | Threat model: injection, auth, secrets, unsafe patterns | always (cannot be skipped) | standard |
  | `seo` | Search-engine optimization: meta tags, sitemaps, canonical URLs | HTML, head / layout files, `robots.txt`, `sitemap`, `next.config`, or SEO tokens in the diff | fast |
  | `skills` | Agent Skill authoring: a changed SKILL.md against the best-practices guide | a `SKILL.md` file changes anywhere in the diff | standard |
  | `tests` | Test coverage and quality | a test file changes (`.test.*`, `.spec.*`, `_test.*`, or `tests/` / `__tests__/` / `spec/` trees) | standard |
  | `types` | Type design: TypeScript invariants and signatures | a `.ts` / `.tsx` / `.cts` / `.mts` file changes | standard |

  The exact gating heuristics (file globs and diff-token patterns) live in [`detect-angles.sh`](https://github.com/howarewoo/woostack/blob/main/skills/woostack-review/scripts/detect-angles.sh), the source of truth. This table summarizes them in plain language.

  <Callout type="info">
    `bugs` and `security` run on every review and can never be skipped. Listing either under `review.angles.skip` is silently ignored.
  </Callout>

  <Callout type="info">
    Two angles behave specially. `comments` is always non-blocking: it posts nits, never a blocking finding. `conventions` only runs when the repo carries a rule file (AGENTS.md, CLAUDE.md, .cursorrules, .windsurfrules, or GEMINI.md) along the changed paths.
  </Callout>

  ## Tiers

  Each angle runs at a model tier matched to its work: `fast` for rubric and pattern checks, `standard` for reasoning-heavy passes. The skeptical validator that filters every finding runs at `deep`. The tier-to-model mapping per provider lives in [Core concepts](/docs/concepts#subagents-isolate-work), and you can override any tier in [Configuration](/docs/configuration#model-selection).

  ## Where to go next

  <Cards>
    <Card title="woostack-review" href="/docs/skills/woostack-review" description="The review engine that runs these angles." />
    <Card title="Configuration" href="/docs/configuration#choosing-angles" description="Force, skip, and tune angles in .woostack/config.json." />
    <Card title="Core concepts" href="/docs/concepts" description="The build loop, context economy, and model tiers." />
  </Cards>
  ````

- [ ] **Step 3: Confirm the page exists and is humanized (green)**
  Run: `test -f site/content/docs/review-angles.mdx && echo EXISTS`
  Expected: `EXISTS`
  Run: `grep -nP '[—–]' site/content/docs/review-angles.mdx && echo FOUND_DASH || echo NO_DASH`
  Expected: `NO_DASH` (no em/en dashes in the prose)

- [ ] **Step 4: Confirm the catalog covers exactly the 19 valid angles (green)**
  Run (line-number-independent: greps the `VALID_ANGLES` set wherever it lives in load-config.sh):
  ```bash
  diff \
    <(grep -oE '^\| `[a-z0-9]+`' site/content/docs/review-angles.mdx | tr -d '| `' | sort) \
    <(grep -m1 -F 'VALID_ANGLES = {' skills/woostack-review/scripts/load-config.sh | grep -oE '"[a-z0-9]+"' | tr -d '"' | sort) \
    && echo ANGLES_MATCH
  ```
  Expected: `ANGLES_MATCH` (empty diff: the table's angle column equals `VALID_ANGLES`, all 19)

- [ ] **Step 5: Commit**
  ```bash
  gt create -m "docs(site): add review-angles catalog page"
  ```

### Task 2: Wire nav and collapse configuration's angle list

**Files:**
- Modify: `site/content/docs/meta.json`
- Modify: `site/content/docs/configuration.mdx:82-84`

- [ ] **Step 1: Confirm nav and config list are in their pre-edit state (red)**
  Run: `python3 -c "import json; print(json.load(open('site/content/docs/meta.json'))['pages'])"`
  Expected: `['index', 'getting-started', 'concepts', 'configuration', 'skills']` (no `review-angles` yet)
  Run: `grep -q 'The valid angles are' site/content/docs/configuration.mdx && echo OLD_LIST_PRESENT`
  Expected: `OLD_LIST_PRESENT`

- [ ] **Step 2: Add the page to nav**
  Edit `site/content/docs/meta.json` so `pages` reads exactly:
  ```json
  {"title":"Docs","pages":["index","getting-started","concepts","configuration","review-angles","skills"]}
  ```

- [ ] **Step 3: Replace configuration's inline angle list with a cross-link**
  In `site/content/docs/configuration.mdx`, replace the three-line list under "### Choosing angles":
  ```
  The valid angles are: `aeo`, `api`, `architecture`, `bugs`, `comments`, `conventions`,
  `database`, `deps`, `design`, `docs`, `i18n`, `infra`, `observability`, `react`, `security`,
  `seo`, `skills`, `tests`, `types`.
  ```
  with:
  ```
  See [Review angles](/docs/review-angles) for the full catalog of all 19 angles: what each one
  audits, when it auto-fires, and its model tier.
  ```

- [ ] **Step 4: Confirm nav and link are wired (green)**
  Run:
  ```bash
  python3 -c "import json; d=json.load(open('site/content/docs/meta.json')); assert d['pages']==['index','getting-started','concepts','configuration','review-angles','skills'], d['pages']; print('NAV_OK')"
  ```
  Expected: `NAV_OK`
  Run: `grep -q '/docs/review-angles' site/content/docs/configuration.mdx && echo LINK_OK`
  Expected: `LINK_OK`
  Run: `grep -q 'The valid angles are' site/content/docs/configuration.mdx && echo OLD_LIST_PRESENT || echo OLD_LIST_GONE`
  Expected: `OLD_LIST_GONE`

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): link configuration angle list to the new catalog page"
  ```

### Task 3: Sync the authored-pages list and pass the build gate

**Files:**
- Modify: `site/AGENTS.md:18-19`

- [ ] **Step 1: Confirm the authored-pages list omits the new page (red)**
  Run: `grep -q 'review-angles.mdx' site/AGENTS.md && echo AGENTS_OK || echo AGENTS_MISSING`
  Expected: `AGENTS_MISSING`

- [ ] **Step 2: Add review-angles.mdx to the authored-pages enumeration**
  In `site/AGENTS.md`, the sentence currently reads:
  ```
  This rule covers the **authored** pages only: `content/docs/index.mdx`, `getting-started.mdx`,
  `concepts.mdx`, `configuration.mdx`, and the landing page.
  ```
  Change it to include the new page:
  ```
  This rule covers the **authored** pages only: `content/docs/index.mdx`, `getting-started.mdx`,
  `concepts.mdx`, `configuration.mdx`, `review-angles.mdx`, and the landing page.
  ```

- [ ] **Step 3: Confirm the list is synced (green)**
  Run: `grep -q 'review-angles.mdx' site/AGENTS.md && echo AGENTS_OK`
  Expected: `AGENTS_OK`

- [ ] **Step 4: Build the docs site (the gate)**
  Run: `pnpm -C site build`
  Expected: PASS. The `prebuild` hook runs `node scripts/gen-skills.mjs` (regenerating the gitignored per-skill pages from each `SKILL.md`), then `next build` compiles the site including the new `review-angles` route, with all internal links resolving.
  If the build fails on missing dependencies (`node_modules` absent in the working tree), run `pnpm -C site install` once and re-run the build.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): list review-angles.mdx as an authored page"
  ```

## Plan Checks

- **Spec coverage** — AC1 (page exists and builds) → Task 1 Step 3 + Task 3 Step 4; AC2 (catalog = exact 19 angles) → Task 1 Step 4; AC3 (no net duplication, canonical homes linked) → Task 1 Step 2 (detect-angles.sh + concepts links, plain-language triggers) and Task 2 (configuration list → cross-link); AC4 (humanized + authored-list synced) → Task 1 Step 3 (NO_DASH) and Task 3.
- **AC coverage** — every AC and each filled happy/error/edge case maps to a concrete check above; §7 has no whole-section N/A.
- **No placeholders** — the full page MDX is inline in Task 1 Step 2; every check carries an exact command and expected output.
- **Type consistency** — angle names in the catalog match `VALID_ANGLES` exactly (pinned by the Task 1 Step 4 diff); tiers match each angle prompt's `tier:` frontmatter; nav array and cross-link anchors (`#choosing-angles`, `#subagents-isolate-work`, `#model-selection`) match the current pages.
