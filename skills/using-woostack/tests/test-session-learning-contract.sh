#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROUTER="$ROOT/skills/using-woostack/SKILL.md"
CONTRACT="$ROOT/skills/using-woostack/references/session-learning.md"

[ -f "$CONTRACT" ] || { echo "missing session-learning contract" >&2; exit 1; }

grep -Fq '[Session learning](references/session-learning.md)' "$ROUTER" || {
  echo "using-woostack does not load the session-learning contract" >&2
  exit 1
}

for phrase in \
  'Treat every final user-facing reply as a session boundary.' \
  'Suggest a change only when the session produced a novel, reusable rule' \
  'Use the narrowest applicable `AGENTS.md` scope.' \
  'Use the global instruction file only for a cross-repository or harness-wide rule.' \
  'Never write an instruction file or a suggestion artifact automatically.' \
  '`AGENTS.md suggestions`'
do
  grep -Fq "$phrase" "$CONTRACT" || {
    echo "session-learning contract missing: $phrase" >&2
    exit 1
  }
done

cutover_surfaces=(
  "$ROOT/AGENTS.md"
  "$ROOT/README.md"
  "$ROOT/CONTRIBUTING.md"
  "$ROOT/skills/using-woostack/SKILL.md"
  "$CONTRACT"
  "$ROOT/skills/woostack-init/SKILL.md"
  "$ROOT/skills/woostack-init/scripts"
  "$ROOT/skills/woostack-init/templates"
  "$ROOT/site/content/docs"
  "$ROOT/site/scripts"
)

for removed in \
  '.woostack/memory' \
  '.woostack/wisdom' \
  'MEMORY.md' \
  'woostack-dream' \
  'woostack-ask'
do
  if grep -R -F -n "$removed" "${cutover_surfaces[@]}" >/dev/null; then
    echo "removed knowledge capability remains on an active routing or scaffolding surface: $removed" >&2
    exit 1
  fi
done

printf 'session learning contract: PASS\n'
