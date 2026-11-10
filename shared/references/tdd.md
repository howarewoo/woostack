# Verification and testing procedures

Use these procedures to select checks, design behavioral protection, and assess existing evidence.
The active workflow owns task admission, sequencing, required evidence at its boundaries, and
completion. Reading this reference invokes no workflow and grants no implementation or delivery
authority.

For test-only work, keep the admitted scope explicit: report a discovered production discrepancy
instead of repairing it outside that scope. Start from existing protection: resolve the target,
observable behavior, and boundaries from current source and acceptance. An existing adequate baseline
is valid evidence; add or strengthen tests only for distinct uncovered behavior, regressions, or
material risks. Explicit test-only acceptance still applies, but needs no duplicate cases when
requested protection already exists.

## Selection, native capabilities, and caching

Prefer established native selection, one-shot execution, safe caching, diagnostics, and resource
controls without prescribing specific tools. Avoid running an aggregate command and equivalent
component checks redundantly on unchanged relevant inputs. If the relevant suite is already fast
and cheap, run it rather than micro-selecting tests. Account for non-imported fixtures, configuration,
and new integration combinations when selecting or reusing checks.

Preserve explicit user, repository, and task requirements. Consult authoritative, version-appropriate
documentation when capabilities are unclear or alternatives are warranted, not as a routine search.
New dependencies, migrations, or CI changes require authorized scope.

## Keep the inner loop focused, broaden before completion

When repository policy, admitted scope, or the user requires test-first, write the failing test
first and observe the expected Red result, add minimum implementation to achieve Green, then
refactor while green — all with focused selection. Never mutate production code to manufacture
a Red result. Do not restart the full suite after every edit.

Before completion, analyze impact on affected consumers and integration boundaries, including shared
infrastructure, changed dependencies or configuration, cross-cutting changes, and uncertain impact.
These call for impact analysis, not unlimited new acceptance. Additional evidence follows explicit
user, repository, or task requirements, or a named material risk: state the concrete failure,
consequence, affected boundary, and smallest adequate observation under the active workflow.
Reuse still-applicable results and preserve mandatory repository checks and targeted safety proof.

Without test-first, establish behavior from source and acceptance, use effective existing checks, and add a
regression test when it detects a genuine uncovered defect or risk. Demonstrating detection is
preferable when feasible without distorting the change. Do not invent a new test contract when
existing evidence suffices.

## Meaningful assertions over test volume

Optimize what failures tests detect, not their count. Choose fast, deterministic tests at the lowest
practical level exercising the real contract. Test observable behavior and real failures for actual
gaps — never exact instruction wording or implementation trivia. Use representative equivalent inputs
and relevant boundaries instead of mechanical combinations or duplicate coverage at multiple layers.

Preserve tests that detect distinct failure modes even when executing the same lines.
Consolidation must retain those protections; do not impose arbitrary test counts, one-test-per-function
rules, or weakened assertions.

## Representative volume and concurrency

When volume or concurrency can materially change the changed behavior's outcome, verify a
representative level drawn from repository evidence: existing fixtures or data, a documented
limit, observed usage, or the deployment assumptions the target already states. Assert the target
contract's expected results and multiplicity at that level, rejecting unintended loss,
deduplication, or duplication; intentional grouping or deduplication is checked against its own
expected output. Preserve required performance measurements and assertions when the task or
repository defines latency, throughput, or resource limits; otherwise elapsed time need not be the
assertion. An unknown production load stays an open uncertainty rather than becoming an invented
scale gate or a production probe.

## Proportional coverage and existing code

Coverage percentages and test counts are signals, not proof. Review changed behavior and affected
consumers; do not add tests merely to inflate a metric. Preserve explicit repository thresholds.
Coverage collection, property-based testing, and mutation testing are targeted responses to real
gaps, not mandatory inner-loop stages; never represent selected-test coverage as whole-repository coverage.

For existing code, reuse an adequate baseline for behavior-preserving refactors; add
characterization only for a genuine gap. Pre-existing failures remain visible failures, not passes.

## When evidence still applies

Reuse an observed command and result while its relevant source, tests, fixtures, dependencies,
configuration, and environment remain applicable. An unrelated prose edit, handoff, commit message,
or revision identifier alone does not invalidate it. Changed relevant inputs or uncertain
equivalence require affected checks to rerun. Newly integrated combinations require evidence for their
interactions; child passes alone cannot establish that.

## Slow checks: bounded diagnosis, no waiver

When a check is unexpectedly slow, inspect progress, selected scope, startup work, dependencies,
resource contention, and unavailable external services. Use existing runner and host timeout and
concurrency capabilities. Avoid duplicate launches, unchanged blind retries, and unbounded waits
without new evidence. Do not introduce universal time limits or terminate unrelated processes.
Timed-out, cancelled, failed, or unrun required checks remain unverified, not passes.


## Efficient CI/CD verification

When designing or tuning CI/CD, optimize **feedback time and regression confidence together**. Inspect the existing pipeline, test ownership, runner capacity, and actual job timings before changing execution policy. Separate queue time, setup/build work, test collection, execution, and artifact upload; address the measured bottleneck with existing platform and test-runner capabilities before adding scripts, dependencies, or infrastructure.

- **Select proportionately.** Use native changed-file, dependency-aware, or affected-project test selection for routine changes when its dependency model is trustworthy. Include affected consumers, fixtures, configuration, generated code, schema changes, and integration boundaries. A small suite that is already cheap needs no selection machinery.
- **Keep a broad backstop.** Targeted PR checks are not proof that other tests cannot regress. Preserve full or appropriately comprehensive verification on protected branches, release gates, or scheduled runs, and ensure required deployment checks cannot be bypassed. Unknown or failed impact analysis expands the test scope rather than silently skipping checks.
- **Tier expensive checks.** Keep quick deterministic checks and critical end-to-end smoke paths in the fast feedback loop; route broader integration, browser, compatibility, and long-running scenarios according to risk and release policy. Do not delete or weaken tests merely to meet a CI time budget.
- **Respect finite capacity.** Bound test workers by measured CPU, memory, and I/O pressure. Shard across genuinely independent runners only when available capacity and shard runtime outweigh queue and repeated setup costs. More workers on an overloaded VM can increase timeouts.
- **Eliminate redundant setup.** Cancel superseded change runs where safe, avoid duplicate jobs and builds, reuse package-manager caches and correctly keyed deterministic outputs, and provision expensive runtime dependencies only when needed. Treat caches as optional and untrusted; prefer native features over bespoke change routers.
- **Preserve diagnosability.** Keep tests isolated, failures blocking where required, retries bounded and visible, timeouts specific to the slow operation, and failure artifacts useful but proportionate. Do not turn flaky, timed-out, or skipped tests into passes.

Compare before/after queue time, median and tail duration, resource saturation, retries, timeouts, and failure detection. Record what verification ran, what was intentionally deferred, and where selective execution could miss a regression. Consult the repository's chosen CI and test-runner documentation for concrete commands and configuration rather than embedding framework-specific recipes here.

## Targets without a test runner

When the target has no test runner, use one concrete verification command with an observable result or
exit status. Run it within the authorized workflow and record the observation. Never invent a runner, fake fallback, or
report an unrun command as passing.

## Verification and delivery boundary

Local proof does not establish remote merge readiness. The active workflow owns delivery and
publication authority; failed or unrun required checks leave its affected boundary unverified.
