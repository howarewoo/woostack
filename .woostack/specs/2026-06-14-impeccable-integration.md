---
name: impeccable-integration
type: spec
status: approved
date: 2026-06-14
branch: feature/impeccable-integration
links:
---

# Impeccable integration — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-14-impeccable-integration]]

## 1. Problem

[impeccable](https://github.com/pbakaus/impeccable) (`pbakaus/impeccable`) is a strong, open-source front-end **design skill** for AI coding agents — discipline commands (`/typeset`, `/colorize`, `/animate`, …), a deterministic non-LLM detector (`impeccable detect`, exit-coded), and portable `PRODUCT.md` / `DESIGN.md` context files. woostack should lean on it rather than reinvent front-end design judgment.

Today impeccable is wired into woostack in exactly **one** place: the `design` review angle (`skills/woostack-review/prompts/angles/design.md`) runs `npx -y impeccable detect --json` and layers a Nielsen-heuristics critique on top. It is referenced in `SKILL.md`, `_header.md`, `install.sh`, `action.yml`, `reusable-review.yml`, and the site docs. That integration is **complete and out of scope here**.

Three gaps remain:
- **A — discoverability.** Nothing in woostack's setup/install docs tells an adopter to install impeccable, even though the shipped `design` review angle already expects it (it degrades to LLM-only without it, but adopters never learn the companion exists).
- **C — design craft is not delegated during the build loop.** `woostack-ideate` and `woostack-execute` have no pointer to impeccable's discipline commands when a task is genuine front-end craft, so agents reinvent design judgment inline.
- **D — no design house-rules.** `woostack-ideate` loads `.woostack/wisdom/*.md` wholesale as house-rules but ignores impeccable's `DESIGN.md`, the portable design-system artifact, so designs don't inherit the project's visual system.

## 2. Goal

Make impeccable a **recommended companion** of woostack across three additive, graceful-degrading touch-points — discoverable at install (A), delegated to for design craft in the build loop (C), and consulted for design house-rules (D) — **without** making it a hard dependency. The build loop must continue to run identically when impeccable is absent.

## 3. Non-goals

- **B — the `design` review angle.** Already shipped; this spec does not modify it. (A verify-only confirmation that it still references impeccable is the only contact.)
- **Live Mode** (impeccable's browser companion). Stays out of the gated build loop — it conflicts with `woostack-ideate`'s standing "no bespoke visual server / does not run a browser companion" boundary. Adopters may use it ad-hoc outside the loop; woostack does not wire it in.
- **Changing the review angle's `npx -y impeccable detect` to pnpx.** The angle runs in consumer CI where `npx -y` (zero-install) is portable and `pnpx` may be absent. The setup-mention install command (A) uses `pnpx` because that is a local-dev install matching woostack's package-manager convention — a deliberately different context, not an inconsistency.
- **Making impeccable a hard dependency** of `woostack-build` / `woostack-ideate` / `woostack-execute`. `woostack-build` advertises "no external skill dependencies" (build/SKILL.md); every touch here is optional + graceful-degrade so that property holds.
- **Bundling, vendoring, or pinning a version** of impeccable. It is referenced by name and resolved live (`pnpx skills add …`, `npx -y impeccable@latest`).

## 4. Approach

**Light-touch optional references.** Treat impeccable as a recommended companion, never required. Each touch is additive and degrades cleanly: absent impeccable → the doc note is informational only, the ideate/execute pointers no-op, ideate runs as today. The repo already has the canonical pattern for this in `skills/woostack-review/prompts/angles/security.md` (references OpenAI's `security-best-practices` skill: "Install (optional, host-dependent): `pnpx skills add …`" + fetch-on-demand fallback) — C and D copy that framing.

Rejected alternatives: (1) impeccable as a first-class build sub-phase — breaks the no-dependency property, over-engineered; (2) docs-only (just A) — leaves the design-craft and house-rules gaps open.

Shipped as **one spec → one plan → three PR-sized increments** (A → C → D), stacked on the spec+plan docs PR. Increment order is independent (no increment depends on another), so A ships first as the smallest, highest-certainty change and the user's explicit ask.

## 5. Components & data flow

All edits are skill-collection Markdown (Mode A); no application code.

**Increment A — setup mention (discoverability).** Three files (every surface that shows the woostack install command also surfaces the companion):
- `README.md` §"Getting Started": add a short **"Recommended companion"** blockquote note immediately after the §1 Installation code block — exact command `pnpx skills add pbakaus/impeccable`, one line on why (front-end design skill that powers the `design` review angle and design craft in the build loop), explicitly marked optional. Note the Claude Code plugin alternative (`/plugin marketplace add pbakaus/impeccable`) as a one-liner.
- `site/content/docs/getting-started.mdx`: mirror the same note in the web-native version, consistent with its existing concise style (e.g. a `<Callout>` after the §1 Install block).
- `site/content/docs/index.mdx`: add a **one-line** companion mention near the landing-page install block — terse, so the quickstart stays minimal; point detail-seekers to getting-started.

**Increment C — command delegation (build-loop design craft).**
- `skills/woostack-ideate/SKILL.md` §"Visual treatment, on demand": add a pointer — when a question is genuine front-end **craft** (not a diagram/wireframe), and impeccable is installed, delegate to its discipline commands. Preserve the existing distinction explicitly: `woostack-visualize` renders a view **to show the user**; impeccable **crafts/improves the UI itself**; Live Mode stays out. The standing "no browser companion" line is not weakened.
- `skills/woostack-execute/SKILL.md` §"Per-increment cadence": note that during a UI-touching increment, the implementer may invoke impeccable for design craft — "optional, host-dependent; proceed normally if absent" — placed as an optional detour mirroring the existing `woostack-debug` optional-detour reference in that skill (the verification-failure routing), and the `angles/security.md` optional-skill framing.

**Increment D — DESIGN.md as design house-rules.**
- `skills/woostack-ideate/SKILL.md` step 1 ("Explore project context", which already loads `.woostack/wisdom/*.md` wholesale): additionally load impeccable's `DESIGN.md` (at the repo root — impeccable's `/impeccable init` default — if present) as design-specific house-rules. **Single-home rule** stated in the skill: `DESIGN.md` is the design-system source of truth; `@infrastructure/ui` tokens are its implementation; `.woostack/wisdom/` holds general house-rules. ideate **reads** `DESIGN.md`, never copies it into `wisdom/` — this is what prevents drift between the three.

## 6. Error handling

The whole feature is graceful-degrade by construction:
- **impeccable not installed** → A's note is informational; C's pointers no-op (agent proceeds with built-in judgment); D finds no `DESIGN.md` and skips it (a no-op, exactly like an absent `wisdom/`).
- **No `DESIGN.md` present** → D skips silently (mirrors ideate's "empty or absent `wisdom/` is a no-op").
- **No conflicting instruction** introduced: C must not contradict ideate's "no bespoke visual server" constraint — the spec resolves this by scoping the delegation to craft, not to a running browser server, and keeping Live Mode a non-goal.
- **build/SKILL.md "no external skill dependencies"** stays literally true — verified as AC4.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. This is a documentation/skill-Markdown change with no runtime, so "tests" are `grep`/`bash` content assertions per [woostack-tdd](../../skills/woostack-tdd/SKILL.md)'s no-runner → concrete-verification rule.

- **AC1 — setup docs recommend impeccable (A)**
  - happy: `README.md` and `site/content/docs/getting-started.mdx` each contain `pnpx skills add pbakaus/impeccable` within a clearly-optional "recommended companion"-style note, and `site/content/docs/index.mdx` contains a one-line companion mention.
  - error: the README + getting-started notes are unambiguously marked optional/recommended — `grep` finds "optional" or "recommended" in the same note block (does not read as a required install step).
  - edge: the Claude Code plugin alternative `/plugin marketplace add pbakaus/impeccable` appears once (in the README/getting-started note) as an alternative, not as the primary instruction; index.mdx stays terse (one line, no second code block).
- **AC2 — ideate delegates design craft to impeccable, gated (C)**
  - happy: `woostack-ideate` §"Visual treatment" references impeccable for front-end craft and states the woostack-visualize-vs-impeccable distinction.
  - error: the reference is install-gated/optional (`grep` finds an "if installed"/"optional" qualifier) so an absent impeccable is a no-op.
  - edge: Live Mode is **not** introduced into ideate; the existing "no bespoke visual server / does not run a browser companion" text remains present verbatim (assert it still exists).
- **AC3 — execute may use impeccable for UI increments, gated (C)**
  - happy: `woostack-execute` notes optional impeccable use during UI-touching increments.
  - error: framed "proceed normally if absent" (graceful-degrade qualifier present).
  - edge: N/A — single additive note, no new branch of behavior beyond present/absent (covered by happy/error).
- **AC4 — DESIGN.md loaded as house-rules without breaking the no-dep property (D)**
  - happy: `woostack-ideate` step 1 loads `DESIGN.md` (if present) as design house-rules and states the single-home rule (DESIGN.md = source, infra tokens = implementation, wisdom/ = general).
  - error: absent `DESIGN.md` is stated as a no-op (skip, like absent `wisdom/`).
  - edge: `build/SKILL.md`'s "no external skill dependencies" sentence is still present and true after all edits (no increment converts impeccable into a required dependency).
- **AC5 — B untouched (non-goal guard)**
  - happy: `skills/woostack-review/prompts/angles/design.md` still references impeccable's detector after this change (verify-only; unchanged by these increments).
  - error: N/A — read-only guard.
  - edge: N/A.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

No application runtime and no test runner (skill-collection Markdown). Per woostack-tdd's no-runner rule, each AC is verified by a concrete `grep`/`bash` assertion against the edited files with exact expected output (string present/absent, optional-qualifier present, non-goal text preserved). The plan's "failing test" steps are these assertions written before each edit. There is no CI for this repo's own pushes (AGENTS.md), so verification is local-only; the only CI that touches impeccable is the consumer-facing review workflow, which is unchanged here (AC5).

## 9. Open questions

Resolved during harden:
- **README note form** → blockquote "Recommended companion" note immediately after §1 Installation's code block.
- **Execute note placement** → main SKILL.md, §"Per-increment cadence", as an optional detour mirroring the existing `woostack-debug` reference (not a separate referenced doc).
- **Third install surface** → include `site/content/docs/index.mdx` with a one-line mention (increment A = 3 files); keep the landing terse.
- **DESIGN.md path** → repo root (`/impeccable init` default), loaded only if present.

None remaining.
