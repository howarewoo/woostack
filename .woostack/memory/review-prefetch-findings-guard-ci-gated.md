---
name: review-prefetch-findings-guard-ci-gated
type: gotcha
scope: skills/woostack-review/scripts/**
tags: prefetch, outdir, findings, guard, validate, ci, local, per-run, contamination, skills-repo
hook: prefetch.sh's in-flight-findings.* guard must stay GITHUB_ACTIONS-gated — CI's validate job pre-downloads findings.* then re-runs prefetch, so warn-and-PRESERVE is load-bearing there; only the local branch may HARD-STOP. And the local default OUTDIR must be per-RUN, not per-project.
updated: 2026-06-12
source: .woostack/fixes/2026-06-12-review-outdir-per-run.md
---
Two coupled facts about `prefetch.sh` / `resolve-outdir.sh` (issue #321):

**1. The findings-guard's branch is context-split — do not collapse it.**
`prefetch.sh` refuses to wipe an `$OUTDIR` already holding `findings.*`. The
refusal MUST differ by context:
- **CI (`GITHUB_ACTIONS=true`) → warn + PRESERVE + continue.** `action.yml`'s
  `Prefetch` step has *no mode gate*, so prefetch re-runs on every action
  invocation. In the `validate` / `validate-prosecutor` job,
  `reusable-review.yml` **downloads the `findings-*` artifacts into `$OUTDIR`
  BEFORE re-invoking the action** — so those `findings.*` are *legitimate*, and
  wiping or aborting destroys the matrix output the validator must read. This
  preserve-and-continue is load-bearing; "tightening" it to always `exit 1`
  silently breaks every consumer's CI validate job.
- **Local (`GITHUB_ACTIONS != true`) → `::error::` + `exit 1`.** With per-run
  OUTDIRs a fresh local review never lands on a dir already holding
  `findings.*`; their presence means a contaminated/active tree, so abort rather
  than merge/post stale artifacts. `WOO_REVIEW_FRESH=1` forces a wipe in both.

**2. The local default `OUTDIR` is per-RUN, not per-project.**
`resolve-outdir.sh` derives `pr-review-<hash>-<ts>-<pid>` locally (`<hash>` of the
git toplevel isolates repos; `<ts>-<pid>` isolates runs) so two reviews of the
same repo never share — and contaminate — one findings/receipt tree. The suffix
is non-deterministic *by design*: it relies on the existing export contract — the
orchestrator captures prefetch's printed `outdir=<path>` and exports `OUTDIR`
verbatim to every sub-agent / downstream stage (no recompute drift). CI keeps the
stable `pr-review-<hash>` form, and `action.yml` pins `OUTDIR=/tmp/pr-review`
anyway, so the per-run branch is dead in CI.

**The pattern:** a review value whose behavior must differ between CI and local
(here the guard, and the OUTDIR shape) belongs to the same CI/local-asymmetry
family as [[review-marker-trust-asymmetry]] and [[review-model-resolution-two-paths]] —
always check both contexts before editing one. Default `.woostack/` paths still
anchor via [[woostack-paths-anchor-to-repo-root]].
