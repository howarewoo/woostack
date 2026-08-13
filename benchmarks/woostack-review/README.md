# Review benchmark evidence

## Purpose and cohort

[`benchmark.mjs`](benchmark.mjs) owns the deterministic evidence contract for `woostack-review`.
[`corpus.json`](corpus.json) remains the pinned ten-case Code Review Bench inventory at commit
`fbc5425c5eec52932aa1303708873d341968fa1c`; `verify-corpus` still verifies all ten cases and all 30
goldens byte-for-byte. A development run selects only the five retained rank-one cases recorded in
`manifest.json.caseIds`. That is the only cohort comparable with the historical five-PR baseline.

A single completed run is **directional development evidence**. It is not a ten-PR or 50-PR score,
a release result, or a variance estimate. The benchmark preserves the existing Core definitions of
TP, FP, FN, precision, recall, F1, and F2. Core includes `api`, `bug`, `concurrency`, `data`,
`doc_defect`, `perf`, `security`, and `test_gap`; a candidate matched only to an excluded golden is
not a false positive.

## Prerequisites

- `git`, `gh`, `jq`, `node`, `omp`, and `sqlite3` on `PATH`.
- `gh` authenticated to an owner where five fresh private fixture repositories and pull requests
  may be created.
- Code Review Bench checked out at `fbc5425c5eec52932aa1303708873d341968fa1c` (the standard local
  checkout is `/tmp/woostack-code-review-benchmark`).
- Fresh isolated OMP review and judge sessions and the benchmark judge model available through host
  roles; direct provider API keys are not required.
- OMP accounting at `$HOME/.omp/stats.db`, or `WOO_BENCHMARK_USAGE_DB` set to the exact database.
  The harness uses exact database rows when present and otherwise reads the same immutable usage
  records from bound session JSONL files; it never recalculates provider prices.
- A create-new run root outside the repository and five fresh fixture PRs. Existing reviews cannot
  be reused because incremental state and prior threads change the review contract.

Resolve inputs without creating the run root:

```bash
./benchmarks/woostack-review/run.sh --dry-run --org OWNER
```

Run the complete directional cohort from the repository root:

```bash
./benchmarks/woostack-review/run.sh --org OWNER
```

Use `--run-root PATH`, `WOO_BENCHMARK_RUN_ROOT`, `WOO_BENCHMARK_ORG`, and
`WOO_BENCHMARK_USAGE_DB` for explicit overrides.

## Evidence protocol

1. Verify the immutable corpus against the pinned upstream checkout:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs verify-corpus \
     --benchmark-root /tmp/woostack-code-review-benchmark
   ```

2. Initialize one create-new historical-five-PR run. Initialization snapshots the full corpus and a
   byte inventory of the complete review skill while creating case directories only for the five
   rank-one case IDs:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs init \
     --run-root /tmp/woostack-review-five-pr/<run-id> \
     --skill-root skills/woostack-review
   ```

3. Recreate each `manifest.json.caseIds` PR privately and run the unmodified public
   `/woostack-review <PR#>` workflow once. Retain the complete review OUTDIR at
   `cases/<case-id>/review/` and copy its exact accepted `findings.json` to
   `cases/<case-id>/findings.json`. Required review evidence is:

   - `swarm-metrics.json` plus every named candidate receipt;
   - `raw_findings.json`, `findings.adjudicator.json`, `findings.json`,
     `receipt.adjudicator.json`, `validator-bindings.json` schema 2, and
     `validator-metrics.json`;
   - benchmark-owned `fixture.json` from the private PR creation read-back,
     `delivery-create.json` from the first successful native create, and
     `delivery-readback.json` from native GitHub delivery read-back, binding the exact repository,
     PR, reviewed `meta.json.headRefOid`, unique create attempt, review ID/event/actor, and every
     accepted finding digest to its posted comment ID and URL.
   - Before PR creation, create `main` with the base commit and push `main` by itself. Set the
     repository default branch to `main` and independently read it back before creating or pushing
     `benchmark-head`. Create `benchmark-head` from that base before applying or committing head
     changes, push it only after its head commit exists, then independently verify distinct local
     SHAs, matching remote refs, `main` as the default branch, and matching PR base/head refs.
     `fixture.json` records `baseSha`, `headSha`, the local and remote base/head ref SHAs, independently
     captured `localMergeBaseSha` and `remoteMergeBaseSha` values equal to `baseSha`, and PR
     base/head read-back SHAs.

   Every invocation of the unmodified public review workflow must set both `GITHUB_REPOSITORY` and
   `GH_REPO` to the exact private fixture repository. Do not retain a source/upstream remote that a
   bare `gh` lookup can select. Verify `meta.json.headRefOid` and `headRefName` against
   `fixture.json`; repository and PR identity come from the independently read fixture and native
   GitHub read-back because the public `meta.json` schema does not contain those fields.

   Native delivery is create-once and owned by the benchmark helper. Generate a unique attempt ID
   and write the complete native review request body to a payload file, then invoke:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs create-delivery \
     --review-root <run-root>/cases/<case-id>/review \
     --attempt-id <unique-attempt-id> \
     --request-payload <absolute-review-request.json> \
     --gh "$(command -v gh)"
   ```

   The helper derives the repository and PR from the case fixture, derives the event from the
   payload, atomically claims a durable per-case lock, and invokes exactly one native
   `gh api --method POST ... --input <payload>` process without a shell. Before it returns, it
   persists the returned review ID, event, and attempt in `delivery-create.json`. If the native
   outcome cannot be established, the same path remains a durable `INDETERMINATE` receipt. The lock
   is never removed: no later helper or native create is permitted, including after read-back
   failure.

   After a successful create, invoke the benchmark-owned read-back exactly once:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs read-delivery \
     --review-root <run-root>/cases/<case-id>/review \
     --request-payload <absolute-review-request.json> \
     --gh "$(command -v gh)" \
     --resolver <absolute-skill-root>/scripts/resolve-diff-line.sh
   ```

   `read-delivery` derives `fixture.json` from the review root unless `--fixture` supplies its
   explicit path. It invokes the absolute `gh` executable without a shell and performs only native
   GETs for the exact created review and its comments. It binds repository, PR, reviewed head,
   review ID, mapped event/state, native actor, request body, and exactly one native comment to each
   finalized finding digest. Native line/side coordinates are preferred. A position-only GitHub
   response is accepted only when the immutable reviewed `diff.txt` deterministically maps it to
   the requested RIGHT-side changed line and the explicitly supplied shipped resolver validates
   that line; position alone is never evidence. The helper atomically creates
   `delivery-readback.json` only after every check succeeds. Controllers must not synthesize or
   compare anchors themselves, post, retry, or replace this artifact.

   The scorer requires exactly one POST-equivalent attempt, unique attempt and review IDs across
   the run, matching receipt/read-back IDs and events, and the state mapping `COMMENT` to
   `COMMENTED`, `APPROVE` to `APPROVED`, and `REQUEST_CHANGES` to `CHANGES_REQUESTED`.


   Candidate-generation job counts come only from `swarm-metrics.json` and its receipts.
   Adjudication completion comes only from the sole adjudicator receipt and artifacts. Rejections
   are reported as first-pass candidate failures, invalid-after-retry candidates, missing receipts,
   candidates rejected by the adjudicator, and deterministic-finalizer rejections. No retired
   prosecutor/defender counters are accepted.

4. Record exact stage intervals and closed OMP session bindings in
   `<run-root>/stage-timings.json`:

   ```json
   {
     "schemaVersion": 2,
     "sessions": [
       {"jobId":"benchmark/controller","role":"controller","sessionFile":"/exact/controller.jsonl","terminalEntryId":"terminal-id","closed":true},
       {"jobId":"cal-dot-com/bugs/attempt-1","role":"candidate","sessionFile":"/exact/candidate/session.jsonl","terminalEntryId":"terminal-id","closed":true,"argv":["/absolute/omp","--session-dir","/exact/candidate","--max-time","30m","-p","<prompt>"],"stdin":"ignore"},
       {"jobId":"cal-dot-com/adjudicator","role":"adjudicator","sessionFile":"/exact/adjudicator/session.jsonl","terminalEntryId":"terminal-id","closed":true,"argv":["/absolute/omp","--session-dir","/exact/adjudicator","--max-time","15m","-p","<prompt>"],"stdin":"ignore"},
       {"jobId":"judge/cal-dot-com--G01--C01","role":"judge","sessionFile":"/exact/judge/session.jsonl","terminalEntryId":"terminal-id","closed":true,"argv":["/absolute/omp","--session-dir","/exact/judge","--max-time","15m","-p","<prompt>"],"stdin":"ignore"}
     ],
     "startedAt": "2026-08-12T00:00:00.000Z",
     "completedAt": "2026-08-12T00:12:00.000Z",
     "stages": [
       {"caseId":"cal-dot-com","name":"candidate-generation","startedAt":"...","completedAt":"..."},
       {"caseId":"cal-dot-com","name":"adjudication","startedAt":"...","completedAt":"..."},
       {"caseId":null,"name":"semantic-judging","startedAt":"...","completedAt":"..."}
     ]
   }
   ```

   Supply exactly one candidate-generation and adjudication interval per manifest case and exactly
   one benchmark semantic-judging interval. Candidate generation must complete before that case's
   adjudication; all adjudication must complete before semantic judging. The controller writes
   one-to-one bindings that exactly cover every first/retry candidate attempt, every adjudicator,
   and every `judge-plan.json` pair. After the controller exits, `run.sh` appends its separately
   captured `benchmark/controller` binding from the create-new `--session-dir`. Every nested binding
   is emitted by `launch-nested` after the owned child process exits successfully. It names the
   exact closed session file and terminal assistant entry, the complete actual OMP `argv`, and
   `stdin: "ignore"`. Its one absolute `--session-dir` contains the session file and its
   one `--max-time` is `30m` for candidates or `15m` for adjudicators and judges. A caller
   attestation, prompt assertion, time window, nearest session, partial ingestion, or incomplete
   aggregate is invalid.

5. Freeze candidates and semantic pairs:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs plan \
     --run-root /tmp/woostack-review-five-pr/<run-id>

   ```
   Launch every nested process through the helper; never invoke nested OMP directly:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs launch-nested \
     --role <candidate|adjudicator|judge> \
     --job-id <exact-job-id> \
     --session-dir <create-new-absolute-session-dir> \
     --executable "$(command -v omp)" \
     -- <all-other-omp-arguments>
   ```

   The helper owns the create-new session directory, selects `30m` for candidates and `15m` for
   adjudicators and judges, inserts the session and timeout arguments, spawns with ignored stdin,
   captures stdout/stderr, and waits for exit. It fails closed on a nonzero exit, a session-directory
   collision, anything other than one JSONL session, or a session without a terminal assistant entry.
   Its JSON output is evidence derived from the actual child argv, exit, and session and is appended
   unchanged to `stage-timings.json`; callers do not supply timeout, stdin, closure, session-file, or
   terminal-entry claims.

   Every candidate is exactly `<title>. <description>` in retained finding order. Before dispatch,
   write one `judge-contract.json` pinning provider, model, agent type, tier, and effort for the
   entire run. Dispatch every `judge-plan.json` pair to a fresh isolated judge using its prompt
   verbatim. Beside each decision, retain a `.receipt.json` binding pair ID, prompt and decision
   SHA-256, exact session file and terminal entry, and every pinned contract field. The scorer
   verifies the receipt against the decision, plan, session manifest, terminal OMP usage record,
   and common judge contract.

6. Exit the controller after every upstream artifact, decision, and worker/judge closed-session
   binding exists. `run.sh` waits for that OMP process to exit, resolves the one session file and
   terminal assistant entry from its create-new session directory, appends the closed controller
   binding, and only then invokes scoring. The scorer uses exact `stats.db` rows when OMP has indexed
   the bound custom session paths; if none are indexed, it reads those exact session JSONL records:

   ```bash
   node benchmarks/woostack-review/benchmark.mjs score \
     --run-root /tmp/woostack-review-five-pr/<run-id> \
     --usage-db "$HOME/.omp/stats.db"
   ```

Missing, malformed, duplicate, inconsistent, or incomplete manifests, receipts, review artifacts,
delivery read-backs, stage intervals, exact bound-session terminal OMP usage, judge contracts,
judgments, or judge receipts block before `result.json` is created. The harness never fabricates
zero usage or marks partial accounting as success. `result.json` is create-new; retain it with the
manifest, corpus/skill inventory, review OUTDIRs, fixture/delivery evidence, timing and
terminal-session bindings, judge plan/contract/decisions/receipts, and usage-source identity.

## Result schema and authoritative sources

`result.json` schema version 2 preserves `tp`, `fp`, `fn`, `excludedMatched`, `precision`, `recall`,
`f1`, `f2`, `cases`, `profile`, `benchmark`, and `complete`, and adds:

| Field | Meaning | Authoritative input |
| --- | --- | --- |
| `cohort`, `runId` | Exact directional run identity | `manifest.json` |
| `accounting.jobs.candidateGeneration` | Planned, attempted, retried, completed jobs | Per-case `swarm-metrics.json` + candidate receipts |
| `accounting.jobs.adjudication` | Planned, attempted, completed sole-adjudicator jobs | Manifest case set + adjudicator receipts/artifacts |
| `accounting.rejectionReasons` | Complete rejection/failure counts by stage boundary | Swarm metrics and raw/adjudicated/final artifact deltas |
| `accounting.timing.stageCompletedAt`, `.completedAt`, `.durationsMs` | Controller-reported final stage boundary; scorer completion after exact usage ingestion; candidate-generation, adjudication, semantic-judging, and end-to-end wall durations | `stage-timings.json` intervals + scorer clock immediately before create-new result |
| `accounting.usage` | Exact job/session bindings, requests, input/output/cache-read/cache-write tokens, cost, error requests, model/provider/agent breakdown | Exact bound session rows in OMP `stats.db`, or the same immutable message usage records in those session JSONL files when the database contains none |
| `comparison.checks`, `comparison.passed` | Per-threshold observed value/operator/result and aggregate result | Existing score fields + wall duration + exact bound-session cost |

`accounting.complete` and top-level `complete` are true only in a created result; blocked runs have
no result. Cost is the sum of observed model-reported costs for the exact bound session set, not an estimate.
Every model breakdown retains provider, model, agent type, requests, tokens, and cost.

## Directional thresholds

All checks must pass:

| Metric | Required development result | Historical five-PR baseline |
| --- | ---: | ---: |
| False positives | `< 8` | 8 |
| Precision | `> 33.3%` | 33.3% (4/12 accepted signal) |
| True positives | `>= 4` | 4 |
| Recall | `>= 33.3%` | 33.3% |
| F2 | `>= 33.3%` | 33.3% |
| Wall time | `< 19m 17.335s` (`1,157,335 ms`) | 38m 34.670s |
| Exact bound-session model cost | `< $79.5203485` | $159.040697 |

A failed check is evidence that the correction did not clear the approved boundary. Report the
first failed design boundary and preserve the run; do not claim completion, release variance, or a
larger-cohort result.

## Historical five-PR baseline (2026-08-12)

The retained baseline used `woostack-review` revision
`249522f3f3f0a33949b28c0515e8db62ef66b413` on Oh My Pi across the five rank-one fixtures. It
recorded 38 first-pass candidate-generation jobs, 10 validator jobs in the then-current workflow,
38 semantic judgments against 15 goldens, 12 accepted findings, and complete native posting/read-
back. Core quality was 4 TP, 8 FP, and 8 FN: 33.3% precision, recall, F1, and F2, with zero missing
or malformed judgments.

Wall time was 38 minutes 34.670 seconds. Exact controller-session OMP accounting was $159.040697
across 1,427 model requests: 12,425,670 input tokens, 300,971 output tokens, and 186,126,720
cache-read tokens. This is one historical observation under the retired workflow, not a price
forecast, release distribution, ten-PR result, or 50-PR result.
