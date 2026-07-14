---
name: harden-premise-lens
type: spec
status: approved
date: 2026-07-14
branch: feature/harden-premise-lens
links:
---

# Harden premise lens — validate the problem before the solution — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-14-harden-premise-lens]]

## 1. Problem

`woostack-harden`'s angle pre-flight interrogates the **solution** and never the **premise**. Every lens entry in
[`angle-preflight.md`](../../skills/woostack-harden/references/angle-preflight.md) — the whole `## Spec lens`
(security, observability, bugs, tests, api, database, i18n, deps, infra) and the whole `## Plan lens`
(architecture, tests, types, security, observability, api/database, deps) — asks "is the design sound?" Not one
asks "is the problem real?" So harden can stamp an artifact `hardened` while its §1 root cause / problem is an
**unproven inference about current behavior**. The premise rides through as a fixed assumption; only the solution
gets grilled.

> **Premise / evidence (this spec).** The premise here is a *derived claim about current behavior* — "the
> pre-flight has no premise lens" — so it must be **demonstrated**, not asserted:
>
> - **Structural evidence (baseline read).** `angle-preflight.md` was read in full. Its lenses are
>   `## Spec lens` (`angle-preflight.md:25-38`) and `## Plan lens` (`angle-preflight.md:40-49`); every entry
>   translates a `woostack-review` *code* angle into an authoring check. There is no premise/evidence entry in
>   either lens, and the `## Skip rule (YAGNI)` (`angle-preflight.md:19-23`) would let any premise question be
>   skipped as "not implicated" even if one existed.
> - **Cost evidence (a real failure).** Fix `#511`→PR `#512` (`feat: flag regression-blind (fixture-neutral)
>   assertions in the tests review angle`) was authored, hardened, committed, and opened as a PR — then
>   **self-closed as won't-fix** once its premise was finally measured at *execution* and found false (the
>   `tests` rubric already caught the case at a capable model tier). The fix-plan harden pass at
>   `woostack-fix` step 3 grilled §2/§3 (bullet placement, severity, over-flag risk) and waved §1 (root cause)
>   straight through, because the checklist told it to interrogate the design and said nothing about the
>   premise. Harden did its job correctly against an incomplete checklist. The wasted branch + commit + PR is
>   the measured cost of the missing lens.

## 2. Goal

Add a **non-skippable premise lens** to harden's angle pre-flight so premise validation happens at the earliest
artifact — spec-harden (`woostack-build` step 3) and fix-plan harden (`woostack-fix` step 3) — before any plan or
code effort. Harden **surfaces and records** whether the premise holds, using its existing "explore the codebase
to answer before asking the user" disposition to *measure the baseline itself* rather than accept assertion. The
**kill decision stays at the caller's existing approve gate** — harden adds no gate. A disproven premise is
rejected one full phase earlier than execution (as with `#512`, before the branch/commit/PR ever exist), at
essentially zero cost.

## 3. Non-goals

- **No priority / ROI / "worth building vs. other work" judgment.** That has no artifact anchor, is not
  codebase-answerable, and would turn harden's interview into speculation — it violates harden's
  explore-to-answer disposition. It stays a human call at the caller's gate, informed by `woostack-ideate`. The
  lens validates *premise* (is the problem real?), not *value* (is it the best use of effort?).
- **No new gate in harden.** Harden keeps "hand back at no-new-questions; own no gate" (`woostack-harden`
  SKILL.md:72). It records the evidence or the disproof into §1 and hands back; the caller's existing
  approve-to-execute gate decides the kill. This preserves `woostack-build`'s "inherit gates, add none."
- **Not a `woostack-review` angle.** The premise lens is **authoring-only**. It is *not* added to
  `VALID_ANGLES` in [`load-config.sh`](../../skills/woostack-review/scripts/load-config.sh) and gets no rubric
  under `woostack-review/prompts/angles/`. A premise is not reviewable from a diff (review sees code, not the
  claim that motivated it), so unlike the other pre-flight entries this lens does **not** translate a review
  angle forward — it is a new authoring precondition. `angle-preflight.md`'s "Canonical angles — link, do not
  restate" note stays accurate: it still covers only the review-derived lenses.
- **No new machinery.** Reuse the existing pre-flight checklist + harden's explore-to-answer rule. No new
  script, config key, or status enum value.
- **No over-demanding ceremony on self-evident premises.** A visible bug or an explicit user request is
  satisfied by pointing at the repro/request; only a *derived* premise about current behavior must be
  demonstrated (see §4).

## 4. Approach

Four surgical, cross-linked edits. No duplication — the rule is stated once in the pre-flight and referenced
elsewhere.

### 4.1 Premise lens in the pre-flight (`skills/woostack-harden/references/angle-preflight.md`)

Add a new section, positioned **before** `## Skip rule (YAGNI)` (so the never-skip lens leads the file and the
skip rule visibly scopes only to the lenses below it), and amend the Skip rule to carve it out:

- New `## Premise lens — is the problem real? (never skips)` section. Content:
  - State the problem and the evidence it is real. If the premise is an **inference about current behavior**
    ("the tool fails to X", "the rubric misses Y"), **demonstrate it** — a reproduction (bug) or a baseline
    showing the deficiency (enhancement). **Reject assertion-as-evidence.** Lands in §1 Problem (spec) / §1
    Root Cause (fix).
  - **Evidence bar scales with the claim.** A self-evident premise (a visible bug, an explicit user request)
    is satisfied by pointing at the repro/request — no ceremony. Only a derived premise about current behavior
    must be demonstrated.
  - **Harden records, the gate decides.** Harden amends §1 with the evidence *or the disproof* and hands back;
    a disproven premise is killed at the caller's approve gate, not by harden.
  - **Premise ≠ priority.** This lens validates that the problem exists, not that it is worth solving vs. other
    work (that is out of scope — see the caller's gate).
- Amend `## Skip rule (YAGNI)` (`angle-preflight.md:19-23`) so it scopes YAGNI to **the lenses below it** (the
  code-derived Spec/Plan lenses), with an explicit exemption: **the premise lens never skips** — every change
  rests on a premise.

### 4.2 Spec template evidence field (`skills/woostack-build/references/spec-template.md`)

Under `## 1. Problem`, add an authoring-guidance blockquote mirroring the existing §7 pre-flight callout
pattern (`spec-template.md:46`):

> **Premise / evidence.** State the evidence the problem is real. A derived claim about current behavior must be
> *demonstrated* (a baseline/repro), not asserted — harden's premise lens will not stamp this spec `hardened`
> otherwise. A self-evident premise (visible bug, explicit request) just cites the repro/request.

This is `.md`-only authoring guidance consumed at write time — like the §7 callout, it does not appear in a
filled spec. The `spec-template.html` mirror renders content via the `{{PROBLEM}}` placeholder
(`spec-template.html:26`) and is **unaffected**; md/html structural parity holds with **no HTML edit**.

### 4.3 Fix template evidence field (`skills/woostack-fix/SKILL.md`, embedded §1 Root Cause block)

Extend the §1 Root Cause guidance in the embedded fix-file template (`woostack-fix/SKILL.md:130-131`) so it
covers **enhancements**, not just bug root causes:

> `## 1. Root Cause` guidance becomes: *Summarize the findings from woostack-debug. Where does the bad value
> originate? What is the evidence?* **For an enhancement (no bad value to trace), demonstrate the current
> behavior is genuinely deficient — a baseline, not an assertion. Harden's premise lens gates this.**

The fix file is the combined spec+plan; harden runs on it at `woostack-fix` step 3, so the premise lens fires
against this §1 exactly as it does against a spec's §1.

### 4.4 Harden SKILL edits — two locations (`skills/woostack-harden/SKILL.md`)

Harden's SKILL describes the pre-flight in **two** places; both must acknowledge the never-skip premise lens or
the SKILL contradicts itself.

1. **Narrative bullet (`woostack-harden/SKILL.md:27-30`).** It currently says "its skip rule keeps untouched
   angles silent." Amend it so the premise lens is the stated exception — it always fires, even when no
   code-angle is implicated.
2. **Hard constraint (`## Hard constraints`, adjacent to the "Angle pre-flight (spec/plan)" line at
   `woostack-harden/SKILL.md:69-71`).** Add one bullet:

> **Premise before solution (never skips).** Before declaring a spec, plan, or fix `hardened`, walk the premise
> lens first (`references/angle-preflight.md`). For a *derived* premise about current behavior, run the
> baseline/repro yourself (per "explore the codebase to answer before asking") — do not accept assertion. Amend
> §1 with the evidence or the disproof. This adds no gate: a disproven premise is killed at the caller's
> approve gate.

### 4.5 Where it runs (no code, documentation of flow)

- `woostack-build` step 3 (spec harden) — earliest artifact, before plan/code.
- `woostack-build` step 6 (plan harden) — premise already settled at step 3; re-confirmed present in §1.
- `woostack-fix` step 3 (fix-plan harden) — the fix file's §1 Root Cause.
- `woostack-plan`'s self-review already reads the pre-flight (`angle-preflight.md:6`), so it inherits the lens
  with no extra wiring.
- **`plan-template.md` intentionally untouched.** The premise is validated once — at the spec (build) or in the
  combined fix file (fix). The plan decomposes an already-premise-validated spec, so its template gains no
  evidence field; plan harden only re-confirms §1 still carries the evidence.

## 5. Components & data flow

```
author writes §1 (problem/root-cause + evidence blockquote from template)
        │
        ▼
woostack-harden  ── premise lens (never skips) ──► derived premise?
        │                                              │ yes
        │ self-evident (cite repro/request)            ▼
        │                                    explore-to-answer: run baseline/repro
        ▼                                              │
   amend §1 with evidence ◄──────────── holds ─────────┤
        │                                              │ disproven
        │                                              ▼
        │                                   amend §1 with the disproof
        ▼                                              │
  hand back "no new questions" ◄────────────────────────┘
        │
        ▼
  caller's approve-to-execute GATE  ──► kill (disproven) | proceed (holds)
```

- **Input:** §1 of a spec / fix file (problem or root cause + the template's evidence blockquote).
- **Owner:** `woostack-harden` (spec-harden, plan-harden, fix-plan harden) + `woostack-plan` self-review.
- **Output:** §1 amended in place with proof or disproof. No new file, no gate, no status value.

## 6. Error handling

- **Assertion-as-evidence on a derived premise** → harden raises a premise question, runs the baseline itself,
  and blocks `hardened` until §1 carries real evidence. (This is the `#511` case.)
- **Premise disproven by the baseline** → harden amends §1 with the disproof and hands back; it does **not**
  self-kill. The caller's gate rejects it. (Preserves "own no gate".)
- **Self-evident premise over-demanded** → guarded by the evidence-scales-with-claim rule: a visible bug or
  explicit request cites the repro/request and passes without a manufactured baseline. Prevents the lens from
  becoming ceremony on obvious work.
- **Priority creep** ("is this worth it vs. other work") → out of scope by §3; harden does not ask it. Keeps the
  interview artifact-grounded.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

> **Angle pre-flight.** Spec lens walked: no data layer, api surface, or UI copy — `database`, `api`, `i18n`
> skip (YAGNI). `security`/`observability` N/A (prose-only skill edits). `tests` → §8. **premise lens: proven
> in §1** (structural read + `#512` cost). Implicated: `bugs`/edge (below), `deps`/`infra` N/A.

- **AC1 — Non-skippable premise lens exists in the pre-flight.**
  - happy: `angle-preflight.md` contains a `## Premise lens` section, placed before `## Skip rule (YAGNI)`, stating the
    evidence-scales-with-claim rule and the record-not-kill boundary.
  - edge: the `## Skip rule (YAGNI)` section explicitly exempts the premise lens ("never skips").
  - error: no code-angle entry is removed or reordered; the Spec/Plan lens lists are byte-unchanged except the
    new section above them.
- **AC2 — Templates demand premise evidence.**
  - happy: `spec-template.md` §1 carries a "Premise / evidence" authoring blockquote; `woostack-fix/SKILL.md`
    §1 Root Cause guidance demands a baseline for an enhancement.
  - edge: `spec-template.html` is **unchanged** and still mirrors `spec-template.md`'s section structure (the
    §1 guidance is write-time-only, rendered via `{{PROBLEM}}`).
- **AC3 — Harden enforces premise-before-solution.**
  - happy: `woostack-harden/SKILL.md` gains a premise-lens hard-constraint bullet requiring evidence (not
    assertion) for a derived premise before `hardened`, **and** the narrative pre-flight bullet (SKILL.md:27-30)
    names the premise lens as the never-skip exception.
  - behavior: on a spec whose §1 is a bare derived assertion, harden raises a premise question and runs the
    baseline itself before proceeding (dogfood check, §8).
  - edge: the bullet states harden records evidence/disproof and adds **no** gate.
- **AC4 — Scope guards hold.**
  - happy: priority/ROI is named out of scope (spec §3 + no harden question asks it).
  - edge: the premise lens is **not** added to `VALID_ANGLES` in `load-config.sh` and gets no
    `prompts/angles/` rubric; the pre-flight's "Canonical angles — link, do not restate" note stays accurate.
  - error: every new cross-link resolves (no dangling relative paths); no fact is duplicated across the four
    edited files (single source in the pre-flight, referenced elsewhere).

## 8. Testing

> Strategy only — per-behavior cases live in §7.

- **Mechanical (grep/read, deterministic).** AC1–AC4 content assertions: the premise-lens section + skip-rule
  carve-out are present; the two templates carry the evidence field; `spec-template.html` is unchanged; the
  harden hard-constraint bullet is present; `load-config.sh` `VALID_ANGLES` is unchanged. Cross-link resolution
  and no-duplication verified by read.
- **Behavioral dogfood (no runtime LLM in CI — same carve-out `#512` used).** Run `woostack-harden` against a
  throwaway spec whose §1 is a bare derived assertion ("skill X misses Y") with no baseline; confirm harden
  raises the premise question and runs the measurement itself rather than stamping `hardened`. This is
  corroborating evidence, not a CI gate.
- **Docs-site sync (CLAUDE.md constraint).** Verify no authored `site/content/docs/` page restates the
  pre-flight lens list or harden's constraint set; the per-skill reference page regenerates from
  `woostack-harden/SKILL.md` at build. Run `pnpm -C site build` to confirm the site still builds. No authored
  page is expected to change (no skill-count, gate, or getting-started change — harden adds no gate).

## 9. Open questions

None. The four edits, their placement, the scope boundary (premise not priority; record not kill; authoring not
review), and the md/html-mirror no-op were all resolved during ideate/harden and are grounded in the files above.
This spec's own premise is demonstrated in §1, so it survives its own premise lens.
