#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PROMPT="$ROOT/skills/woostack-address-comments/prompts/address.md"
SKILL="$ROOT/skills/woostack-address-comments/SKILL.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$file"; then
    echo "missing pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

assert_contains "$PROMPT" "worker"
assert_contains "$PROMPT" "reply"
assert_contains "$PROMPT" "fix_plan"
assert_contains "$PROMPT" "must not edit files"
assert_contains "$PROMPT" "must not commit"
assert_contains "$PROMPT" "must not push"
assert_contains "$PROMPT" "must not reply"
assert_contains "$PROMPT" "must not resolve"
assert_contains "$PROMPT" "must not write memory"
assert_contains "$SKILL" "fast workers"
assert_contains "$SKILL" "parent orchestrator"
