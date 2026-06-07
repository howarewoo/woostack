**Source:** .woostack/specs/2026-06-07-woostack-tdd.md

# woostack-tdd Implementation Plan

**Goal:** Add a public `woostack-tdd` skill that is the single canonical home for the TDD kernel and an on-demand `/woostack-tdd <target>` command that adds appropriate tests to a code block, PR, spec, or plan.

**Architecture:** Increment 1 creates `skills/woostack-tdd/SKILL.md` (doctrine kernel + target-routed command) and wires it into the public surface (routing row + AGENTS.md counts/list/file-map) — a fully working new command on its own. Increment 2 stacks on top and de-duplicates the kernel: the 6 sites that currently restate TDD doctrine are repointed to *link* the new kernel while keeping their context-specific delta. No runtime delegation; no app build/CI (skills repo).

**Tech Stack:** Markdown skill assets only. This repo has **no test runner** (AGENTS.md: "no application source code, app lockfile, build, or CI"), so every "failing test" is a concrete `grep`/link-check verification command with exact expected output (woostack convention, `woostack-plan/SKILL.md:91-93`). Source control via Graphite (`gt`).

---

## Increment 1: Create the woostack-tdd skill + wire the public surface

> One independently shippable PR — a new, fully-routed `/woostack-tdd` command. Its own Graphite branch, stacked on the spec+plan PR.

### Task 1: Author `skills/woostack-tdd/SKILL.md`

**Files:**
- Create: `skills/woostack-tdd/SKILL.md`

- [ ] **Step 1: Write the failing verification**

```bash
# From repo root. Asserts the file exists with its load-bearing markers.
test -f skills/woostack-tdd/SKILL.md \
  && grep -q '^name: woostack-tdd$' skills/woostack-tdd/SKILL.md \
  && grep -q '## The TDD kernel' skills/woostack-tdd/SKILL.md \
  && grep -q 'CHARACTERIZATION-CARVE-OUT' skills/woostack-tdd/SKILL.md \
  && grep -q '/woostack-tdd <target>' skills/woostack-tdd/SKILL.md \
  && grep -q 'Never commits or merges' skills/woostack-tdd/SKILL.md \
  && echo TDD_SKILL_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output / `No such file or directory` (file absent).

- [ ] **Step 3: Create the file with this exact content**

````markdown
---
name: woostack-tdd
description: "woostack's canonical test-driven-development home and on-demand test-adder. The single source for the TDD kernel — Red→Green→Refactor, test-first, cover happy/error/edge/success+failure, framework-aware, no-runner→concrete verification — that woostack-plan, woostack-execute, woostack-debug, and bootstrap patterns.md §7 LINK instead of restating. Also the 14th public command: /woostack-tdd <target> adds appropriate tests to an existing code block, PR, spec, or plan — one verb, target-routed (code→colocated *.test files, PR→tests for the gh pr diff surface, spec→strengthen §7 acceptance criteria, plan→fill failing-test steps) — with a characterization carve-out for existing code (new code is red-first; existing code pins current behavior). Writes tests to the working tree and hands to woostack-commit; never commits, merges, or authors status:/branch:; owns no approval gate."
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
````

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `TDD_SKILL_OK`.

- [ ] **Step 5: Verify every cross-link resolves**

```bash
# Each linked path, resolved relative to skills/woostack-tdd/, must exist.
cd skills/woostack-tdd && for p in \
  ../woostack-plan/SKILL.md ../woostack-execute/SKILL.md ../woostack-debug/SKILL.md \
  ../woostack-bootstrap/references/patterns.md ../woostack-commit/SKILL.md \
  ../woostack-status/references/conventions.md ../woostack-init/references/memory.md; do
  test -f "$p" || echo "BROKEN: $p"; done; echo LINKS_CHECKED
```

Expected: PASS — prints only `LINKS_CHECKED` (no `BROKEN:` lines). Then commit:

```bash
gt create -m "feat(woostack-tdd): canonical TDD kernel + /woostack-tdd add-tests command"
```

### Task 2: Add the Command-Routing row to `using-woostack`

**Files:**
- Modify: `skills/using-woostack/SKILL.md` (Command Routing table, after the `woostack-debug` row)

- [ ] **Step 1: Write the failing verification**

```bash
grep -q '`/woostack-tdd <target>`.*`woostack-tdd`' skills/using-woostack/SKILL.md && echo ROUTE_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (no routing row yet).

- [ ] **Step 3: Insert the routing row**

After the existing line:

```
| `/woostack-debug <target> [--auto]`, find a bug's root cause before fixing (gated; `--auto` for autonomous) | `woostack-debug` |
```

add:

```
| `/woostack-tdd <target>`, add appropriate tests to a code block, PR, spec, or plan (gate-light; TDD doctrine home) | `woostack-tdd` |
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `ROUTE_OK`. Then commit:

```bash
gt modify -c -m "feat(woostack-tdd): route /woostack-tdd in using-woostack"
```

### Task 3: Update `AGENTS.md` — surface list, counts, file map

**Files:**
- Modify: `AGENTS.md` (canonical; `.claude/CLAUDE.md` is a symlink to it)

> Read the real strings first — the counts ("thirteen", "fifteen") and list are authoritative in the file, not in any cached copy. Apply each substitution exactly.

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'fourteen skills' AGENTS.md \
  && grep -q 'woostack-tdd' AGENTS.md \
  && grep -q 'sixteen `SKILL.md` files' AGENTS.md \
  && grep -q 'fourteen-skill command surface' AGENTS.md \
  && ! grep -q 'thirteen' AGENTS.md \
  && ! grep -q 'fifteen' AGENTS.md \
  && echo AGENTS_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (counts still say thirteen/fifteen; no `woostack-tdd`).

- [ ] **Step 3: Apply the five edits**

1. `The public command/adoption surface has thirteen skills:` → `... has fourteen skills:`
2. In that bullet list, after the `woostack-debug` bullet add:
   `` - [`woostack-tdd`](skills/woostack-tdd/SKILL.md) ``
3. `they have no routing row and are absent from the thirteen-skill command` →
   `... absent from the fourteen-skill command`
4. `Do not move or rename any of the fifteen `SKILL.md` files (the thirteen public command/adoption skills plus the internal `woostack-ideate` and `woostack-harden`).`
   → `... any of the sixteen `SKILL.md` files (the fourteen public command/adoption skills plus the internal `woostack-ideate` and `woostack-harden`).`
5. In **Mode B**'s command enumeration (`... `/woostack-status`, `/woostack-visualize`, or `/woostack-debug`, including intent-equivalent wording.`) insert `/woostack-tdd` into the list:
   `... `/woostack-visualize`, `/woostack-debug`, or `/woostack-tdd`, including intent-equivalent wording.`
6. In **Quick file map**, after the `woostack-debug` entry add:
   ```
   - TDD doctrine home and add-tests command (public command):
     [`skills/woostack-tdd/SKILL.md`](skills/woostack-tdd/SKILL.md)
   ```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `AGENTS_OK`.

- [ ] **Step 5: Confirm the symlink reflects the change**

```bash
grep -q 'fourteen skills' .claude/CLAUDE.md && echo SYMLINK_OK
```

Expected: PASS — prints `SYMLINK_OK` (symlink resolves to the edited `AGENTS.md`). Then commit:

```bash
gt modify -c -m "feat(woostack-tdd): list woostack-tdd in AGENTS.md surface, counts, file map"
```

---

## Increment 2: Extract the kernel — de-dup the 6 consumer sites

> One independently shippable refactor PR, stacked on Increment 1. Each site links the new kernel and drops its restated doctrine while keeping its context-specific delta. Its own Graphite branch.

### Task 1: `patterns.md §7` — keep the project standard, link the kernel

**Files:**
- Modify: `skills/woostack-bootstrap/references/patterns.md:129-148` (§7)

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'woostack-tdd' skills/woostack-bootstrap/references/patterns.md \
  && ! grep -q 'minimum code to make it pass' skills/woostack-bootstrap/references/patterns.md \
  && grep -q 'jest-expo' skills/woostack-bootstrap/references/patterns.md \
  && echo PATTERNS_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (kernel workflow prose still present; no `woostack-tdd` link).

- [ ] **Step 3: Replace the §7 body**

Replace lines 129-148 (the whole `## 7. Test-Driven Development` section through "A feature is **not complete** until all tests pass.") with:

```markdown
## 7. Test-Driven Development

Red → Green → Refactor, test-first, non-negotiable. The canonical TDD kernel — the workflow,
coverage classes, and no-runner substitution — lives once in
[woostack-tdd](../../woostack-tdd/SKILL.md); follow it. This section records only the
**project-specific** standard layered on top:

**Frameworks:** Vitest everywhere except React Native (uses Jest via `jest-expo`). Playwright for
E2E. Test files colocated with source as `*.test.ts(x)` or in `__tests__/`.

A feature is **not complete** until all tests pass.
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `PATTERNS_OK` (kernel linked; restated "minimum code to make it pass" workflow gone; project framework standard kept).

```bash
gt create -m "refactor(woostack-tdd): patterns.md §7 links the TDD kernel"
```

### Task 2: `woostack-plan` §"Bite-sized tasks (TDD)" — keep step shape, link the kernel

**Files:**
- Modify: `skills/woostack-plan/SKILL.md:85-93`

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'woostack-tdd' skills/woostack-plan/SKILL.md \
  && ! grep -q 'Never a vague "verify it works."' skills/woostack-plan/SKILL.md \
  && grep -q 'write the failing test → run it, confirm it fails' skills/woostack-plan/SKILL.md \
  && echo PLAN_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (standalone no-runner paragraph still present; no kernel link).

- [ ] **Step 3: Replace the second paragraph**

Keep the first paragraph (lines 85-89, the step-decomposition / checkbox mechanics) unchanged.
Replace the second paragraph (lines 91-93, currently:
`In a target without a test runner (e.g. a docs/skills repo), "the failing test" becomes a concrete **verification command** — a `grep`, a `bash -n`, a link check, or an existing script's test — with exact expected output. Never a vague "verify it works."`)
with:

```markdown
The TDD discipline these steps embody — red→green→refactor, the coverage classes, and the
no-runner→concrete-verification substitution — is the canonical kernel in
[woostack-tdd](../woostack-tdd/SKILL.md); this section applies it to plan-task shape.
```

> Note: `references/plan-template.md` is the literal task scaffold (mechanics) and keeps its own terse no-runner note — it is NOT edited here.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `PLAN_OK` (kernel linked; the duplicated no-runner doctrine paragraph removed; step-shape sentence kept).

```bash
gt modify -c -m "refactor(woostack-tdd): woostack-plan links the TDD kernel"
```

### Task 3: `woostack-execute` drivers — keep impl-loop framing, link the kernel

**Files:**
- Modify: `skills/woostack-execute/references/inline-driver.md:12-17`
- Modify: `skills/woostack-execute/prompts/implementer.md:24-28`

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'woostack-tdd' skills/woostack-execute/references/inline-driver.md \
  && grep -q 'woostack-tdd' skills/woostack-execute/prompts/implementer.md \
  && ! grep -qF 'then **refactor** with the tests green' skills/woostack-execute/references/inline-driver.md \
  && echo EXEC_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (full red-green-refactor restatement still in inline-driver; no kernel links).

- [ ] **Step 3a: Replace inline-driver.md step 1**

Replace step 1 (lines 12-17) with:

```markdown
1. **Follow test-driven development** per the [woostack-tdd kernel](../../woostack-tdd/SKILL.md)
   — red-first for new code, characterization for code that already exists; refactor with the
   tests green; in a no-runner target substitute the concrete verification the plan specifies.
   This is a principle, not a hard dependency: if the kernel isn't loaded, follow TDD by hand.
```

- [ ] **Step 3b: Update implementer.md instruction 1 (keep self-contained)**

implementer.md is a prompt injected into a **fresh, context-free subagent**, so it keeps a
**self-contained** inline TDD rule (it is not reduced to a bare link — same rationale that leaves
`subagent-driver.md` alone). Replace instruction 1 (lines 24-28) with an aligned inline rule
that also names the canonical source:

```markdown
1. Follow test-driven development (canonical: the woostack-tdd kernel,
   `skills/woostack-tdd/SKILL.md`): for new code, write the failing test first, watch it fail,
   write the minimal code, watch it pass, then refactor with the tests green; for code that
   already exists, write characterization tests pinning current behavior. If the change has no
   runnable test harness (e.g. a docs/skill edit), run the concrete verification the task
   specifies instead (grep / link check / structural assertion).
```

> Note: for implementer.md the de-dup is **link-present only** (the inline rule legitimately
> stays — a context-free subagent must not depend on following a link). Full phrase-removal
> applies only to `inline-driver.md`, which the link-following main agent reads.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `EXEC_OK` (both drivers link the kernel; the verbose red-green-refactor restatement removed; impl-loop framing kept).

```bash
gt modify -c -m "refactor(woostack-tdd): execute drivers link the TDD kernel"
```

### Task 4: `woostack-debug` Phase 4 — keep failing-test-first, repoint to the kernel

**Files:**
- Modify: `skills/woostack-debug/SKILL.md:77-81` (Phase 4, step 1)

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'woostack-tdd' skills/woostack-debug/SKILL.md \
  && ! grep -q 'reusing the TDD discipline embodied in' skills/woostack-debug/SKILL.md \
  && grep -q 'Write a failing test first' skills/woostack-debug/SKILL.md \
  && echo DEBUG_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (step still says "reusing the TDD discipline embodied in woostack-execute"; no woostack-tdd link).

- [ ] **Step 3: Replace Phase 4 step 1**

Replace step 1 (lines 77-81) with:

```markdown
1. **Write a failing test first.** The simplest reproduction of the bug, automated if a test
   harness exists — per the [woostack-tdd kernel](../woostack-tdd/SKILL.md). In a target with no
   test runner, the "failing test" is a concrete verification command (a `grep`, a `bash -n`, a
   link check) with exact expected output — never a vague "verify it works". You must have this
   before fixing.
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `DEBUG_OK` (kernel linked; the "embodied in woostack-execute" restatement gone; failing-test-first-before-a-fix kept).

```bash
gt modify -c -m "refactor(woostack-tdd): debug Phase 4 links the TDD kernel"
```

### Task 5: `woostack-build:105` — repoint the by-reference TDD mention

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (the step-9 line: "each implemented with TDD, …")

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'with TDD (the \[woostack-tdd kernel\](../woostack-tdd/SKILL.md))' skills/woostack-build/SKILL.md && echo BUILD_OK
```

- [ ] **Step 2: Run it, confirm it fails**

Run: the command above.
Expected: FAIL — no output (mention is by-reference only, unlinked).

- [ ] **Step 3: Add the kernel link**

The phrase wraps: line 104 ends with `each implemented`; line 105 begins `with TDD,`. On
**line 105**, change `with TDD,` → `with TDD (the [woostack-tdd kernel](../woostack-tdd/SKILL.md)),`.
Edit only the line-105 fragment; leave `each implemented` on line 104.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: the Step 1 command.
Expected: PASS — prints `BUILD_OK`.

- [ ] **Step 5: Final de-dup link check**

```bash
# Every new kernel back-link resolves from its own file's directory.
err=0
check(){ ( cd "$1" && test -f "$2" ) || { echo "BROKEN: $1 -> $2"; err=1; }; }
check skills/woostack-bootstrap/references ../../woostack-tdd/SKILL.md
check skills/woostack-plan ../woostack-tdd/SKILL.md
check skills/woostack-execute/references ../../woostack-tdd/SKILL.md
check skills/woostack-execute/prompts ../../woostack-tdd/SKILL.md
check skills/woostack-debug ../woostack-tdd/SKILL.md
check skills/woostack-build ../woostack-tdd/SKILL.md
[ $err -eq 0 ] && echo ALL_LINKS_OK
```

Expected: PASS — prints `ALL_LINKS_OK` (no `BROKEN:` lines). Then commit:

```bash
gt modify -c -m "refactor(woostack-tdd): woostack-build step 9 links the TDD kernel"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec section maps to a task. §4 Half-A (extract) → Inc 2 Tasks 1-5; §4 Half-B (command) → Inc 1 Task 1; §5 components → Inc 1 Tasks 1-3 + Inc 2 Tasks 1-5; §6 error handling → encoded in skill `## Hard constraints` (Inc 1 Task 1) + the link/grep checks.
- [x] **AC coverage** — AC1 (doctrine home) → Inc 1 Task 1 (Steps 1/4 grep `## The TDD kernel`, frontmatter, carve-out). AC2 (4 targets + no-arg + framework) → Inc 1 Task 1 (target-router table + framework + no-runner + `(none)→ask`). AC3 (boundaries) → Inc 1 Task 1 (`## Hard constraints`: never commits/merges, gate-light, no status:/branch:, no runtime delegation). AC4 (extracted, not duplicated) → Inc 2 Tasks 1-5: full de-dup (link-present **and** phrase-absent) for the main-agent-read sites (`patterns.md`, `woostack-plan`, `inline-driver.md`, `woostack-debug`, `woostack-build`); **link-present only** for `implementer.md` (a context-free subagent prompt keeps its inline rule); `subagent-driver.md`/`plan-template.md` left untouched (not in the task list). AC5 (surface wired) → Inc 1 Tasks 2-3 (routing row; AGENTS.md counts thirteen→fourteen / fifteen→sixteen, list, file map) with the `! grep` guards catching one-count-but-not-the-other drift.
- [x] **No placeholders** — full SKILL.md content inline; every edit gives exact old→new text and an exact grep with expected output.
- [x] **Type consistency** — the kernel anchor name (`## The TDD kernel`), the link target (`woostack-tdd/SKILL.md`), and the carve-out marker (`CHARACTERIZATION-CARVE-OUT`) are used identically across all tasks; relative link depths verified per file location in Inc 1 Task 1 Step 5 and Inc 2 Task 5 Step 5.
