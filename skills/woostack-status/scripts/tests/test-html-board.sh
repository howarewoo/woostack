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
assert_contains "$TPL_OUT" ".source-linear" "template styles the Linear backend source label"
assert_contains "$TPL_OUT" "<th>Feature</th>" "template uses a backend-neutral feature heading"

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
# done row lives in the hidden (details) section
assert_contains "$HTML" "zulu" "AC1: done row present in HTML without --all"
assert_contains "$HTML" "3/3" "AC1: plan progress rendered"

# --- AC2: terminal table unchanged (spot checks match test-status.sh expectations) ---
assert_contains "$OUT" "FEATURE" "AC2: backend-neutral table header intact"
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

# --- AC3: flags block also escapes untrusted fields (a bogus status name embeds the spec name in a flag) ---
r2="$(mktemp -d)/.woostack"
mkspec "$r2" 'x<y>' bogus feature/xy
run_status "$r2"
HTML2="$(cat "$r2/visuals/status-board.html")"
assert_contains "$HTML2" 'x&lt;y&gt;' "AC3: flags block escapes the name"
assert_not_contains "$HTML2" '<li>x<y>' "AC3: flags block has no raw markup"

# --- AC1 error: board template missing -> notice, exit 0, no HTML written ---
tmpd="$(mktemp -d)"
cp -R "$DIR" "$tmpd/scripts"
rm -f "$tmpd/scripts/board-template.html"
r3="$(mktemp -d)/.woostack"
mkspec "$r3" alpha draft feature/alpha
set +e
ARTIFACTS="$DIR/../../woostack-init/scripts/artifacts"
OUT3="$(WOO_DIR="$r3" WOO_STATUS_NO_OPEN=1 \
  WOOSTACK_BACKEND_RESOLVER="$ARTIFACTS/resolve-backend.sh" \
  WOOSTACK_MARKDOWN_ADAPTER="$ARTIFACTS/markdown.sh" \
  WOOSTACK_LINEAR_ADAPTER="$ARTIFACTS/linear.sh" \
  bash "$tmpd/scripts/status.sh" 2>&1)"
CODE3=$?
set -e
assert_exit 0 "$CODE3" "AC1 error: exits 0 when board template missing"
assert_contains "$OUT3" "board template missing" "AC1 error: template-missing notice printed"
assert_file_absent "$r3/visuals/status-board.html" "AC1 error: no HTML written when template missing"

# --- AC1 error: visuals/ uncreatable -> notice, exit 0, no crash ---
r="$(mktemp -d)/.woostack"
mkspec "$r" alpha draft feature/alpha
touch "$r/visuals"   # file squats on the dir path
run_status "$r"
assert_exit 0 "$CODE" "AC1 error: exits 0 when visuals uncreatable"
assert_contains "$OUT" "HTML board skipped" "AC1 error: notice printed"
assert_contains "$OUT" "FEATURE" "AC1 error: terminal board still printed"

# --- AC1 edge: zero specs -> no HTML ---
empty="$(mktemp -d)"
run_status "$empty/.woostack"
assert_contains "$OUT" "no specs or fixes found" "AC1 edge: empty guidance unchanged"
assert_file_absent "$empty/.woostack/visuals/status-board.html" "AC1 edge: no HTML for empty workspace"

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
  assert_file_exists "$r/visuals/status-board.html" "AC4: HTML still written ($supp)"
done

# --- AC1 edge: all rows done/abandoned -> visible table carries a placeholder row ---
r6="$(mktemp -d)/.woostack"
mkspec "$r6" omega done feature/omega
run_status "$r6"
HTML6="$(cat "$r6/visuals/status-board.html")"
assert_contains "$HTML6" "All specs are done or abandoned" "AC1 edge: empty visible table gets placeholder"
assert_contains "$HTML6" "omega" "AC1 edge: done row still in hidden section"

# --- AC1: multi-PR increment chips accumulate (one chip per PR, mixed states) ---
r5="$(mktemp -d)/.woostack"
mkspec "$r5" multi in-review feature/multi
ghstub="$(mktemp -d)"
cat > "$ghstub/gh" <<'GHEOF'
#!/usr/bin/env bash
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
  cat <<'JSON'
[{"number":11,"state":"OPEN","headRefName":"feature/multi-2","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","url":"https://github.com/o/r/pull/11","body":"Spec: .woostack/specs/2026-06-01-multi.md"},
 {"number":10,"state":"MERGED","headRefName":"feature/multi-1","author":{"login":"a"},"updatedAt":"2026-06-01T00:00:00Z","url":"https://github.com/o/r/pull/10","body":"Spec: .woostack/specs/2026-06-01-multi.md"},
 {"number":9,"state":"CLOSED","headRefName":"feature/multi-0","author":{"login":"a"},"updatedAt":"2026-05-30T00:00:00Z","url":"https://github.com/o/r/pull/9","body":"Spec: .woostack/specs/2026-06-01-multi.md"}]
JSON
else
  echo "[]"
fi
GHEOF
chmod +x "$ghstub/gh"
set +e
WOO_DIR="$r5" WOO_STATUS_NO_OPEN=1 WOOSTACK_GH="$ghstub/gh" bash "$ST" >/dev/null 2>&1
set -e
HTML5="$(cat "$r5/visuals/status-board.html")"
assert_contains "$HTML5" '<a class="chip c-open" href="https://github.com/o/r/pull/11" target="_blank" rel="noopener noreferrer">#11 open</a>' "AC1: open PR chip is a GitHub link"
assert_contains "$HTML5" '<a class="chip c-merged" href="https://github.com/o/r/pull/10" target="_blank" rel="noopener noreferrer">#10 merged</a>' "AC1: merged PR chip is a GitHub link"
assert_contains "$HTML5" '<a class="chip c-closed" href="https://github.com/o/r/pull/9" target="_blank" rel="noopener noreferrer">#9 closed</a>' "AC1: closed PR chip is a GitHub link"

# --- AC1: branch-only PR lookup renders the partial chip in HTML ---
r8="$(mktemp -d)/.woostack"
mkspec "$r8" fallback ready feature/fallback
mkplan "$r8" fallback 2026-06-01-fallback.md 0 5 ready feature/fallback
ghstub2="$(mktemp -d)"
cat > "$ghstub2/gh" <<'GHEOF'
#!/usr/bin/env bash
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
  case "$*" in
    *"--head feature/fallback"*)
      cat <<'JSON'
[{"number":77,"state":"OPEN","headRefName":"feature/fallback","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","url":"https://github.com/o/r/pull/77","body":"no spec trailer"}]
JSON
      ;;
    *) echo "[]" ;;
  esac
else
  echo "[]"
fi
GHEOF
chmod +x "$ghstub2/gh"
set +e
WOO_DIR="$r8" WOO_STATUS_NO_OPEN=1 WOOSTACK_GH="$ghstub2/gh" bash "$ST" >/dev/null 2>&1
set -e
HTML8="$(cat "$r8/visuals/status-board.html")"
assert_contains "$HTML8" '<a class="chip c-partial" href="https://github.com/o/r/pull/77" target="_blank" rel="noopener noreferrer">#77 (partial)</a>' "AC1: partial PR chip is a GitHub link"

# --- AC1: a PR with no url degrades to a plain (unlinked) chip ---
r9="$(mktemp -d)/.woostack"
mkspec "$r9" nourl in-review feature/nourl
ghstub3="$(mktemp -d)"
cat > "$ghstub3/gh" <<'GHEOF'
#!/usr/bin/env bash
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
  cat <<'JSON'
[{"number":42,"state":"OPEN","headRefName":"feature/nourl","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-nourl.md"}]
JSON
else
  echo "[]"
fi
GHEOF
chmod +x "$ghstub3/gh"
set +e
WOO_DIR="$r9" WOO_STATUS_NO_OPEN=1 WOOSTACK_GH="$ghstub3/gh" bash "$ST" >/dev/null 2>&1
set -e
HTML9="$(cat "$r9/visuals/status-board.html")"
assert_contains "$HTML9" '<span class="chip c-open">#42 open</span>' "AC1: url-less PR falls back to an unlinked chip"
assert_not_contains "$HTML9" '<a class="chip' "AC1: no anchor chip when url absent"

# --- AC4 edge: openers present but failing -> "no opener found" note, HTML still written ---
r7="$(mktemp -d)/.woostack"
mkspec "$r7" alpha draft feature/alpha
failstub="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexit 1\n' > "$failstub/open"
chmod +x "$failstub/open"; cp "$failstub/open" "$failstub/xdg-open"
set +e
OUT7="$(WOO_DIR="$r7" PATH="$failstub:$PATH" CI= GITHUB_ACTIONS= WOO_STATUS_NO_OPEN= bash "$ST" 2>&1)"
CODE7=$?
set -e
assert_exit 0 "$CODE7" "AC4 edge: exits 0 when no opener works"
assert_contains "$OUT7" "no opener found" "AC4 edge: fallback note printed"
assert_file_exists "$r7/visuals/status-board.html" "AC4 edge: HTML still written when opener fails"

# --- AC5: gh degradation mirrored in HTML footer ---
r="$(mktemp -d)/.woostack"
mkspec "$r" alpha draft feature/alpha
set +e
OUT="$(WOO_DIR="$r" WOO_STATUS_NO_OPEN=1 WOOSTACK_GH=/nonexistent-gh bash "$ST" 2>&1)"
set -e
HTML="$(cat "$r/visuals/status-board.html")"
assert_contains "$HTML" "gh not found" "AC5: gh notice in HTML footer"
assert_contains "$HTML" "pass --fetch to refresh" "AC5: fetch note in HTML footer"

assert_contains "$(cat "$DIR/tests/run-tests.sh")" "WOO_STATUS_NO_OPEN" "test runner suppresses the opener globally"

finish
