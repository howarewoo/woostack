---
name: commit-pr-goal-test-plan
type: spec
status: done
date: 2026-06-04
branch: worktree-delightful-pondering-thimble
links:
---

# woostack-commit: PR body with Goal and structured test plan — Design Spec

> **Plan:** [[plans/2026-06-04-commit-pr-goal-test-plan]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-commit` writes the PR body with a fixed two-section shape (SKILL.md:188–200):

```markdown
## Summary
- <change>

## Test plan
- [ ] <command or manual step>
```

Two gaps:

1. **No stated intent.** The body opens with a change list (`## Summary`) but never says
   *why* the PR exists. A reviewer reconstructs the goal from the bullets. Intent up front is
   what lets a reviewer judge whether the change actually serves its purpose.
2. **Flat, undifferentiated test plan.** Automated runs (commands, `commit.pre_commit`) and
   human verification are mixed in one checklist. There is no signal about which steps a
   reviewer must perform by hand, and no place for verification that can only happen *after*
   the PR lands (deploy behavior, migrations, env-gated config). The skill already pushes for
   manual steps when automated coverage is thin (SKILL.md:210–211) but gives them no
   structure.

## 2. Goal

Update the `woostack-commit` PR body template and its surrounding rules so every PR body:

- Opens with a `## Goal` section (1–2 sentences of intent) above the kept `## Summary`.
- Splits `## Test plan` into `### Automated` and `### Manual`.
- Groups manual steps into **Before merge** and **After merge**, including the after-merge
  group only when post-merge-only verification applies.

Scope is the prose and template of one file: `skills/woostack-commit/SKILL.md`. No code, no
other skills, no behavior outside what the skill documents.

## 3. Non-goals

- No change to git/Graphite/GitHub mechanics (branch shaping, staging, push, `gh pr edit`).
- No change to the fast-subagent delegation boundary — only the list of draftable fields.
- No new config keys. `commit.pre_commit` behavior is unchanged; it keeps surfacing in the
  test plan, now under `### Automated`.
- Not retrofitting existing open PRs. The template governs new/updated bodies going forward.

## 4. Approach

Edit four spots in `skills/woostack-commit/SKILL.md`:

1. **Template block (SKILL.md:188–200)** — replace with the Goal + structured-test-plan
   shape (see §5).
2. **Step-7 rules (SKILL.md:202–211)** — add rules for filling Goal, Automated, and the
   Manual before/after groups; fold the existing command-bullet and `Not run` guidance under
   Automated; relocate the manual-step guidance under Manual with the before/after split and
   the omit-when-empty rule.
3. **Fast-subagent drafting (SKILL.md:48–50)** — add "Goal line" to the draftable text list
   alongside Summary and Test plan bullets.
4. **Description frontmatter (SKILL.md:3)** and **Step-8 Report (SKILL.md:219–227)** — minor
   wording so both reflect goal + structured test plan.

Markdown-only change; the skill is documentation that an agent executes.

## 5. Components & data flow

New PR body template:

```markdown
## Goal

<1-2 sentences: why this PR exists / the problem it solves>

## Summary

- <concise bullet describing a relevant change>
- <another relevant change>

## Test plan

### Automated

- [ ] <command run and result, or "Not run (reason)">

### Manual

**Before merge**

- [ ] <step a reviewer can inspect or exercise on the branch or preview>

**After merge**

- [ ] <step only verifiable post-merge — deploy / migration / env-gated>
```

Filling rules:

- **Goal** states intent or the problem solved, not a change list — distinct from Summary,
  which lists *what* changed. One or two sentences.
- **Automated** lists commands/tests actually run, plus the configured `commit.pre_commit`
  command and result when it ran. Show this group whenever an automated check (test, lint,
  typecheck, `pre_commit`) *could* have run for this change: list results, or `Not run` with
  the reason when one was expected but skipped. **Omit `### Automated` entirely when no
  automated check is applicable to the change** (e.g. a doc-only edit in a repo with no test
  harness) — do not emit a `Not run` placeholder in that case.
- **Manual → Before merge** is what a reviewer can inspect or exercise now: read the diff,
  run the command locally, exercise the change on the branch or a preview.
- **Manual → After merge** is verification that *cannot* be done until the PR lands —
  staging/prod deploy behavior, migrations, environment-specific config. This is the "if
  applicable": **omit the After-merge group entirely when nothing applies.** Most
  skill/doc-only changes have none.
- Omit any empty group — `### Automated`, `### Manual`, or either before/after block —
  rather than leaving placeholder bullets. The omit rule is uniform across all groups: an
  inapplicable automated check drops `### Automated` just as a change with no manual steps
  drops `### Manual`.
- All test-plan items stay unchecked Markdown checkboxes (`- [ ] …`).

## 6. Error handling

No new failure modes — the change is template prose. Existing stop conditions
(`pre_commit` non-zero, ambiguous relevance, no PR) are unchanged. Degenerate cases resolve
by the omit-when-empty rule: a change with only automated coverage renders just
`### Automated`; a doc change with one before-merge check renders `### Manual` with a single
**Before merge** item and no **After merge** block.

## 7. Testing

Automated: none meaningful — this repo has no app build/CI for its own skill markdown, and
the change is documentation. State that explicitly rather than inventing a test.

Manual (before merge):
- Read the updated `skills/woostack-commit/SKILL.md` and confirm the template shows `## Goal`
  above `## Summary` and the `### Automated` / `### Manual` (with **Before merge** / **After
  merge**) split, and that the rules describe each section including omit-when-empty and the
  after-merge "if applicable" condition.
- Confirm the four edit spots (template, step-7 rules, fast-subagent list, description +
  step-8 report) are mutually consistent — no leftover reference to the old flat test plan.

Manual (after merge): none — the skill takes effect for consumers on install; there is no
deploy or runtime surface to verify post-merge for this repo.

## 8. Open questions

None. All decisions are resolved:

- Goal sits above a kept Summary (`## Goal` heading, 1–2 sentences).
- Manual steps use labeled **Before merge** / **After merge** subsections; the after-merge
  group is omitted when no post-merge-only verification applies ("if applicable").
- The omit-when-empty rule is uniform across every group. `### Automated` is shown with
  results or a `Not run (reason)` line whenever an automated check could have run, and
  omitted entirely when none is applicable to the change (rather than emitting a `Not run`
  placeholder).
