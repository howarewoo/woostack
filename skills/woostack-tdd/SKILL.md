---
name: woostack-tdd
description: "woostack's canonical test-driven-development home and on-demand test-adder. The single source for the TDD kernel — Red→Green→Refactor, test-first, cover happy/error/edge/success+failure, framework-aware, no-runner→concrete verification — that woostack-plan, woostack-execute, woostack-debug, and bootstrap patterns.md §7 should link to instead of restating. Also the 14th public command: /woostack-tdd <target> adds appropriate tests to an existing code block, PR, spec, or plan — one verb, target-routed (code→colocated *.test files, PR→tests for the gh pr diff surface, spec→strengthen §7 acceptance criteria, plan→fill failing-test steps) — with a characterization carve-out for existing code (new code is red-first; existing code pins current behavior). Writes tests to the working tree and hands to woostack-commit; never commits, merges, or authors status:/branch:; owns no approval gate."
---

# woostack-tdd

Two roles in one skill. **(1) The canonical TDD doctrine home** — the kernel below is stated
once here and *linked*, never restated, by [woostack-plan](../woostack-plan/SKILL.md),
[woostack-execute](../woostack-execute/SKILL.md), [woostack-debug](../woostack-debug/SKILL.md),
and [bootstrap patterns.md §7](../woostack-bootstrap/references/patterns.md), honoring the repo's
"cross-link, do not duplicate" rule. **(2) The 14th public command** — `/woostack-tdd <target>`
adds the appropriate tests to an existing block of code, a PR, a spec, or a plan. It writes tests
to the working tree and hands to [woostack-commit](../woostack-commit/SKILL.md); it never commits,
merges, or touches a spec's `status:`/`branch:`, and owns no approval gate.

## The TDD kernel

The canonical test-driven-development discipline for all of woostack. Other skills **link** this
section; they do not restate it.

**Red → Green → Refactor.** For code woostack is *authoring*, the test comes first:

1. **Red** — write a failing test describing the expected behavior; run it, watch it fail.
2. **Green** — write the minimal code to make it pass; run it, watch it pass.
3. **Refactor** — clean up names, duplication, and structure with the tests green; re-run to
   confirm they stay green.

**Coverage classes.** Appropriate tests span, per behavior: the **happy** path, every **error**
path, **edge**/boundary conditions, and both **success and failure** outcomes — exactly what a
spec's §7 Acceptance-criteria slots enumerate.

**No-runner substitution.** In a target with no test runner (a docs/skills repo), "the failing
test" becomes a concrete **verification command** — a `grep`, a `bash -n`, a link check, or an
existing script's test — with exact expected output. Never a vague "verify it works."

<CHARACTERIZATION-CARVE-OUT>
Test-first applies to code being authored. When adding tests to code that ALREADY EXISTS (the
`code` and `PR` command targets), you cannot write the test first — the code is already there.
The one sanctioned departure: write CHARACTERIZATION tests that pin the code's CURRENT behavior,
then use them as the regression safety net. New code is red-first; existing code is
characterization. Forcing a red by mutating-then-restoring existing code is NOT required.
</CHARACTERIZATION-CARVE-OUT>

**Framework-aware.** Follow the project's runner and file conventions — Vitest everywhere except
React Native (Jest via `jest-expo`), Playwright for E2E, tests colocated as `*.test.ts(x)` or in
`__tests__/`. The project-specific standard lives in
[patterns.md §7](../woostack-bootstrap/references/patterns.md).

**Clarify before writing** when inputs, outputs, error contracts, or integration points are
unclear — don't guess them.

## `/woostack-tdd <target>` — add appropriate tests

One verb — *add the appropriate tests* — applied to whatever the argument resolves to.
Auto-detect the target by argument shape:

| Target | Detected by | What it produces |
|---|---|---|
| **code** | a source path, or pasted code | colocated `*.test.ts(x)` per the project runner; **characterization** tests for existing code (see the carve-out) |
| **PR** | a PR number or URL | tests covering the **diff surface only** — read it with `gh pr diff <n>` (read-only inspection; `git diff <base>...HEAD` for a local branch) |
| **spec** | a path under `.woostack/specs/` | strengthen the testable **§7 Acceptance criteria** in place (happy/error/edge per behavior) |
| **plan** | a path under `.woostack/plans/` | fill each task's **failing-test-first step** with the actual test and exact expected output |
| **(none)** | no argument | **ask** what to test; never guess (mirrors [woostack-debug](../woostack-debug/SKILL.md)) |

Apply the kernel to whichever target: real tests for code/PR, the artifact's test-equivalent for
spec/plan. In a no-runner target, substitute the concrete verification command per the kernel. If
the argument is ambiguous, **ask** — don't guess the target type.

## Memory

Recall testing `gotcha`/`pattern` notes for the target's working set before adding tests; distill
**at most one** durable testing `pattern` at the end through the reject-by-default gate. The note
schema, recall procedure, and distill gate are defined once in
[memory.md](../woostack-init/references/memory.md) — link, never restate.

## Hard constraints

- **Single source for the kernel.** The kernel above is stated once; consumers link it. Adding a
  duplicate restatement elsewhere is the anti-pattern this skill exists to remove.
- **Never commits or merges.** Writes tests/edits to the working tree and hands to
  [woostack-commit](../woostack-commit/SKILL.md).
- **Gate-light.** Owns no approval gate (like `woostack-execute`/`woostack-harden`). For a
  spec/plan edit, show the before/after diff; do not block.
- **Authors no `status:`/`branch:`.** Spec/plan enrichment is content-only; never author a phase
  transition or fork a second plan. The `spec : plan : PRs = 1 : 1 : N` invariant — defined in
  [conventions.md](../woostack-status/references/conventions.md) — is untouched. When the target's
  `status:` is ≥ `planning` (a plan already exists), surface that the plan may need re-derivation;
  still edit content only.
- **No runtime delegation.** `woostack-execute` and `woostack-debug` write their tests inline and
  link this kernel for the "how"; they do not invoke this skill at runtime.
- **Characterization for existing code only.** New code stays red-first; the carve-out is not a
  license to skip test-first when authoring.
- **No-runner → concrete verification.** Never a vague "verify it works."
- **Distill durable knowledge only.** Reject-by-default; ≤1 testing `pattern` per run; never
  feature-specific trivia.
