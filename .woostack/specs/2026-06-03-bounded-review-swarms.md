---
name: bounded-review-swarms
type: spec
status: done
date: 2026-06-03
branch: feature/bounded-review-swarms
links:
  - https://github.com/howarewoo/woostack/issues/182
---

# Bounded Review Swarms — Design Spec

> **Plan:** [[plans/2026-06-03-bounded-review-swarms]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

Local `/woostack-review` guidance currently says to spawn one review sub-agent per detected angle in parallel when the host supports it, with a sequential fallback for hosts without parallel sub-agents. That leaves a gap for constrained hosts that support parallel sub-agents, but only up to a fixed thread or task limit.

In Codex, a local run detected eight review angles while the host sub-agent runtime could spawn only six reviewers. The orchestrator had to run the remaining `types` and `architecture` angles manually. Without a bounded-concurrency pattern, a host can fail partway through the swarm, silently drop angles, or depend on the orchestrator noticing missing artifacts after the fact.

## 2. Goal

Add a bounded local review-swarm pattern that lets constrained hosts run all detected angles automatically.

The design must:

- launch at most `N` angle workers at once;
- continue draining the remaining angles after earlier workers finish;
- initialize every expected `findings.<angle>.json` artifact to `[]`;
- retry missing or non-array angle artifacts once after the full queue drains;
- propagate the resolved review tier/model context consistently to every scheduled worker;
- preserve existing CI matrix behavior;
- expose enough run metadata for the review summary to report bounded concurrency.

## 3. Non-goals

- Do not replace GitHub Actions matrix fan-out.
- Do not force every host to use the same shell-level sub-agent launcher.
- Do not add a new application build, app lockfile, or CI workflow for this repository.
- Do not change angle detection, validator semantics, severity floors, chunking, or posting behavior except where reporting bounded-swarm metadata is necessary.
- Do not make successful reviews fail solely because one angle artifact stayed invalid after one retry; record the degradation and keep the merge path safe with `[]`.

## 4. Approach

Use a hybrid design: ship a helper script plus update `woostack-review` prompt guidance.

The helper script should live under `skills/woostack-review/scripts/`, tentatively named `run-bounded-swarm.sh`. It should implement the host-agnostic queue mechanics that shell-capable local hosts can reuse:

- read expected angles from `$OUTDIR/angles.txt`;
- accept a max concurrency setting from an environment variable or argument;
- accept a host-supplied worker command template;
- start up to `N` workers at a time;
- wait for workers to finish and continue scheduling queued angles;
- validate artifacts after the first full drain;
- retry invalid angles once;
- write bounded-swarm metadata under `$OUTDIR`.

`SKILL.md` Stage 3 should make bounded execution the default local path whenever more than one angle is detected. With the default limit of `6`, small angle sets still behave like normal parallel execution, while larger angle sets drain safely instead of exceeding host capacity. Setting max concurrency to `1` is the explicit sequential fallback.

Stage 3 should describe two valid local bounded execution modes:

- native host bounded queue: use the host's own task/sub-agent API but follow the same queue, artifact initialization, retry, and metadata contract;
- shell helper: invoke `run-bounded-swarm.sh` with a worker command template when the host can express angle review work as a shell command.

The review summary guidance should read bounded-swarm metadata when present and mention that bounded concurrency was used, including the configured limit and any degraded angles.

When no explicit max concurrency is configured, the helper should default to `6`. That matches the constrained-host failure mode from issue 182 while still preserving bounded parallelism. Override precedence should be: CLI flag first, then `WOO_REVIEW_MAX_CONCURRENCY`, then default `6`.

## 5. Components & data flow

`detect-angles.sh` remains the source of the expected angle list and writes `$OUTDIR/angles.txt`.

Stage 3 then chooses either native bounded orchestration or the helper script:

1. Resolve `OUTDIR` once and export it to all workers.
2. Read each angle from `$OUTDIR/angles.txt`.
3. Before any worker starts, write `[]` to each `$OUTDIR/findings.<angle>.json`.
4. Schedule workers with no more than `max_concurrency` active at once.
5. Wait for all first-pass workers to finish.
6. Validate every expected `findings.<angle>.json` with `jq -e 'type == "array"'`.
7. Retry angles with missing, empty, or non-array artifacts once.
8. Validate again and leave still-invalid artifacts as `[]`.
9. Write `$OUTDIR/swarm-metrics.json`.
10. Continue to `merge-findings.sh`, validator passes, and posting as before.

The helper script's worker command should be a template that receives the angle through a placeholder or environment variable. A simple contract is enough:

- `WOO_REVIEW_ANGLE` contains the current angle;
- `WOO_REVIEW_ACTION_PATH` points to the installed review skill;
- `OUTDIR` points to the shared artifact directory;
- resolved tier/model environment is preserved for every worker, including `FORCE_TIER`, provider/model variables, and any existing review input/config override variables that Stage 3 already relies on;
- the worker must write `$OUTDIR/findings.$WOO_REVIEW_ANGLE.json`.

The helper should execute a generic shell worker command with those variables exported, rather than only printing a scheduling plan. Hosts that cannot express sub-agent work as a shell command should follow the same native bounded-queue contract in `SKILL.md`.

The metadata file should use a stable JSON shape:

```json
{
  "schema_version": 1,
  "mode": "bounded",
  "max_concurrency": 6,
  "angles_total": 8,
  "first_pass_failed": ["types"],
  "retry_angles": ["types"],
  "still_invalid": [],
  "degraded": false
}
```

If no bounded queue was used, the file can be absent. Summary code and prompt guidance should treat absence as the current behavior.

## 6. Error handling

Every expected artifact is initialized to `[]` before the first worker starts. This prevents a missing worker from being silently indistinguishable from a legitimate empty review in merge input, while the metrics file records whether the artifact had to be defaulted or retried.

The runner should treat these conditions as invalid after a worker exits:

- file missing;
- file empty;
- file is not valid JSON;
- JSON root is not an array.

Invalid artifacts are retried once after the entire first-pass queue drains, not immediately. That keeps scheduling simple and avoids starving queued angles on constrained hosts.

If an artifact is still invalid after retry, the runner writes `[]` back to that artifact and records the angle in `still_invalid` with `degraded: true`. This condition should not make the helper exit non-zero by itself. The downstream merge stage can proceed safely, and the review summary can disclose the degradation instead of leaving the orchestrator to infer it.

Worker process failures should not stop the whole queue immediately. They should be recorded as first-pass or retry failures, then handled through the same artifact validation path. A runner-level configuration or shell error that prevents scheduling any worker is different: that should return non-zero because no review swarm ran.

Tier/model inconsistency is not solved by bounded scheduling alone, so the runner must not introduce a new source of drift. Every scheduled worker must inherit the orchestrator's resolved tier/model environment. If the existing model-resolution code is wrong for a provider, that remains a separate bug; this feature's responsibility is to preserve and document the resolved context consistently across all queued angle workers.

## 7. Testing

Add focused script tests for the helper's deterministic behavior using fake angle workers:

- max concurrency is respected with more angles than the limit;
- every expected artifact is initialized to `[]` before worker execution;
- all angles eventually run when there are more angles than the limit;
- a missing artifact is retried once after the first queue drain;
- a non-array artifact is retried once after the first queue drain;
- a still-invalid artifact is reset to `[]` and recorded as degraded;
- `swarm-metrics.json` reports bounded mode, limit, total angles, retry angles, and degradation state.
- tier/model environment is propagated to every fake worker, for example by asserting a fake worker records the expected `FORCE_TIER`.

No app build or CI workflow should be added for this repository. Tests should follow the existing review script-test style under `skills/woostack-review/scripts/tests/`.

## 8. Open questions

No blocking open questions. The worker-command interface for `run-bounded-swarm.sh` should be environment-variable based (`WOO_REVIEW_ANGLE`) because it avoids shell quoting problems in command templates and makes tier/model propagation straightforward.
