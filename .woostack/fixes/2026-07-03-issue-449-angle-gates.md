---
type: fix
status: hardened
branch: fix/issue-449-angle-gates
---

# Fix: Reduce zero-signal review angle fan-out

## 1. Root Cause

Issue #449 reports that several review angles, especially `aeo` and `seo`, launch on many PRs but produce no blocking findings in consumer metrics. The root cause is over-broad angle detection plus missing aggregate feedback:

- `skills/woostack-review/scripts/detect-angles.sh` treats every changed `*.md`, `*.mdx`, or `*.html` file as AEO-relevant (`has_aeo_file`), so ordinary README, `SKILL.md`, changelog, or generic HTML changes launch the AEO worker even when the diff has no AI-answer-engine surface. The AEO prompt is narrower: crawler access, `llms.txt`, pricing/product content, JSON-LD/schema, answer passages, and citability. Synthetic reproduction in the diagnosis showed a README typo diff and a prose-only `SKILL.md` diff both enabling `aeo`.
- `has_seo_diff_token()` scans the whole diff and `detect-angles.sh` enables `seo` when any SEO token appears anywhere. That means a backend/API/source file containing `generateMetadata`, `export const metadata`, `hreflang`, or legacy meta/canonical/sitemap tokens can launch SEO without being an SEO/head/content surface. Existing SEO tests cover positive soft surfaces and some negatives, but not the backend/source-token leak.
- `skills/woostack-review/scripts/metrics-fold.sh` already folds per-angle `runs_present`, `raw_total`, `kept_total`, `blocking_total`, and `nit_total`, but it only prints a generic folded-run message. The docs provide a manual validator-drop ranking query, which misses zero-ever angles (`raw_total == 0`) and gives users no data-driven `review.angles.skip` suggestion.

Relevant repo memory from diagnosis: angle triggers must be high-signal, angle changes require detection tests, and docs/tests must be updated lockstep with review-script changes.

## 2. Proposed Fix

Make the review angle gates match the prompts and add advisory-only metrics feedback:

- Tighten AEO path detection so only high-signal hard surfaces fire by path alone: `robots.txt`, `llms.txt`, and pricing pages/files. Add a narrow public-content predicate for marketing/content/blog/docs-site/pricing/product/landing page markdown/MDX/HTML. Do not fire AEO for arbitrary `README.md`, `SKILL.md`, changelog, internal docs, generic docs paths, or generic HTML unless the diff contains an AEO token.
- Tighten SEO token detection by requiring soft SEO/content paths before soft tokens can enable `seo`. Keep existing hard SEO path triggers for `robots.txt`, `sitemap.{xml,ts}`, and `app/manifest.{ts,json}` because `test-detect-angles-seo.sh` already treats `app/manifest.ts` as an intentional path-alone SEO surface.
- Add metrics-fold skip advisories after aggregation. When `review.metrics: true` and `ANGLE_SKIP_SUGGEST_MIN_RUNS=20` is met, print non-mutating suggestions for zero-kept/zero-blocking or nit-only/no-blocking angles, pointing users to `review.angles.skip`. Do not edit `.woostack/config.json` automatically, and never suggest unskippable core angles (`bugs`, `security`, `simplify`).
- Update `woostack-review/SKILL.md` Stage 6.5 to document the advisory output and correct the aggregate schema version already used by `metrics-fold.sh`. Authored docs-site pages that summarize angle selection or metrics also need lockstep updates: `site/content/docs/configuration.mdx` and `site/content/docs/concepts/review-angles.mdx`.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with failing detection tests**
  - Add `skills/woostack-review/scripts/tests/test-detect-angles-aeo.sh` covering:
    - `README.md` prose-only diff does not enable `aeo` and still enables `docs`.
    - `skills/example/SKILL.md` prose-only diff does not enable `aeo` and still enables `skills`.
    - `public/llms.txt` and/or `public/robots.txt` still enables `aeo` by path.
    - A selected public-content/pricing path, such as `content/blog/answer-engines.mdx` or `app/pricing/page.mdx`, still enables `aeo`.
    - A generic internal docs markdown path does not enable `aeo` unless it includes an AEO token.
    - A diff containing an AEO token such as `GPTBot` or JSON-LD `"@type": "Article"` still enables `aeo`.
  - Extend `skills/woostack-review/scripts/tests/test-detect-angles-seo.sh` so `app/api/users/route.ts` with `+export const metadata = { internal: true }` and a non-SEO source file with `+const hreflang = "en"` do not enable `seo`.
  - Run the new/changed detection tests before implementation and confirm the new cases fail for the current gate behavior.

- [ ] **Step 2: Reproduce with failing metrics-fold tests**
  - Add `skills/woostack-review/scripts/tests/test-metrics-fold-suggestions.sh` covering:
    - An angle at the sample-size threshold with `raw_total=0`, `kept_total=0`, and `blocking_total=0` prints a `consider review.angles.skip` advisory.
    - An angle at the threshold with `kept_total == nit_total` and `blocking_total == 0` prints a nit-only advisory.
    - An angle below threshold prints no advisory.
    - An angle with any blocking finding prints no advisory.
    - The advisory is output-only and does not modify `.woostack/config.json`.
  - Run the new metrics test before implementation and confirm it fails for missing advisory output.

- [ ] **Step 3: Tighten AEO and SEO detection**
  - Update `detect-angles.sh` comments and helper functions to distinguish hard path-only surfaces from soft path-plus-token surfaces.
  - Replace the generic AEO `\.(md|mdx|html)$` path trigger with explicit hard surfaces plus a narrow public-content/pricing predicate.
  - Add a SEO soft-file predicate and change the SEO append condition to hard-path OR soft-path-plus-token.
  - Preserve always-on `bugs`, `security`, and `simplify`, and preserve existing unrelated angle behavior.

- [ ] **Step 4: Add metrics-driven skip advisories**
  - Update `metrics-fold.sh` after the aggregate write to compute advisory-only recommendations from the folded aggregate.
  - Use a conservative constant `ANGLE_SKIP_SUGGEST_MIN_RUNS=20` so small-sample angles like four-run `react` do not get noisy suggestions.
  - Exclude unskippable core angles (`bugs`, `security`, `simplify`) from suggestions.
  - Print concise advisory lines such as `metrics-fold: angle aeo: 35 runs, 0 blocking, 0 kept — consider review.angles.skip += ["aeo"]`.
  - Do not auto-edit config; this is guidance for maintainers.

- [ ] **Step 5: Update review docs**
  - Update `skills/woostack-review/SKILL.md` metrics configuration text to say aggregate schema v3.
  - Update Stage 6.5 to document zero-signal and nit-only advisory output, including the `review.angles.skip` destination and the sample-size caveat.
  - Update authored docs-site pages that state the changed behavior: `site/content/docs/configuration.mdx` for metrics/skip guidance and `site/content/docs/concepts/review-angles.mdx` for the tightened AEO summary.

- [ ] **Step 6: Verification**
  - Run `bash skills/woostack-review/scripts/tests/test-detect-angles-seo.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-detect-angles-aeo.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-metrics-fold-suggestions.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-metrics-fold-root.sh`.
  - If docs-site authored pages change, run `pnpm -C site build`; otherwise record that generated per-skill pages need no manual edit.
