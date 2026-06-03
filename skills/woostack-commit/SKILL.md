---
name: woostack-commit
description: Commit the current session-relevant changes, create a feature branch first when needed, push with Graphite, and update the current PR title/body with a concise summary and test plan. Use for /woostack-commit, "commit this", "commit the current changes", "update the PR", or when finishing a woostack change before review.
---

# woostack-commit

Commit only the changes relevant to the current session, then update the pull request so reviewers see the latest intent, summary, and test plan.

This skill is local-only. It mutates git state and PR metadata, but it never merges, force-pushes, or stages unrelated work.

## Commands

- `/woostack-commit` — Commit the session-relevant changes and update the current PR.
- `/woostack-commit <message>` — Use `<message>` as the commit subject if it accurately describes the staged change.

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

- Delegate only text drafting: commit subject/body candidate, PR title candidate, Summary
  bullets, and Test plan bullets.
- Pass a bounded prompt containing the staged diff, changed-file list, commands run and
  results, relevant user intent, and any existing PR title/body that should be preserved.
- Use the host's fast model when it can be selected explicitly. Follow the `fast` tier in
  [`../woostack-review/prompts/_header.md`](../woostack-review/prompts/_header.md) for
  provider-specific defaults, such as `claude-haiku-4-5` for Anthropic,
  `gpt-5.3-codex-spark` for OpenAI Codex, `gemini-3-5-flash` for Gemini, or
  `openrouter/deepseek/deepseek-v4-flash` for OpenRouter. If the host cannot route a
  subagent to a fast model, draft inline in the main session.
- The subagent must return only proposed text. It must not run commands, stage files,
  commit, push, edit PRs, or decide whether dirty files are relevant.
- Before using any draft, compare it against the staged diff and command results. Rewrite or
  discard anything stale, overstated, vague, or unsupported.

## Workflow

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

Never commit directly to protected integration branches: `main`, `staging`, `beta`, or `alpha`. These branch names do not need to exist in every repo, but when the current branch is one of them, create a `feature/*` branch before staging or committing.

- If current branch matches `feature/*`, continue.
- If current branch is `main`, `staging`, `beta`, or `alpha`, create a new feature branch from the current branch before staging:

```bash
gt create feature/<short-slug>
```

- If current branch is anything else, stop and ask whether to continue on the current branch or create a new `feature/*` branch.

Use a short slug based on the change, such as `feature/review-model-defaults` or `feature/add-commit-skill`. Prefer Graphite (`gt`) for branch creation. Fall back to raw `git switch -c feature/<short-slug>` only when Graphite is unavailable or clearly not initialized.

Never force-push. Never commit directly to `main`, `staging`, `beta`, or `alpha`.

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

Do not stage generated files, secrets, `.env*`, unrelated dirty files, or user work from outside this session.

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

Prefer Graphite:

```bash
gt submit
```

If a PR already exists, `gt submit` should update it. If Graphite is unavailable, push the branch and use `gh pr create` or `gh pr edit` as appropriate.

Do not merge. Do not force-push.

### 7. Update PR fields

Update the PR after the commit/push so the PR reflects the latest branch state.

Use a validated fast-subagent draft for the PR title/body when available. The main agent
must still preserve accurate existing context, remove stale generated content, and ensure
the Summary and Test plan mention only committed changes and real verification.

Resolve the PR:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url
```

If no PR exists after submit/push, create one targeting `staging`:

```bash
gh pr create --base staging --head "$(git branch --show-current)" --title "<concise title>" --body-file <tmp-body-file>
```

Set or update the body with this structure:

```markdown
## Summary

- <concise bullet describing a user-visible or reviewer-relevant change>
- <concise bullet describing another relevant change>

## Test plan

- [ ] <command run and result, or "Not run (reason)">
- [ ] <manual verification step, when a meaningful one exists>
```

Rules:

- Keep bullets concise and specific.
- Include only changes in the committed diff.
- Preserve important existing PR context when it is still accurate.
- Replace stale generated summaries/test plans with the current ones.
- Format test-plan items as unchecked Markdown checkboxes (`- [ ] ...`) so reviewers can mark verification complete.
- Include the configured `commit.pre_commit` command and result when it ran.
- Prefer concrete manual verification steps when automated tests are unavailable, not run, or insufficient. Manual steps should describe what a reviewer can inspect or exercise, for example `Review the updated skill routing table in README.md` or `Run /woostack-commit on a dirty feature branch and confirm the PR body includes Summary and Test plan sections`.
- If tests were not run, say `Not run` and give the reason, then include manual verification steps when possible.

Update with:

```bash
gh pr edit <number> --title "<concise title>" --body-file <tmp-body-file>
```

### 8. Report

Return:

- Branch name.
- Commit subject/SHA if available.
- PR URL.
- Summary bullets used.
- Test plan bullets used.

Do not claim tests passed unless you ran them and saw passing output.
