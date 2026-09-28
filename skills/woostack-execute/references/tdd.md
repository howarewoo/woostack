# Testing guidance for bounded Execute tasks

This is the canonical testing doctrine for woostack. It is guidance for a bounded
[`woostack-execute`](../SKILL.md) task, not a separate command or delegation workflow.

A request to add tests is ordinary bounded Execute input. Resolve the exact target, the observable
behavior and boundaries it covers, the acceptance-defined success and failure conditions, and the
focused checks that prove the result from the outcome and current source — a caller-supplied
contract or template is a convenience, never a gate. Execute retains the task's test-only scope: it
does not turn a test discrepancy into an unapproved production fix, discover a project or provider,
manage subagents, or add a handoff. Report a behavior discrepancy for a scope decision when the
admitted task does not authorize a production correction.

## Test-first when required, evidence always

When repository policy, the admitted outcome, or the user requires a test-first sequence, write the
failing test first and observe the expected Red result, add the minimum implementation and observe
Green, then refactor while green. Do not mutate and restore production code to manufacture a Red
result.

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

Test observable behavior, boundaries, conditions that must hold, state transitions, rule precedence,
and real failures. Follow the repository's existing runner, file layout, and naming conventions.
A materially unclear behavior decision — inputs, outputs, errors, or integration boundaries — is
clarified before tests are written rather than guessed into them.

## Existing code: characterization tests

When adding tests to code that already exists, write characterization tests that pin the current
behavior. A characterization task preserves the existing implementation while still requiring a
focused check and an observed result.

## Targets without a test runner

When the target has no test runner, use one concrete verification command with an observable result
or exit status. Run it during Execute and record the observation. Never invent a runner or report an
unrun command as passing.

## Verification and delivery boundary

Inspect the final diff and use established checks. Failed or unrun required checks leave the task
incomplete: never weaken assertions, suppress failures, or claim a pass. Recheck after relevant
changes. An existing targeted test may also be the acceptance smoke. Invoke
[`woostack-commit`](../../woostack-commit/SKILL.md) only when the caller requested a commit or PR;
otherwise report the verified local diff without publishing it.
