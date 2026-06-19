---
name: 2026-06-19-seo-angle-refine
type: spec
status: approved
date: 2026-06-19
branch: feature/seo-angle-refine
links:
---

# Refine SEO review angle — tiered gate + claude-seo rubric learnings — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-19-seo-angle-refine]]

## 1. Problem

The `seo` review angle in `woostack-review` **fires too often** on PRs with no SEO relevance, and its rubric (`prompts/angles/seo.md`) has drifted behind current search guidance.

Gating (`scripts/detect-angles.sh`) enables `seo` on broad file signals with **no SEO co-signal**:

- `*.html` → fires on *any* HTML file: test fixtures, email templates, storybook stories, component fragments, generated `woostack-visualize` output.
- `head.{ts,tsx,js,jsx}` / `layout.{ts,tsx,js,jsx}` → fires on *every* layout/head edit, the majority of which are structural or styling changes with no metadata impact.
- `next.config.{js,ts,mjs}` → fires on *any* Next config edit (webpack, env, images, redirects), mostly non-SEO.

Each false fire spawns a Haiku angle worker, adds noise to the review, and trains authors to ignore the gate.

Separately, the rubric lacks concrete current thresholds (Core Web Vitals targets), treats canonical only as missing/wrong (not broken chains), has no falsifiability discipline (findings can be speculative), and has no suppressor for client-rendered routes a static diff cannot evaluate. The sibling `aeo` angle still frames `HowTo`/`FAQPage` schema removal as a rich-result regression, which is stale.

## 2. Goal

1. **Cut SEO over-firing** by moving the broad file signals behind an SEO diff-token co-signal, while keeping unambiguous SEO surfaces firing on path alone.
2. **Sharpen the `seo` rubric** with targeted, current learnings ported from [AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo): exact CWV targets, canonical-chain checks, a falsifiability rule, and an SPA/hydration noise suppressor.
3. **Refresh the `aeo` rubric** so deprecated structured-data types are framed as AI/entity signals rather than rich-result regressions, plus the same falsifiability discipline.

Gate change is **`seo`-only**; `aeo` gating is unchanged (the reported pain is SEO firing too much).

## 3. Non-goals

- No new review angle; no change to `VALID_ANGLES`, `_header.md`, `load-config.sh`, or the finding schema.
- No wholesale port of claude-seo's 25-skill live-crawl auditor — its rendered-page + Google-API checks are out of scope for a static diff reviewer.
- No change to the `aeo` **gate** (only its prompt content).
- No change to SEO's tier (`fast`/Haiku) or model routing.
- No re-scoping of which angle owns schema/JSON-LD: `aeo` keeps it; `seo` keeps OG/Twitter card mechanics, canonical, hreflang, CWV, crawl/index.

## 4. Approach

### 4a. Gate — tiered co-signal (`scripts/detect-angles.sh`)

The token check `has_seo_diff_token()` already fires `seo` regardless of which file changed. So "soft files need a token" reduces mechanically to **drop the soft files from the path check and widen the token check** — no new gate condition or co-location slicing required.

- `has_seo_file()` — keep **only** the unambiguous SEO surfaces: `robots.txt`, `sitemap.{xml,ts}`, `app/manifest.{ts,json}`. Remove `*.html`, `head/layout.*`, `next.config.*`.
- `has_seo_diff_token()` — keep the existing alternation (`<meta`, `og:`, `twitter:`, `rel=canonical`, `name=robots`, `<loc>`, `Sitemap:`) unchanged, and add a **second, changed-line-anchored** check for the Next.js / metadata co-signals that real SEO edits to soft files carry: `generateMetadata`, `export const metadata`, `hreflang`, matched `^[+-]` so both **additions and removals** fire (removing `generateMetadata` is itself an SEO regression). Anchoring to changed lines means a styling-only `layout.tsx` with an *unchanged* `generateMetadata` elsewhere in the file does **not** fire.
  - Deliberately **excluded** candidates: `<title` (collides with SVG `<title>`, ubiquitous in icon components) and `<link rel=` (collides with `<link rel="stylesheet|preload|icon">`; the SEO links — `rel=canonical` and `hreflang` — are already covered). Tradeoff: a plain-HTML page whose only SEO change is a `<title>` edit with no `<meta>`/metadata export won't fire — acceptable for the noise-cut goal.
- The gate line `if has_seo_file || has_seo_diff_token; then ANGLES+=("seo"); fi` is **unchanged** (the new anchored check lives inside `has_seo_diff_token`, which `return 0`s on either sub-check).
- The **doc-comment block** at the top of `detect-angles.sh` (the `seo —` lines) is the lockstep partner of these functions and is rewritten to describe the tiered behavior. (See [[wisdom/lockstep-edit-sites]].)

Resulting behavior:

| PR change | Before | After |
|---|---|---|
| `layout.tsx` restyle, no metadata | seo fires | **skips** |
| `layout.tsx` editing `generateMetadata` | seo fires | seo fires |
| `*.html` fixture/email, no SEO tags | seo fires | **skips** |
| `*.html` page with `<meta>`/`<title>` | seo fires | seo fires |
| `next.config.ts` alone (webpack/env) | seo fires | **skips** |
| `robots.txt` / `sitemap.xml` / `app/manifest.ts` | seo fires | seo fires |
| any diff carrying `og:`/canonical/etc. | seo fires | seo fires |

### 4b. `seo` rubric enrichment (`prompts/angles/seo.md`)

- **CWV targets** — add exact thresholds to §2: LCP < 2.5s, INP < 200ms, CLS < 0.1.
- **Canonical chains** — extend the §3 canonical bullet beyond missing/wrong to: broken canonical chains, non-self-referencing canonical, and canonical conflicting with `noindex`.
- **Falsifiability** — one rubric line: every finding must cite the observable diff fact it is grounded in; reject speculative "could be improved" with no concrete regression in the diff.
- **SPA suppressor** — a Skip rule: do not flag content-depth or CWV on routes that are clearly client-rendered in the diff with no SSR/metadata surface, because a static diff cannot observe the rendered output (matches claude-seo's stated hydration-noise limitation).

### 4c. `aeo` rubric refresh (`prompts/angles/aeo.md`)

- **Schema deprecation** — reframe §4: `HowTo` (deprecated 2023) and `FAQPage` no longer yield Google rich results for most sites; treat their presence/absence as an AI/entity signal, not a rich-result regression. Note JSON-LD is the preferred serialization. Conservative phrasing — no fabricated exact dates.
- **Falsifiability** — mirror the `seo` falsifiability line.

## 5. Components & data flow

- `scripts/detect-angles.sh` — `has_seo_file()`, `has_seo_diff_token()`, and the top-of-file doc comment. Consumes `$OUTDIR/{meta.json,diff.txt}` (and `*.filtered` variants); appends `seo` to `ANGLES`; writes `$OUTDIR/angles.{txt,json}`. No interface change — same inputs/outputs, narrower gate.
- `prompts/angles/seo.md` — rubric markdown read by the `seo` angle worker; `tier: fast` frontmatter unchanged; output contract (`findings.seo.json`, schema in `_header.md`) unchanged.
- `prompts/angles/aeo.md` — rubric markdown read by the `aeo` angle worker; unchanged contract.
- **New** `scripts/tests/test-detect-angles-seo.sh` — follows the `test-detect-angles-observability.sh` harness (`setup_diff` writing `meta.json` + `diff.txt`, asserting on `angles.txt`).

No downstream consumer changes: angle workers, `merge-findings.sh`, `intersect-findings.sh`, and the validator are agnostic to which angles fire.

## 6. Error handling

- Gate runs under `set -euo pipefail`; `grep -qE` returns non-zero on no-match, which the `||`/`return 1` structure already absorbs — narrowing the patterns does not introduce new failure modes.
- Empty / sub-threshold diff: `has_seo_file` and `has_seo_diff_token` both return false → `seo` simply absent from `ANGLES` (existing behavior, no error).
- Widened token alternation must stay valid ERE; a malformed pattern would make `grep` exit non-zero under `pipefail` and abort detection — covered by running the existing detect-angles test suite plus the new SEO test.
- No untrusted input is parsed beyond the already-trusted prefetched diff; no new secrets, network, or filesystem surface.

## 7. Acceptance criteria

> **Angle pre-flight.** security: no new input/secret/network surface (grep over already-trusted prefetch artifacts) — N/A. observability: gate still emits `angles.{txt,json}`; no logging change — N/A. api/database: N/A. edge/error: covered by AC1 edge rows below.

- **AC1 — SEO gate fires only on hard files or an SEO token**
  - happy: a diff changing `robots.txt` (or `sitemap.xml`, or `app/manifest.ts`) enables `seo`; a diff whose body carries `og:`/`<meta`/`rel=canonical` enables `seo`.
  - error: a `layout.tsx` whose only change is `generateMetadata`/`export const metadata`/`hreflang` (added **or removed**) enables `seo` (changed-line token co-signal present).
  - edge: a `layout.tsx` restyle with no metadata token — even with an *unchanged* `generateMetadata` elsewhere in the file — does **not** enable `seo`; a `*.html` fixture with no SEO tags does **not** enable `seo`; `next.config.ts` alone does **not** enable `seo`; an added SVG `<title>`/`<link rel="stylesheet">` does **not** enable `seo` (excluded tokens).
- **AC2 — Unrelated angles and `aeo` gating are unchanged**
  - happy: `bugs` + `security` still always present; `aeo` still fires on its existing signals (`robots.txt`, `*.md`, AI-crawler tokens, JSON-LD types).
  - error: a `*.html` with `<meta>` enables both `seo` and `aeo` (each per its own gate) without one suppressing the other.
  - edge: the existing `detect-angles` test suite (`test-detect-angles-{comments,skills,observability}.sh`) still passes — the SEO narrowing does not regress other angle gates.
- **AC3 — `seo.md` rubric carries the new learnings**
  - happy: §2 states LCP/INP/CLS numeric targets; §3 canonical bullet covers chains/self-ref/noindex-conflict; a falsifiability line and an SPA-suppressor Skip rule are present.
  - error: N/A — markdown rubric, no runtime error path.
  - edge: existing output contract (`angle: "seo"`, `title/description/fix/fix_type`, `_header.md` schema) is untouched.
- **AC4 — `aeo.md` rubric reframes deprecated schema + adds falsifiability**
  - happy: §4 frames `HowTo`/`FAQPage` as AI/entity signals (not rich-result regressions), notes JSON-LD preference; a falsifiability line is present.
  - error: N/A — markdown rubric.
  - edge: `aeo`'s "do not double-report `seo`" boundary remains intact.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

- **Gate:** new `scripts/tests/test-detect-angles-seo.sh` modeled on `test-detect-angles-observability.sh` — `setup_diff <path> <added-line>`, run `detect-angles.sh`, assert presence/absence of `seo` in `$OUTDIR/angles.txt`. Cases: robots→yes, sitemap→yes, manifest→yes, layout-restyle→no, layout+`generateMetadata`(added)→yes, `generateMetadata`-removed (`^-`)→yes, html-no-token→no, html+`<meta>`→yes, next.config→no, SVG `<title>`→no, `<link rel="stylesheet">`→no. (`setup_diff` may need a removed-line variant or a raw-diff helper to exercise the `^-` case.)
- **Regression:** run the full `scripts/tests/test-detect-angles-*.sh` set to confirm no other angle gate regressed.
- **Prompts:** no runtime test (markdown). Verification is review-time: the `seo`/`aeo` workers still produce schema-valid `findings.*.json` (contract unchanged). Manual: spot-confirm the doc-comment block matches the function logic.

## 9. Open questions

- None blocking. Resolved during ideation: tiered co-signal over denylist; SEO-only gate change; `next.config` dropped from the gate entirely; conservative (no exact-date) phrasing for schema-deprecation claims.
- Resolved during spec harden: **precise token matching** — new metadata tokens (`generateMetadata`, `export const metadata`, `hreflang`) matched changed-line-anchored (`^[+-]`, additions + removals); `<title` and `<link rel=` **excluded** (SVG `<title>` / stylesheet-link collisions; `rel=canonical` + `hreflang` already cover SEO links). Accepted tradeoff: a plain-HTML title-only edit with no `<meta>`/metadata export won't fire.
