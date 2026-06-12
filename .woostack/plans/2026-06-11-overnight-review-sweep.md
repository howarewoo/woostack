**Source:** .woostack/specs/2026-06-11-overnight-review-sweep.md

# Overnight review sweep Implementation Plan

**Goal:** Add a post-implementation review sweep to `woostack-execute-overnight` that drives every increment PR in a track to a clean review (full `woostack-review` → `woostack-address-comments --auto` → restack-this-stack → re-review, bottom-up, bounded), before advancing to the next track.

**Architecture:** Pure skills-markdown change, no app runtime. Adds a `## Post-implementation review sweep` section to `skills/woostack-execute-overnight/SKILL.md`, cross-wires it from override #2 / terminal-state / hard-constraints / frontmatter, and extends `skills/woostack-execute-overnight/references/report-template.md` with a Review-sweep section + a per-increment sweep column. Additive: per-increment override #2 is unchanged. Verification is concrete presence/consistency checks (`grep`, `bash -n`) — the established woostack prompt/skill-edit pattern — not a live-LLM or app test.

**Tech Stack:** Markdown (skill docs), `grep`/`bash` for verification, Graphite (`gt`) referenced in prose only.

---

## Increment 1: Post-implementation review sweep section + report wiring

> One independently shippable PR (~120 lines of markdown across 2 files, ≪500 LOC) — its own Graphite-stacked branch. Splitting further is artificial: the SKILL section and the report rows it produces are one coupled unit and must land together.

Conventions for this increment:
- All paths are repo-relative (the increment worktree's cwd).
- "Failing test" = a `grep`/`bash -n` check that returns non-zero / empty **before** the edit and the expected match **after** ([woostack-tdd](../../skills/woostack-tdd/SKILL.md) no-runner substitution).
- Edit the **real installed** files under `skills/woostack-execute-overnight/`.

### Task 1: Add the `## Post-implementation review sweep` section to the SKILL

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md` (insert a new section between `## Tracks & halt policy` and `## Morning report`)

- [ ] **Step 1: Write the failing check**

Run: `grep -c "Post-implementation review sweep" skills/woostack-execute-overnight/SKILL.md`
Expected: FAIL — prints `0` (section absent).

- [ ] **Step 2: Insert the section**

Insert the following block immediately **before** the `## Morning report` line in `skills/woostack-execute-overnight/SKILL.md`:

```markdown
## Post-implementation review sweep

After a track's increments are all implemented and committed — and **before advancing to the
next track** — drive that track's stack to a clean review. This is **additive**: the
per-increment override #2 (the `--fast` blocking-review check during the build) is unchanged;
the sweep is a separate, thorough pass over the finished stack. It runs for **both drivers**
(inline and subagent), giving a subagent-built stack its first PR-level review. It **never
merges**.

A plan with no `## Track:` headings has one implicit track, so the default is exactly: implement
the whole stack, then sweep it. The sweep covers **increment (code) PRs only** — never the
docs-only spec+plan base PR. If a track halted mid-implementation, the sweep covers the
increments that reached a committed PR, bottom-up.

### The per-PR loop (bottom-up, drive-to-clean)

For each increment PR in the track, from the **base of the stack upward**, work in a **per-PR
worktree** on the existing increment branch. If that branch is already checked out in a preserved
blocker worktree, reuse it; otherwise run `git worktree add "$wt" <inc-branch>` — **no** `-b`.
The **primary tree is never edited**, per the [worktree contract](../woostack-init/references/worktrees.md)
§3. Export `WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first (contract
§5) so any `address-comments` memory write lands in the primary store. Then loop, up to
`max_rounds` rounds (see Config):

1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review
   of the whole PR), so a fix that breaks something *outside* its own diff is still caught, and
   inline-mode override #2's per-increment SHA watermark can never silently narrow the pass to an
   incremental one.
2. **Clean?** Clean = woostack-review's computed verdict has **no blocking findings** (`STATUS_LINE`
   `APPROVED` / `APPROVED WITH SUGGESTIONS`) **and zero unresolved threads** (checked via `gh`).
   Read the **verdict, not the GitHub event**: overnight increment PRs are self-authored, so
   woostack-review downgrades the posted event `APPROVE`→`COMMENT` (you cannot approve your own
   PR). Clean ⇒ teardown the worktree, advance to the next PR. "Clean" is **review-clean, not a
   human merge-approval** — the run still never merges.
3. **Address** — otherwise run
   [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) from inside the
   worktree (its clean-tree + branch=PR-head precondition holds there): it fixes / pushes back /
   replies / resolves / pushes (via `woostack-commit --no-pr-update`). Never force-push a protected
   base; never merge.
4. **Restack this track's own stack** — `gt restack` then `gt submit` scoped to the current stack,
   so the PRs above rebase onto the new tip. **Never `gt sync` or a repo-wide restack** (worktree
   contract §4/§6: a repo-wide restack collides with any parallel run in flight). A restack/rebase
   conflict is a **blocker**.
5. **Re-review** → back to step 1.

Strictly bottom-up: a PR is driven to clean before the sweep moves up, and a fix only restacks the
PRs **above** it — never a cleared lower PR — so each PR is reviewed exactly once on the way up.

### Termination backstop

The per-PR loop is bounded — **whichever trips first**:

- **Max rounds** — at most `max_rounds` review→address rounds per PR (default **3**; see Config).
- **No-progress guard** — stop early when a round resolves **no** thread, **or** a re-review returns
  the **same** blocking findings as the prior round, **or** an `address-comments` `CLARIFY` leaves a
  thread open (an open thread fails the clean check and can never go clean by churning).

Either, without a clean PR, is a **blocker → halt** (below). The reason is written to the decision
log.

### Halt (reuses Tracks & halt policy)

A sweep blocker — cap-without-clean, no-progress, a restack conflict, or an `address-comments` step
that would touch the never-auto-approve set (destructive / secret / auth / network / ambiguous) —
**ends that track's remaining sweep** (the blocked PR and every PR above it become
`not-attempted-review`) and the run **advances to the next track**, exactly the existing
[Tracks & halt policy](#tracks--halt-policy). Safety is never relaxed for autonomy; the blocked
PR's worktree is **left in place** for morning inspection.

### Config

`overnight.review_sweep.max_rounds` in `.woostack/config.json` (positive integer, default **3**)
caps the per-PR rounds. Validated at **pre-flight**: a non-positive / non-integer value warns, falls
back to 3, and is recorded in the report — never a refuse-to-start (a sweep-cap typo is not a doomed
plan).
```

- [ ] **Step 3: Run the checks, confirm they pass**

Run:
```bash
grep -c "Post-implementation review sweep" skills/woostack-execute-overnight/SKILL.md
grep -q "base of the stack upward" skills/woostack-execute-overnight/SKILL.md && echo "bottom-up: ok"
grep -q "woostack-review <PR#> --full" skills/woostack-execute-overnight/SKILL.md && echo "full: ok"
grep -q 'gt sync' skills/woostack-execute-overnight/SKILL.md && echo "no-gt-sync: ok"   # 'gt sync' appears only in its prohibition
grep -q "overnight.review_sweep.max_rounds" skills/woostack-execute-overnight/SKILL.md && echo "config-key: ok"
grep -q "STATUS_LINE" skills/woostack-execute-overnight/SKILL.md && echo "verdict-not-event: ok"
grep -q "per-PR worktree" skills/woostack-execute-overnight/SKILL.md && echo "worktree: ok"
```
Expected: `1`, then `bottom-up: ok`, `full: ok`, `no-gt-sync: ok`, `config-key: ok`, `verdict-not-event: ok`, `worktree: ok`.

- [ ] **Step 4: Confirm placement (between Tracks & halt and Morning report)**

Run: `grep -n "^## \(Tracks & halt policy\|Post-implementation review sweep\|Morning report\)" skills/woostack-execute-overnight/SKILL.md`
Expected: the three headings appear in that order (Tracks & halt policy < Post-implementation review sweep < Morning report).

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(execute-overnight): post-implementation review sweep section"
```

### Task 2: Cross-wire override #2, terminal state, hard constraints, and the description

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md` (override #2 cross-ref, terminal-state, hard-constraints, frontmatter `description`)

- [ ] **Step 1: Write the failing checks**

Run:
```bash
grep -c "see \[Post-implementation review sweep\]" skills/woostack-execute-overnight/SKILL.md
grep -c "Drive the stack to clean review" skills/woostack-execute-overnight/SKILL.md
```
Expected: FAIL — both print `0`.

- [ ] **Step 2a: Cross-ref from override #2**

In the `## Autonomy overrides` item **2. Blocking review**, append a final sentence to the
**subagent** sub-bullet (the last line of item 2), so the per-increment override points at the new
stack-wide pass. Change the end of item 2 from:

```markdown
     the loop already was the retry; no separate auto-address).
```

to:

```markdown
     the loop already was the retry; no separate auto-address).

   Override #2 is the **per-increment early check** during the build. The stack-wide
   **drive-to-clean** happens after implementation — see
   [Post-implementation review sweep](#post-implementation-review-sweep), which is additive and
   leaves this override unchanged.
```

- [ ] **Step 2b: Update Terminal state**

In `## Terminal state`, replace:

```markdown
Stop when every track has either completed or halted at a blocker. The result is a Graphite stack
(linear, or tree-stacked across tracks) of reviewed / partially-reviewed increment PRs, plus a
complete morning report. Report the path. **Never merge.**
```

with:

```markdown
Stop when every track has either completed (increments implemented **and** swept to a clean review)
or halted at a blocker. The result is a Graphite stack (linear, or tree-stacked across tracks) of
increment PRs each driven to a clean review — or partially, with blockers logged — plus a complete
morning report. Report the path. "Clean" is review-clean, never a merge. **Never merge.**
```

- [ ] **Step 2c: Add a Hard-constraints bullet**

In `## Hard constraints`, immediately after the `**Tracks: author-driven, overnight-only.**`
bullet, insert:

```markdown
- **Drive the stack to clean review.** After a track's increments are committed, sweep its
  increment PRs bottom-up — `woostack-review --full` → `woostack-address-comments --auto` → restack
  **this stack only** (`gt restack`/`gt submit`, never `gt sync`) → re-review — to a clean verdict
  (no blocking findings, read from `STATUS_LINE` not the self-downgraded event) + zero unresolved
  threads. Bounded by `overnight.review_sweep.max_rounds` (default 3) + a no-progress guard; a
  blocker halts only that track. Both drivers. Never merge.
```

- [ ] **Step 2d: Update the frontmatter `description`**

In the YAML frontmatter `description:` string, find the **exact** clause `drives every increment to a reviewed stack` (verified present on the `description:` line) and insert immediately after it — before the following `, swapping` — this text:
` then runs a post-implementation review sweep that drives each increment PR to a clean review (full woostack-review → auto-address → restack → re-review, bounded)`
so the line reads `...drives every increment to a reviewed stack then runs a post-implementation review sweep that drives each increment PR to a clean review (full woostack-review → auto-address → restack → re-review, bounded), swapping woostack-execute's stop-and-ask gates...` (rest of the string unchanged).

- [ ] **Step 3: Run the checks, confirm they pass**

Run:
```bash
grep -q "see \[Post-implementation review sweep\](#post-implementation-review-sweep)" skills/woostack-execute-overnight/SKILL.md && echo "override2-xref: ok"
grep -q "Drive the stack to clean review" skills/woostack-execute-overnight/SKILL.md && echo "hard-constraint: ok"
grep -q "swept to a clean review" skills/woostack-execute-overnight/SKILL.md && echo "terminal-state: ok"
grep -q "post-implementation review sweep that drives each increment PR to a clean review" skills/woostack-execute-overnight/SKILL.md && echo "description: ok"
```
Expected: `override2-xref: ok`, `hard-constraint: ok`, `terminal-state: ok`, `description: ok`.

- [ ] **Step 4: Regression — override #2's `--fast` per-increment text is unchanged**

Run: `grep -q "woostack-review --fast" skills/woostack-execute-overnight/SKILL.md && echo "override2-fast: still present"`
Expected: `override2-fast: still present` (the augment invariant — sweep did not remove or alter override #2).

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(execute-overnight): wire sweep into override #2, terminal state, constraints, description"
```

### Task 3: Extend the morning-report template with the Review sweep

**Files:**
- Modify: `skills/woostack-execute-overnight/references/report-template.md` (per-increment table column + new Review-sweep section + decision-log examples)

- [ ] **Step 1: Write the failing check**

Run: `grep -c "## Review sweep" skills/woostack-execute-overnight/references/report-template.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2a: Add a Sweep column to the per-increment table**

Replace the per-increment table header + row:

```markdown
| Track | Increment | Status | Branch / PR | Review | Auto-address rounds |
|---|---|---|---|---|---|
| {{A}} | {{1}} | {{done / done-with-findings / blocked / not-attempted}} | {{branch / PR URL}} | {{verdict}} | {{0–2}} |
```

with:

```markdown
| Track | Increment | Status | Branch / PR | Review | Auto-address rounds | Sweep |
|---|---|---|---|---|---|---|
| {{A}} | {{1}} | {{done / done-with-findings / blocked / not-attempted}} | {{branch / PR URL}} | {{verdict}} | {{0–2}} | {{clean / blocked / not-attempted-review}} |
```

- [ ] **Step 2b: Add the Review sweep section**

Immediately **after** the per-increment table block and **before** `## Decision log`, insert:

```markdown
## Review sweep

> Post-implementation drive-to-clean over each track's stack, bottom-up. One row per swept
> increment PR. "Clean" = no blocking findings (`STATUS_LINE`) + zero unresolved threads; never a
> merge.

| Track | PR | Rounds (of {{max_rounds}}) | Final verdict | No-progress? | Blocker |
|---|---|---|---|---|---|
| {{A}} | {{#}} | {{r}} | {{clean / blocked / not-attempted-review}} | {{yes / no}} | {{— / cap / no-progress / restack-conflict / unsafe}} |
```

- [ ] **Step 2c: Extend the decision-log examples**

In `## Decision log`, replace the example line:

```markdown
- {{stamp}} — {{decision (debug fix / auto-address round / BLOCKED / blocker recorded / track ended / increment not-attempted) + rationale}}
```

with:

```markdown
- {{stamp}} — {{decision (debug fix / auto-address round / sweep review round / sweep PR clean / sweep blocked: cap | no-progress | restack-conflict | unsafe / BLOCKED / blocker recorded / track ended / increment not-attempted) + rationale}}
```

- [ ] **Step 3: Run the checks, confirm they pass**

Run:
```bash
grep -q "## Review sweep" skills/woostack-execute-overnight/references/report-template.md && echo "sweep-section: ok"
grep -q "| Track | Increment | Status | Branch / PR | Review | Auto-address rounds | Sweep |" skills/woostack-execute-overnight/references/report-template.md && echo "sweep-column: ok"
grep -q "sweep review round" skills/woostack-execute-overnight/references/report-template.md && echo "decision-log: ok"
```
Expected: `sweep-section: ok`, `sweep-column: ok`, `decision-log: ok`.

- [ ] **Step 4: Confirm Review-sweep sits between Per-increment and Decision log**

Run: `grep -n "^## \(Per-increment\|Review sweep\|Decision log\)" skills/woostack-execute-overnight/references/report-template.md`
Expected: the three headings in that order (Per-increment < Review sweep < Decision log).

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(execute-overnight): report-template Review sweep section + sweep column"
```

### Task 4: Full presence/consistency verification sweep (AC coverage)

**Files:** none (verification only)

- [ ] **Step 1: Run the full AC presence-check suite**

Run:
```bash
S=skills/woostack-execute-overnight/SKILL.md
R=skills/woostack-execute-overnight/references/report-template.md
# AC1 — sweep phase: per-track, post-implementation, bottom-up, additive
grep -q "Post-implementation review sweep" "$S" && grep -q "before advancing to the" "$S" && grep -q "base of the stack upward" "$S" && grep -q "additive" "$S" && echo "AC1 ok"
# AC2 — per-PR loop end to end, full review, worktree, no merge, scoped restack
grep -q "per-PR worktree" "$S" && grep -q "woostack-review <PR#> --full" "$S" && grep -q "woostack-address-comments --auto" "$S" && grep -q "Restack this track's own stack" "$S" && grep -q "never merge" "$S" -i && echo "AC2 ok"
# AC3 — clean defined via verdict + threads, self-PR downgrade named
grep -q "STATUS_LINE" "$S" && grep -q "zero unresolved threads" "$S" && grep -q "verdict, not the GitHub event" "$S" && grep -q "downgrades the posted event" "$S" && echo "AC3 ok"
# AC4 — backstop: cap + no-progress + config key + halt mapping
grep -q "max_rounds" "$S" && grep -q "No-progress guard" "$S" && grep -q "overnight.review_sweep.max_rounds" "$S" && grep -q "blocker → halt" "$S" && echo "AC4 ok"
# AC5 — both drivers; halt by reference (not restated); never-auto-approve
grep -q "both drivers" "$S" -i && grep -q "Tracks & halt policy](#tracks--halt-policy)" "$S" && grep -q "never-auto-approve set" "$S" && echo "AC5 ok"
# AC6 — report + description
grep -q "## Review sweep" "$R" && grep -q "Sweep |" "$R" && grep -q "post-implementation review sweep that drives each increment PR to a clean review" "$S" && grep -q "Drive the stack to clean review" "$S" && echo "AC6 ok"
```
Expected: `AC1 ok`, `AC2 ok`, `AC3 ok`, `AC4 ok`, `AC5 ok`, `AC6 ok` (each line prints only if its conjuncts all match).

- [ ] **Step 2: Consistency — config key spelled identically everywhere**

Run: `grep -rho "overnight.review_sweep.max_rounds" skills/woostack-execute-overnight/ | sort -u`
Expected: a single line `overnight.review_sweep.max_rounds` (no spelling drift across the SKILL).

- [ ] **Step 3: Consistency — halt policy referenced by link, not duplicated**

Run: `grep -c "End the current track" skills/woostack-execute-overnight/SKILL.md`
Expected: `1` — the halt policy is defined once (in `## Tracks & halt policy`); the sweep links to it (`#tracks--halt-policy`) rather than restating it.

- [ ] **Step 4: No broken intra-doc anchors introduced**

Run: `grep -n "#post-implementation-review-sweep\|#tracks--halt-policy" skills/woostack-execute-overnight/SKILL.md`
Expected: both anchor references resolve to real `## Post-implementation review sweep` / `## Tracks & halt policy` headings (eyeball the heading lines from Task 1 Step 4 / above).

- [ ] **Step 5: Commit (if any verification surfaced a fix; else no-op)**

```bash
# Only if Steps 1–4 revealed a gap you had to patch:
gt modify -c -m "fix(execute-overnight): close sweep verification gap"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every §1–§6 design point maps to a task: sweep phase/placement (Task 1), per-PR loop incl. worktree/full-review/restack-scope/clean-def (Task 1), backstop + config (Task 1), halt reuse (Task 1), override-#2 augment + terminal/constraints/description (Task 2), report template (Task 3).
- [ ] **AC coverage** — spec §7 AC1–AC6 each map to a presence check in Task 4 Step 1 (plus per-task checks in Tasks 1–3); AC's happy/error/edge conjuncts are encoded in the grep conjunctions.
- [ ] **No placeholders** — every edit step carries the exact final markdown block and every verify step an exact command + expected output; the only `{{...}}` are inside report-**template** literal content (intended).
- [ ] **Type consistency** — the config key `overnight.review_sweep.max_rounds`, the anchor `#post-implementation-review-sweep`, the verdict tokens (`clean` / `blocked` / `not-attempted-review`), and `STATUS_LINE` are spelled identically across SKILL, plan, and report-template.

> woostack plan conventions (kept): frontmatter-free; opens with the `**Source:**` line; filename mirrors the spec basename (`2026-06-11-overnight-review-sweep.md`, the spec's date); no required-sub-skill banner; no-runner "failing test" = a concrete `grep`/`bash -n` with exact expected output.
