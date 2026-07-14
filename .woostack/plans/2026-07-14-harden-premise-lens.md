---
type: plan
source: .woostack/specs/2026-07-14-harden-premise-lens.md
status: ready
branch: feature/harden-premise-lens
---

**Source:** [[specs/2026-07-14-harden-premise-lens]]

# Harden premise lens — validate the problem before the solution — Implementation Plan

**Goal:** Add a non-skippable "premise lens" to `woostack-harden`'s angle pre-flight — plus the matching template evidence fields and SKILL constraints — so a spec/plan/fix is proven *real* (baseline/repro, not assertion) before its solution is hardened.

**Architecture:** Five prose edits across four skill files, single-source-plus-reference: the rule lives once in `angle-preflight.md` (new `## Premise lens` section + a `## Skip rule (YAGNI)` carve-out); the spec and fix templates gain a write-time "Premise / evidence" authoring blockquote; `woostack-harden/SKILL.md` acknowledges the never-skip lens in **both** places it describes the pre-flight (narrative bullet + `## Hard constraints`). No `.html`, no `VALID_ANGLES`, no new rubric, no new gate. This is a docs-only change to a skills collection, so every "failing test" is a concrete `grep`/`bash`/build check with exact expected output (per [plan-template.md](../../skills/woostack-plan/references/plan-template.md)).

**Tech Stack:** Markdown skill files; `grep`/`bash`; Graphite (`gt`) for stacked commits; `pnpm -C site build` for the docs-site sync check.

## Increment 1: Premise lens across pre-flight, templates, and harden SKILL

> One independently shippable PR (~50 LOC of prose, well under the 500 soft target) — its own Graphite branch stacked on the spec+plan base (`feature/harden-premise-lens`, PR #516). The four edits are cross-linked and ship together: splitting them would leave the SKILL referencing a lens that does not yet exist. No deferral markers — nothing is left for a later increment.

All commands run from the repository root (the worktree root: `.woostack/worktrees/feature-harden-premise-lens`).

### Task 1: Premise lens section + Skip rule carve-out (AC1)

**Files:**
- Modify: `skills/woostack-harden/references/angle-preflight.md` (insert new section before line 19 `## Skip rule (YAGNI)`; amend the Skip rule body, lines 19-23)

- [ ] **Step 1: Write the failing test**
  Confirm the section does not exist yet and the current Skip rule wording is present (the baseline we will amend):
  ```bash
  grep -c '^## Premise lens' skills/woostack-harden/references/angle-preflight.md
  grep -n 'Do not manufacture questions' skills/woostack-harden/references/angle-preflight.md
  # Baseline code-angle count (must be identical after the edit — proves the lens bodies are untouched):
  grep -cE '^- \*\*(security|observability|bugs|tests|api|database|i18n|deps|infra|architecture|types)\*\*' skills/woostack-harden/references/angle-preflight.md
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: (the three commands above)
  Expected: first prints `0` (no premise-lens section yet); second prints the line `22:...Do not manufacture questions for` (current Skip rule body intact, our edit anchor); third prints `15` (the pre-edit code-angle baseline).

- [ ] **Step 3: Minimal implementation**
  Insert a new `## Premise lens` section **immediately before** `## Skip rule (YAGNI)` (before line 19), so the never-skip lens leads the file:
  ```markdown
  ## Premise lens — is the problem real? (never skips)

  Every change rests on a premise: that the problem is real. Walk this lens first, on every spec,
  plan, or fix — it is **never** skipped by the YAGNI rule below.

  - **State the problem and the evidence it is real.** If the premise is an *inference about current
    behavior* ("the tool fails to X", "the rubric misses Y"), **demonstrate it** — a reproduction
    (bug) or a baseline showing the deficiency (enhancement). **Reject assertion-as-evidence.** Lands
    in §1 Problem (spec) / §1 Root Cause (fix).
  - **Evidence bar scales with the claim.** A self-evident premise (a visible bug, an explicit user
    request) is satisfied by pointing at the repro/request — no ceremony. Only a *derived* premise
    about current behavior must be demonstrated.
  - **Harden records, the gate decides.** Harden amends §1 with the evidence *or the disproof* and
    hands back; a disproven premise is killed at the caller's approve gate, not by harden.
  - **Premise ≠ priority.** This lens validates that the problem *exists*, not that it is worth
    solving vs. other work (out of scope — see the caller's gate).

  ```
  Then replace the Skip rule body (current lines 21-23) so YAGNI scopes only to the lenses below and the premise lens is exempt. The `## Skip rule (YAGNI)` heading stays; its paragraph becomes:
  ```markdown
  Walk only the angles **in the lenses below** (the code-derived Spec/Plan lenses) whose surface the
  artifact actually implicates. A spec with no data layer skips `database`; a CLI-only change skips
  `api` and `i18n`. Do not manufacture questions for angles the work does not touch. **The premise
  lens above is exempt — it never skips; every change rests on a premise.**
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run:
  ```bash
  # New section present, and positioned before the Skip rule (order check):
  awk '/^## Premise lens/{p=NR} /^## Skip rule/{s=NR} /^## Spec lens/{sp=NR} END{print (p>0 && p<s && s<sp) ? "ORDER_OK" : "ORDER_BAD ("p","s","sp")"}' skills/woostack-harden/references/angle-preflight.md
  # Skip-rule carve-out present:
  grep -c 'The premise lens above is exempt' skills/woostack-harden/references/angle-preflight.md
  # Code-angle lists byte-unchanged: the single-name spec-lens + plan-lens angle bullets still present:
  grep -cE '^- \*\*(security|observability|bugs|tests|api|database|i18n|deps|infra|architecture|types)\*\*' skills/woostack-harden/references/angle-preflight.md
  ```
  Expected: `ORDER_OK`; `1`; and `15` (9 spec-lens single-name bullets + 6 plan-lens single-name bullets — the combined `- **api / database**` plan bullet is intentionally not matched by the single-name pattern; the `## Spec lens` / `## Plan lens` bodies are untouched, so this equals the pre-edit count).

- [ ] **Step 5: Commit**
  ```bash
  gt create -m "docs(harden): add non-skippable premise lens to angle pre-flight"
  ```

### Task 2: Template evidence fields — spec + fix (AC2)

**Files:**
- Modify: `skills/woostack-build/references/spec-template.md` (add authoring blockquote under `## 1. Problem`, after line 18)
- Modify: `skills/woostack-fix/SKILL.md` (extend the embedded §1 Root Cause guidance, line 131)
- Verify unchanged: `skills/woostack-build/references/spec-template.html`

- [ ] **Step 1: Write the failing test**
  ```bash
  grep -c 'Premise / evidence' skills/woostack-build/references/spec-template.md
  grep -c 'demonstrate the current behavior is genuinely deficient' skills/woostack-fix/SKILL.md
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: (both commands above)
  Expected: both print `0` — neither template carries the evidence field yet.

- [ ] **Step 3: Minimal implementation**
  In `spec-template.md`, insert this authoring blockquote between the `## 1. Problem` heading (line 18) and the `{{PROBLEM}}` placeholder (line 20), mirroring the §7 pre-flight callout pattern (blank line above and below):
  ```markdown
  > **Premise / evidence.** State the evidence the problem is real. A derived claim about current behavior must be *demonstrated* (a baseline/repro), not asserted — harden's premise lens will not stamp this spec `hardened` otherwise. A self-evident premise (visible bug, explicit request) just cites the repro/request.
  ```
  In `skills/woostack-fix/SKILL.md`, replace the §1 Root Cause guidance line inside the embedded fenced template (current line 131, 3-space indent kept) with:
  ```markdown
     *Summarize the findings from woostack-debug. Where does the bad value originate? What is the evidence?* **For an enhancement (no bad value to trace), demonstrate the current behavior is genuinely deficient — a baseline, not an assertion. Harden's premise lens gates this.**
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  ```bash
  # Both evidence fields present:
  grep -c 'Premise / evidence' skills/woostack-build/references/spec-template.md
  grep -c 'demonstrate the current behavior is genuinely deficient' skills/woostack-fix/SKILL.md
  # spec-template.html UNCHANGED (AC2 edge): no premise content, section structure intact (9 <h2>):
  grep -ci premise skills/woostack-build/references/spec-template.html
  grep -c '<h2>' skills/woostack-build/references/spec-template.html
  git status --short skills/woostack-build/references/spec-template.html
  ```
  Expected: `1`; `1`; then `0` (no premise text in the HTML); `9` (all nine section headings still present); and the `git status` line is **empty** (the `.html` file is not modified).

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(templates): demand premise evidence in spec and fix §1"
  ```

### Task 3: Harden SKILL — two-location never-skip acknowledgement (AC3)

**Files:**
- Modify: `skills/woostack-harden/SKILL.md` (narrative bullet, lines 27-30; new `## Hard constraints` bullet after line 71)

- [ ] **Step 1: Write the failing test**
  ```bash
  grep -c 'never skips' skills/woostack-harden/SKILL.md
  grep -c 'Premise before solution' skills/woostack-harden/SKILL.md
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: (both commands above)
  Expected: both print `0` — the SKILL does not yet name the never-skip premise lens in either location.

- [ ] **Step 3: Minimal implementation**
  (a) Amend the narrative **Angle pre-flight** bullet (lines 27-30) so the premise lens is the stated exception — replace the bullet with:
  ```markdown
  - **Angle pre-flight.** When hardening a spec or plan, walk the
    [spec/plan angle pre-flight](references/angle-preflight.md) and raise a question for any angle
    the artifact's surface implicates but leaves unaddressed — its skip rule keeps untouched angles
    silent, **except the premise lens, which never skips: it fires on every spec, plan, or fix, even
    when no code angle is implicated.** This makes the interview angle-driven, not only
    decision-tree-driven.
  ```
  (b) Add a new bullet to `## Hard constraints` **after** the "Angle pre-flight (spec/plan)" bullet (after line 71, before the "Own no gate" bullet):
  ```markdown
  - **Premise before solution (never skips).** Before declaring a spec, plan, or fix `hardened`, walk
    the premise lens first ([`references/angle-preflight.md`](references/angle-preflight.md)). For a
    *derived* premise about current behavior, run the baseline/repro yourself (per "explore the
    codebase to answer before asking") — do not accept assertion. Amend §1 with the evidence or the
    disproof. This adds no gate: a disproven premise is killed at the caller's approve gate.
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  ```bash
  # Both edits present:
  grep -c 'never skips' skills/woostack-harden/SKILL.md          # narrative + hard-constraint => 2
  grep -c 'Premise before solution' skills/woostack-harden/SKILL.md
  # Hard-constraint bullet sits inside ## Hard constraints, between Angle pre-flight and Own no gate:
  awk '/^- \*\*Angle pre-flight \(spec\/plan\)/{a=NR} /^- \*\*Premise before solution/{p=NR} /^- \*\*Own no gate/{o=NR} END{print (a<p && p<o) ? "PLACEMENT_OK" : "PLACEMENT_BAD ("a","p","o")"}' skills/woostack-harden/SKILL.md
  ```
  Expected: `2` (the phrase "never skips" now appears in both the narrative bullet and the hard-constraint bullet); `1`; `PLACEMENT_OK`.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(harden): name the never-skip premise lens in both SKILL pre-flight sites"
  ```

### Task 4: Scope guards, cross-link integrity, docs-site & behavioral dogfood (AC4 + §8)

> Verification-only — no file edit, so **no commit**. Pins the negative invariants (AC4) and runs the two §8 checks that are not per-edit greps.

- [ ] **Step 1: Scope guards — premise is NOT a review angle (AC4 edge)**
  Run:
  ```bash
  # VALID_ANGLES must NOT contain "premise":
  grep -n 'VALID_ANGLES' skills/woostack-review/scripts/load-config.sh | grep -c premise
  # No premise rubric was added under prompts/angles/:
  ls skills/woostack-review/prompts/angles/ | grep -c '^premise'
  # The pre-flight's "Canonical angles — link, do not restate" note is still present and accurate:
  grep -c 'Canonical angles' skills/woostack-harden/references/angle-preflight.md
  # AC4 happy: the premise lens itself carves priority/ROI OUT of scope (not a value tribunal):
  grep -c 'Premise ≠ priority' skills/woostack-harden/references/angle-preflight.md
  ```
  Expected: `0` (premise not in `VALID_ANGLES`); `0` (no rubric file); `1` (note intact); `1` (priority explicitly out of scope in the premise lens).

- [ ] **Step 2: Cross-link integrity + no-duplication (AC4 error)**
  Run:
  ```bash
  # Every relative link the new/edited content points at resolves to a real file:
  test -f skills/woostack-harden/references/angle-preflight.md && echo LINK_OK_preflight
  # Single source: the rule text lives ONLY in angle-preflight.md across the skills tree
  # (spec/plan artifacts under .woostack/ are excluded — this checks the four edited skill files):
  grep -rl 'Evidence bar scales with the claim' skills/
  grep -rl 'Harden records, the gate decides' skills/
  ```
  Expected: `LINK_OK_preflight`; and each `grep -rl` prints exactly one path — `skills/woostack-harden/references/angle-preflight.md` — confirming the templates and SKILL reference the rule (by prose/link) rather than duplicating its full text.

- [ ] **Step 3: Docs-site sync check (§8, CLAUDE.md constraint)**
  Run:
  ```bash
  # No authored docs page restates the pre-flight lens list or harden's constraint set:
  grep -rl 'premise lens' site/content/docs/ || echo "NO_AUTHORED_PAGE_MENTIONS (expected)"
  # Site still builds (per-skill reference page regenerates from SKILL.md at build; it is gitignored):
  pnpm -C site build
  # No authored docs page changed on disk:
  git status --short site/content/docs/
  ```
  Expected: `NO_AUTHORED_PAGE_MENTIONS (expected)`; `pnpm -C site build` exits `0`; the `git status` line is empty (generated per-skill pages are gitignored, authored pages untouched). If `site` deps are absent, run `pnpm -C site install` first.

- [ ] **Step 4: Behavioral dogfood (§8 — corroborating evidence, not a CI gate)**
  Construct a throwaway spec whose §1 is a *bare derived assertion* with no baseline, then walk `woostack-harden`'s premise lens against it and confirm the lens fires:
  ```bash
  cat > /tmp/premise-dogfood-spec.md <<'EOF'
  ---
  name: dogfood
  type: spec
  status: draft
  ---
  # Dogfood — Design Spec
  ## 1. Problem
  Skill X misses case Y. (No baseline, no repro — a bare derived assertion about current behavior.)
  ## 2. Goal
  Fix it.
  EOF
  ```
  Then, acting as `woostack-harden` reading `skills/woostack-harden/references/angle-preflight.md`, verify the premise lens (never skips) forces: (1) the §1 claim is a *derived* premise about current behavior with no evidence → harden **raises the premise question** and **runs the baseline itself** ("explore the codebase to answer") rather than stamping `hardened`; (2) had §1 cited a repro/request, the evidence-scales-with-claim rule would pass it without ceremony. Record the outcome in the increment review note. This mirrors the `#512` carve-out and is corroborating evidence only — remove the temp file afterward (`rm /tmp/premise-dogfood-spec.md`).

## Plan Checks

- **Spec coverage** — every §4 edit and §6 error path maps to a task: §4.1 → Task 1; §4.2/§4.3 → Task 2; §4.4 → Task 3; §4.5 (flow, no code) documented, no edit; §6 error paths are the behaviors verified by Task 3 Step 4 (placement) and Task 4 Step 4 (dogfood: assertion-as-evidence raises a question; disproven premise records, no self-kill).
- **AC coverage** — AC1 → Task 1 (section present, before Skip rule, carve-out, code-angle lists unchanged); AC2 → Task 2 (both templates carry the field; `.html` unchanged, 9 `<h2>` intact); AC3 → Task 3 (hard-constraint bullet + narrative "never skips", placement) and Task 4 Step 4 (dogfood behavior); AC4 → Task 4 Steps 1-2 (happy: priority/ROI carved out of the premise lens; edge: `VALID_ANGLES` clean, no rubric; error: cross-links resolve, no duplication).
- **No placeholders** — every step carries the exact insertion content and exact command with expected output; no TBD/TODO.
- **Type consistency** — N/A (prose skill files, no code types); heading/anchor names (`## Premise lens`, "never skips", "Premise before solution", `{{PROBLEM}}`) are used identically across tasks and verification greps.
- **Angle coverage** — plan lens walked: architecture = single-source-plus-reference (rule once in `angle-preflight.md`, referenced elsewhere), lockstep-aware (spec-template `.md`/`.html` pair pinned unchanged in Task 2; harden's two pre-flight sites moved together in Task 3 per the `autonomy-needs-structural-proof` barrier+hard-constraint law); a verification step per AC; security/observability/api/database/i18n/deps skip (prose-only, no code surface — YAGNI).
