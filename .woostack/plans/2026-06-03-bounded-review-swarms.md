---
type: plan
source: .woostack/specs/2026-06-03-bounded-review-swarms.md
status: done
branch: feature/bounded-review-swarms
---

**Source:** .woostack/specs/2026-06-03-bounded-review-swarms.md


# Bounded Review Swarms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded local `/woostack-review` swarm execution so constrained hosts run every detected angle, retry bad artifacts once, preserve tier/model context, and report degraded coverage.

**Architecture:** Add one focused shell helper that owns queueing and artifact validation for local shell-capable hosts. Update `woostack-review/SKILL.md` so bounded Stage 3 is the default local orchestration contract, while CI matrix behavior stays unchanged. Cover behavior with deterministic bash tests using fake workers.

**Tech Stack:** Bash, `jq`, existing woostack review script layout, existing `skills/woostack-init/scripts/tests/assert.sh` assertions.

---

## File structure

- Create: `skills/woostack-review/scripts/run-bounded-swarm.sh`
  - Responsibility: local bounded queue runner for angle workers; initializes expected artifacts; preserves environment; retries invalid artifacts once; writes `$OUTDIR/swarm-metrics.json`.
- Create: `skills/woostack-review/scripts/tests/test-bounded-swarm.sh`
  - Responsibility: deterministic unit-style coverage for queueing, retry, degraded metadata, and tier propagation using fake workers.
- Modify: `skills/woostack-review/SKILL.md`
  - Responsibility: replace unbounded local Stage 3 guidance with default bounded local orchestration, document helper usage, retry contract, metadata, tier/model propagation, and summary disclosure.

## Task 1: Add the bounded swarm helper

**Files:**
- Create: `skills/woostack-review/scripts/run-bounded-swarm.sh`

- [x] **Step 1: Write the helper script**

Create `skills/woostack-review/scripts/run-bounded-swarm.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run-bounded-swarm.sh [--max-concurrency N] -- <worker command...>

Runs detected woostack-review angles from $OUTDIR/angles.txt with bounded
concurrency. For each worker, exports WOO_REVIEW_ANGLE plus the caller's
existing OUTDIR, WOO_REVIEW_ACTION_PATH, FORCE_TIER, provider/model env, and
other review env. The worker must write $OUTDIR/findings.$WOO_REVIEW_ANGLE.json.

Max concurrency precedence: --max-concurrency, WOO_REVIEW_MAX_CONCURRENCY, 6.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"

max_concurrency="${WOO_REVIEW_MAX_CONCURRENCY:-6}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --max-concurrency)
      if [ "$#" -lt 2 ]; then
        echo "::error::--max-concurrency requires a value" >&2
        exit 2
      fi
      max_concurrency="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "::error::unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  echo "::error::worker command is required after --" >&2
  usage >&2
  exit 2
fi

case "$max_concurrency" in
  ''|*[!0-9]*)
    echo "::error::max concurrency must be a positive integer, got: $max_concurrency" >&2
    exit 2
    ;;
esac
if [ "$max_concurrency" -lt 1 ]; then
  echo "::error::max concurrency must be >= 1, got: $max_concurrency" >&2
  exit 2
fi

angles_file="$OUTDIR/angles.txt"
if [ ! -s "$angles_file" ]; then
  echo "::error::missing or empty angles file: $angles_file" >&2
  exit 2
fi

mapfile -t angles < <(grep -v '^[[:space:]]*$' "$angles_file")
if [ "${#angles[@]}" -eq 0 ]; then
  echo "::error::no angles found in $angles_file" >&2
  exit 2
fi

worker_cmd=("$@")
mkdir -p "$OUTDIR"

for angle in "${angles[@]}"; do
  printf '[]\n' > "$OUTDIR/findings.$angle.json"
done

is_array_artifact() {
  local angle="$1"
  local file="$OUTDIR/findings.$angle.json"
  [ -s "$file" ] && jq -e 'type == "array"' "$file" >/dev/null 2>&1
}

run_worker() {
  local angle="$1"
  (
    export WOO_REVIEW_ANGLE="$angle"
    "${worker_cmd[@]}"
  )
}

run_queue() {
  local -n queue_ref="$1"
  local active=0
  local pids=()
  local pid
  local angle

  for angle in "${queue_ref[@]}"; do
    run_worker "$angle" &
    pid=$!
    pids+=("$pid")
    active=$((active + 1))

    if [ "$active" -ge "$max_concurrency" ]; then
      if ! wait "${pids[0]}"; then
        true
      fi
      pids=("${pids[@]:1}")
      active=$((active - 1))
    fi
  done

  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      true
    fi
  done
}

run_queue angles

first_pass_failed=()
for angle in "${angles[@]}"; do
  if ! is_array_artifact "$angle"; then
    first_pass_failed+=("$angle")
  fi
done

retry_angles=("${first_pass_failed[@]}")
if [ "${#retry_angles[@]}" -gt 0 ]; then
  for angle in "${retry_angles[@]}"; do
    printf '[]\n' > "$OUTDIR/findings.$angle.json"
  done
  run_queue retry_angles
fi

still_invalid=()
for angle in "${angles[@]}"; do
  if ! is_array_artifact "$angle"; then
    still_invalid+=("$angle")
    printf '[]\n' > "$OUTDIR/findings.$angle.json"
  fi
done

json_array() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return
  fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}

first_pass_json="$(json_array "${first_pass_failed[@]}")"
retry_json="$(json_array "${retry_angles[@]}")"
still_invalid_json="$(json_array "${still_invalid[@]}")"
degraded=false
if [ "${#still_invalid[@]}" -gt 0 ]; then
  degraded=true
fi

jq -n \
  --argjson max "$max_concurrency" \
  --argjson total "${#angles[@]}" \
  --argjson first "$first_pass_json" \
  --argjson retry "$retry_json" \
  --argjson invalid "$still_invalid_json" \
  --argjson degraded "$degraded" \
  '{
    schema_version: 1,
    mode: "bounded",
    max_concurrency: $max,
    angles_total: $total,
    first_pass_failed: $first,
    retry_angles: $retry,
    still_invalid: $invalid,
    degraded: $degraded
  }' > "$OUTDIR/swarm-metrics.json"

if [ "$degraded" = true ]; then
  echo "::warning::bounded swarm degraded; invalid angle artifacts after retry: ${still_invalid[*]}" >&2
fi
```

- [x] **Step 2: Make the helper executable**

Run:

```bash
chmod +x skills/woostack-review/scripts/run-bounded-swarm.sh
```

Expected: command exits `0`.

## Task 2: Add bounded swarm tests

**Files:**
- Create: `skills/woostack-review/scripts/tests/test-bounded-swarm.sh`

- [x] **Step 1: Write the test script**

Create `skills/woostack-review/scripts/tests/test-bounded-swarm.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/run-bounded-swarm.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf '%s\n' bugs security types architecture docs > "$work/out/angles.txt"

cat > "$work/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$OUTDIR/state"
active_file="$OUTDIR/state/active"
max_file="$OUTDIR/state/max"
: > "$OUTDIR/state/tier.$WOO_REVIEW_ANGLE"
printf '%s\n' "${FORCE_TIER:-}" > "$OUTDIR/state/tier.$WOO_REVIEW_ANGLE"
(
  flock 9
  active=0
  if [ -s "$active_file" ]; then
    active="$(cat "$active_file")"
  fi
  active=$((active + 1))
  printf '%s\n' "$active" > "$active_file"
  max=0
  if [ -s "$max_file" ]; then
    max="$(cat "$max_file")"
  fi
  if [ "$active" -gt "$max" ]; then
    printf '%s\n' "$active" > "$max_file"
  fi
) 9>"$OUTDIR/state/lock"

sleep 0.15

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

(
  flock 9
  active="$(cat "$active_file")"
  active=$((active - 1))
  printf '%s\n' "$active" > "$active_file"
) 9>"$OUTDIR/state/lock"
WORKER
chmod +x "$work/worker.sh"

OUTDIR="$work/out" FORCE_TIER=deep \
  bash "$SCRIPT" --max-concurrency 2 -- "$work/worker.sh"

assert_eq "$(cat "$work/out/state/max")" "2" "max concurrency respected"
assert_eq "$(cat "$work/out/state/types-count")" "2" "missing artifact retried once after drain"
assert_eq "$(jq -r '.mode' "$work/out/swarm-metrics.json")" "bounded" "metrics mode is bounded"
assert_eq "$(jq -r '.max_concurrency' "$work/out/swarm-metrics.json")" "2" "metrics record concurrency"
assert_eq "$(jq -r '.angles_total' "$work/out/swarm-metrics.json")" "5" "metrics record angle count"
assert_eq "$(jq -r '.retry_angles | index("types") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried missing angle"
assert_eq "$(jq -r '.retry_angles | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried non-array angle"
assert_eq "$(jq -r '.still_invalid | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record still-invalid angle"
assert_eq "$(jq -r '.degraded' "$work/out/swarm-metrics.json")" "true" "metrics record degradation"
assert_eq "$(jq -r 'type' "$work/out/findings.docs.json")" "array" "still-invalid artifact reset to array"

for angle in bugs security types architecture docs; do
  assert_eq "$(cat "$work/out/state/tier.$angle")" "deep" "FORCE_TIER propagated to $angle"
done

# Environment override is used when no CLI flag is supplied.
work2="$(mktemp -d)"
mkdir -p "$work2/out"
printf '%s\n' bugs security > "$work2/out/angles.txt"
cat > "$work2/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$work2/worker.sh"
OUTDIR="$work2/out" WOO_REVIEW_MAX_CONCURRENCY=1 bash "$SCRIPT" -- "$work2/worker.sh"
assert_eq "$(jq -r '.max_concurrency' "$work2/out/swarm-metrics.json")" "1" "env concurrency override used"
rm -rf "$work2"

finish
```

- [x] **Step 2: Make the test executable**

Run:

```bash
chmod +x skills/woostack-review/scripts/tests/test-bounded-swarm.sh
```

Expected: command exits `0`.

- [x] **Step 3: Run the new test**

Run:

```bash
bash skills/woostack-review/scripts/tests/test-bounded-swarm.sh
```

Expected: PASS output from `finish`, with no failed assertions.

## Task 3: Update Stage 3 and reporting guidance

**Files:**
- Modify: `skills/woostack-review/SKILL.md`

- [x] **Step 1: Replace the Stage 3 opening with bounded local orchestration**

In `skills/woostack-review/SKILL.md`, replace the Stage 3 title and opening guidance with text equivalent to:

```markdown
### Stage 3 — Run Bounded Review Swarm (one per angle, × chunk if chunked)

**This is the local swarm step.** Local hosts MUST use bounded execution by default whenever more than one angle or `(angle, chunk)` pair is detected. The default concurrency limit is `6`, because several local hosts can spawn parallel sub-agents but cap active workers below the detected angle count. Set max concurrency to `1` for the sequential fallback.

Bounded execution means:

1. read the expected work items from `$OUTDIR/angles.txt` and, when chunking is active, `$OUTDIR/chunks.txt`;
2. initialize every expected findings artifact to `[]` before workers start;
3. run at most `N` workers at once;
4. drain the full first-pass queue;
5. retry missing, empty, invalid-JSON, or non-array artifacts once after the queue drains;
6. reset still-invalid artifacts to `[]`;
7. write `$OUTDIR/swarm-metrics.json` so the summary can disclose bounded mode and degraded coverage.

For unchunked reviews, the expected artifact is `$OUTDIR/findings.<angle>.json`. For chunked reviews, the expected artifact is `$OUTDIR/findings.<angle>.<chunk_id>.json`.
```

Keep the existing host examples, but revise them so they describe host-native bounded queues instead of unrestricted one-call-per-angle parallelism.

- [x] **Step 2: Add helper usage guidance**

Add a subsection near the Stage 3 brief:

```markdown
**Shell helper path.** Shell-capable local hosts can use the shipped bounded queue runner:

```bash
bash "$WOO_REVIEW_ACTION_PATH/scripts/run-bounded-swarm.sh" \
  --max-concurrency "${WOO_REVIEW_MAX_CONCURRENCY:-6}" \
  -- <worker command...>
```

The helper exports `WOO_REVIEW_ANGLE` for each worker and preserves the caller's existing environment, including `OUTDIR`, `WOO_REVIEW_ACTION_PATH`, `FORCE_TIER`, provider/model variables, and review config/input variables. The worker command must write `$OUTDIR/findings.$WOO_REVIEW_ANGLE.json`.

When a host cannot express sub-agent work as a shell command, implement the same bounded queue natively with the host's task/sub-agent API.
```

Do not claim the helper can directly spawn Codex/Claude/Gemini sub-agents unless the host provides a shell command for that.

- [x] **Step 3: Preserve tier/model routing guidance**

In the Stage 3 model-routing section, add this invariant:

```markdown
Bounded runners MUST preserve the resolved tier/model context for every queued worker. In single-model hosts, pass the resolved run-tier (`FORCE_TIER` when set, otherwise the host's standard tier) to every worker. In per-call-routing hosts, apply each angle prompt's `tier:` while still preserving any explicit `FORCE_TIER` override. Bounded scheduling must not cause later queued angles to fall back to default model settings.
```

- [x] **Step 4: Add summary disclosure guidance**

In Stage 5 local reporting guidance, add:

```markdown
If `$OUTDIR/swarm-metrics.json` exists, include a one-line swarm summary. Mention bounded mode and `max_concurrency`. If `.degraded == true`, name the `still_invalid` angles or `(angle, chunk)` items and state that those artifacts contributed `[]` after one retry.
```

- [x] **Step 5: Update troubleshooting**

Update the existing troubleshooting entry for dead sub-agents to reference `swarm-metrics.json` and bounded retry behavior:

```markdown
- **Sub-agent died mid-run and left no findings artifact** — bounded Stage 3 initializes expected artifacts to `[]`, retries missing/non-array artifacts once after the first queue drains, then records remaining gaps in `$OUTDIR/swarm-metrics.json`. If `.degraded == true`, that angle contributed `[]` and the local summary must disclose it.
```

## Task 4: Run focused verification

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-bounded-swarm.sh`

- [x] **Step 1: Run the bounded swarm test**

Run:

```bash
bash skills/woostack-review/scripts/tests/test-bounded-swarm.sh
```

Expected: PASS output from `finish`, with no failed assertions.

- [x] **Step 2: Run one existing adjacent script test**

Run:

```bash
bash skills/woostack-review/scripts/tests/test-memory-record.sh
```

Expected: PASS output from `finish`, with no failed assertions.

## Task 5: Commit-sized review checkpoint

**Files:**
- `skills/woostack-review/scripts/run-bounded-swarm.sh`
- `skills/woostack-review/scripts/tests/test-bounded-swarm.sh`
- `skills/woostack-review/SKILL.md`
- `.woostack/specs/2026-06-03-bounded-review-swarms.md`
- `.woostack/plans/2026-06-03-bounded-review-swarms.md`

- [x] **Step 1: Inspect the resulting diff manually**

Run:

```bash
git diff -- skills/woostack-review/scripts/run-bounded-swarm.sh skills/woostack-review/scripts/tests/test-bounded-swarm.sh skills/woostack-review/SKILL.md .woostack/specs/2026-06-03-bounded-review-swarms.md .woostack/plans/2026-06-03-bounded-review-swarms.md
```

Expected: diff contains only the helper, tests, review-skill docs, spec, and plan.

- [x] **Step 2: Commit if requested by the user**

Only if the user asks to commit, use the repo's Graphite-preferred flow from `AGENTS.md`. Do not merge.
