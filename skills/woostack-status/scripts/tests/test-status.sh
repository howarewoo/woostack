#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
ST="$DIR/status.sh"

OUT=""
CODE=0

run_status() {
  local wd="$1"; shift
  set +e
  OUT="$(WOO_DIR="$wd" bash "$ST" "$@" 2>&1)"
  CODE=$?
  set -e
}

mkspec() {
  mkdir -p "$1/specs"
  printf -- '---\nname: %s\ntype: spec\nstatus: %s\ndate: 2026-06-01\nbranch: %s\n---\n# %s\nbody\n' \
    "$2" "$3" "$4" "$2" > "$1/specs/2026-06-01-$2.md"
}

mkplan() {
  local n
  mkdir -p "$1/plans"
  { printf '# %s Plan\n\n**Source:** .woostack/specs/%s\n\n' "$2" "$3"
    n=1; while [ "$n" -le "$4" ]; do echo "- [x] done $n"; n=$((n+1)); done
    n=1; while [ "$n" -le "$5" ]; do echo "- [ ] todo $n"; n=$((n+1)); done
  } > "$1/plans/2026-06-01-$2.md"
}

mk_fake_gh() {
  mkdir -p "$1/bin"
  cat > "$1/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"--head"*) printf '%s' "${FAKE_GH_HEAD_JSON:-${FAKE_GH_JSON:-[]}}" ;;
  *"pr list"*) printf '%s' "${FAKE_GH_JSON:-[]}" ;;
  *) printf '[]' ;;
esac
EOF
  chmod +x "$1/bin/gh"
}

empty="$(mktemp -d)"
run_status "$empty/.woostack"
assert_contains "$OUT" "no specs found" "empty state prints guidance"
assert_exit 0 "$CODE" "empty state exits 0"

r="$(mktemp -d)/.woostack"
mkspec "$r" alpha draft feature/alpha
mkspec "$r" bravo hardened feature/bravo
mkspec "$r" charlie approved feature/charlie
printf '<html></html>' > "$r/specs/2026-05-31-orphan-design.html"
run_status "$r"
assert_contains "$OUT" "alpha" "alpha row present"
assert_contains "$OUT" "draft" "alpha phase shown"
assert_contains "$OUT" "run grill-me" "draft next-action"
assert_contains "$OUT" "get spec approval" "hardened next-action"
assert_contains "$OUT" "writing-plans" "approved next-action"
assert_not_contains "$OUT" "orphan-design" "html spec is ignored"

p="$(mktemp -d)/.woostack"
mkspec "$p" delta planning feature/delta
mkplan "$p" delta 2026-06-01-delta.md 3 7
run_status "$p"
assert_contains "$OUT" "3/10" "plan progress counted"
legacy="$(mktemp -d)/.woostack"
mkspec "$legacy" legacy planning feature/legacy
mkdir -p "$legacy/plans"
printf '# Legacy Plan\n\n- [x] done\n- [ ] todo\n' > "$legacy/plans/2026-06-01-legacy.md"
run_status "$legacy"
assert_contains "$OUT" "1/2" "legacy same-slug plan resolves without Source"
mkspec "$p" echo planning feature/echo
run_status "$p"
assert_contains "$OUT" "echo" "echo row present"
assert_contains "$OUT" "no plan" "0-plan flagged"
mkplan "$p" echo 2026-06-01-echo.md 1 1
cp "$p/plans/2026-06-01-echo.md" "$p/plans/2026-06-02-echo-dup.md"
run_status "$p"
assert_contains "$OUT" "2 plans" "duplicate-plan flagged"

g="$(mktemp -d)"; mk_fake_gh "$g"
b="$(mktemp -d)/.woostack"
mkspec "$b" foxtrot executing feature/foxtrot
mkplan "$b" foxtrot 2026-06-01-foxtrot.md 4 6
export FAKE_GH_JSON='[{"number":190,"state":"OPEN","headRefName":"feature/foxtrot","author":{"login":"dana"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-foxtrot.md"}]'
PATH="$g/bin:$PATH" run_status "$b"
assert_contains "$OUT" "in-review" "open PR => in-review via truth table"
unset FAKE_GH_JSON

mkspec "$b" golf executing feature/golf
mkplan "$b" golf 2026-06-01-golf.md 2 8
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$b"
assert_contains "$OUT" "golf" "golf present"
assert_exit 0 "$CODE" "band compute exits 0"

exec_repo="$(mktemp -d)"
( cd "$exec_repo" && git -c user.email=t@t -c user.name=Tess init -q && git checkout -qb main )
mkspec "$exec_repo/.woostack" sierra planning feature/sierra
mkplan "$exec_repo/.woostack" sierra 2026-06-01-sierra.md 1 2
( cd "$exec_repo" && git add -A && git -c user.email=t@t -c user.name=Tess commit -qm "add sierra plan" )
( cd "$exec_repo" && git checkout -qb feature/sierra && printf 'work\n' > work.txt && git add work.txt && git -c user.email=t@t -c user.name=Tess commit -qm "start sierra" )
( cd "$exec_repo" && FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" WOO_DIR=.woostack bash "$ST" > /tmp/sierra.out 2>&1 )
OUT="$(cat /tmp/sierra.out)"
assert_contains "$OUT" "sierra" "commit-backed planning spec rendered"
assert_contains "$OUT" "executing" "commit-backed planning spec derives executing"
assert_not_contains "$OUT" "sierra                 planning" "commit-backed planning spec does not remain planning"

h="$(mktemp -d)/.woostack"
mkspec "$h" hotel executing feature/hotel
mkplan "$h" hotel 2026-06-01-hotel.md 5 5
export FAKE_GH_JSON='[{"number":181,"state":"MERGED","headRefName":"feature/hotel-1","author":{"login":"adam"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-hotel.md"},{"number":190,"state":"OPEN","headRefName":"feature/hotel-2","author":{"login":"adam"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-hotel.md"}]'
PATH="$g/bin:$PATH" run_status "$h"
assert_contains "$OUT" "#181" "merged increment listed"
assert_contains "$OUT" "#190" "open increment listed"
unset FAKE_GH_JSON

i="$(mktemp -d)/.woostack"
mkspec "$i" india executing feature/india
mkplan "$i" india 2026-06-01-india.md 1 9
export FAKE_GH_JSON='[]'
export FAKE_GH_HEAD_JSON='[{"number":77,"state":"OPEN","headRefName":"feature/india","author":{"login":"ira"},"updatedAt":"2026-06-03T00:00:00Z"}]'
PATH="$g/bin:$PATH" run_status "$i"
assert_contains "$OUT" "#77 (partial)" "missing trailer falls back to head branch"
unset FAKE_GH_JSON FAKE_GH_HEAD_JSON

gr="$(mktemp -d)"
( cd "$gr" && git -c user.email=t@t -c user.name=Tess init -q )
mkdir -p "$gr/.woostack/specs"
printf -- '---\nname: juliet\ntype: spec\nstatus: draft\ndate: 2026-06-01\nbranch: feature/juliet\n---\nbody\n' > "$gr/.woostack/specs/2026-06-01-juliet.md"
( cd "$gr" && git add -A && GIT_AUTHOR_DATE='2026-05-20T00:00:00' GIT_COMMITTER_DATE='2026-05-20T00:00:00' \
  git -c user.email=t@t -c user.name=Tess commit -qm "add juliet spec" )
( cd "$gr" && WOOSTACK_NOW=2026-06-04 WOO_DIR=.woostack bash "$ST" > /tmp/st.out 2>&1 )
CODE=$?; OUT="$(cat /tmp/st.out)"
assert_contains "$OUT" "Tess" "pre-PR owner from spec git log"
assert_contains "$OUT" "15d" "pre-PR age from spec git log"

k="$(mktemp -d)/.woostack"; mkspec "$k" kilo executing unknown
mkplan "$k" kilo 2026-06-01-kilo.md 1 9
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$k"
assert_contains "$OUT" "branch is 'unknown'" "unknown branch flagged"

l="$(mktemp -d)/.woostack"; mkspec "$l" lima bogusphase feature/lima
mkspec "$l" mike draft feature/mike
run_status "$l"
assert_contains "$OUT" "lima" "lima still rendered"
assert_contains "$OUT" "unknown phase" "bogus phase flagged"
assert_contains "$OUT" "mike" "sibling row survives bad row"

n="$(mktemp -d)/.woostack"; mkspec "$n" november approved feature/november
export FAKE_GH_JSON='[{"number":5,"state":"OPEN","headRefName":"feature/november","author":{"login":"x"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-november.md"}]'
PATH="$g/bin:$PATH" run_status "$n"
assert_contains "$OUT" "status lags" "PR-open-but-early-phase flagged"
unset FAKE_GH_JSON

o="$(mktemp -d)/.woostack"; mkspec "$o" oscar done feature/oscar
mkplan "$o" oscar 2026-06-01-oscar.md 5 0
export FAKE_GH_JSON='[{"number":9,"state":"MERGED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"}]'
PATH="$g/bin:$PATH" run_status "$o"
assert_not_contains "$OUT" "oscar " "done hidden by default"
assert_contains "$OUT" "1 done" "done counted in footer"
PATH="$g/bin:$PATH" run_status "$o" --all
assert_contains "$OUT" "oscar" "done shown with --all"
unset FAKE_GH_JSON

oc="$(mktemp -d)/.woostack"; mkspec "$oc" oscar executing feature/oscar
mkplan "$oc" oscar 2026-06-01-oscar.md 5 0
export FAKE_GH_JSON='[{"number":9,"state":"MERGED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"},{"number":10,"state":"CLOSED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"}]'
PATH="$g/bin:$PATH" run_status "$oc"
assert_contains "$OUT" "oscar" "closed-unmerged increment keeps row visible"
assert_contains "$OUT" "executing" "closed-unmerged increment prevents done"
assert_contains "$OUT" "0 done" "closed-unmerged increment not counted done"
unset FAKE_GH_JSON

mkspec "$o" papa abandoned feature/papa
run_status "$o"
assert_contains "$OUT" "abandoned" "abandoned counted in footer"
assert_not_contains "$OUT" "papa " "abandoned hidden by default"

q="$(mktemp -d)/.woostack"; mkspec "$q" quebec executing feature/quebec
mkplan "$q" quebec 2026-06-01-quebec.md 1 9
( PATH="/usr/bin:/bin" WOO_DIR="$q" bash "$ST" > /tmp/q.out 2>&1 )
qc=$?
assert_exit 0 "$qc" "gh-absent still exits 0"
assert_contains "$(cat /tmp/q.out)" "quebec" "renders without gh"

gr2="$(mktemp -d)"
( cd "$gr2" && git -c user.email=t@t -c user.name=Tess init -q )
mkdir -p "$gr2/.woostack/specs" "$gr2/.woostack/plans"
printf '{ "status": { "staleDays": 3 } }' > "$gr2/.woostack/config.json"
printf -- '---\nname: romeo\ntype: spec\nstatus: executing\ndate: 2026-06-01\nbranch: feature/romeo\n---\nb\n' > "$gr2/.woostack/specs/2026-06-01-romeo.md"
printf '# r\n\n**Source:** .woostack/specs/2026-06-01-romeo.md\n\n- [x] a\n- [ ] b\n' > "$gr2/.woostack/plans/2026-06-01-romeo.md"
( cd "$gr2" && git add -A && GIT_AUTHOR_DATE='2026-05-30T00:00:00' GIT_COMMITTER_DATE='2026-05-30T00:00:00' \
  git -c user.email=t@t -c user.name=Tess commit -qm x )
( cd "$gr2" && WOOSTACK_NOW=2026-06-04 PATH="/usr/bin:/bin" WOO_DIR=.woostack bash "$ST" > /tmp/r.out 2>&1 )
assert_contains "$(cat /tmp/r.out)" "stale" "staleDays:3 makes 5d spec stale"

# trailer exact-match: a PR's Spec: trailer attaches only to its own spec; a look-alike
# PR (same fuzzy tokens, different spec) must NOT cross-match a sibling.
xm="$(mktemp -d)/.woostack"
mkspec "$xm" xalpha executing feature/xalpha
mkplan "$xm" xalpha 2026-06-01-xalpha.md 1 9
mkspec "$xm" xbeta executing feature/xbeta
mkplan "$xm" xbeta 2026-06-01-xbeta.md 1 9
export FAKE_GH_JSON='[{"number":300,"state":"OPEN","headRefName":"feature/xalpha","author":{"login":"z"},"updatedAt":"2026-06-03T00:00:00Z","body":"work done. Spec: .woostack/specs/2026-06-01-xalpha.md"}]'
# Real `gh pr list --head feature/xbeta` returns only xbeta-headed PRs (none here); the test
# fake would otherwise echo FAKE_GH_JSON for any --head, so pin the head query empty to model
# reality and isolate the prs_for_spec trailer match.
export FAKE_GH_HEAD_JSON='[]'
PATH="$g/bin:$PATH" run_status "$xm" --all
assert_contains "$OUT" "#300" "trailer PR is listed for its own spec"
XALPHA_ROW="$(printf '%s\n' "$OUT" | grep '^xalpha')"
XBETA_ROW="$(printf '%s\n' "$OUT" | grep '^xbeta')"
assert_contains "$XALPHA_ROW" "#300" "trailer PR attaches to its own spec (xalpha)"
assert_not_contains "$XBETA_ROW" "#300" "trailer PR does NOT cross-match the sibling spec (xbeta)"
assert_not_contains "$XBETA_ROW" "in-review" "sibling spec stays out of in-review on a look-alike PR"
unset FAKE_GH_JSON FAKE_GH_HEAD_JSON

# authored 'done' at plan 100% with no trailered PR (legacy, pre-trailer) renders done,
# not executing — an explicit terminal assertion plus a complete plan is trusted.
ld="$(mktemp -d)/.woostack"
mkspec "$ld" legdone done feature/legdone
mkplan "$ld" legdone 2026-06-01-legdone.md 4 0
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$ld"
assert_contains "$OUT" "1 done" "authored done + 100% plan + no PR counts as done"
assert_not_contains "$OUT" "legdone " "legacy done hidden by default"

finish
