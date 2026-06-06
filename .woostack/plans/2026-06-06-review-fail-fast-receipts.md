**Source:** .woostack/specs/2026-06-06-review-fail-fast-receipts.md

# woostack-review fail-fast on non-executing angle workers — Implementation Plan

**Goal:** Make `findings.json == []` provably mean "every expected angle executed and found nothing" by adding a per-worker execution receipt + a hard postflight gate, so a review can never report a clean PASS when no angle analysis ran.

**Architecture:** A new `verify-receipts.sh` is the single authority on "did this angle worker execute" (valid receipt = JSON object, matching `angle`/`chunk`, non-empty `runner`+`model`). It runs as a gate (hard-fail) and exposes a non-failing `--list-missing` mode reused by `run-bounded-swarm.sh` for its retry set. Workers write the receipt as their last action (contract in `prompts/_header.md` + the SKILL Stage-3 brief). The gate is invoked from three entry points — end of `run-bounded-swarm.sh` (local shell), the chat-host orchestrator (SKILL Stage 3), and the CI validate path (`action.yml`). A lightweight preflight hardens `detect-provider.sh`. Increments are ordered so the receipt-write contract lands before any mandatory gate wiring (the §6 lockstep).

**Tech Stack:** Bash (POSIX-ish, must run on macOS bash 3.2 and ubuntu — no `mapfile`), `jq`, GitHub Actions composite action + reusable workflow, the repo's `assert.sh` shell test harness.

**Increment order & lockstep:** Inc 1 (gate script, inert) → Inc 2 (workers write receipts, inert) → Inc 3 (local enforcement: swarm calls the gate) → Inc 4 (CI enforcement). Every mandatory-gate increment (3, 4) sits above the receipt-write increment (2) in the Graphite stack, so no merge point enforces the gate before workers write receipts. Inc 1 and Inc 2 are individually inert (an unwired script; harmless extra `receipt.*.json` files), so each merges green with no behavior change; the gate only ever activates with receipts already on `main` below it.

**Within-increment sequencing (Inc 3).** Adding the swarm's receipt gate (Task 1) makes the pre-existing `test-bounded-swarm.sh` start failing, because its stubs write no receipts; Task 2 immediately repairs that test by having its stubs write receipts. This is sequenced, not accidental: Task 1's own verification runs only the *new* `test-bounded-swarm-receipts.sh` (green at end of Task 1), so execute never observes the stale test as a surprise red; Task 2 Step 1 *expects* `test-bounded-swarm.sh` to fail, then fixes it. The increment ends fully green, and the `degraded` (findings) path stays a soft warning — only a missing receipt hard-fails.

---

## Increment 1: `verify-receipts.sh` gate script + tests

> One independently shippable PR. Adds the standalone gate and its tests. Nothing calls it yet (inert), so it changes no behavior on its own.

### Task 1: Create `verify-receipts.sh`

**Files:**
- Create: `skills/woostack-review/scripts/verify-receipts.sh`
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-pass.sh`

- [x] **Step 1: Write the failing test** (happy path: all receipts valid → exit 0, metrics recorded)

Create `skills/woostack-review/scripts/tests/test-verify-receipts-pass.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security > "$OUTDIR/angles.txt"
for a in bugs security; do
  printf '{"angle":"%s","chunk":null,"runner":"claude-code","model":"claude-sonnet-4-6","tier":"standard","ts":"2026-06-06T00:00:00Z"}\n' "$a" > "$OUTDIR/receipt.$a.json"
done

rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "all receipts valid → exit 0"
assert_eq "$(jq -r '.executed_angles | length' "$OUTDIR/swarm-metrics.json")" "2" "metrics record 2 executed angles"
assert_eq "$(jq -r '.expected_total' "$OUTDIR/swarm-metrics.json")" "2" "metrics record expected total"
finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-verify-receipts-pass.sh`
Expected: FAIL — script missing, e.g. `bash: .../verify-receipts.sh: No such file or directory`, non-zero exit.

- [x] **Step 3: Minimal implementation**

Create `skills/woostack-review/scripts/verify-receipts.sh`:

```bash
#!/usr/bin/env bash
# Postflight gate: assert every expected angle (from angles.txt × chunks.txt) wrote
# a VALID execution receipt. A valid receipt is a JSON object whose `angle` (and
# `chunk`, when chunking is active) matches and whose `runner` and `model` are both
# non-empty. This is the single authority on "did the angle worker actually execute":
# empty findings are an honest clean review ONLY when the receipt proves the worker ran.
#
# Modes:
#   (default)       gate: emit ::error and exit 1 if any expected receipt is missing/invalid.
#   --list-missing  print the missing/invalid "<angle>" or "<angle>.<chunk>" labels, exit 0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"

mode="gate"
case "${1:-}" in
  --list-missing) mode="list" ;;
  "") ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "::error::unknown argument: $1" >&2; exit 2 ;;
esac

angles_file="$OUTDIR/angles.txt"
if [ ! -s "$angles_file" ]; then
  echo "::error::missing or empty angles file: $angles_file" >&2
  exit 2
fi

angles=()
while IFS= read -r a; do [ -n "$a" ] && angles+=("$a"); done < "$angles_file"
if [ "${#angles[@]}" -eq 0 ]; then
  echo "::error::no angles found in $angles_file" >&2
  exit 2
fi

chunks=("")
chunks_file="$OUTDIR/chunks.txt"
if [ -s "$chunks_file" ]; then
  chunks=()
  while IFS= read -r c; do [ -n "$c" ] && chunks+=("$c"); done < "$chunks_file"
  [ "${#chunks[@]}" -eq 0 ] && chunks=("")
fi

receipt_path() { # angle chunk
  if [ -n "$2" ]; then printf '%s/receipt.%s.%s.json' "$OUTDIR" "$1" "$2"
  else printf '%s/receipt.%s.json' "$OUTDIR" "$1"; fi
}
label() { # angle chunk
  if [ -n "$2" ]; then printf '%s.%s' "$1" "$2"; else printf '%s' "$1"; fi
}

# Valid iff: JSON object; .angle == angle; (.chunk matches, or both empty/null);
# .runner and .model are non-empty.
is_valid_receipt() { # angle chunk file
  local angle="$1" chunk="$2" f="$3"
  [ -s "$f" ] || return 1
  jq -e --arg a "$angle" --arg c "$chunk" '
    (type == "object")
    and (.angle == $a)
    and ( (($c == "") and ((.chunk == null) or (.chunk == ""))) or (.chunk == $c) )
    and (((.runner // "") | tostring | length) > 0)
    and (((.model  // "") | tostring | length) > 0)
  ' "$f" >/dev/null 2>&1
}

missing=()
executed=()
for angle in "${angles[@]}"; do
  for chunk in "${chunks[@]}"; do
    f="$(receipt_path "$angle" "$chunk")"
    if is_valid_receipt "$angle" "$chunk" "$f"; then
      executed+=("$(label "$angle" "$chunk")")
    else
      missing+=("$(label "$angle" "$chunk")")
    fi
  done
done

if [ "$mode" = "list" ]; then
  for m in ${missing[@]+"${missing[@]}"}; do printf '%s\n' "$m"; done
  exit 0
fi

# Gate mode: record executed/expected/missing into swarm-metrics.json (best-effort).
expected_total=$(( ${#angles[@]} * ${#chunks[@]} ))
metrics="$OUTDIR/swarm-metrics.json"
to_json_array() { # items...
  if [ "$#" -eq 0 ]; then printf '[]'; return; fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}
exec_json="$(to_json_array ${executed[@]+"${executed[@]}"})"
miss_json="$(to_json_array ${missing[@]+"${missing[@]}"})"
if [ -s "$metrics" ] && jq -e . "$metrics" >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --argjson ex "$exec_json" --argjson mi "$miss_json" --argjson et "$expected_total" \
    '.executed_angles=$ex | .expected_total=$et | .missing_receipts=$mi' "$metrics" > "$tmp" && mv "$tmp" "$metrics"
else
  jq -n --argjson ex "$exec_json" --argjson mi "$miss_json" --argjson et "$expected_total" \
    '{schema_version:1, executed_angles:$ex, expected_total:$et, missing_receipts:$mi}' > "$metrics"
fi

if [ "${#missing[@]}" -gt 0 ]; then
  miss_csv="$(IFS=', '; echo "${missing[*]}")"
  if [ "${#executed[@]}" -eq 0 ]; then
    echo "::error::woostack-review: no angle analysis executed (0 of ${expected_total} angle workers produced a valid receipt): ${miss_csv}. The review did NOT run. Configure a provider/model, install auth, or set the correct runner override, then re-run." >&2
  else
    echo "::error::woostack-review: ${#missing[@]} of ${expected_total} angle worker(s) did not execute (no valid receipt): ${miss_csv}. No angle analysis ran for these, so the review is NOT complete. Configure a provider/model, install auth, or set the correct runner override, then re-run." >&2
  fi
  exit 1
fi

echo "verify-receipts: all ${expected_total} angle receipt(s) valid."
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-verify-receipts-pass.sh`
Expected: PASS — `  3 passed, 0 failed`

- [x] **Step 5: Syntax-check the script**

Run: `bash -n skills/woostack-review/scripts/verify-receipts.sh && echo OK`
Expected: `OK`

- [x] **Step 6: Commit**

```bash
# first commit in this increment:
gt create -m "feat(woostack-review): add verify-receipts.sh execution gate"
```

### Task 2: Missing / none / identity failure-path tests

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-missing.sh`
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-none.sh`
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-identity.sh`

- [x] **Step 1: Write the failing tests**

Create `skills/woostack-review/scripts/tests/test-verify-receipts-missing.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security types > "$OUTDIR/angles.txt"
# bugs + security executed; types produced NO receipt.
for a in bugs security; do
  printf '{"angle":"%s","chunk":null,"runner":"claude-code","model":"m","tier":"standard","ts":"t"}\n' "$a" > "$OUTDIR/receipt.$a.json"
done

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing receipt → exit 1"
assert_contains "$err" "did not execute" "error states workers did not execute"
assert_contains "$err" "types" "error names the non-executing angle"
assert_not_contains "$err" "no angle analysis executed" "partial failure uses the partial message"
finish
```

Create `skills/woostack-review/scripts/tests/test-verify-receipts-none.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security > "$OUTDIR/angles.txt"
# No receipts at all.

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "zero receipts → exit 1"
assert_contains "$err" "no angle analysis executed" "zero-receipt message fires"
finish
```

Create `skills/woostack-review/scripts/tests/test-verify-receipts-identity.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
# Receipt file present + valid JSON object + matching angle, but model is empty.
printf '{"angle":"bugs","chunk":null,"runner":"claude-code","model":"","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "empty model → invalid receipt → exit 1"
assert_contains "$err" "bugs" "names the angle whose identity is incomplete"

# Empty runner is likewise invalid.
printf '{"angle":"bugs","chunk":null,"runner":"","model":"m","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "empty runner → invalid receipt → exit 1"
finish
```

- [x] **Step 2: Run the tests, confirm they pass** (script already exists from Task 1)

Run:
```bash
bash skills/woostack-review/scripts/tests/test-verify-receipts-missing.sh
bash skills/woostack-review/scripts/tests/test-verify-receipts-none.sh
bash skills/woostack-review/scripts/tests/test-verify-receipts-identity.sh
```
Expected: each prints `  N passed, 0 failed` and exits 0 (`4 passed`, `2 passed`, `3 passed` respectively).

- [x] **Step 3: Commit**

```bash
gt modify -c -m "test(woostack-review): cover verify-receipts missing/none/identity paths"
```

### Task 3: `--list-missing` mode + chunked tests

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-list-missing.sh`
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-chunked.sh`

- [x] **Step 1: Write the failing tests**

Create `skills/woostack-review/scripts/tests/test-verify-receipts-list-missing.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs security types > "$OUTDIR/angles.txt"
printf '{"angle":"bugs","chunk":null,"runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.json"
# security + types missing.

rc=0; out="$(bash "$SCRIPT" --list-missing)" || rc=$?
assert_exit 0 "$rc" "--list-missing exits 0 (non-failing)"
assert_contains "$out" "security" "lists missing security"
assert_contains "$out" "types" "lists missing types"
assert_not_contains "$out" "bugs" "valid receipt not listed as missing"
finish
```

Create `skills/woostack-review/scripts/tests/test-verify-receipts-chunked.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/verify-receipts.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' bugs > "$OUTDIR/angles.txt"
printf '%s\n' chunk-0 chunk-1 > "$OUTDIR/chunks.txt"
# chunk-0 executed, chunk-1 missing.
printf '{"angle":"bugs","chunk":"chunk-0","runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.chunk-0.json"

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "missing (angle,chunk) receipt → exit 1"
assert_contains "$err" "bugs.chunk-1" "names the missing angle.chunk"

# Add the missing chunk receipt → now passes.
printf '{"angle":"bugs","chunk":"chunk-1","runner":"r","model":"m"}\n' > "$OUTDIR/receipt.bugs.chunk-1.json"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "all chunk receipts valid → exit 0"
finish
```

- [x] **Step 2: Run the tests, confirm they pass**

Run:
```bash
bash skills/woostack-review/scripts/tests/test-verify-receipts-list-missing.sh
bash skills/woostack-review/scripts/tests/test-verify-receipts-chunked.sh
```
Expected: `  4 passed, 0 failed` and `  3 passed, 0 failed`.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "test(woostack-review): cover verify-receipts list-missing + chunked"
```

---

## Increment 2: workers write the execution receipt (contract)

> One independently shippable PR. Adds the receipt-write instruction to the shared `_header.md` contract and the SKILL Stage-3 sub-agent brief. Workers begin writing receipts; nothing enforces yet (inert). Lands BEFORE any mandatory gate wiring (§6 lockstep).

### Task 1: Add the receipt-write bullet to `_header.md`

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` (Output Discipline list, around line 12)

- [x] **Step 1: Verification baseline (no receipt instruction yet)**

Run: `grep -c "receipt." skills/woostack-review/prompts/_header.md`
Expected: `0`

- [x] **Step 2: Add the instruction**

In `skills/woostack-review/prompts/_header.md`, immediately AFTER the existing bullet that begins `- **Write \`[]\` to your findings file as the FIRST action.**` (the one ending `…silently dropped out of the review."`), insert this new bullet:

```markdown
- **Write your execution receipt as your LAST action.** After writing your real findings array, and just before EXIT, write `$OUTDIR/receipt.<angle>.json` (chunked runs: `$OUTDIR/receipt.<angle>.<chunk>.json`) — a JSON object that proves you actually ran: `{"angle":"<angle>","chunk":<chunk-id-or-null>,"runner":"<host or provider, e.g. claude-code>","model":"<your resolved model — the `Run model` line in the review context>","tier":"<fast|standard|deep — the `Force tier` line>","ts":"<ISO-8601 timestamp>"}`. `runner` and `model` MUST be non-empty. This receipt is how the orchestrator tells "ran and found nothing" (`[]` findings + receipt) apart from "never ran" (no receipt): a review where any angle has no valid receipt HARD-FAILS instead of silently reporting a clean pass. Do NOT pre-create the receipt — write it once, last, after the findings.
```

- [x] **Step 3: Confirm the instruction is present and well-formed**

Run:
```bash
grep -q 'Write your execution receipt as your LAST action' skills/woostack-review/prompts/_header.md && echo OK
grep -q 'receipt.<angle>.json' skills/woostack-review/prompts/_header.md && echo OK2
```
Expected: `OK` then `OK2`.

- [x] **Step 4: Commit**

```bash
gt create -m "feat(woostack-review): require angle workers to write an execution receipt"
```

### Task 2: Add the receipt write to the SKILL Stage-3 sub-agent brief

**Files:**
- Modify: `skills/woostack-review/SKILL.md` (Stage 3 brief code block, ~lines 317-331)

- [x] **Step 1: Verification baseline**

Run: `grep -c "receipt" skills/woostack-review/SKILL.md`
Expected: `0`

- [x] **Step 2: Edit the brief**

In `skills/woostack-review/SKILL.md`, inside the Stage-3 sub-agent brief fenced block, change the final findings sentence. Replace:

```
$OUTDIR/findings.<angle>.json per the schema in _header.md. The file MUST
start with `[` and end with `]` — no preamble, no commentary, no markdown
fences. Before writing each finding's `line` field, validate it via
`bash $WOO_REVIEW_ACTION_PATH/scripts/resolve-diff-line.sh --file <path> --line <N>`
and drop the finding when the helper prints `null` (the line is not anchorable
on the diff's RIGHT side and the GitHub API will reject the comment). EXIT.
```

with:

```
$OUTDIR/findings.<angle>.json per the schema in _header.md. The file MUST
start with `[` and end with `]` — no preamble, no commentary, no markdown
fences. Before writing each finding's `line` field, validate it via
`bash $WOO_REVIEW_ACTION_PATH/scripts/resolve-diff-line.sh --file <path> --line <N>`
and drop the finding when the helper prints `null` (the line is not anchorable
on the diff's RIGHT side and the GitHub API will reject the comment). Then, as
your LAST action, write your execution receipt to
$OUTDIR/receipt.<angle>.json (chunked: $OUTDIR/receipt.<angle>.<chunk>.json) —
a JSON object {angle, chunk, runner, model, tier, ts} with non-empty runner
and model, proving you executed (see _header.md). EXIT.
```

- [x] **Step 3: Confirm**

Run: `grep -q 'write your execution receipt to' skills/woostack-review/SKILL.md && echo OK`
Expected: `OK`

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs(woostack-review): add receipt write to the Stage 3 sub-agent brief"
```

---

## Increment 3: local enforcement — swarm gate + preflight

> One independently shippable PR, stacked above Inc 1 (gate script) and Inc 2 (receipts). Wires the gate into `run-bounded-swarm.sh` and the SKILL orchestrator, adds the local preflight note, and updates/adds the swarm tests.

### Task 1: Wire receipts into `run-bounded-swarm.sh` (retry trigger + final gate)

**Files:**
- Modify: `skills/woostack-review/scripts/run-bounded-swarm.sh` (retry computation ~lines 188-220; tail)

- [x] **Step 1: Write the failing test** (worker writes findings but no receipt → swarm hard-fails after retry)

Create `skills/woostack-review/scripts/tests/test-bounded-swarm-receipts.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/run-bounded-swarm.sh"

# Case A: worker writes findings but NEVER a receipt → swarm gate hard-fails.
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf '%s\n' bugs security > "$work/out/angles.txt"
cat > "$work/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
# Intentionally writes NO receipt.
WORKER
chmod +x "$work/worker.sh"
rc=0
OUTDIR="$work/out" bash "$SCRIPT" --max-concurrency 2 -- "$work/worker.sh" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing receipts → swarm exits non-zero"

# Case B: worker writes findings AND a valid receipt → swarm succeeds.
work2="$(mktemp -d)"
mkdir -p "$work2/out"
printf '%s\n' bugs security > "$work2/out/angles.txt"
cat > "$work2/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t"}\n' "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$work2/worker.sh"
rc=0
OUTDIR="$work2/out" bash "$SCRIPT" --max-concurrency 2 -- "$work2/worker.sh" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "findings + receipts → swarm exits 0"
assert_eq "$(jq -r '.executed_angles | length' "$work2/out/swarm-metrics.json")" "2" "metrics record executed angles"
rm -rf "$work2"
finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-bounded-swarm-receipts.sh`
Expected: FAIL — Case A still exits 0 today (no gate), so `assert_exit 1` fails: `FAIL: missing receipts → swarm exits non-zero (expected exit 1, got 0)`.

- [x] **Step 3: Minimal implementation**

In `skills/woostack-review/scripts/run-bounded-swarm.sh`, replace the first-pass-failed computation block (currently):

```bash
first_pass_failed=()
for item in "${work_items[@]}"; do
  angle="${item%%|*}"
  chunk="${item#*|}"
  if ! is_array_artifact "$angle" "$chunk"; then
    first_pass_failed+=("$item")
  fi
done
```

with a version that also treats a missing/invalid receipt as a failed worker, using `verify-receipts.sh --list-missing` as the receipt authority:

```bash
# Receipts still missing after pass 1 (verify-receipts.sh is the receipt authority).
receipt_missing=()
while IFS= read -r _lbl; do
  [ -n "$_lbl" ] && receipt_missing+=("$_lbl")
done < <(bash "$SCRIPT_DIR/verify-receipts.sh" --list-missing 2>/dev/null || true)

in_list() { # needle list...
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

first_pass_failed=()
for item in "${work_items[@]}"; do
  angle="${item%%|*}"
  chunk="${item#*|}"
  lbl="$(item_label "$angle" "$chunk")"
  if ! is_array_artifact "$angle" "$chunk" || in_list "$lbl" ${receipt_missing[@]+"${receipt_missing[@]}"}; then
    first_pass_failed+=("$item")
  fi
done
```

Then, at the very END of the file (after the `if [ "$degraded" = true ]; then … fi` block that emits the warning), append the hard gate:

```bash

# Single-authority receipt gate. Findings degradation (above) is a soft warning;
# a missing/invalid receipt means an angle never executed → hard-fail the swarm so
# the orchestrator cannot proceed to merge a false-clean review. verify-receipts.sh
# also folds executed_angles / expected_total / missing_receipts into swarm-metrics.json.
bash "$SCRIPT_DIR/verify-receipts.sh"
```

(`set -euo pipefail` at the top propagates `verify-receipts.sh`'s non-zero exit as the swarm's exit code.)

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-bounded-swarm-receipts.sh`
Expected: PASS — `  3 passed, 0 failed`

- [x] **Step 5: Syntax-check**

Run: `bash -n skills/woostack-review/scripts/run-bounded-swarm.sh && echo OK`
Expected: `OK`

- [x] **Step 6: Commit**

```bash
gt create -m "feat(woostack-review): hard-fail the bounded swarm on missing angle receipts"
```

### Task 2: Update `test-bounded-swarm.sh` so its stubs write receipts

**Files:**
- Modify: `skills/woostack-review/scripts/tests/test-bounded-swarm.sh` (three inline worker heredocs)

- [x] **Step 1: Confirm the existing test now fails under the gate**

Run: `bash skills/woostack-review/scripts/tests/test-bounded-swarm.sh`
Expected: FAIL — the worker stubs write no receipts, so `run-bounded-swarm.sh` now exits non-zero at the first invocation (test line ~80), aborting under `set -e` before assertions (e.g. an error like `::error::woostack-review: … did not execute …` and a non-zero test exit).

- [x] **Step 2: Make the stubs write receipts**

In the FIRST worker heredoc (the `case "$WOO_REVIEW_ANGLE"` stub), add a receipt write for every angle. Replace the `case … esac` block:

```bash
case "$WOO_REVIEW_ANGLE" in
  types)
    count_file="$OUTDIR/state/types-count"
    count=0
    if [ -s "$count_file" ]; then
      count="$(cat "$count_file")"
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$count_file"
    if [ "$count" -eq 1 ]; then
      rm -f "$OUTDIR/findings.types.json"
    else
      printf '[]\n' > "$OUTDIR/findings.types.json"
    fi
    ;;
  docs)
    printf '{"not":"array"}\n' > "$OUTDIR/findings.docs.json"
    ;;
  *)
    printf '[]\n' > "$OUTDIR/findings.%s.json" "$WOO_REVIEW_ANGLE"
    ;;
esac
```

with (same logic, plus an always-written receipt so the receipt gate is satisfied — this test exercises the FINDINGS degraded path, which is independent of receipts):

```bash
case "$WOO_REVIEW_ANGLE" in
  types)
    count_file="$OUTDIR/state/types-count"
    count=0
    if [ -s "$count_file" ]; then
      count="$(cat "$count_file")"
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$count_file"
    if [ "$count" -eq 1 ]; then
      rm -f "$OUTDIR/findings.types.json"
    else
      printf '[]\n' > "$OUTDIR/findings.types.json"
    fi
    ;;
  docs)
    printf '{"not":"array"}\n' > "$OUTDIR/findings.docs.json"
    ;;
  *)
    printf '[]\n' > "$OUTDIR/findings.%s.json" "$WOO_REVIEW_ANGLE"
    ;;
esac
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"%s","ts":"t"}\n' \
  "$WOO_REVIEW_ANGLE" "${FORCE_TIER:-standard}" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
```

In the SECOND worker heredoc (`work2`), replace:

```bash
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
```

with:

```bash
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t"}\n' "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
```

In the THIRD worker heredoc (`work3`, chunked), replace:

```bash
printf '%s\n' "$WOO_REVIEW_CHUNK" >> "$OUTDIR/chunks-seen.txt"
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
```

with:

```bash
printf '%s\n' "$WOO_REVIEW_CHUNK" >> "$OUTDIR/chunks-seen.txt"
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
printf '{"angle":"%s","chunk":"%s","runner":"test","model":"test-model","tier":"standard","ts":"t"}\n' "$WOO_REVIEW_ANGLE" "$WOO_REVIEW_CHUNK" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
```

- [x] **Step 3: Run the test, confirm it passes** (degraded/findings assertions intact; gate satisfied)

Run: `bash skills/woostack-review/scripts/tests/test-bounded-swarm.sh`
Expected: PASS — `  N passed, 0 failed` (all existing assertions, e.g. `degraded` is `true` for the `docs` findings case while the swarm still exits 0 because every angle wrote a receipt).

- [x] **Step 4: Commit**

```bash
gt modify -c -m "test(woostack-review): swarm stubs write receipts; degraded path intact"
```

### Task 3: SKILL orchestrator gate + bounded-contract note + local preflight

**Files:**
- Modify: `skills/woostack-review/SKILL.md` (Stage 3 bounded contract ~lines 284-292; after-swarm orchestration; Stage 2→3 boundary)

- [x] **Step 1: Verification baseline**

Run: `grep -c "verify-receipts.sh" skills/woostack-review/SKILL.md`
Expected: `0`

- [x] **Step 2: Add the orchestrator gate after the swarm**

In `skills/woostack-review/SKILL.md`, at the END of the Stage 3 section (immediately before the `### Stage 4 — Merge + Adversarial Validation` heading), add:

```markdown
**Receipt gate (hard fail).** After the swarm finishes — and before `merge-findings.sh` — run:

```bash
bash "$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh"
```

This is the single authority on whether each expected angle actually executed: it hard-fails
(non-zero) and prints an actionable `::error` if any angle in `angles.txt` (× `chunks.txt`) lacks a
valid receipt (`receipt.<angle>[.<chunk>].json` — a JSON object with matching `angle`/`chunk` and
non-empty `runner`+`model`). The shell helper `run-bounded-swarm.sh` already calls this as its final
step; hosts that dispatch workers natively (no shell helper) MUST run it themselves. On non-zero,
**abort the run and surface the error — do NOT proceed to merge/validate/post.** A missing receipt
means that angle never ran, so an empty `findings.json` would be a false clean PASS. This applies in
both PR and local-no-PR modes.
```

- [x] **Step 3: Update bounded-contract step 6 + add the Stage 2→3 preflight note**

In the bounded-execution numbered list, replace the step:

```
6. reset still-invalid artifacts to `[]`;
```

with:

```
6. reset still-invalid *findings* artifacts to `[]`, but treat a missing/invalid *receipt* as a worker that did not execute — after one retry, a still-missing receipt aborts the run (receipts are never pre-initialized; their presence is the proof of execution);
```

Then, at the very start of the Stage 3 section (right after the `**This is the local swarm step.**` paragraph), add a preflight sentence:

```markdown
**Preflight (local).** Before dispatching workers, confirm your host can actually run review
sub-agents (its `Task`/sub-agent primitive is available). If it cannot, stop now with an
actionable error — do not dispatch a swarm that will produce no receipts and then hard-fail the
gate. In the GitHub Action, `detect-provider.sh` performs the equivalent provider/runner preflight.
```

- [x] **Step 4: Confirm all three edits landed**

Run:
```bash
grep -q 'Receipt gate (hard fail)' skills/woostack-review/SKILL.md && echo OK1
grep -q 'still-missing receipt aborts the run' skills/woostack-review/SKILL.md && echo OK2
grep -q 'Preflight (local)' skills/woostack-review/SKILL.md && echo OK3
```
Expected: `OK1`, `OK2`, `OK3`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(woostack-review): orchestrator receipt gate + local preflight in SKILL"
```

---

## Increment 4: CI enforcement — Action gate, receipt upload, retry, provider preflight

> One independently shippable PR, stacked above Inc 1-3. Wires the gate + receipt upload + one-retry into the GitHub Action path and hardens the provider preflight message.

### Task 1: Harden the `detect-provider.sh` preflight message + test

**Files:**
- Modify: `skills/woostack-review/scripts/detect-provider.sh:24-26`
- Test: `skills/woostack-review/scripts/tests/test-detect-provider-preflight.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-detect-provider-preflight.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-provider.sh"

unset INPUT_PROVIDER INPUT_ANTHROPIC_TOKEN INPUT_ANTHROPIC_API_KEY \
      INPUT_OPENAI_API_KEY INPUT_GOOGLE_API_KEY INPUT_GEMINI_API_KEY \
      INPUT_OPENROUTER_API_KEY 2>/dev/null || true

rc=0; err="$(bash "$SCRIPT" 2>&1 1>/dev/null)" || rc=$?
assert_exit 1 "$rc" "no provider/runner → exit 1"
assert_contains "$err" "no model provider/runner resolvable" "actionable preflight message"
assert_contains "$err" "install auth" "message names the auth remedy"
finish
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-detect-provider-preflight.sh`
Expected: FAIL — current message lacks the new phrasing: `FAIL: actionable preflight message`.

- [ ] **Step 3: Update the message**

In `skills/woostack-review/scripts/detect-provider.sh`, replace the empty-provider error line:

```bash
  "")
    echo "::error::No provider resolvable. Set 'provider' input or one of: anthropic_token, openai_api_key, google_api_key, openrouter_api_key."
    exit 1
    ;;
```

with:

```bash
  "")
    echo "::error::woostack-review preflight: no model provider/runner resolvable, so no angle worker can execute. Configure a provider/model (set the 'provider' input), install auth (one of: anthropic_token, openai_api_key, google_api_key, openrouter_api_key), or set the correct runner override. Refusing to run a review that cannot analyze the diff."
    exit 1
    ;;
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-detect-provider-preflight.sh`
Expected: PASS — `  3 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(woostack-review): actionable provider/runner preflight error"
```

### Task 2: Add the CI receipt gate to `action.yml` (validate modes)

**Files:**
- Modify: `action.yml` (insert a step before `Merge findings (validate modes)`, ~line 177)

- [ ] **Step 1: Verification baseline**

Run: `grep -c "verify-receipts.sh" action.yml`
Expected: `0`

- [ ] **Step 2: Insert the gate step**

In `action.yml`, immediately BEFORE the existing step:

```yaml
    - name: Merge findings (validate modes)
      if: steps.prefetch.outputs.skip != 'true' && (inputs.mode == 'validate' || inputs.mode == 'validate-prosecutor')
      shell: bash
      run: bash "${{ github.action_path }}/skills/woostack-review/scripts/merge-findings.sh"
```

insert:

```yaml
    - name: Verify angle receipts (validate modes)
      # Hard-fail BEFORE merge/validate/post if any detected angle produced no valid
      # execution receipt — i.e. a worker never ran. Prevents a false clean PASS when
      # the runner/auth/bridge was absent. Reads angles.txt (× chunks.txt) and the
      # receipt.*.json downloaded with the per-angle findings artifacts.
      if: steps.prefetch.outputs.skip != 'true' && (inputs.mode == 'validate' || inputs.mode == 'validate-prosecutor')
      shell: bash
      run: bash "${{ github.action_path }}/skills/woostack-review/scripts/verify-receipts.sh"
```

- [ ] **Step 3: Confirm placement + YAML validity**

Run:
```bash
grep -q 'Verify angle receipts (validate modes)' action.yml && echo OK
python3 -c "import yaml; yaml.safe_load(open('action.yml')); print('YAML-OK')"
```
Expected: `OK` then `YAML-OK`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "feat(woostack-review): CI receipt gate before validate merge"
```

### Task 3: Upload receipts + one-retry wrapper in `reusable-review.yml`

**Files:**
- Modify: `.github/workflows/reusable-review.yml` (review job: action step ~123-142, upload step ~146-151)

- [ ] **Step 1: Verification baseline**

Run: `grep -c "receipt" .github/workflows/reusable-review.yml`
Expected: `0`

- [ ] **Step 2: Add the receipt glob to the upload step**

In `.github/workflows/reusable-review.yml`, change the per-angle upload step's `path:`. Replace:

```yaml
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7
        with:
          name: findings-${{ matrix.angle }}-${{ matrix.chunk || 'all' }}
          path: /tmp/pr-review/findings.${{ matrix.angle }}*.json
          retention-days: 1
          if-no-files-found: ignore
```

with:

```yaml
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7
        with:
          name: findings-${{ matrix.angle }}-${{ matrix.chunk || 'all' }}
          # Receipts ride alongside findings in the same artifact so the validate
          # job's `pattern: findings-*` + merge-multiple download picks them up,
          # and verify-receipts.sh can prove each angle actually executed.
          path: |
            /tmp/pr-review/findings.${{ matrix.angle }}*.json
            /tmp/pr-review/receipt.${{ matrix.angle }}*.json
          retention-days: 1
          if-no-files-found: ignore
```

- [ ] **Step 3: Add the one-retry wrapper to the review action step**

Replace the review job's single action invocation:

```yaml
      - uses: howarewoo/woostack@main
        with:
          mode: review
          angle: ${{ matrix.angle }}
          chunk: ${{ matrix.chunk }}
          provider: ${{ inputs.provider }}
          model: ${{ inputs.model }}
          force_tier: ${{ inputs.force_tier }}
          anthropic_token: ${{ secrets.anthropic_token }}
          anthropic_api_key: ${{ secrets.anthropic_api_key }}
          openai_api_key: ${{ secrets.openai_api_key }}
          google_api_key: ${{ secrets.google_api_key }}
          gemini_api_key: ${{ secrets.gemini_api_key }}
          openrouter_api_key: ${{ secrets.openrouter_api_key }}
          trigger_phrase: ${{ inputs.trigger_phrase }}
          max_turns: ${{ inputs.max_turns }}
          skip_labels: ${{ inputs.skip_labels }}
          prompt_override: ${{ inputs.prompt_override }}
          react_doctor_version: ${{ inputs.react_doctor_version }}
          impeccable_version: ${{ inputs.impeccable_version }}
```

with two steps — a first attempt that tolerates failure, then a single retry that runs only if the first failed (dependency-free; mirrors the local swarm's one retry so a transient model/rate-limit blip self-heals before the receipt gate):

```yaml
      - name: Run angle review (attempt 1)
        id: review1
        continue-on-error: true
        uses: howarewoo/woostack@main
        with:
          mode: review
          angle: ${{ matrix.angle }}
          chunk: ${{ matrix.chunk }}
          provider: ${{ inputs.provider }}
          model: ${{ inputs.model }}
          force_tier: ${{ inputs.force_tier }}
          anthropic_token: ${{ secrets.anthropic_token }}
          anthropic_api_key: ${{ secrets.anthropic_api_key }}
          openai_api_key: ${{ secrets.openai_api_key }}
          google_api_key: ${{ secrets.google_api_key }}
          gemini_api_key: ${{ secrets.gemini_api_key }}
          openrouter_api_key: ${{ secrets.openrouter_api_key }}
          trigger_phrase: ${{ inputs.trigger_phrase }}
          max_turns: ${{ inputs.max_turns }}
          skip_labels: ${{ inputs.skip_labels }}
          prompt_override: ${{ inputs.prompt_override }}
          react_doctor_version: ${{ inputs.react_doctor_version }}
          impeccable_version: ${{ inputs.impeccable_version }}
      - name: Run angle review (retry once)
        if: steps.review1.outcome == 'failure'
        uses: howarewoo/woostack@main
        with:
          mode: review
          angle: ${{ matrix.angle }}
          chunk: ${{ matrix.chunk }}
          provider: ${{ inputs.provider }}
          model: ${{ inputs.model }}
          force_tier: ${{ inputs.force_tier }}
          anthropic_token: ${{ secrets.anthropic_token }}
          anthropic_api_key: ${{ secrets.anthropic_api_key }}
          openai_api_key: ${{ secrets.openai_api_key }}
          google_api_key: ${{ secrets.google_api_key }}
          gemini_api_key: ${{ secrets.gemini_api_key }}
          openrouter_api_key: ${{ secrets.openrouter_api_key }}
          trigger_phrase: ${{ inputs.trigger_phrase }}
          max_turns: ${{ inputs.max_turns }}
          skip_labels: ${{ inputs.skip_labels }}
          prompt_override: ${{ inputs.prompt_override }}
          react_doctor_version: ${{ inputs.react_doctor_version }}
          impeccable_version: ${{ inputs.impeccable_version }}
```

- [ ] **Step 4: Confirm edits + YAML validity**

Run:
```bash
grep -q 'receipt.${{ matrix.angle }}' .github/workflows/reusable-review.yml && echo OK1
grep -q 'Run angle review (retry once)' .github/workflows/reusable-review.yml && echo OK2
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/reusable-review.yml')); print('YAML-OK')"
```
Expected: `OK1`, `OK2`, `YAML-OK`.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(woostack-review): CI uploads receipts + one-retry per angle job"
```

### Task 4: Full review test sweep

**Files:** (none — verification only)

- [ ] **Step 1: Run every woostack-review shell test**

Run:
```bash
for t in skills/woostack-review/scripts/tests/test-*.sh; do
  echo "== $t"; bash "$t" || { echo "FAILED: $t"; exit 1; }
done
echo ALL-GREEN
```
Expected: each test prints `  N passed, 0 failed`; final line `ALL-GREEN`.

- [ ] **Step 2: Commit (only if the sweep surfaced a fixable nit)**

```bash
gt modify -c -m "test(woostack-review): green full receipt + swarm test sweep"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — receipt mechanism (Inc 1 contract + Inc 2 write), `verify-receipts.sh` single authority + `--list-missing` (Inc 1), strictness/every-angle + swarm hard-fail + retry-trigger extension + receipts-never-pre-initialized (Inc 3 Task 1), preflight light/local + GHA message (Inc 3 Task 3, Inc 4 Task 1), CI gate + receipt upload + one-retry + line-156 reversal (Inc 4 Tasks 2-3), all tests incl. updated `test-bounded-swarm.sh` (Inc 1-4). Non-goals respected: findings schema unchanged, validator-`degraded` axis untouched, no live API probe, merge/intersect unchanged.
- [ ] **No placeholders** — every step has complete code/edit text + exact command + expected output.
- [ ] **Type/contract consistency** — receipt object shape `{angle, chunk, runner, model, tier, ts}` identical across `_header.md`, the SKILL brief, every test stub, and `verify-receipts.sh`'s `is_valid_receipt` (matching `angle`/`chunk`, non-empty `runner`+`model`). Artifact paths `receipt.<angle>.json` / `receipt.<angle>.<chunk>.json` consistent everywhere. `verify-receipts.sh` invoked via `$SCRIPT_DIR/verify-receipts.sh` (swarm) and `${{ github.action_path }}/skills/woostack-review/scripts/verify-receipts.sh` (Action). Portable bash (no `mapfile`; `set -u`-safe array expansions).

> woostack plan conventions: frontmatter-free; opens with the `**Source:**` line; filename mirrors the spec basename (`2026-06-06-review-fail-fast-receipts.md`); no required-sub-skill banner; in this skills repo a "failing test" is a shell test or a `grep`/`bash -n`/`python3 -c yaml` verification with exact expected output. Execution is `woostack-execute`'s job (woostack-build step 9, or `/woostack-execute <plan>`).
