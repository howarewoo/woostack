# Linear issue worktree lifecycle and ancestry contract

This is the single authority for how woostack isolates Git-backed development writes. Official
host-exposed Linear MCP identifies and owns the work; Git, Graphite, and GitHub own source,
branches, ancestry, PRs, and merge truth. Every implementation worktree is bound to exactly one
verified Linear issue. No local specification, plan, progress, or lifecycle record may authorize a
worktree.

`woostack-execute`, `woostack-execute-overnight`, `woostack-fix`, `woostack-change`,
`woostack-bootstrap`, and `woostack-commit` link here rather than inventing a second isolation
scheme. Linear-only design, specification, planning, assignment, and gate mutations create no Git
worktree. Apart from the single greenfield primary scaffold defined below, the first tracked
implementation write occurs only after the applicable issue, contract, state, ownership, and
`assignmentAccepted` receipts are complete.

Human-readable branch naming remains caller-specific—`change/<slug>` for `woostack-change`,
`fix/<slug>` for `woostack-fix`, and the verified issue branch for execution—but branch text is
never worktree identity or recovery authority. Every such branch is bound to the issue's immutable
native Linear ID and exact registry/worktree path below.

`<wi>` below means the installed `woostack-init` scripts directory. `$WOOSTACK_ROOT` is the primary
repository root, resolved from any linked worktree with:

```bash
export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
```

## Artifact-backend boundary

Only `woostack-bootstrap` has a pre-repository exception, and it may cross that boundary exactly
once. The complete design must already have explicit approval; the normalized official
host-exposed Linear MCP/config preflight, canonical repository and initial-base intent, exact
managed role-`feature` project receipt, and stable `designApproved` receipt must each have complete
independent read-back. No target-filesystem action or Git invocation may occur before those
barriers.

The first target action is a read-only collision check with no Git invocation. It must prove that
the intended primary directory is absent or is a real, fully listed, empty, non-symlink, non-Git
directory. A populated path, existing Git metadata or repository, non-directory, symlink, unreadable
or partial result, path race, or ambiguity is a collision or unknown state and blocks before mkdir,
write, scaffold, or Git. A timeout or failed command proves neither absence nor emptiness.

Only that passing receipt permits `woostack-bootstrap` to perform the single initial scaffold in
the primary directory before a repository, base branch, issue branch, or worktree can exist. The
scaffold retains the exact verified project identity. It is not an issue worktree, does not create
or satisfy an exact-ID registry claim, and is not a reusable bypass for implementation work.

The exception is consumed as soon as Git metadata or repository state exists. From that boundary
onward, every implementation write requires the applicable verified issue receipts and the exact
issue-owned registry, branch, and worktree lifecycle in this contract; the primary checkout is
never an implementation workspace. An interrupted or partially observed scaffold does not reopen
the exception: preserve the target and remote receipts, classify the state as collision or unknown,
and stop before another write.

## 1. Verified start point

A caller supplies one complete issue-bound ancestry receipt. Never substitute the current checkout,
current branch tip, ordinal adjacency, a PR title, or a disposable registry entry.

### Standalone issue

Resolve the integration branch with `<wi>/resolve-base.sh`; never hard-code `main` or `staging`.
Before worktree creation, retain the exact branch and commit SHA from independent Git/GitHub reads
and bind both to the standalone role-`work-item` receipt. Its Graphite parent/base is that verified
integration branch and its branch starts at that exact commit. A moved base on resume is drift, not
permission to rebase silently.

### Project dependency root

A role-`increment` dependency root starts at the exact immutable commit SHA frozen by the verified
project `ready`/`executionApproved` chain. Its Graphite parent/base is the exact frozen base branch.
Do not replace the frozen SHA with that branch's newer tip.

Multiple roots may start from the same frozen SHA in parallel only when the complete verified Linear
DAG proves no dependency path between them; their exact issue IDs, owner/run identities,
responsibility surfaces, registry claims, branches/worktrees, and PRs are disjoint; and no project
or issue receipt is partial.

### Project dependency child

A dependent role-`increment` issue declares exactly one native dependency as its Git parent. Require
that parent issue's exact branch, finalized head commit, `implementationEvidence`, canonical PR,
Linear branch/PR relation, and semantic `inReview` or `done` state to agree. Start the child at that
exact parent branch/head and pass the same parent branch to `gt track --parent`.

Every other dependency is non-parent and must already be `done` with current responsible
`acceptance` plus independently verified canonical GitHub merge evidence. Prove its merged commit is
represented in the child's permitted ancestry. Merely open, `inReview`, or reachable non-parent
work is insufficient. Reject a parent inferred from issue order, a cross-project relation, newer or
rewritten parent head, unmerged non-parent dependency, missing PR relation, or partial ancestry
proof.

## 2. Disposable exact-ID registry

The registry prevents one machine from creating competing worktrees for the same issue and makes
crash recovery explicit. It is gitignored, disposable administration under the primary root:

```text
$WOOSTACK_ROOT/.woostack/worktrees/.registry/<exact-native-linear-issue-id>/claim.json
```

The directory name is the exact native Linear issue ID, not an issue identifier, title, ordinal,
slug, branch, or shortened hash. Create the per-issue directory atomically before `git worktree add`.
Its `claim.json` records only derived recovery facts:

- exact native and stable client issue IDs;
- exact native and stable client project IDs for role `increment`, or explicit `projectId: null` for
  role `work-item`;
- role and canonical repository URL;
- type-aware owner kind/principal, stable engineer name, and run ID from the verified
  `assignmentAccepted` receipt;
- branch and absolute worktree path;
- exact start commit SHA and Graphite parent/base branch; and
- creation timestamp plus the latest observed local Git boundary.

Only a claim atomically created for the verified review-reopen state in §3 additionally records
`mode: "review-reopen"`, the `restackAuthorized` stable event UUID, native comment ID and current
revision, its `operationId`, target controller principal kind/native ID, and `expiresAt`. Its
owner/run fields still name the unchanged current owner and `assignmentAccepted`; the target
controller is bounded operation metadata, never replacement ownership.

The registry is not assignment, scope, dependency, phase, approval, evidence, acceptance, branch,
or PR authority. Every use begins with fresh complete Linear/Git/Graphite/GitHub discovery and
compares the entry to those authorities. Never infer an owner or recreate missing remote evidence
from `claim.json`.

A missing entry plus complete absence of issue Git artifacts permits one fresh atomic claim after
verified assignment. One exact entry plus matching external state permits resume. A pre-existing
entry owned by a different issue, project, principal, or run; more than one claim; a path/branch
claimed elsewhere; an unexplained branch/worktree without its expected claim; or any partial match
is a collision and blocks. Do not overwrite, delete, adopt, or create around it.

On a verified handoff, preserve the entry and worktree. Only after the typed `handoff`, deliberate
assignee/delegate change, new owner read-back, and new `assignmentAccepted` all verify may the new
run replace the owner/run fields while preserving the issue, project, path, branch, and ancestry
identity. The former owner performs no later side effect.

A missing claim beside an existing issue branch or PR is not **Fresh** and cannot be adopted through
generic release/reclaim. After a §7 teardown it may return to the canonical claim/path only through
the verified review-reopen state below.

The registry is machine-local. Absence on another machine does not prove global absence: complete
local/remote Git, Graphite, GitHub, Linear relation, and typed-event reads remain mandatory before
creation.

## 3. Discovery before create, resume, or review-reopen

Fresh creation and exact resume begin only after verified issue `executing`, type-aware ownership,
`assignmentAccepted`, and ancestry. Verified review-reopen instead begins after a prior verified
§7 teardown and the `inReview`/authorization proof below. Before either kind of registry or Git
mutation, read all of:

- the exact issue resource, optional exact project and complete DAG relations, current owner/state,
  current issue events, and branch/PR relations through official MCP;
- every registry claim, local checkout, worktree, and branch relevant to the exact issue, canonical
  path, expected branch, or authorized operation;
- remote branch and Graphite tracking/submission/operation state; and
- canonical GitHub PRs, heads, bases, commits, bodies, merge state, and repository attribution.

Before counting candidates or collisions, complete MCP reads must validate and partition every
observed `restackAuthorized` record:

- **Inactive history:** only a record whose exact canonical envelope/data, stable and native
  identity, native author/time, relations, and independent read-back all validate may qualify.
  A validated authorization is inactive when it either expired unconsumed before the current
  operation or was validly consumed by the exact resulting `implementationEvidence` read-back
  within its authorization window. Exclude these inactive records from active
  authorization-candidate and competing-operation collision counts. They remain append-only
  evidence and cannot satisfy review-reopen or authorize a new checkout, edit, ref rewrite, push,
  or provider mutation.
- **Candidate invalidity:** a record selected for or naming the current operation is an active
  candidate, not inactive history. If that candidate is expired or consumed, it blocks.
- **Historical invalidity or conflict:** malformed or partially read historical evidence,
  ambiguous expiry or consumption history, duplicate/ambiguous records, or unresolved temporal
  overlap or live claim/path/branch/relation conflict with the current operation blocks as a
  collision or unknown state. Never infer inactivity from a timestamp or consumed-looking
  relation alone.

Classify the complete state:

1. **Fresh:** registry, branch, worktree, commit, submission, PR, and Linear attribution are all
   proven absent. Claim and create once.
2. **Exact resume:** one registry/worktree/branch and every observed monotonic boundary match the
   same issue/project, current owner/run or verified handoff successor, start/parent ancestry, and
   evidence. Reuse it; skip exact verified boundaries.
3. **Verified review-reopen:** complete reads reproduce the prior §7 teardown and prove the exact
   issue is still `inReview`; its current owner and `assignmentAccepted`, existing canonical branch,
   sole canonical PR, PR/branch head, current `implementationEvidence`, relations, and ancestry all
   agree; and exactly one active candidate is a current, unexpired, unconsumed, owner-authored
   `restackAuthorized` revision that
   names the authenticated controller, operation, same branch/head, canonical exact-ID claim/path,
   and affected relations. The canonical claim and worktree path are proven free, the branch is
   checked out nowhere, and complete registry/Git/Graphite/GitHub/Linear reads prove no other
   checkout, worktree, claim, active operation, candidate authorization, or collision. Only then
   atomically create that canonical claim and reattach the existing branch at §4; ownership stays
   unchanged.
4. **Collision or unknown:** any duplicate, partial page, wrong owner/controller/operation,
   expired or consumed candidate authorization, malformed or ambiguous history, branch claimed or
   checked out elsewhere, foreign path, unexpected commit/PR, missing provenance, changed
   ancestry, competing operation, unresolved overlap/conflict, or downstream evidence without its
   prerequisite. Preserve everything and stop.

A timeout or command error proves neither absence nor failure. Discover the observed result before
any later explicit retry; never allocate a duplicate worktree, branch, commit, submission, PR,
authorization, or operation.

## 4. Create and verify

Choose the caller's role-appropriate deterministic branch name, then bind that name in the exact-ID
registry. Branch display text is not identity. The worktree path is derived from the exact native
issue ID so mutable titles cannot redirect recovery:

```bash
issue_id="<exact-native-linear-issue-id>"
wt="$WOOSTACK_ROOT/.woostack/worktrees/issues/$issue_id"
git worktree add -b "$branch" "$wt" "$start_ref"
( cd "$wt" && gt track --parent "$graphite_parent" )
```

`start_ref` is the exact retained start commit or verified parent head from §1. `graphite_parent` is
the verified integration branch, frozen base branch, or declared parent issue branch. `-b` creates a
fresh branch without checking out the base branch, so independent issue runs do not compete for the
primary checkout.

For **Verified review-reopen**, first atomically create only the authorization-bound exact-ID claim,
then reattach the already verified branch without creating or resetting it:

```bash
git worktree add "$wt" "$branch"
```

Immediately assert the authorization event UUID/native comment/current revision, operation,
controller, expiry, unchanged owner/run, canonical claim/path, top-level, branch, exact pre-operation
HEAD, Graphite parent, PR, and issue/project relations. Any checkout race, moved head, competing
operation, partial read, or post-create mismatch is an unknown mutation boundary: preserve the
claim/worktree and stop. Fresh creation and exact-resume behavior are unchanged.

After fresh creation, immediately read/assert the absolute path, Git top-level, new branch,
HEAD/start commit, Graphite parent, exact-ID registry entry, issue/project IDs, and current
type-aware owner. A failed or partial post-create assertion is an unknown mutation boundary:
preserve the registry/worktree and stop.

## 5. Operate only in the issue worktree

After creation/resume, every tracked write for the issue happens with `cwd = $wt`. The primary
checkout remains a stable clean integration point. Any called skill operating on tracked source or
memory inherits that cwd.

For subagent execution, enforce both guards where available:

1. set the spawn call's cwd to `$wt`; and
2. always put the exact path in the dispatched prompt and make the worker enter it, compare
   path-normalized `pwd -P` to `git rev-parse --show-toplevel`, and abort before a write on mismatch.

A host `isolation: "worktree"` option that creates a new throwaway worktree is not a substitute; it
would bypass the exact registry claim and Graphite parent.

The controller re-reads the exact issue, project/relations when applicable, current
`assignmentAccepted`, and type-aware owner immediately before the first tracked edit in each task,
before commit, before push, and before PR creation/update/submission. Owner or relation drift stops
before the side effect. The registry never satisfies this read.

For a review-reopen, those same barriers also re-read the exact current `restackAuthorized`
revision, target controller, operation, expiry, branch/head, claim/path, and consumed state before
the first review/address side effect and every ref rewrite. The registry owner fields continue to
match the current owner, not the delegated controller. No assignee/delegate mutation or replacement
`assignmentAccepted` is permitted. Once matching rewritten `implementationEvidence` consumes the
authorization, no further edit or ref rewrite may begin; only the exact operation's resulting-head
submission/read-back and §7 teardown may finish.

No project update, issue contract, assignment, lifecycle, or typed evidence is stored in the
worktree. Tracked implementation and durable memory notes may be committed; they are Git content,
not Linear authority.

## 6. One issue, one branch, one worktree, at most one PR

One exact Linear issue owns one implementation branch, one active worktree, and at most one
canonical implementation PR. A branch/worktree cannot serve two issues, and an issue cannot fork
into competing implementation branches. A role-`increment` PR has the exact project-plus-issue
trailers; a role-`work-item` PR has only the exact issue trailer.

Independent roots can run concurrently only as separate Graphite tracks rooted at the frozen base.
A child Graphite-tracks its declared issue parent. Never run repository-wide `gt sync`, restack-all,
or a force-push while another issue run may be active. Submit only the current issue branch/track.
Raw-Git/GitHub fallback, where separately authorized, must preserve identical ancestry and exact PR
base.

Overlapping exclusive file/surface responsibility between nominally independent issues is an
allocation collision unless the lead first records and verifies a relation/contract correction
before either edits. A worker cannot resolve that collision locally.

## 7. Teardown and preservation

Remove the worktree and exact-ID registry entry only after independent reads verify the finalized
commit, typed `implementationEvidence`, canonical PR, exact Linear branch/PR relation, `inReview`
state, unchanged issue/project relations, and current type-aware owner:

```bash
git worktree remove "$wt"
# remove only this issue's exact verified .registry/<issue-id> entry
```

Only the working directory and disposable claim disappear. The branch, commits, PR, and Linear
history remain for review and descendants.

A review-reopen that rewrote the branch also requires the matching current
`implementationEvidence` revision related to its `restackAuthorized` native comment, proving that
the authorization was consumed for the exact resulting head. The consumed authorization, unchanged
owner/assignment, branch, commits, PR, and Linear history remain after its canonical worktree and
claim are removed.

On failure, blocker, collision, handoff, hook drift, submit uncertainty, PR mismatch, or missing
read-back, preserve the worktree and registry. Report the exact native/stable issue and optional
project IDs, owner/run, path, branch, start/parent, known commit/PR, and first unknown boundary. Do
not force-remove or delete a recoverable branch under a generic cleanup rule.

Explicit abandonment cleanup requires responsible authority plus complete reads proving what exists
and that no recoverable committed/unpushed work will be lost. Unknown state is preserved, not
pruned.

## 8. Primary-root sidecars

Gitignored metrics and memory telemetry remain non-authoritative machine-local sidecars and must
survive issue worktree teardown. Resolve them through `$WOOSTACK_ROOT`, never the current worktree:

- `.woostack/metrics.json`
- `.woostack/memory/.telemetry.tsv`
- `.woostack/memory/.dream-watermark`

Tracked `.woostack/memory/` notes and the derived `MEMORY.md` index are written in the issue
worktree and may ride its implementation commit. Neither tracked knowledge nor sidecars determine
issue scope, assignment, dependency, phase, progress, or acceptance.

## 9. Stale registry/worktree recovery

A stale directory is not permission to prune or reuse. Re-run complete authority discovery and
classify it as exact resume, verified review-reopen, verified teardown residue, collision, or
unknown. Only exact resume may continue an existing claim. Only verified review-reopen may
atomically recreate a canonical claim/path after proven teardown, and only for its exact current
authorization. Only a fully verified teardown residue may remove its matching registry/worktree. A
collision or unknown state remains preserved for the responsible lead/dispatcher.

Generic `git worktree prune` may drop administration for directories already removed outside this
contract; it must never be used to erase an unresolved exact-ID claim or as proof that Linear/GitHub
state is absent.
