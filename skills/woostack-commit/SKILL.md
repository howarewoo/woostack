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

**Always stage `.woostack/memory/` changes.** Distilled memory notes are session work by
definition in the woostack loop — never "unrelated dirty files." Stage every non-ignored
change under `.woostack/memory/` (modifications, additions, and the note deletions distill's
dedupe makes), folded into the same commit as the code, with no relevance check and no
stop-and-ask:

```bash
[ -d .woostack/memory ] && git add .woostack/memory/
```

Plain `git add` (never `-f`) honors `.gitignore`, so ignored paths such as
`.woostack/memory/metrics.json` and `*.local.*` are skipped automatically — "unless
gitignored" needs no `git check-ignore` step. The `[ -d … ]` guard makes this a silent no-op
outside a woostack repo, where a bare `git add` of an absent path would exit non-zero with
`fatal: pathspec '.woostack/memory/' did not match any files`.

Do not stage generated files, secrets, `.env*`, unrelated dirty files, or user work from outside this session — the `.woostack/memory/` rule above is the sole exception to "unrelated dirty files."

### 4.5 Invariant check (advisory)

When the staged changes touch `.woostack/specs/*.md` or `.woostack/plans/*.md`, run the cheap feature-state invariant checks on every affected spec so the `/woostack-status` board stays honest. The affected set is every directly touched spec plus the spec named by each touched plan's `**Source:** .woostack/specs/<file>.md` line. These are **advisory**: print any violation as a single non-blocking line in the commit report and continue. Never abort, stage differently, or change the commit because of them.

For each affected spec, check:

- **1:1 plan** — exactly one plan resolves to it: a plan whose first lines carry `**Source:** .woostack/specs/<file>.md` (legacy same-slug match is the fallback). Zero or two-or-more resolved plans is a violation.
- **`branch:` present** — the frontmatter `branch:` is non-empty and not the literal `unknown`.
- **`status:` in the enum** — the frontmatter `status:` is one of `draft｜hardened｜approved｜planning｜executing｜in-review｜done｜abandoned`.

The phase enum and the join contracts are defined once in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md) — do not restate them here. If the `woostack-status` skill is not installed, skip this check silently.

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

If the `--no-pr-update` flag is specified (or if a context signal like `WOOSTACK_COMMIT_NO_PR_UPDATE=1` is set in the environment), skip updating the PR title and body description (do not run `gh pr edit`), but still ensure the PR is created if it does not exist.

Use a validated fast-subagent draft for the PR title/body when available. The main agent
must still preserve accurate existing context, remove stale generated content, and ensure
the Goal, Summary, and Test plan mention only committed changes and real verification.

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

Rules:

- End the body with a `Spec: .woostack/specs/<file>.md` **trailer line** naming the spec this PR's increments trace to — the spec whose `branch:` matches the current branch, or the spec under active work. The `/woostack-status` board enumerates a spec's increment PRs by searching this exact trailer (`gh pr list --search "Spec: <path>"`); the contract is defined in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md). Omit the trailer only when the change traces to no spec (for example a repo-meta or tooling edit).
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
- Goal used.
- Summary bullets used.
- Test plan bullets used (Automated and Manual).

Do not claim tests passed unless you ran them and saw passing output.
