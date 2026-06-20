---
type: plan
source: .woostack/specs/2026-06-19-seo-angle-refine.md
status: ready
branch: feature/seo-angle-refine
---

**Source:** [[specs/2026-06-19-seo-angle-refine]]

# Refine SEO review angle — tiered gate + claude-seo rubric learnings — Implementation Plan

**Goal:** Cut `seo` review-angle over-firing by gating soft files behind an SEO diff-token co-signal, and sharpen the `seo`/`aeo` rubrics with targeted current learnings.

**Architecture:** Two independent, linearly-stacked increments. **Increment 1** rewrites the `seo` gate in `scripts/detect-angles.sh` (hard files fire on path; soft files need a changed-line-anchored metadata token) plus its lockstep doc-comment, pinned by a new committed gating test. **Increment 2** edits the two rubric prompts (`seo.md`, `aeo.md`) — markdown only, no runtime behavior. No change to `VALID_ANGLES`, `_header.md`, `load-config.sh`, the finding schema, SEO's `fast` tier, or `aeo` gating.

**Tech Stack:** Bash (`set -euo pipefail`, `grep -qE` ERE), the `skills/woostack-init/scripts/tests/assert.sh` test helper, Markdown prompts.

**Lockstep note (wisdom: [[lockstep-edit-sites]]):** a gate edit moves 3 sites together — the predicate functions, the top-of-file doc-comment catalog, and the committed gating test. No other angle-wiring site changes here: `seo` stays a valid angle (so `load-config.sh` VALID_ANGLES, `_header.md` catalog/footer/count, `anthropic.md` `fast` tier, and SKILL.md's defer-to-script line are all untouched). `aeo` gating is unchanged.

---

## Increment 1: Tiered SEO gate + committed gating test

> One independently shippable PR — rewrites the `seo` gate and pins it with a structural test. Base of the increment stack (stacks on the spec+plan PR).

### Task 1: Narrow the `seo` gate to hard-file OR token, behind a red→green test

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-detect-angles-seo.sh`
- Modify: `skills/woostack-review/scripts/detect-angles.sh` (`has_seo_file`, `has_seo_diff_token`, doc-comment block)

- [x] **Step 1: Write the failing test**
  Create `skills/woostack-review/scripts/tests/test-detect-angles-seo.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/detect-angles.sh"

  # setup $1 = changed file path, $2 = diff body (may be multi-line; literal +/- prefixes)
  setup_diff() {
    work="$(mktemp -d)"
    export OUTDIR="$work/out"
    mkdir -p "$OUTDIR"
    printf '{"files":[{"path":"%s"}]}\n' "$1" > "$OUTDIR/meta.json"
    printf '%s\n' "$2" > "$OUTDIR/diff.txt"
  }
  absent() { grep -cx 'seo' "$OUTDIR/angles.txt" || true; }  # "0" when seo not enabled

  # 1. HARD file: robots.txt fires on path alone (no token needed).
  setup_diff "public/robots.txt" "+Disallow: /tmp"
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "robots.txt enables seo on path alone"
  assert_contains "$(cat "$OUTDIR/angles.txt")" "bugs" "bugs always on"
  rm -rf "$work"

  # 2. HARD file: sitemap.xml fires on path alone.
  setup_diff "app/sitemap.xml" "+  <loc>https://x.com/</loc>"
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "sitemap.xml enables seo"
  rm -rf "$work"

  # 3. HARD file: app/manifest.ts fires on path alone.
  setup_diff "app/manifest.ts" "+  name: 'X',"
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "app/manifest.ts enables seo"
  rm -rf "$work"

  # 4. SOFT file, no token: layout.tsx restyle does NOT enable seo.
  setup_diff "app/layout.tsx" '+  <div className="wrap">'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "layout.tsx restyle does not enable seo"
  rm -rf "$work"

  # 5. SOFT file + metadata co-signal (added): generateMetadata enables seo.
  setup_diff "app/layout.tsx" '+export async function generateMetadata() {'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "added generateMetadata enables seo"
  rm -rf "$work"

  # 6. SOFT file + metadata co-signal (REMOVED): a removed export is an SEO regression.
  setup_diff "app/page.tsx" '-export const metadata = { title: "Old" }'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "removed metadata export enables seo"
  rm -rf "$work"

  # 7. SOFT file, no token: *.html with no SEO tag does NOT enable seo.
  setup_diff "emails/welcome.html" '+  <div>Hello</div>'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "html with no SEO tag does not enable seo"
  rm -rf "$work"

  # 8. SOFT file + token: *.html with <meta> enables seo.
  setup_diff "public/index.html" '+  <meta name="description" content="x">'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "html with <meta> enables seo"
  rm -rf "$work"

  # 9. SOFT file, no token: next.config.ts alone does NOT enable seo.
  setup_diff "next.config.ts" '+  images: { remotePatterns: [] },'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "next.config.ts alone does not enable seo"
  rm -rf "$work"

  # 10. Excluded token: SVG <title> does NOT enable seo (collision guard).
  setup_diff "components/Icon.tsx" '+    <title>Close</title>'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "SVG <title> does not enable seo"
  rm -rf "$work"

  # 11. Excluded token: <link rel="stylesheet"> does NOT enable seo.
  setup_diff "app/layout.tsx" '+  <link rel="stylesheet" href="/x.css">'
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "link rel=stylesheet does not enable seo"
  rm -rf "$work"

  # 12. Anchoring: an UNCHANGED (context) metadata line does NOT enable seo.
  setup_diff "app/layout.tsx" "$(printf '+  <div className="x">\n   export const metadata = { title: "keep" }')"
  bash "$SCRIPT" >/dev/null 2>&1
  assert_eq "$(absent)" "0" "unchanged-context metadata does not enable seo"
  rm -rf "$work"

  finish
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-review/scripts/tests/test-detect-angles-seo.sh`
  Expected: FAIL — the current gate fires `seo` on every soft file, so cases 4, 7, 9, 10, 11, 12 fail, e.g.:
  ```
    FAIL: layout.tsx restyle does not enable seo
      expected: [0]
      actual:   [1]
    FAIL: next.config.ts alone does not enable seo
    ...
    N passed, 6 failed
  ```
  (exit 1 from `finish`)

- [x] **Step 3: Narrow `has_seo_file` to hard files only**
  In `skills/woostack-review/scripts/detect-angles.sh`, replace the `has_seo_file` function:
  ```bash
  has_seo_file() {
    echo "$CHANGED_PATHS" | grep -qE '(^|/)(robots\.txt|sitemap\.(xml|ts)|next\.config\.(js|ts|mjs))$' && return 0
    echo "$CHANGED_PATHS" | grep -qE '\.html$' && return 0
    echo "$CHANGED_PATHS" | grep -qE '(^|/)(head|layout)\.(ts|tsx|js|jsx)$' && return 0
    echo "$CHANGED_PATHS" | grep -qE '(^|/)app/manifest\.(ts|json)$' && return 0
    return 1
  }
  ```
  with (hard SEO surfaces only):
  ```bash
  has_seo_file() {
    # Hard SEO surfaces only — unambiguous, fire on path alone. Soft surfaces
    # (*.html, head/layout.*, next.config.*) now gate on a diff token co-signal
    # in has_seo_diff_token() to cut over-firing on non-SEO edits.
    echo "$CHANGED_PATHS" | grep -qE '(^|/)(robots\.txt|sitemap\.(xml|ts))$' && return 0
    echo "$CHANGED_PATHS" | grep -qE '(^|/)app/manifest\.(ts|json)$' && return 0
    return 1
  }
  ```

- [x] **Step 4: Add the changed-line-anchored metadata co-signal to `has_seo_diff_token`**
  Replace the `has_seo_diff_token` function:
  ```bash
  has_seo_diff_token() {
    # Anchored to reduce false positives in docs/comments/JSON keys.
    # Matches: meta tags, og:/twitter: prefixed props, rel=canonical, name=robots,
    # <loc> sitemap entries, Sitemap: directive.
    grep -qE "</?meta\b|\bog:[a-z_-]+|\btwitter:[a-z_-]+|rel=[\"']canonical|name=[\"']robots|<loc>|(^|[[:space:]])Sitemap:" "$DIFF"
  }
  ```
  with (legacy tokens unchanged + a second, changed-line-anchored metadata check):
  ```bash
  has_seo_diff_token() {
    # Legacy unanchored tokens: meta tags, og:/twitter: prefixed props, rel=canonical,
    # name=robots, <loc> sitemap entries, Sitemap: directive.
    grep -qE "</?meta\b|\bog:[a-z_-]+|\btwitter:[a-z_-]+|rel=[\"']canonical|name=[\"']robots|<loc>|(^|[[:space:]])Sitemap:" "$DIFF" && return 0
    # Soft-surface co-signal: Next.js metadata edits in head/layout/*.html files.
    # Anchored to CHANGED lines (^[+-]) so a styling-only edit near an unchanged
    # metadata export does not fire, and a REMOVED export (an SEO regression) does.
    # <title and <link rel= are intentionally excluded (SVG <title> / stylesheet-link
    # collisions; rel=canonical + hreflang already cover SEO links).
    grep -qE "^[+-].*(\bgenerateMetadata\b|export[[:space:]]+const[[:space:]]+metadata\b|\bhreflang\b)" "$DIFF" && return 0
    return 1
  }
  ```

- [x] **Step 5: Update the lockstep doc-comment catalog**
  In the same file, replace the `seo` lines in the top-of-file "Angle gating:" comment block:
  ```
  #   seo       — *.html, head.{ts,tsx}, layout.{ts,tsx}, robots.txt, sitemap.{xml,ts},
  #               next.config.{js,ts,mjs}, app/manifest.{ts,json}, OR diff body
  #               contains <meta / og: / twitter: / canonical / robots / sitemap
  ```
  with:
  ```
  #   seo       — HARD files (fire on path alone): robots.txt, sitemap.{xml,ts},
  #               app/manifest.{ts,json}. SOFT surfaces (*.html, head/layout.{ts,tsx,js,jsx},
  #               next.config.*) no longer gate on path — they fire only via a diff token:
  #               legacy <meta / og: / twitter: / rel=canonical / name=robots / <loc> /
  #               Sitemap:, OR a changed-line (^[+-]) metadata co-signal generateMetadata /
  #               export const metadata / hreflang (additions and removals). <title and
  #               <link rel= are excluded (SVG <title> / stylesheet-link collisions).
  ```

- [x] **Step 6: Run the test, confirm it passes**
  Run: `bash skills/woostack-review/scripts/tests/test-detect-angles-seo.sh`
  Expected: PASS — `  13 passed, 0 failed` (exit 0). ✓ Observed `13 passed, 0 failed`.

- [x] **Step 7: Regression — run the sibling detect-angles tests**
  Run:
  ```bash
  for t in skills/woostack-review/scripts/tests/test-detect-angles-*.sh; do
    echo "== $t =="; bash "$t" || exit 1
  done
  ```
  Expected: every file ends `… 0 failed`; loop exits 0. Confirms the SEO narrowing did not regress `comments`, `skills`, or `observability` gates.

- [x] **Step 8: Syntax check + commit**
  Run: `bash -n skills/woostack-review/scripts/detect-angles.sh && echo OK`
  Expected: `OK`
  ```bash
  gt create -m "fix(review): gate seo angle behind hard-file or metadata token"
  ```

---

## Increment 2: SEO + AEO rubric enrichment

> One independently shippable PR — markdown rubric edits only, no runtime behavior. Stacks on Increment 1.

### Task 1: Enrich `seo.md` (CWV targets, canonical chains, SPA suppressor, falsifiability)

**Files:**
- Modify: `skills/woostack-review/prompts/angles/seo.md`

- [x] **Step 1: Verify the new content is absent (red)**
  Run: `grep -c "2.5s" skills/woostack-review/prompts/angles/seo.md || true`
  Expected: `0` (no CWV numeric target yet).

- [x] **Step 2: Add Core Web Vitals numeric targets**
  Replace:
  ```
  - **Core Web Vitals**: Detect potential LCP, INP, or CLS regressions in the diff (e.g., large unoptimized images, layout shifts).
  ```
  with:
  ```
  - **Core Web Vitals**: Detect potential LCP (target < 2.5s), INP (< 200ms), or CLS (< 0.1) regressions in the diff (e.g., large unoptimized images, layout shifts, render-blocking resources).
  ```

- [x] **Step 3: Extend the canonical check to chains / self-ref / noindex conflict**
  Replace:
  ```
  - **Canonical & Hreflang**: Missing or wrong `<link rel="canonical">` or `hreflang` mismatches on i18n/new pages.
  ```
  with:
  ```
  - **Canonical & Hreflang**: Missing, wrong, or broken canonical chains (`<link rel="canonical">` pointing through a redirect or to a non-200), non-self-referencing canonicals, a canonical that conflicts with a `noindex` on the same page, or `hreflang` mismatches on i18n/new pages.
  ```

- [x] **Step 4: Add SPA suppressor + falsifiability to the Skip list**
  Replace:
  ```
  ## Skip
  - Internal admin / authenticated pages (should not be indexable).
  - Style-only changes to existing SEO-correct pages.
  - Pre-existing missing metadata not touched by this PR.
  ```
  with:
  ```
  ## Skip
  - Internal admin / authenticated pages (should not be indexable).
  - Style-only changes to existing SEO-correct pages.
  - Pre-existing missing metadata not touched by this PR.
  - Client-rendered routes with no SSR/metadata surface in the diff — a static diff cannot observe the rendered output, so do not flag content-depth or Core Web Vitals there (heavy client-side hydration produces noisy, unverifiable findings).
  - Speculative "could rank better?" suggestions without a concrete regression in the diff — every finding must cite the observable diff fact it is grounded in.
  ```

- [x] **Step 5: Verify present + output contract intact (green)**
  Run:
  ```bash
  grep -q "target < 2.5s" skills/woostack-review/prompts/angles/seo.md \
    && grep -q "broken canonical chains" skills/woostack-review/prompts/angles/seo.md \
    && grep -q "cannot observe the rendered output" skills/woostack-review/prompts/angles/seo.md \
    && grep -q "must cite the observable diff fact" skills/woostack-review/prompts/angles/seo.md \
    && grep -q 'findings.seo.json' skills/woostack-review/prompts/angles/seo.md \
    && echo OK
  ```
  Expected: `OK` (all four additions present; the `findings.seo.json` output contract line is untouched).

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "docs(review): sharpen seo rubric (CWV targets, canonical chains, SPA + falsifiability)"
  ```

### Task 2: Refresh `aeo.md` structured-data framing

**Files:**
- Modify: `skills/woostack-review/prompts/angles/aeo.md`

- [x] **Step 1: Verify the reframe is absent (red), falsifiability already present**
  Run:
  ```bash
  grep -c "AI/entity signals" skills/woostack-review/prompts/angles/aeo.md || true
  grep -q "without a concrete regression in the diff" skills/woostack-review/prompts/angles/aeo.md && echo "falsifiability-present"
  ```
  Expected: first prints `0` (reframe not yet added); second prints `falsifiability-present` — AC4's falsifiability line already exists (Skip list), so this task only reframes schema.

- [x] **Step 2: Reframe `### 4. Structured data for AI`**
  Replace:
  ```
  ### 4. Structured data for AI (P2)
  - Removed or broken `FAQPage`, `HowTo`, `Article`/`BlogPosting`, `Product`, `ItemList`, `Review`/`AggregateRating`, `Organization` schema on content where it applied.
  - New FAQ / comparison / how-to content shipped without matching schema.
  - Schema introduced that mis-describes the page (would mislead AI extraction).
  ```
  with:
  ```
  ### 4. Structured data for AI (P2)
  - Prefer **JSON-LD** (the format AI extractors and Google both favor) over inline microdata / RDFa.
  - Removed or broken `Article`/`BlogPosting`, `Product`, `ItemList`, `Review`/`AggregateRating`, `Organization` schema on content where it applied.
  - `HowTo` and `FAQPage` no longer produce Google rich results for most sites — treat them as **AI/entity signals**, not rich-result regressions: flag mis-describing or invalid markup, not the mere absence of a rich result.
  - New FAQ / comparison / how-to content shipped without matching schema.
  - Schema introduced that mis-describes the page (would mislead AI extraction).
  ```

- [x] **Step 3: Align the severity rubric with the reframe (lockstep)**
  The MEDIUM severity line still treats schema *removal* as a finding, contradicting the §4 reframe. Replace:
  ```
  - `MEDIUM` + `blocking: false` — Lost citations / statistics / author attribution; FAQ or HowTo schema removed or malformed; answer passages buried below filler; comparison tables converted to prose; missing `/pricing.md` companion for new pricing page.
  ```
  with:
  ```
  - `MEDIUM` + `blocking: false` — Lost citations / statistics / author attribution; FAQ or HowTo schema malformed or mis-describing content (not its mere absence — see §4); answer passages buried below filler; comparison tables converted to prose; missing `/pricing.md` companion for new pricing page.
  ```

- [x] **Step 4: Verify present + double-report boundary intact (green)**
  Run:
  ```bash
  grep -q "AI/entity signals" skills/woostack-review/prompts/angles/aeo.md \
    && grep -q "Prefer \*\*JSON-LD\*\*" skills/woostack-review/prompts/angles/aeo.md \
    && grep -q "malformed or mis-describing content" skills/woostack-review/prompts/angles/aeo.md \
    && grep -q "do not double-report" skills/woostack-review/prompts/angles/aeo.md \
    && echo OK
  ```
  Expected: `OK` (reframe + severity-line alignment present; the `seo`-boundary "do not double-report" Skip line is untouched).

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(review): reframe aeo structured-data as AI/entity signals"
  ```

---

## Plan Checks

- **Spec coverage** — §4a gate → Increment 1; §4b `seo.md` → Inc 2 Task 1; §4c `aeo.md` → Inc 2 Task 2; §8 test strategy → Inc 1 Steps 1-2,6-7. All covered.
- **AC coverage** — AC1 (gate fires on hard file/token; soft-no-token/SVG/stylesheet/next.config/unchanged-context skip; added+removed metadata fire) → Inc 1 test cases 1-12. AC2 (bugs/security on; aeo gate unchanged; sibling tests pass) → Inc 1 case 1 (`bugs`) + Step 7 regression. AC3 (`seo.md` learnings) → Inc 2 Task 1 Steps 2-5. AC4 (`aeo.md` reframe + JSON-LD; falsifiability present) → Inc 2 Task 2 (falsifiability pre-satisfied, verified Step 1). Every filled happy/error/edge maps to a step.
- **No placeholders** — every step carries full file content / exact `grep`/`bash` commands with expected output. No TBD/TODO.
- **Type consistency** — token names (`generateMetadata`, `export const metadata`, `hreflang`) identical across the gate function, the doc-comment, and the test; the excluded tokens (`<title`, `<link rel=`) named identically in all three.
- **Angle coverage** (plan lens) — architecture: 2 single-responsibility increments (gate vs prose), no layer leak. tests: each AC maps to a committed gate-test case or a `grep` verification; the load-bearing gate is backed by a structural test (wisdom: [[autonomy-needs-structural-proof]]). security/observability: no new input/secret/network surface; gate still emits `angles.{txt,json}` unchanged. Lockstep (doc-comment + function + test) walked per [[lockstep-edit-sites]]. No deferral markers — increments share no open gap.
