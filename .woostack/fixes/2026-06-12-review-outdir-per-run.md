---
type: fix
status: in-review
branch: fix/review-outdir-per-run
---

# Fix: woostack-review local default OUTDIR is per-project, so same-repo reviews share (and contaminate) one artifact tree

> Issue: [howarewoo/woostack#321](https://github.com/howarewoo/woostack/issues/321).
> Stacked on `fix/resolve-outdir-zsh` (PR #317 / issue #314) — both edit
> `skills/woostack-review/scripts/resolve-outdir.sh` and
> `skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh`, so basing on
> `main` would conflict. #317 is the very PR whose review surfaced this incident.

## 1. Root Cause

Traced directly through the review scripts (no `woostack-debug` subprocess
needed — the data flow is short and the contaminating value is visible in two
files).

**Defect A — the default OUTDIR is keyed per-*project*, not per-*run*.**
`skills/woostack-review/scripts/resolve-outdir.sh` derives the default OUTDIR
from a hash of the git toplevel only:

```sh
_wr_hash="$(printf '%s' "$WOOSTACK_ROOT" | { sha1sum 2>/dev/null || shasum; } | cut -c1-12)"
OUTDIR="${WOOSTACK_ROOT}/.woostack/tmp/pr-review-${_wr_hash}"   # or /tmp/pr-review-<hash>
```

Two reviews of the **same** repo — sequential or concurrent — resolve to the
**same** directory. The header comment even admits it: *"Two concurrent runs of
the SAME repo still share one dir (rare; accepted)."* The incident showed it is
not only the concurrent case: a prior run that left artifacts behind (aborted,
or simply not cleaned) contaminates the next run of the same repo.

**Defect B — the in-flight guard warns but then continues with the
contaminated directory.** `skills/woostack-review/scripts/prefetch.sh` (issue
#48 guard) refuses to `rm -rf` an OUTDIR that already holds in-flight
`findings.*`, but the refusal path only *skips the wipe* and falls through:

```sh
if [ "${WOO_REVIEW_FRESH:-}" != "1" ] && compgen -G "$OUTDIR/findings.*" >/dev/null 2>&1; then
  echo "::warning::prefetch: $OUTDIR holds in-flight findings.* — refusing rm -rf ..." >&2
else
  rm -rf "$OUTDIR"
fi
mkdir -p "$OUTDIR"        # <-- execution CONTINUES here either way
```

So when the guard fires, prefetch leaves the stale `findings.*` / `receipt.*`
in place **and proceeds** to merge / validation / posting. In the incident, the
receipt gate then saw 14 angle receipts (and stale `site/` findings) for a PR
that only enabled six angles.

**Evidence (issue #321 incident):** `/woostack-review 317` selected the
per-project dir, warned it held in-flight artifacts, continued, and the receipt
gate saw stale receipts from an unrelated review. A clean rerun with an explicit
per-run `OUTDIR` (`.woostack/tmp/pr-review-317-20260612172146-54329`) produced
six receipts and the correct result.

**Why CI is unaffected by Defect A:** `action.yml` pins `OUTDIR=/tmp/pr-review`
via `GITHUB_ENV` (line 119) *before any script runs*, and the runner is
ephemeral (fresh dir per job). So `resolve-outdir.sh`'s unset-OUTDIR branch never
executes in CI. The fix must keep this true.

**CI relies on the guard's warn-and-continue (load-bearing — Defect B
constraint).** `action.yml`'s `Prefetch` step has **no mode gate**, so
`prefetch.sh` re-runs on *every* action invocation, including the matrix
`review` and `validate` jobs. In the `validate` / `validate-prosecutor` job
(`reusable-review.yml` lines 210–221) the workflow **downloads the
`findings-*` artifacts into `/tmp/pr-review/` BEFORE re-invoking the action**, so
when prefetch re-runs there `findings.*` are already present — and the current
`::warning::` + skip-wipe + **continue** is exactly what preserves those
downloaded artifacts for the validator to read. A blanket `exit 1` on a refused
wipe would abort every CI validate job. Therefore the hard-stop must be **gated
to local runs only** (`GITHUB_ACTIONS != true`); in CI the warn-and-preserve
path stays. (CI `review`-mode jobs download only the *base* artifacts — no
`findings.*` yet — so prefetch there wipes and re-fetches as today; the guard
does not fire.)

**Why a deterministic per-project hash was chosen originally:**
`resolve-outdir.sh` is *sourced independently* by ~13 review scripts. A
deterministic hash guarantees every independent source resolves to the same
path even if a host forgets to export `OUTDIR`. Per-run uniqueness inherently
needs a non-deterministic suffix (timestamp + pid), which **relies on the
existing export contract**: the orchestrator resolves OUTDIR once (or captures
prefetch's printed `outdir=<path>`) and exports it to every sub-agent and
downstream stage (SKILL.md §"OUTDIR override" / line 244). That contract already
exists and is already mandated — the per-run default leans on it instead of on
recompute-determinism. CI keeps the deterministic form because OUTDIR is pinned.

## 2. Proposed Fix

Two minimal, targeted changes plus doc/test alignment. **Scope: `woostack-review`
only.** The sibling `woostack-address-comments` copy of `resolve-outdir.sh` is
left per-project — it has no `rm -rf`, no stale-`findings.*` merge step, and thus
no contamination hazard, and making it non-deterministic would risk recompute
drift for a host that does not export OUTDIR. The shared zsh regression test is
decoupled so each copy is asserted against its own intended shape.

**A. `skills/woostack-review/scripts/resolve-outdir.sh` — per-run default off CI.**
When `OUTDIR` is unset:
- If `GITHUB_ACTIONS = true` → keep the stable per-project
  `pr-review-<hash>` form (dead path in practice since CI pins OUTDIR, but it
  keeps CI's hardcoded `/tmp/pr-review-*` assumptions byte-stable as
  defense-in-depth).
- Otherwise (local) → mint a per-**run** dir:
  `pr-review-<hash>-<YYYYmmddHHMMSS>-<pid>`. The `<hash>` keeps per-repo
  isolation; `<timestamp>-<pid>` keeps per-run isolation. Still placed under
  `${WOOSTACK_ROOT}/.woostack/tmp/` when `.woostack` exists (pre-approved
  workspace perms), else `/tmp`.
- An explicit `OUTDIR` override is still honored verbatim (sandbox dirs, tests,
  the CI pin) — the `if [ -z "${OUTDIR:-}" ]` guard is unchanged.

Update the file header comment to describe the per-run-local / per-project-CI
behavior and the export contract it depends on.

**B. `skills/woostack-review/scripts/prefetch.sh` — local hard-stop on a refused
wipe; CI keeps preserve-and-continue.** Split the guard branch on
`GITHUB_ACTIONS`:
- **Local (`GITHUB_ACTIONS != true`)** → `::error::` + `exit 1` (unless
  `WOO_REVIEW_FRESH=1`). A directory that already holds in-flight `findings.*`
  must **abort the run**, not proceed to merge/validation/posting with stale
  artifacts. With Defect A fixed, a genuinely fresh local run lands on an empty
  per-run dir and never trips this guard — so it becomes a true safety net that
  only fires on a real anomaly (an explicit reused `OUTDIR`, or a stray
  mid-swarm prefetch re-run), exactly where aborting is correct.
- **CI (`GITHUB_ACTIONS = true`)** → keep the current `::warning::` +
  skip-wipe + **continue**. The validate job legitimately pre-populates
  `$OUTDIR` with downloaded `findings.<angle>.json` / `receipt.<angle>.json`
  before re-invoking the action; wiping or aborting would destroy the matrix
  output the validator must read (issue #48). `WOO_REVIEW_FRESH=1` still forces a
  wipe in both contexts.

**C. Docs — `skills/woostack-review/SKILL.md` Stage 1.**
Update the "Default is per-project" / "Atomic state" notes and the inline code
comments (lines ~231–251, ~271) to state: local default is now **per-run**; CI
pins OUTDIR; the orchestrator MUST capture prefetch's printed `outdir=<path>`
and export `OUTDIR` verbatim to every sub-agent (no recompute drift); a refused
wipe now hard-stops.

**D. Test — `skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh`.**
Decouple the per-copy OUTDIR assertion so it still pins the #314 zsh regression
(WOOSTACK_ROOT resolves, no empty-hash) while accommodating the new shapes:
- review copy (local, no CI) → asserts OUTDIR *starts with* `pr-review-<hash>-`
  (per-run suffix present) and is **not** the bare per-project form;
- address-comments copy → unchanged exact `/tmp/pr-review-<hash>`.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests** (new file
  `skills/woostack-review/scripts/tests/test-resolve-outdir-per-run.sh`)
  - Test 1 (per-run isolation): in a throwaway git repo with `OUTDIR` unset and
    `GITHUB_ACTIONS` unset, source `resolve-outdir.sh` in **two separate
    processes**; assert the two resolved `OUTDIR` values **differ** and both
    start with `pr-review-<hash>-` (where `<hash>` = sha1-12 of the toplevel).
    Pre-fix this fails — both resolve to the identical `pr-review-<hash>`.
  - Test 2 (explicit override preserved): with `OUTDIR=/some/explicit/dir`
    exported, assert `resolve-outdir.sh` leaves it exactly as-is.
  - Test 3 (CI determinism): with `GITHUB_ACTIONS=true` and `OUTDIR` unset,
    assert OUTDIR is the stable `pr-review-<hash>` form (no timestamp/pid
    suffix), so CI's hardcoded paths stay byte-stable.
  - Test 4 (prefetch guard, three cases) — seed an `OUTDIR` (explicit, so
    `resolve-outdir.sh` is bypassed) containing a `findings.bugs.json`:
    - **4a local hard-stop**: `GITHUB_ACTIONS` unset, `WOO_REVIEW_FRESH` unset →
      `prefetch.sh` exits **non-zero**, stderr contains `::error::` /
      "contaminated", and the seeded `findings.bugs.json` is **not** deleted.
      The guard is at the top of the script (before any `gh` call), so no fake
      env is needed.
    - **4b CI preserve**: `GITHUB_ACTIONS=true`, `WOO_REVIEW_FRESH` unset,
      `PR_NUMBER` unset, `GITHUB_REPOSITORY=owner/repo` → prefetch must **not**
      abort at the guard: it preserves `findings.bugs.json` (still present),
      emits the `::warning::` preserve message (not `::error::`), and reaches the
      no-PR `emit_skip` (exit 0). Note: `WOO_REVIEW_TEST_MODE=1` is **refused**
      under `GITHUB_ACTIONS=true` (prefetch lines 74–77), so this case uses the
      no-PR early-skip path rather than the fake-data hooks.
    - **4c FRESH wipe**: `GITHUB_ACTIONS` unset, `WOO_REVIEW_FRESH=1`, full
      `WOO_REVIEW_TEST_MODE=1` + `WOO_REVIEW_FAKE_*` harness (as
      `test-prefetch-flat-memory.sh`) → prefetch wipes the seeded
      `findings.bugs.json` and completes (`Prefetch complete`), proving FRESH
      still forces a wipe with no hard-stop.
- [x] **Step 2: Apply the minimal fix**
  - Edit `skills/woostack-review/scripts/resolve-outdir.sh` per Proposed Fix A
    (per-run-local / per-project-CI branch + header comment).
  - Edit `skills/woostack-review/scripts/prefetch.sh` per Proposed Fix B
    (`::error::` + `exit 1` on refused wipe unless `WOO_REVIEW_FRESH=1`).
  - Update `skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh`
    per Proposed Fix D (decoupled per-copy assertion).
  - Update `skills/woostack-review/SKILL.md` Stage 1 notes per Proposed Fix C.
- [x] **Step 3: Verification**
  - Run the new test, the updated zsh test, and the existing prefetch test:
    ```
    bash skills/woostack-review/scripts/tests/test-resolve-outdir-per-run.sh
    bash skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh
    bash skills/woostack-review/scripts/tests/test-prefetch-flat-memory.sh
    ```
    All pass.
  - `shellcheck skills/woostack-review/scripts/resolve-outdir.sh skills/woostack-review/scripts/prefetch.sh` clean (or no new findings vs. baseline).
  - Confirm the address-comments copy is untouched:
    `git diff --name-only` lists no `woostack-address-comments` path.

## Notes / out of scope

- **Local-diff mode also benefits.** The no-PR "local mode" path
  (SKILL.md ~line 271) sources `resolve-outdir.sh` then does its own
  `rm -rf "$OUTDIR"; mkdir -p`. With per-run defaults each local-diff run now
  gets a fresh dir too, so that self-wipe becomes harmless rather than a reuse
  of a shared tree. No code change needed there.
- **`.woostack/tmp/` accumulation (follow-up, not this fix).** Per-run dirs
  accumulate one-per-review under `.woostack/tmp/` (gitignored — `.gitignore`
  line 60 — so nothing is committed). A reaper for old `pr-review-*` dirs is a
  reasonable later enhancement but is out of scope here; the issue asks only for
  isolation, not cleanup.
- **Stacking.** This fix is stacked on `fix/resolve-outdir-zsh` (PR #317).
  Deviation from the literal worktree-contract base (`resolve-base.sh` → `main`)
  is deliberate: #317 is unmerged and edits the same two files, so basing on
  `main` would guarantee a conflict.
