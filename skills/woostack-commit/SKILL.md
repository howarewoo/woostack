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
- If it modifies files, include those changes only when they are relevant to the session change; otherwise stop and ask. A verified `change/*` invocation follows the stricter receipt-freshness loop in step 3 instead.
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

## Hard constraints

- Resolve the artifact backend before inspection, invariant checks, or drafting. Never fall back
  from Linear to Markdown.
- A verified `change/*` invocation remains artifact-neutral. Only the canonical isolation and
  Graphite-registration guard enables it.
- Stage only session-relevant changes. Never stage unrelated work, generated sidecars, secrets,
  or `.env*`.
- Never force-push. Do not merge.
- Preserve failure state: a hook, commit, submission, PR edit, adapter mutation, or read-back
  failure stops the workflow at its documented boundary; never infer success from transport
  results or discard evidence needed for an explicit resume.
- Report only commands and results actually observed.

## Workflow
### 0. Resolve the artifact backend

Before inspection, invariant checks, or any fast-subagent/inline drafting, run the installed
backend resolver (`<wi>` = the installed `woostack-init` scripts directory):

```bash
ARTIFACT_CONTEXT="$(bash <wi>/artifacts/resolve-backend.sh <repo-root>)"
```

Require one successful normalized result and retain its `backend`, `repository`, and resolved
Linear UUID context for the whole invocation. Do not inspect invariants, dispatch a drafting
subagent, or draft commit/PR text before this succeeds. The returned `backend` controls artifact
attribution except for a canonical, verified `change/*` invocation established only by the guard
in step 2; never infer that exception from caller arguments, credentials, or an unverified branch
name, and never fall back from Linear to Markdown.

In Linear mode, retain supplied managed project UUID and issue identifier (`<TEAM-NUMBER>`)
execution context when present. After step 2 establishes the invocation mode, require valid
context for every invocation that is not a verified `change/*` invocation; missing or malformed
context is an error, and an issue must never be guessed from a branch name, title, or recent
activity. A verified `change/*` invocation is artifact-neutral even when the resolver returns
Linear: it neither requires nor uses project, issue, spec, or fix attribution. This exception
cannot apply to `feature/*`, `fix/*`, or any other branch, which retain all backend-specific
requirements. Do not perform backend-specific drafting or attribution work until step 2 has
established which path applies.


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
- If current branch matches `change/*`, continue only after verifying the caller's existing isolation and Graphite registration:

```bash
branch="$(git branch --show-current)"
export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
actual_root="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
expected_root="$(cd "$WOOSTACK_ROOT/.woostack/worktrees/${branch//\//-}" && pwd -P)"
test "$actual_root" = "$expected_root"
gt branch info --branch "$branch" --quiet
```

Every command and the path equality must succeed. If the canonical worktree does not exist, the
normalized roots differ, or Graphite does not positively identify the current branch, stop; do not
ask to continue, create another branch, or use the raw-git fallback. Raw git cannot satisfy the
`change/*` guard.
- If current branch is `$base`, `main`, `staging`, `beta`, or `alpha`, create a new feature branch from the resolved integration branch before staging:

```bash
git switch "$base"
gt create feature/<short-slug>
gt track feature/<short-slug> --parent "$base"
```

- If current branch is anything else, stop and ask whether to continue on the current branch or create a new `feature/*` branch.

When branch creation or tracking is needed, load
[`references/graphite.md`](references/graphite.md) for Graphite commands and the raw-git fallback
decision. Never load or use its fallback for a verified `change/*` invocation.

**Running inside a worktree:** when a driving skill (build / execute / fix / `woostack-change`) has already created a per-PR worktree on a `feature/*`, `fix/*`, or `change/*` branch (see the [worktree contract](../woostack-init/references/worktrees.md)), this step finds a non-protected branch and continues — for `change/*`, only after the isolation and Graphite guard above succeeds. `woostack-commit` then commits whatever tree it is invoked in and creates no second branch.

Never force-push. Never commit directly to `$base`, `main`, `staging`, `beta`, or `alpha`.

### 3. Run configured pre-commit command

Read `.woostack/config.json` for `commit.pre_commit`:

```bash
jq -r '.commit.pre_commit // empty' .woostack/config.json
```

For an ordinary invocation, execute a non-empty command with the user's shell. If it fails, stop
and report the failure. If it succeeds and changes files, reassess relevance before staging.

For a verified `change/*` invocation, both skills use the shipped identity helper — never invent a
second hash or path encoding:

```bash
receipt_identity="$(bash <commit-skill-dir>/scripts/change-receipt.sh "$base_ref")"
```

The helper emits one compact JSON object with this canonical schema:

```json
{"branch":"change/example","baseRef":"main","baseCommit":"<oid>","headCommit":"<oid>","baseToHead":"<git-object-hash>","staged":"<git-object-hash>","unstaged":"<git-object-hash>","untracked":[{"pathBase64":"<raw-path-bytes-base64>","object":"<git-object-hash>"}]}
```

It resolves the base and HEAD commits, hashes `git diff --binary --no-ext-diff` payloads with
`git hash-object --stdin`, and lists non-ignored untracked paths in Git's bytewise order as base64
path bytes plus `git hash-object --no-filters` object IDs. Its compact JSON output is the exact
receipt identity; compare it byte for byte.

Require the caller's supplied `woostack-change` `PASS` identity before running the hook (or before
staging when no hook is configured). Re-run the helper with the receipt's `baseRef` and compare
its output exactly with the supplied identity. A branch, base, HEAD, tracked-content, staging, or
untracked mismatch returns immediately to
[`woostack-change`](../woostack-change/SKILL.md) for changed-path verification, smoke testing, and
a fresh full-diff `PASS`/`BLOCKED` review before any hook, staging, or commit.

When a hook is configured and the receipt comparison succeeds, retain that output as the
**pre-hook full identity**, execute the command exactly once with the user's shell, then run the
helper again as the **post-hook full identity**. If the hook fails or the two JSON values differ,
stop before staging or committing and return to `woostack-change` for the same verification and
full-diff review. Only a fresh `woostack-commit` invocation with the new PASS receipt may resume.
Repeat this return → verify → full-diff review → fresh commit invocation loop until the hook makes
no further change. Because branch, base, and HEAD are identity fields, hook-created commits,
checkouts, or ref movement are detected. Never stage or commit under a stale receipt.

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

A **verified `change/*` invocation** is artifact-neutral and skips both backend subsections below,
regardless of the resolver's backend. It performs no Markdown invariant lookup, Linear API
verification or lifecycle transition, and carries no project, issue, spec, or fix attribution.
Only the canonical branch/worktree/Graphite guard in step 2 enables this path; `feature/*` and
`fix/*` always use the resolved backend path.

#### Markdown

When the resolved backend is Markdown, load and follow
[`references/markdown-attribution.md`](references/markdown-attribution.md) for the advisory
artifact invariants and exact `Spec: .woostack/specs/<file>.md` or
`Spec: .woostack/fixes/<file>.md` trailer decision. Load no Linear attribution procedure.

#### Linear

When the resolved backend is Linear:

1. Unless `--no-pr-update` applies, load [`references/pr-body.md`](references/pr-body.md) to compose the proposed title/body; do not apply it yet.
2. Load and follow only [Verify the owned project and issue](references/linear-attribution.md#verify-the-owned-project-and-issue), then stop at the next heading. Do not submit, edit the PR, invoke `issue-transition`, or perform the post-mutation read-back during step 4.5.

Load no Markdown attribution procedure. Missing or failed API verification, foreign project
ownership, or any ambiguous attribution must block submission and PR update.

### 5. Commit

If a fast-subagent draft is available, use it only after validating that the proposed
subject describes the staged diff accurately and follows the rules below.

Commit with `gt modify -m "<type>: <concise subject>"`. Only when branch creation, tracking, or
fallback mechanics are needed, load [`references/graphite.md`](references/graphite.md). For a
verified `change/*` invocation, `gt modify` is mandatory and raw git is forbidden.

Commit message rules:

- Use a concise conventional subject, usually `feat:`, `fix:`, `docs:`, or `chore:`.
- Mention the real change, not the process.
- Add a body only when the reason is not obvious from the diff.

### 6. Push or submit

Submit exactly once on the applicable backend path:

- For Linear, follow only [Submit with Graphite](references/linear-attribution.md#submit-with-graphite), then stop at the next heading.
- For a verified `change/*` invocation, run `gt submit` and require success.
- For Markdown, run `gt submit`. Only when it fails or fallback eligibility must be decided, load [`references/graphite.md`](references/graphite.md).

Any mandatory Graphite failure stops before PR update and retains existing artifact state.

Do not merge. Do not force-push.

### 7. Resolve and attribute the PR

Resolve the PR after the successful commit/push so it reflects the latest branch state.

If the `--no-pr-update` flag is specified (or if a context signal like
`WOOSTACK_COMMIT_NO_PR_UPDATE=1` is set in the environment), skip updating the PR title and body
description and do not run `gh pr edit`, but still ensure the PR is created if it does not exist.
For a non-change Linear invocation, the flag skips only the field edit; continue through the
phase-scoped identity, adapter-recording, and read-back sections below. A verified `change/*`
invocation performs no Linear attribution or adapter mutation.

Resolve the PR:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url
```

For a verified `change/*` invocation, require the PR created by successful `gt submit` to exist,
match the current head branch and resolved repository, and target the resolved base. Its body must
contain no `Spec:`, `Linear-Project:`, or `Linear-Issue:` trailer, and no Linear adapter transition
or read-back occurs.

For any invocation other than verified `change/*`, if no PR exists after submit/push, create one
targeting the resolved base branch (`<wi>` = the installed `woostack-init` scripts dir, as in step
2):

```bash
base="$(bash <wi>/resolve-base.sh)"
gh pr create --base "$base" --head "$(git branch --show-current)" --title "<concise title>" --body-file <tmp-body-file>
```

For a **stacked** increment PR the base is the **parent branch**, not `$base` (see the
[worktree contract](../woostack-init/references/worktrees.md) §4); Graphite sets it automatically
via `gt submit` when the branch was `gt track --parent`ed.

For Linear, a PR must already exist after successful Graphite submission. Follow
[Identify and verify the PR](references/linear-attribution.md#identify-and-verify-the-pr), then
[Record and read back attribution](references/linear-attribution.md#record-and-read-back-attribution)
in that order. Do not repeat the step-4.5 preflight or step-6 submission.

For Markdown-backed and verified `change/*` invocations only, unless `--no-pr-update` applies, perform all three steps:

1. Load [`references/pr-body.md`](references/pr-body.md) for the title/body template and formatting rules.
2. Apply the validated fields with its documented `gh pr edit` command.
3. Re-fetch them with `gh pr view`; only the observed intended read-back is success.

### 8. Report

Return:

- Branch name.
- Commit subject/SHA if available.
- PR URL.
- Selected artifact backend and whether the verified `change/*` artifact-neutral override applied; for non-change Linear, the verified project UUID and issue identifier.
- Goal used.
- Summary bullets used.
- Test plan bullets used (Automated and Manual).

Do not claim tests passed unless you ran them and saw passing output.
