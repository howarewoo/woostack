---
name: woostack-tdd
type: spec
status: approved
date: 2026-06-07
branch: woostack-tdd
links:
---

# woostack-tdd: TDD doctrine home + add-tests command — Design Spec

> **Plan:** [[plans/2026-06-07-woostack-tdd]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

woostack's TDD doctrine is **scattered and restated** across five sites, with no canonical
home — directly against this repo's "Cross-link, do not duplicate" ethos (project AGENTS.md):

- `skills/woostack-bootstrap/references/patterns.md:129-148` (§7) — the kernel itself:
  Red→Green→Refactor, "tests written before implementation", coverage classes (user
  scenarios, edge/boundary, error conditions, success+failure), framework choices, "not
  complete until tests pass".
- `skills/woostack-plan/SKILL.md:83-94` (§"Bite-sized tasks (TDD)") + `references/plan-template.md`
  — TDD as plan **steps** (write failing test → confirm fail → minimal impl → confirm pass →
  commit), plus the no-runner→concrete-verification rule.
- `skills/woostack-execute/references/inline-driver.md:10-17`, `prompts/implementer.md:23-27`,
  `references/subagent-driver.md:37` — TDD as the **implement loop** (red → green → refactor;
  no-runner substitution).
- `skills/woostack-debug/SKILL.md:77-81` (Phase 4) — **failing-test-first** before a fix, with
  the same no-runner substitution.
- `skills/woostack-build/SKILL.md:105` — TDD by reference only.

The kernel ("Red→Green→Refactor; test-first; cover happy/error/edge/success+failure;
characterization for existing code; framework-aware; no-runner→concrete verification") is the
same in every site, re-typed each time. There is no single source the others link.

There is also a **capability gap**: every existing TDD touchpoint writes tests for code the
loop is *currently authoring*. Nothing offers an on-demand "add the appropriate tests to *this*
existing code / PR / spec / plan" entry point — the common brownfield need (untested existing
code, a PR that shipped thin tests, a spec whose acceptance criteria are weak, a plan whose
tasks lack concrete failing-test steps). Today that work has no skill.

## 2. Goal

Create a new **public** skill `woostack-tdd` that serves two coupled roles:

1. **Canonical TDD doctrine home.** The kernel lives once in `woostack-tdd/SKILL.md`; the five
   consumer sites keep only their **context-specific application** and **link** the kernel
   instead of restating it — mirroring how `conventions.md` and `memory.md` are single sources
   linked everywhere.
2. **`/woostack-tdd <target>` command** that **adds appropriate tests** to a **code block / PR /
   spec / plan**. One verb, target-specific output; framework-aware; in a no-runner target the
   "test" is a concrete verification command. It writes tests/edits to the **working tree**,
   hands off to `woostack-commit`, and **never commits or merges**.

After this change, the kernel is stated once and reused by link; and a user with existing
untested code (or a thin PR / weak spec / under-specified plan) has a single command that adds
the right tests.

## 3. Non-goals

- **No runtime delegation.** `woostack-execute` (implementer) and `woostack-debug` (Phase 4)
  keep writing tests **inline** in their own control flow. They link the kernel for the "how";
  they do **not** invoke `woostack-tdd` as a sub-step. No skill hop inside hot loops.
- **No new approval gate in the build loop.** The build chain's three hard gates are untouched.
  `woostack-tdd` is **gate-light** — like `woostack-execute`/`woostack-harden`, it owns no
  approval gate (it shows the diff for spec/plan edits but does not block).
- **Never commits or merges.** Writes to the working tree; hands to `woostack-commit`.
- **Authors no `status:`/`branch:` transitions.** Spec/plan edits are **content-only**; the
  `spec : plan : PRs = 1 : 1 : N` invariant and the build loop's ownership of phase transitions
  are untouched.
- **No new test harness, CI, or package script** for this repo (AGENTS.md: "no hidden tools").
- **No automatic backfill of existing specs/plans.** The command enriches a spec/plan **only
  when explicitly pointed at one**; it does not sweep `.woostack/` retro-fitting §7 or task
  steps.
- **No coverage-percentage tooling.** It adds *appropriate* tests by behavior class, not a
  numeric coverage gate or threshold.
- **No template reshaping.** It uses the **existing** spec §7 Acceptance-criteria scaffold and
  the existing plan-task step shape; it does not redesign either template.

## 4. Approach

Two halves, both pure skill-asset edits.

**Half A — extract the kernel (de-dup).** `woostack-tdd/SKILL.md` carries the canonical TDD
kernel as a named section. Each of the five consumer sites is edited to **keep its
context-specific delta and link the kernel** rather than restate it:

- `patterns.md §7` keeps the generated **project's** framework table + "not complete until
  tests pass" standard; the Red→Green→Refactor/coverage-class prose links the kernel.
- `woostack-plan` keeps the **plan-step** decomposition (one action per step, checkbox syntax);
  the red→green rationale links the kernel.
- `woostack-execute` (`inline-driver.md`, `implementer.md`, `subagent-driver.md`) keeps the
  **implement-loop** wording; the red→green→refactor definition links the kernel.
- `woostack-debug` Phase 4 keeps **failing-test-first-before-a-fix**; the TDD definition links
  the kernel (it already half-links execute).
- `woostack-build:105` keeps the by-reference mention, now pointing at the kernel.

The test: the kernel sentences appear **once** (in `woostack-tdd`) and are **removed** from the
consumers, which each gain a link.

**Half B — the command.** `/woostack-tdd <target>` **auto-detects the target by argument
shape** and applies one verb — "add appropriate tests" — with target-specific output:

| Target | Detected by | Output |
|---|---|---|
| code block | a source path or pasted code | colocated `*.test.ts(x)`; **characterization** tests for existing code |
| PR | a PR number / URL | tests covering the **diff surface** only |
| spec | a path under `.woostack/specs/` | strengthen the testable **§7 Acceptance criteria** in place |
| plan | a path under `.woostack/plans/` | fill each task's **failing-test-first step** with exact expected output |
| (none) | no argument | **ask** what to test — never guess (mirrors `woostack-debug`) |

**Test-first vs existing code (the kernel's central carve-out).** The kernel states test-first
(red-first) as **the** discipline for code the loop is *authoring* (execute/debug/plan). But the
command's headline job is adding tests to code that *already exists* — you cannot write the test
"first". So the kernel sanctions **one** departure: for existing code (the code/PR targets), the
command writes **characterization tests** that pin current behavior, explicitly named as the
brownfield carve-out from literal red-first. New-code TDD stays red-first; existing-code
test-adding is characterization. (Force-a-red — mutate code → watch fail → restore → watch pass —
is **not** required; rejected as over-ceremony in harden.)

Framework-aware: detect the runner (Vitest / Jest-expo / Playwright per `patterns.md §7`); in a
**no-runner** target (e.g. this skills repo) the "failing test" becomes a **concrete
verification command** (grep / `bash -n` / link check) with exact expected output — never a
vague "verify it works". PR diff read via `gh pr diff <n>` (read-only inspection, per AGENTS.md;
`git diff <base>...HEAD` for a local branch). Boundaries: write to the working tree, hand to
`woostack-commit`, never commit/merge, leave `status:`/`branch:` alone, show the diff for
spec/plan edits.

**Memory** (light): recall testing `gotcha`/`pattern` notes for the target's working set at
start; reject-by-default distill of **at most one** durable testing `pattern` at end. Schema and
procedure are defined once in [memory.md](../../skills/woostack-init/references/memory.md) —
link, never restate.

## 5. Components & data flow

**New file:**

1. **`skills/woostack-tdd/SKILL.md`** — the skill. Sections: dense single-paragraph
   `description` frontmatter; H1 lead (role: doctrine home + on-demand add-tests command, public
   command #14, never commits/merges); a named **kernel** section (the canonical TDD doctrine
   the consumers link); a **command** section with the target-router table + framework/no-runner
   rule + no-arg→ask; a **boundaries** paragraph; a **memory** section (link memory.md); a
   `## Hard constraints` list. House style: two-field frontmatter, named fenced block for any
   load-bearing rule, cross-links relative.

**Edited (de-dup, Half A):**

2. `skills/woostack-bootstrap/references/patterns.md` (§7) — keep project framework/coverage
   standard; link kernel for Red→Green→Refactor.
3. `skills/woostack-plan/SKILL.md` (§"Bite-sized tasks (TDD)") — keep plan-step shape; link
   kernel. `references/plan-template.md` is the **literal task scaffold** (mechanics, not
   doctrine prose) → no kernel removal; the kernel link lives in the SKILL.md prose, not the
   template.
4. `skills/woostack-execute/references/inline-driver.md:12-17` + `prompts/implementer.md:23-27`
   — both restate the full red→green→refactor kernel; keep the impl-loop framing, remove the
   restated kernel, link it. `references/subagent-driver.md:36` only says "follows TDD"
   (terse, no restatement) → **left untouched**.
5. `skills/woostack-debug/SKILL.md` (Phase 4) — keep failing-test-first; relink the TDD
   reference to the kernel.
6. `skills/woostack-build/SKILL.md:105` — repoint the by-reference TDD mention at the kernel.

**Edited (public-surface wiring, Half B):**

7. `skills/using-woostack/SKILL.md` — add a Command-Routing row for `/woostack-tdd <target>`.
8. `AGENTS.md` (= `.claude/CLAUDE.md` symlink) — add `woostack-tdd` to the public command
   surface list; bump the count language (**thirteen→fourteen** public skills, **fifteen→sixteen**
   `SKILL.md` files); add a Quick-file-map entry.

No runtime data structure; the "data" is markdown/test files the command writes and the doctrine
links propagating at authoring time.

## 6. Error handling

Authoring- and command-time failures (no runtime service):

- **Ambiguous target.** If the argument doesn't clearly resolve to code/PR/spec/plan, **ask** —
  never guess (mirrors `woostack-debug`'s no-target behavior).
- **No test runner present.** Fall back to a concrete verification command with exact expected
  output; never emit a vague "verify it works".
- **Editing an in-flight spec/plan.** Enriching a spec's §7 or a plan's tasks while that artifact
  is mid-build-loop can drift from its existing plan/PRs. The command edits **content only**,
  **must not** author `status:`/`branch:`, and **surfaces** that the plan may need
  re-derivation — it does not silently mutate phase state or the 1:1:N join.
- **Over-removal during de-dup.** Stripping the kernel from a consumer must remove **only** the
  restated kernel sentences, never the site's context-specific delta (plan-step shape, impl-loop
  wording, failing-test-first rule, project framework table). Each consumer must still read
  coherently and gain exactly one kernel link.
- **Broken cross-link.** Every new kernel link must resolve (relative path + section anchor);
  a dangling link is a defect caught by the link check.
- **Doc-count drift.** AGENTS.md count strings ("thirteen", "fifteen"), the surface list, the
  routing row, and the file map must update **together** and stay mutually consistent.
- **Clobbering existing tests.** Characterization on existing code must **augment**, detecting
  and not duplicating or overwriting tests already present.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. Fill every class or mark N/A + why.

- **AC1 — `woostack-tdd/SKILL.md` exists as the canonical doctrine home**
  - happy: `skills/woostack-tdd/SKILL.md` exists with two-field frontmatter (`name: woostack-tdd`,
    a dense `description`), an H1 lead naming it the doctrine home + add-tests command + public
    command #14 that never commits/merges, and a named **kernel** section stating
    Red→Green→Refactor, test-first, the coverage classes (happy/error/edge/success+failure),
    characterization for existing code, framework-awareness, and no-runner→concrete-verification.
  - error: N/A — a static skill file has no runtime error path; malformed authoring is caught by
    AC4 (de-dup consistency) and the link checks, not by the file itself.
  - edge: The kernel is stated **once** here; consumers link this section, so the doctrine has a
    single anchor to point at.

- **AC2 — `/woostack-tdd <target>` adds target-appropriate tests across all four targets**
  - happy: The command section documents the target router — code→colocated `*.test` files
    (characterization for existing code), PR→tests for the diff surface (`gh pr diff`),
    spec→strengthen §7 ACs in place, plan→fill each task's failing-test-first step — plus
    framework detection (Vitest/Jest-expo/Playwright), the no-runner→concrete-verification
    fallback, and the **characterization carve-out** (existing code pins current behavior; only
    new code is red-first).
  - error: A target argument that doesn't resolve to one of the four types makes the command
    **ask**, not guess; a missing test runner triggers the concrete-verification fallback, never
    a vague "verify it works".
  - edge: `/woostack-tdd` with **no argument** asks what to test (mirrors `woostack-debug`'s
    no-target behavior) rather than defaulting to any target.

- **AC3 — Boundaries are enforced**
  - happy: `## Hard constraints` state: writes to the working tree and hands to `woostack-commit`;
    **never commits or merges**; **gate-light** (owns no approval gate, shows the diff for
    spec/plan edits); authors **no** `status:`/`branch:` transitions; leaves the
    `spec : plan : PRs = 1 : 1 : N` invariant untouched.
  - error: Spec/plan enrichment that would author `status:`/`branch:` or fork a second plan is a
    constraint violation the skill text forbids; an in-flight-artifact edit surfaces the
    re-derivation warning instead of mutating phase state.
  - edge: No runtime delegation — execute/debug/plan are **not** invoked by or invoking this
    skill at runtime (verified by AC4: they only gain a doctrine link).

- **AC4 — Kernel is extracted, not duplicated**
  - happy: Each of the five consumer sites (`patterns.md §7`, `woostack-plan`,
    `woostack-execute` driver/implementer, `woostack-debug` Phase 4, `woostack-build:105`) gains
    a link to the `woostack-tdd` kernel **and** has its restated kernel sentences removed, while
    keeping its context-specific delta and reading coherently.
  - error: A consumer that still restates the kernel **and** adds the link (duplication), or that
    lost its context-specific delta during removal, is a de-dup defect a grep/read check flags.
  - edge: De-dup depth varies by reader. Main-agent-read sites (`patterns.md`, `woostack-plan`,
    `inline-driver.md`, `woostack-debug`, `woostack-build`) fully de-dup (link + phrase removed).
    `implementer.md` is a **context-free subagent prompt** → keeps its inline rule and only
    **adds** the canonical pointer (link-present, not phrase-absent). `subagent-driver.md`
    ("follows TDD") and `plan-template.md` (literal scaffold) are untouched.

- **AC5 — Public surface is wired consistently**
  - happy: `using-woostack/SKILL.md` has a Command-Routing row for `/woostack-tdd <target>`;
    AGENTS.md lists `woostack-tdd` in the public command surface, bumps the counts
    (thirteen→fourteen public, fifteen→sixteen `SKILL.md`), and adds a Quick-file-map entry.
  - error: A surface update that changes one count but not the other, or adds the routing row
    without the surface-list entry (or vice-versa), is an inconsistency the doc-count checks
    flag.
  - edge: The `SKILL.md`-count change accounts for **one** new public skill (no new internal
    sub-skill), so internal-sub-skill language (`woostack-ideate`/`woostack-harden`) is
    unchanged.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

This repo is a skills collection with **no test runner** (AGENTS.md: "no application source
code, app lockfile, build, or CI"). Per woostack convention (`woostack-plan/SKILL.md:91-93`),
each "failing test" is a concrete **verification command** with exact expected output. Planned
verifications:

- `grep`/structural assertions that `skills/woostack-tdd/SKILL.md` exists with the frontmatter,
  the named kernel section (Red→Green→Refactor, the coverage classes, no-runner rule), the
  target-router table, and the hard-constraints block.
- `grep` that **each** consumer site links the `woostack-tdd` kernel **and** no longer restates
  the kernel sentences (presence of link + absence of the duplicated phrase), while its
  context-specific delta remains.
- `grep` that `using-woostack/SKILL.md` carries the `/woostack-tdd` routing row, and that
  AGENTS.md contains `woostack-tdd` in the surface list, the updated count strings, and the file-
  map entry.
- A link/anchor check that every new kernel cross-link resolves (relative path + section anchor).

No automated harness, fixtures, or CI are added (forbidden by AGENTS.md "no hidden tools").

## 9. Open questions

_(Settled in ideate, in resolution order:)_

- **Extract scope** (ideate) — full extract + de-dup: `woostack-tdd` is the canonical kernel;
  the five consumers link it and keep only their delta.
- **Spec/plan target semantics** (ideate) — enrich each artifact's test-shaped section in place
  (spec §7 ACs; plan failing-test steps), one verb across all four targets.
- **Runtime coupling** (ideate) — link doctrine only; no runtime skill hop in execute/debug hot
  loops.
- **Public vs internal** (lgtm) — public command #14: routing row + AGENTS.md surface/counts/file-
  map.
- **Gate posture** (lgtm) — gate-light (no build-loop gate); show the diff for spec/plan edits.
- **Memory weight** (lgtm) — light: recall testing gotchas/conventions; ≤1 reject-by-default
  testing `pattern` distilled.

_(Settled in harden, in resolution order:)_

- **Kernel location** (harden) — inline named section in `woostack-tdd/SKILL.md`; the skill
  *is* the doctrine. Consumers link the **file** (`../woostack-tdd/SKILL.md`), matching the
  repo's file-level link style (`inline-driver.md:3`) — **no** fragile in-file `#anchor`.
- **De-dup precision** (harden) — `inline-driver.md:12-17` and `implementer.md:23-27` restate
  the kernel (edit); `subagent-driver.md:36` ("follows TDD") and `plan-template.md` (literal
  task scaffold) do **not** → left untouched.
- **Test-first vs existing code** (harden) — characterization carve-out: new code is red-first;
  existing code (code/PR targets) gets characterization tests pinning current behavior. Force-a-red
  rejected as over-ceremony.
- **PR-diff mechanics** (harden) — `gh pr diff <n>` (read-only inspection, AGENTS.md-sanctioned);
  `git diff <base>...HEAD` for a local branch. No Graphite needed (read-only).
- **No flags** (harden) — auto-detect target by arg shape + ask on ambiguity; no `--type` flag,
  keeping the command surface minimal (house style for simple commands).
- **In-flight-edit threshold** (harden) — when a spec/plan target's `status:` is ≥ `planning` (a
  plan already exists), the content edit surfaces a "plan may need re-derivation" warning; it
  still never authors `status:`/`branch:`.
- **Prompt self-containment** (plan harden) — `implementer.md` (a context-free subagent prompt)
  keeps its inline TDD rule and only adds the canonical pointer; it is **not** stripped to a bare
  link, since a fresh subagent must not depend on following one. Full de-dup applies to the five
  main-agent-read sites only.
