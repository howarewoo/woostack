# Testing guidance for bounded Execute tasks

This is the canonical testing doctrine for woostack. It is guidance for a bounded
[`woostack-execute`](../SKILL.md) task, not a separate command or delegation workflow.
[`woostack-simplify`](../../woostack-simplify/SKILL.md) uses this same rule for its
focused baseline and final checks. Reading this reference invokes no workflow and
installs nothing; there is no mandatory cross-skill invocation or installation
dependency.

A request to add tests is ordinary bounded Execute input. Resolve the exact target, the observable
behavior and boundaries it covers, the acceptance-defined success and failure conditions, and the
focused checks that prove the result from the outcome and current source — a caller-supplied
contract or template is a convenience, never a gate. Execute retains the task's test-only scope: it
does not turn a test discrepancy into an unapproved production fix, discover a project or provider,
manage subagents, or add a handoff. Report a behavior discrepancy for a scope decision when the
admitted task does not authorize a production correction.

## Select checks rather than accumulate them

A command's presence in a manifest or CI configuration does not make it required locally for
every task. Select the smallest established set that proves the promised behavior. If the whole
relevant suite is already cheap, run it rather than spending more effort micro-selecting tests.
An existing targeted test that covers the change can be the acceptance smoke — do not add another
scenario or a fixed test sequence for bookkeeping. Preserve explicit user, repository, and
accepted-task requirements; ambiguous requirements are not permission to waive them.

## Keep the inner loop focused, broaden before completion

When test-first is required, observe Red and Green with the focused test selection, without
mutating and restoring production code to manufacture a Red result. Do not restart the full
repository suite after every edit. Before completion, cover affected consumers and integration
boundaries; expand for shared infrastructure, changed dependencies or configuration,
cross-cutting changes, uncertain impact, or an explicit requirement. These are selection
principles, not three mandatory test stages.

Otherwise, establish the behavior from source and acceptance, use the repository's effective
existing checks, and add a regression test when it adds real coverage. Demonstrating that a new
regression test detects the defect is preferable when it is feasible without distorting the change.
Do not invent a new test contract when the outcome and source already supply enough evidence.

## Meaningful coverage

Choose tests for the behavior the task promises, not for implementation trivia. Cover:

- the happy path;
- every material error path;
- edge and boundary conditions; and
- each acceptance-defined success and failure outcome.

Prefer fast, deterministic tests at the lowest level that exercises the real contract. Retain
material success, error, boundary, and acceptance coverage. Add tests for actual gaps, not
duplicate cases at every layer, exact instruction wording, or implementation trivia. Expensive
end-to-end and live-host checks are appropriate when their boundary is implicated, not as default
extra ceremony.

Test observable behavior, boundaries, conditions that must hold, state transitions, rule precedence,
and real failures. Follow the repository's existing runner, file layout, and naming conventions.
A materially unclear behavior decision — inputs, outputs, errors, or integration boundaries — is
clarified before tests are written rather than guessed into them.

## Existing code: focused characterization baseline

When adding tests to code that already exists, write characterization tests that pin the current
behavior. A focused characterization baseline is sufficient when it covers a bounded refactor;
record pre-existing failures or missing evidence where feasible. Pre-existing failures remain
visible, not passes. A characterization task preserves the existing implementation while still
requiring a focused check and an observed result.

## When evidence still applies

Reuse an observed command and result while its relevant source, tests, fixtures, dependencies,
configuration, and environment remain applicable. A handoff, commit-message change, new revision
identifier, or unrelated prose edit alone does not invalidate it. Changed relevant inputs or
uncertain equivalence require the affected checks to be rerun. A newly integrated combination
needs evidence for its interactions; successful child tests alone cannot establish that. A change
after verification invalidates affected proof.

## Slow checks: bounded diagnosis, no waiver

When a check is unexpectedly slow, inspect progress, selected scope, startup and dependency work,
resource contention, and unavailable external services. Use existing runner and host timeout and
concurrency capabilities where appropriate. Avoid duplicate launches, unchanged blind retries,
and unbounded waiting without new evidence. Do not introduce a universal time limit or terminate
unrelated processes. A timed-out, cancelled, failed, or unrun required check remains unverified,
not a pass; the existing bounded-recovery and task-owned-resource rules still apply.

## Targets without a test runner

When the target has no test runner, use one concrete verification command with an observable result
or exit status. Run it during Execute and record the observation. Never invent a runner or report an
unrun command as passing.

## Local proof is not remote readiness

Required local verification and remote merge readiness are different. Do not invent CI coverage,
weaken protections, mark unrun checks passed, or wait for post-delivery CI contrary to the
existing delivery boundary.

## Verification and delivery boundary

Inspect the final diff and use established checks under
[Execute's verification rule](../SKILL.md#implement-and-verify). Failed or unrun required checks
leave the task incomplete: never weaken assertions, suppress failures, or claim a pass. Invoke
[`woostack-commit`](../../woostack-commit/SKILL.md) only when the caller requested a commit or PR;
otherwise report the verified local diff without publishing it.
