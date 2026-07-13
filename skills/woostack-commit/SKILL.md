---
name: woostack-commit
description: Commit the current session-relevant changes, create a feature branch first when needed, push with Graphite, and update the current PR title/body with a goal, concise summary, and structured (automated + manual) test plan. Use for /woostack-commit, "commit this", "commit the current changes", "update the PR", or when finishing a woostack change before review.
---

# woostack-commit

Commit only the changes relevant to the current session, then update the pull request so reviewers see the latest intent, summary, and test plan.

This skill is local-only. It mutates git state and PR metadata, but it never merges, force-pushes, or stages unrelated work.

## Commands

- `/woostack-commit` — Commit the session-relevant changes and update the current PR.
- `/woostack-commit <message>` — Use `<message>` as the commit subject if it accurately describes the staged change.
- `/woostack-commit --no-pr-update [<message>]` — Commit the session-relevant changes and push/submit without updating the pull request's title or body description.

## Optional config

Consumers may add a commit hook command under `.woostack/config.json`:

```json
{
  "commit": {
    "pre_commit": "pnpm format && pnpm test"
  }
}
```

`commit.pre_commit` is a shell command run from the repo root after branch resolution and before staging. Use it for formatters, linters, test runners, or a repo-local script such as `./scripts/pre-commit.sh`.

Rules:

- Treat a missing `.woostack/config.json` or missing `commit.pre_commit` as no-op.
- Run the command exactly once per `/woostack-commit` invocation.
- If it exits non-zero, stop immediately. Do not stage, commit, push, or update PR fields.
- If it modifies files, include those changes only when they are relevant to the session change; otherwise stop and ask.
- Report the command and result in the PR test plan.

## Fast-subagent drafting

Use a fast-tier subagent to draft commit and PR text when the host supports subagents with
model routing. This is a cost optimization for the mechanical writing portion only; the
main agent remains responsible for all git, Graphite, GitHub, staging, relevance, and final
verification decisions.

Rules:

- Delegate only text drafting: commit subject/body candidate, PR title candidate, Goal line,
  Summary bullets, and Test plan bullets (Automated and Manual).
- Pass a bounded prompt containing the staged diff, changed-file list, commands run and
  results, relevant user intent, and any existing PR title/body that should be preserved.
- Route the subagent at the `fast` tier when the host can select it explicitly: resolve the
  tier through the shared [Model Tiers table](../using-woostack/references/model-tiers.md) and pass
  what it resolves to on the spawn. **Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).
  If the host can neither route a subagent per call nor select an agent-by-tier definition,
  draft inline in the main session.
- The subagent must return only proposed text. It must not run commands, stage files,
  commit, push, edit PRs, or decide whether dirty files are relevant.
- Before using any draft, compare it against the staged diff and command results. Rewrite or
  discard anything stale, overstated, vague, or unsupported.

## Workflow
### 0. Resolve the artifact backend

Before inspection, invariant checks, or any fast-subagent/inline drafting, run the installed
backend resolver (`<wi>` = the installed `woostack-init` scripts directory):

```bash
ARTIFACT_CONTEXT="$(bash <wi>/artifacts/resolve-backend.sh <repo-root>)"
```

Require one successful normalized result and retain its `backend`, `repository`, and resolved
Linear UUID context for the whole invocation. Do not inspect invariants, dispatch a drafting
subagent, or draft commit/PR text before this succeeds. Branch only on the returned `backend`;
never infer it from `.woostack/` files, the current branch, credentials, or caller arguments,
and never fall back from Linear to Markdown.

In Linear mode the driving execution flow must also supply the managed project UUID and issue
identifier (`<TEAM-NUMBER>`) selected for this increment. Treat missing or malformed execution
context as an error; never guess an issue from a branch name, title, or recent activity.


### 1. Inspect state

Run read-only inspection:

```bash
pwd
gt status 2>/dev/null || git status --short --branch
gh pr view --json number,title,body,headRefName,baseRefName,url 2>/dev/null || true
```

Identify:

- Current branch.
- Open PR, if any.
- Changed files.
- Which changes are relevant to the current user/session.

If relevance is ambiguous, stop and ask the user before staging.

### 2. Enforce branch shape before committing

Resolve the integration branch before checking the current branch (`<wi>` = the installed `woostack-init` scripts dir):

```bash
base="$(bash <wi>/resolve-base.sh)"
```

Never commit directly to protected integration branches: the resolved `$base`, plus conventional protected names `main`, `staging`, `beta`, or `alpha`. These branch names do not need to exist in every repo, but when the current branch is one of them, create a `feature/*` branch before staging or committing.

- If current branch matches `feature/*` or `fix/*`, continue.
- If current branch is `$base`, `main`, `staging`, `beta`, or `alpha`, create a new feature branch from the resolved integration branch before staging:

```bash
git switch "$base"
gt create feature/<short-slug>
gt track feature/<short-slug> --parent "$base"
```

- If current branch is anything else, stop and ask whether to continue on the current branch or create a new `feature/*` branch.

Use a short slug based on the change, such as `feature/review-model-defaults` or `feature/add-commit-skill`. Prefer Graphite for branch creation and tracking: switch to the resolved base, run `gt create feature/<short-slug>`, then ensure the parent is registered with `gt track feature/<short-slug> --parent "$base"`. If Graphite is unavailable or clearly not initialized, fall back to raw git only: `git switch -c feature/<short-slug> "$base"`.

**Running inside a worktree:** when a driving skill (build / execute / fix) has already created a per-PR worktree on a `feature/*` or `fix/*` branch (see the [worktree contract](../woostack-init/references/worktrees.md)), this step finds a non-protected branch and continues — `woostack-commit` commits whatever tree it is invoked in and creates no second branch.

Never force-push. Never commit directly to `$base`, `main`, `staging`, `beta`, or `alpha`.

### 3. Run configured pre-commit command

If `.woostack/config.json` has `commit.pre_commit`, run it from the repo root before staging:

```bash
jq -r '.commit.pre_commit // empty' .woostack/config.json
```

If the value is non-empty, execute it with the user's shell:

```bash
<pre_commit command>
```

If the command fails, stop and report the failure. If the command succeeds and changes files, reassess relevance before staging.

### 4. Stage only session-relevant changes

Use targeted staging:

```bash
git add <file1> <file2>
```

When a file contains unrelated hunks, use interactive patch staging:

```bash
git add -p <file>
```

Tracked `.woostack/memory/` notes and `MEMORY.md` may be staged when they are relevant to the
current change ([memory contract](../woostack-init/references/memory.md)). Do not stage local
sidecars such as `.telemetry.tsv` or `.dream-watermark`, generated files, secrets, `.env*`,
unrelated dirty files, or user work from outside this session.

### 4.5 Backend-specific invariant and attribution checks

#### Markdown

When the staged changes touch `.woostack/specs/*.md`, `.woostack/plans/*.md`, or `.woostack/fixes/*.md`, run the cheap feature-state invariant checks on every affected spec/fix so the `/woostack-status` board stays honest. The affected set is every directly touched spec/fix plus the spec named by each touched plan's `source:` frontmatter or `**Source:**` line (a `[[specs/<basename>]]` wikilink, or the legacy `.woostack/specs/<file>.md` path). These are **advisory**: print any violation as a single non-blocking line in the commit report and continue. Never abort, stage differently, or change the commit because of them.

For each affected spec/fix, check:

- **1:1 plan** — exactly one plan resolves to it (for specs). (For fixes under `fixes/`, they are self-contained plans and this check is skipped).
- **`branch:` present** — the active lifecycle artifact frontmatter (`spec` before planning, `plan` after planning, `fix` for fixes) is non-empty and not the literal `unknown`.
- **`status:` in the enum** — spec frontmatter uses `draft|hardened|approved|abandoned`; plan frontmatter uses `planning|ready|executing|in-review|done|abandoned`; fix frontmatter uses the full fix lifecycle.

The phase enum and the join contracts are defined once in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md) — do not restate them here. If the `woostack-status` skill is not installed, skip this check silently.

#### Linear

Linear attribution is blocking, not advisory. Validate the preflight-resolved `LINEAR_CONTEXT`,
then extract `LINEAR_PROJECT_STATUSES="$(jq -c '.projectStatuses' <<<"$LINEAR_CONTEXT")"` and
`LINEAR_ISSUE_STATES="$(jq -c '.issueStates' <<<"$LINEAR_CONTEXT")"`. Using the repository,
project UUID, issue identifier, and those extracted UUID maps, fetch the managed project and issue
set with `linear.sh feature-read`. Require successful API verification, require the returned
`feature.id` equals the supplied project UUID, and select exactly one increment whose `identifier`
equals the supplied `<TEAM-NUMBER>`. The selected issue must come from that verified feature issue
set, be managed by woostack, be owned by the resolved repository, and be in the execution
lifecycle expected by the driving flow.

Before commit or submission, validate the proposed PR body against that verified pair. It must
end with exactly one `Linear-Project:` trailer containing `<uuid>` and exactly one
`Linear-Issue:` trailer containing `<TEAM-NUMBER>`, in that order, whose rendered lines are
`Linear-Project: <uuid>` and `Linear-Issue: <TEAM-NUMBER>` and whose values exactly equal the fetched
project and issue. A mismatch, duplicate trailer, foreign project issue, missing issue,
ambiguous issue, malformed identifier, missing credentials, missing or failed API verification,
or adapter failure must block submission and PR update. Do not include a `Spec:` trailer in a
Linear-backed PR. Existing PR bodies with any Linear attribution are subject to the same exact
check; do not silently normalize or replace foreign, mismatched, partial, or duplicate
attribution. One recovery case is allowed when PR updates are enabled: the verified current
branch's existing PR may have neither Linear trailer. Treat it as unattributed, validate the
proposed body containing the exact pair, and add that pair through the post-submit `gh pr edit`
path. `--no-pr-update` never permits this missing-pair recovery.

### 5. Commit

If a fast-subagent draft is available, use it only after validating that the proposed
subject describes the staged diff accurately and follows the rules below.

Prefer Graphite:

```bash
gt modify -m "<type>: <concise subject>"
```

Use `gt create -m "<type>: <concise subject>"` only when creating the branch and committing in one Graphite flow is appropriate for the local stack state. Fall back to raw git only when Graphite is unavailable:

```bash
git commit -m "<type>: <concise subject>"
```

Commit message rules:

- Use a concise conventional subject, usually `feat:`, `fix:`, `docs:`, or `chore:`.
- Mention the real change, not the process.
- Add a body only when the reason is not obvious from the diff.

### 6. Push or submit

#### Markdown

Prefer Graphite:

```bash
gt submit
```

If a PR already exists, `gt submit` should update it. If Graphite is unavailable, push the branch and use `gh pr create` or `gh pr edit` as appropriate.

#### Linear

Graphite submission is mandatory because the verified issue owns one exact branch/PR
attribution pair. Run `gt submit` and require success; do not use raw-git or `gh pr create`
fallbacks when it fails or Graphite is unavailable. A failed submit leaves the issue unchanged
and blocks PR update.

Do not merge. Do not force-push.

### 7. Resolve and attribute the PR

Resolve the PR after the successful commit/push so it reflects the latest branch state.

If the `--no-pr-update` flag is specified (or if a context signal like
`WOOSTACK_COMMIT_NO_PR_UPDATE=1` is set in the environment), skip updating the PR title and body
description and do not run `gh pr edit`, but still ensure the PR is created if it does not exist.
In Linear mode this branch requires the existing PR body to carry the exact verified trailer
pair, then still records attribution through `linear.sh issue-transition` and performs the
mandatory `feature-read` read-back. The flag skips only the field edit; it never skips attribution
validation, adapter recording, or read-back.

Use a validated fast-subagent draft for the PR title/body when available. The main agent
must still preserve accurate existing context, remove stale generated content, and ensure
the Goal, Summary, and Test plan mention only committed changes and real verification.

Resolve the PR:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url
```

If no PR exists after submit/push, create one targeting the resolved base branch (`<wi>` = the installed `woostack-init` scripts dir, as in step 2):

```bash
base="$(bash <wi>/resolve-base.sh)"
gh pr create --base "$base" --head "$(git branch --show-current)" --title "<concise title>" --body-file <tmp-body-file>
```

For a **stacked** increment PR the base is the **parent branch**, not `$base` (see the [worktree contract](../woostack-init/references/worktrees.md) §4); Graphite sets it automatically via `gt submit` when the branch was `gt track --parent`ed.

For Linear, a PR must already exist from the successful Graphite submit. Require its head branch
to equal `git branch --show-current`, its repository to equal the backend resolver's repository,
and its URL to be the canonical PR URL for that repository. Unless `--no-pr-update` applies,
apply the validated title/body with `gh pr edit`, then re-fetch its body with `gh pr view` and
require the exact verified trailer pair. With `--no-pr-update`, require the submitted PR body
already contains that exact pair. An edit failure, read failure, missing trailer, duplicate,
or mismatch leaves the issue unchanged. Only after `gt submit` succeeds and all of these checks
pass, invoke the atomic state-plus-evidence transition exactly once through the adapter:

```bash
linear.sh issue-transition \
  --project "<verified-project-uuid>" \
  --repository "<owner/repo>" \
  --issue "<TEAM-NUMBER>" \
  --issue-state-map "$LINEAR_ISSUE_STATES" \
  --target inReview \
  --branch "<submitted-branch>" \
  --pull-request "<canonical-pr-url>"
```

Immediately call `linear.sh feature-read` with both captured UUID maps regardless of whether
the mutation returned success, an error, or timed out; never infer mutation outcome from the
transport result. Resolve the outcome only from the owned project/issue read-back:

- The exact intended read-back is success: one matching issue has the exact submitted branch and PR URL
  in managed metadata, `status: inReview`, and the verified project UUID. When a mutation
  receipt was returned, also require `verified: true` and an empty `pending` array.
- An unchanged issue still at `executing` with no branch/PR evidence is a safe stopped outcome.
  Do not retry in the same invocation; only a later explicit resume may retry after another
  fresh read confirms the same unchanged state.
- Any partial or mismatched evidence requires manual reconciliation. Do not retry, overwrite
  evidence, edit lifecycle state separately, or report success.
- A failed or ambiguous read-back is unresolved. Stop without retrying or changing the PR again.

Never write branch/PR evidence before successful submission and exact PR-body verification,
and never write it directly through GraphQL or PR text; the adapter owns the atomic mutation
and read-back.

Compose the validated body with this structure. Markdown sets or updates it at this point;
Linear applied and verified it before adapter attribution above:

```markdown
## Goal

<1-2 sentences: why this PR exists / the problem it solves>

## Summary

- <concise bullet describing a user-visible or reviewer-relevant change>
- <concise bullet describing another relevant change>

## Test plan

### Automated

- [ ] <command run and result, or "Not run (reason)">

### Manual

**Before merge**

- [ ] <step a reviewer can inspect or exercise on the branch or preview>

**After merge**

- [ ] <step only verifiable post-merge — deploy / migration / env-gated>

Spec: .woostack/specs/<file>.md
```

For a Linear-backed PR, replace the Markdown `Spec:` trailer with this exact final pair:

```text
Linear-Project: <uuid>
Linear-Issue: <TEAM-NUMBER>
```

Rules:

- **Markdown:** end the body with the exact `Spec: .woostack/specs/<file>.md` or `Spec: .woostack/fixes/<file>.md` **trailer line** naming the spec/fix this PR's increments trace to — the spec/fix whose `branch:` matches the current branch, or the spec/fix under active work. The `/woostack-status` board enumerates a spec/fix's increment PRs by searching this exact trailer (`gh pr list --search "Spec: <path>"`); the contract is defined in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md). Omit the trailer only when the Markdown change traces to no spec/fix (for example a repo-meta or tooling edit).
- **Linear:** the final two nonblank lines are exactly one `Linear-Project: <uuid>` trailer followed by exactly one `Linear-Issue: <TEAM-NUMBER>` trailer. Both values come from the blocking adapter verification in step 4.5. A Linear implementation PR may never omit these trailers or use a Markdown `Spec:` trailer.
- State the **Goal** as intent or the problem solved in one or two sentences — not a change list. It is distinct from Summary, which lists *what* changed. Always present it.
- Keep Summary bullets concise and specific. Include only changes in the committed diff.
- Under **Automated**, list the commands/tests actually run, plus the configured `commit.pre_commit` command and result when it ran. Show this group whenever an automated check (test, lint, typecheck, `pre_commit`) could have run for the change: list results, or `Not run` with the reason when one was expected but skipped. Omit `### Automated` entirely when no automated check applies to the change (for example a doc-only edit in a repo with no test harness) rather than emitting a `Not run` placeholder.
- Under **Manual**, group human verification into **Before merge** and **After merge**. Before-merge steps are what a reviewer can inspect or exercise now — read the diff, run the command locally, exercise the change on the branch or a preview, for example `Run /woostack-commit on a dirty feature branch and confirm the PR body shows Goal, Summary, and the Automated/Manual test plan`. After-merge steps are verification only possible once the PR lands — staging/prod deploy behavior, migrations, env-specific config. Include the After-merge group only when such steps exist; this is the "if applicable".
- Omit any empty group — `### Automated`, `### Manual`, or either before/after block — rather than leaving placeholder bullets.
- Preserve important existing PR context when it is still accurate. Replace stale generated summaries/test plans with the current ones.
- Format test-plan items as unchecked Markdown checkboxes (`- [ ] ...`) so reviewers can mark verification complete.

Update with:

```bash
gh pr edit <number> --title "<concise title>" --body-file <tmp-body-file>
```

### 8. Report

Return:

- Branch name.
- Commit subject/SHA if available.
- PR URL.
- Selected artifact backend; for Linear, the verified project UUID and issue identifier.
- Goal used.
- Summary bullets used.
- Test plan bullets used (Automated and Manual).

Do not claim tests passed unless you ran them and saw passing output.
