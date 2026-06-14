---
name: review-self-contained
type: spec
status: planning
date: 2026-06-06
branch: review-self-contained
links:
---

# Make woostack-review self-contained (retire pr-review-toolkit) — Design Spec

> **Plan:** [[plans/2026-06-06-review-self-contained]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

woostack-review is meant to be a self-contained review engine, but the user also runs the
external `pr-review-toolkit` plugin (Anthropic) for review depth woostack does not obviously
match. The user wants to **uninstall pr-review-toolkit** without losing review value.

Recon of pr-review-toolkit's six subagents against woostack-review's eighteen angles shows:

- **Fully redundant** (no action): `code-reviewer` → woostack `bugs` + `conventions` angles
  with the adversarial **prosecutor/defender** validator pair. code-reviewer's signature feature
  is a single self-scored ≥80 confidence gate; woostack's two independent validation passes are
  equal-or-stronger false-positive suppression. `code-simplifier` → the user's `/simplify`
  command. `pr-test-analyzer` → woostack `tests` angle (behavioral coverage gaps).
- **Real gaps** (this spec closes them): three capabilities present in pr-review-toolkit and
  absent or shallow in woostack-review:
  1. **Silent-failure depth** (`silent-failure-hunter`). woostack `observability` catches empty
     `catch {}`, `.catch(() => null)`, ignored rejections — but **misses** `?.`/`??` used to
     silently skip operations that should fail, broad *non-empty* catches that swallow unrelated
     error types, and mock/stub/fake fallbacks shipped in production code. Its retry-exhaustion
     check is log-only, not user-impact aware.
  2. **Type-design / invariant scoring** (`type-design-analyzer`). woostack `types` audits
     type-system *holes* (`any`, unsafe casts, untyped boundaries) but has **nothing** on type
     *design*: anemic domain models, mutable internals, invariants enforced only by comments.
  3. **Comment accuracy** (`comment-analyzer`). No woostack angle checks whether code comments
     match the code. `docs` covers README/CHANGELOG/markdown, not in-code comment rot.

## 2. Goal

After this change, uninstalling `pr-review-toolkit` loses **no review capability**:

- woostack-review's `observability` angle matches `silent-failure-hunter`.
- woostack-review's `types` angle matches `type-design-analyzer`.
- a new `comments` angle matches `comment-analyzer`.
- the three already-covered subagents (`code-reviewer`, `code-simplifier`, `pr-test-analyzer`)
  stay covered as-is.

Each addition grafts into the **existing angle architecture** (detect → fan-out → prosecutor/
defender → post). No new orchestration, no parallel review pipeline, no numeric confidence gate.

## 3. Non-goals

- **Not** porting `code-simplifier` — the `/simplify` command owns refactor-for-clarity; review
  flags, it does not rewrite.
- **Not** porting `pr-test-analyzer` — woostack `tests` already audits behavioral coverage/edge
  paths; we do not duplicate it.
- **Not** adding code-reviewer's numeric 0–100 confidence gate — the prosecutor/defender
  intersection is the chosen false-positive mechanism and supersedes a self-scored number.
- **Not** changing the swarm, merge, validators, severity-floor, or memory machinery.
- **Not** importing pr-review-toolkit's project-specific assumptions verbatim (e.g. its hardcoded
  `constants/errorIds.ts` Sentry convention) — woostack stays framework-agnostic, deferring such
  specifics to `rules.md` when a consuming repo mandates them.

## 4. Approach

Three independent, individually-shippable sub-changes. Each is a reviewable increment.

### A. Enrich the `observability` angle (silent-failure depth)

In [`skills/woostack-review/prompts/angles/observability.md`](../../skills/woostack-review/prompts/angles/observability.md),
extend the **Swallowed errors** section with the three missing patterns and tighten the
retry-exhaustion line:

- `?.` optional chaining / `??` null-coalescing used to silently skip an operation that *should*
  surface a failure (not a legitimate optional access).
- Broad **non-empty** `catch (e) { log; continue }` that can swallow *unrelated* error types —
  finding must enumerate which unexpected error classes the catch could hide.
- Mock / stub / fake fallback reached in **production** code paths (architectural defect, not
  test scaffolding).
- Retry loop that exhausts attempts and continues with **no user-facing signal** (extend the
  existing log-only retry-exhaustion bullet to cover user impact).

Then extend the angle's **detection trigger** so the new checks actually fire — but precisely:
in [`skills/woostack-review/scripts/detect-angles.sh`](../../skills/woostack-review/scripts/detect-angles.sh),
broaden `has_observability_diff_token()` **only** for cheap high-signal tokens — `mock`/`stub`/
`fake` fallback identifiers and broad non-empty `catch` blocks — **not** for raw `?.`/`??`
(resolved Q7: firing on any added `?.`/`??` would trigger observability on nearly every TS PR —
cost blowup + noise). The `?.`/`??`-as-suppressor check rides on the **prompt only** and is
evaluated whenever the angle already fires; `?.`/`??` suppression co-occurs with the
`catch`/`.catch`/logging changes that already trigger observability, so the relevant PRs are
already in scope. Accepted miss: a PR whose *only* silent failure is a lone `?.` with no other
error-handling change (rare, low-stakes; `bugs`/`architecture` still see the diff). **Without a
trigger extension the prompt enrichment never fires** (the angle is diff-gated, not always-on).

### B. Deepen the `types` angle (invariant / type-design)

In [`skills/woostack-review/prompts/angles/types.md`](../../skills/woostack-review/prompts/angles/types.md),
add a **Type design & invariants** section covering type-design-analyzer's four axes —
encapsulation, invariant expression, invariant usefulness, invariant enforcement — surfaced as
concrete findings (not numeric scores):

- Anemic domain model: a type that is a bag of public primitives with invariants enforced
  nowhere (or only in prose comments).
- Mutable internals leaking an invariant (public mutable field / array that callers can corrupt).
- Invariant expressible in the type system but left to runtime/docs (e.g. `string` where a
  branded type or union would make the illegal state unrepresentable).

Trigger is unchanged (already fires on `*.ts/tsx`). Tier may rise `fast → standard` (open
question) because invariant reasoning is heavier than hole-spotting.

### C. New `comments` angle (comment accuracy)

Add a first-class angle following the established add-an-angle contract (the four enumeration
sites — see Components). Scope: code comments that **lie about or lag the code** — stale
comments after a refactor, comments describing behavior the diff changed, comments asserting an
invariant the code no longer holds. Advisory: **always non-blocking** (mirrors comment-analyzer's
advisory-only stance), `LOW`/`MEDIUM` only, never `blocking: true`. Skip: comments that merely
restate the obvious unless misleading; pre-existing comment rot in untouched code; style.

## 5. Components & data flow

Files touched, by increment:

**A — observability:**
- `skills/woostack-review/prompts/angles/observability.md` (prompt body)
- `skills/woostack-review/scripts/detect-angles.sh` (`has_observability_diff_token()`)
- maybe `_header.md` + `SKILL.md` tier row if tier bumps to `standard`

**B — types:**
- `skills/woostack-review/prompts/angles/types.md` (prompt body)
- maybe `_header.md` + `SKILL.md` tier row if tier bumps to `standard`

**C — comments (full add-an-angle, four sites — per the `woostack-review-add-angle` learning):**
1. `skills/woostack-review/scripts/detect-angles.sh` — `has_comments_*` gate + append to `ANGLES`
2. `skills/woostack-review/prompts/angles/comments.md` — new angle prompt (`tier:`, scope,
   find/skip/severity/output, writes `findings.comments.json`)
3. `skills/woostack-review/prompts/_header.md` — Review-Angles table row, `angle` discriminator
   in the findings schema, **and** the Python footer whitelist set
4. `skills/woostack-review/SKILL.md` — prose angle list + tier-routing table

Data flow for all three is unchanged: `detect-angles.sh` writes `angles.txt` → one sub-agent per
angle reads `_header.md` + its angle prompt + `diff.txt` → writes `findings.<angle>.json` →
merge → prosecutor + defender intersect → post.

## 6. Error handling

- **Trigger-or-it-never-runs.** The single biggest failure mode (learned, see
  `woostack-review-add-angle`): a prompt enriched but its diff trigger not extended means the
  new checks silently never fire. Increment A and C must add/verify the trigger, and testing
  must assert the trigger fires on a fixture diff.
- **Comment-angle noise.** Comment accuracy is inherently judgment-heavy and false-positive prone.
  Containment: always non-blocking, lean on the prosecutor/defender intersection, and a tight
  Skip list. If still noisy, it surfaces as nits under the severity floor, never blocking.
- **No regression to existing angles.** Enriching observability/types must not drop their current
  checks; additions are additive sections.

## 7. Testing

This repo ships skills, not an app — verification is via the review scripts and a real diff, not
an app test harness.

- **Automated-ish:** run `detect-angles.sh` against crafted fixture diffs and assert the right
  angle appears in `angles.txt`: (a) a diff adding `x?.y()` / `a ?? fallback()` in a call
  position fires `observability`; (b) a diff adding a `return mockClient()` fallback fires
  `observability`; (c) a source diff with a stale comment fires `comments`.
- **Manual:** run a full `woostack-review` pass on a small PR seeded with one `?.`-suppressed
  failure, one anemic mutable domain type, and one comment that contradicts the code; confirm one
  finding from each of observability / types / comments survives prosecutor+defender.
- **No-regression:** re-run an existing review fixture; confirm prior observability/types findings
  still surface.

## 8. Open questions

**Resolved during spec harden (2026-06-06):**

1. ~~`comments` new angle vs. fold into `docs`?~~ **New angle.** `docs` triggers on markdown
   files; comment-accuracy must fire on *source* diffs — a different trigger and scope. Pays the
   four-site add-an-angle tax once.
2. ~~Deepen `types` in place vs. a separate angle?~~ **Enrich `types` in place.** Same `*.ts`
   trigger, avoids the four-site tax.
3. ~~`comments` always non-blocking?~~ **Yes.** Advisory, `LOW`/`MEDIUM` only, never
   `blocking: true` — mirrors comment-analyzer's advisory-only stance.
4. ~~Broad-catch "hidden error types" output?~~ **Prose in `description`.** Do not touch the
   shared findings schema.
5. ~~Increment order / count?~~ **Three increments A, B, C — defer exact decomposition to the
   plan phase.** `woostack-plan` owns increment structuring; they are independent, any order, C
   the largest.
6. ~~Deliberately skip code-reviewer's numeric confidence gate, `code-simplifier`,
   `pr-test-analyzer`?~~ **Confirmed skip** — prosecutor/defender supersedes the numeric gate;
   `/simplify` and the `tests` angle cover the other two. Captured in Non-goals (§3).

7. ~~`?.` / `??` trigger precision (increment A)?~~ **Prompt-only for `?.`/`??`; broaden the
   trigger only for high-signal `mock`/`stub`/`fake` fallback + broad-catch tokens.** Folded into
   §4.A. Captures ~all real suppressor cases (they co-occur with already-triggering error-handling
   changes) at bounded cost; accepts the rare lone-`?.` miss.
8. ~~Tier bumps?~~ **observability `fast → standard`, types `fast → standard`, new `comments`
   stays `fast`.** New sections need model-thinky reasoning (invariant design; "what could this
   catch hide"); both remain diff-gated so cost stays bounded. Requires updating the tier rows in
   `_header.md` and `SKILL.md` for observability and types (in addition to the per-increment
   files already listed in §5).
