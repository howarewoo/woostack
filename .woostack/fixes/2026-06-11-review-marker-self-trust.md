---
type: fix
status: in-review
branch: fix/review-marker-self-trust
---

# Fix: local `/woostack-review` writes an incremental SHA marker but never trusts its own on re-run

Source issue: [howarewoo/woostack#273](https://github.com/howarewoo/woostack/issues/273)

## 1. Root Cause

Two separate mechanisms govern the incremental SHA watermark; only the **read** side is bot-gated, so a local review trusts no marker it ever wrote.

- **Write side (CI *and* local).** `skills/woostack-review/prompts/_header.md:172` embeds `<!-- woostack-review:sha=${HEAD_SHA} -->` into **every** posted review body. A local review is posted under the human's own `gh` login.
- **Read side (bot-only).** `skills/woostack-review/scripts/prefetch.sh:251-261` resolves `LAST_SHA` from prior review bodies, but the jq filter (line 255) trusts a marker only when its author matches `BOT_NAME_PATTERN` (`claude|openai|gemini|opencode`, hardcoded at line 64):

  ```
  | select(.login | test("^(" + $bots + ")"; "i"))
  | select(.body | test("<!-- woo-?stack-review:sha=[a-f0-9]+ -->"))
  ```

A local review authored by e.g. `howarewoo` fails the bot filter → the marker is ignored → `LAST_SHA=""` → `prefetch.sh:278` logs `Marker: none` → the incremental branch at line 371 (`[ -n "$LAST_SHA" ]`) is never taken → `gh pr diff` full path (line 410-411). Every local re-review is a full re-review.

**Why the bot gate exists (and why it is CI-only):** `prefetch.sh:240-249` — in CI any PR collaborator could post a review with a forged `sha=` marker pointing *past* their own malicious commits, narrowing the next incremental window to skip them. Trusting only bot-authored markers blocks that forge. That threat is a CI / untrusted-third-party concern: locally the user runs the review with their own token, reviewing as themselves — there is no other party forging against them.

**Evidence:** confirmed by reading the code — the filter rejects every non-bot login; the write site embeds the marker unconditionally; the logged `Marker: none` in the issue matches the empty-`LAST_SHA` full-diff path.

**Gotcha (distill at fix end):** local review *writes* a watermark on every run, but the trust gate was CI-shaped (bot-author-only) — a write/read trust asymmetry. Self-trust must be gated on *not-in-CI* to stay forge-safe.

## 2. Proposed Fix

Widen the marker-trust gate to: **bot-authored OR (local-run AND authored-by-self)**, gating self-trust on `GITHUB_ACTIONS != "true"`.

Extract the marker-trust resolution into a single-authority helper, matching the repo idiom — `resolve-root.sh`, `resolve-model.sh`, `resolve-outdir.sh` are all extracted and unit-tested, whereas the current inline jq is untestable in isolation. The TDD failing-test-first kernel needs a reachable unit, and a single authority keeps the test and the production filter from drifting.

- **New `skills/woostack-review/scripts/resolve-marker.sh`** — owns the marker-trust jq. Reads the `gh --json reviews` JSON on stdin; args `$1=BOT_NAME_PATTERN`, `$2=ME` (authenticated gh login, lowercased; `''` disables self-trust), `$3=LOCAL` (`1` when not in CI, else `0`). Emits the trusted SHA or empty. The widened filter:

  ```
  | select((.login | test("^(" + $bots + ")"; "i"))
           or ($local == "1" and $me != "" and (.login | ascii_downcase) == $me))
  | select(.body | test("<!-- woo-?stack-review:sha=[a-f0-9]+ -->"))
  ```

  Preserves the legacy `woo-?stack` read alias and the `^`-anchored bot pattern unchanged.

- **`skills/woostack-review/scripts/prefetch.sh:251-261`** — replace the inline jq with: resolve `AUTH_LOGIN` (`gh api user --jq .login`, lowercased, only when `GITHUB_ACTIONS != "true"`) and `LOCAL_RUN`, then pipe `REVIEWS_JSON` through `resolve-marker.sh`. In CI, `LOCAL_RUN=0` makes the self-clause dead → behavior identical to today (bot-only); `AUTH_LOGIN` is not even fetched.

- **`skills/woostack-review/SKILL.md`** (Incremental Mode section) — document that local runs now honor their own marker, gated on not-in-CI + author==self; a *different* local reviewer or any CI third-party falls back to full review; `--full` / `incremental: off` escape hatches unchanged.

**Safety:** anti-forge preserved — only markers authored *as you* on a *local* run are newly trusted; CI is untouched; a different local reviewer mismatches `$me` and degrades to full.

### Hardening — resolved questions

- **`gh api user` fails locally (no/expired auth):** `AUTH_LOGIN=""`; the filter's `$me != ""` clause makes the self-branch dead → falls back to full review. Safe by construction (use `|| true`).
- **Case sensitivity:** GitHub logins are case-insensitive. Lowercase both sides — `tr '[:upper:]' '[:lower:]'` on `AUTH_LOGIN`, `ascii_downcase` on the review login inside jq.
- **CI is provably unchanged:** when `GITHUB_ACTIONS == "true"`, `LOCAL_RUN=0`, the self-clause `($local == "1" and …)` is dead, and `AUTH_LOGIN` is not even fetched → byte-for-byte the current bot-only behavior. This is what test case 4 pins.
- **"No new commits" skip (`prefetch.sh:362`) now fires on a local re-run with no new pushes** (`LAST_SHA == HEAD_SHA` → `skip=true`). This is *intended* — it is the cheaper local loop the issue asks for; previously a local re-run always full-reviewed. Document it in SKILL.md; `--full` still forces a pass.
- **Bot-comment re-run guard (`prefetch.sh:269-296`) is intentionally NOT widened.** It counts only bot-authored comments (`TOTAL_BOT_COMMENTS`) to suppress auto-re-runs in CI; local runs are explicit user requests, so a human self-review never trips it. Leaving it bot-only is correct and keeps scope tight.
- **Single copy.** `woostack-address-comments` has no marker reader (verified — only `resolve-root.sh` is twinned). `resolve-marker.sh` lives once under `skills/woostack-review/scripts/`.
- **Helper interface:** reviews JSON on **stdin** (mirrors the current `printf '%s' "$REVIEWS_JSON" | jq …` shape); trust knobs as positional args. Pure jq, no `gh` dependency → unit-testable without network.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test (Red).**
  Add `skills/woostack-review/scripts/tests/test-resolve-marker.sh` (modeled on `test-resolve-model.sh`; source `skills/woostack-init/scripts/tests/assert.sh`). It pipes fake `{"reviews":[…]}` JSON into `resolve-marker.sh` and asserts the resolved SHA. Cases:
  1. bot-authored marker + `LOCAL=0` (CI) → returns the SHA *(preserves CI behavior)*.
  2. self-authored marker + `LOCAL=1`, `ME==author` → returns the SHA *(the fix — fails before Step 2, the Red)*.
  3. third-party-authored marker + `LOCAL=1`, `ME != author` → empty *(anti-forge)*.
  4. self/non-bot-authored marker + `LOCAL=0` (CI) → empty *(CI never self-trusts)*.
  5. malformed / absent marker → empty *(silent fallback)*.
  6. legacy `woo-stack-review:sha=` alias + trusted author → returns the SHA *(read-alias intact)*.
  Run it first and confirm it fails (the helper does not yet exist).

- [x] **Step 2: Apply the minimal fix (Green).**
  - Create `skills/woostack-review/scripts/resolve-marker.sh` with the widened jq filter above (header comment documenting the trust contract: bot OR local-self, CI-gated, anti-forge rationale, legacy alias).
  - Edit `prefetch.sh:251-261`: compute `AUTH_LOGIN` (only when `GITHUB_ACTIONS != "true"`) and `LOCAL_RUN`, replace the inline jq with a call to `resolve-marker.sh` (invoke via `$(dirname "${BASH_SOURCE[0]}")/resolve-marker.sh`, consistent with lines 35-37). Keep the surrounding trust-rationale comment, updated to mention the local self-trust clause.
  - Make `resolve-marker.sh` executable.
  - Re-run Step 1's test → green.

- [x] **Step 3: Document the behavior.**
  Update `skills/woostack-review/SKILL.md` Incremental Mode section (lines 50-67):
  - Amend the line 58 sentence ("scans **bot-authored** prior review bodies …") to: scans bot-authored markers, **plus — on a local (not-in-CI) run — a marker authored by the gh user running the review**; a different local reviewer or any CI third-party still falls back to full (anti-forge intact).
  - Amend the line 65 "no new commits" note to call out that this skip now also fires on a **local** re-run with no new pushes (the cheaper local loop); `--full` / `incremental: off` still force a pass.

- [x] **Step 4: Verification.**
  - `bash skills/woostack-review/scripts/tests/test-resolve-marker.sh` → all pass.
  - Re-run the existing review test suite to confirm no regression: `for t in skills/woostack-review/scripts/tests/test-*.sh; do bash "$t"; done` (or the repo's documented runner).
  - `bash -n skills/woostack-review/scripts/prefetch.sh skills/woostack-review/scripts/resolve-marker.sh` (syntax).
  - Optional sanity: pipe a fake bot-marker reviews JSON through `prefetch.sh` in `WOO_REVIEW_TEST_MODE=1` is out of scope (prefetch hits live `gh` after the marker step); the unit test on `resolve-marker.sh` is the authority.
