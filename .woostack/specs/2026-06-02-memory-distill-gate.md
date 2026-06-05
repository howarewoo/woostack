---
name: memory-distill-gate
type: spec
status: done
date: 2026-06-02
branch: feature/memory-distill-gate
links:
---

# Memory: distillation gate + updated: coverage (#167 + #161) — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

Two gaps in the scoped-memory write path, both part of the memory-system efficacy initiative ([[woostack-memory-vault]]):

- **#161 — distillation drift.** "Distill cross-feature knowledge, not trivia" is a per-cycle judgment the agent re-makes each build. Judgment drifts; the store fills with thin, feature-specific notes that dilute recall. The current dedupe is exact-name vs `MEMORY.md` only — near-duplicates phrased differently slip through.
- **#167 — incomplete dead-note coverage.** `doctor.sh`'s dead-note check requires `updated:` as its age basis and silently skips notes without it. The distillation write path does not currently guarantee an `updated:` stamp, so the dead-note signal covers only part of the store. (The review write path `memory-record.sh` already stamps it; distillation is the lone gap.)

## 2. Goal

Raise the write bar with a mechanical reject-by-default gate at distill time, backed by `doctor.sh` warnings that catch escapes — and guarantee every distilled note carries `updated:` so dead-note detection has full coverage.

## 3. Non-goals

- No fuzzy-hook-dedupe **script** — fuzzy `hook:` comparison stays agent-judgment in the prose procedure. doctor does not attempt semantic dedupe. **Known soft spot:** the strengthened dedupe has no mechanical backstop this increment; store-level hook/scope collision surfacing is deferred to #162 (conflict detection), the dedicated issue, where it can be done right.
- No error-severity gates. All new `doctor.sh` checks are warning-only (exit 0). Distill notes from legacy or review paths must never hard-block.
- #166 (churn-guard for review stamping) and #168 (recalled-but-acted-on signal) stay deferred per their issues.
- No new script file; no change to `recall.sh`, `build-index.sh`, `memory-record.sh`, or the build/execute flow beyond the distill step prose.

## 4. Approach

Two layers: a write-time procedure (prose the distill step follows) and a `doctor.sh` backstop (mechanical warnings catching what slips through).

**Layer 1 — distill procedure (prose).** Encode a reject-by-default checklist the distill step must pass before writing each note:

1. **Cross-feature test** — if `scope:` is a single literal file/path (no glob), reject as trivia. Scope must be a glob that could plausibly fire on another feature's files.
2. **Provenance required** — no `source:` → no note.
3. **Dedupe (strengthened)** — exact-name vs `MEMORY.md` **plus** a fuzzy `hook:` compare for near-duplicates phrased differently; update the existing note instead of adding.
4. **Stamp `updated:`** — every created/updated note gets today's ISO date (#167).

**Layer 2 — doctor.sh backstop.** Three new per-note warning checks in the existing lint loop.

## 5. Components & data flow

| Touch point | Change |
|---|---|
| `skills/woostack-init/references/memory.md` §7 | Add the reject-by-default gate (4 items above) to the distillation write-path contract. Canonical home for the rule. |
| `skills/woostack-build/SKILL.md` step 7 | Terse pointer only — "apply the reject-by-default distillation gate (memory.md §7) and stamp `updated:`". Do NOT restate the four criteria (CLAUDE.md: cross-link, don't duplicate). §7 is canonical. |
| `skills/woostack-init/scripts/doctor.sh` | Add 3 warning-only checks in the per-note loop (see below). |
| `skills/woostack-init/references/memory.md` §8 | Document the 3 new warnings alongside existing staleness signals. |

**doctor.sh checks (all `warn`, exit 0):**

- **Missing `source:`** — `source` field empty/absent on a note in `memory/` → warn (provenance gap).
- **Non-glob `scope:`** — `scope` non-empty, not global (`*`), **no** `*` glob char anywhere in the field, **and** `source:` is not review-provenance (`pr-*` / `address-comments`) → warn `non-glob scope '<scope>' (possible trivia — prefer a glob)`. Catches single literal paths and all-literal multi-globs in one test. Global notes (`scope: *` or absent) exempt; review-recorded notes exempt because they deliberately scope narrowly to suppress an accepted finding only where it applies (see [memory.md §7](../../skills/woostack-init/references/memory.md) review write path).
- **Missing `updated:`** — no `updated:` field at all → warn (cannot be aged; add `updated:`). Complements the existing dead-note check, which still only fires when `updated:` is present and old.

Data flow unchanged: doctor reads frontmatter via `field()` from `lib.sh`, same as the existing checks. No new dependency, no `git`/`stat` calls.

## 6. Error handling

- All new checks increment the warning counter, never the error counter — `doctor.sh` still exits 0 on warnings, 1 only on pre-existing error conditions. The distill step's "fix any error" contract is unaffected; warnings are advisory.
- Single-path check must not false-positive on a legitimately single-file note (e.g. a shared root config) beyond a warning — human reviews; never blocks.
- A note missing `source:` from a global/flat-shard context is in `memory.md`, not `memory/`; doctor only lints `memory/`, so those are out of range by construction.
- The fuzzy `hook:` dedupe is best-effort agent judgment; no failure mode in tooling.

## 7. Testing

doctor.sh is bash; verify by fixture, matching the existing test style (`WOOSTACK_NOW` deterministic override pattern already in the script):

- Note with glob `scope:`, `source:`, `updated:` → no new warnings.
- Note with single literal `scope: packages/api/handler.ts`, distill/source-less → non-glob-scope warning; exit still 0.
- Note with all-literal multi-scope `scope: a/b.ts, c/d.ts` → non-glob-scope warning (no `*` anywhere).
- Note with `scope: *` (or absent) → no non-glob-scope warning.
- **Review-provenance exempt:** note with literal `scope: packages/api/handler.ts` **and** `source: pr-42` (or `address-comments`) → NO non-glob-scope warning.
- Note missing `source:` → missing-source warning.
- Note missing `updated:` → missing-updated warning; and confirm dead-note check skips it (no double signal beyond the new warning).
- Multi-glob `scope: packages/api/**, apps/*/x.ts` → no non-glob-scope warning (contains `*`).
- Full pass: a clean realistic note → 0 new warnings, exit 0.

Run `bash doctor.sh` against a temp fixture dir for each. Confirm warning text is greppable and the summary line counts correctly. Re-run `build-index.sh` is unaffected (no frontmatter shape change).

## 8. Open questions

None — all four design forks resolved in brainstorm:
- Gate model → procedure + doctor backstop.
- Backstop severity/scope → 2 #161 checks, warning-only; fuzzy dedupe stays procedural.
- #167 doctor coverage → add missing-`updated:` warning (third check).
- Distill stamps `updated:` → procedural, in §7.
