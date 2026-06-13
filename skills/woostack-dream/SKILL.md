---
name: woostack-dream
description: Use to curate the .woostack/ knowledge store. Reflects over the static memory store, the specs/plans/fixes/overnight decision corpus, and docs (no session mining), then proposes a gated changeset that merges/replaces/drops/resolves memory notes, consolidates recurring trends from memory + overnight + the specs/plans/fixes corpus into the .woostack/wisdom/ store, and prunes the fully-absorbed scratch (memory notes + overnight reports) it merged. Nothing mutates before explicit approval; ends on a summary + iterate loop. Approved memory/wisdom/doc edits hand off to woostack-commit. Never self-commits or merges. Invoke via /woostack-dream [instructions].
---

# woostack-dream

`woostack-dream` reflects over the static memory store, the specs/plans/fixes decision corpus, the overnight run reports, and documentation (deterministic and repeatable) to clean and align knowledge, and it never reflects over session transcripts or the live conversation. It is a standalone maintenance command and is not part of the `woostack-build` phase. Instead, it serves as the agentic synthesis and apply layer on top of the mechanical lint checks provided by [`doctor.sh`](../woostack-init/scripts/doctor.sh).

## Command

- `/woostack-dream [instructions]`
  - The optional free-text `instructions` argument steers the synthesis focus (for example, `"focus on API conventions; ignore one-off gotchas"`), which is applied throughout the reflection process.
  - When no argument is provided, the tool curates the entire knowledge store.

## Procedure

### Phase 1 — Gather (read-only)

If the `.woostack/memory/` directory exists, run [`doctor.sh`](../woostack-init/scripts/doctor.sh) and capture its warnings (overlap clusters, stale provenance, orphaned scope, dead notes, missing provenance, and non-glob trivia). Next, read `.woostack/memory/MEMORY.md` and the body of every note. Enumerate the documentation surface by executing `git ls-files '*.md'` to gather only tracked markdown files, excluding gitignored memory and any `node_modules` directories. Exclude any files under `.woostack/{specs,plans,fixes}/*.md` from the promotion-target set, as they are provenance inputs rather than targets for documentation updates.

Separately enumerate and read the `.woostack/{specs,plans,fixes,overnight}/*.md` corpus (overnight is gitignored, so it is full-scanned separately — see next paragraph) as design-trend input to the `consolidate` operation. This corpus read is distinct from following `source:` for staleness: it mines authored decisions for recurring trends, but those artifacts are still not documentation-promotion targets. Read it incrementally from the gitignored `.woostack/memory/.dream-watermark` ref when present: `git log <ref>..HEAD --name-only -- .woostack/specs .woostack/plans .woostack/fixes`. Matching is against the always-read memory note index as the history proxy: a new artifact corroborating a decision already captured as a note strengthens or rescopes that note; new-vs-new corroboration is a fresh trend. First run (missing, absent, corrupt watermark, or non-git checkout) is a full-corpus baseline. `instructions: "full corpus"` forces a re-baseline. The watermark advances to `HEAD` only after a successful, approved run.

`.woostack/overnight/*.md` (gitignored morning reports from woostack-execute-overnight) are also read as scratch trend-input. Because overnight reports are gitignored, the git-log watermark cannot track them — they are full-scanned every run; the prune step (Phase 2/4) bounds the set by deleting fully-absorbed reports so the scan does not grow unbounded.

Read the recent `git log` and the specification, plan, or fix that a note's `source:` field points to, using this context to ground judgments of whether a note is stale or current. Honor any optional `instructions` steering argument provided. For further details on the store structure, cross-link the memory contract in [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md).

### Phase 2 — Synthesize the "dream" (read-only)

Produce a changeset of discrete, labeled operations. The changeset must explicitly enumerate the following operations:
- **merge**: Collapse duplicate or fuzzy-near-duplicate notes. The surviving note retains the union of scopes and the most specific provenance. All inbound `[[wikilinks]]` are rewritten to target the survivor by leveraging [`graph.sh`](../woostack-init/scripts/graph.sh) `--backlinks` to identify and update references.
- **replace**: Rewrite contradicted or stale notes to reflect the latest values, while preserving the original `source:` provenance information.
- **drop**: Remove dead notes and notes with orphaned scope. Rewrite or remove inbound links pointing to dropped notes. (Overnight reports are unrecoverable — the Phase 3 gate shows their full body before any prune.)
- **resolve**: Adjudicate each overlap cluster identified by `doctor.sh`. When a confident decision cannot be made, flag the conflict for the user instead of guessing.
- **consolidate**: Roll a recurring pattern (a trend across the memory + overnight +
  specs/plans/fixes corpora) into a single tracked **wisdom file** at `.woostack/wisdom/<slug>.md`,
  per the wisdom contract [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
  The wisdom file's `source:` records **all** contributing inputs (note names +
  artifact paths) as permanent provenance. New wisdom must clear the wisdom contract's bar
  (generalized, cross-cutting, high-value); dedupe store-wide against existing wisdom — a
  corroborated trend strengthens or rescopes the existing wisdom file rather than adding a duplicate.
  `woostack-dream` therefore no longer creates memory notes (those are written by woostack-execute
  distillation); it consolidates, hygienes, and prunes them.
- **prune**: Delete the **fully-absorbed** scratch inputs of a wisdom file — only memory notes and
  overnight reports, never `fixes/specs/plans`. Compute a **prune list** = the subset of a wisdom
  file's `source:` ledger whose value is *fully* captured by the finding (per-input agent judgment).
  Inputs retaining independent value (e.g. a scope-specific memory note) are **partial** → kept or
  rescoped, never pruned. **Any doubt → keep.** See the wisdom contract §5
  [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
- **doc recommendation**: Propose promoting a convention or correcting a contradicted claim in the documentation. This is subject to an evidence guard: every proposed documentation edit must cite a backing memory note. If no backing memory note is found, the documentation edit is prohibited.

This synthesis pass is idempotent and does not mutate any files. A re-run with no new artifacts since the watermark is a no-op unless the user requests a full-corpus baseline.

### Phase 3 — Review gate (HARD)

Present the complete changeset in the conversation transcript as a before-and-after diff or description. The presentation must follow these strict rules:
- Show the full body of each note scheduled to be dropped, as memory notes are git-tracked (recoverable), but `.woostack/overnight/` reports are gitignored and **unrecoverable once deleted** — so the gate shows their full body before any prune.
- Show the **prune list**: each fully-absorbed input, its absorbing wisdom file, and a one-line
  "why absorbed". Show the **full body** of every `.woostack/overnight/` report on the prune list
  (gitignored → unrecoverable). `fixes/specs/plans` never appear on a prune list.
- Explicitly flag any un-adjudicable conflicts for the user to resolve.
- Show a diff for each recommended documentation edit, citing its backing note.

At this gate, no changes from the current synthesis pass have been applied yet. The tool requires explicit, unambiguous user approval before proceeding; silence or ambiguous confirmation does not constitute approval, honoring the project's overall approval-gate discipline. For large changesets, the tool can offer a [`woostack-visualize`](../woostack-visualize/SKILL.md) render tailored to an `engineer` audience as a reading aid, but the actual changeset remains in the conversation for approval rather than being moved to a separate artifact.

### Phase 4 — Apply (on approval)

Upon receiving explicit user approval, perform the following actions:
- **Memory**: Rewrite or delete the affected note files in place. Next, execute [`build-index.sh`](../woostack-init/scripts/build-index.sh) to regenerate the `MEMORY.md` index file. Finally, re-run [`doctor.sh`](../woostack-init/scripts/doctor.sh) to confirm a clean state, reporting any residual warnings (especially unresolved `[[wikilinks]]`). Execute the approved **prune list**: delete each fully-absorbed memory note (`.woostack/memory/<name>.md`) and overnight report (`.woostack/overnight/<file>.md`). Pruning memory notes is a memory mutation → re-run `build-index.sh` then `doctor.sh`; deleting overnight reports touches no index.
- **Wisdom**: Write each new or updated wisdom file to `.woostack/wisdom/<slug>.md`.
- **Docs**: Write the approved documentation edits directly to the working tree.
- **Commit handoff**: Because memory notes and wisdom files are tracked shared knowledge, hand all curated memory changes, new/updated wisdom files, and documentation edits to [`woostack-commit`](../woostack-commit/SKILL.md). Pruned overnight reports are gitignored and require no commit. `woostack-dream` itself never commits, pushes, merges, or advances the watermark before the approved run is successfully applied.

### Phase 5 — Summarize & iterate

Report a clear summary of what changed (including notes merged, replaced, dropped, or added, conflicts resolved, and documentation edits applied). Invite the user to suggest change requests or adjustments. If a change request is received, return to Phase 2 to re-synthesize from the current store state, then proceed through Phases 3 and 4 to present the updated changeset and re-summarize. When complete, hand the approved memory and documentation edits to [`woostack-commit`](../woostack-commit/SKILL.md); after a successful approved run, advance `.woostack/memory/.dream-watermark` to `HEAD`. Do not self-commit, push, or merge during this command.

## Degradation

The tool degrades gracefully depending on the environment:
- If the repository uses a scoped memory store, utilize the designated memory scripts.
- If the scoped store is absent, report that there is no memory store to curate and defer to `/woostack-init`.
- If the `.woostack/{specs,plans,fixes}/` corpus is absent or empty, trend mining is a no-op and the rest of the pass proceeds.
- If the dream watermark is missing or corrupt, fall back to a full-corpus baseline; never error solely because the watermark is unusable.
- If a detected trend duplicates an existing note, update that note rather than adding a duplicate.
- If no `.woostack/` directory exists, stop immediately; there is nothing to curate, and the tool must not scaffold a new store (defer to `/woostack-init`).
- If individual memory scripts are missing (such as in an individual manual install), announce a manual fallback per section 10 of the memory contract [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md). Perform recall and lint checks by hand, and never fail silently.
- If `.woostack/wisdom/` is absent, create it on the first approved `consolidate` (or defer to `/woostack-init`); never error solely because it is missing.
- If `.woostack/overnight/` is absent or empty, the overnight scan is a no-op; the rest of the pass proceeds.

## Hard constraints

- **Non-destructive before the gate**: Do not mutate any files until after the review gate.
- **Explicit approval required**: The review gate requires explicit and positive user approval; silence or ambiguity is not approval.
- **Tracked memory**: Approved memory changes are tracked shared knowledge and hand off to `woostack-commit` with documentation edits.
- **No self-commit or merge**: The tool must never self-commit, push, or merge changes.
- **Evidence-guarded doc edits**: Documentation edits are strictly prohibited without a citing backing memory note.
- **Full-body drop visibility**: Dropped notes must be shown full-body at the review gate.
- **Inbound-link integrity**: Ensure that all inbound links are updated or removed when merging or dropping notes.
- **Idempotent**: A re-run with no new artifacts since the watermark is a no-op.
- **Reuse existing scripts at runtime**: a `woostack-dream` *run* reuses the scripts under
  `skills/woostack-init/scripts/`, adds no new scripts, and does not edit the memory/wisdom contracts.
  (Evolving those contracts or tooling is feature work, not a dream run.)
- **Two stores, one writer**: dream is the only writer of `.woostack/wisdom/`. It consolidates into
  wisdom and prunes absorbed scratch, but never deletes `fixes/specs/plans`.
- **Standalone**: This command is not part of the gated build chain.
