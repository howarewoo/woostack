# Development Guide

End-to-end workflow for shipping a change into a project bootstrapped from this spec. Designed for AI-driven development with human oversight at key gates.

## The loop

```
brainstorm → spec → grill → plan → execute → PR → review → address → (loop) → merge
```

Every change runs the same path. Skipping steps is a smell — the loop exists so that intent is clear before code is written, and so that review feedback is acted on systematically.

## Branching model

| Branch | Role | Parent | Direction |
|---|---|---|---|
| `main` | Production. What's running for users. | — | Receives from `staging` only |
| `staging` | Integration. Pre-prod testing. | `main` | Receives from feature branches |
| `feature/<name>` | One change. One PR. | `staging` | Merged into `staging` via PR |

**Rules:**
- Every feature branch is cut from `staging`, not `main`.
- Every PR targets `staging`.
- `staging` is merged into `main` on a regular cadence (weekly, or per release) after manual/automated testing on the staging environment.
- Never PR directly into `main` except for emergency hotfixes (and even then, cherry-pick into `staging` immediately after).
- Never force-push to `main` or `staging`.

Use Graphite (`gt create`, `gt modify`, `gt submit`) to manage stacks. `gt create --base staging` for the initial branch.

## Step 1 — Brainstorm

Use the **`brainstorming`** skill from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/brainstorming).

Goal: explore the problem space, surface unknowns, expose hidden assumptions. Output is a rough idea, not a commitment.

Trigger when:
- The change isn't yet a concrete spec.
- Multiple approaches are viable and the trade-offs aren't obvious.
- The requirements are vague or aspirational.

Skip when:
- The change is a small fix with one obvious path.
- The user has already written a clear spec.

## Step 2 — Spec

Write a short feature spec. Markdown file under `docs/specs/<feature-name>.md` in the project repo. Captures:

- **Problem** — what's broken or missing.
- **Goal** — desired end state, in user-visible terms.
- **Non-goals** — what's explicitly out of scope.
- **Approach** — chosen direction at a high level (no code yet).
- **Open questions** — anything unresolved going into the grill step.

Keep it tight — one page is plenty for most features.

## Step 3 — Grill

Run the **`grill-me`** skill against the spec. Adversarial review that hammers on edge cases, hidden assumptions, and unstated requirements. The agent asks hard questions; the human (or AI) answers them by amending the spec.

A spec that survives grilling is one where:
- Every open question is resolved or explicitly deferred.
- Edge cases are enumerated.
- Failure modes are documented.
- Cross-cutting impact (auth, RLS, API stability, performance) is acknowledged.

Iterate until the grilling stops producing new questions.

## Step 4 — Plan

Use the **`writing-plans`** skill from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/writing-plans).

Turn the grilled spec into an executable plan: ordered, concrete steps that an agent can work through. Each step has a clear definition of done.

Output lives in `docs/plans/<feature-name>-plan.md` or equivalent. Plan references the spec — they're sibling documents.

Plans are written **before** any code. If the plan can't be written, the spec isn't ready.

## Step 5 — Execute

Cut a branch from `staging`:

```bash
gt create feature/<name> --base staging
```

Then use the **`executing-plans`** skill from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/executing-plans) to work the plan top to bottom.

Constraints during execution:
- TDD per [patterns.md#7-test-driven-development](patterns.md#7-test-driven-development) — red, green, refactor.
- Stay within the plan. New surface area requires a plan amendment, not a quiet expansion.
- Verify each step before moving on — use **`verification-before-completion`** from superpowers.
- Commit early and often via Graphite (`gt modify` to amend the current stack entry).

## Step 6 — Open PR

```bash
gt submit
```

Targets `staging` automatically when the branch was cut from `staging`. PR title uses conventional commit format. Body fills out the project's PR template.

Optional: use the **`requesting-code-review`** skill from superpowers to write a tight reviewer brief.

## Step 7 — Review

Invoke the **`woo-review`** skill from [howarewoo/woo-review](https://github.com/howarewoo/woo-review) against the PR. Configurable as either a GitHub Action or a manual invocation, depending on the project setup.

`woo-review` produces structured findings posted to the PR — bugs, missing tests, architecture violations, and deviations from the patterns in [patterns.md](patterns.md).

## Step 8 — Address feedback

Use the **`receiving-code-review`** skill from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/receiving-code-review).

Workflow:
1. Read all review comments before changing anything.
2. Group findings by category (bug, design, style, nit).
3. Respond inline to each one — either commit a fix, push back with reasoning, or defer with a follow-up issue.
4. Push a new commit on the same branch (`gt modify`).
5. Re-request review.

## Step 9 — Loop steps 7–8

Re-run `woo-review` after every fix push. Continue until:
- All blocking findings addressed.
- No new findings on the latest review pass.
- The PR is approved.

## Step 10 — Merge

Squash-merge into `staging` (preserve a single commit per feature; the granular history lives in the PR).

```bash
gh pr merge --squash --delete-branch
```

## Step 11 — Promote `staging` → `main`

On a regular cadence (or when a release is cut):

1. Run integration tests against the `staging` environment.
2. Manual smoke test of key flows.
3. Open a PR from `staging` to `main` titled `release: YYYY-MM-DD`.
4. Run `woo-review` against the release PR (catches anything that snuck through).
5. Merge with a **merge commit** (preserve individual feature commits in `main` history).
6. Tag the release: `git tag vYYYY.MM.DD && git push --tags`.

Hotfixes: branch from `main`, PR to `main`, then immediately cherry-pick (or merge) into `staging` so the two don't diverge.

## Required skills

For projects bootstrapped from this spec, ensure these skills are installed on the contributor's machine (or in CI for automated steps):

| Skill | Source | Role |
|---|---|---|
| `brainstorming` | [obra/superpowers](https://github.com/obra/superpowers) | Step 1 |
| `grill-me` | community (`/grill-me`) | Step 3 |
| `writing-plans` | [obra/superpowers](https://github.com/obra/superpowers) | Step 4 |
| `executing-plans` | [obra/superpowers](https://github.com/obra/superpowers) | Step 5 |
| `verification-before-completion` | [obra/superpowers](https://github.com/obra/superpowers) | Step 5 |
| `test-driven-development` | [obra/superpowers](https://github.com/obra/superpowers) | Step 5 |
| `using-git-worktrees` | [obra/superpowers](https://github.com/obra/superpowers) | Optional — isolate concurrent work |
| `requesting-code-review` | [obra/superpowers](https://github.com/obra/superpowers) | Step 6 |
| `woo-review` | [howarewoo/woo-review](https://github.com/howarewoo/woo-review) | Step 7 |
| `receiving-code-review` | [obra/superpowers](https://github.com/obra/superpowers) | Step 8 |
| `finishing-a-development-branch` | [obra/superpowers](https://github.com/obra/superpowers) | Step 10 |

Install superpowers per its [README](https://github.com/obra/superpowers). Install `woo-review` per its [README](https://github.com/howarewoo/woo-review) — it ships as both a GitHub Action and a Claude Code skill.

## When to deviate

The loop is the default. Bypassing steps is allowed when the change is genuinely small (typo fix, comment edit, version bump) or genuinely urgent (production incident).

Document any deviation in the PR description so reviewers understand why the usual gates were skipped.
