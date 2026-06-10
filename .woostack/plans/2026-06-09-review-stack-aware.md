**Source:** .woostack/specs/2026-06-09-review-stack-aware.md

# Stack-aware review Implementation Plan

**Goal:** Teach `woostack-review` to recognize work a later PR in the same Graphite stack verifiably implements, and demote the matching "missing X" finding to a non-blocking `Deferred to #N` nit instead of a normal finding.

**Architecture:** Detection and `stack.md` composition live in a new `scripts/detect-stack.sh` (one `gh pr list --state open` for the repo, then in-memory base-branch chaining), called by `prefetch.sh`, gated by `review.stack_aware`. Judgment lives in the defender validator (`prompts/validator.md`), which annotates `stack_deferred: "#N"` on covered findings. Mechanical demotion is deterministic in `intersect-findings.sh::classify_floor` (forces `nit:true, blocking:false`), and the `_header.md` body builder renders the deferral note. All offline-testable via the existing `WOO_REVIEW_TEST_MODE` fake-`gh` hook pattern.

**Tech Stack:** Bash, Python 3 stdlib (`json`), `gh` CLI, `jq`. Shell unit tests under `scripts/tests/` using `assert.sh`.

---

## Increment 1: Stack detection + `stack.md` artifact + config off-switch

> One independently shippable PR. Adds the `stack_aware` config key, the detection script, and the prefetch wiring. Produces `stack.md` as context only — no finding behavior changes yet, so it is safe to ship alone.

### Task 1: `stack_aware` config key (load-config.sh)

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:89` (REVIEW_KEYS) and `:229` (validation block region)
- Test: `skills/woostack-review/scripts/tests/test-load-config-stack-aware.sh`

- [x] **Step 1: Write the failing test**

```bash
# skills/woostack-review/scripts/tests/test-load-config-stack-aware.sh
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

setup() { # $1 = config json body
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  export GITHUB_WORKSPACE="$work/repo"
  mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
  printf '%s\n' "$1" > "$GITHUB_WORKSPACE/.woostack/config.json"
}

# stack_aware:false accepted + emitted to canonical config.
setup '{"review":{"stack_aware":false}}'
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
assert_eq "$(jq -r '.stack_aware' "$OUTDIR/config.json")" "false" "stack_aware:false emitted"
rm -rf "$work"

# stack_aware:true accepted + emitted.
setup '{"review":{"stack_aware":true}}'
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
assert_eq "$(jq -r '.stack_aware' "$OUTDIR/config.json")" "true" "stack_aware:true emitted"
rm -rf "$work"

# Non-boolean stack_aware fails the loader loudly (non-zero exit).
setup '{"review":{"stack_aware":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean stack_aware fails loader"
assert_contains "$(cat /tmp/load-config-stack.out)" "stack_aware" "error names the stack_aware key"
rm -rf "$work"

finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-stack-aware.sh`
Expected: FAIL — the first assertion errors because `stack_aware` is an unknown `review` key today, so `load-config.sh` exits non-zero with `unknown review key(s): stack_aware` and `$OUTDIR/config.json` is never written (`jq` returns empty, not `false`).

- [x] **Step 3: Minimal implementation**

Add `stack_aware` to the recognized keys set (`load-config.sh:89-93`):

```python
REVIEW_KEYS = {
    "angles", "severity_floor", "ignore", "project_rules",
    "authors_skip", "release_rollup_pattern", "models", "fix_commands",
    "disable_adversarial", "metrics", "chunking", "force_tier", "nits",
    "stack_aware",
}
```

Add a validation block next to the other boolean keys (after the `nits` block, ~line 233):

```python
if "stack_aware" in raw:
    val = raw["stack_aware"]
    if not isinstance(val, bool):
        loud("`stack_aware` must be a boolean (true/false), got {}".format(type(val).__name__))
    out["stack_aware"] = val
```

Add the doc line to the schema comment block (after the `nits` comment, ~line 56):

```bash
#   stack_aware         bool       (issue #224: detect later PRs in the same
#                                   stack and demote findings a descendant PR
#                                   already fixes to non-blocking nits;
#                                   default true. false disables detection.)
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-stack-aware.sh`
Expected: PASS — `3 passed, 0 failed`

- [x] **Step 5: Commit**

```bash
gt create -m "feat(review): accept review.stack_aware config key"
```

### Task 2: Descendant detection + `stack.md` composition (detect-stack.sh)

**Files:**
- Create: `skills/woostack-review/scripts/detect-stack.sh`
- Test: `skills/woostack-review/scripts/tests/test-detect-stack.sh`

- [x] **Step 1: Write the failing test**

```bash
# skills/woostack-review/scripts/tests/test-detect-stack.sh
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-stack.sh"

# setup $1 = headRefName of the PR under review; $2 = stack_aware ("true"/"false")
setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  jq -n --arg h "$1" '{headRefName:$h, baseRefName:"main", title:"PR0", body:"", files:[]}' \
    > "$OUTDIR/meta.json"
  printf '{"stack_aware":%s}\n' "$2" > "$OUTDIR/config.json"
  export WOO_REVIEW_TEST_MODE=1
}

# A linear stack: feat-1 (under review) -> feat-2 (child) -> feat-3 (grandchild).
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[
  {"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"Increment 2","body":"wires call sites","files":[{"path":"skills/x/SKILL.md"},{"path":"x.ts"}]},
  {"number":226,"baseRefName":"feat-2","headRefName":"feat-3","title":"Increment 3","body":"adds enum","files":[{"path":"y.ts"}]},
  {"number":999,"baseRefName":"main","headRefName":"unrelated","title":"Other","body":"","files":[{"path":"z.ts"}]}
]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{"225":"diff --git a/x.ts b/x.ts\n+wire()\n","226":"diff --git a/y.ts b/y.ts\n+enum()\n"}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "#225" "child 225 present"
assert_contains "$(cat "$OUTDIR/stack.md")" "#226" "grandchild 226 present"
assert_not_contains "$(cat "$OUTDIR/stack.md")" "#999" "unrelated PR absent"
assert_contains "$(cat "$OUTDIR/stack.md")" "+wire()" "child diff included"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Degraded diff: a matched descendant absent from the diffs map gets the degraded
# placeholder (AC3 error / AC4 error — never deferred against an unverified diff).
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"I2","body":"","files":[]}]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "degraded" "missing descendant diff -> degraded placeholder"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Off-switch: stack_aware:false -> no stack.md, no work.
setup "feat-1" "false"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"x","body":"","files":[]}]'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$([ -f "$OUTDIR/stack.md" ] && echo yes || echo no)" "no" "off-switch writes no stack.md"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON

# No descendants -> no stack.md.
setup "leaf" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"main","headRefName":"other","title":"x","body":"","files":[]}]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$([ -f "$OUTDIR/stack.md" ] && echo yes || echo no)" "no" "no descendants -> no stack.md"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Cycle guard: feat-1 -> feat-2 -> feat-1 (malformed) terminates without hanging.
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[
  {"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"A","body":"","files":[]},
  {"number":226,"baseRefName":"feat-2","headRefName":"feat-1","title":"B","body":"","files":[]}
]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{"225":"d1","226":"d2"}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "#225" "cycle: 225 captured"
assert_eq "$(grep -c '^## #' "$OUTDIR/stack.md")" "2" "cycle: each PR appears once (no infinite loop)"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Depth cap: a chain longer than 10 stops at exactly 10 descendants (AC1 edge).
setup "b0" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON="$(python3 -c 'import json; print(json.dumps([{"number":100+i,"baseRefName":"b%d"%i,"headRefName":"b%d"%(i+1),"title":"L%d"%i,"body":"","files":[]} for i in range(15)]))')"
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON="$(python3 -c 'import json; print(json.dumps({str(100+i):"d" for i in range(15)}))')"
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$(grep -c '^## #' "$OUTDIR/stack.md")" "10" "depth cap stops at 10 descendants"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# CI refusal: fake hooks rejected when GITHUB_ACTIONS=true.
setup "feat-1" "true"
export GITHUB_ACTIONS=true
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[]'
set +e
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "fake hooks refused under GITHUB_ACTIONS"
unset GITHUB_ACTIONS WOO_REVIEW_FAKE_STACK_PRS_JSON
rm -rf "$work"

finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-detect-stack.sh`
Expected: FAIL — `bash: .../detect-stack.sh: No such file or directory` (script does not exist yet).

- [x] **Step 3: Minimal implementation**

```bash
# skills/woostack-review/scripts/detect-stack.sh
#!/usr/bin/env bash
# Detects later PRs in the same stack (issue #224) and composes $OUTDIR/stack.md.
#
# A descendant is an open PR whose baseRefName chains (recursively) up to this
# PR's headRefName. We fetch ALL open PRs once and chain in-memory, so detection
# is one `gh pr list` call regardless of stack depth. Each descendant's diff is
# fetched via `gh pr diff <n>` and embedded so the defender validator can verify
# a finding's "missing X" against real descendant code.
#
# Gated by review.stack_aware (config.json, default true): off => no stack.md.
# No descendants => no stack.md. Both are normal no-ops; every downstream
# consumer treats stack.md as optional (mirrors rules.md / memory.md).
#
# Test hooks (only when WOO_REVIEW_TEST_MODE=1; REFUSED under GITHUB_ACTIONS):
#   WOO_REVIEW_FAKE_STACK_PRS_JSON  - canned `gh pr list --state open` array
#   WOO_REVIEW_FAKE_STACK_DIFFS_JSON- {"<number>": "<diff text>", ...} per PR
set -euo pipefail

# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]}")/resolve-outdir.sh"

META="$OUTDIR/meta.json"
CONFIG="$OUTDIR/config.json"
STACK_MD="$OUTDIR/stack.md"
DEPTH_CAP=10
BYTE_CAP="${WOO_REVIEW_STACK_CAP_BYTES:-100000}"

rm -f "$STACK_MD"

# Off-switch: stack_aware defaults true; explicit false short-circuits.
stack_aware="true"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.stack_aware' "$CONFIG" 2>/dev/null || echo null)"
  [ "$v" = "false" ] && stack_aware="false"
fi
if [ "$stack_aware" = "false" ]; then
  echo "detect-stack: review.stack_aware=false — skipping stack detection"
  exit 0
fi

HEAD_BRANCH="$(jq -r '.headRefName // empty' "$META" 2>/dev/null || echo "")"
if [ -z "$HEAD_BRANCH" ]; then
  echo "detect-stack: no headRefName in meta.json — cannot detect stack; skipping"
  exit 0
fi

# Test-mode gate: refuse fakes in CI (mirrors prefetch.sh).
TEST_MODE="${WOO_REVIEW_TEST_MODE:-}"
if [ "$TEST_MODE" = "1" ] && [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "::error::WOO_REVIEW_TEST_MODE is refused inside GitHub Actions. Stack test hooks are local-only." >&2
  exit 1
fi

# Fetch all open PRs (one call). Fake hook replaces it in tests.
if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_STACK_PRS_JSON:-}" ]; then
  ALL_PRS="$WOO_REVIEW_FAKE_STACK_PRS_JSON"
else
  ALL_PRS="$(gh pr list --state open --limit 200 \
    --json number,baseRefName,headRefName,title,body,files 2>/dev/null || echo '[]')"
fi
printf '%s' "$ALL_PRS" > "$OUTDIR/.stack-prs.json"

# Chain in-memory: BFS from HEAD_BRANCH, seen-set on number, depth cap.
DESC_JSON="$OUTDIR/.stack-descendants.json"
python3 - "$OUTDIR/.stack-prs.json" "$HEAD_BRANCH" "$DEPTH_CAP" "$DESC_JSON" <<'PY'
import json, sys
prs_path, head, depth_cap, out_path = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
try:
    prs = json.load(open(prs_path))
    if not isinstance(prs, list):
        prs = []
except (OSError, ValueError):
    prs = []

# Index open PRs by the branch they target (baseRefName -> [pr, ...]).
by_base = {}
for pr in prs:
    by_base.setdefault(pr.get("baseRefName"), []).append(pr)

descendants, seen, frontier, depth = [], set(), [head], 0
while frontier and depth < depth_cap:
    nxt = []
    for branch in frontier:
        for pr in by_base.get(branch, []):
            num = pr.get("number")
            if num in seen:        # cycle guard
                continue
            seen.add(num)
            descendants.append({
                "number": num,
                "title": pr.get("title") or "",
                "body": pr.get("body") or "",
                "files": [f.get("path") for f in (pr.get("files") or []) if f.get("path")],
            })
            nxt.append(pr.get("headRefName"))
    frontier = nxt
    depth += 1

json.dump(descendants, open(out_path, "w"))
print(len(descendants))
PY

DESC_COUNT="$(jq 'length' "$DESC_JSON" 2>/dev/null || echo 0)"
if [ "$DESC_COUNT" -eq 0 ]; then
  echo "detect-stack: no descendant PRs for branch '$HEAD_BRANCH' — no stack.md"
  rm -f "$OUTDIR/.stack-prs.json" "$DESC_JSON"
  exit 0
fi

# Fetch each descendant's diff (real or faked) into per-PR scratch files. A fetch
# failure (real gh error, or a PR absent from the fake diffs map) writes the SAME
# degraded placeholder, so the validator never defers against an unverified diff.
DEGRADED_MSG='[diff unavailable — descendant inspection degraded for this PR]'
for num in $(jq -r '.[].number' "$DESC_JSON"); do
  if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_STACK_DIFFS_JSON:-}" ]; then
    d="$(printf '%s' "$WOO_REVIEW_FAKE_STACK_DIFFS_JSON" | jq -r --arg n "$num" '.[$n] // "__WOO_NODIFF__"')"
    if [ "$d" = "__WOO_NODIFF__" ]; then
      printf '%s\n' "$DEGRADED_MSG" > "$OUTDIR/.stack-diff-$num.txt"
    else
      printf '%s' "$d" > "$OUTDIR/.stack-diff-$num.txt"
    fi
  else
    gh pr diff "$num" > "$OUTDIR/.stack-diff-$num.txt" 2>/dev/null \
      || { echo "::warning::detect-stack: could not fetch diff for #$num (degraded)" >&2; \
           printf '%s\n' "$DEGRADED_MSG" > "$OUTDIR/.stack-diff-$num.txt"; }
  fi
done

# Compose stack.md. Metadata always survives; diffs are appended greedily under
# the byte cap, lowest-priority (later) descendants dropped first with a notice.
python3 - "$DESC_JSON" "$OUTDIR" "$STACK_MD" "$BYTE_CAP" <<'PY'
import json, os, sys
desc_path, outdir, stack_md, cap = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
descendants = json.load(open(desc_path))

head = (
    "# Stack context — later PRs in this stack\n\n"
    "These OPEN pull requests are LATER in the same stack and build on the PR "
    "under review. A finding that says something is *missing*, *not yet wired*, "
    "or *presented before it lands* may be intentionally completed by one of "
    "these. Verify against the descendant DIFF below before deferring a finding "
    "to it. Do NOT defer security findings or findings about wrong code present "
    "in THIS PR.\n\n"
)
# Metadata for every descendant (always kept).
blocks = []
for d in descendants:
    files = "\n".join("- {}".format(p) for p in d["files"]) or "- (none listed)"
    meta = "## #{} — {}\n\n{}\n\nChanged files:\n{}\n\n".format(
        d["number"], d["title"], (d["body"] or "(no description)"), files)
    diff = open(os.path.join(outdir, ".stack-diff-{}.txt".format(d["number"]))).read()
    blocks.append((d["number"], meta, diff))

out = [head]
used = len(head.encode("utf-8"))
dropped = []
# Pass 1: reserve all metadata (never dropped).
metas = "".join(m for _, m, _ in blocks)
used += len(metas.encode("utf-8"))
# Pass 2: append diffs in order until the cap; drop the rest's diff bodies.
rendered = {}
for num, meta, diff in blocks:
    diff_block = "Diff:\n```diff\n{}\n```\n\n".format(diff.rstrip("\n"))
    if used + len(diff_block.encode("utf-8")) <= cap:
        rendered[num] = meta + diff_block
        used += len(diff_block.encode("utf-8"))
    else:
        rendered[num] = meta + "Diff: [omitted — stack.md byte cap reached]\n\n"
        dropped.append(num)
for num, meta, diff in blocks:
    out.append(rendered[num])
if dropped:
    sys.stderr.write(
        "::warning::detect-stack: stack.md exceeded {} bytes; omitted diff body for PR(s): {}\n"
        .format(cap, ", ".join("#{}".format(n) for n in dropped)))

open(stack_md, "w").write("".join(out))
print("detect-stack: wrote stack.md with {} descendant(s){}".format(
    len(descendants), " (some diffs omitted for cap)" if dropped else ""))
PY

# Clean scratch.
rm -f "$OUTDIR/.stack-prs.json" "$DESC_JSON" "$OUTDIR"/.stack-diff-*.txt
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-detect-stack.sh`
Expected: PASS — `11 passed, 0 failed`

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(review): add detect-stack.sh for descendant-PR context"
```

### Task 3: Wire detection into prefetch.sh

**Files:**
- Modify: `skills/woostack-review/scripts/prefetch.sh:296` (meta fetch) and `:791` (before the chunk-diff call)

- [x] **Step 1: Write the failing test (concrete verification)**

This is integration wiring; verify with static checks rather than a new harness.

Run: `grep -n 'headRefName' skills/woostack-review/scripts/prefetch.sh; grep -n 'detect-stack.sh' skills/woostack-review/scripts/prefetch.sh`
Expected (current): both print nothing — neither the field nor the call is wired yet.

- [x] **Step 2: Confirm the gap**

Run: `bash -n skills/woostack-review/scripts/prefetch.sh && echo "syntax-ok"`
Expected: `syntax-ok` (baseline parses; the wiring is simply absent).

- [x] **Step 3: Minimal implementation**

Add `headRefName` to the meta fetch (`prefetch.sh:296`):

```bash
gh pr view "$PR_NUMBER" --json headRefOid,headRefName,baseRefName,title,body,files,author > "$OUTDIR/meta.json"
```

Call detect-stack.sh just before the chunk-diff call (`prefetch.sh:791`, after memory composition, where `meta.json` + `config.json` + `diff.txt` all exist):

```bash
# Issue #224: detect later PRs in the same stack and compose stack.md (descendant
# diffs as additional rubric). Self-gates on review.stack_aware (default true);
# a no-op when off or when there are no descendants. Runs before chunking so a
# capped stack.md is ready for the swarm alongside rules.md / memory.md.
bash "$SCRIPT_DIR/detect-stack.sh" || echo "::warning::detect-stack.sh failed (non-fatal); continuing without stack.md"
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'headRefName' skills/woostack-review/scripts/prefetch.sh; grep -c 'detect-stack.sh' skills/woostack-review/scripts/prefetch.sh; bash -n skills/woostack-review/scripts/prefetch.sh && echo ok`
Expected: `1` (headRefName in the meta fetch), `1` (the call), `ok`. Then re-run the Task 2 suite to confirm no regression: `bash skills/woostack-review/scripts/tests/test-detect-stack.sh` → `11 passed, 0 failed`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(review): fetch headRefName and compose stack.md in prefetch"
```

---

## Increment 2: Validator deferral + classifier demotion + rendering

> One independently shippable PR, stacked on Increment 1. Turns the `stack.md` context into behavior: the defender annotates `stack_deferred`, the classifier forces it to a nit, and the body builder renders `Deferred to #N`.

### Task 4: classify_floor demotion + `stack_deferred_count` metric (intersect-findings.sh)

**Files:**
- Modify: `skills/woostack-review/scripts/intersect-findings.sh` — `classify_floor()` loop (~line 309), `write_metrics()` (~line 122), and both `write_metrics` call sites (~line 345, ~line 606)
- Test: `skills/woostack-review/scripts/tests/test-intersect-stack-deferred.sh`

- [ ] **Step 1: Write the failing test**

```bash
# skills/woostack-review/scripts/tests/test-intersect-stack-deferred.sh
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# A finding carrying stack_deferred must become a non-blocking nit regardless of
# severity_floor. Run defender-only (disable_adversarial) to isolate the floor
# classifier from the intersection logic.
setup() { # $1 = severity_floor
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '{"disable_adversarial":true,"severity_floor":"%s"}\n' "$1" > "$OUTDIR/config.json"
  cat > "$OUTDIR/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"x.ts","line":3,"severity":"HIGH","blocking":true,
   "title":"Missing call-site wiring","description":"d","fix":"f","fix_type":"prose",
   "suggestion":null,"rule_quote":null,"stack_deferred":"#225"}
]
JSON
  printf '[]\n' > "$OUTDIR/raw_findings.json"
}

# Under floor=high: HIGH would normally be a normal blocking finding; the
# stack_deferred override must still demote it to a nit.
setup "high"
bash "$SCRIPT" >/tmp/intersect-stack.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "stack_deferred -> nit (floor=high)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "stack_deferred -> non-blocking (floor=high)"
assert_eq "$(jq -r '.stack_deferred_count' "$OUTDIR/validator-metrics.json")" "1" "stack_deferred_count counted"
rm -rf "$work"

# Under floor=low: HIGH is at/above floor (would be a normal finding); the
# override must STILL force nit — proving it is floor-independent.
setup "low"
bash "$SCRIPT" >/tmp/intersect-stack.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "stack_deferred -> nit (floor=low, floor-independent)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "stack_deferred -> non-blocking (floor=low)"
rm -rf "$work"

finish
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-stack-deferred.sh`
Expected: FAIL — under `floor=high` the HIGH blocking finding stays `nit:false, blocking:true` (no override yet), and `.stack_deferred_count` is `null` in `validator-metrics.json` (key absent).

- [ ] **Step 3: Minimal implementation**

In `classify_floor()`, add the override as the first branch of the per-finding loop (before the `rank >= floor_rank` check, ~line 309):

```python
out = []
for f in findings:
    # Stack-aware deferral (issue #224): a finding the defender confirmed a later
    # stack PR fixes is forced to a non-blocking nit, INDEPENDENT of the floor.
    sd = f.get("stack_deferred")
    if isinstance(sd, str) and sd.strip():
        f["nit"] = True
        f["blocking"] = False
        out.append(f)
        continue
    # Unknown/missing severity -> MEDIUM (matches sev_rank() used in the merge).
    rank = RANK.get((f.get("severity") or "").lower(), 1)
    ...
```

Extend `write_metrics()` to emit `stack_deferred_count` (add a 10th positional arg, ~line 122-144):

```bash
write_metrics() {
  jq -n \
    --arg mode "$1" \
    --argjson degraded "$2" \
    --argjson prosecutor_count "$3" \
    --argjson defender_count "$4" \
    --argjson kept_count "$5" \
    --argjson disagreement_count "$6" \
    --argjson dropped_by_defender "$7" \
    --argjson dropped_by_prosecutor "$8" \
    --argjson nit_count "$9" \
    --argjson stack_deferred_count "${10}" \
    '{
      mode: $mode,
      degraded: $degraded,
      prosecutor_count: $prosecutor_count,
      defender_count: $defender_count,
      kept_count: $kept_count,
      disagreement_count: $disagreement_count,
      dropped_by_defender: $dropped_by_defender,
      dropped_by_prosecutor: $dropped_by_prosecutor,
      nit_count: $nit_count,
      stack_deferred_count: $stack_deferred_count
    }' > "$METRICS"
}
```

Compute the count after `classify_floor` and pass it at BOTH call sites. Defender-only path (~line 343-345):

```bash
  kept_count="$(jq 'length' "$FINAL")"
  nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
  stack_deferred_count="$(jq '[.[] | select((.stack_deferred // "") != "")] | length' "$FINAL")"
  write_metrics "$mode" "$degraded" null "$defender_count" "$kept_count" 0 0 0 "$nit_count" "$stack_deferred_count"
```

Adversarial path (~line 599-606):

```bash
nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
stack_deferred_count="$(jq '[.[] | select((.stack_deferred // "") != "")] | length' "$FINAL")"
...
write_metrics adversarial false "$prosecutor_count" "$defender_count" "$kept_count" "$disagreement_count" "$dropped_by_defender" "$dropped_by_prosecutor" "$nit_count" "$stack_deferred_count"
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-stack-deferred.sh`
Expected: PASS — `5 passed, 0 failed`. Then regression: `bash skills/woostack-review/scripts/tests/test-intersect-nits.sh` → still passes.

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(review): demote stack_deferred findings to nits in classifier"
```

### Task 5: Defender stack-deferral judgment (validator.md)

**Files:**
- Modify: `skills/woostack-review/prompts/validator.md` — Input Artifacts (~line 16) and Step 2 (~line 45, a new sub-step between Memory Check and Severity Check)

- [ ] **Step 1: Write the failing test (concrete verification)**

Prompt text — verify by presence of the directive the runtime reads.

Run: `grep -c 'stack_deferred' skills/woostack-review/prompts/validator.md`
Expected (current): `0`.

- [ ] **Step 2: Confirm the gap**

Run: `grep -n 'Memory Check' skills/woostack-review/prompts/validator.md`
Expected: prints the Memory Check line (the anchor the new sub-step follows); no `stack_deferred` directive exists yet.

- [ ] **Step 3: Minimal implementation**

Add the input artifact (after the memory.md bullet, ~line 15):

```markdown
- **Stack context** (optional): /tmp/pr-review/stack.md — when this PR is part of a Graphite stack, the LATER PRs' diffs. Absent when there are no descendants or `review.stack_aware` is false. See the Stack-deferral Check below.
```

Insert a new numbered sub-step in Step 2 immediately after "4. **Memory Check**" (renumber the rest is unnecessary — append as 4b):

```markdown
4b. **Stack-deferral Check** (issue #224): If `/tmp/pr-review/stack.md` exists, read it. For each finding that asserts something is **missing, not yet wired, or presented before it lands** (e.g. "X is referenced before it is defined", "command not yet routed", "integration absent"), check whether one of the descendant PR DIFFS in `stack.md` actually ADDS that exact thing.
   - If a descendant diff verifiably adds it: set the finding's `stack_deferred` field to that PR's number string (e.g. `"#225"`) and set `blocking: false`. Do NOT drop it — it is demoted downstream to a non-blocking `Deferred to #N` nit, staying visible and auditable.
   - **Never** set `stack_deferred` on a `security`-angle finding, or on a finding about WRONG code that is present in THIS PR (deferral is only for *missing/deferred* work that a later PR completes).
   - PR-body phrases like "Increment N" / "lands in N+1" are a hint to LOOK, never proof — the descendant diff is the proof.
   - If `stack.md` marks a descendant's diff as `[diff unavailable — degraded]`, do NOT defer against it; instead keep the finding as-is (the downstream review stays honest rather than blind-suppressing).
   - Findings with no `stack.md`, or no matching descendant, are unchanged (leave `stack_deferred` unset/null).
```

Note the schema field in the same file is documented centrally in `_header.md` (Task 6); the validator only needs to know to *set* it.

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'stack_deferred' skills/woostack-review/prompts/validator.md`
Expected: `≥3` (artifact mention + the set-directive + the security guard). Confirm the security exclusion is present: `grep -n 'Never.*security' skills/woostack-review/prompts/validator.md` prints the guard line.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(review): defender annotates stack_deferred from stack.md"
```

### Task 6: Document the artifact + schema field + render the note (_header.md)

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` — Prefetched Artifacts list (~line 33), Findings Schema (~line 404), config table (~line 85), and the body-builder python (~line 245)

- [ ] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'stack.md' skills/woostack-review/prompts/_header.md; grep -c 'stack_deferred' skills/woostack-review/prompts/_header.md; grep -c 'Deferred to' skills/woostack-review/prompts/_header.md`
Expected (current): `0`, `0`, `0`.

- [ ] **Step 2: Confirm the gap**

Run: `grep -n 'Cross-PR memory' skills/woostack-review/prompts/_header.md | head -1`
Expected: prints the memory artifact line (the anchor the stack.md artifact bullet follows).

- [ ] **Step 3: Minimal implementation**

Add the artifact bullet (after the Cross-PR memory bullet, ~line 33):

```markdown
- **Stack context** (optional, present only when this PR has open descendant PRs in its Graphite stack and `review.stack_aware` is not false): `/tmp/pr-review/stack.md` — the later stack PRs' numbers, titles, bodies, changed files, and diffs. Treat it as verification context: a finding that something is *missing/not-yet-wired* may be intentionally completed by a descendant. The defender validator (`validator.md`) sets `stack_deferred: "#N"` on such a finding; it is demoted to a non-blocking `Deferred to #N` nit downstream. Angle workers may read it but MUST NOT defer — deferral is the validator's job.
```

Add the schema field (in the Findings Schema JSON, ~line 404, after `rule_quote`):

```json
    "rule_quote": "exact quoted rule text if rule-based, else null",
    "stack_deferred": "later-stack PR number (e.g. \"#225\") this finding is deferred to, set by the defender when a descendant diff adds the missing thing; else null"
```

Add a one-line note after the schema explaining it is downstream-driven (near the `nit` field note, ~line 445):

```markdown
`stack_deferred` is a string (`"#N"`) or null, set by the defender validator (`validator.md`) when a later PR in the same stack verifiably implements the work a finding flags as missing. `intersect-findings.sh` forces any finding carrying a non-empty `stack_deferred` to `nit: true, blocking: false` (independent of `severity_floor`), and the body builder appends a `Deferred to #N` line. Never set on `security` findings.
```

Add the config-table row (~line 85, after the `chunking.max_loc` row):

```markdown
| `stack_aware` | `prefetch.sh` → `detect-stack.sh` (compose `stack.md`) | Stage 1 — default `true`; `false` disables stack detection |
```

Render the deferral note in the body builder (~line 245, right after the `description` is set into `body`, before the `Fix:` append):

```python
    body = f"**{title}**\n\n{description}"
    sd = (f.get("stack_deferred") or "").strip()
    if sd:
        body += f"\n\n_Deferred to {sd} — a later PR in this stack adds this; non-blocking._"
    if fix:
        body += f"\n\nFix: {fix}"
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'stack.md' skills/woostack-review/prompts/_header.md; grep -c 'stack_deferred' skills/woostack-review/prompts/_header.md; grep -c 'Deferred to' skills/woostack-review/prompts/_header.md`
Expected: `≥2`, `≥3`, `≥2`. Sanity-check the body-builder python still parses by extracting and `python3 -c`-importing is overkill; instead confirm the edit sits inside the snippet: `grep -n 'Deferred to' skills/woostack-review/prompts/_header.md` shows the line within the `body = ` builder block.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): document stack.md artifact, stack_deferred field, render note"
```

---

## Increment 3: SKILL.md documentation

> One independently shippable docs PR, stacked on Increment 2. Brings the human-facing `SKILL.md` in line with the shipped behavior.

### Task 7: Document stack-aware review in SKILL.md

**Files:**
- Modify: `skills/woostack-review/SKILL.md` — config schema block (~line 128), key reference (~line 174), artifact table (~line 236), and a new "Stack-aware review" section (after "Incremental Mode", ~line 68)

- [ ] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'stack_aware' skills/woostack-review/SKILL.md; grep -c 'stack.md' skills/woostack-review/SKILL.md`
Expected (current): `0`, `0`.

- [ ] **Step 2: Confirm the gap**

Run: `grep -n 'Incremental Mode' skills/woostack-review/SKILL.md | head -1`
Expected: prints the section header the new "Stack-aware review" section follows.

- [ ] **Step 3: Minimal implementation**

Add the config-schema key inside the `review` object (~line 165, near `nits`):

```json
    "nits": true,
    "stack_aware": true,
```

Add the key-reference bullet (~line 176, after the `nits` bullet):

```markdown
- **`stack_aware`** — `true` | `false`; default **`true`**. When `true`, `prefetch.sh` runs `detect-stack.sh` to find later PRs in the same Graphite stack and compose `stack.md`; the defender validator then demotes a finding a descendant PR verifiably fixes to a non-blocking `Deferred to #N` nit (issue #224). Set `false` to disable stack detection entirely (no `gh pr list`, no `stack.md`). Never defers `security` findings; degrades to a low-confidence finding when a descendant diff can't be fetched.
```

Add the artifact-table row (~line 236, after the `memory.md` row):

```markdown
| `stack.md` | `prefetch.sh` → `detect-stack.sh` | all angles, validator | Later stack PRs' diffs; present only when this PR has open descendants and `stack_aware` ≠ false. Drives `stack_deferred` demotion |
```

Add a new section after "Incremental Mode" (~line 68):

```markdown
## Stack-aware review (`review.stack_aware`, issue #224)

woostack encourages PR-sized **stacked** increments, so an early PR in a stack often *intentionally* defers integration to a later PR. Reviewing the isolated diff would flag that deferred work as "missing" — noise that trains authors to ignore the review gate.

When `review.stack_aware` is `true` (the default), `prefetch.sh` calls `detect-stack.sh`: it lists open PRs once and base-branch-chains from this PR's head branch (recursively, depth-capped, cycle-guarded) to find **descendant** PRs — host-agnostic, no Graphite runtime dependency. Their numbers, titles, bodies, changed files, and diffs are composed into `stack.md` (section-capped at 100KB; metadata never dropped).

The **defender validator** reads `stack.md` and, for a finding that asserts something is *missing / not-yet-wired / presented-before-it-lands*, checks whether a descendant's **diff** actually adds it. If so it sets `stack_deferred: "#N"`; `intersect-findings.sh` then forces the finding to a non-blocking **`Deferred to #N` nit** (visible, auditable, event-neutral → `APPROVE`), independent of `severity_floor`. Guards: `security` findings are never deferred; a finding about wrong code *present in this PR* is never deferred; when a descendant diff can't be fetched the finding stays a normal (low-confidence) finding rather than being blindly suppressed. Set `review.stack_aware: false` to turn the whole feature off.
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'stack_aware' skills/woostack-review/SKILL.md; grep -c 'stack.md' skills/woostack-review/SKILL.md`
Expected: `≥4`, `≥3`. Spot-check the section renders: `grep -n 'Stack-aware review' skills/woostack-review/SKILL.md` prints the new header.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): document stack-aware review in SKILL.md"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above:
  - §4.1 detect (base-chaining, recursive, depth cap, cycle guard, off-switch, CI perms) → Task 2 + Task 1 + Task 3
  - §4.2 compose `stack.md` (full capped diff, metadata-survives) → Task 2
  - §4.3 defender judgment (`stack_deferred`, security excluded, body-cue-hint, degraded→low-confidence) → Task 5
  - §4.4 classifier demotion (floor-independent, `stack_deferred_count`) → Task 4
  - §4.5 render `Deferred to #N` → Task 6
  - config + docs surface (load-config, _header config table, SKILL schema/key/section/artifact) → Tasks 1, 6, 7
- [ ] **AC coverage** — AC1 (detection happy/error/edge) → test-detect-stack: child+grandchild (happy), empty `gh pr list` → no stack.md graceful (error), cycle guard + depth cap at 10 (edge); AC2 (off-switch happy/error/edge) → test-load-config-stack-aware (accept/reject) + test-detect-stack off-switch (no stack.md); AC3 (`stack.md` happy/error/edge) → test-detect-stack diff-included (happy) + degraded-placeholder for an unfetchable descendant diff (error); the 100KB cap is parameterized via `WOO_REVIEW_STACK_CAP_BYTES` for an executor-added cap test if desired (edge — small, deterministic); AC4 (deferral happy/error/edge) → validator.md directive carries the security/in-PR-code/degraded guards, exercised end-to-end by the classifier (Task 4) + render (Task 6); AC5 (classifier floor-independent + metric) → test-intersect-stack-deferred (floor high AND low + `stack_deferred_count`).
- [ ] **No placeholders** — every step carries real code, exact commands, expected output.
- [ ] **Type consistency** — `stack_deferred` is a string `"#N"` or null everywhere (validator sets, intersect reads `(.stack_deferred // "") != ""`, body builder reads `(f.get("stack_deferred") or "").strip()`); `stack_aware` is a bool everywhere; `WOO_REVIEW_FAKE_STACK_PRS_JSON` / `_DIFFS_JSON` names match between detect-stack.sh and its test.

> woostack plan conventions: frontmatter-free; opens with `**Source:**`; basename mirrors the spec (`2026-06-09-review-stack-aware`); no sub-skill banner; prompt/doc edits use concrete grep/`bash -n` verifications in place of a runner.
