# Testing guidance for bounded Execute tasks

Canonical testing guidance for bounded [`woostack-execute`](../SKILL.md) tasks,
[`woostack-simplify`](../../woostack-simplify/SKILL.md) checks, and newly authored
[`woostack-plan`](../../woostack-plan/SKILL.md) verification expectations. Reading it
invokes no workflow and requires no skill installation or handoff.

A request to add or strengthen tests is ordinary bounded Execute input under
[test-only scope](../SKILL.md#test-only-outcomes). Start from existing protection: resolve the
target, observable behavior, and boundaries from current source and acceptance. An existing
adequate baseline is a valid stopping point; add or strengthen tests only for distinct uncovered
behavior, regressions, or material risks. Explicit test-only acceptance still applies, but needs
no duplicate cases when requested protection already exists.

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
a Red result. Do not restart the full suite after every edit. Before completion, cover affected
consumers and integration boundaries; expand for shared infrastructure, changed dependencies or
configuration, cross-cutting changes, uncertain impact, or explicit requirements.

Otherwise, establish behavior from source and acceptance, use effective existing checks, and add a
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

## Targets without a test runner

When the target has no test runner, use one concrete verification command with an observable result or
exit status. Run it during Execute and record the observation. Never invent a runner, fake fallback, or
report an unrun command as passing.

## Verification and delivery boundary

Local proof does not establish remote merge readiness. Delivery and publication remain owned by
[`woostack-execute`](../SKILL.md#implement-and-verify) and
[`woostack-commit`](../../woostack-commit/SKILL.md); failed or unrun required checks leave the task
incomplete.
