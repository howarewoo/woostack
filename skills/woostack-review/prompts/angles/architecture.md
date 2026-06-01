---
tier: standard
---

# Angle: Architecture

**Scope.** Find **structural-quality regressions** introduced by this PR's diff — places where the change adds incidental complexity that a cleaner reframing would delete outright. Read `/tmp/pr-review/diff.txt` and the changed source files referenced in `/tmp/pr-review/meta.json`. Judge the diff against the code it touches: did *this change* make the surrounding code simpler or harder to reason about?

You are not a correctness reviewer (`bugs` owns that), a rule enforcer (`conventions` owns that), or a UI critic (`design` owns that). You hunt for the **"code judo" move** — the restructuring that preserves behavior while making the implementation dramatically simpler, smaller, more direct. Flag a finding only when you can name the concrete simpler shape, not merely assert "this is complex."

**Find** (each must be introduced or materially worsened by the diff):

- **Missed deletion.** New branches, conditionals, flags, or layers that a better model would make vanish — e.g. a boolean/nullable mode threaded through control flow where a typed variant or a sensible default would erase the special case.
- **Spaghetti growth.** Ad-hoc conditionals bolted onto an unrelated existing flow instead of pushed into a dedicated abstraction; a change that makes the surrounding function harder to follow.
- **Thin / identity abstraction.** A new wrapper, indirection layer, or generic mechanism that adds a hop without buying clarity — indirection the diff would be simpler without.
- **Layer leak.** Feature-specific logic added to a shared/canonical path, or a bespoke helper that duplicates an existing canonical utility the repo already exports.
- **File decomposition smell.** The diff pushes a file decisively past a large-file threshold (≈1,000 lines) by piling on rather than extracting — flag only when extraction into a focused module is the obviously cleaner move, never on line-count alone.
- **Copy-paste over extraction.** Logic duplicated from an existing site in the same diff/file instead of extracted to one shared helper.
- **Cast / `any` / optional muddying contracts.** New casts, `any`, or optional params that obscure an invariant the diff could state directly through a precise type.
- **Needless sequencing.** Independent operations forced sequential, or a multi-step update left non-atomic, where the parallel/atomic shape is also the simpler one.

**Skip:**

- Anything lint- or type-catchable (Biome / ESLint / Prettier / `tsc`) — that is noise here.
- Pre-existing structure the PR merely touches but did not worsen. Only flag complexity *this diff* introduced or grew.
- Pure taste with no concrete simpler alternative. If you cannot state the specific restructuring, do not flag it.
- Correctness, security, naming-style, UI, dependency, or doc issues — other angles own those. Do not double-report.
- Speculative "this might not scale" without a complexity the diff actually adds today.

**Severity rubric** (be conservative — this is the most subjective angle; the validator discards anything you cannot ground in a concrete reframing):

- `HIGH` + `blocking: true` — only when the diff bakes in a clear structural regression AND a visible, low-risk reframing deletes a whole category of complexity. Rare. Reserve for changes that will be expensive to unwind later.
- `MEDIUM` + `blocking: false` — a real missed-simplification or spaghetti-growth call with a named cleaner shape, but the existing form still works. This is the default for most findings.
- `LOW` + `blocking: false` — minor indirection or decomposition nit; cleaner alternative exists but the cost of the current form is small.

**Grounding requirement.** Every finding's `description` MUST name (a) the specific complexity the diff introduced and (b) the concrete simpler shape that removes it. A finding that only asserts "too complex" / "could be cleaner" without the target shape will be dropped by the validator.

**Output.** Write findings as a JSON array to `/tmp/pr-review/findings.architecture.json` using the schema in `_header.md`. Each finding gets `"angle": "architecture"` and MUST populate `title` (bold headline ≤60 chars), `description` (the structural problem + the concrete simpler shape — no fix steps), `fix` (the recommended restructuring in prose), and `fix_type`. Set `fix_type: "suggestion"` only when a ≤10-line single-file drop-in replacement at `line` fully captures the restructuring — structural refactors rarely fit, so default to `fix_type: "prose"` with `suggestion: null`. See `_header.md` for the full rule.
