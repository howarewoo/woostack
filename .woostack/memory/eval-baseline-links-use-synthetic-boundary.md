---
name: eval-baseline-links-use-synthetic-boundary
type: gotcha
scope: tooling/evals/scripts/**
tags: evaluation, validation, baselines, links
hook: Validate live cross-package links strictly, but let target-only Git snapshots leave only links outside the package and inside the preserved synthetic collection unresolved.
updated: 2026-07-16
source: [[plans/2026-07-15-skill-evaluation-optimization]]
---

A target-only Git baseline cannot contain sibling packages. Preserve the target's Git-relative collection boundary so validation may leave only contained cross-package links unresolved; in-package misses and collection escapes must still fail.
