---
type: fix
status: hardened
branch: fix/angle-preflight
---

# Fix: build-loop harden + plan self-review are not angle-aware

## 1. Root Cause

Running `woostack-review` on a spec+plan PR surfaces many issues. The build loop's spec/plan
quality mechanisms do not check the same dimensions the review does:

- `woostack-harden` (build steps 3 and 6) interviews a generic **decision tree**
  (`skills/woostack-harden/SKILL.md:16-27`) — no angle vocabulary.
- `woostack-plan` self-review runs **3 checks** — spec-coverage / placeholder / type-consistency
  (`skills/woostack-plan/SKILL.md:149-162`) — none angle-derived.
- `woostack-review`'s angles (`security`, `observability`, `architecture`, edge/error, …;
  canonical list at `skills/woostack-review/scripts/load-config.sh:92`) are **post-diff lenses**.
  On a docs-only spec+plan PR they fire late and mostly misfire (they path-gate on source files,
  per `skills/woostack-review/scripts/detect-angles.sh`).

So spec/plan gaps that an angle would catch are not caught at authoring time — they surface at
review. Evidence: §7 of the spec template (`skills/woostack-build/references/spec-template.md:42-53`)
has only a generic happy/error/edge scaffold with no angle prompts; the plan template's
`## Plan Checks` (`skills/woostack-plan/references/plan-template.md:56-62`) carries the same 4
non-angle checks.

## 2. Proposed Fix

Fold the spec/plan-relevant angles into the writing the loop **already** does — harden and plan
self-review — via **one shared rubric**, cross-linked everywhere (DRY; repo "cross-link, do not
duplicate" constraint). Adds **no new approval gate** (preserves build's "inherit two gates, add
one"). The rubric translates each review angle from "what it flags in a diff" into "what to ask
before writing," split into a **spec lens** (→ §6/§7) and a **plan lens** (→ decomposition). It
carries a YAGNI **skip rule** and does **not** restate per-angle rubric — it links the canonical
source. Scope: **rubric enrichment only** (no adversarial multi-angle sub-pass).

Note on the docs site: the per-skill pages `site/content/docs/skills/woostack-{harden,plan,build}.mdx`
are **gitignored and generated from SKILL.md** (`git check-ignore` confirms) — they regenerate, so
they are not edited here. The build-loop chain shape is unchanged (no new step/gate), so
`concepts.mdx` / `building-rules.mdx` need no change. `concepts/review-angles.mdx` (authored) gets
a one-line cross-link noting the angles also pre-flight spec/plan authoring (Step 6).

## 3. Implementation Plan

- [ ] **Step 1: Create the shared rubric (red → green)**
  - Verify absent: `test ! -f skills/woostack-harden/references/angle-preflight.md && echo RED-OK`
  - Create `skills/woostack-harden/references/angle-preflight.md` with this content:
    ```markdown
    # Spec/plan angle pre-flight

    A write-time checklist that pulls `woostack-review`'s angle lenses **forward** into authoring,
    so spec and plan gaps are caught while writing — not surfaced late on the docs PR. Read by
    [`woostack-harden`](../SKILL.md) (run on both the spec and the plan) and by
    [`woostack-plan`](../../woostack-plan/SKILL.md)'s self-review; prompted from the spec and plan
    templates.

    **No gate.** Harden raises a question per gap and amends in place; plan self-review fixes
    inline. The actual swarm review still runs on the execution-increment **code** PRs.

    **Canonical angles — link, do not restate.** The authoritative list lives in
    [`woostack-review` `load-config.sh`](../../woostack-review/scripts/load-config.sh)
    (`VALID_ANGLES`); each angle's full rubric lives in
    [`woostack-review/prompts/angles/`](../../woostack-review/prompts/angles/). This file only
    **translates** the relevant angles into "what to ask before writing."

    ## Skip rule (YAGNI)

    Walk only the angles whose surface the artifact actually implicates. A spec with no data layer
    skips `database`; a CLI-only change skips `api` and `i18n`. Do not manufacture questions for
    angles the work does not touch.

    ## Spec lens — what to build (lands in §6 Error handling / §7 Acceptance criteria)

    - **security** — threat surface: untrusted input, authz boundaries, secrets, injection → each
      becomes an error/edge AC.
    - **observability** — failure modes: what is logged, what must not be (PII), errors propagated
      vs. swallowed.
    - **bugs** (edge/error) — the non-happy classes: empty/oversized input, concurrency, partial
      failure — captured as error/edge ACs, not left to "happy" only.
    - **tests** — every behavior in the body has a testable AC in §7 (AC coverage).
    - **api** — contract shape: breaking changes, versioning, auth scope of any exposed surface.
    - **database** — data model, migrations, row-level access, when the spec touches storage.
    - **i18n** — user-facing strings are translatable, when the spec adds UI copy.
    - **deps** — any new dependency the spec implies, and why it is warranted.
    - **infra** — CI/runtime/deploy surface the spec assumes.

    ## Plan lens — how to build (lands in decomposition + self-review)

    - **architecture** — file/module boundaries, increment sequencing, abstraction depth; no layer
      leaks or copy-paste.
    - **tests** — each AC maps to a failing-test step; assertions on behavior, not implementation.
    - **types** — signatures and invariants consistent across tasks (no `any` escape hatch).
    - **security** — implementation choices close, not open, the threat surface the spec named.
    - **observability** — each task's error-handling shape is concrete (no silent catch).
    - **api / database** — interface-first / migration-safe task ordering.
    - **deps** — install/lockfile steps where a new dependency is introduced.

    ## Out of scope for spec/plan

    Code-only angles — `react`, `design`, `seo`, `aeo`, `comments`, `conventions` — rarely apply to
    a markdown spec or plan. They fire at the execution-increment review, on the real diff. Do not
    force them here.
    ```
  - Verify present + lenses: `test -f skills/woostack-harden/references/angle-preflight.md && grep -q "Spec lens" skills/woostack-harden/references/angle-preflight.md && grep -q "Plan lens" skills/woostack-harden/references/angle-preflight.md && echo GREEN-OK`

- [ ] **Step 2: Wire into `woostack-harden/SKILL.md`**
  - Verify absent: `grep -q angle-preflight skills/woostack-harden/SKILL.md || echo RED-OK`
  - Add an **Angle pre-flight** bullet to "The grill loop" (after the existing 4 bullets,
    ~line 27): a write-time walk of
    `[references/angle-preflight.md](references/angle-preflight.md)`, one question per implicated-
    but-unaddressed angle, amend in place.
  - Amend "Terminal state" (line 38-40): *no new questions* now also requires every implicated
    angle addressed (link the rubric).
  - Add one hard-constraint bullet: **Angle pre-flight.** Walk the rubric before declaring
    hardened; no gate; amend in place.
  - Verify: `grep -q "angle-preflight" skills/woostack-harden/SKILL.md && echo GREEN-OK`

- [ ] **Step 3: Add check 4 to `woostack-plan/SKILL.md` §Self-review**
  - Verify absent: `grep -q angle-preflight skills/woostack-plan/SKILL.md || echo RED-OK`
  - After item 3 (Type consistency, ~line 161) add:
    ```markdown
    4. **Angle coverage** — walk the plan lens of the [spec/plan angle pre-flight](../woostack-harden/references/angle-preflight.md):
       architecture boundaries, security/observability, and a failing-test step per AC are each
       addressed by a task. Fix gaps inline.
    ```
  - Verify: `grep -q "angle-preflight" skills/woostack-plan/SKILL.md && echo GREEN-OK`

- [ ] **Step 4: Add `Angle coverage` to `plan-template.md` `## Plan Checks`**
  - Verify absent: `grep -q "Angle coverage" skills/woostack-plan/references/plan-template.md || echo RED-OK`
  - After the `Type consistency` bullet (line 62) add (bare path — template lands in consumer
    repos, no relative skill link):
    ```markdown
    - **Angle coverage** - the plan lens of `skills/woostack-harden/references/angle-preflight.md`
      is walked: architecture, tests-per-AC, security/observability addressed by tasks.
    ```
  - Verify: `grep -q "Angle coverage" skills/woostack-plan/references/plan-template.md && echo GREEN-OK`

- [ ] **Step 5: Add §7 angle pre-flight prompt to `spec-template.md`**
  - Verify absent: `grep -q "Angle pre-flight" skills/woostack-build/references/spec-template.md || echo RED-OK`
  - After the "Each AC is a testable behavior" paragraph (line 44), before the AC rows, add (bare
    path):
    ```markdown
    > **Angle pre-flight.** Before finalizing ACs, walk the spec lens of
    > `skills/woostack-harden/references/angle-preflight.md`: capture each implicated angle —
    > security, observability, api, data, edge/error — as a §6 error path or a §7 error/edge case.
    ```
  - Verify: `grep -q "Angle pre-flight" skills/woostack-build/references/spec-template.md && echo GREEN-OK`

- [ ] **Step 6: Cross-link integrity + site build**
  - Resolve every new relative link target exists:
    - `test -f skills/woostack-harden/SKILL.md` (target `references/angle-preflight.md` resolves to `skills/woostack-harden/references/angle-preflight.md`)
    - `test -f skills/woostack-harden/references/angle-preflight.md` (plan link `../woostack-harden/references/angle-preflight.md`)
    - `test -f skills/woostack-review/scripts/load-config.sh && test -d skills/woostack-review/prompts/angles` (rubric's canonical cross-links)
  - Add a one-line cross-link to `site/content/docs/concepts/review-angles.mdx` (authored page)
    noting the same angles also pre-flight spec/plan authoring via harden — a short sentence or a
    small Callout/"where to go next" note. (Resolved in harden: include it.)
  - Verify: `grep -qi "pre-flight\|preflight\|harden" site/content/docs/concepts/review-angles.mdx && echo GREEN-OK`
  - Build the site (regenerates the gitignored per-skill pages from the edited SKILL.md files):
    `pnpm -C site build` → expect success.

## 4. Verification

- All RED/GREEN echoes above print as expected.
- `grep -rn angle-preflight skills/` shows the rubric + 3 consumers (harden, plan SKILL, and the
  two templates by bare path).
- `pnpm -C site build` exits 0.
- Manual read: spec lens lands in §6/§7, plan lens in decomposition/self-review; no per-angle
  rubric is restated (links only); no approval gate added (harden still "owns no gate"; build
  still three hard gates).
