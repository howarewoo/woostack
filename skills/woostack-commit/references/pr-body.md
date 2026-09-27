# Pull-request body contract

Apply this after `woostack-commit` has independently verified one canonical current-branch PR.
Issue-free PRs are normal and require no issue reference.

## Preserve ownership

Read the entire existing title and body before editing. Preserve repository-required templates,
checkboxes, links, human-authored context, and unknown sections. Replace only a clearly
woostack-owned prior Goal/Summary/Test plan block; otherwise append the new block. Never rebuild the
whole body from a partial read, and never alter a human title, readiness state, or prose outside the
woostack-owned block unless the approved task explicitly covers it.

A malformed or legacy attribution line is ordinary untrusted PR text. Do not silently normalize,
delete, or reinterpret it. Preserve it unless the caller explicitly requested that exact cleanup
inside the approved task.

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

The Goal matches the approved outcome. Summary bullets describe observed changes, not intent or
marketing claims. Test entries include only commands and scenarios actually run; failures and
omissions stay explicit. Never claim a check from artifact text, a worker assertion, or an earlier
diff, and never publish credentials, raw remote payloads, local filesystem paths, or temporary
receipts.

## Associated GitHub issues

For each caller-supplied issue this PR fully addresses, independently read its canonical URL and
add one line after the woostack-owned block:

```markdown
Resolves https://github.com/owner/repo/issues/42
```

Use one line per fully addressed issue, each with a single closing keyword and the verified URL,
and reuse an existing exact matching line rather than appending a duplicate. Treat closing lines
already in the body as preserved text: keep one for an issue this PR fully addresses, and never
silently delete one whose issue is only partially addressed — leave it and report the discrepancy
so the caller decides. Related authorized issues may share one PR when it delivers them; when the
caller mapped issues to separate PRs, keep that mapping. A partially addressed issue gets no new
closing line, so never imply completion of work this PR does not finish. Do not add a Project
reference: a merged PR resolves its issue, not the containing Project. The line has GitHub's normal
post-merge behavior; it never proves PR identity, scope, assignment, ownership, acceptance, review,
merge, or current issue state. Never infer an issue from the existing body, branch, title, issue
key, or recent activity.

## Validation and read-back

Before editing, verify the canonical repository, PR number/URL, current head branch/SHA, base, and
open state. Then validate the proposed body against preservation of unrelated content, accurate
observed verification outcomes, secret and local-path exclusion, closing URLs that exactly match the
independently read caller-supplied issues, and no unevidenced merge or acceptance claim.

After editing, independently read title, full body, head/base, and head SHA back. Exact body content
and PR identity must match the intended update. A mutation response alone is not proof. On unknown
outcome, re-read before retrying and never create or edit a neighboring PR.
