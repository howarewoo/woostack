#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

require_file() {
  [ -f "$ROOT/$1" ] || { printf 'missing file: %s\n' "$1" >&2; exit 1; }
}

require_text() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$ROOT/$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

require_line() {
  local file="$1" text="$2"
  grep -Fxq -- "$text" "$ROOT/$file" || {
    printf 'missing exact contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

require_file "skills/woostack-change/SKILL.md"
require_text "skills/woostack-change/SKILL.md" "name: woostack-change"
require_line "skills/woostack-fix/SKILL.md" 'description: Use for bugs, regressions, hotfixes, and small technical issues that require diagnosis or root-cause analysis before implementation.'
require_text "skills/woostack-change/SKILL.md" '/woostack-change <goal>'
require_text "skills/woostack-change/SKILL.md" 'If either is ambiguous, ask exactly one'
require_text "skills/woostack-change/SKILL.md" 'focused clarification question before classifying or writing.'
require_text "skills/woostack-change/SKILL.md" 'Inspect repository context and the affected surface before any write'
require_text "skills/woostack-change/SKILL.md" '[`woostack-fix`](../woostack-fix/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" '[`woostack-bootstrap`](../woostack-bootstrap/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" '[`woostack-build`](../woostack-build/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" 'Create no spec, plan, change artifact, `.woostack/changes/` directory'
require_text "skills/woostack-change/SKILL.md" '[`woostack-tdd` kernel](../woostack-tdd/SKILL.md)'
require_text "skills/woostack-change/SKILL.md" 'name and run an exact concrete verification'
require_text "skills/woostack-change/SKILL.md" 'smoke-test the changed path as a user or caller exercises it.'
require_text "skills/woostack-change/SKILL.md" 'complete base-to-HEAD diff'
require_text "skills/woostack-change/SKILL.md" 'staged, unstaged, and untracked state.'
require_text "skills/woostack-change/SKILL.md" 'PASS'
require_text "skills/woostack-change/SKILL.md" 'BLOCKED'
require_text "skills/woostack-change/SKILL.md" '[`woostack-commit`'"'"'s canonical receipt helper](../woostack-commit/scripts/change-receipt.sh)'
require_text "skills/woostack-change/SKILL.md" 'Use exactly one `change/<slug>` branch and one PR'
require_text "skills/woostack-change/SKILL.md" 'Only after successful PR read-back, remove the change worktree'
require_text "skills/woostack-change/SKILL.md" 'preserve every recoverable branch or worktree state on creation/tracking'
require_text "skills/woostack-change/SKILL.md" 'expanded scope, or any verification, review, commit, push, submit, or PR read-back'
require_text "skills/woostack-change/SKILL.md" 'report the exact intended/preserved path and never auto-delete it.'
require_text "skills/woostack-change/SKILL.md" '**Never merge.**'

require_text "skills/using-woostack/SKILL.md" '| `/woostack-change <goal>`, implement a bounded non-bug enhancement or refactor that fits one reviewable PR | `woostack-change` |'
require_text "skills/woostack-commit/SKILL.md" 'change/*'
require_text "skills/woostack-commit/SKILL.md" 'supplied `woostack-change` `PASS`'
require_text "skills/woostack-commit/SKILL.md" 'scripts/change-receipt.sh "$base_ref"'
require_text "skills/woostack-commit/SKILL.md" 'pre-hook full identity'
require_text "skills/woostack-commit/SKILL.md" 'post-hook full identity'
require_text "skills/woostack-commit/SKILL.md" 'hook-created commits'
require_file "skills/woostack-commit/scripts/change-receipt.sh"
bash -n "$ROOT/skills/woostack-commit/scripts/change-receipt.sh"
receipt="$(cd "$ROOT" && bash skills/woostack-commit/scripts/change-receipt.sh HEAD)"
printf '%s' "$receipt" | jq -e '
  type == "object" and
  (.branch | type == "string" and length > 0) and
  (.baseRef == "HEAD") and
  (.baseCommit | test("^[0-9a-f]{40}$")) and
  (.headCommit | test("^[0-9a-f]{40}$")) and
  (.baseToHead | test("^[0-9a-f]{40}$")) and
  (.staged | test("^[0-9a-f]{40}$")) and
  (.unstaged | test("^[0-9a-f]{40}$")) and
  (.untracked | type == "array") and
  (all(.untracked[]; (.pathBase64 | type == "string") and (.object | test("^[0-9a-f]{40}$"))))
' >/dev/null || {
  printf 'invalid change receipt identity\n' >&2
  exit 1
}
require_text "skills/woostack-init/references/worktrees.md" 'change/<slug>'
require_text "AGENTS.md" 'This collection still has twenty-two public command/adoption skills at twenty-five fixed'
require_text "AGENTS.md" '- [`woostack-change`](skills/woostack-change/SKILL.md)'
require_text "AGENTS.md" '`/woostack-fix`, `/woostack-change`, `/woostack-plan`'
require_text "AGENTS.md" 'Bounded non-bug change loop (public command; one reviewable PR, no approval gate or persisted plan):'
require_text "README.md" 'This command registers twenty-two public command/adoption skills and three bundled supporting skills at twenty-five fixed `SKILL.md` locations.'
require_text "README.md" '[/woostack-change](skills/woostack-change/SKILL.md)'
require_text "README.md" 'Ships an enhancement or refactor that fits one reviewable PR without an approval gate or persisted plan.'
require_text "CONTRIBUTING.md" 'Keep the twenty-two public command/adoption skills and all twenty-five installed `SKILL.md` files'
require_text "CONTRIBUTING.md" '| Change the bounded non-bug one-PR workflow (`/woostack-change`) | `skills/woostack-change/SKILL.md` |'
require_text "skills/woostack-bootstrap/references/development.md" 'Build a feature or work item requiring multiple PRs'
require_text "skills/woostack-bootstrap/references/development.md" 'bounded non-bug enhancement or refactor that fits one reviewable PR (no approval gate or persisted plan)'
require_text "site/content/docs/getting-started.mdx" '[woostack-change](/docs/skills/woostack-change)'
require_text "site/content/docs/getting-started.mdx" 'bounded non-bug enhancement or refactor that fits one reviewable PR without an approval gate or persisted plan'
require_text "site/content/docs/getting-started.mdx" '[woostack-fix](/docs/skills/woostack-fix) for a diagnosed bug'
require_text "site/content/docs/concepts/worktrees.mdx" '| [woostack-change](/docs/skills/woostack-change) | `change/<slug>` | `.woostack/worktrees/change-<slug>` |'
require_text "site/content/docs/concepts/least-code.mdx" '[woostack-change](/docs/skills/woostack-change)'

if [ -e "$ROOT/.woostack/changes" ]; then
  printf 'unexpected persistent change-artifact directory\n' >&2
  exit 1
fi

bash "$ROOT/skills/using-woostack/tests/test-artifact-reader-contract.sh"
bash "$ROOT/skills/woostack-respond/scripts/tests/test-command-surface.sh"

printf 'woostack-change command surface: PASS\n'
