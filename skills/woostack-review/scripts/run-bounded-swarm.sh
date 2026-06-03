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
  local queue=("$@")
  local active=0
  local pids=()
  local pid
  local angle

  for angle in "${queue[@]}"; do
    run_worker "$angle" &
    pid=$!
    pids+=("$pid")
    active=$((active + 1))

    if [ "$active" -ge "$max_concurrency" ]; then
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

run_queue "${angles[@]}"

first_pass_failed=()
for angle in "${angles[@]}"; do
  if ! is_array_artifact "$angle"; then
    first_pass_failed+=("$angle")
  fi
done

retry_angles=()
if [ "${#first_pass_failed[@]}" -gt 0 ]; then
  retry_angles=("${first_pass_failed[@]}")
fi
if [ "${#retry_angles[@]}" -gt 0 ]; then
  for angle in "${retry_angles[@]}"; do
    printf '[]\n' > "$OUTDIR/findings.$angle.json"
  done
  run_queue "${retry_angles[@]}"
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
