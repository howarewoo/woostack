---
type: fix
status: hardened
branch: fix/status-board-github-links
---

# Fix: Status board PR references are not clickable GitHub links

## 1. Root Cause

This is a small enhancement, not a defect. The `/woostack-status` HTML board
(`.woostack/visuals/status-board.html`) renders every increment PR in the
`Increments` column as a static, non-clickable text chip. The evidence:

- `skills/woostack-status/scripts/status.sh:272` — `chip()` emits
  `<span class="chip c-%s">#%s %s</span>`. A `<span>` can never be a link.
- `prs_for_spec` (`status.sh:144-165`) and `prs_for_branch`
  (`status.sh:167-175`) request `--json number,state,headRefName,author,updatedAt[,body]`
  and emit those fields as TSV. The PR **`url`** field GitHub returns is never
  requested, so the renderer has no destination to link to even if it wanted one.

Net: the board already names PRs by number (`#123`) but strips away the one datum
(`.url`) needed to turn that reference into a navigable GitHub link.

The terminal table is the "canonical narration surface" (SKILL.md), a fixed-width
plain-text table with byte-exact tests; it stays plain text. Only the HTML board —
"the status board" the user means — gains links.

## 2. Proposed Fix

Thread the PR `url` through the existing PR-resolution path and let `chip()` render
an anchor when a URL is present, falling back to today's `<span>` when it is not
(gh absent, older gh without `url`, or any empty value):

1. `prs_for_spec` / `prs_for_branch` — add `url` to the `gh pr list --json` field
   list and append `(.url // "")` as a trailing TSV column. `@tsv` renders a null
   as an empty field, so stubs/gh that omit `url` degrade cleanly to "no link".
2. The two increment loops in the main body read the new trailing `url` column and
   pass it to `chip()`. Position is trailing, so the existing `${upd:0:10}` and all
   terminal-cell logic (`inc_parts`, `inc_cell`) are untouched — terminal output is
   byte-identical.
3. `chip()` gains a 4th `url` argument: when non-empty it emits
   `<a class="chip c-MARK" href="ESCAPED_URL" target="_blank" rel="noopener noreferrer">#N LABEL</a>`
   (href HTML-escaped via the existing `html_escape`; `target="_blank"` +
   `rel="noopener noreferrer"` so a click opens the PR in a new tab and the board
   stays put); when empty it emits the current `<span>`, keeping the gh-absent /
   no-url path pixel-identical to today.
4. `board-template.html` — add chip-anchor styling so a linked chip reads as a chip,
   not a default underlined blue link: `a.chip { text-decoration: none; color:
   inherit; }` and `a.chip:hover { text-decoration: underline; }`. No URL is added to
   the template file itself (the offline-template test forbids `http(s)://` there).

Non-goals: no links in the terminal table; no linking of the spec/fix name column
(blob URLs for in-flight files on feature branches are unreliable and out of scope).

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with a failing test**
  - In `skills/woostack-status/scripts/tests/test-html-board.sh`, extend the
    multi-PR `gh` stub (the `#11/#10/#9` case) to emit a `url` field per PR, and
    change the three chip assertions to expect the anchor form, e.g.
    `<a class="chip c-open" href="https://github.com/o/r/pull/11" target="_blank" rel="noopener noreferrer">#11 open</a>`.
  - Extend the branch-fallback stub (`#77`) to emit a `url` and assert the partial
    chip is now an anchor:
    `<a class="chip c-partial" href="...">#77 (partial)</a>`.
  - Add one assertion proving graceful fallback: a PR with no `url` (or gh absent)
    still renders the plain `<span class="chip ...">` (no `<a`), so the degradation
    path is pinned.
  - Confirm these fail against the current `chip()` (`<span>` only).
- [ ] **Step 2: Apply the minimal fix**
  - `status.sh`: add `url` to both `gh pr list --json` field lists; append
    `(.url // "")` to both jq `@tsv` outputs; read the trailing `url` in both
    loops; give `chip()` the 4th `url` arg with the anchor (new-tab) / span branch and
    an `html_escape`d href.
  - `board-template.html`: add the `a.chip` / `a.chip:hover` CSS rules.
- [ ] **Step 3: Verification**
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh` — both
    `test-html-board.sh` and `test-status.sh` green (terminal assertions unchanged,
    HTML chip assertions now expect links).
  - Sanity-render the real board in this repo
    (`WOO_STATUS_NO_OPEN=1 bash skills/woostack-status/scripts/status.sh`) and
    confirm any PR chip in `.woostack/visuals/status-board.html` is an `<a href>` to
    the real GitHub PR (or a `<span>` when gh is unauthenticated).
