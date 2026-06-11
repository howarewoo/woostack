---
type: fix
status: in-review
branch: fix/enable-repo-review-action
---

# Fix: Enable woostack-review on this repo's PRs

## 1. Root Cause

The repo ships the reusable review workflow at `.github/workflows/reusable-review.yml`, but
that workflow only declares `workflow_call`. GitHub will not run it directly on this repo's
pull requests or PR comments without a separate event-triggered workflow that calls it.

Evidence:

- `.github/workflows/reusable-review.yml` has only `on.workflow_call`, so it is callable but
  not self-triggering.
- `.github/` currently has no `ai-review.yml` or equivalent trigger workflow.
- `skills/woostack-review/SKILL.md` documents the intended companion workflow shape: a thin
  `.github/workflows/ai-review.yml` with `pull_request` and trusted `issue_comment` triggers
  that calls the reusable review workflow.
- The documented `issue_comment` event is only safe when it is both actor-gated and
  phrase-gated. `prefetch.sh` parses `/woostack-review` command modifiers after a run has
  started, but the caller workflow is the right place to avoid starting expensive review jobs
  for unrelated trusted maintainer comments.
- The first PR run failed in `review / detect` even though this repo has
  `CLAUDE_CODE_OAUTH_TOKEN` configured. The reusable workflow's detect job called the
  composite action without forwarding `inputs.provider` or any provider secrets, so
  `detect-provider.sh` could not auto-detect a provider before angle detection.
- After detect was fixed, angle workers exposed two shipped-action issues: the Anthropic
  runner needs `id-token: write`, and `load-prompt.sh` used a `printf | grep -q` marker check
  under `pipefail`, which can false-fail as "marker missing" when `grep -q` exits early.
- The reusable workflow self-invoked `howarewoo/woostack@main`. That works for consumers, but
  it prevents this repo's own PRs from testing action changes before merge; the failing `bugs`
  angle kept running the old `load-prompt.sh` from `main`.
- `AGENTS.md` still describes the review workflow assets as consumer-facing only, so adding a
  repo-local trigger also needs a small instruction update to prevent future cleanup as
  accidental CI.

Memory recall:

- `.woostack/memory.md` notes that markdown/skill-doc-only PRs previously skipped automated
  swarm review. Enabling a repo-level review action addresses that operational gap for future
  PRs.
- `.woostack/memory/woostack-command-surface-bookkeeping.md` applies to `AGENTS.md` edits:
  keep repo-surface bookkeeping explicit when changing documented workflows.

## 2. Proposed Fix

Add a thin `.github/workflows/ai-review.yml` workflow for this repo. It should:

- Trigger on `pull_request` events: `opened`, `reopened`, `ready_for_review`, and
  `synchronize`. The job gate should run these automatically only for same-repo branches,
  because fork PRs do not receive provider secrets.
- Trigger on `issue_comment.created`, but run only for PR comments that are both from trusted
  actors (`OWNER`, `MEMBER`, or `COLLABORATOR`) and explicitly request review with
  `@review` or `/woostack-review`. This gives maintainers an explicit path to review fork PRs.
- Call the existing local reusable workflow with `uses: ./.github/workflows/reusable-review.yml`
  instead of duplicating the review matrix.
- Pass through the known provider secrets so `action.yml` can auto-detect the configured
  provider.
- Forward provider inputs and provider secrets from the reusable workflow's `detect` job to
  the composite action, matching the review and validate jobs.
- Grant `id-token: write` to jobs that run Anthropic's action.
- Replace the prompt-marker pipeline with a shell pattern check and cover it with a regression
  test.
- Checkout the woostack action bundle into `.woostack-action` inside each reusable workflow
  job and invoke that local action. For this repo's PRs, checkout the PR branch; for consumers,
  keep using `main`.
- Grant only the permissions the reusable flow needs at the caller level: `contents: read` and
  `pull-requests: write`.

Update `AGENTS.md` to state that `.github/workflows/ai-review.yml` is an intentional
repo-level review-delivery workflow, while preserving the constraint that this repo has no
application build/test CI.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing verification**
  - Verify `.github/workflows/ai-review.yml` is absent.
  - Verify `.github/workflows/reusable-review.yml` is `workflow_call` only.
  - Verify `actionlint .github/workflows/ai-review.yml .github/workflows/reusable-review.yml`
    cannot cover the missing trigger because the trigger workflow does not exist yet.

- [x] **Step 2: Add the repo-level review trigger workflow**
  - Create `.github/workflows/ai-review.yml`.
  - Use the local reusable workflow path.
  - Preserve the trusted-author and review-phrase gates for comment-triggered reviews.
  - Pass through all supported provider secrets without hardcoding a provider.

- [x] **Step 3: Update repo instructions**
  - Amend `AGENTS.md` so the new workflow is identified as an intentional review-delivery
    asset, not app/test CI.

- [x] **Step 4: Fix provider auto-detection in reusable detect job**
  - Forward `provider` and supported provider secrets into the `mode: detect` composite action
    invocation.
  - Preserve provider auto-detection instead of hardcoding this repo to a single provider.

- [x] **Step 5: Fix angle-runner failures**
  - Add `id-token: write` where Anthropic runner jobs need OIDC.
  - Replace the prompt marker `printf | grep -q` check with a non-pipeline shell pattern check.
  - Add a regression test for `load-prompt.sh`.
  - Replace direct `howarewoo/woostack@main` action invocations with a checked-out local action
    path so this repo can test PR action changes before merge.

- [x] **Step 6: Verification**
  - Run `actionlint .github/workflows/ai-review.yml .github/workflows/reusable-review.yml`.
  - Run `bash skills/woostack-review/scripts/tests/test-load-prompt-marker.sh`.
  - Confirm the `issue_comment` job gate requires a trusted author and either `@review` or
    `/woostack-review`.
  - Confirm `gh secret list --repo howarewoo/woostack` includes at least one provider secret.
  - Confirm `git status --short` only changes `.github/workflows/ai-review.yml`,
    `.github/workflows/reusable-review.yml`, `AGENTS.md`,
    `skills/woostack-review/scripts/load-prompt.sh`,
    `skills/woostack-review/scripts/tests/test-load-prompt-marker.sh`, and this fix file.
