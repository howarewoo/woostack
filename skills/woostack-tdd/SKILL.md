---
name: woostack-tdd
description: "Canonical Red→Green→Refactor guidance and `/woostack-tdd <target>` test addition for code, PRs, or an exact verified Linear project and issue. Writes local code-test output only; never commits, merges, or mutates Linear lifecycle content."
---

# woostack-tdd

Two roles in one skill. **(1) The canonical TDD doctrine home** — the kernel below is stated once
here and linked, never restated, by [woostack-plan](../woostack-plan/SKILL.md),
[woostack-execute](../woostack-execute/SKILL.md), [woostack-debug](../woostack-debug/SKILL.md), and
[bootstrap patterns.md §7](../woostack-bootstrap/references/patterns.md). **(2) The public command**
— `/woostack-tdd <target>` adds appropriate tests to code, a PR, or the local implementation surface
owned by one exact Linear project and issue. It writes local code-test output only and owns no
approval gate.

## The TDD kernel

**Red → Green → Refactor.** For code woostack is authoring, the test comes first:

1. **Red** — write a failing test describing the expected behavior; run it and observe the failure.
2. **Green** — write the minimum code that makes it pass; run it and observe success.
3. **Refactor** — improve names, duplication, and structure without changing behavior; re-run the
   test and keep it green.

Appropriate tests cover the observable happy path, error paths, edge and boundary conditions, and
both success and failure outcomes. In a target with no test runner, use a concrete verification
command with exact expected output, never a vague “verify it works.”

<CHARACTERIZATION-CARVE-OUT>
Test-first applies to code being authored. Existing code and PR targets may receive characterization
tests that pin current behavior. New behavior remains red-first; mutating and restoring existing
code merely to manufacture a failure is not required.
</CHARACTERIZATION-CARVE-OUT>

Follow the repository's runner, file placement, and naming conventions. Project-specific defaults
live in [patterns.md §7](../woostack-bootstrap/references/patterns.md). Stop rather than guessing
when inputs, outputs, error contracts, or integration points are absent from the owning contract.

## `/woostack-tdd <target>`

| Target | Required input | Output |
|---|---|---|
| **code** | source path or pasted code | local tests following the project runner; characterization tests for existing behavior |
| **PR** | exact PR number or URL | local tests for the diff surface read through read-only GitHub/Git evidence |
| **Linear issue** | exact project UUID or URL **and** exact issue UUID or URL | local code tests for the issue's immutable implementation contract |
| **none** | no argument | ask what to test and stop; never guess |

For an artifact-facing invocation, require both exact project and issue inputs. Through the
official host-exposed Linear MCP, independently read and verify project and issue identity, canonical
repository attribution, workspace/team, `woostack` ownership metadata, project membership, native
dependencies, work owner, and complete issue contract. An issue-only input, title match, ambiguous
reference, incomplete pagination, foreign resource, or failed read-back blocks before local writes.

Treat the verified issue description, acceptance criteria, dependencies, and verification steps as
immutable execution input. Write only tests in the local code worktree. Never mutate the project,
issue, relation, comment, native state, or typed lifecycle event. If the issue lacks testable detail,
report a planning defect for explicit reconciliation instead of repairing Linear from this command.

## Memory

Recall testing `gotcha` and `pattern` notes for the target's working set before adding tests. Distill
at most one durable testing pattern through the reject-by-default gate in
[memory.md](../woostack-init/references/memory.md); never record feature-specific lifecycle state.

## Hard constraints

- **Single kernel authority.** Consumers link this kernel rather than restating it.
- **Local code-test output only.** Do not author specification, plan, lifecycle, or transport files.
- **Read-only Linear input.** Exact verified project and issue identities are mandatory; all Linear
  content and metadata remain unchanged.
- **Never commits or merges.** Hand local test changes to
  [woostack-commit](../woostack-commit/SKILL.md).
- **No approval gate or runtime delegation.** Execute and debug apply this kernel inline.
- **Characterization is existing-code-only.** New behavior remains red-first.
- **Concrete verification.** Every no-runner substitution names a command and exact result.
