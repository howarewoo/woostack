#!/usr/bin/env bash
set -euo pipefail

# Pins the build loop's spec-commit-before-approval ordering (fix 2026-06-23):
# the spec must be committed (PR opened) BEFORE the step-3 spec-approval gate, so the user
# reviews the spec in the PR — mirroring woostack-fix's commit-before-gate pattern. The same
# spec+plan base PR opens earlier (spec-only) and the plan is appended at step 7; no new gate,
# no second PR. Authored docs-site diagram must stay in sync.
#
# Assertions use fixed-string matching (rg -F) so arrows (→) and '+' are literal, and prove
# ORDER via adjacency strings rather than line numbers.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BUILD_SKILL="$ROOT/skills/woostack-build/SKILL.md"
RULES="$ROOT/site/content/docs/concepts/building-rules.mdx"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -qF "$pattern" "$file"; then
    echo "missing pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if rg -qF "$pattern" "$file"; then
    echo "unexpected pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

# --- SKILL.md Overview diagram: spec PR committed before approve-spec ---
# New adjacency present, old adjacency gone (proves the commit got inserted before the gate).
assert_contains "$BUILD_SKILL" "commit spec PR → approve spec"
assert_not_contains "$BUILD_SKILL" "harden spec → approve spec"
# Step 7 reframed from a fresh spec+plan commit to appending the plan to the already-open PR.
assert_contains "$BUILD_SKILL" "append plan to spec+plan PR"
assert_not_contains "$BUILD_SKILL" "commit spec+plan as their own PR"

# --- SKILL.md Hard constraints + gate prose ---
# A skim-resistant Hard-constraints bullet must carry the new rule (mirrors woostack-fix).
assert_contains "$BUILD_SKILL" "Commit the spec before its approval gate"
# Abandon at the spec gate must now also close the PR opened before it.
assert_contains "$BUILD_SKILL" "close the now-open PR"
# The early commit must not add a fourth gate.
assert_contains "$BUILD_SKILL" "three hard gates"

# --- Docs site authored page stays in sync with the loop diagram ---
assert_contains "$RULES" "commit spec PR"
assert_contains "$RULES" "append plan to spec+plan PR"
assert_not_contains "$RULES" "ship spec+plan PR"

echo "test-build-spec-commit-ordering: OK"
