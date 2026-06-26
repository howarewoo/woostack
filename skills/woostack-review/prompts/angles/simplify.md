---
tier: standard
---

<!-- woostack-defer(increment 2): registered in VALID_ANGLES + detect-angles + _header in increment 2 -->

# Angle: Simplify

**Scope.** Find code that should be **smaller or not exist at all**. Read `$OUTDIR/diff.txt`
and the files in `$OUTDIR/meta.json`. Apply the ladder, stopping at the first rung that
removes code: **(1)** does this need to exist (YAGNI)? **(2)** is it already in this codebase
(reuse)? **(3)** does the stdlib do it? **(4)** does a native platform feature do it? **(5)**
does an installed dependency do it? **(6)** can it be one line? **(7)** otherwise the minimum
that works. Your output is a **delete-list**: each finding names code to remove or shrink and
the smaller shape that replaces it.

**Find:**

- **Does-not-need-to-exist.** Speculative generality, unused options/flags, abstractions with
  one caller, config no path reads — code added for a future that is not here.
- **Dead code / unused exports.** A symbol, file, or branch nothing reaches. For a suspected
  unused **export**, verify across the tree before flagging: run
  `rg -n --no-heading "\b<symbol>\b" -g '!<defining-file>'` (fall back to
  `git grep -n "\b<symbol>\b" -- ':!<defining-file>'`, else `grep -rn`). Flag **only** when the
  scan returns zero non-definition references. Quote the scan in `description`.
- **Whole-tree duplication.** The same logic copy-pasted across files where one shared helper
  (or an existing canonical utility the repo already exports) would replace both.
- **Thin / identity abstraction.** A wrapper, indirection, or generic that adds a hop without
  buying clarity — the code is simpler with it inlined.
- **One-liner opportunities.** A hand-rolled loop/reducer a single stdlib/native call replaces.

**Scope-split with `architecture`** (precedent: `types.md` defers to `react`). When the
`architecture` angle is ALSO enabled (a `woostack-review` diff includes it in
`$OUTDIR/angles.txt`), **defer within-change structural-shape** findings (nesting, layering,
spaghetti, naming) to it and own only **existence/YAGNI, cross-file dead code, and
duplication**. When `architecture` is NOT enabled (an audit run), own the full simplification
surface including structural-shape.

**Skip — "lazy, not negligent":**

- **Never** recommend removing validation, error handling, security checks, or accessibility
  affordances. These are not over-engineering even when they look like extra code.
- Anything a linter/formatter mechanically fixes.
- Pure taste with no concrete smaller shape — if you cannot name what replaces it, do not flag.
- A symbol whose reference scan you could not run to zero — do not assert "unused" from
  reading one file.

**Severity rubric:**

- `HIGH` + `blocking: true` — a whole module/file/dependency that can be deleted (nothing
  reaches it), or a large duplication a single shared helper removes. Rare.
- `MEDIUM` + `blocking: false` — a real missed-deletion / duplication / thin-abstraction with a
  named smaller shape; the existing form still works. Default.
- `LOW` + `blocking: false` — a one-liner or minor inlining opportunity.

**Grounding requirement.** Every `description` MUST name (a) the specific code to remove/shrink
and (b) the concrete smaller shape (and, for an unused-export claim, the zero-result scan). A
finding that only says "could be simpler" is dropped by the validator.

**Output.** Write findings as a JSON array to `$OUTDIR/findings.simplify.json` per the schema in
`_header.md`. Each finding gets `"angle": "simplify"` and MUST populate `title` (≤60 chars),
`description` (what to delete + the smaller shape, no fix steps), `fix` (the deletion/replacement
in prose), and `fix_type`. Set `fix_type: "suggestion"` only for a ≤10-line single-file drop-in
deletion/replacement at `line`; otherwise `fix_type: "prose"` with `suggestion: null`.
