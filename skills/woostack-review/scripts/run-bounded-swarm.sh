#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run-bounded-swarm.sh [--max-concurrency N] -- <worker command...>

Runs detected woostack-review work items from $OUTDIR/angles.txt and, when
present, $OUTDIR/chunks.txt. By default it starts every work item and lets the
host manage scheduling pressure; pass a cap for explicit bounded concurrency.
For each worker, exports WOO_REVIEW_ANGLE and WOO_REVIEW_CHUNK. Generic runs
retain the caller environment. With WOO_REVIEW_ENGINEER_UNIT=true, each worker
starts in OUTDIR with a fresh HOME/XDG/TMPDIR and an allowlisted environment:
PATH/locale, OUTDIR/action path, tier/model routing, and known provider API
variables plus any comma-separated names explicitly listed in
WOO_REVIEW_PROVIDER_ENV. Linear/GitHub-write/SSH/Git/profile contexts are absent.
The worker must write $OUTDIR/findings.$WOO_REVIEW_ANGLE.json when unchunked, or
$OUTDIR/findings.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json when chunked.

Max concurrency precedence: --max-concurrency, WOO_REVIEW_MAX_CONCURRENCY, unset.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"

engineer_unit=false
case "${WOO_REVIEW_ENGINEER_UNIT:-}" in
  1|true|yes) engineer_unit=true ;;
  0|false|no|"") ;;
  *)
    echo "::error::WOO_REVIEW_ENGINEER_UNIT must be true/false (or 1/0)" >&2
    exit 2
    ;;
esac

engineer_repo_root=""
engineer_repo_fingerprint_before=""
engineer_identity_manifest=""
engineer_identity_manifest_hash_before=""
engineer_worker_root=""
if [ "$engineer_unit" = true ]; then
  engineer_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "::error::engineer-unit swarm requires a Git worktree for mutation fingerprinting" >&2
    exit 2
  }
  engineer_repo_root="$(cd "$engineer_repo_root" && pwd -P)"
  if [ -d "$OUTDIR" ]; then
    engineer_outdir="$(cd "$OUTDIR" && pwd -P)"
  else
    engineer_outdir_parent="$(dirname "$OUTDIR")"
    [ -d "$engineer_outdir_parent" ] || {
      echo "::error::engineer-unit OUTDIR parent must already exist outside the implementation repository/worktree" >&2
      exit 2
    }
    engineer_outdir="$(cd "$engineer_outdir_parent" && pwd -P)/$(basename "$OUTDIR")"
  fi
  case "$engineer_outdir/" in
    "$engineer_repo_root/"*)
      echo "::error::engineer-unit OUTDIR must be outside the implementation repository/worktree" >&2
      exit 2
      ;;
  esac
fi

review_provider_env=(
  ANTHROPIC_API_KEY
  OPENAI_API_KEY
  OPENAI_BASE_URL
  AZURE_OPENAI_API_KEY
  AZURE_OPENAI_ENDPOINT
  GOOGLE_API_KEY
  GEMINI_API_KEY
  OPENROUTER_API_KEY
  AI_GATEWAY_API_KEY
)

if [ "$engineer_unit" = true ] && [ -n "${WOO_REVIEW_PROVIDER_ENV:-}" ]; then
  IFS=',' read -r -a extra_provider_env <<< "$WOO_REVIEW_PROVIDER_ENV"
  for name in "${extra_provider_env[@]}"; do
    case "$name" in
      ""|[0-9]*|*[!A-Za-z0-9_]*)
        echo "::error::invalid variable name in WOO_REVIEW_PROVIDER_ENV: $name" >&2
        exit 2
        ;;
      LINEAR_*|GH_*|GITHUB_*|GIT_*|GRAPHITE_*|SSH_*|HERMES_*|OMP_*|CLAUDE_*|CODEX_*|OPENCODE_*|BROWSER_*|XDG_*|WOO_REVIEW_*|HOME|TMPDIR|PWD|OLDPWD|SHELL|USER|LOGNAME|PATH|TERM|CI|FORCE_TIER|INPUT_MODEL|*PROFILE*|*SESSION*|*PRINCIPAL*|*CREDENTIAL*|*TOKEN_CACHE*|*TOKEN_STORE*|*AUTH_CONTEXT*|*MCP*|*OAUTH*)
        echo "::error::WOO_REVIEW_PROVIDER_ENV may name provider-only variables, not host/reviewer/Git credentials or contexts: $name" >&2
        exit 2
        ;;
      *) review_provider_env+=("$name") ;;
    esac
  done
fi
repository_fingerprint() { # repository root
  local root="$1" branch head staged unstaged untracked
  branch="$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')"
  head="$(git -C "$root" rev-parse --verify 'HEAD^{commit}')" || return 1
  staged="$(git -C "$root" diff --binary --full-index --no-ext-diff --cached | git hash-object --stdin)" || return 1
  unstaged="$(git -C "$root" diff --binary --full-index --no-ext-diff | git hash-object --stdin)" || return 1
  untracked="$({
    while IFS= read -r -d '' path; do
      path_base64="$(printf '%s' "$path" | base64 | tr -d '\n')"
      object="$(git -C "$root" hash-object --no-filters -- "$path")" || exit 1
      printf '%s\t%s\n' "$path_base64" "$object"
    done < <(LC_ALL=C git -C "$root" ls-files --others --exclude-standard -z)
  } | jq -Rn '[inputs | split("\t") | {pathBase64: .[0], object: .[1]}]')" || return 1

  jq -cn \
    --arg branch "$branch" \
    --arg head "$head" \
    --arg staged "$staged" \
    --arg unstaged "$unstaged" \
    --argjson untracked "$untracked" \
    '{branch:$branch,head:$head,staged:$staged,unstaged:$unstaged,untracked:$untracked}' |
    git hash-object --stdin
}


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
    if [ "$engineer_unit" = true ]; then
      controller_outdir="$OUTDIR"
      worker_outdir="$(mktemp -d "$engineer_worker_root/work.XXXXXX")"
      worker_outdir="$(cd "$worker_outdir" && pwd -P)"
      cp -R "$controller_outdir/." "$worker_outdir/"
      rm -f \
        "$worker_outdir"/findings.*.json \
        "$worker_outdir"/receipt.*.json \
        "$worker_outdir"/reviewer-identities.json
      jq -e --arg angle "$angle" --arg chunk "$chunk" '
        [
          .reviewers[]
          | select(
              .angle == $angle
              and (
                (($chunk == "") and ((.chunk == null) or (.chunk == "")))
                or (.chunk == $chunk)
              )
            )
        ]
        | if length == 1 then .[0] else error("missing exact worker binding") end
      ' "$engineer_identity_manifest" > "$worker_outdir/reviewer-binding.json"
      chmod 400 "$worker_outdir/reviewer-binding.json"

      reviewer_home="$worker_outdir/home"
      mkdir -p \
        "$reviewer_home/tmp" \
        "$reviewer_home/.config" \
        "$reviewer_home/.cache" \
        "$reviewer_home/.local/share" \
        "$reviewer_home/.local/state" \
        "$reviewer_home/runtime"
      chmod 700 "$reviewer_home/runtime"
      worker_env=(
        "PATH=${PATH:-/usr/bin:/bin}"
        "LANG=${LANG:-C}"
        "HOME=$reviewer_home"
        "TMPDIR=$reviewer_home/tmp"
        "XDG_CONFIG_HOME=$reviewer_home/.config"
        "XDG_CACHE_HOME=$reviewer_home/.cache"
        "XDG_DATA_HOME=$reviewer_home/.local/share"
        "XDG_STATE_HOME=$reviewer_home/.local/state"
        "XDG_RUNTIME_DIR=$reviewer_home/runtime"
        "OUTDIR=$worker_outdir"
        "WOO_REVIEW_BINDING_PATH=$worker_outdir/reviewer-binding.json"
        "WOO_REVIEW_ACTION_PATH=${WOO_REVIEW_ACTION_PATH:-$SCRIPT_DIR/..}"
        "WOO_REVIEW_ANGLE=$angle"
        "WOO_REVIEW_CHUNK=$chunk"
      )
      for name in \
        TERM USER LOGNAME SHELL NO_COLOR CI \
        FORCE_TIER INPUT_MODEL WOO_REVIEW_PROVIDER WOO_REVIEW_HOST \
        "${review_provider_env[@]}"; do
        value="${!name-}"
        [ -n "$value" ] && worker_env+=("$name=$value")
      done
      worker_rc=0
      (
        cd "$worker_outdir"
        env -i "${worker_env[@]}" "${worker_cmd[@]}"
      ) || worker_rc=$?

      output_suffix="$angle${chunk:+.$chunk}"
      for output_kind in findings receipt; do
        worker_output="$worker_outdir/$output_kind.$output_suffix.json"
        if [ -f "$worker_output" ] && [ ! -L "$worker_output" ]; then
          cp "$worker_output" "$controller_outdir/$output_kind.$output_suffix.json"
        fi
      done
      exit "$worker_rc"
    else
      "${worker_cmd[@]}"
    fi
  )
}
if [ "$engineer_unit" = true ]; then
  engineer_identity_manifest="${WOO_REVIEW_IDENTITY_MANIFEST:-$OUTDIR/reviewer-identities.json}"
  OUTDIR="$OUTDIR" \
    WOO_REVIEW_ENGINEER_UNIT=true \
    WOO_REVIEW_IDENTITY_MANIFEST="$engineer_identity_manifest" \
    bash "$SCRIPT_DIR/verify-receipts.sh" --list-missing >/dev/null
  engineer_identity_manifest_hash_before="$(
    git hash-object --no-filters -- "$engineer_identity_manifest"
  )" || {
    echo "::error::could not fingerprint the controller-owned reviewer identity manifest" >&2
    exit 2
  }
  engineer_worker_root="$(mktemp -d "/tmp/woostack-review-workers.XXXXXX")"
  chmod 700 "$engineer_worker_root"
  trap 'rm -rf "$engineer_worker_root"' EXIT HUP INT TERM
  engineer_repo_fingerprint_before="$(repository_fingerprint "$engineer_repo_root")" || {
    echo "::error::could not capture the engineer worktree fingerprint before review dispatch" >&2
    exit 2
  }
fi



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

if [ "$engineer_unit" = true ]; then
  engineer_identity_manifest_hash_after="$(
    git hash-object --no-filters -- "$engineer_identity_manifest"
  )" || {
    echo "::error::controller-owned reviewer identity manifest disappeared during dispatch" >&2
    exit 1
  }
  if [ "$engineer_identity_manifest_hash_after" != "$engineer_identity_manifest_hash_before" ]; then
    echo "::error::review worker changed the controller-owned reviewer identity manifest" >&2
    exit 1
  fi
  engineer_repo_fingerprint_after="$(repository_fingerprint "$engineer_repo_root")" || {
    echo "::error::could not capture the engineer worktree fingerprint after review dispatch" >&2
    exit 1
  }
  if [ "$engineer_repo_fingerprint_after" != "$engineer_repo_fingerprint_before" ]; then
    echo "::error::engineer-unit review worker changed repository/worktree state; receipts and findings are invalid" >&2
    exit 1
  fi
fi

# Single-authority receipt gate. Findings degradation (above) is a soft warning;
# a missing/invalid receipt means an angle never executed → hard-fail the swarm so
# the orchestrator cannot proceed to merge a false-clean review. verify-receipts.sh
# also folds executed_angles / expected_total / missing_receipts into swarm-metrics.json.
bash "$SCRIPT_DIR/verify-receipts.sh"
