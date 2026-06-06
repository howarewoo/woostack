**Source:** .woostack/specs/2026-06-06-review-self-contained.md

# Make woostack-review self-contained (retire pr-review-toolkit) Implementation Plan

**Goal:** Fold the three review capabilities woostack-review lacks vs. pr-review-toolkit (silent-failure depth, type-design/invariant scoring, comment accuracy) into woostack-review's existing angle system so `pr-review-toolkit` can be uninstalled with no loss of review value.

**Architecture:** Three independent, Graphite-stacked increments, each grafting into the existing `detect → fan-out → prosecutor/defender → post` pipeline. A & B enrich existing angle prompts (`observability`, `types`) and bump their tier `fast → standard`; A also extends the observability diff trigger precisely. C adds a new always-non-blocking `comments` angle across the eight enumeration sites. No orchestration, validator, or schema-shape changes; no numeric confidence gate.

**Tech Stack:** Bash (`detect-angles.sh`), Markdown angle prompts, the shared `_header.md` contract, `SKILL.md`. Verification is via `bash -n`, `grep`, and running `detect-angles.sh` against fixture diffs (this repo ships skills, not an app — no test runner).

---

## Increment 1: observability — silent-failure depth + precise trigger + tier bump

> One independently shippable PR. Retires `silent-failure-hunter`. Touches `observability.md`, `detect-angles.sh`, `SKILL.md`.

### Task 1: Enrich the observability prompt with the three missing silent-failure patterns

**Files:**
- Modify: `skills/woostack-review/prompts/angles/observability.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c 'null-coalescing\|mock / stub / fake\|unrelated.*error' skills/woostack-review/prompts/angles/observability.md`
Expected: FAIL — prints `0` (none of the new patterns are present yet).

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected output: `0`.

- [ ] **Step 3: Add the three new bullets to the "Swallowed errors" block and tighten retry-exhaustion**

In `observability.md`, the **Swallowed errors** list currently ends at the `void asyncFn()` bullet. Append these three bullets immediately after it:

```markdown
  - `?.` optional chaining / `??` null-coalescing used to silently skip an operation that
    *should* surface a failure — e.g. `user?.save()` where a missing `user` means the write
    never happens and nobody is told, or `primary() ?? fallback()` that masks a failed primary
    call. A legitimate optional *read* (`user?.name`) is fine — flag only when the skipped
    operation has a side effect or a failure that should be observed.
  - Broad, **non-empty** `catch (e) { log; continue }` that can swallow *unrelated* error
    classes. In the finding's `description`, enumerate which unexpected error types this catch
    could hide (e.g. a `TypeError` from a later refactor, an `AbortError`, an out-of-memory) —
    not just the expected one.
  - Mock / stub / fake fallback reached on a **production** code path (e.g. `return
    mockClient()` / `new FakeRepo()` in a non-test file when the real dependency is
    unavailable). This hides an outage behind synthetic data — flag as an architectural defect.
```

Then, in the **Missing signals on new paths** block, replace the retry-exhaustion bullet:

```markdown
  - New retry loop with no log on retry-exhaustion.
```

with:

```markdown
  - New retry loop that exhausts its attempts with no log **and no user-facing signal** — the
    caller silently proceeds as if the operation succeeded.
```

- [ ] **Step 4: Confirm it passes**

Run: `grep -c 'null-coalescing\|mock / stub / fake\|unrelated' skills/woostack-review/prompts/angles/observability.md`
Expected: PASS — prints `3` or more.

### Task 2: Bump the observability angle tier `fast → standard`

**Files:**
- Modify: `skills/woostack-review/prompts/angles/observability.md` (frontmatter)

- [ ] **Step 1: Write the failing verification**

Run: `sed -n '1,3p' skills/woostack-review/prompts/angles/observability.md`
Expected: FAIL — shows `tier: fast`.

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected: the frontmatter reads `tier: fast`.

- [ ] **Step 3: Edit the frontmatter**

Change line 2 of `observability.md` from `tier: fast` to `tier: standard`.

- [ ] **Step 4: Confirm it passes**

Run: `head -3 skills/woostack-review/prompts/angles/observability.md | grep -q 'tier: standard' && echo PASS`
Expected: PASS.

### Task 3: Extend the observability diff trigger for production mock/stub/fake fallbacks (NOT raw `?.`/`??`)

**Files:**
- Modify: `skills/woostack-review/scripts/detect-angles.sh` (`has_observability_diff_token()` + the angle-gating doc header)

> Rationale (resolved spec Q7): firing on any added `?.`/`??` would trigger observability on nearly every TS PR. Broad non-empty `catch` blocks that *log* already fire via the existing `logger.`/`console.` tokens, so the only genuinely-uncovered high-signal case is a mock/stub/fake fallback (which logs nothing). Trigger on that token; leave `?.`/`??` to the prompt when the angle already fires.
>
> Hardened note: the mock/stub/fake grep is deliberately coarse — it also matches a `Mock` constructed in a *test* file. The prompt scopes findings to **production** paths, so a test-only mock costs at most one extra `standard`-tier worker slot and yields no finding. This is the established coarse-trigger / precise-prompt split; the bounded false-fire cost is accepted.

- [ ] **Step 1: Write the failing fixture test**

```bash
export OUTDIR=/tmp/woo-detect-test-mock
rm -rf "$OUTDIR" && mkdir -p "$OUTDIR"
printf '{"files":[{"path":"src/pay.ts"}]}\n' > "$OUTDIR/meta.json"
printf '%s\n' \
  'diff --git a/src/pay.ts b/src/pay.ts' \
  '+++ b/src/pay.ts' \
  '@@ -1,1 +1,2 @@' \
  '+  if (!client) return new MockPaymentClient()' > "$OUTDIR/diff.txt"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
grep -qx observability "$OUTDIR/angles.txt" && echo "OBSERVABILITY-FIRED" || echo "NOT-FIRED"
```

- [ ] **Step 2: Confirm it fails**

Run the block above. Expected: `NOT-FIRED` (the mock fallback token is not yet a trigger; the diff has no logging/catch token).

- [ ] **Step 3: Add the mock/stub/fake grep to `has_observability_diff_token()`**

In `detect-angles.sh`, inside `has_observability_diff_token()` (currently two `grep … && return 0` lines then `return 1`), insert a third detection line **before** `return 1`:

```bash
  # Production mock/stub/fake fallback that hides an outage behind synthetic data.
  # NOT raw ?./?? (too common — would fire on nearly every TS PR; that suppressor
  # check rides on the prompt when the angle already fires). Broad non-empty catch
  # blocks that log already fire via the logger./console. tokens above.
  grep -qE "^\+[^/]*\b(return|=>|:?=)[[:space:]]*(new[[:space:]]+)?(Mock|Fake|Stub)[A-Za-z0-9_]*\(" "$DIFF" && return 0
```

Also update the angle-gating doc header (the `#   observability —` block near the top, lines ~47-50) to append: `, production Mock/Fake/Stub fallback construction`.

- [ ] **Step 4: Confirm syntax + the fixture now fires**

```bash
bash -n skills/woostack-review/scripts/detect-angles.sh && echo "SYNTAX-OK"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
grep -qx observability "$OUTDIR/angles.txt" && echo "OBSERVABILITY-FIRED"
```
Expected: `SYNTAX-OK` then `OBSERVABILITY-FIRED`.

- [ ] **Step 5: Control test — confirm raw `?.`/`??` does NOT broaden the trigger**

```bash
export OUTDIR=/tmp/woo-detect-test-optchain
rm -rf "$OUTDIR" && mkdir -p "$OUTDIR"
printf '{"files":[{"path":"src/util.ts"}]}\n' > "$OUTDIR/meta.json"
printf '%s\n' \
  'diff --git a/src/util.ts b/src/util.ts' \
  '+++ b/src/util.ts' \
  '@@ -1,1 +1,2 @@' \
  '+  const name = user?.name ?? "anon"' > "$OUTDIR/diff.txt"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
grep -qx observability "$OUTDIR/angles.txt" && echo "WRONGLY-FIRED" || echo "CORRECTLY-SILENT"
```
Expected: `CORRECTLY-SILENT` (proves we did not broaden on `?.`/`??`). Note: `types` will fire here (it's a `.ts` file) — that is expected and unrelated.

### Task 4: Move observability from the `fast` tier row to a new `standard` row in SKILL.md

**Files:**
- Modify: `skills/woostack-review/SKILL.md` (Model-routing tier table, ~line 349)

- [ ] **Step 1: Write the failing verification**

Run: `grep -n '`observability`, `types`, `i18n`, `docs`, `deps` workers | `fast`' skills/woostack-review/SKILL.md`
Expected: FAIL to be absent — the line is still present (observability/types not yet moved).

- [ ] **Step 2: Confirm it fails**

Run: `grep -q 'observability\`, \`types\`, \`i18n\`, \`docs\`, \`deps\` workers | \`fast\`' skills/woostack-review/SKILL.md && echo "STILL-FAST"`
Expected: `STILL-FAST`.

- [ ] **Step 3: Edit the tier table**

In the tier table, change the `fast` row from:

```markdown
| `observability`, `types`, `i18n`, `docs`, `deps` workers | `fast` | Pattern matching + diff-anchored hygiene checks. |
```

to (drop `observability`, and add a new `standard` row above it — note `types` is dropped in Increment 2, which stacks on this one):

```markdown
| `observability` worker | `standard` | Silent-failure depth: error-suppression + swallow-path reasoning. |
| `types`, `i18n`, `docs`, `deps` workers | `fast` | Pattern matching + diff-anchored hygiene checks. |
```

- [ ] **Step 4: Confirm it passes**

Run: `grep -q '`observability` worker | `standard`' skills/woostack-review/SKILL.md && echo PASS`
Expected: PASS.

- [ ] **Step 5: Commit increment 1**

```bash
gt create -m "feat(woostack-review): add silent-failure depth to observability angle"
```

---

## Increment 2: types — type-design / invariant depth + tier bump

> One independently shippable PR, stacked on Increment 1. Retires `type-design-analyzer`. Touches `types.md`, `SKILL.md`.

### Task 1: Add a "Type design & invariants" section to the types prompt

**Files:**
- Modify: `skills/woostack-review/prompts/angles/types.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c 'Anemic domain model\|unrepresentable\|Mutable internals' skills/woostack-review/prompts/angles/types.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected: `0`.

- [ ] **Step 3: Insert the new section before the `**Skip:**` block**

In `types.md`, immediately before the `**Skip:**` line, insert:

```markdown
- **Type design & invariants:**
  - Anemic domain model: a new type that is a bag of public, independently-settable primitives
    whose invariants are enforced nowhere — or only in a prose comment (e.g.
    `{ startDate: string; endDate: string }` with "endDate must be after startDate" written in a
    comment instead of the type).
  - Mutable internals leaking an invariant: a public mutable field / array / map callers can
    mutate to violate the type's contract (no `readonly`, no encapsulation, an exposed setter).
  - Invariant left to runtime/docs that the type system could enforce: `string` where a branded
    type, template-literal type, or union would make the illegal state unrepresentable (e.g.
    `status: string` instead of `'active' | 'archived'`; a raw `string` id instead of `UserId`).
```

- [ ] **Step 4: Confirm it passes**

Run: `grep -c 'Anemic domain model\|unrepresentable\|Mutable internals' skills/woostack-review/prompts/angles/types.md`
Expected: PASS — prints `3`.

### Task 2: Bump the types angle tier `fast → standard` (prompt + SKILL.md)

**Files:**
- Modify: `skills/woostack-review/prompts/angles/types.md` (frontmatter)
- Modify: `skills/woostack-review/SKILL.md` (tier table — the `fast` row left by Increment 1)

- [ ] **Step 1: Write the failing verification**

Run: `head -3 skills/woostack-review/prompts/angles/types.md | grep -q 'tier: fast' && echo "STILL-FAST"`
Expected: FAIL-state present — prints `STILL-FAST`.

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected: `STILL-FAST`.

- [ ] **Step 3: Edit both files**

(a) In `types.md`, change line 2 from `tier: fast` to `tier: standard`.

(b) In `SKILL.md`, fold `types` into the `standard` observability row created in Increment 1, and drop it from the `fast` row. Change:

```markdown
| `observability` worker | `standard` | Silent-failure depth: error-suppression + swallow-path reasoning. |
| `types`, `i18n`, `docs`, `deps` workers | `fast` | Pattern matching + diff-anchored hygiene checks. |
```

to:

```markdown
| `observability`, `types` workers | `standard` | Silent-failure depth + type-design/invariant reasoning. |
| `i18n`, `docs`, `deps` workers | `fast` | Pattern matching + diff-anchored hygiene checks. |
```

- [ ] **Step 4: Confirm it passes**

```bash
head -3 skills/woostack-review/prompts/angles/types.md | grep -q 'tier: standard' && echo "PROMPT-OK"
grep -q '`observability`, `types` workers | `standard`' skills/woostack-review/SKILL.md && echo "SKILL-OK"
```
Expected: `PROMPT-OK` then `SKILL-OK`.

- [ ] **Step 5: Commit increment 2**

```bash
gt create -m "feat(woostack-review): add type-design/invariant depth to types angle"
```

---

## Increment 3: new `comments` angle (comment-accuracy)

> One independently shippable PR, stacked on Increment 2. Retires `comment-analyzer`. Touches all eight add-an-angle enumeration sites: `detect-angles.sh`, new `comments.md`, `_header.md` (count + table + python whitelist + schema discriminator), `SKILL.md` (prose list + tier table).

### Task 1: Create the `comments` angle prompt

**Files:**
- Create: `skills/woostack-review/prompts/angles/comments.md`

- [ ] **Step 1: Write the failing verification**

Run: `test -f skills/woostack-review/prompts/angles/comments.md && echo EXISTS || echo MISSING`
Expected: FAIL — prints `MISSING`.

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected: `MISSING`.

- [ ] **Step 3: Create the file with this exact content**

```markdown
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
```

- [ ] **Step 4: Confirm it passes**

```bash
test -f skills/woostack-review/prompts/angles/comments.md && \
grep -q 'findings.comments.json' skills/woostack-review/prompts/angles/comments.md && echo PASS
```
Expected: PASS.

### Task 2: Gate the `comments` angle in detect-angles.sh

**Files:**
- Modify: `skills/woostack-review/scripts/detect-angles.sh` (doc header + `ANGLES+=` block)

> Gate: reuse the existing `has_code_file()` predicate. Comment rot most often surfaces when the surrounding code changes while its comment does not, so fire on any source-code change (same population as `architecture`). Markdown-only PRs do not fire it.
>
> Hardened note (cost asymmetry): this fires on ~every code PR, which is acceptable precisely because `comments` is `fast`-tier and **always non-blocking** — the cheapest worker, never gating a merge. Contrast Increment 1, where observability is `standard`-tier and *can* block, so its trigger is kept narrow (no raw `?.`/`??`). Cheap+advisory tolerates a broad gate; expensive+blocking does not.

- [ ] **Step 1: Write the failing fixture test**

```bash
export OUTDIR=/tmp/woo-detect-test-comments
rm -rf "$OUTDIR" && mkdir -p "$OUTDIR"
printf '{"files":[{"path":"src/sort.ts"}]}\n' > "$OUTDIR/meta.json"
printf '%s\n' \
  'diff --git a/src/sort.ts b/src/sort.ts' \
  '+++ b/src/sort.ts' \
  '@@ -1,1 +1,2 @@' \
  '+// input must be pre-sorted' \
  '+export function pick(xs: number[]) { return xs[0] }' > "$OUTDIR/diff.txt"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
grep -qx comments "$OUTDIR/angles.txt" && echo "COMMENTS-FIRED" || echo "NOT-FIRED"
```

- [ ] **Step 2: Confirm it fails**

Run the block above. Expected: `NOT-FIRED` (no `comments` angle exists yet).

- [ ] **Step 3: Add the doc-header entry and the gating block**

(a) In the angle-gating doc header, after the `#   skills —` block (~line 70), add:

```bash
#   comments  — reuses the general-purpose source-file signal (any *.{ts,js,py,go,…}
#               in the diff, same as architecture). Audits whether code comments still
#               match the code the PR changed (comment rot). Always non-blocking.
```

(b) After the `architecture` gating block (`if has_code_file; then ANGLES+=("architecture"); fi`), add:

```bash
if has_code_file; then
  ANGLES+=("comments")
fi
```

- [ ] **Step 4: Confirm syntax + the fixture now fires**

```bash
bash -n skills/woostack-review/scripts/detect-angles.sh && echo "SYNTAX-OK"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
grep -qx comments "$OUTDIR/angles.txt" && echo "COMMENTS-FIRED"
```
Expected: `SYNTAX-OK` then `COMMENTS-FIRED`.

### Task 3: Register `comments` in the `_header.md` shared contract (4 edits)

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md`

- [ ] **Step 1: Write the failing verification**

```bash
grep -q 'nineteen distinct review angles' skills/woostack-review/prompts/_header.md && echo C1
grep -q '| `comments` |' skills/woostack-review/prompts/_header.md && echo C2
grep -q '"comments","bugs"\|comments","security\|,"comments"' skills/woostack-review/prompts/_header.md && echo C3
grep -q 'docs | deps | architecture | comments\|architecture | comments' skills/woostack-review/prompts/_header.md && echo C4
```
Expected: FAIL — prints nothing (no `C1`..`C4`).

- [ ] **Step 2: Confirm it fails**

Run the block above. Expected: empty output.

- [ ] **Step 3: Make the four edits**

(a) **Count** (line ~88): change `up to eighteen distinct review angles` to `up to nineteen distinct review angles`.

(b) **Review Angles table** (after the `skills` row, ~line 109): add:

```markdown
| `comments` | no | LLM only — gated on general-purpose source files in diff (same signal as `architecture`); audits whether code comments still match the code the PR changed. Always non-blocking. |
```

(c) **Python footer whitelist** (line ~272): in the set, append `,"comments"` so it reads:

```python
    if angle in {"bugs","security","conventions","seo","aeo","design","react","database","tests","api","infra","observability","types","i18n","docs","deps","architecture","comments"}:
```

(d) **Findings-schema discriminator** (line ~346): change the `angle` enumeration to end with `… | docs | deps | architecture | comments`.

- [ ] **Step 4: Confirm it passes**

```bash
grep -q 'nineteen distinct review angles' skills/woostack-review/prompts/_header.md && echo C1
grep -q '| `comments` | no |' skills/woostack-review/prompts/_header.md && echo C2
grep -q '"architecture","comments"' skills/woostack-review/prompts/_header.md && echo C3
grep -q 'architecture | comments`' skills/woostack-review/prompts/_header.md && echo C4
```
Expected: PASS — prints `C1` `C2` `C3` `C4`.

### Task 4: Register `comments` in SKILL.md (prose list + tier table)

**Files:**
- Modify: `skills/woostack-review/SKILL.md`

- [ ] **Step 1: Write the failing verification**

```bash
grep -q '`comments`' skills/woostack-review/SKILL.md && echo "FOUND" || echo "ABSENT"
```
Expected: FAIL-state — prints `ABSENT`.

- [ ] **Step 2: Confirm it fails**

Run the command above. Expected: `ABSENT`.

- [ ] **Step 3: Make the two edits**

(a) **Prose conditional-angle list** (line ~270): in the conditional list, append `, `comments` (when the diff touches general-purpose source files)` after the `architecture` clause.

(b) **Tier table** `fast` row (left by Increment 2 as `| `i18n`, `docs`, `deps` workers | `fast` | …`): add `comments` so it reads:

```markdown
| `i18n`, `docs`, `deps`, `comments` workers | `fast` | Pattern matching + diff-anchored hygiene checks. |
```

- [ ] **Step 4: Confirm it passes**

```bash
grep -c '`comments`' skills/woostack-review/SKILL.md
```
Expected: PASS — prints `2` (prose list + tier table).

### Task 5: End-to-end angle-count sanity check

- [ ] **Step 1: Verify the angle prompt count matches the registered set**

```bash
ls skills/woostack-review/prompts/angles/*.md | wc -l
```
Expected: the prior count **+1** (the new `comments.md`). There are now nineteen angle prompt files.

- [ ] **Step 2: Commit increment 3**

```bash
gt create -m "feat(woostack-review): add comments angle for comment-accuracy review"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — §4.A (observability +3 patterns + precise trigger + tier) → Increment 1; §4.B (types invariant depth + tier) → Increment 2; §4.C (new comments angle) → Increment 3. Non-goals (no numeric gate, no code-simplifier/pr-test-analyzer port, no schema-shape change) honored: nothing in this plan adds a confidence score, a simplifier, or a new schema field.
- [ ] **No placeholders** — every edit step carries exact file, exact insertion text, and a runnable verification command with expected output.
- [ ] **Type consistency** — angle name is `comments` everywhere (file `comments.md`, `findings.comments.json`, `"angle": "comments"`, whitelist, schema, table, tier row, prose list); tier strings are exactly `fast`/`standard`; the SKILL.md tier-table line is mutated in a defined sequence across Increments 1→2→3 (observability moves to standard in 1, types joins it in 2, comments joins the fast row in 3) — each increment's Step-3 text matches the prior increment's output state.

> woostack plan conventions (kept):
> - Frontmatter-free; opens with the `**Source:**` line.
> - Filename mirrors the spec basename: `2026-06-06-review-self-contained.md` (the spec's date).
> - No required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - This is a skills repo: each "failing test" is a `grep` / `bash -n` / fixture-`detect-angles.sh` verification with exact expected output, not a unit test.
