---
type: fix
status: in-review
branch: fix/prefetch-rule-dedupe
---

# Fix: Dedupe symlinked project-rule files in review prefetch

## 1. Root Cause

`skills/woostack-review/scripts/prefetch.sh` builds `$OUTDIR/rules.md` from two path lists and only dedupes by the relative path string:

- auto-discovered root rule files and per-directory walk-up rule files are appended to `RULES_LIST`, then reduced with `awk 'NF && !seen[$0]++'` at `prefetch.sh` lines 669-684;
- `review.project_rules` glob matches are appended to `EXTRA_LIST`, then separately reduced with the same path-only `awk` at lines 718-724;
- both write loops concatenate every surviving relative path into `rules.md` with a separate `## SOURCE:` header at lines 687-691 and 726-731.

That means `AGENTS.md` and `GEMINI.md -> AGENTS.md` are treated as two different documents even though they resolve to the same inode/content. A local reproduction in a temp repo with `AGENTS.md` plus `GEMINI.md` symlink and a 12-LOC fake PR produced:

```text
Discovered 2 rule file(s), 76 bytes:
  AGENTS.md
  GEMINI.md
rules headers 2
## SOURCE: AGENTS.md
canonical rule

## SOURCE: GEMINI.md
canonical rule
```

The same bug applies across the two discovery channels: a `review.project_rules` glob can append a document already included by auto-discovery because the second phase has its own dedupe set and unconditionally appends to `rules.md`.

## 2. Proposed Fix

Add one shared rule-document append path inside `prefetch.sh` that dedupes candidates before concatenation by:

1. resolved real path, so symlinks and alternate relative spellings of the same file include once;
2. content hash, so hard-linked or copied rule files kept in sync also include once;
3. original relative path, preserving the existing path-level uniqueness as a fallback and keeping the first discovered source header as the emitted `## SOURCE:`.

Use that shared path for both auto-discovery and `review.project_rules` candidates so dedupe state spans root scan, walk-up scan, and config globs. Keep the existing 100KB cap behavior and status output, but report only documents that actually survive dedupe.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing prefetch tests**
  - Add a shell regression test under `skills/woostack-review/scripts/tests/` that creates a temp git repo with `AGENTS.md`, root symlink aliases such as `GEMINI.md`, and nested walk-up aliases such as `src/AGENTS.md -> ../AGENTS.md`; drive a fake PR via `WOO_REVIEW_TEST_MODE=1` and assert `$OUTDIR/rules.md` contains one `## SOURCE:` section and the canonical rule body once.
  - In the same test, configure `.woostack/config.json` with `review.project_rules` matching an already auto-discovered rule, a symlinked alias such as `.claude/CLAUDE.md`, and a copied rule with identical content; assert all duplicates are still emitted only once by real path or content hash.

- [x] **Step 2: Apply the minimal prefetch dedupe fix**
  - Refactor the `prefetch.sh` rule-file assembly to collect auto-discovered and config-glob candidates through one deduping writer keyed by real path plus content hash, preserving first source order and first source label.
  - Ensure missing globs and absent rule files remain no-ops, and keep the existing `rules.md` 100KB cap and log lines.

- [x] **Step 3: Verification**
  - Run the new regression test script directly.
  - Run the existing prefetch-focused tests that exercise adjacent behavior: `test-prefetch-flat-memory.sh` and `test-prefetch-incremental-rebase.sh`.
  - Run `bash -n skills/woostack-review/scripts/prefetch.sh`.
