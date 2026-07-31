#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
DOCTOR="$ROOT/skills/woostack-doctor/SKILL.md"
CHANGE="$ROOT/skills/woostack-change/SKILL.md"

require_text() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing repair handoff contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

reject_text() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'forbidden repair handoff contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

require_text "$DOCTOR" 'routes approved tracked repairs through [`woostack-change`](../woostack-change/SKILL.md) before'
require_text "$DOCTOR" 'before invoking any `--fix` path.'
require_text "$DOCTOR" 'binds or creates the standalone issue, records the approved bounded contract'
require_text "$DOCTOR" 'Doctor never hands tracked repairs directly to `woostack-commit`.'
require_text "$DOCTOR" 'approved repair is filesystem-only, run `orphan-worktree --fix`'
require_text "$CHANGE" 'Before any tracked repository edit, the issue'
require_text "$CHANGE" 'binds or creates exactly'
reject_text "$DOCTOR" 'After file repairs, hand to [`woostack-commit`]'

printf 'doctor repair handoff contract: PASS\n'
