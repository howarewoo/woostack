---
tier: fast
---

# Angle: Comments

**Scope.** Audit whether code comments introduced or affected by this PR's diff still tell the
truth about the code. Read `/tmp/pr-review/diff.txt`. Focus on comments that **lie about or
lag** the code — never on prose style. Advisory only: this angle is **always non-blocking**.

**Find:**

- **Stale comment after a change:** a comment (unchanged or edited) that describes behavior the
  diff altered — wrong parameter name, removed branch, changed return value, renamed symbol.
- **Comment contradicts the code it sits on:** the comment asserts X, the adjacent code does
  not-X (inverted condition, different default, opposite order).
- **Invariant comment the code no longer holds:** "must be sorted" / "never null" / "caller
  holds the lock" that the diff breaks or that the new code violates.
- **Doc-comment drift:** a JSDoc / docstring `@param` / `@returns` / type that no longer matches
  the signature the diff produced.

**Skip:**

- Comments that merely restate the obvious, *unless* they are actively misleading.
- Pre-existing comment rot in code the PR does not touch.
- Style of comments (capitalization, TODO formatting, banner art).
- Spelling / grammar in comments.

**Severity rubric (never blocking):**

- `MEDIUM` + `blocking: false` — a comment that would actively mislead a maintainer about
  behavior or an invariant (wrong contract, inverted condition).
- `LOW` + `blocking: false` — minor drift (stale `@param` name, outdated example) with low
  misdirection risk.
- Never emit `blocking: true`. If a comment-vs-code mismatch reflects a real code bug, that is
  the `bugs` angle's finding, not this one.

**Output.** Write findings as a JSON array to `/tmp/pr-review/findings.comments.json` using the
schema in `_header.md`. Each finding gets `"angle": "comments"`, `"blocking": false`, and MUST
populate `title` (bold headline ≤60 chars), `description` (the mismatch: what the comment claims
vs. what the code now does — no fix), `fix` (the comment edit in prose), and `fix_type`. Set
`fix_type: "suggestion"` only when a ≤10-line single-file drop-in comment replacement at `line`
is safe — and populate `suggestion` accordingly. Otherwise set `fix_type: "prose"` with
`suggestion: null`. See `_header.md` for the full rule.
