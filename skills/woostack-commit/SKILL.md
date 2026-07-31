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

`commit.pre_commit` is a shell command eligible to run from the repo root after branch-path
admission and before staging only when resume admission proves the finalized commit absent. Use it
for formatters, linters, test runners, or a repo-local script such as `./scripts/pre-commit.sh`.

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
  is non-degraded. **Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, or draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded). Draft inline when degraded.
- The subagent returns only proposed text. It must not run commands, stage files, commit, push,
  mutate Linear, edit PRs, or decide whether dirty files are relevant.
- Before using any draft, require its recorded input identity to equal the current
  resume-admission-selected diff and compare its claims with retained command observations.
  Rewrite or discard anything stale, identity-less, overstated, vague, or unsupported. A lost
  in-memory draft is reconstructed; never infer or reuse it.
- The controller owns the official Linear suffix. Discard any draft that introduces, copies, or
  normalizes attribution; compose the body again from only the validated title, Goal, Summary, and
  Test plan fields, then append the exact controller-owned suffix.

## Hard constraints

- Official host-exposed Linear MCP is the only development-record interface. Git and GitHub remain
  authoritative for repository, commit, branch, pull-request, review, and merge evidence. GitHub
  GraphQL is permitted only for GitHub operations.
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
- A Linear execution caller must supply independently read current passing `verification` and
  canonical `precommitReview` receipts for the exact precommit diff. `reviewResult` is post-PR full
  review evidence and is never a commit input or an `implementationEvidence` relation.
- Before any side effect, classify the exact local commit, `implementationEvidence` history,
  Graphite/remote state, complete all-state canonical GitHub PR candidate set, stable native Linear
  PR relation, and issue state from fresh complete reads. Admit a first submission only from proven
  absence. Admit an ordinary-later or consumed-restack revision only from the exact sole canonical
  PR at historical head A and the same stable relation, then update that retained PR to finalized
  head B without replacing the relation. Skip verified boundaries and resume at the first pending
  one. Partial, ambiguous, non-monotonic, stale-C, foreign, replacement, duplicate, or unknown state
  blocks; never rerun a finalized commit, allocate a duplicate event UUID, infer a branch, create a
  second PR, or replace a relation.
- Branch admission reuses the caller-created issue branch/worktree or creates from its verified Graphite parent only after proving all exact-issue artifacts absent.
  Any existing branch, claim, worktree, commit, submission, remote, PR, or relation forbids fresh
  creation; never derive identity from branch display text or create/reparent a workflow branch.
- Stage only session-relevant changes; never stage unrelated work, generated sidecars, secrets, or `.env*`.
- Never force-push. Do not merge.
- Preserve failure state: any hook, commit, submission, GitHub/Linear mutation, or read-back failure stops there; never infer success, retry blindly, discard a UUID, or continue.
- Report only commands, identities, and results actually observed.

## Workflow

### 0. Bind the caller-supplied Linear work

Require the exact issue UUID or exact Linear URL, invoking controller principal, engineer/run
identity, and current passing `verification` and `precommitReview` receipts. Accept an exact project
UUID or exact Linear URL only as a candidate for role-`increment` work. Load the canonical authority
linked above, discover the official MCP capabilities needed to read issues, projects, owners,
comments, relations, and state, and require independently readable results with complete
pagination.

Load [`references/linear-attribution.md`](references/linear-attribution.md) and perform the identity,
ownership, repository, role, relation, and initial ancestry preflight under
[Verify the caller-owned issue, project, and ancestry](references/linear-attribution.md#verify-the-caller-owned-issue-project-and-ancestry).
Retain the verified native IDs, stable client UUIDs, issue identifier, resource role, canonical
repository URL, workspace/team, current semantic state, resolved owner type/principal, exact
authenticated controller, expected base or Git parent, current assignment/verification/
`precommitReview`, and exact required relations for the whole invocation.

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
Fresh complete Git, Graphite, all-state GitHub, and official-MCP reads must select one
evidence-derived submission shape. Initial revision 1 requires proven absence of submission,
remote branch, every canonical PR candidate, and Linear relation before its first submit. An
ordinary-later or consumed-restack revision B requires the exact prior implementation
revision/head A, sole retained PR number/repository/explicit branch/base, and same stable native
Linear relation before any B update. Never infer the shape from a branch or PR.

Skip exact verified mutations and resume at the first pending boundary: commit, implementation
evidence, initial PR creation or same-PR update, initial relation creation, or `inReview`
confirmation. Existing updates never mutate their stable relation. If all boundaries are exact at
B, perform no mutation and report the verified result. Any downstream evidence without its
prerequisite, duplicate candidate, changed identity, mismatch, partial page, or unknown read
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

If an existing PR is present, scan its raw body before drafting, hooks, staging, branch creation,
commit, PR edit, or Linear mutation. Follow the legacy-`Spec:` rejection rule in
[`references/pr-body.md`](references/pr-body.md): any case-insensitive exact, indented, quoted, or
fenced `Spec:` candidate blocks. Never delete, rewrite, or normalize it into Linear attribution.

### 2. Enforce issue-owned branch shape before committing

Resolve the primary root, integration branch, and exact native issue ID using the installed
`woostack-init` scripts directory (`<wi>`):

```bash
export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
base="$(bash <wi>/resolve-base.sh)"
current_root="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
current_branch="$(git branch --show-current)"
issue_id="<verified-native-linear-issue-id>"
wt="$WOOSTACK_ROOT/.woostack/worktrees/issues/$issue_id"
```

Follow the canonical [worktree and base-branch contract](../woostack-init/references/worktrees.md).
Verified Linear relations, not ordinal adjacency or a branch name, determine `start_sha` and
`graphite_parent`:

- A standalone role-`work-item` starts at the retained integration-base commit and uses the
  integration branch as Graphite parent, with no project relation.
- A dependency-root role-`increment` starts at the frozen project root and uses its frozen base.
- A dependent role-`increment` starts at its declared parent issue head and uses that branch as
  Graphite parent. Every additional dependency must already be merged or Git-reachable from it.

Fresh complete official-MCP, registry, Git worktree, Git, Graphite, remote, and canonical-PR reads
must admit exactly one branch path:

- **Existing caller-created branch reuse.** The exact-ID claim, `$wt`, checked-out branch, start
  commit, Graphite parent, repository, issue/project IDs, owner/run, and assignment all match.
  Require `current_root="$wt"` and `gt branch info --branch "$current_branch" --quiet`. Reuse it;
  never run `gt create`, attach another worktree, or reparent it. This is the only path accepted
  from `woostack-change`, `woostack-execute`, or another workflow that owns the branch.
- **Direct fresh creation.** The user invoked `/woostack-commit --issue …` without a branch
  handoff; root, current parent, `HEAD`, and the complete dirty-state receipt exactly match, with no
  unrelated path. Derive only display name `change/<lowercase-verified-issue-identifier>` for
  `work-item` or `feature/<lowercase-verified-issue-identifier>` for `increment`; never use a title.
  The claim, `$wt`, and every local branch/checkout or Graphite/remote identity under that exact
  name, plus commit, PR, and Linear PR relation, are absent. Native issue ID in the claim and `$wt`
  remains the binding. Retain pending creation until the hook, staging,
  fresh authority/diff check, and proposed-body gate pass.

Any mixed, partial, duplicate, foreign, stale, colliding, or unknown shape blocks. Existing
branch/worktree evidence disqualifies direct creation rather than being adopted or recreated.
Never run `gt modify` or raw Git commit on the parent/protected base. Read the exact commands in
[`references/graphite.md`](references/graphite.md); never substitute transport or force-push.

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
unstaged, or untracked mismatch invalidates the existing verification and reviewed-precommit-diff
identity and returns to the caller for verification, smoke testing, and a fresh task-scoped
spec/quality review. Only a fresh `/woostack-commit` invocation with new matching `verification`
and `precommitReview` PASS receipts may resume; never stage or commit under a stale receipt.

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
parent against the retained role and native relations. Require the issue to remain in the execution
lifecycle with the same type-aware owner and current assignment, passing `verification`, and
passing `precommitReview`. Its sorted changed paths and reviewed byte-safe precommit diff hash must
equal the exact diff being committed. A post-PR `reviewResult` is neither expected nor admissible as
a substitute.

When PR fields may be drafted or updated, load [`references/pr-body.md`](references/pr-body.md) and
select input from resume admission. Before rebuilding, copying, or editing an existing PR body,
scan its raw lines and reject every case-insensitive exact, indented, quoted, or fenced `Spec:`
candidate. This legacy attribution is a blocker even when the body also has the expected Linear
suffix or updates are enabled; never remove or normalize it. On the commit-absent path, compose and
validate from the staged diff. When the exact finalized commit exists, reconstruct the title/body
solely from its verified committed base-to-head diff; ignore current staged, unstaged, and
untracked state and any lost or identity-mismatched in-memory draft. Include prior hook output only
from a verified retained observation; otherwise report it as unavailable and not rerun, without
inference. Append the exact role-derived Linear suffix and validate the complete body against that
selected diff before the next mutation. Inspect any existing current-branch PR as well: its
repository/head/base must match, it must contain no legacy `Spec:` candidate, and its body must
either contain the exact expected suffix or contain neither official Linear attribution label when
updates are enabled. Wrapped, missing, duplicate, reordered, partial, foreign, or mismatched Linear
attribution blocks; an unattributed body is never accepted with `--no-pr-update`.

Do not create a branch or commit, submit, edit the PR, append `implementationEvidence`, write a
branch/PR relation, or change issue state unless every read and proposed-body check is complete and
exact.

### 5. Commit

If resume admission proves the finalized commit absent, validate the drafted subject against the
staged diff, then use exactly the branch action admitted in step 2.

For an existing caller-created branch, create the commit on that verified current Graphite branch:

```bash
gt modify -m "<type>: <concise subject>"
commit_sha="$(git rev-parse HEAD)"
```

For direct fresh creation only, repeat the exact issue, owner, assignment, repository, parent/start,
complete-diff, and artifact-absence checks. Atomically reserve the canonical exact-ID claim for
`$wt`, then create and commit the already staged diff without implicit staging:

```bash
gt create "$branch" --no-interactive -m "<type>: <concise subject>"
commit_sha="$(git rev-parse HEAD)"
```

Require the observed branch, commit, staged contents, and Graphite parent to be exact. `gt create`
already tracks the verified current parent; never `gt track` or reparent it. Then return the primary
checkout to the parent and attach, rather than recreate, the branch at the reserved issue path:

```bash
git switch "$graphite_parent"
git worktree add "$wt" "$branch"
```

Immediately verify the registry claim, absolute worktree path, branch, HEAD, Graphite parent,
repository, exact issue/project IDs, and current owner/assignment, then perform every later step
with `cwd="$wt"`. A failed, timed-out, or unknown create/switch/attach result preserves the claim,
branch, commit, and worktree observations and stops for explicit reconciliation; never retry
`gt create` or make a duplicate worktree.

Use a concise conventional subject, usually `feat:`, `fix:`, `docs:`, or `chore:`. Mention the real
change, not the process. Add a body only when the reason is not obvious from the diff. Require the
observed commit to contain exactly the intended staged changes and remain unpushed. If admission
already found the exact finalized commit for the reviewed base/head identity, retain its SHA and
skip the mutation; never run `gt modify` or `gt create` again. A missing-but-partial or mismatched
local commit blocks rather than recommitting. A commit failure stops with no Linear comment or
state mutation.

### 5.5 Record finalized implementation evidence

After the finalized commit exists and before any push or PR submission, follow
[Record and read back implementation evidence](references/linear-attribution.md#record-and-read-back-implementation-evidence).
Re-read the issue identity, role, repository, relations, ancestry, current state, type-aware owner,
current assignment/verification/`precommitReview`, and authenticated controller. For a first or
ordinary later revision, the native author and authenticated controller must exactly equal the
current type-aware owner and assignment. An authorized sweep rewrite instead requires the exact
controller named by the still-valid `restackAuthorized` while owner and assignment remain
unchanged. Record only the commit-scoped base SHA, head SHA, and hash of the byte-safe committed
base-to-head diff in the typed `implementationEvidence` issue event. Staged, unstaged, and
untracked paths or hashes remain local PASS-freshness data and must not enter the remote event.

If resume admission proves the exact event absent, preallocate one stable event UUID, append once,
and independently read that exact comment and all related records back. If the exact event already
exists for the same commit evidence, canonical assignment/verification/`precommitReview`/project
relations, and conditional restack authorization, reuse its stable UUID and skip both allocation
and append. A missing, partial, stale, duplicate, foreign, mismatched, or unknown event read-back
stops before push or submission. Never write evidence for a provisional commit, replace an event
UUID after a timeout, or infer success from the mutation response.

For every later B revision, the read-back must also preserve and resolve the exact superseded
implementation/head A by its authoritative timestamp plus the retained sole PR and native Linear
relation that were exact at A. The event append does not move either provider record. Missing A,
unexpected head C, or changed PR/relation identity stops before submission.

### 6. Push or submit

Immediately re-read the type-aware owner, retained issue/project relations, exact
implementation A/B history, explicit issue branch, Graphite/remote state, complete canonical PR
candidate set, and Linear PR relation. Then follow
[Submit with Graphite](references/linear-attribution.md#submit-with-graphite).

For initial revision 1, run the first `gt submit` only when complete reads prove the Graphite
submission, remote branch, every all-state canonical PR candidate, and Linear PR relation all
absent. Any pre-existing candidate blocks fresh creation. For an ordinary-later or
consumed-restack revision B, run the Graphite submission only after independently re-proving the
sole retained PR number/URL, repository, explicit head branch, base, historical head A, and the
same stable native Linear relation. Submit/push B to that already verified branch and update that
same PR; do not create, retarget, replace, or infer anything.

Before updating any role-`increment` branch, enumerate the complete native dependency descendant
set and every descendant branch/PR. No descendants permits the single-branch path. Any live
descendant requires the caller-authorized coordinated restack path: every affected descendant
owner must have a current unexpired unconsumed `restackAuthorized` naming this exact controller,
operation, branch/head, claim/path, and affected relations, and the pinned project lead must have
authorized the exact cross-issue operation. Missing, partial, conflicting, or unauthorized
descendant evidence blocks before changing the parent ref or submitting.

After a failed, timed-out, or otherwise unknown Graphite result, independently read Graphite,
remote branch state, and the complete GitHub PR set before deciding anything. The retained same PR
exactly at B skips another submit. On initial creation, complete absence of every remote surface
permits one retry. On an existing update, every Graphite/remote/PR surface still exactly at A
permits one retry against that same retained PR. Mixed A/B state, unexpected C, duplicate,
replacement, foreign, partial, ambiguous, or unknown state blocks without another submit.

This is the only push/submission path; do not use raw Git, `gh pr create`, or an alternate
transport. A caller-authorized coordinated restack may use only its bounded Graphite stack
submission for these same retained per-PR identities. If the host separates push and PR submission
into distinct Graphite operations, repeat the owner/identity/A/B read immediately before each one.
Do not merge or force-push.

### 7. Resolve and attribute the PR

Resolve or resume the canonical PR through GitHub authority. Initial creation resolves the sole
candidate from the retained explicit branch and finalized head B. An existing update fetches the
retained PR number directly and also lists the complete candidate set:

```bash
gh pr view <retained-number> --json number,title,body,headRefName,baseRefName,url,headRefOid
```

A successful push is not a PR receipt. Require exactly one PR with the retained canonical
repository, number/URL, explicit head branch, verified base, and finalized head B. Existing updates
must preserve the exact number/repository/branch/base proven at A; never infer the PR from a branch
name or accept a duplicate/replacement. A same-identity PR still at A means submission remains
pending; unexpected head C, a stale/foreign relation, or any partial/conflicting read blocks.
Follow
[Identify, update, and verify the canonical PR](references/linear-attribution.md#identify-update-and-verify-the-canonical-pr)
and require exact role-derived ancestry and trailer suffix as well.

When updates are enabled and the verified retained PR is present at B but not yet the exact
validated title/body, apply the fields once with the `gh pr edit` command in
`references/pr-body.md`, then independently re-fetch that number and re-list candidates. If the
fields already read back exactly, skip the edit. With `--no-pr-update`, require the existing body
already be exact. A mutation response alone never crosses this boundary.

Only after canonical PR read-back at B succeeds, follow
[Record and read back PR relation and state](references/linear-attribution.md#record-and-read-back-pr-relation-and-state).
Perform a fresh complete official-MCP identity/owner/relation read. Initial creation writes the one
stable relation only from proven absence. An existing update requires the exact retained native
relation and performs no relation mutation: its issue, repository, PR number/URL, branch, native
relation ID, and timestamps stay stable while GitHub supplies current head B.

Independently read both the exact native relation ID and the complete relation collection after an
initial create response, including an error, timeout, or unknown outcome. Exactly one stable
matching relation plus the independently verified canonical PR at B permits state handling.
Initial creation may transition `executing` to `inReview` once and read it back. An ordinary-later
or consumed-restack update must remain `inReview` and performs neither relation nor state mutation.
Commit never transitions a feature project or marks any resource `done`.

At every boundary, a missing prerequisite, partial, stale, foreign, ambiguous, conflicting,
replacement, duplicate, or unknown read-back stops before the next mutation. Preserve the explicit
branch, worktree, A/B commits, PR number, native relation ID, stable resource/event UUIDs, and
observed receipts for explicit reconciliation; never retry blindly or repair only one side.

### 8. Report

Return:

- Verified Linear issue UUID/URL, identifier, role, native ID, state, and type-aware owner.
- Verified project UUID/URL and native ID for role-`increment`, or explicit no-project proof for
  role-`work-item`.
- Branch admission (`direct-created` or `caller-created-reused`), branch name, canonical exact-ID
  worktree path, verified base/parent ancestry, finalized commit subject/SHA, and the commit-scoped
  base SHA, head B SHA, and committed-diff hash recorded remotely.
- Read-back receipt and stable UUID for the typed `implementationEvidence` event, plus historical
  head A and superseded native revision for an ordinary-later or consumed-restack update.
- Canonical PR number/URL, exact observed trailer suffix, and proof that repository/branch/base and
  PR identity were absent for first creation or unchanged from A through B for an existing update.
- Read-back receipt and native ID for the created-or-retained stable Linear PR relation, plus
  independently verified GitHub head B and `inReview` state.
- Goal, Summary bullets, and Test plan bullets used (Automated and Manual).
- Any preserved blocker/unknown-outcome identities and the exact safe resume boundary.

Do not claim tests passed unless you ran them and observed passing output. Never report a Linear
mutation, PR field, relation, or state that was not independently read back.
