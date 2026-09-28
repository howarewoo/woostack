# Pull-request body contract

Apply this after `woostack-commit` has independently verified one canonical current-branch PR.
Issue-free PRs are normal and require no issue reference.

## Preserve ownership and present evidence

Read the complete existing title and body and the target repository's applicable PR template.
For a new PR, use the template's sections to present the observed outcome, changes, affected
paths when requested, and verification. Without a template, write a concise ordinary body
covering those facts. Do not append a second standard Goal/Summary/Test plan block.

On an update, preserve required checkboxes, links, human-authored or ownership-uncertain content,
title, and readiness. Edit only content clearly authorized for this task in appropriate existing
sections. If a section cannot safely be edited, add only missing evidence without repeating the
full template, or report the exact edit boundary. A repeat with no new evidence makes no duplicate
section or claim; never automatically deduplicate old human sections or rebuild from a partial read.

Describe observed changes rather than intent; list only checks and scenarios actually run, with
failures and unrun required checks explicit. Never claim verification from a worker assertion or
stale artifact. Exclude credentials, raw remote payloads, personal paths, and temporary receipts.
Preserve malformed or legacy attribution as untrusted human text unless its exact cleanup was
separately authorized.

## Associated GitHub issues

For each caller-supplied issue this PR fully addresses, independently read its canonical URL and
add one line in the PR body:

```markdown
Resolves https://github.com/owner/repo/issues/42
```

Use one line per fully addressed issue, each with a single closing keyword and the verified URL,
and reuse an existing exact matching line rather than appending a duplicate. Inspect existing
closing references before submission: if any would close an issue this PR does not fully address,
or whose completion cannot be verified, block delivery. Preserve the human-authored line until the
caller explicitly authorizes its removal or neutralization, or the PR fully addresses that issue;
report the blocker rather than submitting a live closing reference for incomplete work. Related
authorized issues may share one PR when it delivers them; when the caller mapped issues to separate
PRs, keep that mapping. A partially addressed issue gets no new closing line. Do not add a Project
reference: a merged PR resolves its issue, not the containing Project. The line has GitHub's normal
post-merge behavior; it never proves PR identity, scope, assignment, ownership, acceptance, review,
merge, or current issue state. Never infer an issue from the existing body, branch, title, issue
key, or recent activity.

## Validation and read-back

Before editing, verify the canonical repository, PR number/URL, current head branch/SHA, base, and
open state. Then validate the proposed body against preservation of unrelated content, accurate
observed verification outcomes, secret and local-path exclusion, no active closing reference for
incomplete work, closing URLs that exactly match the independently read caller-supplied issues, and
no unevidenced merge or acceptance claim.

After editing, independently read title, full body, head/base, and head SHA back. Exact body content
and PR identity must match the intended update. A mutation response alone is not proof. On unknown
outcome, re-read before retrying and never create or edit a neighboring PR.
