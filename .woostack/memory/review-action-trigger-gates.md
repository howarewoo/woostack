---
name: review-action-trigger-gates
type: convention
scope: .github/workflows/**
tags: github-actions, review, security
hook: Review-trigger workflows must actor+phrase gate issue_comment and avoid automatic secret-dependent fork PR runs.
updated: 2026-06-11
source: [[fixes/2026-06-11-enable-repo-review-action]]
---

When enabling woostack-review in GitHub Actions, `issue_comment` triggers run in the
base-repo context with secrets available. Gate them by trusted actor and explicit review
phrase (`@review` or `/woostack-review`). For `pull_request`, do not auto-run
provider-secret-dependent jobs on fork PRs; use same-repo automatic runs plus trusted
maintainer comments for forks.
