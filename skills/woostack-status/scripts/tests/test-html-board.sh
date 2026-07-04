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
OUT3="$(WOO_DIR="$r3" WOO_STATUS_NO_OPEN=1 bash "$tmpd/scripts/status.sh" 2>&1)"
CODE3=$?
set -e
assert_exit 0 "$CODE3" "AC1 error: exits 0 when board template missing"
assert_contains "$OUT3" "board template missing" "AC1 error: template-missing notice printed"
[ ! -e "$r3/visuals/status-board.html" ] && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: AC1 error: no HTML written when template missing"; }

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

finish
