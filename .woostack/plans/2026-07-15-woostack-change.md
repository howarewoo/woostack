---
type: plan
source: .woostack/specs/2026-07-15-woostack-change.md
status: ready
branch: feature/woostack-change
---

**Source:** [[specs/2026-07-15-woostack-change]]

# `/woostack-change` Implementation Plan

**Goal:** Ship `/woostack-change <goal>` as the 22nd registered public/adoption skill: a gate-free, isolated, one-PR path for bounded non-bug enhancements and refactors.

**Architecture:** One implementation increment updates the entire public command contract atomically. The new skill owns classification, a `change/<slug>` worktree, direct implementation, verification and inline review receipts, `woostack-commit` delegation, and verified teardown; existing worktree, TDD, commit, and least-code authorities remain linked. A structural shell test pins the multi-reader command surface and safety barriers, while the Fumadocs build proves generated skill discovery and authored framing pages remain valid.

**Tech Stack:** Markdown skill contracts, Bash structural verification, Graphite/Git worktrees, existing `woostack-tdd` and `woostack-commit` skills, Fumadocs/Next.js docs build.

**Dependency and Git-parent shape:** One independently shippable increment. Its implementation branch stacks directly on the spec+plan base PR branch `feature/woostack-change`; no sibling or dependent increment exists.

## Increment 1: Public `/woostack-change` command

> One independently shippable PR containing the skill, its focused structural test, commit/worktree integration, all registered-command bookkeeping, and affected authored docs. Keeping these sites together satisfies the public-surface lockstep contract; splitting them would leave either an undiscoverable skill or broken routing.

### Task 1: Pin the command contract with a failing structural test

**Files:**
- Create: `skills/woostack-change/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Write the executable structural test**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
  skill="$ROOT/skills/woostack-change/SKILL.md"

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

  require_file "skills/woostack-change/SKILL.md"
  require_text "skills/woostack-change/SKILL.md" "name: woostack-change"
  require_text "skills/woostack-change/SKILL.md" '/woostack-change <goal>'
  require_text "skills/woostack-change/SKILL.md" 'change/<slug>'
  require_text "skills/woostack-change/SKILL.md" '.woostack/worktrees/change-<slug>'
  require_text "skills/woostack-change/SKILL.md" 'PASS'
  require_text "skills/woostack-change/SKILL.md" 'BLOCKED'
  require_text "skills/woostack-change/SKILL.md" 'No approval gate'
  require_text "skills/woostack-change/SKILL.md" 'Never merge'

  require_text "skills/using-woostack/SKILL.md" '/woostack-change <goal>'
  require_text "skills/woostack-commit/SKILL.md" 'change/*'
  require_text "skills/woostack-init/references/worktrees.md" 'change/<slug>'
  require_text "AGENTS.md" 'twenty-two skills'
  require_text "CONTRIBUTING.md" 'twenty-second registered public/adoption skill'
  require_text "skills/woostack-bootstrap/references/development.md" 'woostack-change'
  require_text "site/content/docs/getting-started.mdx" 'woostack-change'
  require_text "site/content/docs/concepts/worktrees.mdx" 'woostack-change'
  require_text "site/content/docs/concepts/least-code.mdx" 'woostack-change'

  if [ -e "$ROOT/.woostack/changes" ]; then
    printf 'unexpected persistent change-artifact directory\n' >&2
    exit 1
  fi

  printf 'woostack-change command surface: PASS\n'
  ```

- [ ] **Step 2: Confirm the test is syntactically valid**
  Run: `bash -n skills/woostack-change/scripts/tests/test-command-surface.sh`
  Expected: exit `0`, no output.

- [ ] **Step 3: Run the test before implementation and confirm red**
  Run: `bash skills/woostack-change/scripts/tests/test-command-surface.sh`
  Expected: FAIL with `missing file: skills/woostack-change/SKILL.md`.

### Task 2: Author the gate-free change skill

**Files:**
- Create: `skills/woostack-change/SKILL.md`
- Test: `skills/woostack-change/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Add concise discovery frontmatter and command boundary**
  The file must begin with:
  ```markdown
  ---
  name: woostack-change
  description: Use for a bounded non-bug enhancement or refactor that can ship as one reviewable PR without the full build or fix loop. Classifies scope before writing, isolates work on change/<slug>, implements with TDD or concrete verification, records an inline review receipt, commits through woostack-commit, and tears down only after a verified PR. Routes bugs to woostack-fix, greenfield work to woostack-bootstrap, and multi-PR work to woostack-build. Never merges. Invoke via /woostack-change <goal>.
  ---

  # woostack-change
  ```

- [ ] **Step 2: Define the complete qualifying and routing contract**
  Add sections `## Commands`, `## Scope preflight`, and `## Procedure` that require:
  - an explicit goal; one focused question when the target or outcome is ambiguous;
  - repository/context inspection before any write;
  - bugs, regressions, incidents, and root-cause work route to `woostack-fix`;
  - greenfield project creation routes to `woostack-bootstrap`;
  - work that cannot remain one reviewable PR routes to `woostack-build`;
  - qualifying non-bug behavior/API changes and refactors may proceed even when user-visible, provided the full safe change remains one PR;
  - classification happens before creating the worktree, and routing is not an approval gate.

- [ ] **Step 3: Define worktree creation and direct implementation**
  Link `../woostack-init/references/worktrees.md` as the authority. Require resolving the primary root and base, creating `change/<slug>` at `$WOOSTACK_ROOT/.woostack/worktrees/change-<slug>`, and running `gt track --parent "$base"` from that worktree. All writes and downstream skill calls use that cwd. State a concise intent, then implement without waiting. Link the TDD kernel and `patterns.md §10`; require red→green→refactor for new observable behavior and exact concrete verification for docs/config/no-runner work.

- [ ] **Step 4: Define verification, review receipt, and closeout**
  Require the narrow relevant checks plus a smoke test of the changed path. Review the current diff inline through two explicit lenses: specification/intent compliance and code/skill quality. Emit a receipt of exactly `PASS` or `BLOCKED` naming the reviewed diff state; a missing receipt is blocked. On `PASS`, invoke `woostack-commit` from the same `change/*` worktree, require successful push/submission and PR read-back, then remove only the worktree. Return branch, commit, PR URL, verification evidence, and review receipt. Never merge.

- [ ] **Step 5: Add a prominent failure barrier and matching hard constraints**
  Include a visible `<HARD-STOP>` block plus `## Hard constraints` restatement covering: no approval gate; no spec/plan/change artifact; no writes before classification; no silent workflow fallback; no verification/review downgrade; one branch/one PR; preserve worktree on expanded scope or any verification/review/commit/submit failure; verified PR before teardown; never merge. Expanded scope after writes must stop and report the exact worktree path rather than auto-stack or delete work.

- [ ] **Step 6: Verify the skill-specific structural contract**
  Run: `bash skills/woostack-change/scripts/tests/test-command-surface.sh`
  Expected at this intermediate point: FAIL at the first not-yet-updated external command-surface site, proving the skill checks now pass and bookkeeping remains red.

### Task 3: Integrate `change/*` with commit and worktree authorities

**Files:**
- Modify: `skills/woostack-commit/SKILL.md`
- Modify: `skills/woostack-init/references/worktrees.md`
- Test: `skills/woostack-change/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Extend the commit branch-shape guard**
  Update every relevant `woostack-commit` branch-shape and caller-created-worktree sentence so `change/*` is accepted alongside `feature/*` and `fix/*`, and so a driving `woostack-change` caller reuses its existing worktree instead of creating a second branch. Do not weaken protected-branch checks or Linear attribution behavior. A Markdown change PR with no spec/fix continues to omit the `Spec:` trailer under the existing rule.

- [ ] **Step 2: Extend the canonical worktree consumer contract**
  Add `woostack-change` to the authority's consumer list, create/operate examples, stack-base description, and parallel-run descriptions where build/fix are currently exhaustive. Document `change/<slug>` → `.woostack/worktrees/change-<slug>` and one standalone PR targeting the resolved base. Cross-link the new skill; do not duplicate its classification or review workflow.

- [ ] **Step 3: Verify the integration clauses**
  Run: `grep -F 'change/*' skills/woostack-commit/SKILL.md && grep -F 'change/<slug>' skills/woostack-init/references/worktrees.md`
  Expected: both commands print matching contract lines and exit `0`.

### Task 4: Register the 22nd public command in lockstep

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `skills/using-woostack/SKILL.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Test: `skills/woostack-change/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Update repository authority and contribution map**
  In `AGENTS.md`, change the public count from twenty-one to twenty-two, insert `woostack-change` after `woostack-fix`, add it to Mode B routing and the Quick file map, and change the protected `SKILL.md` total from twenty-four to twenty-five while preserving the two internal plus one unregistered accounting. In `CONTRIBUTING.md`, add the skill to the complete public surface, identify it as the twenty-second registered public/adoption skill, and add its change-location table row.

- [ ] **Step 2: Update adoption and command routing**
  Add `/woostack-change <goal>` to `skills/using-woostack/SKILL.md` with the exact bounded non-bug one-PR boundary. Update `README.md` installation examples and authoring-flow section so bootstrap, build, fix, and change are the four supported code-writing routes; describe fix as bugs/root-cause work and change as gate-free bounded non-bug work. Update `skills/woostack-bootstrap/references/development.md` with the new command row.

- [ ] **Step 3: Preserve cross-skill boundaries**
  Ensure no existing `/woostack-fix` claim still presents generic non-bug refactors/enhancements as its preferred entry point where the new routing boundary applies. Do not rewrite fix's internal ability to handle an enhancement when explicitly invoked; routing and public-facing recommendations should prefer change for qualifying non-bug work.

- [ ] **Step 4: Re-run the structural test**
  Run: `bash skills/woostack-change/scripts/tests/test-command-surface.sh`
  Expected at this intermediate point: FAIL at the first not-yet-updated authored site page, proving repository routing/bookkeeping now passes.

### Task 5: Synchronize authored docs and prove consumer discovery

**Files:**
- Modify: `site/content/docs/getting-started.mdx`
- Modify: `site/content/docs/concepts/worktrees.mdx`
- Modify: `site/content/docs/concepts/least-code.mdx`
- Generated, not committed: `site/content/docs/skills/woostack-change.mdx`
- Test: `skills/woostack-change/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Update authored workflow framing**
  Add `woostack-change` to getting-started with its non-bug, one-PR, no-gate boundary and distinguish `woostack-fix` as the diagnosed bug path. Add its branch/path row and parallel-run wording to the worktree page. Add it to the authoring skills that carry least-code guidance. Do not manually create or edit the generated per-skill MDX page.

- [ ] **Step 2: Run focused structural verification**
  Run: `bash -n skills/woostack-change/scripts/tests/test-command-surface.sh && bash skills/woostack-change/scripts/tests/test-command-surface.sh`
  Expected: `woostack-change command surface: PASS` and exit `0`.

- [ ] **Step 3: Build the documentation site**
  Run: `pnpm -C site build`
  Expected: exit `0`; prebuild generates a valid `/docs/skills/woostack-change` reference page and the Next.js production build completes.

- [ ] **Step 4: Smoke-test generated command discovery**
  Run: `test -f site/content/docs/skills/woostack-change.mdx && grep -Fq 'name: woostack-change' skills/woostack-change/SKILL.md && grep -Fq '/woostack-change <goal>' skills/using-woostack/SKILL.md`
  Expected: exit `0`. Generated files remain gitignored and unstaged.

- [ ] **Step 5: Perform the increment review receipt**
  Review the complete implementation diff against spec AC1–AC5 and the skill-authoring/least-code constraints. Record `PASS` only when the new skill, branch guard, worktree authority, public counts, routing, authored docs, and structural verification agree; otherwise record `BLOCKED` with exact findings and fix them before commit.

## Plan Checks

- **Spec coverage:** Tasks 1–5 cover classification/routing, gate-free isolated execution, verification/review receipts, one-PR closeout, failure preservation, and every public-surface reader named in the spec.
- **AC coverage:** AC1 maps to Tasks 1, 2, and 4; AC2 to Tasks 1–3; AC3 to Tasks 1, 2, and 5; AC4 to Tasks 1–3; AC5 to Tasks 1, 4, and 5. Every happy/error/edge branch has either a structural assertion or explicit skill procedure/hard-stop clause.
- **No placeholders:** All files, commands, expected outcomes, routing destinations, branch/worktree shapes, counts, and lifecycle outcomes are concrete.
- **Architecture:** One increment is necessary for atomic public registration and independently shippable as the complete new command. No abstraction, dependency, artifact schema, status lifecycle, or second PR is introduced.
- **Types/API/database/security/observability:** No application type, database, runtime API, credential, or telemetry surface changes. The agent command contract treats ambiguous input and failed receipts as explicit stopped outcomes and never swallows or downgrades failures.
- **Dependencies:** No new package or external service dependency. Site generation and build use the existing `site/` toolchain.
- **Git validity:** One root increment stacks directly on `feature/woostack-change`; no cycles, deferrals, sibling tracks, or unrepresentable ancestry.
