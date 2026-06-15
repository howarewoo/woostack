---
type: plan
source: .woostack/specs/2026-06-13-woostack-sweep.md
status: ready
branch: feature/woostack-sweep
---

**Source:** [[specs/2026-06-13-woostack-sweep]]

# woostack-sweep Implementation Plan

**Goal:** Extract the bottom-up drive-a-stack-to-clean-review loop out of `woostack-execute-overnight` into a new standalone public skill, `woostack-sweep`, that is the single source of truth and that overnight delegates to per track.

**Architecture:** Three stacked increments of skill-markdown edits. (1) Create `skills/woostack-sweep/SKILL.md` — the complete engine + standalone command surface; self-contained and shippable. (2) Register it on the public command surface (`using-woostack` routing row, `AGENTS.md` list / file map / count). (3) Rewire `woostack-execute-overnight` to delegate to it and promote the config key `overnight.review_sweep.max_rounds` → `review_sweep.max_rounds`, removing the now-duplicated loop text (both the `## Post-implementation review sweep` section and the "Drive the stack to clean review" hard-constraint bullet). Transient duplication of the loop exists across increments 1–2 and is resolved in increment 3 (intentional sequencing, not missing work — no `woostack-defer` marker applies).

**Tech Stack:** Markdown skills (no application code, no test runner). Per [woostack-tdd](../../skills/woostack-tdd/SKILL.md)'s no-runner → concrete-verification rule, every "failing test" step is a `grep` / `bash -n` assertion with exact expected output. Graphite (`gt`) for stacked PRs.

---

## Increment 1: Create the `woostack-sweep` skill (engine + standalone surface)

> One independently shippable PR — a new self-contained skill that works standalone immediately; touches no existing file. Its own Graphite-stacked branch on the spec+plan base. (A reviewer may note it duplicates overnight's sweep text; that duplication is intentional and resolved in Increment 3 — call it out in the PR body.)

### Task 1: Author `skills/woostack-sweep/SKILL.md`

**Files:**
- Create: `skills/woostack-sweep/SKILL.md`

- [x] **Step 1: Write the failing verification**

The "test" is a presence + structure assertion that must fail before the file exists:

```bash
test ! -e skills/woostack-sweep/SKILL.md && echo "ABSENT (expected pre-impl)" || echo "PRESENT"
```

- [x] **Step 2: Run it, confirm it fails (file absent)**

Run: `test ! -e skills/woostack-sweep/SKILL.md && echo "ABSENT (expected pre-impl)" || echo PRESENT`
Expected: `ABSENT (expected pre-impl)` — the skill does not yet exist.

- [x] **Step 3: Create the skill file**

Create `skills/woostack-sweep/SKILL.md` with the exact content below. (It contains no triple-backtick fences, so it is reproduced here between explicit `BEGIN`/`END` markers — copy everything strictly between them, not the markers.)

`<<<BEGIN skills/woostack-sweep/SKILL.md>>>`

    ---
    name: woostack-sweep
    description: Use to drive a stack of stacked PRs to a clean review — sweep each increment PR bottom-up (woostack-review --full → woostack-address-comments → restack this stack only → re-review), bounded by review_sweep.max_rounds plus a no-progress guard, to a clean verdict or approved-with-only-nits. Autonomous by default; stops and reports on a blocker. The single home of the review-sweep loop, reused by woostack-execute-overnight per track. Never merges.
    ---

    # woostack-sweep

    Drive a stack of stacked PRs to a **clean review**, bottom-up: for each increment PR from the
    base of the stack upward, loop `woostack-review --full` → (if not clean)
    `woostack-address-comments` → restack this stack only → re-review, until the PR is clean (no
    blocking findings + zero unresolved threads) or the bounded loop stops. This is the single home
    of woostack's **review sweep** — [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md)
    delegates to it per track; a human invokes it directly on any Graphite stack. It **never merges**.

    ## Commands

    - `/woostack-sweep` — infer the stack from the current Graphite branch (`gt log` / `gt stack`) and
      sweep every increment PR strictly **above `--base`**, bottom-up to the tip.
    - `/woostack-sweep <PR#>` — sweep the stack **containing** that PR instead of the current branch's
      stack.
    - `--base <ref|PR#>` — **exclusive** lower floor of the swept range; default the resolved trunk
      (`WOOSTACK_BASE_BRANCH`, [worktree contract](../woostack-init/references/worktrees.md) §1). A
      caller (e.g. overnight) passes a base PR/branch to exclude a docs-only base PR.
    - `--interactive` — gate each PR's address step (defer to `woostack-address-comments`' own
      per-fix gate). Default is autonomous: pass `--auto` down so the sweep never stalls per-fix.

    An unresolvable stack or an empty `--base`..tip range → report **"nothing to sweep"** and exit 0.

    ## Resolve the stack

    - **Current stack** (no `<PR#>`): the chain of branches from `--base` (exclusive) up to the
      current branch tip, via `gt log` / `gt stack`.
    - **Named `<PR#>`**: resolve the stack **containing** that PR from `gt` / `gh` metadata **without
      checking out the primary tree** ([worktree contract](../woostack-init/references/worktrees.md)
      §3 — the primary tree is never edited).
    - Map each in-range branch to its open PR (`gh pr view <branch> --json number`). A branch with
      **no open PR** is un-reviewable → **skip it + warn** (record it in the summary); never
      auto-`gt submit`, never halt the sweep for it.
    - Raw-git host (no `gt`): reconstruct the stack from git ancestry + `gh`; say so rather than
      pretend `gt` ran.

    ## The per-PR loop (bottom-up, drive-to-clean)

    For each increment PR in range, from the **base of the stack upward**, work in a **per-PR
    worktree** on the existing increment branch. If that branch is already checked out in a preserved
    worktree, reuse it; otherwise set `wt="$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>-sweep"` and
    run `git worktree add "$wt" <inc-branch>` — **no** `-b`. The **primary tree is never edited**
    ([worktree contract](../woostack-init/references/worktrees.md) §3). Export
    `WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` first (contract §5) so any
    `address-comments` memory write lands in the primary store. Then loop, up to `max_rounds` rounds
    (see Config):

    1. **Review** — `woostack-review <PR#> --full`. **Every** round is `--full` (a complete re-review
       of the whole PR), so a fix that breaks something *outside* its own diff is still caught.
    2. **Clean?** — Clean = `woostack-review`'s computed verdict has **no blocking findings**
       (`STATUS_LINE` `APPROVED` / `APPROVED WITH SUGGESTIONS`) **and** zero unresolved threads
       (checked via `gh`). Read the **verdict, not the GitHub event**: self-authored stack PRs get the
       posted event downgraded `APPROVE`→`COMMENT`, so trust `STATUS_LINE`. Clean ⇒ teardown the
       worktree, advance to the next PR up. "Clean" is **review-clean, not a merge-approval** — the
       run never merges.
    3. **Address** — otherwise run
       [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) (or interactive,
       under `--interactive`) from inside the worktree: it fixes / pushes back / replies / resolves /
       pushes (via `woostack-commit --no-pr-update`). Never force-push a protected base; never merge.
    4. **Restack this stack only** — `gt restack` then `gt submit --stack` scoped to the **current**
       stack, so the PRs above rebase onto the new tip and their rebased branches are pushed. **Never
       `gt sync` or a repo-wide restack** ([worktree contract](../woostack-init/references/worktrees.md)
       §4/§6: a repo-wide restack collides with any parallel run in flight). A restack/rebase conflict
       is a **blocker**.
    5. **Re-review** → back to step 1.

    Strictly bottom-up: a PR is driven to clean — or, at the `max_rounds` cap, to
    approved-with-only-nits — before the sweep moves up, and a fix only restacks the PRs **above** it,
    never a cleared lower PR, so each PR is reviewed exactly once on the way up.

    ## Termination backstop

    The per-PR loop is bounded — **whichever trips first**:

    - **Max rounds** — at most `max_rounds` review→address rounds per PR (default **3**; see Config).
    - **No-progress guard (blocking only)** — stop early **only while blocking findings remain** with
      no headway: a re-review returns the **same** blocking findings, **or** a round resolves **no
      blocking** thread, **or** an `address-comments` `CLARIFY` leaves a **blocking** thread open.
      **Nits never trip this guard** — while only non-blocking nits remain, keep reviewing/addressing
      them until the `max_rounds` cap.

    At either terminus **without a clean PR**, branch on the verdict (read `STATUS_LINE`, not the
    self-downgraded event):

    - **Blocking findings remain** (request-changes) → **blocker** (see Blocker & terminal state).
    - **Only nits remain** (`APPROVED` / `APPROVED WITH SUGGESTIONS`, open non-blocking threads) —
      reachable only at the `max_rounds` cap, since the guard never stops on nits → **not a blocker**:
      mark the PR `done-with-findings`, record the open nits, and **move to the next PR up**.

    ## Per-PR outcome vocabulary

    Each PR ends `clean` / `done-with-findings` (approved-with-only-nits at the cap) / `blocked`. The
    engine returns these; a caller maps them — a standalone run into the terminal summary,
    [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) into its morning-report
    table + "Needs you".

    ## Blocker & terminal state

    A **blocker** = the cap or no-progress guard reached with **blocking findings still present**, a
    `woostack-review` error/hang, a restack/rebase conflict, or an `address-comments` step that would
    touch the never-auto-approve set (destructive / secret / auth / network / ambiguous). Safety is
    never relaxed for autonomy.

    **Standalone:** on a blocker, **stop** at that PR, **leave its worktree** for inspection, and print
    a "Needs you" summary — the blocked PR + reason, plus any `done-with-findings` PRs with their open
    nits, and any no-PR branches skipped. PRs swept clean below it stay clean (no rollback). **No
    report file is written** — a human is at the terminal. A fully clean run prints **"stack swept
    clean"**; a nits-only run exits **0** with the nits listed.

    **Delegated (e.g. overnight):** the engine surfaces the blocker; the caller decides what to do with
    it. [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) leaves the worktree,
    records the blocked PR (and `not-attempted-review` above it in that track), and advances to the
    next track per its Tracks & halt policy. Overnight owns tracks, the morning report, and
    leave-on-blocker; this skill owns the loop.

    ## Config

    `review_sweep.max_rounds` in `.woostack/config.json` (positive integer, default **3**) caps the
    per-PR rounds. A non-positive / non-integer value **warns, falls back to 3, and is recorded** —
    never a refuse-to-start (a sweep-cap typo is not a doomed run). This is the **single key**;
    [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) reads the same
    `review_sweep.max_rounds`.

    ## Gate boundary

    Owns **no approval gate** — it is an autonomous engine. `--interactive` defers per-fix approval to
    `woostack-address-comments`' own gate; it is not a sweep-level gate. A protected **current** branch
    is fine — every write lands in a per-PR worktree on an increment branch, never the current branch —
    but it never force-pushes a protected base, never merges, and never edits the primary tree.

    ## Hard constraints

    - **Single home of the sweep loop.** This is the one definition of the bottom-up drive-to-clean
      loop; callers (overnight) delegate here and never restate it.
    - **Bottom-up, each PR reviewed once on the way up.** Drive a PR to clean (or
      approved-with-only-nits at the cap) before moving up; a fix restacks only the PRs above it.
    - **Read the verdict, not the event.** Clean = `STATUS_LINE` no-blocking + zero unresolved threads;
      self-authored PR events are downgraded.
    - **Restack this stack only.** `gt restack` / `gt submit --stack`; never `gt sync` / repo-wide
      restack.
    - **Bounded.** `review_sweep.max_rounds` (default 3) + no-progress guard scoped to **blocking**
      findings; nits loop to the cap; only blocking findings at the cap are a blocker.
    - **No-PR branch → skip + warn.** Never auto-submit, never halt the whole sweep for one
      un-submitted branch.
    - **Autonomous, stop on blocker.** Default `--auto`; on a blocker stop, leave the worktree, print
      the summary. Write no report file (overnight writes its own).
    - **Never merge, never force-push a protected base, never edit the primary tree, own no gate.**

`<<<END skills/woostack-sweep/SKILL.md>>>`

- [x] **Step 4: Run the structure assertions, confirm they pass**

Run:
```bash
f=skills/woostack-sweep/SKILL.md
grep -q '^name: woostack-sweep$' "$f" && \
grep -q '## Commands' "$f" && \
grep -q '/woostack-sweep <PR#>' "$f" && \
grep -q -- '--base <ref|PR#>' "$f" && \
grep -q -- '--interactive' "$f" && \
grep -q '## The per-PR loop' "$f" && \
grep -q '## Termination backstop' "$f" && \
grep -q 'clean` / `done-with-findings' "$f" && \
grep -q 'review_sweep.max_rounds' "$f" && \
grep -q 'Never merge' "$f" && echo "ALL PRESENT"
```
Expected: `ALL PRESENT`

- [x] **Step 5: Lint the frontmatter / structure**

Run: `head -4 skills/woostack-sweep/SKILL.md`
Expected: opens with `---`, `name: woostack-sweep`, a `description:` line, `---`.

- [x] **Step 6: Commit**

```bash
# first commit in this increment:
gt create -m "feat(sweep): woostack-sweep skill — single home of the drive-stack-to-clean review loop"
```

source: .woostack/specs/2026-06-13-woostack-sweep.md
---

## Increment 2: Register `woostack-sweep` on the public command surface

> One shippable PR stacked on Increment 1 — pure registration edits. `using-woostack` routing row + `AGENTS.md` list / file map / count.

### Task 1: Add the `using-woostack` routing row

**Files:**
- Modify: `skills/using-woostack/SKILL.md` (routing table, after the `woostack-execute-overnight` row)

- [x] **Step 1: Write the failing assertion**

Run: `grep -c 'woostack-sweep' skills/using-woostack/SKILL.md`
Expected: `0` (no row yet).

- [x] **Step 2: Confirm it fails**

Run: `grep -q 'woostack-sweep' skills/using-woostack/SKILL.md && echo PRESENT || echo ABSENT`
Expected: `ABSENT`

- [x] **Step 3: Insert the routing row immediately after the `woostack-execute-overnight` row**

Add this line after the `/woostack-execute-overnight …` table row (match the exact column shape of the adjacent rows):

```
| `/woostack-sweep [PR#] [--base R] [--interactive]`, drive a stack of PRs to a clean review | `woostack-sweep` |
```

- [x] **Step 4: Confirm it passes**

Run: ``grep -q '`/woostack-sweep' skills/using-woostack/SKILL.md && echo PRESENT``
Expected: `PRESENT`

- [x] **Step 5: Commit**

```bash
gt create -m "docs(using-woostack): route /woostack-sweep to the woostack-sweep skill"
```

### Task 2: Add `woostack-sweep` to `AGENTS.md` (list + file map + count)

**Files:**
- Modify: `AGENTS.md` — public-skill bullet list (after the `woostack-dream` bullet, ~line 34), the prose count ("sixteen", ~line 17; "eighteen"/"sixteen", ~line 94), and the quick file map (after the execute-overnight entry, ~line 117).

> `AGENTS.md` is the source of truth; `.claude/CLAUDE.md` is a symlink to it, so editing `AGENTS.md` updates both. The count bump is **relative** — increment whatever number the file currently states by one; do **not** also fold in `woostack-ask` / `woostack-doctor` (separate in-flight work that hasn't updated these counts on this branch). Assert *list length == spelled count*, not a hardcoded word.

- [x] **Step 1: Capture the current count + list length (the assertion baseline)**

Run:
```bash
grep -nE 'surface has [a-z]+ skills' AGENTS.md
grep -cE '^- \[`(using-)?woostack-[a-z-]+`\]\(skills/' AGENTS.md
```
Expected: prints the current count word (e.g. `sixteen`) and the current bullet count (e.g. `16`). Record both; the list must equal the spelled count, and after the edit both rise by exactly 1.

- [x] **Step 2: Confirm woostack-sweep is absent from the list**

Run: ``grep -q '^- \[`woostack-sweep`\]' AGENTS.md && echo PRESENT || echo ABSENT``
Expected: `ABSENT`

- [x] **Step 3: Add the bullet, bump the counts, add the file-map entry**

1. After the `- [`woostack-dream`](skills/woostack-dream/SKILL.md)` bullet, add:
```
- [`woostack-sweep`](skills/woostack-sweep/SKILL.md)
```
2. In the "public command/adoption surface has **N** skills" sentence, change the spelled number up by one (e.g. `sixteen` → `seventeen`).
3. In the "do not move or rename any of the **eighteen** `SKILL.md` files (the **sixteen** public …)" sentence, bump both numbers by one (`eighteen` → `nineteen`, `sixteen` → `seventeen`) — woostack-sweep is a public command skill, so it adds to both the public count and the total SKILL-file count.
4. In the quick file map, after the `woostack-execute-overnight` entry, add:
```
- Stack review-sweep engine (public command + delegated-to by execute-overnight):
  [`skills/woostack-sweep/SKILL.md`](skills/woostack-sweep/SKILL.md)
```

- [x] **Step 4: Confirm list == count and the entry resolves**

Run:
```bash
n=$(grep -cE '^- \[`(using-)?woostack-[a-z-]+`\]\(skills/' AGENTS.md)
word=$(grep -oE 'surface has [a-z]+ skills' AGENTS.md | grep -oE '[a-z]+ skills' | awk '{print $1}')
grep -q '^- \[`woostack-sweep`\]' AGENTS.md && \
test -e skills/woostack-sweep/SKILL.md && \
echo "REGISTERED — list=$n spelled=$word (must match, and = baseline+1)"
```
Expected: `REGISTERED`, with `list=` exactly one more than the Step-1 baseline and the spelled word naming that same number (e.g. `list=17 spelled=seventeen`).

- [x] **Step 5: Commit**

```bash
gt create -m "docs(agents): register woostack-sweep on the public command surface + file map"
```

---

## Increment 3: Delegate overnight to `woostack-sweep` + promote the config key

> One shippable PR stacked on Increment 2 — collapse **both** restatements of the loop in `woostack-execute-overnight` (the `## Post-implementation review sweep` section **and** the "Drive the stack to clean review" hard-constraint bullet) to a delegation, keep overnight's tracks/report/halt wrapping, and promote `overnight.review_sweep.max_rounds` → `review_sweep.max_rounds`. Resolves the transient loop duplication.

### Task 1: Collapse the `## Post-implementation review sweep` section to a delegation

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md` — the `## Post-implementation review sweep` section (the per-PR loop, Termination backstop, Halt, Config subsections, ~lines 118–209).

- [x] **Step 1: Write the de-duplication assertion (must currently fail)**

Run:
```bash
f=skills/woostack-execute-overnight/SKILL.md
grep -c 'Restack this track.s own stack\|No-progress guard (blocking only)\|### The per-PR loop' "$f"
```
Expected: a non-zero count (e.g. `3`) — overnight still restates the loop mechanics inline.

- [x] **Step 2: Confirm the duplication is present**

Run: `grep -q '### The per-PR loop (bottom-up, drive-to-clean)' skills/woostack-execute-overnight/SKILL.md && echo DUP || echo CLEAN`
Expected: `DUP`

- [x] **Step 3: Replace the whole section body**

Replace the entire `## Post-implementation review sweep` section — from its `## Post-implementation review sweep` heading through the end of the `### Config` subsection (i.e. up to but not including the next top-level heading `## Morning report`) — with the content between the markers below (copy strictly between them):

`<<<BEGIN replacement>>>`

    ## Post-implementation review sweep

    After a track's increments are all implemented and committed — and **before advancing to the next
    track** — drive that track's stack to a clean review by delegating to
    [`woostack-sweep`](../woostack-sweep/SKILL.md), the single home of the bottom-up drive-to-clean
    loop. This is **additive**: the per-increment override #2 (the `--fast` blocking-review check
    during the build) is unchanged; the sweep is a separate, thorough pass over the finished stack. It
    runs for **both drivers** and **never merges**.

    For each track, from the track tip, invoke `woostack-sweep --base <track-base-branch>`, where
    `<track-base-branch>` is the common base (the spec+plan PR branch when invoked from build, else the
    current non-protected branch HEAD). `woostack-sweep` then sweeps that track's increment PRs
    **above the base**, bottom-up, excluding the docs-only spec+plan base PR. The loop mechanics, the
    `review_sweep.max_rounds` + no-progress bounds, and the `clean` / `done-with-findings` / `blocked`
    per-PR outcomes all live in [`woostack-sweep`](../woostack-sweep/SKILL.md) — **do not restate them
    here**.

    Overnight owns the wrapping around each delegated sweep:

    - **Map outcomes into the morning report** — fold each PR's returned outcome into the
      per-increment table and the decision log; a `done-with-findings` PR's open nits go under
      **Needs you**.
    - **Blocker → halt the track** — when `woostack-sweep` ends a track's sweep on a **blocker**,
      leave its worktree in place for morning inspection, record the blocked PR (`blocked`) and every
      PR above it (`not-attempted-review`), and **advance to the next track** per
      [Tracks & halt policy](#tracks--halt-policy). Reaching the `max_rounds` cap with **only nits**
      is **not** a blocker — that PR is `done-with-findings` and the sweep moves on.

    A plan with no `## Track:` headings has one implicit track, so the default is exactly: implement
    the whole stack, then delegate one `woostack-sweep` over it. The sweep covers **increment PRs
    only** — the `--base` excludes the docs-only spec+plan base PR.

`<<<END replacement>>>`

- [x] **Step 4: Confirm the loop mechanics are gone (delegation only)**

Run:
```bash
f=skills/woostack-execute-overnight/SKILL.md
grep -q 'woostack-sweep --base' "$f" && \
grep -q '../woostack-sweep/SKILL.md' "$f" && \
! grep -q '### The per-PR loop (bottom-up, drive-to-clean)' "$f" && \
! grep -q 'Restack this track.s own stack' "$f" && echo "SECTION DELEGATED"
```
Expected: `SECTION DELEGATED`.

- [x] **Step 5: Commit**

```bash
gt create -m "refactor(overnight): delegate the review-sweep section to woostack-sweep; keep tracks/report/halt"
```

### Task 2: Collapse the "Drive the stack to clean review" hard-constraint bullet + promote the config key

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md` — the `- **Drive the stack to clean review.** …` hard-constraint bullet (~lines 260–267), which still restates the loop **and** holds the last `overnight.review_sweep.max_rounds`.
- Verify-only: `skills/woostack-init/templates/config.json` (carries no `review_sweep` key — no edit expected).

- [x] **Step 1: Find the stale key + bullet restatement (must currently match)**

Run:
```bash
f=skills/woostack-execute-overnight/SKILL.md
grep -n 'overnight\.review_sweep\.max_rounds' "$f"
grep -q 'Drive the stack to clean review' "$f" && grep -q 'gt restack`/`gt submit --stack' "$f" && echo "BULLET RESTATES LOOP"
```
Expected: one `overnight.review_sweep.max_rounds` hit (the bullet — Task 1 removed the `### Config` copy) and `BULLET RESTATES LOOP`.

- [x] **Step 2: Confirm the old key is still present**

Run: `grep -q 'overnight\.review_sweep\.max_rounds' skills/woostack-execute-overnight/SKILL.md && echo STALE || echo CLEAN`
Expected: `STALE`

- [x] **Step 3: Replace the bullet with a delegation form**

Replace the entire `- **Drive the stack to clean review.** …` bullet (the multi-line item ending `… A blocker halts only that track. Both drivers. Never merge.`) with:

```
- **Drive the stack to clean review (delegated).** After a track's increments are committed,
  delegate the post-implementation sweep to [`woostack-sweep`](../woostack-sweep/SKILL.md)
  (`woostack-sweep --base <track-base>`, one invocation per track) — it drives that track's
  increment PRs to a clean review, bounded by `review_sweep.max_rounds` (default 3). A blocker
  halts only that track; overnight maps each per-PR outcome into the morning report. Both drivers.
  Never merge.
```

- [x] **Step 4: Confirm dedup + the single-key invariant**

Run:
```bash
f=skills/woostack-execute-overnight/SKILL.md
! grep -rq 'overnight\.review_sweep\.max_rounds' skills/ && \
! grep -q 'restack' "$f" && \
grep -q 'woostack-sweep --base' "$f" && \
grep -q 'review_sweep\.max_rounds' "$f" && \
grep -q 'review_sweep\.max_rounds' skills/woostack-sweep/SKILL.md && echo "DEDUP + SINGLE KEY"
grep -c 'review_sweep' skills/woostack-init/templates/config.json
```
Expected: `DEDUP + SINGLE KEY`, then `0` — no `overnight.`-prefixed key anywhere, no `restack` restatement left in overnight, the promoted key present in both skills, and the config template untouched (the optional key isn't templated; default 3 applies when absent).

- [x] **Step 5: Commit**

```bash
gt modify -c -m "refactor(overnight): collapse the sweep hard-constraint bullet; promote key to review_sweep.max_rounds"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec section maps to a task:
  - §4 new skill / engine / command surface / config / outcomes → Increment 1.
  - §4 delegation seam (overnight, **both** the section and the hard-constraint bullet) + config promotion → Increment 3.
  - §4 registration surface → Increment 2.
  - §6 error handling (no-PR skip, exit-0, protected-OK, raw-git, bad-config) → Increment 1 SKILL body.
- [ ] **AC coverage** — AC1 (skill exists + engine) → Inc 1 Steps 4–5; AC2 (overnight delegates, no restate — section + bullet) → Inc 3 Task 1 Step 4 **and** Task 2 Step 4 (`! grep restack`); AC3 (single config key) → Inc 3 Task 2 Step 4; AC4 (standalone terminal incl. no-PR skip + exit 0) → Inc 1 SKILL body (Blocker & terminal state, Resolve the stack); AC5 (registered) → Inc 2 Step 4 of both tasks; AC6 (safety invariants) → Inc 1 Step 4 `Never merge` + Hard constraints.
- [ ] **No placeholders** — every step has the exact file, the full SKILL.md / replacement content, exact grep/`gh`/`gt` commands, and expected output.
- [ ] **Type consistency** — the per-PR outcome vocabulary (`clean` / `done-with-findings` / `blocked`), the key name `review_sweep.max_rounds`, the flag names (`--base`, `--interactive`), and the skill name `woostack-sweep` are spelled identically across the new SKILL, the overnight delegation (section + bullet), the routing row, and AGENTS.md.

> woostack plan conventions (keep them):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-13-woostack-sweep.md` (the spec's date, not today's).
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - In this no-runner target, each "failing test" step is a concrete `grep` / `bash -n` verification with exact expected output.
> - File bodies are shown between `BEGIN`/`END` markers (indented), not in fenced blocks, to avoid nested-fence corruption — copy the indented body, not the markers.
