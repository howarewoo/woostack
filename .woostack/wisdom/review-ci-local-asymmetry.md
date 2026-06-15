---
name: review-ci-local-asymmetry
type: wisdom
category: review
source: review-marker-trust-asymmetry, review-prefetch-findings-guard-ci-gated, review-model-resolution-two-paths, fixes/2026-06-11-review-marker-self-trust, fixes/2026-06-12-review-outdir-per-run, fixes/2026-06-11-review-local-model-resolution
updated: 2026-06-15
---

woostack-review runs in two contexts — CI (single-session, GitHub Actions) and local
(per-call) — and many of its values must behave *differently* in each. A change wired for one
context silently regresses the other. Before editing any review value, ask: **does this path
run in CI, local, or both — and is the gate/resolver shaped for every context that reads or
writes it?**

Cases, each of which cost a fix:

- **Marker trust** — the SHA watermark is written in both contexts, but the read-side trust
  gate was bot-author-only, so a local re-review never trusted its own marker. Widen to
  `bot OR (local AND author==self)`, gated `not-in-CI`. ([[review-marker-trust-asymmetry]])
- **Findings guard** — CI re-runs `prefetch.sh` with pre-downloaded `findings.*` present
  (warn + preserve); local treats the same state as a hard-stop. Don't collapse the branch.
  ([[review-prefetch-findings-guard-ci-gated]])
- **Model resolution** — two paths (`load-prompt.sh` in CI's single session;
  `resolve-model.sh` per-call locally) must share one tier→model precedence. A resolver wired
  to one path regresses the other. ([[review-model-resolution-two-paths]])
- **OUTDIR shape** — CI wants a stable per-project dir; local wants per-run (ts+pid) so
  concurrent local runs don't clobber. ([[woostack-paths-anchor-to-repo-root]])

How to apply: extract the context-split logic into a single-authority resolver script
(`resolve-marker.sh` / `resolve-model.sh` / `resolve-root.sh`) so the unit test and the
production filter cannot drift, and gate CI-only safety clauses on `GITHUB_ACTIONS`. Treat
"works locally" and "works in CI" as two separate proofs.
