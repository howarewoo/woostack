# Pull-request body contract

Use this reference after `woostack-commit` has independently verified one canonical current-branch
PR. Artifact-free PRs are normal and require no provider trailer.
## Preserve ownership

Read the entire existing title/body before editing. Preserve repository-required templates,
checkboxes, links, human-authored context, and unknown sections. Replace only a clearly
woostack-owned prior Goal/Summary/Test plan block, otherwise append the new block. Never rebuild the
whole body from a partial read.

A malformed or legacy attribution line is ordinary untrusted PR text. Do not silently normalize,
delete, or reinterpret it. Preserve it unless the caller explicitly requested that exact cleanup
inside the approved task contract.

## Woostack-owned block

```markdown
## Goal
<one observable outcome>

## Summary
- <concrete change>
- <concrete change>

## Test plan
### Automated
- `<command>` — passed|failed|not run

### Manual
- <scenario and observed result, or "Not run — <reason>">
```

The Goal matches the approved bounded task. Summary bullets describe observed changes, not intent or
marketing claims. Test entries include only commands/scenarios actually run; failures and omissions
remain explicit. Never claim a check from artifact text, a worker assertion, or an earlier diff.

## Associated issue or work item

When the caller supplied one exact issue or work item, independently read its canonical identifier
and add one line after the woostack-owned block:

```markdown
Resolves APP-123
```

Use exactly one closing keyword and the verified issue/work-item identifier. Reuse an existing exact matching
line rather than appending a duplicate. Do not add a project reference: a merged PR resolves its
issue or work item, not the containing project. This line associates the PR immediately and lets the
repository's provider integration move the issue or work item to its configured merged state after
merge. It never proves PR identity, scope, assignment, ownership, acceptance, review, merge, or
current lifecycle state. Never infer the issue from the existing body, branch, title, issue key, or
recent activity.

## Validation and read-back

Before the edit verify the canonical repository, PR number/URL, current head branch/SHA, base, and
open state. Validate the proposed body:

- one current woostack-owned Goal/Summary/Test plan block;
- no deletion or alteration of unrelated content;
- accurate observed verification outcomes;
- no credentials, raw provider payloads, local filesystem paths, or temporary receipts;
- closing reference identifier exactly matches the independently read caller-supplied issue;
- exactly one matching `Resolves <issue identifier>` line when an issue was supplied; and
- no claim of merge or acceptance without direct evidence.

After editing, independently read title, full body, head/base, and head SHA back. Exact body content
and PR identity must match the intended update. A mutation response alone is not proof. On unknown
outcome, re-read before retrying and never create or edit a neighboring PR.
