---
name: memory-distill
type: spec
status: done
date: 2026-06-02
branch: feat/woostack-memory-distill
increment: C of 4
---

# Memory distill + skill wiring — Design Spec

> **Plan:** [[plans/2026-06-02-memory-distill]]

> Increment C of 4. Stacks on B ([[memory-recall]]). Wires the remaining three skills to the memory system. **Docs-only** — no new scripts; reuses A's `build-index`/`doctor` and B's `recall.sh`. Runs a lighter loop (no TDD) because it ships no code.

## 1. Problem

After A (store + tooling) and B (review reads scope-routed memory), three skills are still unwired:
- **woostack-build** never feeds learnings back — knowledge gained building a feature is lost.
- **woostack-bootstrap** scaffolds a repo but never creates `.woostack/`, so a fresh project has no workspace until something writes ad-hoc.
- **woostack-address-comments** — actually already inherits scope-routed memory via B (it reads `/tmp/pr-review/memory.md`, which `prefetch.sh` now composes via `recall.sh`); this just needs documenting.

## 2. Goal

- **Distill (build):** add a build-loop step that, after execute, extracts durable learnings from the spec+plan into **scoped memory notes** with `source:` provenance, then rebuilds the index and lints.
- **Bootstrap→init:** bootstrap invokes `/woostack-init` so a fresh repo gets `.woostack/`.
- **Address:** document that its memory context is already scope-routed (via B); no behavior change.
- Update the memory contract to describe the distill write-path.

## 3. Non-goals

- No new scripts. Distillation is agent behavior (semantic extraction); it reuses `build-index`/`doctor`.
- No change to the accept-by-design write path (`memory-append.sh` still appends to flat `memory.md` — a separate, valid write path).
- No Obsidian layer (D).
- No change to recall.sh or prefetch (B).

## 4. Approach

### Distill = new build step 6.5

Insert between Execute (6) and Offer-PR (7): after the increment lands, the agent extracts each durable, reusable learning from the spec/plan/implementation and writes it as a `memory/` note:
- `type`: `pattern | decision | gotcha | convention`.
- `scope`: inferred from the feature's touched files (e.g. `packages/api/**`).
- `source`: the spec or plan path (provenance).
- body: terse; links related notes with `[[wikilinks]]`.
- **Dedupe first:** check `MEMORY.md` for an existing note on the topic → update rather than duplicate.
- Then run `build-index.sh` + `doctor.sh`; fix any error before the PR.

Only durable, cross-feature knowledge is distilled — not feature-specific trivia (YAGNI for memory).

### Bootstrap invokes /woostack-init

In bootstrap section 10 (Initialize repo), after `git init`, run `/woostack-init` (the canonical scaffold) so `.woostack/{memory,specs,plans,config.json,.gitignore}` exist and are committed with the initial bootstrap.

### Address inherits recall (document only)

woostack-address-comments delegates to the review address verb, which reads `/tmp/pr-review/memory.md` — composed by `prefetch.sh` via `recall.sh` after B. So address already applies scope-routed memory. Add one sentence saying so; no code.

## 5. Components (edits)

- `skills/woostack-build/SKILL.md` — new step 6.5 "Distill"; update the Overview flow line and renumber Offer-PR; add a hard-constraint line ("distill durable learnings, dedupe, never feature trivia").
- `skills/woostack-bootstrap/references/bootstrap.md` — section 10: add the `/woostack-init` step.
- `skills/woostack-bootstrap/SKILL.md` — if it enumerates the procedure, add the init step (else skip).
- `skills/woostack-address-comments/SKILL.md` — one sentence: memory is scope-routed via the review engine's recall.
- `skills/woostack-init/references/memory.md` — a "Distillation (write path)" subsection: build distills spec/plan → scoped notes with `source:`; contrast with the flat-file accept-by-design path.

## 6. Error handling

- Distill runs `doctor` before PR; an error (bad type, dup name) is fixed, not ignored.
- Dedupe prevents memory bloat; if unsure whether a learning is durable, do NOT write it (favor a small curated store).

## 7. Testing

No code → no unit tests. Verification:
- Every cross-link in the edited files resolves.
- `doctor.sh` still passes on any notes the contract example references.
- The woostack-init suite stays green (untouched).
- Manual read-through: the distill step is unambiguous and the bootstrap step is in the right place.

## 8. Open questions

- **Scope inference granularity** — distilled note scope from the feature's touched dirs; the agent picks the narrowest glob that covers them. Documented as guidance, not enforced.
- **Distill autonomy** — auto step, but the agent still uses judgment on what is "durable." Acceptable; doctor + dedupe are the guardrails.
