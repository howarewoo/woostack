---
name: woostack-dream
description: Use to curate the .woostack/ knowledge store. Reflects over the static memory store + docs (no session mining), then proposes a gated changeset that merges duplicate notes, replaces stale/contradicted ones, drops dead/orphaned notes, resolves conflicts, surfaces consolidated insights, and recommends evidence-guarded documentation edits. Nothing mutates before explicit approval; ends on a summary + iterate loop. Local-only memory (no commit); doc edits land in the working tree. Never commits or merges. Invoke via /woostack-dream [instructions].
---

# woostack-dream

`woostack-dream` reflects over the static memory store and documentation (deterministic and repeatable) to clean and align knowledge, and it never reflects over session transcripts or the live conversation. It is a standalone maintenance command and is not part of the `woostack-build` phase. Instead, it serves as the agentic synthesis and apply layer on top of the mechanical lint checks provided by [`doctor.sh`](../woostack-init/scripts/doctor.sh).

## Command

- `/woostack-dream [instructions]`
  - The optional free-text `instructions` argument steers the synthesis focus (for example, `"focus on API conventions; ignore one-off gotchas"`), which is applied throughout the reflection process.
  - When no argument is provided, the tool curates the entire knowledge store.

## Procedure

### Phase 1 — Gather (read-only)

If the `.woostack/memory/` directory exists, run [`doctor.sh`](../woostack-init/scripts/doctor.sh) and capture its warnings (overlap clusters, stale provenance, orphaned scope, dead notes, missing provenance, and non-glob trivia). Next, read `.woostack/memory/MEMORY.md` and the body of every note. Regardless of the store structure, always read the flat `.woostack/memory.md` file if present. Enumerate the documentation surface by executing `git ls-files '*.md'` to gather only tracked markdown files, excluding gitignored memory and any `node_modules` directories. Exclude any files under `.woostack/{specs,plans,fixes}/*.md` from the promotion-target set, as they are provenance inputs rather than targets for documentation updates. Read the recent `git log` and the specification, plan, or fix that a note's `source:` field points to, using this context to ground judgments of whether a note is stale or current. Honor any optional `instructions` steering argument provided. For further details on the store structure, cross-link the memory contract in [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md).

### Phase 2 — Synthesize the "dream" (read-only)

Produce a changeset of discrete, labeled operations. The changeset must explicitly enumerate the following operations:
- **merge**: Collapse duplicate or fuzzy-near-duplicate notes. The surviving note retains the union of scopes and the most specific provenance. All inbound `[[wikilinks]]` are rewritten to target the survivor by leveraging [`graph.sh`](../woostack-init/scripts/graph.sh) `--backlinks` to identify and update references.
- **replace**: Rewrite contradicted or stale notes to reflect the latest values, while preserving the original `source:` provenance information.
- **drop**: Remove dead notes and notes with orphaned scope. Rewrite or remove inbound links pointing to dropped notes. Note that gitignored memory files are unrecoverable once deleted.
- **resolve**: Adjudicate each overlap cluster identified by `doctor.sh`. When a confident decision cannot be made, flag the conflict for the user instead of guessing.
- **surface**: Consolidate a recurring pattern into a single new note. The `source:` must be derived from the contributing notes and never fabricated. All new notes must pass the memory contract's section 7 distillation gate, which rejects new notes by default unless they represent generalized, high-value knowledge.
- **doc recommendation**: Propose promoting a convention or correcting a contradicted claim in the documentation. This is subject to an evidence guard: every proposed documentation edit must cite a backing memory note. If no backing memory note is found, the documentation edit is prohibited.

This synthesis pass is idempotent and does not mutate any files.

### Phase 3 — Review gate (HARD)

Present the complete changeset in the conversation transcript as a before-and-after diff or description. The presentation must follow these strict rules:
- Show the full body of each note scheduled to be dropped, as gitignored memory is unrecoverable once applied.
- Explicitly flag any un-adjudicable conflicts for the user to resolve.
- Show a diff for each recommended documentation edit, citing its backing note.

At this gate, nothing has mutated. The tool requires explicit, unambiguous user approval before proceeding; silence or ambiguous confirmation does not constitute approval, honoring the project's overall approval-gate discipline. For large changesets, the tool can offer a [`woostack-visualize`](../woostack-visualize/SKILL.md) render tailored to an `engineer` audience as a reading aid, but the actual changeset remains in the conversation for approval rather than being moved to a separate artifact.

### Phase 4 — Apply (on approval)

Upon receiving explicit user approval, perform the following actions:
- **Memory**: Rewrite or delete the affected note files in place. Next, execute [`build-index.sh`](../woostack-init/scripts/build-index.sh) to regenerate the `MEMORY.md` index file. Finally, re-run [`doctor.sh`](../woostack-init/scripts/doctor.sh) to confirm a clean state, reporting any residual warnings (especially unresolved `[[wikilinks]]`).
- **Docs**: Write the approved documentation edits directly to the working tree. Leave these edits uncommitted.

### Phase 5 — Summarize & iterate

Report a clear summary of what changed (including notes merged, replaced, dropped, or added, conflicts resolved, and documentation edits applied). Invite the user to suggest change requests or adjustments. If a change request is received, return to Phase 3/4 to present the updated changeset and re-summarize. When complete, the memory changes remain local-only (uncommitted). For the working-tree documentation edits, offer to hand off the changes to [`woostack-commit`](../woostack-commit/SKILL.md). Do not commit, push, or merge these changes during this command.

## Degradation

The tool degrades gracefully depending on the environment:
- If the repository uses a scoped memory store, utilize the designated memory scripts.
- If only a flat `.woostack/memory.md` file exists, fall back to curating the flat file using bullet-level deduplication, replacement, and dropping, skipping the scope, indexing, and `doctor.sh` machinery.
- If no `.woostack/` directory exists, stop immediately; there is nothing to curate, and the tool must not scaffold a new store (defer to `/woostack-init`).
- If individual memory scripts are missing (such as in an individual manual install), announce a manual fallback per section 10 of the memory contract [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md). Perform recall and lint checks by hand, and never fail silently.

## Hard constraints

- **Non-destructive before the gate**: Do not mutate any files until after the review gate.
- **Explicit approval required**: The review gate requires explicit and positive user approval; silence or ambiguity is not approval.
- **Local-only memory**: Memory changes must remain local-only and must never be staged or committed.
- **Working-tree doc edits**: Documentation edits must only land in the working tree. The tool must never commit, push, or merge changes.
- **Evidence-guarded doc edits**: Documentation edits are strictly prohibited without a citing backing memory note.
- **Full-body drop visibility**: Dropped notes must be shown full-body at the review gate.
- **Inbound-link integrity**: Ensure that all inbound links are updated or removed when merging or dropping notes.
- **Idempotent**: The synthesis pass must be idempotent and repeatable.
- **Reuse existing scripts**: Reuse the existing scripts under `skills/woostack-init/scripts/`; do not add new scripts or modify the memory contract.
- **Standalone**: This command is not part of the gated build chain.
