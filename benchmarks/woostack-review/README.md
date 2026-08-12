# Review benchmarks

## Reproducible ten-PR regression benchmark

The [`benchmark.mjs`](benchmark.mjs) harness defines the repository-owned regression benchmark for
`woostack-review`. It deliberately measures the normal public review contract: detected angle
workers, independent Prosecutor and Defender validation, deterministic intersection, and native
GitHub delivery. It is not a cheaper review mode.

The fixed corpus contains two PRs each from Cal.com, Discourse, Grafana, Keycloak, and Sentry. Cases
are selected from Code Review Bench commit
`fbc5425c5eec52932aa1303708873d341968fa1c` by choosing the two lowest
`SHA-256("woostack-review-five-pr-v1\n<original-pr-url>")` values in each golden-comment source
file. The original seed is retained so the first five cases stay fixed while the second-ranked case
from each project expands coverage. [`corpus.json`](corpus.json) retains the selected URLs, ranks,
exact goldens, selection hashes, and per-case content hashes. This prevents later cherry-picking or
silent corpus drift.

| Project | Retained case | Added case | Goldens |
| --- | --- | --- | ---: |
| Cal.com | [`7232`](https://github.com/calcom/cal.com/pull/7232) | [`8087`](https://github.com/calcom/cal.com/pull/8087) | 5 |
| Discourse | [`5`](https://github.com/ai-code-review-evaluation/discourse-graphite/pull/5) | [`10`](https://github.com/ai-code-review-evaluation/discourse-graphite/pull/10) | 10 |
| Grafana | [`76186`](https://github.com/grafana/grafana/pull/76186) | [`106778`](https://github.com/grafana/grafana/pull/106778) | 5 |
| Keycloak | [`1`](https://github.com/ai-code-review-evaluation/keycloak-greptile/pull/1) | [`36882`](https://github.com/keycloak/keycloak/pull/36882) | 4 |
| Sentry | [`77754`](https://github.com/getsentry/sentry/pull/77754) | [`95633`](https://github.com/getsentry/sentry/pull/95633) | 6 |

The ten cases contain 30 human-verified goldens, 25 of them in the Core scoring categories. The five
added cases contribute concurrency, data, security, documentation, and functional bug coverage.

The benchmark uses the accepted structured `findings.json` from each completed review. Every
candidate is exactly `<title>. <description>` in retained finding order. It does not ask another
model to extract issues from the GitHub prose, so candidate boundaries and deduplication remain
reproducible. Because that differs from Code Review Bench's extraction pipeline, results are an
internal **woostack ten-PR** cohort and must not be compared with its published 50-PR leaderboard.

### One-line run

From the repository root:

```bash
./benchmarks/woostack-review/run.sh
```

The runner invokes one non-interactive OMP session that executes the complete contract below. It
defaults to the authenticated GitHub user, creates ten fresh private fixture repositories and pull
requests, and writes run evidence under a timestamped `/tmp/woostack-review-ten-pr/` directory.
It never changes the repository or the skill under test. Each case runs its detected first-pass
angles, two validators, and all semantic judgments, so review model usage and GitHub mutations are
real.

Use `--org OWNER` to target an organization, `--run-root PATH` to select the create-new evidence
directory, or `--dry-run` to print resolved inputs without creating anything. Equivalent environment
overrides are `WOO_BENCHMARK_ORG` and `WOO_BENCHMARK_RUN_ROOT`.

### Run contract

1. Check out Code Review Bench at the pinned commit and verify the corpus:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs verify-corpus \
     --benchmark-root /path/to/code-review-benchmark
   ```

2. Create a fresh run root outside the repository. Initialization snapshots the corpus and a
   byte-level inventory of the complete review skill package:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs init \
     --run-root /tmp/woostack-review-ten-pr/<run-id> \
     --skill-root skills/woostack-review
   ```

3. Recreate the ten original PRs in a disposable private organization. Use fresh PRs for every run
   so prior reviews cannot enable incremental review or affect thread state. Run the unmodified
   `/woostack-review <PR#>` workflow once per case. Copy each exact accepted intersection to
   `<run-root>/cases/<case-id>/findings.json`. A blocked or incomplete review blocks the benchmark;
   never substitute raw, Prosecutor-only, or Defender-only findings.

4. Freeze the candidate and judgment plan:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs plan \
     --run-root /tmp/woostack-review-ten-pr/<run-id>
   ```

   Dispatch every `judge-plan.json` pair to a fresh isolated judge using the prompt verbatim. The
   judge may see only that pair's prompt and must write its decision to the listed `decisionPath` as
   exactly `{"reasoning":"...","match":true|false,"confidence":0.0}`. Pin and record the same host
   role, model/session identity, tier, and effort for all pairs. Missing, malformed, failed, or timed
   out judgments block scoring.

5. Aggregate the Core profile:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs score \
     --run-root /tmp/woostack-review-ten-pr/<run-id>
   ```

   `result.json` is create-new and reports TP, FP, FN, precision, recall, F1, F2, excluded matched
   goldens, and per-case evidence. Core counts `api`, `bug`, `concurrency`, `data`, `doc_defect`,
   `perf`, `security`, and `test_gap`. A candidate matched only to an excluded golden is not a false
   positive, matching the upstream profile rule.

Run once during development. For a release comparison, run three fresh repetitions and report each
result plus the median and range; never average blocked or incomplete runs. Retain the run manifest,
skill inventory, review OUTDIRs, posted-review read-backs, accepted findings, judge plan, every
judgment, and result together.

## 2026-08-12 five-PR result

This historical run covers only the five retained rank-one cases. It predates the ten-case corpus;
no ten-PR result or cost measurement is claimed yet.

One complete run used `woostack-review` revision
`249522f3f3f0a33949b28c0515e8db62ef66b413` on Oh My Pi. The default workflow detected 38
first-pass angles across five fresh private fixtures. Workers used host-owned `@default` through
`woostack-standard`; both validators used host-owned `@slow` through `woostack-deep`. All 38 angle
receipts and all 10 validator receipts validated. The intersections retained 12 findings, all 12
were posted as native inline GitHub review comments, and exact review read-back succeeded.

The structured candidates produced 38 independent semantic-match judgments against 15 goldens.
The Core result was 4 TP, 8 FP, and 8 FN: 33.3% precision, 33.3% recall, 33.3% F1, and 33.3% F2,
with zero missing or malformed judgments.

Here, **TP** means *true positive*: a human-verified golden issue matched by at least one accepted
review finding. **FP** means *false positive*: an accepted finding that matched no included golden
issue. **FN** means *false negative*: an included golden issue the review missed. **Precision** is
`TP / (TP + FP)`, the accepted findings' signal rate; **recall** is `TP / (TP + FN)`, the share of
included golden issues found. **F1** is the harmonic mean of precision and recall with equal weight.
**F2** is the weighted harmonic mean that gives recall four times the weight of precision, reflecting
the higher cost assigned to missed bugs. Because precision and recall were both one-third in this
run, F1 and F2 were also 33.3%.

Measured wall-clock runtime was **38 minutes 34.670 seconds**, from creation of `manifest.json` at
2026-08-12 14:38:03.353874840 EDT through creation of `result.json` at
2026-08-12 15:16:38.023543986 EDT. OMP's local usage database reports **$159.040697** in model cost
for the exact benchmark controller session during that interval: $3.607273 for 29 controller
requests, $0.215839 for 36 fast-worker requests, and $155.217585 for 1,362 standard/deep-worker
requests. The accounting includes 12,425,670 input tokens, 300,971 output tokens, and 186,126,720
cache-read tokens. This is observed OMP accounting for the models and prices used by this run, not a
future cost estimate; GitHub operations recorded no separate billed cost.

| Case | Goldens | Candidates | TP | FP | FN | Precision | Recall | Review |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Cal.com | 3 | 3 | 1 | 2 | 2 | 33.3% | 33.3% | [`4920273201`](https://github.com/howarewoo-tmp/calcom-cal-com-woostack-bench/pull/11#pullrequestreview-4920273201) |
| Discourse | 3 | 1 | 0 | 1 | 3 | 0% | 0% | [`4920273575`](https://github.com/howarewoo-tmp/ai-code-review-evaluation-discourse-graphite-woostack-bench/pull/11#pullrequestreview-4920273575) |
| Grafana | 3 | 2 | 1 | 1 | 2 | 50% | 33.3% | [`4920273858`](https://github.com/howarewoo-tmp/grafana-grafana-woostack-bench/pull/11#pullrequestreview-4920273858) |
| Keycloak | 2 | 2 | 1 | 1 | 1 | 50% | 50% | [`4920274208`](https://github.com/howarewoo-tmp/ai-code-review-evaluation-keycloak-greptile-woostack-bench/pull/2#pullrequestreview-4920274208) |
| Sentry | 4 | 4 | 1 | 3 | 3 | 25% | 25% | [`4920274528`](https://github.com/howarewoo-tmp/getsentry-sentry-woostack-bench/pull/7#pullrequestreview-4920274528) |

This is one internal five-PR run, not a published Code Review Bench score. It establishes a baseline,
not a variance estimate; release comparisons require the three fresh repetitions specified above.

## 2026-08-12 integration pilot

The initial integration pilot used `woostack` revision
`d664024e95e24cea389872d5236531a3a803d5ec` and Code Review Bench revision
`fbc5425c5eec52932aa1303708873d341968fa1c` on Oh My Pi. Review workers used the host-owned
`@default` role through `woostack-standard`; validators used `@slow` through `woostack-deep`.

The first recreated Sentry fixture completed review, GitHub posting/read-back, OMP candidate
extraction, 16 semantic judgments, aggregation, and dashboard generation. Its single-case Core
result was 3 TP, 1 FP, and 1 FN: 75% precision, recall, F1, and F2, with zero judge errors. Re-running
scoring produced the same artifact SHA-256:
`1db52e56024b3ea69fd909ffbbf5f0b02eb5deb2286c6d3d32eef5571671d3fb`.
This is integration evidence, not a five-PR or 50-PR benchmark score.

A second Cal.com fixture completed nine angles, a summary worker, both deep validators, native review
posting, and exact read-back. Three findings survived intersection and were posted inline in
[`pullrequestreview-4919023465`](https://github.com/howarewoo-tmp/calcom-cal-com-woostack-bench/pull/1#pullrequestreview-4919023465).

All 50 upstream fixtures were recreated, but the full run was stopped after 320 of approximately 400
first-pass angle jobs when observed model cost reached about $600, before most validators and full
scoring. No full-cohort result exists or is claimed.
