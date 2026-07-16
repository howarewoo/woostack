---
type: fix
status: executing
branch: fix/linear-artifact-migration-hardening
---

# Fix: Harden Linear artifact migration against normalization and partial writes

## 1. Root Cause
The Linear adapter validates remote write success by comparing local source bytes against fresh remote reads (e.g., `cmp -s` for spec/doc and direct content equality for plan/read-back), so writes that are normalized by Linear are treated as unverified failures even when their IDs/state are correct. This is reproducible in `feature-create`, `spec-write`, and `plan-reconcile` with identical content except for provider-induced list-marker normalization.

`command_issue_transition` updates managed increment metadata and target state in one `issueUpdate` call, but then immediately validates through `normalized_increments`; when managed metadata has a PR URL that Linear rewrites to Markdown-autolink form (`[url](<url>)`), `require_repository_pr_url` rejects it and the command marks the transition as pending. At the same time, state has already been written remotely, so retries can become non-convergent.

`issue-list.graphql` does not request native attachment references, yet attachment-based PR metadata can still be present and merged; `raw_managed_increments` currently derives `pullRequest` only from managed metadata. As a result, `status-reconcile` cannot terminalize an increment when managed metadata is null or rewritten.

Across all paths, receipts do not distinguish `attempted-without-verification` from `written-with-provider-normalized` and thus cannot encode a resumable safe state transition.

## 2. Proposed Fix
Implement shared, provider-aware normalization and lifecycle classification at the adapter boundaries:

- Add a canonical comparison function that compares submitted vs. observed Linear Markdown via Linear-aware equivalence (newline/border metadata and markdown marker normalization) so semantically equal canonicalized documents verify as equivalent while preserving strict semantic mismatch detection.
- Normalize PR URLs in managed metadata before validation (only accept explicit same-repository `https://.../pull/<n>` and transform supported Linear autolink forms back to canonical URL) so metadata remains contract-safe regardless of Linear rewrite.
- Extend issue normalization to include native GitHub PR attachment evidence, merging attachment-derived PR URLs into increment state when managed metadata is absent and rejecting conflicts/ambiguities.
- Tighten `issue-transition` and related receipt logic to be evidence-first: capture observed remote state/evidence after each mutation, classify outcomes (`attempted`, `attemptedWithUnknown`, `writtenButNormalized`, `verified`), and avoid claiming verified success when only one part verifies.

The shared root for all required changes is `skills/woostack-init/scripts/artifacts` (scripts + GraphQL fixtures + tests).

## 3. Implementation Plan
- [x] **Step 1: Reproduce with a failing test**
  - Add/update fixture-based tests for `linear-metadata` and `linear-resources` proving: provider marker normalization, URL autolink normalization, attachment-derived pullRequest handling, and non-retry behavior after partial outcomes.
  - Ensure failure reproduction is explicit for:
    - `feature-create`, `spec-write`, and `plan-reconcile` content verification.
    - `issue-transition --target inReview` with managed autolink PR value.
    - `status-reconcile` using merged native PR attachment.

- [x] **Step 2: Apply the minimal fix**
  - Implement one provider-aware content comparison helper in `skills/woostack-init/scripts/artifacts/linear-metadata.py` and apply it in `skills/woostack-init/scripts/artifacts/linear.sh` document and plan read-back points.
  - Implement managed URL normalization in metadata parsing and require exact repository PR URL shape after normalization.
  - Extend GraphQL issue listing to retrieve native PR references and fold attachment-derived PRs into `raw_managed_increments`.
  - Update `command_issue_transition` and plan/reconciliation receipt composition to distinguish attempts, observed outcomes, and full verification.

- [x] **Step 3: Verification**
  - Run focused adapter test suites:
    - `skills/woostack-init/scripts/tests/test-linear-metadata.sh`
    - `skills/woostack-init/scripts/tests/test-linear-resources.sh`
  - Confirm no byte-only exact-match assertions remain where semantically equivalent provider output should be accepted.
  - Confirm issue transition now emits a resumable, deterministic receipt when only evidence/read-back normalization is delayed by provider rewrites.
