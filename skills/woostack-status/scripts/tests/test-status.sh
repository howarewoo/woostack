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
assert_contains "$OUT" "no specs or fixes found" "empty state prints guidance"
assert_exit 0 "$CODE" "empty state exits 0"

r="$(mktemp -d)/.woostack"
mkspec "$r" alpha draft feature/alpha
mkspec "$r" bravo hardened feature/bravo
mkspec "$r" charlie approved feature/charlie
printf '<html></html>' > "$r/specs/2026-05-31-orphan-design.html"
run_status "$r"
assert_contains "$OUT" "alpha" "alpha row present"
assert_contains "$OUT" "draft" "alpha phase shown"
assert_contains "$OUT" "woostack-harden" "draft next-action"
assert_contains "$OUT" "get spec approval" "hardened next-action"
assert_contains "$OUT" "woostack-plan" "approved next-action"
assert_not_contains "$OUT" "orphan-design" "html spec is ignored"

p="$(mktemp -d)/.woostack"
mkspec "$p" delta planning feature/delta
mkplan "$p" delta 2026-06-01-delta.md 3 7
run_status "$p"
assert_contains "$OUT" "3/10" "plan progress counted"
assert_contains "$OUT" "harden the plan" "planning next-action"

# Fenced example checkboxes (embedded template / SKILL.md literals) must NOT count
# as tasks. Real: 3 done + 3 todo = 6. The 5 boxes inside the ```` fence (including
# a nested ``` block, which must not close the enclosing fence) are ignored.
fence="$(mktemp -d)/.woostack"
mkspec "$fence" echo planning feature/echo
mkdir -p "$fence/plans"
{
  printf -- '---\ntype: plan\nsource: .woostack/specs/2026-06-01-echo.md\nstatus: planning\nbranch: feature/echo\n---\n\n'
  printf -- '**Source:** .woostack/specs/2026-06-01-echo.md\n\n'
  printf -- '- [x] real done 1\n- [x] real done 2\n- [x] real done 3\n- [ ] real todo 1\n- [ ] real todo 2\n\n'
  printf -- '````markdown\n'
  printf -- '- [ ] embedded example a\n- [ ] embedded example b\n'
  printf -- '```bash\n- [ ] nested fenced c\n```\n'
  printf -- '- [ ] embedded example d\n- [ ] embedded example e\n'
  printf -- '````\n\n'
  printf -- '- [ ] real todo 3 after fence\n'
} > "$fence/plans/2026-06-01-echo.md"
run_status "$fence"
assert_contains "$OUT" "3/6" "fenced example checkboxes excluded from progress"
assert_not_contains "$OUT" "3/11" "fenced boxes not over-counted"

# A plain triple-backtick fence (the everyday variant) must also exclude its
# example boxes. Outside the fence: 2 done + 1 todo = 3. The 2 boxes inside the
# ``` block are ignored. Guards the flen=3 / `run>=flen` close path directly, so
# a regression to `run==flen` (which still passes the 4-backtick test above)
# fails here.
tick3="$(mktemp -d)/.woostack"
mkspec "$tick3" tick3 planning feature/tick3
mkdir -p "$tick3/plans"
{
  printf -- '---\ntype: plan\nsource: .woostack/specs/2026-06-01-tick3.md\nstatus: planning\nbranch: feature/tick3\n---\n\n'
  printf -- '**Source:** .woostack/specs/2026-06-01-tick3.md\n\n'
  printf -- '- [x] real done 1\n- [x] real done 2\n- [ ] real todo 1\n\n'
  printf -- '```markdown\n'
  printf -- '- [ ] example a\n- [ ] example b\n'
  printf -- '```\n'
} > "$tick3/plans/2026-06-01-tick3.md"
run_status "$tick3"
assert_contains "$OUT" "2/3" "plain 3-backtick fence excludes example checkboxes"
assert_not_contains "$OUT" "2/5" "3-backtick fenced boxes not over-counted"

# Unclosed fence (a plausible state for a mid-write or agent-authored plan):
# the opening ``` never closes, so `infence` stays 1 to EOF and every checkbox
# after it is excluded. This pins CURRENT behavior — 1 done + 1 todo before the
# fence count (1/2); the 2 real todos after the unclosed fence are swallowed.
# Footgun: a malformed plan reads MORE complete than it is (denominator shrinks).
# We characterize rather than fix it: counting post-unclosed-fence boxes would
# need EOF-buffering of every pending-fence line, not worth it for malformed
# input. If the awk ever changes, this assert makes the behavior shift visible.
nofence="$(mktemp -d)/.woostack"
mkspec "$nofence" nofence planning feature/nofence
mkdir -p "$nofence/plans"
{
  printf -- '---\ntype: plan\nsource: .woostack/specs/2026-06-01-nofence.md\nstatus: planning\nbranch: feature/nofence\n---\n\n'
  printf -- '**Source:** .woostack/specs/2026-06-01-nofence.md\n\n'
  printf -- '- [x] real done 1\n- [ ] real todo 1\n\n'
  printf -- '```markdown\n'
  printf -- '- [ ] swallowed todo a\n- [ ] swallowed todo b\n'
} > "$nofence/plans/2026-06-01-nofence.md"
run_status "$nofence"
assert_contains "$OUT" "1/2" "unclosed fence swallows trailing checkboxes (characterized)"
assert_not_contains "$OUT" "1/4" "post-unclosed-fence boxes are not counted"

# Source line as an Obsidian wikilink ([[specs/<basename>]]) resolves the plan, same as a
# bare path. The plan basename intentionally differs from the spec slug so resolution can
# only come from the **Source:** line, not the slug fallback.
wl="$(mktemp -d)/.woostack"
mkspec "$wl" wikispec planning feature/wikispec
mkdir -p "$wl/plans"
printf '# w\n\n**Source:** [[specs/2026-06-01-wikispec]]\n\n- [x] a\n- [x] b\n- [ ] c\n' > "$wl/plans/2026-06-01-wikiplan.md"
run_status "$wl"
assert_contains "$OUT" "2/3" "wikilink Source line resolves the plan"

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

# `ready` = plan hardened, 0 boxes done, ready for execution (build step 6).
rdy="$(mktemp -d)/.woostack"
mkspec "$rdy" mike ready feature/mike
mkplan "$rdy" mike 2026-06-01-mike.md 0 5 ready feature/mike
run_status "$rdy"
assert_contains "$OUT" "ready" "ready phase rendered"
assert_contains "$OUT" "open spec+plan PR, then execute" "ready next-action"
assert_not_contains "$OUT" "not a known phase" "ready is a valid phase"
ready_no_plan="$(mktemp -d)/.woostack"
mkspec "$ready_no_plan" november ready feature/november
run_status "$ready_no_plan"
assert_contains "$OUT" "no plan" "ready without plan flagged"
# `ready` is the phase where the spec+plan handoff PR is opened (conventions: the spec+plan
# PR opens before execution), so a PR existing at plan `status: ready` is expected, not
# "status lags" drift. Plan must be authored at `ready` (not the mkplan default `planning`)
# to exercise the real path.
ready_pr="$(mktemp -d)/.woostack"
mkspec "$ready_pr" oscar approved feature/oscar
mkplan "$ready_pr" oscar 2026-06-01-oscar.md 0 5 ready feature/oscar
ready_gh="$(mktemp -d)"; mk_fake_gh "$ready_gh"
export FAKE_GH_JSON='[{"number":310,"state":"OPEN","headRefName":"feature/oscar","author":{"login":"olivia"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"}]'
PATH="$ready_gh/bin:$PATH" run_status "$ready_pr"
assert_not_contains "$OUT" "status lags" "ready with spec+plan PR not flagged (PR expected at ready)"
unset FAKE_GH_JSON

# A plan still at `planning` while a PR exists *is* drift — keep that nudge.
planning_pr="$(mktemp -d)/.woostack"
mkspec "$planning_pr" papa approved feature/papa
mkplan "$planning_pr" papa 2026-06-01-papa.md 0 5 planning feature/papa
planning_gh="$(mktemp -d)"; mk_fake_gh "$planning_gh"
export FAKE_GH_JSON='[{"number":311,"state":"OPEN","headRefName":"feature/papa","author":{"login":"pat"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-papa.md"}]'
PATH="$planning_gh/bin:$PATH" run_status "$planning_pr"
assert_contains "$OUT" "status lags" "planning with open PR still flagged"
unset FAKE_GH_JSON
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
mkplan "$exec_repo/.woostack" sierra 2026-06-01-sierra.md 1 2 executing feature/sierra
( cd "$exec_repo" && git add -A && git -c user.email=t@t -c user.name=Tess commit -qm "add sierra plan" )
( cd "$exec_repo" && git checkout -qb feature/sierra && printf 'work\n' > work.txt && git add work.txt && git -c user.email=t@t -c user.name=Tess commit -qm "start sierra" )
( cd "$exec_repo" && FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" WOO_DIR=.woostack bash "$ST" > /tmp/sierra.out 2>&1 )
OUT="$(cat /tmp/sierra.out)"
assert_contains "$OUT" "sierra" "commit-backed planning spec rendered"
assert_contains "$OUT" "executing" "commit-backed planning spec derives executing"
assert_not_contains "$OUT" "sierra                 planning" "commit-backed planning spec does not remain planning"

h="$(mktemp -d)/.woostack"
mkspec "$h" hotel executing feature/hotel
mkplan "$h" hotel 2026-06-01-hotel.md 5 5 executing feature/hotel
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
mkplan "$k" kilo 2026-06-01-kilo.md 1 9 executing unknown
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
mkplan "$oc" oscar 2026-06-01-oscar.md 5 0 done feature/oscar
export FAKE_GH_JSON='[{"number":9,"state":"MERGED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"},{"number":10,"state":"CLOSED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscar.md"}]'
PATH="$g/bin:$PATH" run_status "$oc"
assert_not_contains "$OUT" "oscar " "completed plan with closed-unmerged increment resolves done (hidden by default)"
assert_contains "$OUT" "1 done" "closed-unmerged increment no longer blocks done (counted in footer)"
PATH="$g/bin:$PATH" run_status "$oc" --all
assert_contains "$OUT" "oscar" "done row shown with --all"
unset FAKE_GH_JSON

# frac<100 is the gate keeping incomplete plans out of done: the same merged+closed PR
# pair on an INCOMPLETE plan must stay executing — merged==active alone must not flip it.
oi="$(mktemp -d)/.woostack"; mkspec "$oi" partial executing feature/partial
mkplan "$oi" partial 2026-06-01-partial.md 5 3 executing feature/partial
export FAKE_GH_JSON='[{"number":30,"state":"MERGED","headRefName":"feature/partial-1","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-partial.md"},{"number":31,"state":"CLOSED","headRefName":"feature/partial-2","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-partial.md"}]'
PATH="$g/bin:$PATH" run_status "$oi"
assert_contains "$OUT" "partial" "incomplete plan with merged+closed pair stays visible"
assert_contains "$OUT" "executing" "incomplete plan with merged+closed pair resolves executing"
assert_contains "$OUT" "0 done" "incomplete plan with merged+closed pair not counted done"
unset FAKE_GH_JSON

ocd="$(mktemp -d)/.woostack"; mkspec "$ocd" oscardone done feature/oscardone
mkplan "$ocd" oscardone 2026-06-01-oscardone.md 5 0 done feature/oscardone done feature/oscardone
export FAKE_GH_JSON='[{"number":11,"state":"MERGED","headRefName":"feature/oscardone","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscardone.md"},{"number":12,"state":"CLOSED","headRefName":"feature/oscardone","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-oscardone.md"}]'
PATH="$g/bin:$PATH" run_status "$ocd"
assert_not_contains "$OUT" "oscardone " "authored-done completed plan with closed-unmerged increment resolves done (hidden by default)"
assert_contains "$OUT" "1 done" "closed-unmerged increment no longer blocks authored done (counted in footer)"
PATH="$g/bin:$PATH" run_status "$ocd" --all
assert_contains "$OUT" "oscardone" "authored-done row shown with --all"
unset FAKE_GH_JSON

# Zero-checkbox plans carry no progress signal (issue #456): trust an explicit
# authored done when all discovered increment PRs are merged...
zd="$(mktemp -d)/.woostack"; mkspec "$zd" zuludone done feature/zuludone
mkplan "$zd" zuludone 2026-06-01-zuludone.md 0 0 done feature/zuludone
export FAKE_GH_JSON='[{"number":21,"state":"MERGED","headRefName":"feature/zuludone-1","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuludone.md"},{"number":22,"state":"MERGED","headRefName":"feature/zuludone-2","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuludone.md"}]'
PATH="$g/bin:$PATH" run_status "$zd"
assert_contains "$OUT" "1 done" "zero-checkbox authored done + all merged counts as done"
assert_not_contains "$OUT" "zuludone " "zero-checkbox done hidden by default"
unset FAKE_GH_JSON

# ...and, like checkbox plans, a closed-unmerged increment no longer blocks done for a
# completed/authored-done plan: a merged+closed PR pair resolves done (the closed PR is
# workflow noise, not active work).
zc="$(mktemp -d)/.woostack"; mkspec "$zc" zuluclosed done feature/zuluclosed
mkplan "$zc" zuluclosed 2026-06-01-zuluclosed.md 0 0 done feature/zuluclosed
export FAKE_GH_JSON='[{"number":23,"state":"MERGED","headRefName":"feature/zuluclosed-1","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuluclosed.md"},{"number":24,"state":"CLOSED","headRefName":"feature/zuluclosed-2","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuluclosed.md"}]'
PATH="$g/bin:$PATH" run_status "$zc"
assert_not_contains "$OUT" "zuluclosed " "zero-checkbox authored done with closed-unmerged increment resolves done (hidden by default)"
assert_contains "$OUT" "1 done" "zero-checkbox closed-unmerged increment no longer blocks done (counted in footer)"
PATH="$g/bin:$PATH" run_status "$zc" --all
assert_contains "$OUT" "zuluclosed" "zero-checkbox done row shown with --all"
unset FAKE_GH_JSON

# ...but all-closed/none-merged is not done: `merged -gt 0` is the gate, so a feature
# whose only discovered increment PR is CLOSED must not count done via merged==active (0==0).
zco="$(mktemp -d)/.woostack"; mkspec "$zco" zclosedonly done feature/zclosedonly
mkplan "$zco" zclosedonly 2026-06-01-zclosedonly.md 0 0 done feature/zclosedonly
export FAKE_GH_JSON='[{"number":27,"state":"CLOSED","headRefName":"feature/zclosedonly-1","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zclosedonly.md"}]'
PATH="$g/bin:$PATH" run_status "$zco"
assert_contains "$OUT" "zclosedonly" "closed-only increments keep authored done visible"
assert_contains "$OUT" "0 done" "closed-only increments do not count as done"
unset FAKE_GH_JSON

# ...and the legacy no-PR no-commits case mirrors the 100%-plan legacy rule.
zl="$(mktemp -d)/.woostack"; mkspec "$zl" zululeg done feature/zululeg
mkplan "$zl" zululeg 2026-06-01-zululeg.md 0 0 done feature/zululeg
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$zl"
assert_contains "$OUT" "1 done" "zero-checkbox authored done + no PRs + no commits counts as done"
assert_not_contains "$OUT" "zululeg " "zero-checkbox legacy done hidden by default"

# Authored executing with zero checkboxes must NOT flip to done on merged PRs —
# only an explicit authored done is trusted for a plan with no progress signal.
ze="$(mktemp -d)/.woostack"; mkspec "$ze" zuluexec executing feature/zuluexec
mkplan "$ze" zuluexec 2026-06-01-zuluexec.md 0 0 executing feature/zuluexec
export FAKE_GH_JSON='[{"number":25,"state":"MERGED","headRefName":"feature/zuluexec-1","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuluexec.md"}]'
PATH="$g/bin:$PATH" run_status "$ze"
assert_contains "$OUT" "executing" "zero-checkbox authored executing stays executing on merged PRs"
assert_contains "$OUT" "0 done" "zero-checkbox authored executing not counted done"
unset FAKE_GH_JSON

# An open increment PR still wins: in-review is derived before any done rule.
zo="$(mktemp -d)/.woostack"; mkspec "$zo" zuluopen done feature/zuluopen
mkplan "$zo" zuluopen 2026-06-01-zuluopen.md 0 0 done feature/zuluopen
export FAKE_GH_JSON='[{"number":26,"state":"OPEN","headRefName":"feature/zuluopen-1","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-zuluopen.md"}]'
PATH="$g/bin:$PATH" run_status "$zo"
assert_contains "$OUT" "in-review" "zero-checkbox done with open PR derives in-review"
unset FAKE_GH_JSON

# The done rule's authored-abandoned guard: abandoned is a terminal human decision. A
# complete plan (frac=100) plus a MERGED+CLOSED pair (merged==active — the exact shape
# that flips other rows to done) must NOT resurrect the row as done: it stays abandoned,
# counted in the footer and hidden by default.
# Mirrors: resolve_phase abandoned 1 100 0 1 2 0 0 5.
ab="$(mktemp -d)/.woostack"; mkspec "$ab" abnfinal abandoned feature/abnfinal
mkplan "$ab" abnfinal 2026-06-01-abnfinal.md 5 0 abandoned feature/abnfinal
export FAKE_GH_JSON='[{"number":28,"state":"MERGED","headRefName":"feature/abnfinal-1","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-abnfinal.md"},{"number":29,"state":"CLOSED","headRefName":"feature/abnfinal-2","author":{"login":"a"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-abnfinal.md"}]'
PATH="$g/bin:$PATH" run_status "$ab"
assert_contains "$OUT" "1 abandoned" "authored abandoned with complete plan + merged pair stays abandoned"
assert_contains "$OUT" "0 done" "abandoned row is not counted done by the merged==active rule"
assert_not_contains "$OUT" "abnfinal " "abandoned row hidden by default (terminal)"
PATH="$g/bin:$PATH" run_status "$ab" --all
ABN_ROW="$(printf '%s\n' "$OUT" | grep '^abnfinal')"
assert_contains "$ABN_ROW" "abandoned" "abandoned row phase renders abandoned with --all"
# " done " (space-delimited cell) — "abandoned" itself contains the bare substring "done".
assert_not_contains "$ABN_ROW" " done " "abandoned row phase cell is not done with --all"
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
mkplan "$xm" xalpha 2026-06-01-xalpha.md 1 9 executing feature/xalpha
mkspec "$xm" xbeta executing feature/xbeta
mkplan "$xm" xbeta 2026-06-01-xbeta.md 1 9
export FAKE_GH_JSON='[{"number":300,"state":"OPEN","headRefName":"feature/xalpha","author":{"login":"z"},"updatedAt":"2026-06-03T00:00:00Z","body":"work done.\nSpec: .woostack/specs/2026-06-01-xalpha.md"}]'
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

# A prose mention of a sibling spec path is not a trailer and must not attach. This catches
# regressions where the matcher accepts any body substring instead of a real `Spec:` line.
export FAKE_GH_JSON='[{"number":301,"state":"OPEN","headRefName":"feature/xalpha","author":{"login":"z"},"updatedAt":"2026-06-03T00:00:00Z","body":"Supersedes .woostack/specs/2026-06-01-xbeta.md\nSpec: .woostack/specs/2026-06-01-xalpha.md"}]'
export FAKE_GH_HEAD_JSON='[]'
PATH="$g/bin:$PATH" run_status "$xm" --all
XALPHA_ROW="$(printf '%s\n' "$OUT" | grep '^xalpha')"
XBETA_ROW="$(printf '%s\n' "$OUT" | grep '^xbeta')"
assert_contains "$XALPHA_ROW" "#301" "trailer PR still attaches to its own spec when body mentions sibling"
assert_not_contains "$XBETA_ROW" "#301" "non-trailer body mention does NOT attach to sibling spec"
assert_not_contains "$XBETA_ROW" "in-review" "sibling spec stays out of in-review on non-trailer mention"
unset FAKE_GH_JSON FAKE_GH_HEAD_JSON

# A Spec: trailer whose value only contains the spec path as a prefix is not an exact
# trailer match. This guards against accepting backup/suffixed paths such as `.md.bak`.
export FAKE_GH_JSON='[{"number":302,"state":"OPEN","headRefName":"feature/xalpha","author":{"login":"z"},"updatedAt":"2026-06-03T00:00:00Z","body":"Spec: .woostack/specs/2026-06-01-xbeta.md.bak"}]'
export FAKE_GH_HEAD_JSON='[]'
PATH="$g/bin:$PATH" run_status "$xm" --all
XBETA_ROW="$(printf '%s\n' "$OUT" | grep '^xbeta')"
assert_not_contains "$XBETA_ROW" "#302" "suffixed Spec trailer does NOT attach to target spec"
assert_not_contains "$XBETA_ROW" "in-review" "suffixed Spec trailer does not move target spec to in-review"
unset FAKE_GH_JSON FAKE_GH_HEAD_JSON

# authored 'done' at plan 100% with no trailered PR (legacy, pre-trailer) renders done,
# not executing — an explicit terminal assertion plus a complete plan is trusted.
ld="$(mktemp -d)/.woostack"
mkspec "$ld" legdone done feature/legdone
mkplan "$ld" legdone 2026-06-01-legdone.md 4 0 done feature/legdone
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$ld"
assert_contains "$OUT" "1 done" "authored done + 100% plan + no PR counts as done"
assert_not_contains "$OUT" "legdone " "legacy done hidden by default"

# Authored done is not trusted when the active branch still has commits ahead of main.
active_done_repo="$(mktemp -d)"
( cd "$active_done_repo" && git -c user.email=t@t -c user.name=Tess init -q && git checkout -qb main )
mkspec "$active_done_repo/.woostack" activedone done feature/activedone
mkplan "$active_done_repo/.woostack" activedone 2026-06-01-activedone.md 4 0 done feature/activedone
( cd "$active_done_repo" && git add -A && git -c user.email=t@t -c user.name=Tess commit -qm "add active done plan" )
( cd "$active_done_repo" && git checkout -qb feature/activedone && printf 'work\n' > work.txt && git add work.txt && git -c user.email=t@t -c user.name=Tess commit -qm "active work" )
( cd "$active_done_repo" && FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" WOO_DIR=.woostack bash "$ST" --all > /tmp/active-done.out 2>&1 )
OUT="$(cat /tmp/active-done.out)"
assert_contains "$OUT" "activedone" "authored done with active branch work stays visible"
assert_contains "$OUT" "executing" "active branch work overrides legacy authored done shortcut"

# A merged-but-not-deleted branch is not active work. If it has no commits ahead of main,
# authored done plus a complete plan can still be trusted for legacy/untrailered specs.
merged_done_repo="$(mktemp -d)"
( cd "$merged_done_repo" && git -c user.email=t@t -c user.name=Tess init -q && git checkout -qb main )
mkspec "$merged_done_repo/.woostack" mergeddone done feature/mergeddone
mkplan "$merged_done_repo/.woostack" mergeddone 2026-06-01-mergeddone.md 4 0 done feature/mergeddone
( cd "$merged_done_repo" && git add -A && git -c user.email=t@t -c user.name=Tess commit -qm "add merged done plan" )
( cd "$merged_done_repo" && git checkout -qb feature/mergeddone && printf 'work\n' > work.txt && git add work.txt && git -c user.email=t@t -c user.name=Tess commit -qm "merged work" )
( cd "$merged_done_repo" && git checkout -q main && git merge --no-ff -q feature/mergeddone -m "merge work" )
( cd "$merged_done_repo" && FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" WOO_DIR=.woostack bash "$ST" > /tmp/merged-done.out 2>&1 )
OUT="$(cat /tmp/merged-done.out)"
assert_contains "$OUT" "1 done" "authored done + merged branch with no active commits counts as done"
assert_not_contains "$OUT" "mergeddone " "merged legacy done hidden by default"

# RC2: branch-collision is scoped to in-flight rows. Two COMPLETED features that share a
# branch must NOT flag a collision (done rows are not active work); two IN-FLIGHT features
# that share one still must. Both derive from the legacy authored path (FAKE_GH_JSON='[]').
dcol="$(mktemp -d)/.woostack"; mkspec "$dcol" collalpha done feature/dup
mkplan "$dcol" collalpha 2026-06-01-collalpha.md 3 0 done feature/dup
mkspec "$dcol" collbeta done feature/dup
mkplan "$dcol" collbeta 2026-06-01-collbeta.md 3 0 done feature/dup
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$dcol"
assert_contains "$OUT" "2 done" "both completed features sharing a branch resolve done"
assert_not_contains "$OUT" "collision" "two done rows sharing a branch do not collide"

xcol="$(mktemp -d)/.woostack"; mkspec "$xcol" execalpha executing feature/dup2
mkplan "$xcol" execalpha 2026-06-01-execalpha.md 1 9 executing feature/dup2
mkspec "$xcol" execbeta executing feature/dup2
mkplan "$xcol" execbeta 2026-06-01-execbeta.md 1 9 executing feature/dup2
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$xcol"
assert_contains "$OUT" "collision" "two in-flight rows sharing a branch still collide"

# RC2 mixed pair, terminal row FIRST (specs glob-sort by filename, so mixdone processes
# before mixexec): a done row sharing a branch with an in-flight row must not poison it —
# the recording-side exclusion keeps terminal branches out of SEEN_BRANCHES.
mcol="$(mktemp -d)/.woostack"; mkspec "$mcol" mixdone done feature/mixdup
mkplan "$mcol" mixdone 2026-06-01-mixdone.md 3 0 done feature/mixdup
mkspec "$mcol" mixexec executing feature/mixdup
mkplan "$mcol" mixexec 2026-06-01-mixexec.md 1 9 executing feature/mixdup
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$mcol"
assert_contains "$OUT" "1 done" "terminal-first mixed pair: done row still resolves done"
assert_not_contains "$OUT" "collision" "done row first does not poison the later in-flight row"

# ...and reverse order (active row FIRST): the in-flight row records the branch; the later
# done row must not flag against it — the flag-side exclusion covers terminal rows.
rcol="$(mktemp -d)/.woostack"; mkspec "$rcol" revactive executing feature/revdup
mkplan "$rcol" revactive 2026-06-01-revactive.md 1 9 executing feature/revdup
mkspec "$rcol" revdone done feature/revdup
mkplan "$rcol" revdone 2026-06-01-revdone.md 3 0 done feature/revdup
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$rcol"
assert_contains "$OUT" "1 done" "active-first mixed pair: done row still resolves done"
assert_not_contains "$OUT" "collision" "later done row does not flag against the in-flight branch"

# The guard's `!= abandoned` arm: an abandoned row sharing a branch with an in-flight row
# is not in-flight either — processed first, it must not record the branch and poison the
# live row.
acol="$(mktemp -d)/.woostack"; mkspec "$acol" abnleft abandoned feature/abndup
mkspec "$acol" abnwork executing feature/abndup
mkplan "$acol" abnwork 2026-06-01-abnwork.md 1 9 executing feature/abndup
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$acol"
assert_contains "$OUT" "1 abandoned" "abandoned row counted in footer"
assert_not_contains "$OUT" "collision" "abandoned row does not poison the later in-flight row"


# Backend adapter routing and Linear terminal reconciliation.
backend_stub="$(mktemp -d)"
cat > "$backend_stub/resolve-backend" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_BACKEND:-markdown}" = linear ]; then
  printf '%s\n' '{"backend":"linear","repository":"acme/widgets","linear":{"workspace":"Acme","team":"ENG","projectStatuses":{"draft":"ps-draft","hardened":"ps-hardened","approved":"ps-approved","planning":"ps-planning","ready":"ps-ready","executing":"ps-executing","inReview":"ps-review","done":"ps-done","abandoned":"ps-abandoned"},"issueStates":{"planned":"is-planned","executing":"is-executing","inReview":"is-review","done":"is-done","blocked":"is-blocked"}}}'
else
  printf '%s\n' '{"backend":"markdown","repository":null,"linear":null}'
fi
EOF
cat > "$backend_stub/markdown" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_MARKDOWN_FAIL:-0}" = 1 ]; then exit 1; fi
printf 'markdown %s\n' "$*" >> "$ADAPTER_LOG"
printf '%s\n' '{"backend":"markdown","feature":{"id":".woostack/specs/2026-06-01-routed.md","url":null,"title":"Adapter Routed","status":"planning","branch":"feature/routed"},"spec":{"id":".woostack/specs/2026-06-01-routed.md","url":null,"content":"spec","revision":"rev"},"progress":{"completed":1,"total":1},"increments":[{"id":"increment-1","identifier":null,"ordinal":1,"status":"done","dependencies":[],"branch":null,"pullRequest":null,"content":"adapter input"}]}'
EOF
cat > "$backend_stub/linear" <<'EOF'
#!/usr/bin/env bash
printf 'linear %s\n' "$*" >> "$ADAPTER_LOG"
if [ "$1" = feature-read ] && [ "${FAKE_LINEAR_MODE:-success}" = multi-discovery ]; then
  project_id="$3"
  case "$project_id" in
    11111111-1111-4111-8111-111111111111) project_title="Multi One" ;;
    44444444-4444-4444-8444-444444444444) project_title="Multi Two" ;;
    *) exit 2 ;;
  esac
  jq -cn --arg id "$project_id" --arg title "$project_title" '{
    backend:"linear",
    feature:{id:$id,url:"https://linear.app/acme/project/multi",title:$title,status:"planning",baseBranch:"main",baseCommitSha:"abc"},
    spec:{id:"22222222-2222-4222-8222-222222222222",url:"https://linear.app/acme/document/spec",content:"# spec",revision:"rev"},
    increments:[]
  }'
  exit 0
fi
case "$1" in
  preflight)
    if [ "${FAKE_LINEAR_MODE:-success}" = preflight-fail ]; then
      printf '%s\n' 'simulated preflight failure' >&2
      exit 1
    fi
    printf '%s\n' '{"verified":true}'
    ;;
  feature-resolve)
    if [ "${FAKE_LINEAR_MODE:-success}" = invalid-discovery ]; then
      printf '%s\n' '{"id":"not-a-uuid"}'
    elif [ "${FAKE_LINEAR_MODE:-success}" = multi-discovery ]; then
      printf '%s\n' 'candidate id=11111111-1111-4111-8111-111111111111 name=One' >&2
      printf '%s\n' 'candidate id=44444444-4444-4444-8444-444444444444 name=Two' >&2
      exit 4
    else
      printf '%s\n' '{"id":"11111111-1111-4111-8111-111111111111","name":"Linear <Launch>","url":"https://linear.app/acme/project/launch","status":"inReview","statusId":"ps-review","updatedAt":"2026-06-03T00:00:00Z"}'
    fi
    ;;
  feature-read)
    feature_branch=feature/eng-7
    feature_pr=https://github.com/acme/widgets/pull/42
    feature_title="Linear <Launch>"
    [ "${FAKE_LINEAR_MODE:-success}" = control-title ] && feature_title=$'Linear \033]52;c;Zm9v\aLaunch'
    if [ "${FAKE_LINEAR_MODE:-success}" = resume-project ]; then
      if [ -f "$LINEAR_STATE" ]; then
        feature_status=done; issue_status=done
      else
        feature_status=inReview; issue_status=done
      fi
    elif [ "${FAKE_LINEAR_MODE:-success}" = executing ]; then
      feature_status=executing; issue_status=executing
    elif [ "${FAKE_LINEAR_MODE:-success}" = already-done ]; then
      feature_status=done; issue_status=done
    elif [ -f "$LINEAR_STATE" ]; then
      feature_status=done; issue_status=done
    else
      feature_status=inReview; issue_status=inReview
    fi
    [ "${FAKE_LINEAR_MODE:-success}" = missing-branch ] && feature_branch=
    [ "${FAKE_LINEAR_MODE:-success}" = missing-pr ] && feature_pr=
    jq -cn --arg fs "$feature_status" --arg is "$issue_status" --arg title "$feature_title" \
      --arg branch "$feature_branch" --arg pr "$feature_pr" '{
      backend:"linear",
      feature:{id:"11111111-1111-4111-8111-111111111111",url:"https://linear.app/acme/project/launch",title:$title,status:$fs,baseBranch:"main",baseCommitSha:"abc"},
      spec:{id:"22222222-2222-4222-8222-222222222222",url:"https://linear.app/acme/document/spec",content:"# spec",revision:"rev"},
      increments:[{id:"33333333-3333-4333-8333-333333333333",identifier:"ENG-7",ordinal:1,status:$is,dependencies:[],branch:(if $branch=="" then null else $branch end),pullRequest:(if $pr=="" then null else $pr end),content:"Ship it"}]
    }'
    ;;
  status-reconcile)
    case "${FAKE_LINEAR_MODE:-success}" in
      api-fail) printf '%s\n' 'simulated API failure' >&2; exit 1 ;;
      already-done) printf '%s\n' '{"eligibleIssues":[],"attempted":[],"completed":[],"pending":[],"projectDone":true,"verified":true}' ;;
      resume-project)
        : > "$LINEAR_STATE"
        printf '%s\n' '{"eligibleIssues":[],"attempted":["projectUpdate"],"completed":["projectUpdate"],"pending":[],"projectDone":true,"verified":true}'
        ;;
      mismatch) printf '%s\n' '{"eligibleIssues":["33333333-3333-4333-8333-333333333333"],"attempted":["issueUpdate"],"completed":[],"pending":["issue-done-verification"],"projectDone":false,"verified":false}' ;;
      wrong-id)
        : > "$LINEAR_STATE"
        printf '%s\n' '{"eligibleIssues":["44444444-4444-4444-8444-444444444444"],"attempted":["issueUpdate","projectUpdate"],"completed":["issueUpdate","projectUpdate"],"pending":[],"projectDone":true,"verified":true}'
        ;;
      *)
        : > "$LINEAR_STATE"
        printf '%s\n' '{"eligibleIssues":["33333333-3333-4333-8333-333333333333"],"attempted":["issueUpdate","projectUpdate"],"completed":["issueUpdate","projectUpdate"],"pending":[],"projectDone":true,"verified":true}'
        ;;
    esac
    ;;
  *) exit 2 ;;
esac
EOF
cat > "$backend_stub/gh" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_GH_FAIL:-0}" = 1 ]; then exit 1; fi
printf 'gh %s\n' "$*" >> "$ADAPTER_LOG"
printf '%s' "${FAKE_LINEAR_GH_JSON:-[]}"
EOF
chmod +x "$backend_stub/"*

adapter_md="$(mktemp -d)/.woostack"
mkspec "$adapter_md" routed draft feature/routed
mkplan "$adapter_md" routed 2026-06-01-routed.md 0 1 planning feature/routed
printf '\n## Increment 1: routed\n- [ ] adapter input\n' >> "$adapter_md/plans/2026-06-01-routed.md"
ADAPTER_LOG="$(mktemp)"
export ADAPTER_LOG
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_MARKDOWN_ADAPTER="$backend_stub/markdown" run_status "$adapter_md"
assert_contains "$(cat "$ADAPTER_LOG")" "markdown feature" "Markdown rows route through the Markdown adapter"
assert_contains "$OUT" "Adapter Routed" "Markdown board consumes the normalized adapter model"
assert_not_contains "$(cat "$ADAPTER_LOG")" "linear " "Markdown status never invokes the Linear adapter"
assert_contains "$OUT" "1/1" "Markdown board derives progress from the normalized adapter model"
export FAKE_MARKDOWN_FAIL=1
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_MARKDOWN_ADAPTER="$backend_stub/markdown" run_status "$adapter_md"
assert_contains "$OUT" "normalized Markdown adapter failed" "canonical Markdown adapter failure is explicit"
assert_not_contains "$OUT" "Adapter Routed" "canonical Markdown row does not bypass a failed adapter"
unset FAKE_MARKDOWN_FAIL

linear_root="$(mktemp -d)/.woostack"
mkdir -p "$linear_root"
ADAPTER_LOG="$(mktemp)"; LINEAR_STATE="$(mktemp)"; rm -f "$LINEAR_STATE"
export ADAPTER_LOG LINEAR_STATE FAKE_BACKEND=linear LINEAR_API_KEY=test-key
LINEAR_TRAILERS=$'Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7'
export FAKE_LINEAR_GH_JSON="$(jq -cn --arg body "$LINEAR_TRAILERS" '[
  [range(1;101) | {number:.,state:"closed",html_url:("https://github.com/acme/widgets/pull/"+(.|tostring)),merged_at:null,updated_at:"2026-06-01T00:00:00Z",user:{login:"bot"},body:""}],
  [{number:42,state:"closed",html_url:"https://github.com/acme/widgets/pull/42",merged_at:"2026-06-03T00:00:00Z",updated_at:"2026-06-03T00:00:00Z",user:{login:"lee"},body:$body}]
]')"
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "Linear merge reconciliation exits 0"
assert_contains "$OUT" "preview: Linear issue ENG-7 inReview -> done via https://github.com/acme/widgets/pull/42" "Linear reconciliation previews the exact issue write"
assert_contains "$OUT" "preview: Linear project 11111111-1111-4111-8111-111111111111 inReview -> done (all managed issues done)" "Linear reconciliation previews the project write"
assert_contains "$OUT" "Linear <Launch>" "Linear feature renders after verified read-back"
assert_contains "$OUT" "done" "Linear feature renders terminal state"
LINEAR_HTML="$(cat "$linear_root/visuals/status-board.html")"
assert_contains "$LINEAR_HTML" 'data-backend="linear"' "Linear HTML row records its backend"
assert_contains "$LINEAR_HTML" 'Linear &lt;Launch&gt;' "Linear HTML escapes project titles"
assert_contains "$LINEAR_HTML" 'class="source-linear">Linear</span>' "Linear HTML identifies its source"
LINEAR_LOG="$(cat "$ADAPTER_LOG")"
assert_contains "$LINEAR_LOG" "linear preflight" "every Linear status run authenticates before reads"
assert_contains "$LINEAR_LOG" "linear status-reconcile" "eligible Linear project is reconciled"
assert_contains "$LINEAR_LOG" "linear feature-read" "Linear reconciliation performs read-back"
assert_contains "$LINEAR_LOG" "gh api --paginate --slurp" "GitHub evidence follows every PR pagination page"
assert_contains "$LINEAR_LOG" '--expected-eligible ["33333333-3333-4333-8333-333333333333"]' "status sends the exact previewed issue identity set"
assert_contains "$LINEAR_LOG" '--expected-project-transition true' "status sends the exact previewed project decision"
assert_contains "$LINEAR_LOG" '--expected-snapshot {"projectStatus":"inReview","issues":[{"id":"33333333-3333-4333-8333-333333333333","status":"inReview"}]}' "status pins the pre-write project/issue snapshot"
: > "$ADAPTER_LOG"; export FAKE_GH_FAIL=1
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 1 "$CODE" "GitHub pagination failure fails Linear status closed"
assert_not_contains "$(cat "$ADAPTER_LOG")" "status-reconcile" "pagination failure performs no status mutation"
unset FAKE_GH_FAIL


rm -f "$LINEAR_STATE"; : > "$ADAPTER_LOG"
unset LINEAR_API_KEY
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 1 "$CODE" "missing Linear credentials fail closed"
assert_contains "$OUT" "LINEAR_API_KEY" "missing-credential diagnostic names the environment contract"
assert_eq "$(cat "$ADAPTER_LOG")" "" "missing credentials block API calls"
export LINEAR_API_KEY=test-key
: > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=preflight-fail
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 1 "$CODE" "failed Linear preflight exits 1"
assert_contains "$OUT" "Linear authentication or schema preflight failed" "failed Linear preflight has a safe diagnostic"
PREFLIGHT_LOG="$(cat "$ADAPTER_LOG")"
assert_contains "$PREFLIGHT_LOG" "linear preflight" "failed Linear preflight invokes only the authentication boundary"
assert_not_contains "$PREFLIGHT_LOG" "feature-resolve" "failed Linear preflight blocks discovery"
assert_not_contains "$PREFLIGHT_LOG" "feature-read" "failed Linear preflight blocks reads"
assert_not_contains "$PREFLIGHT_LOG" "status-reconcile" "failed Linear preflight blocks mutations"
unset FAKE_LINEAR_MODE

for missing_metadata in missing-branch missing-pr; do
  : > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE="$missing_metadata" FAKE_LINEAR_GH_JSON='[]'
  WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
  WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
  assert_exit 1 "$CODE" "inReview issue with $missing_metadata fails closed"
  assert_contains "$OUT" "missing its branch or pull request" "missing inReview metadata has a safe diagnostic"
  assert_not_contains "$(cat "$ADAPTER_LOG")" "status-reconcile" "missing inReview metadata performs zero mutation"
  assert_not_contains "$(cat "$ADAPTER_LOG")" "gh api" "missing inReview metadata fails before PR evidence lookup"
done
unset FAKE_LINEAR_MODE

export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"MERGED","url":"https://github.com/acme/widgets/pull/42","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7\nLinear-Issue: ENG-8"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 1 "$CODE" "ambiguous Linear trailers fail closed"
assert_contains "$OUT" "ambiguous" "ambiguous trailer diagnostic is explicit"
rm -f "$LINEAR_STATE"; : > "$ADAPTER_LOG"
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"MERGED","url":"https://github.com/acme/widgets/pull/42","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"},{"number":99,"state":"MERGED","url":"https://github.com/acme/widgets/pull/99","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"fork"},"body":"Linear-Project: malformed\nLinear-Project: duplicate\nLinear-Issue: BAD"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "unreferenced malformed Linear trailers are ignored"
assert_contains "$OUT" "Linear <Launch>" "referenced valid PR still reconciles beside unrelated malformed history"

rm -f "$LINEAR_STATE"; : > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=resume-project
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"MERGED","url":"https://github.com/acme/widgets/pull/42","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "status resumes an all-issues-done inReview project"
assert_contains "$OUT" "preview: Linear project 11111111-1111-4111-8111-111111111111 inReview -> done" "resumable status previews the project-only write"
assert_not_contains "$OUT" "preview: Linear issue" "resumable project-only status does not preview a repeated issue write"
unset FAKE_LINEAR_MODE

: > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=invalid-discovery
export FAKE_LINEAR_GH_JSON='[]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 1 "$CODE" "invalid normalized project discovery fails closed"
assert_contains "$OUT" "invalid candidate" "invalid discovery has a safe diagnostic"
assert_not_contains "$(cat "$ADAPTER_LOG")" "feature-read" "invalid discovery fails before feature reads"
unset FAKE_LINEAR_MODE

: > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=multi-discovery FAKE_LINEAR_GH_JSON='[]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
assert_exit 0 "$CODE" "multiple managed Linear projects are discovered"
assert_contains "$OUT" "Multi One" "first discovered Linear project renders"
assert_contains "$OUT" "Multi Two" "second discovered Linear project renders"
assert_contains "$(cat "$ADAPTER_LOG")" "feature-read --project 11111111-1111-4111-8111-111111111111" "first discovered project is read"
assert_contains "$(cat "$ADAPTER_LOG")" "feature-read --project 44444444-4444-4444-8444-444444444444" "second discovered project is read"
unset FAKE_LINEAR_MODE

export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"MERGED","url":"https://github.com/acme/widgets/pull/42","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
for failure in api-fail mismatch wrong-id; do
  rm -f "$LINEAR_STATE"; export FAKE_LINEAR_MODE="$failure"
  WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
  WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root"
  assert_exit 1 "$CODE" "Linear $failure fails closed"
done
unset FAKE_LINEAR_MODE

rm -f "$LINEAR_STATE"; : > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=already-done
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"MERGED","url":"https://github.com/acme/widgets/pull/42","mergedAt":"2026-06-03T00:00:00Z","updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "already-done Linear project is invariant-checked"
assert_contains "$(cat "$ADAPTER_LOG")" "status-reconcile" "done project still validates through the reconciliation adapter"

: > "$ADAPTER_LOG"
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"CLOSED","url":"https://github.com/acme/widgets/pull/42","mergedAt":null,"updatedAt":"2026-06-03T00:00:00Z","author":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 1 "$CODE" "done Linear issue without merged evidence fails closed"
assert_not_contains "$(cat "$ADAPTER_LOG")" "status-reconcile" "unverified done issue fails before mutation adapter call"

rm -f "$LINEAR_STATE"; : > "$ADAPTER_LOG"; export FAKE_LINEAR_MODE=executing
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"open","html_url":"https://github.com/acme/widgets/pull/42","merged_at":null,"updated_at":"2026-06-03T00:00:00Z","user":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "attributed non-terminal Linear state renders without mutation"
assert_not_contains "$(cat "$ADAPTER_LOG")" "status-reconcile" "status never writes non-terminal Linear states"
assert_contains "$OUT" "executing" "non-terminal Linear state is preserved"

export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"open","html_url":"https://github.com/acme/widgets/pull/42","merged_at":null,"updated_at":"2026-06-03T00:00:00Z","user":{"login":"lee"},"body":""}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 1 "$CODE" "non-terminal Linear PR without attribution fails closed"
assert_contains "$OUT" "attribution is missing" "non-terminal attribution failure is explicit"

export FAKE_LINEAR_MODE=control-title
export FAKE_LINEAR_GH_JSON='[{"number":42,"state":"closed","html_url":"https://github.com/acme/widgets/pull/42","merged_at":"2026-06-03T00:00:00Z","updated_at":"2026-06-03T00:00:00Z","user":{"login":"lee"},"body":"Linear-Project: 11111111-1111-4111-8111-111111111111\nLinear-Issue: ENG-7"}]'
WOOSTACK_BACKEND_RESOLVER="$backend_stub/resolve-backend" \
WOOSTACK_LINEAR_ADAPTER="$backend_stub/linear" WOOSTACK_GH="$backend_stub/gh" run_status "$linear_root" --all
assert_exit 0 "$CODE" "Linear title controls are sanitized"
assert_not_contains "$OUT" $'\033' "terminal output strips Linear title controls"
assert_not_contains "$(cat "$linear_root/visuals/status-board.html")" $'\033' "HTML output strips Linear title controls before escaping"
unset FAKE_LINEAR_MODE FAKE_BACKEND FAKE_LINEAR_GH_JSON LINEAR_API_KEY
finish
