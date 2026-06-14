---
name: spec-acceptance-criteria
type: spec
status: approved
date: 2026-06-06
branch: spec-acceptance-criteria
links:
---

# Structured Acceptance Criteria in the spec template — Design Spec

> **Plan:** [[plans/2026-06-06-spec-acceptance-criteria]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

woostack's TDD machinery guarantees test **cadence** but not test **breadth**. Each plan task
runs a real failing test through red→green (`inline-driver.md:12-17`, `implementer.md:24-28`,
`plan-template.md:24-44`), and plan self-review asserts "every requirement maps to a task"
(`woostack-plan/SKILL.md:131`). But nothing requires that a requirement's tests span the
**happy path, error path(s), and edge cases**. A task whose single assertion is a happy-path
check passes every existing gate.

The breadth gap originates at the **spec**, not at execute. The spec template
([`spec-template.md`](../../skills/woostack-build/references/spec-template.md)) has eight
sections; the only test-relevant ones — §6 Error handling and §7 Testing — are freeform
`{{...}}` placeholders with no structure forcing per-behavior enumeration. There is no discrete,
testable acceptance-criteria list for the plan to map 1:1 into tasks and tests. So whether
error/edge cases get tested depends entirely on author diligence, enforced nowhere.

`woostack-plan/SKILL.md:104` actively bans the vague phrase *"handle edge cases"* as a
placeholder — anti-vagueness, but it also offers no structured slot where edge cases *should*
be enumerated, so authors have nowhere to put them.

## 2. Goal

Add a structured **Acceptance Criteria** section to the spec template that enumerates testable
behaviors, each carrying explicit happy / error / edge slots, and tighten plan self-review so
that breadth flows mechanically into TDD tasks. After this change, a spec that lists a
behavior's error and edge cases will have them carried — by the existing "every requirement →
task → real failing test" plumbing — down into the executed test suite, with no change to how
execute runs.

## 3. Non-goals

- **No change to TDD execution mechanics.** The drivers (`inline-driver.md`,
  `subagent-driver.md`, `implementer.md`) and the per-task red→green cycle are untouched.
  Execute runs whatever tests the plan names; it cannot know a feature's edge cases.
- **No enforcement gate inside execute.** Breadth is a spec property; it is gated at plan, not
  at execute.
- **No new approval gate** in the build loop. The change is to artifacts and self-review
  checklists only.
- **No execution-receipt / proof-of-red mechanism.** Verifying that a red test was actually
  observed (cf. `woostack-review`'s `verify-receipts.sh`) is a separate concern, out of scope
  here.
- **No change to `woostack-harden`.** Harden stays a generic interview engine (see §4).
- **No change to the plan task shape.** A behavior's three cases may share one task or span
  several — planner judgment, not a mechanical rule.
- **No backfill of existing specs.** The change is forward-only: the 10 specs already in
  `.woostack/specs/` keep their 8-section shape (their plans already exist, so retro-fitting §7
  buys no test breadth). Only specs authored after this change carry §7.
- **No template-substitution engine.** `spec-template.html`'s `{{...}}` tokens are illustrative
  cues, not wired placeholders — `woostack-visualize` *composes bespoke HTML* and treats the
  template as a starting point only (`woostack-visualize/SKILL.md:32-38`). This change adds no
  rendering/substitution machinery.

## 4. Approach

Fix breadth at the layer that owns it (the spec), gate it at the layer that derives tasks from
the spec (the plan), and leave the runner (execute) and the generic interviewer (harden)
alone.

- **Spec template** gains a dedicated, structured Acceptance Criteria section so behaviors are
  enumerated as testable units with happy/error/edge slots. The markdown ships a **literal
  scaffold** (instruction line + an example AC skeleton with `{{token}}` fills), not a bare
  `{{ACCEPTANCE_CRITERIA}}` token — making the happy/error/edge structure visible to the author
  is the feature. This matches `plan-template.md`'s scaffold style and deliberately diverges
  from the sibling sections' bare-token style. The HTML mirror keeps a bare
  `{{ACCEPTANCE_CRITERIA}}` panel, consistent with the other illustrative HTML panels.
- **Coverage is opt-out, not mandatory.** A spec may mark §7 **whole-section N/A** when it has
  no testable behavior (docs-only, pure refactor) — written as `N/A — <why no testable
  behavior>`. When §7 carries real ACs, each filled (non-N/A) case must map to a test.
- **Plan self-review** (the engine's checklist and the plan template's self-review block) gains
  an AC-coverage check: when §7 has ACs, every AC — and each filled case — maps to a test; when
  §7 is whole-section N/A, a one-line **sanity check** confirms the spec body genuinely has no
  behavioral requirement (else flag), so the escape hatch cannot silently swallow breadth.
- **Harden needs no edit.** It already "walks every branch of the decision tree" and grills
  open questions one at a time. A spec AC section shipped with empty happy/error/edge cells —
  or a dubious whole-section N/A — presents as open questions harden naturally surfaces:
  emergent enforcement, without bloating a deliberately-generic skill with section-specific
  rules.
- **Execute needs no edit.** Once the plan names error/edge tests, the existing red→green
  cadence runs them unchanged.

The breadth chain end to end: spec AC (happy/error/edge) → harden grills blank cells / dubious
N/A → plan self-review maps each filled case to a test (or sanity-checks a whole-section N/A) →
plan task = a real failing test → execute drives it red→green.

## 5. Components & data flow

Four files change; two skills are deliberately left untouched.

1. **`skills/woostack-build/references/spec-template.md`** — insert a new **§7 Acceptance
   criteria** after §6 Error handling as a **literal scaffold** (instruction line allowing
   per-slot N/A *and* whole-section `N/A — <why>`; an example AC skeleton with
   `happy:`/`error:`/`edge:` sub-bullets and `{{behavior}}`/`{{expected}}` tokens); renumber
   Testing → §8 and Open questions → §9; add a one-line scope note to §8 Testing.
2. **`skills/woostack-build/references/spec-template.html`** — mirror the markdown 1:1: add a
   `7. Acceptance criteria` heading + panel with a bare `{{ACCEPTANCE_CRITERIA}}` placeholder
   (illustrative, like the sibling panels — no substitution engine reads it), and renumber the
   following two sections. Heading text and numbers must match `spec-template.md` exactly.
3. **`skills/woostack-plan/SKILL.md`** — extend self-review step 1 (spec coverage) to assert AC
   → task → test mapping when §7 has ACs, **and** a whole-section-N/A sanity check (confirm the
   spec body has no behavioral requirement, else flag); add a cross-reference reconciling the §7
   AC slots with the existing `:104` ban on the vague *"handle edge cases"* phrase.
4. **`skills/woostack-plan/references/plan-template.md`** — add an **AC coverage** line to the
   self-review checklist; task/step mechanics unchanged.

Untouched on purpose: `skills/woostack-harden/SKILL.md` (emergent coverage),
`skills/woostack-execute/**` (runner), `skills/woostack-build/SKILL.md` (does not enumerate
spec sections).

Data flow (authoring time): author fills spec §7 → `woostack-harden` grills any blank cell as
an open question → `woostack-plan` reads §7 and maps each AC + filled case to a task/test →
`woostack-execute` runs those tests red→green. No runtime data structure; the "data" is the
markdown propagating through the build phases.

## 6. Error handling

This is a docs/skills change with no runtime, so "errors" are authoring and consistency
failures:

- **Markdown ↔ HTML drift.** If only one of `spec-template.md` / `spec-template.html` is
  edited, the render desynchronizes. Both must change together; section numbers and headings
  must match exactly (§7 AC, §8 Testing, §9 Open questions).
- **Inapplicable case classes.** Not every behavior has a meaningful error or edge case, and
  not every spec has testable behavior at all. The template must explicitly allow **per-slot**
  `N/A — <reason>` *and* **whole-section** `N/A — <why no testable behavior>`, so authors don't
  fabricate cases or leave ambiguous blanks. A blank (unfilled) cell is a harden prompt; an
  explicit `N/A — <why>` is a settled decision. A whole-section N/A is additionally sanity-checked
  at plan self-review (confirm no behavioral requirement exists) so it cannot hide real breadth.
- **Stale cross-references.** `woostack-plan/SKILL.md:104` and `:131` carry line-anchored
  meaning; the edits must keep those references coherent and not orphan the banned-phrase rule.
- **Over-prescription risk.** The AC section must stay lean (the repo values concision); an
  over-heavy template would push authors to skip or under-fill it. Format is the
  already-chosen per-AC bullet with three sub-slots, not a verbose BDD block.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. Fill every class or mark N/A + why.

- **AC1 — Spec template exposes a structured Acceptance Criteria scaffold**
  - happy: `spec-template.md` contains a `## 7. Acceptance criteria` section shipped as a
    literal scaffold — an instruction line plus an example AC skeleton with the per-AC bullet
    format (behavior + `happy:`/`error:`/`edge:` sub-slots, `{{token}}` fills) — not a bare
    `{{ACCEPTANCE_CRITERIA}}` token.
  - error: N/A — a static template has no runtime error path; malformed authoring is caught by
    AC2 (consistency) and by harden, not by the template itself.
  - edge: The instruction line sanctions both **per-slot** `N/A — <reason>` (a behavior with no
    meaningful error/edge case) and **whole-section** `N/A — <why no testable behavior>` (a
    docs-only or pure-refactor spec), so §7 is never left ambiguously blank.

- **AC2 — Markdown and HTML templates stay 1:1**
  - happy: `spec-template.html` renders sections `1…9` with `7. Acceptance criteria`,
    `8. Testing`, `9. Open questions`, including a bare `{{ACCEPTANCE_CRITERIA}}` panel, and
    every heading/number matches `spec-template.md`.
  - error: A numbering or heading mismatch between the two files is a defect — a structural diff
    (compare the ordered section list of each file) must show them identical.
  - edge: The `{{ACCEPTANCE_CRITERIA}}` token is illustrative only — `woostack-visualize`
    composes bespoke HTML and reads no token — so it just follows the existing `{{UPPER_SNAKE}}`
    panel convention; no substitution machinery is added or required.

- **AC3 — Plan self-review gates AC → task → test breadth**
  - happy: `woostack-plan/SKILL.md` self-review asserts every spec AC maps to a task and each
    *filled* (non-N/A) happy/error/edge case maps to a test; `plan-template.md`'s self-review
    checklist carries a matching **AC coverage** line.
  - error: An AC (or a filled case within it) with no corresponding task/test is a self-review
    failure the planner must fix before handing back — the checklist names this as a gap to
    "list and fill," consistent with the existing spec-coverage step.
  - edge: A case (or slot) marked `N/A — <reason>` is honored — no test required, not counted as
    a gap. When §7 is **whole-section N/A**, the AC-mapping check is skipped but a one-line
    sanity check confirms the spec body has no behavioral requirement (else the planner flags
    the N/A as suspect), so the escape hatch cannot silently swallow breadth.

- **AC4 — Existing plan rules stay coherent**
  - happy: The `:104` ban on the vague phrase *"handle edge cases"* remains, now cross-referenced
    to §7 as the structured place where edge cases are actually enumerated.
  - error: N/A — no behavioral path; this is a documentation-consistency criterion verified by
    reading the amended section.
  - edge: Plan task/step mechanics (one real failing test per step) are unchanged — a behavior's
    three cases may live in one task or span several, so the gate checks test *existence*, not
    task count.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

This repo is a skills collection with **no test runner** (see project AGENTS.md: "no
application source code, app lockfile, build, or CI"). Per woostack convention
(`woostack-plan/SKILL.md:91-93`), each "failing test" becomes a concrete **verification
command** with exact expected output. Planned verifications:

- `grep`/structural assertions that `spec-template.md` contains the `## 7. Acceptance criteria`
  heading, the three sub-slots, and the instruction line; and that §8/§9 are renumbered.
- A structural comparison that `spec-template.html`'s ordered section headings match
  `spec-template.md`'s, and that `{{ACCEPTANCE_CRITERIA}}` is present.
- `grep` that `woostack-plan/SKILL.md` self-review names AC→task→test mapping and that
  `plan-template.md`'s self-review checklist carries the AC-coverage line.
- A link/anchor check that the `:104` cross-reference to §7 is coherent.

No automated harness, fixtures, or CI are added (forbidden by AGENTS.md "no hidden tools").

## 9. Open questions

_(none — all resolved. Settled decisions, in resolution order:)_

- **AC format** (ideate) — per-AC bullet with `happy:`/`error:`/`edge:` sub-slots. Not a table,
  not Given/When/Then.
- **Enforcement layer** (ideate) — plan gate only; `woostack-harden` left untouched (emergent
  coverage of blank cells / dubious N/A).
- **Testing section** (ideate) — kept as §8 and scope-noted ("strategy only"), not absorbed into
  AC.
- **§7 in markdown** (harden) — literal scaffold (visible structure), diverging from sibling
  bare-token sections; HTML keeps a bare `{{ACCEPTANCE_CRITERIA}}` panel.
- **Renumbering** (harden) — safe: nothing parses spec section numbers (`/woostack-status` reads
  frontmatter; `woostack-visualize` composes bespoke HTML).
- **Backfill** (harden) — none; forward-only (see §3 Non-goals).
- **AC required?** (harden) — no; §7 may be marked whole-section N/A when a spec has no testable
  behavior. Coverage is opt-out, not mandatory.
- **N/A guard** (harden) — whole-section N/A must carry a reason; harden grills a dubious N/A;
  plan self-review sanity-checks an N/A §7 against the spec body. Three layers keep the opt-out
  from swallowing real breadth.
