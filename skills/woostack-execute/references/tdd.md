# Testing guidance for bounded Execute tasks

This is the canonical testing doctrine for woostack. It is guidance for a bounded
[`woostack-execute`](../SKILL.md) task, not a separate command or delegation workflow.

A request to add tests is ordinary bounded Execute input. Supply the exact target, the observable
behavior and boundaries to cover, the acceptance-defined success and failure conditions, and the
focused checks that prove the result. Execute retains the task's test-only scope: it does not turn
a test discrepancy into an unapproved production fix, discover a project or provider, manage
subagents, or add a handoff. Report a behavior discrepancy for a scope decision when the admitted
task does not authorize a production correction.

## Red → Green → Refactor

For new implementation, write the test first:

1. **Red:** write a failing test that describes the expected behavior, run it, and observe the
   expected failure.
2. **Green:** write the minimum implementation needed to pass, run the test, and observe success.
3. **Refactor:** improve names, duplication, and structure while the test remains green, then run
   it again.

A complete task records the commands and the observed Red and Green results. A missing, vague, or
incomplete test contract blocks implementation rather than inviting guessed behavior.

## Meaningful coverage

Choose tests for the behavior the task promises, not for implementation trivia. Cover:

- the happy path;
- every material error path;
- edge and boundary conditions; and
- each acceptance-defined success and failure outcome.

Test observable behavior, boundaries, conditions that must hold, state transitions, rule precedence,
and real failures. Follow the repository's existing runner, file layout, and naming conventions.
Clarify materially unclear inputs, outputs, errors, or integration boundaries before writing tests.

## Existing code: characterization tests

Test-first applies to newly implemented behavior. When adding tests to code that already exists,
write characterization tests that pin the current behavior. Do not mutate and restore production
code merely to manufacture a Red result. A characterization task preserves the existing
implementation while still requiring a focused check and an observed result.

## Targets without a test runner

When the target has no test runner, replace the failing-test step with one concrete verification
command and its exact expected output or exit status. State the command and observation in the task
contract and run it during Execute. Never substitute a vague assurance such as “verify it works,”
and never invent a runner or report an unrun command as passing.

## Verification and delivery boundary

Use the target's established commands and keep mandatory checks mandatory. A failed or incomplete
check blocks delivery. Any source change after verification invalidates affected evidence and
requires fresh checks. Execute owns the focused verification, smoke scenario, commit, push, and one
reviewable draft PR through [`woostack-commit`](../../woostack-commit/SKILL.md); the testing doctrine
does not add provider requirements, project discovery, orchestration, or a second PR path.
