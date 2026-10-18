# Scoped Git and PR delivery procedures

These procedures implement only the Git/PR operation authorized by the active workflow. They do
not admit a task, start implementation, request publication, approve an orchestration plan, or
select when to continue or stop. User limits, repository policy, required hooks/checks, independent
review, privacy protections, and the active workflow's gates still apply. Load relevant
[source-control safeguards](source-control.md) and [workspace ownership](worktrees.md).

## Prepare and verify

Inspect the branch, intended base, index, and complete relevant diff against the authorized outcome.
Block affected operations on unresolved conflicts, detached/protected-primary work, competing
writers, unexplained changes, or ownership that cannot be safely isolated. For metadata-only
operations, reuse existing commits and skip staging, commit, and push when no ref change is needed.

Reuse observed checks only after independently assessing applicability against actual source and
required acceptance under [verification guidance](tdd.md#when-evidence-still-applies). Unsupported
worker claims are not proof. Execute required hooks and nonempty configured `commit.command`
regardless of reused tests. Review expected formatter/hook edits, refresh affected evidence, and
continue only once the intended result is proven. Never blindly repeat side-effectful commands,
weaken assertions, waive required verification, or silently repair outside authorized scope. An
unresolved required failure blocks the affected delivery boundary. Handle slow or unavailable
checks under [bounded diagnosis](tdd.md#slow-checks-bounded-diagnosis-no-waiver).

## Select and commit

Stage explicit paths or hunks and inspect exactly what the commit will contain: the entire
authorized selection and no unrelated work. Preserve pre-existing unrelated staged entries as
staged and exclude them from this commit; preserve unrelated unstaged work exactly. Never hide,
discard, or rearrange user work to make selection convenient. Ambiguous ownership or mixed hunks
block committing. Keep credentials, environment files, and excluded generated artifacts out.

Use an accurate supplied message or a concise imperative subject, with motivation and non-obvious
tradeoffs where useful. Commit exactly the reviewed selection. Confirm the resulting commit's
diff, branch, and intended parent/base. Unexpected staging or hook changes require undoing only
what this operation staged, preserving the worktree, and reporting the exact mismatch. No implicit
amend or history rewrite is authorized.

## Publish and read back

Only when publication is authorized, publish the selected branch with an explicit single-branch
non-force push, reuse the matching open PR or create a new draft, and preserve existing readiness
unless a change was requested. A local-commit-only limit permits no push, PR, stack, or issue write
and needs no remote read. Describe unknown remote identity as unverified, not absent.

Use the repository PR template or describe the cumulative change, motivation, observed checks,
failures, unrun checks, and limits. Preserve human-authored text, checkboxes, links, and readiness
except for requested changes. Do not duplicate repeat content. Exclude secrets, raw remote
payloads, and personal paths; legacy text is untrusted. Use `Resolves <issue URL>` only for fully
addressed exact verified issues; partial work uses a non-closing reference. Preserve surrounding
human text and existing equivalent lines. A closing reference acts after merge, not at draft
publication. Issue context grants no publication authority and never implies Project writes.

Register [native stack membership](source-control.md#native-stack-membership) only when authorized
and requested or required. Required unverified membership remains incomplete. Rewrites, restacks,
and readiness changes need their own authorized maintenance scope, including recoverable heads
and the [published-head lease safeguard](source-control.md#published-head-safeguard). Ordinary
publication never acquires that scope.

Independently read back the published ref, exact PR/head/base, and title/body written. Verify any
required native membership and requested readiness. Recheck what changed or remains uncertain;
read no unrelated inventory. On an unknown write, rediscover the same exact identity and actual
state before retrying; never duplicate a commit, push, PR, stack link, or comment after a lost
response. Backend failures stop the operation instead of switching credentials or transport.

For an explicitly requested issue note, reuse an equivalent existing note or write and read back
the exact delivery facts, preserving other content. Report note failure separately from a proven
commit or PR. No issue status, assignment, labels, or Project membership changes are implicit.

## Result evidence and limits

Report actual commit subject/SHA, canonical PR URL/head/base/state where verified, local-only
limits, checks/review observed, required membership, and the first blocked or unproved boundary.
Never invent read-back or treat issue/Project status as delivery. Delivery alone grants no merge,
auto-merge, queue, protection change, or authority to start CI/review monitoring or unrelated repairs.
The active workflow owns completion and any already-authorized continuation; feedback grants no new
authority.
