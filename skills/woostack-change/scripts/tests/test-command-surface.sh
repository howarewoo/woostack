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

reject_text() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$ROOT/$file"; then
    printf 'forbidden active contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

require_file "skills/woostack-change/SKILL.md"
require_text "skills/woostack-change/SKILL.md" "name: woostack-change"
require_line "skills/woostack-fix/SKILL.md" 'description: Use for bugs, regressions, hotfixes, and small technical issues that require diagnosis or root-cause analysis before implementation.'
require_text "skills/woostack-change/SKILL.md" '/woostack-change <goal> [--issue <Linear issue UUID|exact URL>]'
require_text "skills/woostack-change/SKILL.md" 'If either is ambiguous, ask exactly one'
require_text "skills/woostack-change/SKILL.md" 'focused clarification question before classifying or writing.'
require_text "skills/woostack-change/SKILL.md" 'Inspect repository context and the affected surface before any write'
require_text "skills/woostack-change/SKILL.md" '[`woostack-fix`](../woostack-fix/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" '[`woostack-bootstrap`](../woostack-bootstrap/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" '[`woostack-build`](../woostack-build/SKILL.md).'
require_text "skills/woostack-change/SKILL.md" 'host-exposed Linear MCP is the only development-record authority.'
require_text "skills/woostack-change/SKILL.md" 'one repository-owned standalone issue with role `work-item`'
require_text "skills/woostack-change/SKILL.md" 'wrapper project, Linear document, local specification, plan, or change artifact.'
require_text "skills/woostack-change/SKILL.md" 'Discover host tools by capability'
require_text "skills/woostack-change/SKILL.md" 'generate the resource client UUID before mutation'
require_text "skills/woostack-change/SKILL.md" 'search by the same UUID'
require_text "skills/woostack-change/SKILL.md" 'Never create a replacement, match by title'
require_text "skills/woostack-change/SKILL.md" 'A supplied project, Linear document, project-backed `increment` issue'
require_text "skills/woostack-change/SKILL.md" 'repository/team issue'
require_text "skills/woostack-change/SKILL.md" 'blocks before branch'
require_text "skills/woostack-change/SKILL.md" 'Project creation is neither required nor permitted.'
require_text "skills/woostack-change/SKILL.md" 'goal, target, in-scope and out-of-scope surface, acceptance criteria'
require_text "skills/woostack-change/SKILL.md" 'before worktree creation or tracked repository mutation.'
require_text "skills/woostack-change/SKILL.md" 'A human engineer is the native assignee'
require_text "skills/woostack-change/SKILL.md" 'native delegate'
require_text "skills/woostack-change/SKILL.md" 'immediately before worktree creation and every later'
require_text "skills/woostack-change/SKILL.md" '`assignmentAccepted`'
require_text "skills/woostack-change/SKILL.md" '`implementationEvidence`'
require_text "skills/woostack-change/SKILL.md" '`verification`'
require_text "skills/woostack-change/SKILL.md" '`precommitReview`'
require_text "skills/woostack-change/SKILL.md" '`decisionRequest`/`decisionResponse`'
require_text "skills/woostack-change/SKILL.md" '**no hard approval gate**'
require_text "skills/woostack-change/SKILL.md" 'Do not pause for approval.'
require_text "skills/woostack-change/SKILL.md" '[`woostack-tdd` kernel](../woostack-tdd/SKILL.md)'
require_text "skills/woostack-change/SKILL.md" 'the changed path as a user or caller exercises it.'
require_text "skills/woostack-change/SKILL.md" 'complete base-to-HEAD diff plus staged, unstaged, and untracked state.'
require_text "skills/woostack-change/SKILL.md" 'matching passing `verification` and `precommitReview` receipts'
require_text "skills/woostack-change/SKILL.md" '`BLOCKED`'
require_text "skills/woostack-change/SKILL.md" '[`woostack-commit`'"'"'s canonical receipt helper](../woostack-commit/scripts/change-receipt.sh)'
require_text "skills/woostack-change/SKILL.md" 'Linear-Issue: <TEAM-NUMBER>'
require_text "skills/woostack-change/SKILL.md" 'no `Linear-Project:` or `Spec:` trailer'
require_text "skills/woostack-change/SKILL.md" 'issue to `inReview` and independently verify that state.'
require_text "skills/woostack-change/SKILL.md" 'responsible terminal `acceptance` event plus verified merge evidence'
require_text "skills/woostack-change/SKILL.md" 'GitHub GraphQL remains permitted'
require_text "skills/woostack-change/SKILL.md" 'migration input only'
require_text "skills/woostack-change/SKILL.md" 'preserve every recoverable branch/worktree'
require_text "skills/woostack-change/SKILL.md" 'exact intended/preserved'
require_text "skills/woostack-change/SKILL.md" '**Never merge.**'
require_text "skills/woostack-change/SKILL.md" '## Resume and state admission'
require_text "skills/woostack-change/SKILL.md" 'a fresh `planned` work item'
require_text "skills/woostack-change/SKILL.md" 'no implementation branch, worktree, commit, PR, or prior `assignmentAccepted`'
require_text "skills/woostack-change/SKILL.md" '`executing` when the issue/state receipt, current `assignmentAccepted`, and current resolved owner'
require_text "skills/woostack-change/SKILL.md" '`blocked` only after a current verified `unblocked` event'
require_text "skills/woostack-change/SKILL.md" '`inReview` or `done` as report-only states'
require_text "skills/woostack-change/SKILL.md" 'without reopening implementation.'
require_text "skills/woostack-change/SKILL.md" 'recreate an expected but missing Git artifact.'
require_text "skills/woostack-change/SKILL.md" 'the exact existing branch/worktree and complete-state receipt match the issue'
require_text "skills/woostack-change/SKILL.md" 'a fresh complete branch, worktree, commit, and PR read proves there are **no Git artifacts**'
require_text "skills/woostack-change/SKILL.md" 'crash boundary after assignment/state mutation but before worktree creation'
require_text "skills/woostack-change/SKILL.md" '`.woostack/worktrees/issues/<exact-native-linear-issue-id>` worktree exactly once'
require_text "skills/woostack-change/SKILL.md" 'Any partial, unknown, duplicate, or conflicting Git residue blocks'
require_text "skills/woostack-change/SKILL.md" 'only executing admission that may create the deterministic worktree.'
require_text "skills/woostack-change/SKILL.md" 'Append and independently verify only the'
require_text "skills/woostack-change/SKILL.md" 'do not write `implementationEvidence`.'
require_text "skills/woostack-change/SKILL.md" 'After the finalized commit exists and before push or PR submission'
require_text "skills/woostack-change/SKILL.md" '`woostack-commit` consumer owns appending `implementationEvidence`'
require_text "skills/woostack-change/SKILL.md" 'evidence receipt stops before push.'

reject_text "skills/woostack-change/SKILL.md" "resolve-backend.sh"
reject_text "skills/woostack-change/SKILL.md" "artifacts.specPlan"
reject_text "skills/woostack-change/SKILL.md" "linear.sh"
reject_text "skills/woostack-change/SKILL.md" 'Create a markdown file under `.woostack/'
reject_text "skills/woostack-change/SKILL.md" "Spec: .woostack/"
reject_text "skills/woostack-change/SKILL.md" "create a one-issue project"

require_text "skills/using-woostack/SKILL.md" '| `/woostack-change <goal>`, implement a bounded non-bug enhancement or refactor that fits one reviewable PR | `woostack-change` |'
require_text "skills/woostack-commit/SKILL.md" 'change/*'
require_text "skills/woostack-commit/SKILL.md" 'supply its current `woostack-change` PASS identity'
require_text "skills/woostack-commit/SKILL.md" 'scripts/change-receipt.sh "$base_ref"'
require_text "skills/woostack-commit/SKILL.md" 'supplied PASS identity before the hook'
require_text "skills/woostack-commit/SKILL.md" 'fresh pre-hook and post-hook values'
require_text "skills/woostack-commit/SKILL.md" 'never stage or commit under a stale receipt'
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
require_text "AGENTS.md" 'This collection still has twenty-three public command/adoption skills at twenty-six fixed'
require_text "AGENTS.md" '- [`woostack-change`](skills/woostack-change/SKILL.md)'
require_text "AGENTS.md" '`/woostack-fix`, `/woostack-change`, `/woostack-plan`'
require_text "AGENTS.md" 'Bounded non-bug change loop (public command; one reviewable PR, no approval gate or persisted plan):'
require_text "README.md" 'This command registers twenty-three public command/adoption skills and three bundled supporting skills at twenty-six fixed `SKILL.md` locations.'
require_text "README.md" '[/woostack-change](skills/woostack-change/SKILL.md)'
require_text "README.md" 'Ships an enhancement or refactor that fits one reviewable PR without an approval gate or persisted plan.'
require_text "CONTRIBUTING.md" 'Keep the twenty-three public command/adoption skills and all twenty-six fixed `SKILL.md` files'
require_text "CONTRIBUTING.md" '| Change the bounded non-bug one-PR workflow (`/woostack-change`) | `skills/woostack-change/SKILL.md` |'
require_text "skills/woostack-bootstrap/references/development.md" 'Build a feature or work item requiring multiple PRs'
require_text "skills/woostack-bootstrap/references/development.md" 'bounded non-bug enhancement or refactor that fits one reviewable PR (no approval gate or persisted plan)'
require_text "site/content/docs/getting-started.mdx" '[woostack-change](/docs/skills/woostack-change)'
require_text "site/content/docs/getting-started.mdx" 'bounded non-bug enhancement or refactor that fits one reviewable PR without an approval gate or persisted plan'
require_text "site/content/docs/getting-started.mdx" '[woostack-fix](/docs/skills/woostack-fix) for a diagnosed bug'
require_text "site/content/docs/concepts/worktrees.mdx" '| [woostack-change](/docs/skills/woostack-change) | `change/<slug>` | `.woostack/worktrees/issues/<native-issue-id>` |'
require_text "site/content/docs/concepts/least-code.mdx" '[woostack-change](/docs/skills/woostack-change)'

if [ -e "$ROOT/.woostack/changes" ]; then
  printf 'unexpected persistent change-artifact directory\n' >&2
  exit 1
fi

bash "$ROOT/skills/woostack-respond/scripts/tests/test-command-surface.sh"

printf 'woostack-change command surface: PASS\n'
