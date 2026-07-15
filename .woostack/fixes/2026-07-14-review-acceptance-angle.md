---
type: fix
status: in-review
branch: fix/review-acceptance-angle
---

# Fix: Verify PRs against their governing woostack intent

## 1. Root Cause

`woostack-review` has no governing-artifact ingestion boundary. `skills/woostack-review/scripts/prefetch.sh` fetches the PR body into `meta.json` and composes project rules, scoped memory, and wisdom, but it neither resolves `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/` artifacts nor writes `intent.md`. The metadata request also omits `headRefName`, so a branch-frontmatter fallback cannot work in CI. Consequently, `detect-angles.sh` has no intent artifact to gate on, the prompt registries have no `acceptance` angle, and workers cannot compare the diff with the criteria and completed steps that authorized it.

The deficiency is reproduced on the current code in two independent baselines:

- A temporary consumer repository with a self-contained fix and fake PR metadata ending in `Spec: .woostack/fixes/2026-07-14-demo.md` completed `prefetch.sh` successfully but produced no `intent.md`.
- A valid synthetic review output directory containing `intent.md` completed `detect-angles.sh`, but `angles.txt` contained zero `acceptance` entries.

Existing focused checks remained green (`test-status.sh`: 101 passed; `test-intersect-deferred.sh`: 14 passed; `test-detect-angles-comments.sh`: pass), confirming this is an omitted end-to-end path rather than a regression in exact trailer matching or deferral classification. `skills/woostack-status/scripts/status.sh` provides only part of the needed pattern: it performs the inverse artifact-to-PR lookup for exact `Spec:` trailers, does not accept `Plan:`, and does not compose review intent.

## 2. Proposed Fix

Add one read-only intent resolver at `skills/woostack-review/scripts/resolve-intent.sh`, invoked by prefetch after `meta.json` exists. It will remove stale `intent.md`, resolve only repository-contained `.woostack/{specs,plans,fixes}/*.md` files, and write `intent.md` atomically only when the result is unambiguous.

Resolution order and invariants:

1. Prefer exact, trimmed PR-body trailer lines. Accept canonical `Spec:` paths under `.woostack/specs/` or `.woostack/fixes/` and the requested `Plan:` path under `.woostack/plans/`. Reject prose mentions, traversal, absolute paths, missing files, suffix collisions, and conflicting trailers.
2. Without a resolvable trailer, match `meta.json.headRefName` exactly against YAML `branch:` frontmatter. A fix is self-contained. A spec and its canonical plan on the same branch form one joined pair, not an ambiguity. Multiple unrelated matches warn and no-op rather than guessing.
3. Compose both sides of a feature contract: a resolved spec includes its unique canonical plan; a resolved plan includes its source spec using the accepted frontmatter, legacy `**Source:**` path, or wikilink forms. A fix remains one source. Prefix each section with `## SOURCE: <repo-relative-path>`. This gives the worker both section 7 acceptance criteria and checked implementation steps.
4. Missing `.woostack`, metadata, head branch, artifact, or unique join exits successfully without `intent.md`, preserving current review behavior.

Add `prompts/angles/acceptance.md` at the standard tier. It compares every explicit acceptance criterion and every `[x]` implementation step with diff evidence, validates the artifact's code claims and line references, ignores unticked `[ ]` steps as unclaimed work, and emits only right-side diff-anchored findings. An absent `intent.md` defensively emits `[]`.

Keep deferral authority centralized: the worker treats `woostack-defer(<ref>)` as inert; the defender alone decides whether a co-located marker covers missing later-increment work, and `intersect-findings.sh` demotes that acceptance finding to a visible non-blocking nit. Add a classifier guard so even malformed validator output can never defer `security`.

Register the twenty-second angle across the live split contracts: `detect-angles.sh`, `load-config.sh`, `_worker-header.md`, `_orchestrator-header.md`, `SKILL.md`, and Anthropic effort routing. Update the authored review-angle and configuration pages because they currently promise a catalog of 21 angles. No application dependency or new external service is required.

## 3. Implementation Plan

- [x] **Step 1: Reproduce intent resolution failures with focused tests**
  - Add `skills/woostack-review/scripts/tests/test-resolve-intent.sh` covering exact `Spec:` spec/fix trailers, exact `Plan:` trailers, spec-plan composition through frontmatter/legacy/wikilink joins, exact branch matching, shared spec-plan branches, conflicting or unrelated matches, traversal/absolute/suffixed/prose paths, missing artifacts/metadata, and stale-output removal.
  - Add `skills/woostack-review/scripts/tests/test-prefetch-intent.sh` using the existing local-only fake metadata/diff hooks. Assert trailer and branch resolution write the expected `## SOURCE:` sections, while an unresolved repository still completes with the pre-existing artifact set and no `intent.md`.
  - Run both new scripts before implementation and confirm they fail because the resolver and prefetch integration do not exist.

- [x] **Step 2: Implement one safe governing-intent resolver**
  - Create `skills/woostack-review/scripts/resolve-intent.sh` with exact, repository-contained path validation; exact trailer precedence; exact `headRefName` fallback; canonical spec-plan joining; ambiguity warnings; atomic output; and no-op compatibility behavior.
  - Update `prefetch.sh` to request `headRefName`, invoke the resolver after metadata is available, and document `intent.md` in its output contract.
  - Update the local-diff metadata recipe in `skills/woostack-review/SKILL.md` so it supplies the current head branch and invokes the same resolver rather than introducing a second resolution path.
  - Run `test-resolve-intent.sh` and `test-prefetch-intent.sh`; confirm pass.

- [x] **Step 3: Reproduce and implement conditional acceptance-angle gating**
  - Add `skills/woostack-review/scripts/tests/test-detect-angles-acceptance.sh`. Assert default detection includes `acceptance` exactly once only when `intent.md` exists, leaves the no-intent baseline unchanged, and guards every live registry/standard-tier integration site.
  - Run it before implementation and confirm failure.
  - Gate `acceptance` in `detect-angles.sh` on `intent.md`, preserving existing `angles.force`/`angles.skip` precedence used by other conditional angles.
  - Register `acceptance` in `load-config.sh`, `_worker-header.md`, `_orchestrator-header.md`, `SKILL.md`, and `prompts/anthropic.md`; update the angle count from 21 to 22 where stated.
  - Run `test-detect-angles-acceptance.sh`; confirm pass.

- [x] **Step 4: Define and verify the acceptance worker contract**
  - Add `skills/woostack-review/scripts/tests/test-acceptance-angle.sh` and first confirm failure. Its contract checks must require criterion-by-criterion diff evidence, verification of each `[x]` claim, no completion claim for `[ ]`, stale artifact claim/line-reference validation, right-side diff anchors, defensive `[]` without intent, and defender-only deferral handling.
  - Add `skills/woostack-review/prompts/angles/acceptance.md` with `tier: standard` and the tested scope, skip rules, severity guidance, and output contract.
  - Run `test-acceptance-angle.sh`; confirm pass.

- [x] **Step 5: Structurally preserve deferral safety**
  - Extend `skills/woostack-review/scripts/tests/test-intersect-deferred.sh` first with an acceptance finding demoted by a valid defender-populated `deferred_to`, the same finding unaffected when `defer_markers: false`, and a security finding that remains blocking/non-nit despite malformed `deferred_to`.
  - Confirm the security case fails on the current classifier, then add the minimal `angle != security` guard in `intersect-findings.sh`.
  - Run `test-intersect-deferred.sh`; confirm pass.

- [x] **Step 6: Keep authored documentation synchronized**
  - Update `site/content/docs/concepts/review-angles.mdx` with the acceptance angle, its intent-artifact gate, standard tier, and special deferral behavior.
  - Update angle-count references in `site/content/docs/configuration.mdx` and `site/content/docs/concepts/index.mdx` from 21 to 22.
  - Do not edit generated per-skill reference pages.

- [x] **Step 7: Verification**
  - Run `bash -n skills/woostack-review/scripts/resolve-intent.sh skills/woostack-review/scripts/prefetch.sh skills/woostack-review/scripts/detect-angles.sh skills/woostack-review/scripts/intersect-findings.sh`.
  - Run the five focused review test scripts: `test-resolve-intent.sh`, `test-prefetch-intent.sh`, `test-detect-angles-acceptance.sh`, `test-acceptance-angle.sh`, and `test-intersect-deferred.sh`.
  - Run existing adjacent regressions: `test-prefetch-rule-dedupe.sh`, `test-detect-angles-comments.sh`, `test-load-config-root.sh`, and `skills/woostack-status/scripts/tests/test-status.sh`.
  - Run `pnpm -C site build` to verify the authored docs and generated skill reference still build.
  - Smoke-test one temporary consumer repository through `prefetch.sh` then `detect-angles.sh`: a resolvable fix must produce `intent.md` and one `acceptance` angle; removing the trailer and branch match must produce neither while prefetch still completes.
  - Run the acceptance worker against a controlled `intent.md`/diff fixture: confirm it reports one unmet criterion and one unsupported `[x]` claim, emits no finding for a satisfied criterion, and produces schema-valid right-side anchors. Feed the deferred missing-work finding through the existing defender/intersection path and confirm the final result is a non-blocking `Deferred to <ref>` nit while a security finding cannot be demoted.
