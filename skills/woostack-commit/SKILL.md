---
name: woostack-commit
description: Commit the current session-relevant changes for one exact Linear issue, create or verify its Graphite branch, record finalized implementation evidence, submit, and update the current PR title/body with a goal, concise summary, structured test plan, and exact Linear attribution. Use for /woostack-commit, "commit this", "commit the current changes", "update the PR", or when finishing a woostack change before review.
---

# woostack-commit

Commit only the changes relevant to the current session, then update the pull request and its exact
Linear owner so reviewers see the latest intent, evidence, summary, and test plan.

This skill mutates Git state, GitHub PR metadata, and one caller-supplied Linear issue. It never
merges, force-pushes, discovers work from recent activity, or creates a development record.

## Commands

```text
/woostack-commit --issue <Linear issue UUID|exact URL> [--project <Linear project UUID|exact URL>] [<message>]
/woostack-commit --issue <Linear issue UUID|exact URL> [--project <Linear project UUID|exact URL>] --no-pr-update [<message>]
```

`--issue` is always required. `--project` is required only when the verified issue has role
`increment`; it is forbidden when the verified issue has role `work-item`. A driving skill may
supply the same exact identities in its structured handoff instead of spelling flags, but an issue
identifier such as `TEAM-123`, a title, branch name, or recent issue is never sufficient identity.

Use `<message>` as the commit subject only when it accurately describes the staged change.
`--no-pr-update` skips only the GitHub field edit; it does not skip Linear verification, finalized
implementation evidence, Graphite submission, exact existing trailers, PR/relation read-back, or
the verified transition to `inReview`.

## Optional config

Consumers may add a commit hook command under `.woostack/config.json`:

```json
{
  "commit": {
    "pre_commit": "pnpm format && pnpm test"
  }
}
```

`commit.pre_commit` is a shell command eligible to run from the repo root after branch resolution
and before staging only when resume admission proves the finalized commit absent. Use it for
formatters, linters, test runners, or a repo-local script such as `./scripts/pre-commit.sh`.

Rules:

- Treat a missing `.woostack/config.json` or missing `commit.pre_commit` as no-op.
- When the finalized commit is proven absent, run the command exactly once before the one staging
  and commit path. When the exact finalized commit already exists, do not read or execute the hook;
  stages 3–5 perform zero hook, PASS-helper, staging, or `gt modify` operations.
- If it exits non-zero, stop immediately. Do not stage, commit, push, update PR fields, append a
  Linear comment, write a Linear relation, or change Linear state.
- If it modifies files, include those changes only when they are relevant to the session change;
  otherwise stop. A caller-supplied `change/*` PASS receipt follows the stricter freshness loop in
  step 3.
- Report the command and observed result in the PR test plan.

## Fast-subagent drafting

Use a fast-tier subagent to draft commit and PR text when the host supports subagents with either
explicit model routing or host-owned role routing. This is a cost optimization for the mechanical
writing portion only; the main agent remains responsible for Linear identity and ownership,
Git/Graphite/GitHub operations, staging, relevance, and final verification.

Rules:

- Delegate only text drafting: the commit subject/body candidate and, for PR prose, the title,
  Goal line, Summary bullets, and Test plan bullets (Automated and Manual). Attribution is not a
  drafting field.
- Pass a bounded prompt containing the resume-admission-selected diff: the staged diff only on the
  commit-absent path, or the verified committed base-to-head diff for an exact finalized commit.
  Also pass that diff's identity, its changed-file list, commands and retained observations,
  relevant user intent, and accurate existing PR context.
- Route the subagent at the `fast` tier. On a host with explicit per-call model routing, resolve
  the tier through the shared [Model Tiers table](../using-woostack/references/model-tiers.md) and
  pass what it resolves to on the spawn. On a host with host-owned role routing, select the fixed
  role-backed built-in worker from its host file without reading repository model settings; this
  is non-degraded. **Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).
- The subagent returns only proposed text. It must not run commands, stage files, commit, push,
  mutate Linear, edit PRs, or decide whether dirty files are relevant.
- Before using any draft, require its recorded input identity to equal the current
  resume-admission-selected diff and compare its claims with retained command observations.
  Rewrite or discard anything stale, identity-less, overstated, vague, or unsupported. A lost
  in-memory draft is reconstructed; never infer or reuse it.
- The controller owns attribution. Discard any draft that introduces, copies, or normalizes a
  `Spec:`, `Linear-Project:`, or `Linear-Issue:` line; compose the body again from only the
  validated title, Goal, Summary, and Test plan fields, then append the exact controller-owned
  Linear suffix.

## Hard constraints

- Official host-exposed Linear MCP is the only development-record interface. There is no backend
  selection or resolver, local spec/fix/plan attribution, Linear document, provider adapter,
  direct Linear HTTP/GraphQL call, or alternate-authority fallback. GitHub GraphQL is permitted
  only for GitHub operations.
- Load the canonical [Linear MCP development authority](../woostack-init/references/artifact-backends.md)
  before any Linear read. Discover official MCP operations by capability, not by hard-coded tool
  name.
- Every invocation owns exactly one caller-supplied managed issue. A role-`increment` issue also
  owns exactly one caller-supplied role-`feature` project; a role-`work-item` issue has no project.
  Never infer or manufacture either identity.
- Every Linear mutation addresses the already verified stable resource UUID. Every managed comment
  has a preallocated stable event UUID and typed metadata. Preserve those UUIDs across an unknown
  outcome, and independently read the affected resource, event, relation, or state after every
  mutation before the next side effect.
- Before any side effect, classify the exact local commit, `implementationEvidence` event,
  Graphite/GitHub PR, Linear PR relation, and issue state from fresh complete reads. Skip every
  exact verified boundary and resume at the first proven-missing boundary. Partial, ambiguous,
  non-monotonic, or unknown state blocks; never rerun a finalized commit or allocate a duplicate
  event UUID.
- Stage only session-relevant changes. Never stage unrelated work, generated sidecars, secrets,
  or `.env*`.
- Never force-push. Do not merge.
- Preserve failure state. A hook, commit, Graphite submission, GitHub edit, Linear mutation, or
  read-back failure stops at that boundary; never infer success from a mutation response, retry
  blindly, discard a stable UUID, or continue after partial/unknown evidence.
- Report only commands, identities, and results actually observed.

## Workflow

### 0. Bind the caller-supplied Linear work

Require the exact issue UUID or exact Linear URL and the invoking engineer/run identity. Accept an
exact project UUID or exact Linear URL only as a candidate for role-`increment` work. Load the
canonical authority linked above, discover the official MCP capabilities needed to read issues,
projects, owners, comments, relations, and state, and require independently readable results with
complete pagination.

Load [`references/linear-attribution.md`](references/linear-attribution.md) and perform the identity,
ownership, repository, role, relation, and initial ancestry preflight under
[Verify the caller-owned issue, project, and ancestry](references/linear-attribution.md#verify-the-caller-owned-issue-project-and-ancestry).
Retain the verified native IDs, stable client UUIDs, issue identifier, resource role, canonical
repository URL, workspace/team, current semantic state, resolved owner type/principal, expected
base or Git parent, and exact required relations for the whole invocation.

This read must establish exactly one of two shapes:

- role `work-item`: one exact managed issue, no project argument, no native project membership,
  and an issue-only PR suffix;
- role `increment`: one exact managed issue, one exact managed role-`feature` project, matching
  native project membership and dependency/Git-parent relations, and a project-plus-issue suffix.

Missing official MCP capability, a missing or extra identity, an unsupported or wrong `kind`/`role`,
foreign repository/workspace/team, owner drift, malformed managed metadata, stale or partial
pagination, ambiguous reads, or a relation mismatch blocks before branch creation, drafting,
hooks, staging, commit, comment, relation, or state mutation. Never guess from a title, issue
identifier, branch, PR text, or recent activity.

Before continuing, follow
[Classify resume state before side effects](references/linear-attribution.md#classify-resume-state-before-side-effects).
Fresh complete Git, Graphite, GitHub, and official-MCP reads must classify the local finalized
commit, exact `implementationEvidence` event, canonical PR, issue PR relation, and native issue
state as exact or absent. Skip exact verified mutations and resume at the first missing boundary:
commit, implementation evidence, submission/PR, PR field update, relation, or `inReview` state.
If all boundaries are exact, perform no mutation and report the verified result. Any downstream
evidence without its prerequisite, duplicate candidate, mismatch, partial page, or unknown read
blocks. An existing finalized commit means stages 3–5 are read-only/skipped; never rerun
`gt modify` or allocate a second implementation event.

### 1. Inspect state

Run read-only inspection:

```bash
pwd
gt status 2>/dev/null || git status --short --branch
gh repo view --json nameWithOwner,url
gh pr view --json number,title,body,headRefName,baseRefName,url,headRefOid 2>/dev/null || true
```

Identify the current branch, exact repository, open current-branch PR if any, changed files, and
which changes are relevant to the current user/session. Compare the GitHub repository with the
verified canonical repository URL. If relevance is ambiguous or the repositories disagree, stop
before staging or mutation.

### 2. Enforce issue-owned branch shape before committing

Resolve the integration branch using the installed `woostack-init` scripts directory (`<wi>`):

```bash
base="$(bash <wi>/resolve-base.sh)"
branch="$(git branch --show-current)"
```

Follow the canonical [worktree and base-branch contract](../woostack-init/references/worktrees.md).
The verified Linear relations, not ordinal adjacency or a branch name, determine the expected base:

- A standalone role-`work-item` branch targets the resolved integration base recorded by its caller
  receipt and must have no project relation.
- A dependency-root role-`increment` branch starts at the feature project's frozen root commit and
  tracks the frozen base branch as its Graphite parent.
- A dependent role-`increment` branch starts at its declared parent issue branch and tracks that
  same branch. Every additional dependency must already be merged or Git-reachable from it.

Never commit directly to `$base`, `main`, `staging`, `beta`, or `alpha`. A fresh branch may be
created only when the verified issue has empty branch/PR evidence and the caller's exact expected
branch, base ref, and role-compatible worktree relation are already established. Prefer:

```bash
git switch "$base"
gt create <verified-role-compatible-branch>
gt track <verified-role-compatible-branch> --parent <verified-parent-branch>
```

Otherwise require the existing issue-owned branch/worktree. For `change/*`, verify the canonical
worktree path and Graphite registration:

```bash
export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
actual_root="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
expected_root="$(cd "$WOOSTACK_ROOT/.woostack/worktrees/${branch//\//-}" && pwd -P)"
test "$actual_root" = "$expected_root"
gt branch info --branch "$branch" --quiet
```

Every check must succeed. For branch creation, tracking, or commit command mechanics, read
[`references/graphite.md`](references/graphite.md); its non-Linear fallback paths do not apply.
Raw Git cannot substitute for the required Graphite identity. Never force-push.

### 3. Run the configured pre-commit command

Enter this step only when resume admission proves the finalized commit absent. Then read
`.woostack/config.json` for `commit.pre_commit`:

```bash
jq -r '.commit.pre_commit // empty' .woostack/config.json
```

Immediately re-read and verify the exact issue role, repository, relations, semantic state, and
type-aware owner before executing a non-empty hook. If the read is incomplete or differs from the
retained context, stop. Execute the hook exactly once with the user's shell. If it fails, stop; if
it changes files, reassess relevance before staging.

A `change/*` caller must also supply its current `woostack-change` PASS identity. Only on this
commit-absent path, both skills use the shipped identity helper; never invent a second hash or path
encoding:

```bash
receipt_identity="$(bash <commit-skill-dir>/scripts/change-receipt.sh "$base_ref")"
```

The helper's compact JSON is the byte-for-byte complete-state identity. Compare a fresh value with
the supplied PASS identity before the hook (or before staging when there is no hook). When a hook
runs, compare fresh pre-hook and post-hook values. Any branch, base, HEAD, tracked-content, staged,
unstaged, or untracked mismatch returns to `woostack-change` for verification, smoke testing, and a
fresh complete-diff review. Only a fresh `/woostack-commit` invocation with the new matching PASS
receipt may resume; never stage or commit under a stale receipt.

When resume admission finds the exact finalized commit, skip this entire step without reading the
hook or invoking `change-receipt.sh`; retain the verified commit and resume at the first missing
evidence, submission, PR, relation, or state boundary.

### 4. Stage only session-relevant changes

Enter the staging path only when the finalized commit is proven absent. If the exact finalized
commit already exists, run no `git add` or `git add -p`; this stage is read-only/skipped.

Use targeted staging:

```bash
git add <file1> <file2>
```

When a file contains unrelated hunks, use interactive patch staging:

```bash
git add -p <file>
```

Tracked `.woostack/memory/` notes and `MEMORY.md` may be staged when relevant under the
[memory contract](../woostack-init/references/memory.md). Do not stage local sidecars, generated
files, secrets, `.env*`, unrelated dirty files, or user work from outside this session.

### 4.5 Verify Linear identity and proposed attribution

On the commit-absent path, after staging, perform a fresh complete pre-commit read through the
official MCP. On a resume with an exact finalized commit, stage nothing and perform only the fresh
read-only identity/owner/ancestry admission needed for the later boundary. Follow
[Verify the caller-owned issue, project, and ancestry](references/linear-attribution.md#verify-the-caller-owned-issue-project-and-ancestry),
then stop at the next heading. Recompute and verify the current branch/base ancestry and Graphite
parent against the retained role and native relations. Require the issue to remain in the
execution lifecycle with the same type-aware owner and current assignment/evidence relations.

When PR fields may be drafted or updated, load [`references/pr-body.md`](references/pr-body.md) and
select input from resume admission. On the commit-absent path, compose and validate from the staged
diff. When the exact finalized commit exists, reconstruct the title/body solely from its verified
committed base-to-head diff; ignore current staged, unstaged, and untracked state and any lost or
identity-mismatched in-memory draft. Include prior hook output only from a verified retained
observation; otherwise report it as unavailable and not rerun, without inference. Append the exact
role-derived Linear suffix and validate the complete body against that selected diff before the
next mutation. Inspect any existing current-branch PR
as well: its repository/head/base must match, and its body must either contain the exact expected
suffix or contain no attribution lines at all when updates are enabled. Any `Spec:` mention,
including Markdown-wrapped text, or wrapped, missing, duplicate, reordered, partial, foreign, or
mismatched Linear attribution blocks; an unattributed body is never accepted with
`--no-pr-update`.

Do not commit, submit, edit the PR, append `implementationEvidence`, write a branch/PR relation, or
change issue state unless every read and proposed-body check is complete and exact.

### 5. Commit

If resume admission proves the finalized commit absent, validate any drafted subject against the
staged diff, then create it locally:

```bash
gt modify -m "<type>: <concise subject>"
commit_sha="$(git rev-parse HEAD)"
```

Use a concise conventional subject, usually `feat:`, `fix:`, `docs:`, or `chore:`. Mention the real
change, not the process. Add a body only when the reason is not obvious from the diff. Require the
observed commit to contain exactly the intended staged changes and remain unpushed. If admission
already found the exact finalized commit for the reviewed base/head identity, retain its SHA and
skip the mutation; never run `gt modify` again. A missing-but-partial or mismatched local commit
blocks rather than recommitting. A commit failure stops with no Linear comment or state mutation.

### 5.5 Record finalized implementation evidence

After the finalized commit exists and before any push or PR submission, follow
[Record and read back implementation evidence](references/linear-attribution.md#record-and-read-back-implementation-evidence).
Re-read the issue identity, role, repository, relations, ancestry, current state, and type-aware
owner. Record only the commit-scoped base SHA, head SHA, and hash of the byte-safe committed
base-to-head diff in the typed `implementationEvidence` issue event. Staged, unstaged, and
untracked paths or hashes remain local PASS-freshness data and must not enter the remote event.

If resume admission proves the exact event absent, preallocate one stable event UUID, append once,
and independently read that exact comment and all related records back. If the exact event already
exists for the same commit evidence, reuse its stable UUID and skip both allocation and append. A
missing, partial, stale, duplicate, foreign, mismatched, or unknown event read-back stops before
push or submission. Never write evidence for a provisional commit, replace an event UUID after a
timeout, or infer success from the mutation response.

### 6. Push or submit

Immediately re-read the type-aware owner and retained issue/project relations. Then follow
[Submit with Graphite](references/linear-attribution.md#submit-with-graphite).

Run `gt submit` only when resume admission proves the canonical PR and Graphite submission absent.
After a failed, timed-out, or otherwise unknown prior `gt submit`, read Graphite and canonical
GitHub state first. Skip submission when the exact branch/commit/PR is verified; resubmit only when
complete reads prove the remote branch, Graphite submission, and PR all absent. Partial,
ambiguous, foreign, or conflicting remote state blocks without another submit.

This is the only push/submission path; do not use raw Git, `gh pr create`, or an alternate
transport. If the host separates push and PR submission into distinct Graphite operations, repeat
the owner/identity read immediately before each one. Do not merge or force-push.

### 7. Resolve and attribute the PR

Resolve or resume the current PR through GitHub authority:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url,headRefOid
```

A successful push is not a PR receipt. If complete Graphite/GitHub reads prove no submission or PR,
return to stage 6; if they are partial or conflicting, block. Never use `gh pr create`. Follow
[Identify, update, and verify the canonical PR](references/linear-attribution.md#identify-update-and-verify-the-canonical-pr).
Require the canonical repository, exact submitted head and commit, verified role-derived base and
ancestry, and exact trailer suffix.

When updates are enabled and the canonical PR is present but not yet the exact validated
title/body, apply the fields once with the `gh pr edit` command in `references/pr-body.md`, then
re-fetch and compare the exact intended result. If the fields already read back exactly, skip the
edit. With `--no-pr-update`, require the existing body already be exact.

Only after canonical PR read-back succeeds, follow
[Record and read back PR relation and state](references/linear-attribution.md#record-and-read-back-pr-relation-and-state).
Perform a fresh official-MCP identity/owner/relation read. Write the exact branch and canonical PR
relation only when admission proves it absent, then independently read it back; skip the write when
the exact relation is already verified. Only that receipt permits the native issue transition
from `executing` to `inReview`. Skip the transition when the exact `inReview` state and all
prerequisite evidence already read back; otherwise transition once and independently re-read the
state, issue, owner, event, and relation. Commit does not transition a feature project or mark any
resource `done`.

At every boundary, a missing prerequisite, partial, stale, foreign, ambiguous, conflicting, or
unknown read-back stops before the next mutation. Preserve the branch, worktree, commit, stable
resource/event UUIDs, and observed receipts for explicit reconciliation; never retry blindly,
duplicate an exact mutation, or repair only one side.

### 8. Report

Return:

- Verified Linear issue UUID/URL, identifier, role, native ID, state, and type-aware owner.
- Verified project UUID/URL and native ID for role-`increment`, or explicit no-project proof for
  role-`work-item`.
- Branch name, verified base/parent ancestry, finalized commit subject/SHA, and the commit-scoped
  base SHA, head SHA, and committed-diff hash recorded remotely.
- Read-back receipt and stable UUID for the typed `implementationEvidence` event.
- Canonical PR URL and exact observed trailer suffix.
- Read-back receipts for the branch/PR relation and `inReview` state.
- Goal, Summary bullets, and Test plan bullets used (Automated and Manual).
- Any preserved blocker/unknown-outcome identities and the exact safe resume boundary.

Do not claim tests passed unless you ran them and observed passing output. Never report a Linear
mutation, PR field, relation, or state that was not independently read back.
