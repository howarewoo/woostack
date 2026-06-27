#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run-bounded-swarm.sh [--max-concurrency N] -- <worker command...>

Runs detected woostack-review work items from $OUTDIR/angles.txt and, when
present, $OUTDIR/chunks.txt. By default it starts every work item and lets the
host manage scheduling pressure; pass a cap for explicit bounded concurrency.
For each worker, exports
WOO_REVIEW_ANGLE and WOO_REVIEW_CHUNK plus the caller's existing OUTDIR,
WOO_REVIEW_ACTION_PATH, FORCE_TIER, provider/model env, and other review env.
The worker must write $OUTDIR/findings.$WOO_REVIEW_ANGLE.json when unchunked,
or $OUTDIR/findings.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json when chunked.

Max concurrency precedence: --max-concurrency, WOO_REVIEW_MAX_CONCURRENCY, unset.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"

max_concurrency="${WOO_REVIEW_MAX_CONCURRENCY:-}"
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
  '')
    ;;
  *[!0-9]*)
    echo "::error::max concurrency must be a positive integer, got: $max_concurrency" >&2
    exit 2
    ;;
esac
if [ -n "$max_concurrency" ]; then
  if [ "$max_concurrency" -lt 1 ]; then
    echo "::error::max concurrency must be >= 1, got: $max_concurrency" >&2
    exit 2
  fi
fi

angles_file="$OUTDIR/angles.txt"
if [ ! -s "$angles_file" ]; then
  echo "::error::missing or empty angles file: $angles_file" >&2
  exit 2
fi

angles=()
while IFS= read -r angle; do
  if [ -n "$angle" ]; then
    angles+=("$angle")
  fi
done < "$angles_file"
if [ "${#angles[@]}" -eq 0 ]; then
  echo "::error::no angles found in $angles_file" >&2
  exit 2
fi

chunks=("")
chunks_file="$OUTDIR/chunks.txt"
if [ -s "$chunks_file" ]; then
  chunks=()
  while IFS= read -r chunk; do
    if [ -n "$chunk" ]; then
      chunks+=("$chunk")
    fi
  done < "$chunks_file"
  if [ "${#chunks[@]}" -eq 0 ]; then
    chunks=("")
  fi
fi

work_items=()
for angle in "${angles[@]}"; do
  for chunk in "${chunks[@]}"; do
    work_items+=("$angle|$chunk")
  done
done

worker_cmd=("$@")
mkdir -p "$OUTDIR"

artifact_path() {
  local angle="$1"
  local chunk="$2"
  if [ -n "$chunk" ]; then
    printf '%s/findings.%s.%s.json' "$OUTDIR" "$angle" "$chunk"
  else
    printf '%s/findings.%s.json' "$OUTDIR" "$angle"
  fi
}

item_label() {
  local angle="$1"
  local chunk="$2"
  if [ -n "$chunk" ]; then
    printf '%s.%s' "$angle" "$chunk"
  else
    printf '%s' "$angle"
  fi
}

for item in "${work_items[@]}"; do
  angle="${item%%|*}"
  chunk="${item#*|}"
  printf '[]\n' > "$(artifact_path "$angle" "$chunk")"
done

is_array_artifact() {
  local angle="$1"
  local chunk="$2"
  local file
  file="$(artifact_path "$angle" "$chunk")"
  [ -s "$file" ] && jq -e 'type == "array"' "$file" >/dev/null 2>&1
}

normalize_artifact() {
  local angle="$1"
  local chunk="$2"
  local file
  local tmp
  file="$(artifact_path "$angle" "$chunk")"
  if [ ! -s "$file" ]; then
    return 1
  fi
  if jq -e 'type == "array"' "$file" >/dev/null 2>&1; then
    return 0
  fi
  # Common LLM mistake: emit one finding object instead of a one-element array.
  # Recover only objects that look like real findings; arbitrary objects remain
  # invalid and go through the retry/degrade path.
  if jq -e 'type == "object" and has("file") and has("line") and has("title") and has("description") and has("fix")' "$file" >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq '[.]' "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "::warning::bounded swarm recovered single finding object as array: $(item_label "$angle" "$chunk")" >&2
    return 0
  fi
  return 1
}

run_worker() {
  local item="$1"
  local angle="${item%%|*}"
  local chunk="${item#*|}"
  (
    export WOO_REVIEW_ANGLE="$angle"
    export WOO_REVIEW_CHUNK="$chunk"
    "${worker_cmd[@]}"
  )
}

run_queue() {
  local queue=("$@")
  local active=0
  local pids=()
  local pid
  local angle

  for item in "${queue[@]}"; do
    run_worker "$item" &
    pid=$!
    pids+=("$pid")
    active=$((active + 1))

    if [ -n "$max_concurrency" ] && [ "$active" -ge "$max_concurrency" ]; then
      if ! wait "${pids[0]}"; then
        true
      fi
      if [ "${#pids[@]}" -gt 1 ]; then
        pids=("${pids[@]:1}")
      else
        pids=()
      fi
      active=$((active - 1))
    fi
  done

  if [ "${#pids[@]}" -gt 0 ]; then
    for pid in "${pids[@]}"; do
      if ! wait "$pid"; then
        true
      fi
    done
  fi
}

run_queue "${work_items[@]}"

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
  if ! normalize_artifact "$angle" "$chunk" || in_list "$lbl" ${receipt_missing[@]+"${receipt_missing[@]}"}; then
    first_pass_failed+=("$item")
  fi
done

retry_angles=()
if [ "${#first_pass_failed[@]}" -gt 0 ]; then
  retry_angles=("${first_pass_failed[@]}")
fi
if [ "${#retry_angles[@]}" -gt 0 ]; then
  for item in "${retry_angles[@]}"; do
    angle="${item%%|*}"
    chunk="${item#*|}"
    printf '[]\n' > "$(artifact_path "$angle" "$chunk")"
  done
  run_queue "${retry_angles[@]}"
fi

still_invalid=()
for item in "${work_items[@]}"; do
  angle="${item%%|*}"
  chunk="${item#*|}"
  if ! normalize_artifact "$angle" "$chunk"; then
    still_invalid+=("$item")
    printf '[]\n' > "$(artifact_path "$angle" "$chunk")"
  fi
done

json_array() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return
  fi
  for item in "$@"; do
    angle="${item%%|*}"
    chunk="${item#*|}"
    item_label "$angle" "$chunk"
    printf '\n'
  done | jq -R . | jq -s .
}

label_list() {
  if [ "$#" -eq 0 ]; then
    return
  fi
  local labels=()
  local item
  local angle
  local chunk
  for item in "$@"; do
    angle="${item%%|*}"
    chunk="${item#*|}"
    labels+=("$(item_label "$angle" "$chunk")")
  done
  printf '%s' "${labels[*]}"
}

first_pass_json="[]"
if [ "${#first_pass_failed[@]}" -gt 0 ]; then
  first_pass_json="$(json_array "${first_pass_failed[@]}")"
fi
retry_json="[]"
if [ "${#retry_angles[@]}" -gt 0 ]; then
  retry_json="$(json_array "${retry_angles[@]}")"
fi
still_invalid_json="[]"
if [ "${#still_invalid[@]}" -gt 0 ]; then
  still_invalid_json="$(json_array "${still_invalid[@]}")"
fi
degraded=false
if [ "${#still_invalid[@]}" -gt 0 ]; then
  degraded=true
fi

if [ -n "$max_concurrency" ]; then
  max_concurrency_json="$max_concurrency"
  swarm_mode="bounded"
else
  max_concurrency_json="null"
  swarm_mode="host-managed"
fi

jq -n \
  --argjson max "$max_concurrency_json" \
  --arg mode "$swarm_mode" \
  --argjson angles_total "${#angles[@]}" \
  --argjson chunks_total "${#chunks[@]}" \
  --argjson work_items_total "${#work_items[@]}" \
  --argjson first "$first_pass_json" \
  --argjson retry "$retry_json" \
  --argjson invalid "$still_invalid_json" \
  --argjson degraded "$degraded" \
  '{
    schema_version: 1,
    mode: $mode,
    max_concurrency: $max,
    angles_total: $angles_total,
    chunks_total: $chunks_total,
    work_items_total: $work_items_total,
    first_pass_failed: $first,
    retry_angles: $retry,
    still_invalid: $invalid,
    degraded: $degraded
  }' > "$OUTDIR/swarm-metrics.json"

if [ "$degraded" = true ]; then
  echo "::warning::bounded swarm degraded; invalid angle artifacts after retry: $(label_list "${still_invalid[@]}")" >&2
fi

# Single-authority receipt gate. Findings degradation (above) is a soft warning;
# a missing/invalid receipt means an angle never executed → hard-fail the swarm so
# the orchestrator cannot proceed to merge a false-clean review. verify-receipts.sh
# also folds executed_angles / expected_total / missing_receipts into swarm-metrics.json.
bash "$SCRIPT_DIR/verify-receipts.sh"
