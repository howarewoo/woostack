---
type: plan
source: .woostack/specs/2026-07-03-status-html-board.md
status: done
branch: feature/status-html-board
---

**Source:** [[specs/2026-07-03-status-html-board]]

# woostack-status HTML board Implementation Plan

**Goal:** Every `status.sh` run additionally renders a self-contained HTML board to gitignored `.woostack/visuals/status-board.html` and opens it in the browser, deterministically and script-native, with the terminal table and CI behavior unchanged.

**Architecture:** One derivation, two renders. The existing per-spec loop in `skills/woostack-status/scripts/status.sh` accumulates escaped HTML rows alongside the text rows; after the terminal print, `render_html()` substitutes marker lines in a bundled `board-template.html` (awk `index()`-and-print — never `gsub`, so `&`/`\` in field values survive literally) and `maybe_open()` applies the suppression rules (`--no-open`, `WOO_STATUS_NO_OPEN=1`, `CI`/`GITHUB_ACTIONS`). All failure paths degrade to a one-line notice and exit 0.

**Tech Stack:** bash 3.2-compatible shell, awk, self-contained HTML/CSS (no JS frameworks, no CDN, `prefers-color-scheme` for dark mode). Test harness: existing `scripts/tests/` bash tests (`assert.sh`, auto-discovered by `run-tests.sh`).

## Increment 1: HTML board render (template + script + tests + doc lockstep)

> One independently shippable PR (~450 LOC) — its own Graphite-stacked branch on top of the spec+plan PR. Docs move in lockstep with behavior (repo hard constraint), so they ship in the same increment.

### Task 1: bundled board template

**Files:**
- Create: `skills/woostack-status/scripts/board-template.html`
- Test: `skills/woostack-status/scripts/tests/test-html-board.sh` (first assertions; file grows in Task 2)

- [x] **Step 1: Write the failing test**

  Create `skills/woostack-status/scripts/tests/test-html-board.sh`:

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "$DIR/tests/assert.sh"
  ST="$DIR/status.sh"
  TPL="$DIR/board-template.html"

  # --- template contract ---
  TPL_OUT="$(cat "$TPL" 2>/dev/null || echo MISSING)"
  assert_not_contains "$TPL_OUT" "MISSING" "board-template.html exists"
  for m in WOO_ROWS WOO_HIDDEN_ROWS WOO_FLAGS WOO_FOOTER WOO_GENERATED; do
    assert_contains "$TPL_OUT" "<!--$m-->" "template carries $m marker"
  done
  assert_not_contains "$TPL_OUT" "http://" "template is offline (no http URLs)"
  assert_not_contains "$TPL_OUT" "https://" "template is offline (no https URLs)"
  assert_contains "$TPL_OUT" "prefers-color-scheme" "template has dark-mode styles"

  finish
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-status/scripts/tests/test-html-board.sh`
  Expected: FAIL — `board-template.html exists` (template not yet written).

- [x] **Step 3: Minimal implementation**

  Create `skills/woostack-status/scripts/board-template.html`. Each `WOO_*` marker sits on its own line (the renderer replaces whole marker lines):

  ```html
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>woostack status board</title>
  <style>
    :root {
      --bg: #ffffff; --fg: #1a1a1a; --muted: #6b7280; --line: #e5e7eb;
      --warn-bg: #fef3c7; --warn-fg: #92400e; --bar-bg: #e5e7eb; --bar-fg: #2563eb;
      --chip-open: #dbeafe; --chip-merged: #dcfce7; --chip-closed: #fee2e2;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #111418; --fg: #e5e7eb; --muted: #9ca3af; --line: #2a2f36;
        --warn-bg: #3a2e10; --warn-fg: #fbbf24; --bar-bg: #2a2f36; --bar-fg: #3b82f6;
        --chip-open: #1e3a5f; --chip-merged: #14432a; --chip-closed: #4c1d1d;
      }
    }
    body { margin: 2rem auto; max-width: 72rem; padding: 0 1rem; background: var(--bg);
           color: var(--fg); font: 14px/1.5 -apple-system, "Segoe UI", sans-serif; }
    h1 { font-size: 1.3rem; margin: 0 0 .25rem; }
    .gen { color: var(--muted); font-size: .8rem; margin-bottom: 1.25rem; }
    table { border-collapse: collapse; width: 100%; }
    th, td { text-align: left; padding: .5rem .75rem; border-bottom: 1px solid var(--line);
             vertical-align: top; }
    th { color: var(--muted); font-size: .75rem; text-transform: uppercase;
         letter-spacing: .05em; }
    .badge { display: inline-block; padding: .1rem .5rem; border-radius: 999px;
             font-size: .75rem; border: 1px solid var(--line); white-space: nowrap; }
    .p-draft, .p-hardened { background: var(--bar-bg); }
    .p-approved, .p-planning, .p-ready { background: var(--chip-open); }
    .p-executing { background: var(--warn-bg); color: var(--warn-fg); }
    .p-in-review { background: var(--chip-open); }
    .p-done { background: var(--chip-merged); }
    .p-abandoned, .p-unknown { background: var(--chip-closed); }
    .bar { background: var(--bar-bg); border-radius: 3px; height: 6px; width: 6rem;
           margin-top: .3rem; }
    .bar > div { background: var(--bar-fg); border-radius: 3px; height: 6px; }
    .chip { display: inline-block; padding: 0 .4rem; border-radius: 4px; font-size: .75rem;
            margin-right: .25rem; white-space: nowrap; }
    .c-open { background: var(--chip-open); } .c-merged { background: var(--chip-merged); }
    .c-closed { background: var(--chip-closed); } .c-partial { background: var(--warn-bg); }
    .flags { background: var(--warn-bg); color: var(--warn-fg); border-radius: 6px;
             padding: .75rem 1rem; margin-top: 1.5rem; }
    .flags h2 { font-size: .9rem; margin: 0 0 .5rem; }
    .flags ul { margin: 0; padding-left: 1.2rem; }
    details { margin-top: 1.5rem; }
    summary { cursor: pointer; color: var(--muted); }
    .footer { color: var(--muted); font-size: .8rem; margin-top: 1.5rem;
              white-space: pre-line; }
  </style>
  </head>
  <body>
  <h1>woostack status board</h1>
  <div class="gen">
  <!--WOO_GENERATED-->
  </div>
  <table>
  <thead><tr><th>Spec</th><th>Phase</th><th>Plan</th><th>Increments</th><th>Owner</th><th>Age</th><th>Next</th></tr></thead>
  <tbody>
  <!--WOO_ROWS-->
  </tbody>
  </table>
  <!--WOO_FLAGS-->
  <details>
  <summary>done / abandoned</summary>
  <table>
  <tbody>
  <!--WOO_HIDDEN_ROWS-->
  </tbody>
  </table>
  </details>
  <div class="footer">
  <!--WOO_FOOTER-->
  </div>
  </body>
  </html>
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-status/scripts/tests/test-html-board.sh`
  Expected: PASS — `7 passed, 0 failed` (template assertions only).

- [x] **Step 5: Commit**
  ```bash
  # First commit in the increment (from the increment worktree):
  gt create -m "feat: add woostack-status board HTML template"
  ```

### Task 2: status.sh HTML render, escaping, opener suppression

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh` (arg parse ~line 15-24; per-spec loop ~line 303-380; footer ~line 383-391)
- Test: `skills/woostack-status/scripts/tests/test-html-board.sh` (extend)

- [x] **Step 1: Write the failing tests**

  Append to `skills/woostack-status/scripts/tests/test-html-board.sh` **above** the `finish` line (helpers mirror `test-status.sh`):

  ```bash
  OUT=""; CODE=0
  run_status() {
    local wd="$1"; shift
    set +e
    OUT="$(WOO_DIR="$wd" WOO_STATUS_NO_OPEN=1 bash "$ST" "$@" 2>&1)"
    CODE=$?
    set -e
  }

  mkspec() {
    mkdir -p "$1/specs"
    printf -- '---\nname: %s\ntype: spec\nstatus: %s\ndate: 2026-06-01\nbranch: %s\n---\n# %s\nbody\n' \
      "$2" "$3" "$4" "$2" > "$1/specs/2026-06-01-$2.md"
  }

  mkplan() {
    local n status branch
    status="${6:-planning}"
    branch="${7:-feature/$2}"
    mkdir -p "$1/plans"
    { printf -- '---\ntype: plan\nsource: .woostack/specs/%s\nstatus: %s\nbranch: %s\n---\n\n**Source:** .woostack/specs/%s\n\n' "$3" "$status" "$branch" "$3"
      n=1; while [ "$n" -le "$4" ]; do echo "- [x] done $n"; n=$((n+1)); done
      n=1; while [ "$n" -le "$5" ]; do echo "- [ ] todo $n"; n=$((n+1)); done
    } > "$1/plans/2026-06-01-$2.md"
  }

  # --- AC1 happy: HTML written, rows mirror the board; footer names the path ---
  r="$(mktemp -d)/.woostack"
  mkspec "$r" alpha draft feature/alpha
  mkspec "$r" zulu done feature/zulu
  mkplan "$r" zulu 2026-06-01-zulu.md 3 0 done
  run_status "$r"
  assert_exit 0 "$CODE" "AC1: exits 0"
  HTML="$(cat "$r/visuals/status-board.html" 2>/dev/null || echo MISSING)"
  assert_not_contains "$HTML" "MISSING" "AC1: status-board.html written"
  assert_contains "$HTML" "alpha" "AC1: in-flight row present"
  assert_contains "$HTML" 'class="badge p-draft"' "AC1: phase badge rendered"
  assert_contains "$HTML" "harden the spec (woostack-harden)" "AC1: next action rendered"
  assert_contains "$OUT" "board: $r/visuals/status-board.html" "AC2: footer names HTML path"
  # done row lives in the hidden (details) section, after WOO_HIDDEN marker area
  assert_contains "$HTML" "zulu" "AC1: done row present in HTML without --all"
  assert_contains "$HTML" "3/3" "AC1: plan progress rendered"

  # --- AC2: terminal table unchanged (spot checks match test-status.sh expectations) ---
  assert_contains "$OUT" "SPEC" "AC2: table header intact"
  assert_contains "$OUT" "draft" "AC2: phase cell intact"
  assert_contains "$OUT" "1 done" "AC2: footer counts intact"

  # --- AC2 edge: --all changes terminal only; HTML identical ---
  # (strip the generated-at line: a minute-boundary tick between runs must not flake this)
  H1="$(grep -v 'generated ' "$r/visuals/status-board.html")"
  run_status "$r" --all
  H2="$(grep -v 'generated ' "$r/visuals/status-board.html")"
  assert_eq "$H2" "$H1" "AC2: HTML identical with and without --all"

  # --- AC3: interpolated fields are HTML-escaped ---
  r="$(mktemp -d)/.woostack"
  mkspec "$r" 'a<b>&"c"' draft 'feature/x&y'
  run_status "$r"
  HTML="$(cat "$r/visuals/status-board.html")"
  assert_contains "$HTML" 'a&lt;b&gt;&amp;&quot;c&quot;' "AC3: name escaped"
  assert_not_contains "$HTML" 'a<b>' "AC3: no raw markup from fields"

  # --- AC1 error: visuals/ uncreatable -> notice, exit 0, no crash ---
  r="$(mktemp -d)/.woostack"
  mkspec "$r" alpha draft feature/alpha
  touch "$r/visuals"   # file squats on the dir path
  run_status "$r"
  assert_exit 0 "$CODE" "AC1 error: exits 0 when visuals uncreatable"
  assert_contains "$OUT" "HTML board skipped" "AC1 error: notice printed"
  assert_contains "$OUT" "SPEC" "AC1 error: terminal board still printed"

  # --- AC1 edge: zero specs -> no HTML ---
  empty="$(mktemp -d)"
  run_status "$empty/.woostack"
  assert_contains "$OUT" "no specs or fixes found" "AC1 edge: empty guidance unchanged"
  [ ! -e "$empty/.woostack/visuals/status-board.html" ] \
    && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "  FAIL: AC1 edge: no HTML for empty workspace"; }

  # --- AC4: opener invoked once by default; suppressed by flag/env/CI ---
  stub="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho "$1" >> "$OPEN_LOG"\n' > "$stub/open"
  chmod +x "$stub/open"; cp "$stub/open" "$stub/xdg-open"
  r="$(mktemp -d)/.woostack"
  mkspec "$r" alpha draft feature/alpha
  LOG="$(mktemp)"
  set +e
  WOO_DIR="$r" OPEN_LOG="$LOG" PATH="$stub:$PATH" CI= GITHUB_ACTIONS= WOO_STATUS_NO_OPEN= \
    bash "$ST" >/dev/null 2>&1
  set -e
  assert_eq "$(wc -l < "$LOG" | tr -d ' ')" "1" "AC4: opener invoked exactly once by default"
  assert_contains "$(cat "$LOG")" "status-board.html" "AC4: opener got the board path"
  for supp in "--no-open" "ENV" "CI" "GHA"; do
    : > "$LOG"
    set +e
    case "$supp" in
      --no-open) WOO_DIR="$r" OPEN_LOG="$LOG" PATH="$stub:$PATH" CI= GITHUB_ACTIONS= WOO_STATUS_NO_OPEN= bash "$ST" --no-open >/dev/null 2>&1 ;;
      ENV)  WOO_DIR="$r" OPEN_LOG="$LOG" PATH="$stub:$PATH" CI= GITHUB_ACTIONS= WOO_STATUS_NO_OPEN=1 bash "$ST" >/dev/null 2>&1 ;;
      CI)   WOO_DIR="$r" OPEN_LOG="$LOG" PATH="$stub:$PATH" CI=1 GITHUB_ACTIONS= WOO_STATUS_NO_OPEN= bash "$ST" >/dev/null 2>&1 ;;
      GHA)  WOO_DIR="$r" OPEN_LOG="$LOG" PATH="$stub:$PATH" CI= GITHUB_ACTIONS=true WOO_STATUS_NO_OPEN= bash "$ST" >/dev/null 2>&1 ;;
    esac
    set -e
    assert_eq "$(wc -l < "$LOG" | tr -d ' ')" "0" "AC4: opener suppressed ($supp)"
    [ -s "$r/visuals/status-board.html" ] && PASS=$((PASS+1)) \
      || { FAIL=$((FAIL+1)); echo "  FAIL: AC4: HTML still written ($supp)"; }
  done

  # --- AC5: gh degradation mirrored in HTML footer ---
  r="$(mktemp -d)/.woostack"
  mkspec "$r" alpha draft feature/alpha
  set +e
  OUT="$(WOO_DIR="$r" WOO_STATUS_NO_OPEN=1 WOOSTACK_GH=/nonexistent-gh bash "$ST" 2>&1)"
  set -e
  HTML="$(cat "$r/visuals/status-board.html")"
  assert_contains "$HTML" "gh not found" "AC5: gh notice in HTML footer"
  assert_contains "$HTML" "pass --fetch to refresh" "AC5: fetch note in HTML footer"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-status/scripts/tests/test-html-board.sh`
  Expected: FAIL — `AC1: status-board.html written` and subsequent assertions (script writes no HTML yet).

- [x] **Step 3: Minimal implementation**

  Modify `skills/woostack-status/scripts/status.sh`:

  a. Arg parse (after `DO_FETCH=0`, ~line 16): add `NO_OPEN=0`; in the `case` add `--no-open) NO_OPEN=1 ;;` and update the usage line to `usage: status.sh [--all] [--fetch] [--no-open]`.

  b. Helpers (after `row_has()`, ~line 245):

  ```bash
  html_escape() {
    local s="$1"
    s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
    printf '%s' "$s"
  }

  render_html() {
    local tpl="$HERE/board-template.html" out="$WOO_DIR/visuals/status-board.html"
    if [ ! -f "$tpl" ]; then
      printf '\nnote: board template missing (%s) - HTML board skipped' "$tpl"; return 1
    fi
    if ! mkdir -p "$WOO_DIR/visuals" 2>/dev/null; then
      printf '\nnote: cannot create %s/visuals - HTML board skipped' "$WOO_DIR"; return 1
    fi
    WOO_HTML_ROWS="$html_rows" WOO_HTML_HIDDEN="$html_hidden_rows" \
    WOO_HTML_FLAGS="$html_flags" WOO_HTML_FOOTER="$(html_escape "$html_footer")" \
    WOO_HTML_GENERATED="$(html_escape "generated $(date '+%Y-%m-%d %H:%M') · $(pwd)")" \
    awk '
      index($0, "<!--WOO_ROWS-->")        { printf "%s", ENVIRON["WOO_HTML_ROWS"]; next }
      index($0, "<!--WOO_HIDDEN_ROWS-->") { printf "%s", ENVIRON["WOO_HTML_HIDDEN"]; next }
      index($0, "<!--WOO_FLAGS-->")       { printf "%s", ENVIRON["WOO_HTML_FLAGS"]; next }
      index($0, "<!--WOO_FOOTER-->")      { printf "%s", ENVIRON["WOO_HTML_FOOTER"]; next }
      index($0, "<!--WOO_GENERATED-->")   { printf "%s", ENVIRON["WOO_HTML_GENERATED"]; next }
      { print }
    ' "$tpl" > "$out" 2>/dev/null || {
      printf '\nnote: cannot write %s - HTML board skipped' "$out"; return 1
    }
    printf '\nboard: %s' "$out"
    return 0
  }

  maybe_open() {
    local f="$1"
    [ "$NO_OPEN" -eq 1 ] && return 0
    [ "${WOO_STATUS_NO_OPEN:-}" = "1" ] && return 0
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then return 0; fi
    if command -v open >/dev/null 2>&1 && open "$f" 2>/dev/null; then return 0; fi
    if command -v xdg-open >/dev/null 2>&1 && xdg-open "$f" >/dev/null 2>&1; then return 0; fi
    printf '\nnote: no opener found - open %s manually' "$f"
  }
  ```

  c. Accumulators (next to `rows=""`, ~line 256): add `html_rows=""`, `html_hidden_rows=""`, `html_flags=""`, `html_footer=""`.

  d. Increment-chip accumulation: in the `prs_for_spec` read loop (~line 305-312) add, after the `inc_parts=` line:

  ```bash
      inc_html="${inc_html}<span class=\"chip c-$mark\">#$num $mark</span>"
  ```

  and initialize `inc_html=""` beside `inc_cell="-"` (~line 303). In the `prs_for_branch` fallback loop (~line 315-321), after `inc_cell="#$num (partial)"` add `inc_html="<span class=\"chip c-partial\">#$num (partial)</span>"`.

  e. HTML row build: immediately after the text `row=` assignment (~line 370-372):

  ```bash
    bar=""
    if [ "$total" -gt 0 ]; then
      bar="<div class=\"bar\"><div style=\"width:${frac}%\"></div></div>"
    fi
    [ -n "$inc_html" ] || inc_html="$(html_escape "$inc_cell")"
    hrow="<tr><td>$(html_escape "$name")</td><td><span class=\"badge p-$eff\">$(html_escape "$eff")</span></td><td>$(html_escape "$plan_cell")$bar</td><td>$inc_html</td><td>$(html_escape "$owner")</td><td>$(html_escape "$agecell")</td><td>$(html_escape "$(next_action "$eff" "$done" "$total" "$merged" "$prcount" "$f")")</td></tr>"$'\n'
  ```

  In the phase `case` right below, mirror the text-row routing: `done`/`abandoned` append `hrow` to `html_hidden_rows`; every other phase appends to `html_rows`. Unlike the text rows, the hidden append is unconditional (no `SHOW_ALL` check) — the HTML always carries the collapsed section.

  f. Flags + footer HTML, before the final print block (~line 383):

  ```bash
  if [ -n "$FLAGS" ]; then
    html_flags="<div class=\"flags\"><h2>! FLAGS</h2><ul>"
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      html_flags="${html_flags}<li>$(html_escape "${ln#  ! }")</li>"
    done <<< "$FLAGS"
    html_flags="${html_flags}</ul></div>"
  fi
  html_footer="$done_count done · $abandoned_count abandoned"
  [ "$gh_missing" -eq 1 ] && html_footer="$html_footer"$'\n'"note: gh not found - PR/increment/owner data omitted for PR-phase rows"
  [ "$DO_FETCH" -eq 0 ] && html_footer="$html_footer"$'\n'"note: PR-less branch data may be stale; pass --fetch to refresh"
  ```

  g. Wire-up: between the existing fetch note and the final `printf '\n'` (~line 389-390):

  ```bash
  if render_html; then
    maybe_open "$WOO_DIR/visuals/status-board.html"
  fi
  ```

  (`render_html`'s non-zero return only skips the opener; the script still reaches `exit 0`.)

- [x] **Step 4: Run the tests, confirm they pass**
  Run: `bash skills/woostack-status/scripts/tests/test-html-board.sh && bash skills/woostack-status/scripts/tests/run-tests.sh`
  Expected: PASS on the new file **and** every pre-existing `test-status.sh` assertion (AC2), `0 failed` overall.

- [x] **Step 5: Syntax check on bash 3.2 shape**
  Run: `bash -n skills/woostack-status/scripts/status.sh && /bin/bash --version | head -1`
  Expected: no output from `-n`; version line confirms the system bash 3.2 used by the tests.

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "feat: render woostack-status board to HTML and open it"
  ```

### Task 3: doc lockstep (SKILL.md + site concepts.mdx)

**Files:**
- Modify: `skills/woostack-status/SKILL.md` (Commands ~line 25-29; Procedure step 1 ~line 33-44; Hard constraints ~line 72-75)
- Modify: `site/content/docs/concepts.mdx:97`

- [x] **Step 1: Write the failing check**
  Run: `grep -c 'no-open' skills/woostack-status/SKILL.md; grep -c 'HTML' site/content/docs/concepts.mdx`
  Expected: FAIL — both greps print `0` (docs not yet updated).

- [x] **Step 2: Update SKILL.md**

  In `## Commands`, add:

  ```markdown
  - `/woostack-status --no-open` — write the HTML board but do not open a browser (also
    suppressed by `WOO_STATUS_NO_OPEN=1` or a `CI`/`GITHUB_ACTIONS` environment).
  ```

  In Procedure step 1, after the "read-only and exits 0" sentence, add:

  ```markdown
  Alongside the terminal table the script writes a self-contained HTML render of the same
  board to the gitignored `.woostack/visuals/status-board.html` and opens it in the default
  browser (suppressed in CI or via `--no-open`); the terminal output remains the canonical
  narration surface.
  ```

  Reword the Hard constraint:

  ```markdown
  - **No committed status file.** Print to the terminal; never write `STATUS.md` or any
    *tracked* snapshot. The gitignored `.woostack/visuals/status-board.html` render is the
    sanctioned exception — it is a presentation target, never a source of truth.
  ```

- [x] **Step 3: Update site/content/docs/concepts.mdx line 97**

  Change:

  ```markdown
  - `status.sh` reads the specs, plans, and PR state and prints the feature board, so the agent never
  ```

  to:

  ```markdown
  - `status.sh` reads the specs, plans, and PR state, prints the feature board, and writes a
    gitignored HTML render of it, so the agent never
  ```

  (preserve the sentence's continuation on the following line unchanged).

- [x] **Step 4: Verify**
  Run: `grep -c 'no-open' skills/woostack-status/SKILL.md; grep -c 'HTML render' site/content/docs/concepts.mdx; pnpm -C site build >/dev/null && echo SITE_OK`
  Expected: both greps ≥ 1; `SITE_OK`.

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs: document woostack-status HTML board and --no-open"
  ```

## Plan Checks

- **Spec coverage** — §4/§5 approach → Task 1 (template) + Task 2 (render/escape/open); §6 error handling → Task 2 render_html/maybe_open degrade paths + AC1-error/AC4 tests; §7 AC1–AC5 → named assertions in `test-html-board.sh`; SKILL.md + concepts.mdx lockstep → Task 3.
- **AC coverage** — AC1 happy/error/edge, AC2 happy/edge, AC3 happy/edge (metacharacters exercised via the `&`-bearing branch and escaped name), AC4 happy/error(no-opener path is the `maybe_open` notice)/edge, AC5 happy/edge each map to an assertion; N/A cases match the spec's declared N/As.
- **No placeholders** — complete template, complete functions, exact commands and expected outputs throughout.
- **Type consistency** — variable names (`html_rows`, `html_hidden_rows`, `html_flags`, `html_footer`, `inc_html`, `NO_OPEN`) used identically across tasks; bash 3.2-safe constructs only (`${var//}`, `<<<`, no arrays added).
- **Angle coverage** — security: unconditional `html_escape` on every interpolated field (AC3); observability: every degrade path prints a notice, nothing swallowed; architecture: template/renderer/opener are three small units, one derivation feeding two renders; tests: one failing-test step per AC. `api`/`database`/`i18n` untouched — skipped per the pre-flight skip rule.
