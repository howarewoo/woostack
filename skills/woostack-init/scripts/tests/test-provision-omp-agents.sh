#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISIONER="$HERE/../provision-omp-agents.sh"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

ROOT="$(mktemp -d)"
ROOT="$(cd "$ROOT" && pwd -P)"
trap 'rm -rf "$ROOT"' EXIT
file_state() {
  python3 - "$1" <<'PY'
import os
import sys
value = os.stat(sys.argv[1], follow_symlinks=False)
print(f"{value.st_dev}:{value.st_ino}:{value.st_mtime_ns}:{value.st_size}")
PY
}

mkdir -p "$ROOT/.omp/agents"
printf '%s\n' 'consumer-owned' >"$ROOT/.omp/agents/custom.md"

bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(cat "$ROOT/.omp/agents/custom.md")" "consumer-owned" "provisioning preserves consumer-authored agents"
assert_eq "$(cat "$ROOT/.omp/agents/.gitignore")" 'woostack-*.md' \
  "provisioning creates the scoped generated-agent ignore rule"
printf '%s' 'consumer-ignore' >"$ROOT/.omp/agents/.gitignore"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(cat "$ROOT/.omp/agents/.gitignore")" $'consumer-ignore\nwoostack-*.md' \
  "provisioning preserves an unterminated consumer-owned ignore line"


body='You are a general-purpose woostack worker for delegated tasks.

Follow the supplied task contract, repository rules, worktree boundary, and authority constraints. Complete only the assigned work and return concise evidence.'
for entry in 'fast @smol' 'standard @default' 'deep @slow'; do
  set -- $entry
  tier="$1"; role="$2"; path="$ROOT/.omp/agents/woostack-$tier.md"
  expected="---
name: woostack-$tier
description: General-purpose woostack worker using a host-owned model role
model: \"$role\"
---

$body"
  assert_eq "$(cat "$path")" "$expected" "generated $tier definition is exact"
done
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "fresh definitions pass read-only diagnosis"

before="$(file_state "$ROOT/.omp/agents/woostack-fast.md"):$(file_state "$ROOT/.omp/agents/.gitignore")"
bash "$PROVISIONER" "$ROOT" >/dev/null
after="$(file_state "$ROOT/.omp/agents/woostack-fast.md"):$(file_state "$ROOT/.omp/agents/.gitignore")"
assert_eq "$after" "$before" "provisioning is idempotent for clean managed definitions and ignore coverage"
printf '%s\n' 'woostack-*.md' >>"$ROOT/.omp/agents/.gitignore"
ignore_drift="$(bash "$PROVISIONER" --check "$ROOT")"
assert_contains "$ignore_drift" ".gitignore" "diagnosis reports duplicate generated-agent ignore rules"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(cat "$ROOT/.omp/agents/.gitignore")" $'consumer-ignore\nwoostack-*.md' \
  "repair leaves every consumer-owned ignore line and exactly one managed rule"
printf '%s\n' '# stale body' >>"$ROOT/.omp/agents/woostack-fast.md"
drifted="$(bash "$PROVISIONER" --check "$ROOT")"
assert_contains "$drifted" $'drifted\t' "diagnosis reports stale managed definitions"
bash "$PROVISIONER" "$ROOT" >/dev/null


printf '%s\n' 'not frontmatter' >"$ROOT/.omp/agents/woostack-fast.md"
malformed="$(bash "$PROVISIONER" --check "$ROOT")"
assert_contains "$malformed" $'malformed\t' "diagnosis reports malformed managed definitions"
printf '%s\n' '---' 'name: woostack-standard' 'model: "@smol"' '---' >"$ROOT/.omp/agents/woostack-standard.md"
wrong_role="$(bash "$PROVISIONER" --check "$ROOT")"
assert_contains "$wrong_role" $'wrong-role\t' "diagnosis reports the wrong host role"
rm "$ROOT/.omp/agents/woostack-deep.md"
missing="$(bash "$PROVISIONER" --check "$ROOT")"
assert_contains "$missing" $'missing\t' "diagnosis reports missing managed definitions"

bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "provisioning repairs malformed, wrong-role, and missing definitions"
assert_eq "$(cat "$ROOT/.omp/agents/custom.md")" "consumer-owned" "repair preserves unrelated agents"
UNSAFE_ROOT="$ROOT/unsafe-consumer"
mkdir -p "$UNSAFE_ROOT/.omp/agents"
printf '%s\n' 'SYMLINK_TARGET_MUST_STAY_UNCHANGED' >"$UNSAFE_ROOT/ignore-target"
ln -s "$UNSAFE_ROOT/ignore-target" "$UNSAFE_ROOT/.omp/agents/.gitignore"
set +e
bash "$PROVISIONER" "$UNSAFE_ROOT" >/dev/null 2>&1
unsafe_status=$?
set -e
assert_exit 1 "$unsafe_status" "provisioning fails closed on a symlinked agent ignore file"
for tier in fast standard deep; do
  [ ! -e "$UNSAFE_ROOT/.omp/agents/woostack-$tier.md" ] \
    && pass || fail "unsafe ignore preflight creates no managed $tier definition"
done
assert_eq "$(cat "$UNSAFE_ROOT/ignore-target")" "SYMLINK_TARGET_MUST_STAY_UNCHANGED" \
  "unsafe ignore preflight never reads or changes the symlink target"
FIFO_ROOT="$ROOT/fifo-consumer"
mkdir -p "$FIFO_ROOT/.omp/agents"
mkfifo "$FIFO_ROOT/.omp/agents/.gitignore"
fifo_status="$(python3 - "$PROVISIONER" "$FIFO_ROOT" <<'PY'
import subprocess
import sys
try:
    result = subprocess.run(
        ["bash", sys.argv[1], sys.argv[2]],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=3,
    )
    print(result.returncode)
except subprocess.TimeoutExpired:
    print(124)
PY
)"
assert_exit 1 "$fifo_status" "provisioning promptly rejects a FIFO agent ignore path"
for tier in fast standard deep; do
  [ ! -e "$FIFO_ROOT/.omp/agents/woostack-$tier.md" ] \
    && pass || fail "FIFO ignore preflight creates no managed $tier definition"
done



finish
