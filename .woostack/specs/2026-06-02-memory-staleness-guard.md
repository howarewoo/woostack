---
name: memory-staleness-guard
type: spec
status: done
date: 2026-06-02
branch: memory-staleness-guard
links:
---

# Memory Staleness Guard — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`doctor.sh` already checks memory note structure and warns when a note's `scope:` globs match no tracked files. It does not check whether a distilled note's `.woostack` provenance still exists. A note derived from a deleted spec or plan can remain in the memory store and keep influencing future work without any prompt for review.

## 2. Goal

Add a cheap stale-provenance warning to `doctor.sh` for memory notes whose `source:` points at a missing `.woostack/specs/` or `.woostack/plans/` file, and document the warning in the memory contract.

## 3. Non-goals

- Do not add an expensive semantic validation pass.
- Do not fail `doctor.sh` for stale provenance; warnings still exit 0.
- Do not validate non-file provenance such as `source: pr-165`.
- Do not change memory note schema or distillation behavior.
- Do not rework the existing orphaned-scope check.

## 4. Approach

Keep the check in `skills/woostack-init/scripts/doctor.sh`, alongside the existing per-note warning checks. For each non-index note, read `source:` with the existing `field` helper. If `source:` starts with `.woostack/specs/` or `.woostack/plans/`, test it as a repo-root-relative file path. When the file is missing, emit a warning naming the note and source path, then continue.

Sources outside those two `.woostack` authored-document roots are intentionally ignored. Review memory currently writes values like `source: pr-165`, and future provenance may be URLs or other symbolic references. Treating only `.woostack/specs/` and `.woostack/plans/` as filesystem paths keeps the check precise.

## 5. Components & data flow

- `doctor.sh` iterates each memory note under the supplied memory directory.
- `field "$f" source` extracts provenance from frontmatter.
- A shell `case` detects `.woostack/specs/*` and `.woostack/plans/*`.
- `[ -f "$source" ]` checks existence from the current working directory, matching the existing expectation that `doctor.sh` is run from the consumer repo root.
- Missing files call `warn`, incrementing the warning count without affecting the exit code.

## 6. Error handling

Malformed notes, missing required fields, bad types, duplicate names, and empty bodies remain errors. Stale provenance is a warning only. Blank `source:`, absent `source:`, PR provenance, URLs, and paths outside `.woostack/specs/` or `.woostack/plans/` produce no warning.

## 7. Testing

Extend `skills/woostack-init/scripts/tests/test-doctor.sh` with fixtures in the existing throwaway git repo:

- A note with `source: .woostack/specs/missing.md` warns and exits 0.
- A note with `source: .woostack/plans/missing.md` warns and exits 0.
- Notes whose `.woostack/specs/existing.md` or `.woostack/plans/existing.md` files exist do not warn.
- A note with `source: pr-165` does not warn.

Run `bash skills/woostack-init/scripts/tests/run-tests.sh` to verify the full init-script test suite.

## 8. Open questions

None. The approved scope is the cheap structural stale-provenance proxy from issue 160.
