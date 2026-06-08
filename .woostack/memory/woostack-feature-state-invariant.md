---
name: woostack-feature-state-invariant
type: convention
scope: .woostack/specs/**, .woostack/plans/**, skills/woostack-status/**
tags: status, specs, plans, prs
hook: Specs, plans, and increment PRs are joined by Source and Spec trailers.
updated: 2026-06-04
source: .woostack/plans/2026-06-04-woostack-status.md
recall_count: 58
last_recalled: 2026-06-08
---
Feature state is derived from artifacts, not a committed status file: each spec
has exactly one plan via `**Source:** .woostack/specs/<file>.md`, and each
increment PR carries `Spec: .woostack/specs/<file>.md`. The execute/review/done
band is computed from plan progress and PR state; authored `status:` is checked
against that truth and drift is reported as a flag.
