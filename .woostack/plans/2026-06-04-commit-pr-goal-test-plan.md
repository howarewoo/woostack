# woostack-commit PR body: Goal + structured test plan — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `woostack-commit` so PR bodies open with a `## Goal` section and split the test plan into `### Automated` and `### Manual` (with **Before merge** / **After merge** groups).

**Architecture:** Documentation-only change to a single skill file. Edit four spots in `skills/woostack-commit/SKILL.md` — the PR-body template, the step-7 filling rules, the fast-subagent draftable-field list, and the description frontmatter + step-8 report — keeping them mutually consistent.

**Tech Stack:** Markdown. No code, no build, no test harness in this repo for its own skill markdown.

**Spec:** `.woostack/specs/2026-06-04-commit-pr-goal-test-plan.md`

**Verification note:** This repo has no automated tests/CI for its skill markdown, so there is no failing-test-first loop. Each task's verification is a structured read confirming the edited text matches the spec and stays internally consistent. State `Not run` honestly for automated coverage.

---

### Task 1: Replace the PR-body template

**Files:**
- Modify: `skills/woostack-commit/SKILL.md` — the template block under step 7 (currently the fenced markdown at lines ~190–200, the `## Summary` + `## Test plan` block)

- [x] **Step 1: Replace the template block**

Replace the existing fenced block:

````markdown
```markdown
## Summary

- <concise bullet describing a user-visible or reviewer-relevant change>
- <concise bullet describing another relevant change>

## Test plan

- [x] <command run and result, or "Not run (reason)">
- [x] <manual verification step, when a meaningful one exists>
```
````

with:

````markdown
```markdown
## Goal

<1-2 sentences: why this PR exists / the problem it solves>

## Summary

- <concise bullet describing a user-visible or reviewer-relevant change>
- <concise bullet describing another relevant change>

## Test plan

### Automated

- [x] <command run and result, or "Not run (reason)">

### Manual

**Before merge**

- [x] <step a reviewer can inspect or exercise on the branch or preview>

**After merge**

- [x] <step only verifiable post-merge — deploy / migration / env-gated>
```
````

- [x] **Step 2: Verify**

Read the block back. Confirm `## Goal` precedes `## Summary`, and `## Test plan` contains `### Automated` then `### Manual` with bold `**Before merge**` / `**After merge**` groups. No stray old bullets remain.

---

### Task 2: Rewrite the step-7 filling rules

**Files:**
- Modify: `skills/woostack-commit/SKILL.md` — the `Rules:` bullet list under step 7 (currently lines ~202–211)

- [x] **Step 1: Replace the rules list**

Replace the current bullet list (from `- Keep bullets concise and specific.` through `- If tests were not run, say `Not run`...`) with a list that:

1. Keeps: bullets concise/specific; include only committed-diff changes; preserve still-accurate existing context; replace stale generated content; checkbox format for test-plan items.
2. Adds a **Goal** rule: state intent or the problem solved in 1–2 sentences — not a change list; distinct from Summary, which lists *what* changed. Always present.
3. Adds an **Automated** rule: list commands/tests actually run, plus the configured `commit.pre_commit` command and result when it ran. Show this group whenever an automated check (test, lint, typecheck, `pre_commit`) could have run for the change — list results, or `Not run` with the reason when one was expected but skipped. Omit `### Automated` entirely when no automated check is applicable (e.g. a doc-only edit in a repo with no test harness); do not emit a `Not run` placeholder then.
4. Adds a **Manual** rule with two groups:
   - **Before merge** — what a reviewer can inspect or exercise now: read the diff, run the command locally, exercise the change on the branch or a preview. Keep a concrete example (e.g. `Run /woostack-commit on a dirty feature branch and confirm the PR body shows Goal, Summary, and the Automated/Manual test plan`).
   - **After merge** — verification that cannot happen until the PR lands (staging/prod deploy behavior, migrations, env-specific config). Omit this group when nothing applies — this is the "if applicable".
5. Adds the uniform **omit-when-empty** rule: omit any empty group (`### Automated`, `### Manual`, or either before/after block) rather than leaving placeholder bullets.

Concretely, the replacement list:

```markdown
Rules:

- State the **Goal** as intent or the problem solved in one or two sentences — not a change list. It is distinct from Summary, which lists *what* changed. Always present.
- Keep Summary bullets concise and specific. Include only changes in the committed diff.
- Under **Automated**, list the commands/tests actually run, plus the configured `commit.pre_commit` command and result when it ran. Show this group whenever an automated check (test, lint, typecheck, `pre_commit`) could have run for the change: list results, or `Not run` with the reason when one was expected but skipped. Omit `### Automated` entirely when no automated check applies to the change (for example a doc-only edit in a repo with no test harness) rather than emitting a `Not run` placeholder.
- Under **Manual**, group human verification into **Before merge** (steps a reviewer can inspect or exercise now — read the diff, run the command locally, exercise the change on the branch or a preview, for example `Run /woostack-commit on a dirty feature branch and confirm the PR body shows Goal, Summary, and the Automated/Manual test plan`) and **After merge** (verification only possible once the PR lands — staging/prod deploy behavior, migrations, env-specific config). Include the After-merge group only when such steps exist; this is the "if applicable".
- Omit any empty group — `### Automated`, `### Manual`, or either before/after block — rather than leaving placeholder bullets.
- Preserve important existing PR context when it is still accurate. Replace stale generated summaries/test plans with the current ones.
- Format test-plan items as unchecked Markdown checkboxes (`- [ ] ...`) so reviewers can mark verification complete.
```

- [x] **Step 2: Verify**

Read the rules list back. Confirm every section of the new template (Goal, Summary, Automated, Manual/before, Manual/after) has a governing rule, the omit-when-empty rule is uniform, and no rule still references a single flat test-plan list.

---

### Task 3: Update the fast-subagent draftable-field list

**Files:**
- Modify: `skills/woostack-commit/SKILL.md` — the "Fast-subagent drafting" bullet listing draftable text (currently lines ~48–50: "PR title candidate, Summary bullets, and Test plan bullets.")

- [x] **Step 1: Add Goal to the list**

Change the delegated-text bullet so the draftable fields read: commit subject/body candidate, PR title candidate, **Goal line**, Summary bullets, and Test plan bullets (Automated and Manual).

- [x] **Step 2: Verify**

Confirm the draftable list now names the Goal and reflects the Automated/Manual test-plan shape, and the "subagent returns only proposed text / main agent validates" boundary is unchanged.

---

### Task 4: Update description frontmatter and step-8 report

**Files:**
- Modify: `skills/woostack-commit/SKILL.md` — `description:` frontmatter (line 3) and the step-8 "Report" return list (lines ~219–227)

- [x] **Step 1: Update the description**

Reword the trailing clause of the `description:` so it reflects the new body shape, e.g. "...update the current PR title/body with a goal, concise summary, and structured (automated + manual) test plan." Keep the trigger phrases intact.

- [x] **Step 2: Update the step-8 report list**

Add `Goal used` to the returned fields alongside Summary bullets and Test plan bullets, so the report mirrors the body sections.

- [x] **Step 3: Verify**

Confirm description still fits on sensible length, trigger phrases preserved, and the report list mentions Goal + the test-plan sections.

---

### Task 5: Whole-file consistency pass and commit

**Files:**
- Read: `skills/woostack-commit/SKILL.md` (entire file)

- [x] **Step 1: Full read-through**

Read the whole file. Confirm: no remaining reference to a flat single-section test plan; the template, rules, fast-subagent list, description, and report all agree; the omit-when-empty and after-merge "if applicable" semantics are stated once and consistent; no placeholder text introduced.

- [x] **Step 2: Commit**

Hand off to `woostack-commit` (build step 8 offers the PR). Until then, the change sits staged on the branch. Automated tests: `Not run` — this repo has no test harness for its own skill markdown (doc-only change).
