# PR title and body

Load this reference only after the caller-supplied Linear issue, optional project, repository, role,
relations, and owner have been independently verified through official MCP. The root workflow
supplies the exact verified role and identities; this procedure never discovers, chooses, or
normalizes attribution.

Use a validated fast-subagent draft for the PR title/body when available. The controller must still
preserve accurate existing context, remove stale generated content, and ensure the Goal, Summary,
and Test plan mention only committed changes and verification actually observed.

## Reject legacy `Spec:` attribution before drafting

Before copying context, rebuilding prose, or editing fields, scan the complete raw existing PR body
line by line. A case-insensitive exact `Spec:` label at the start of a line after only whitespace
and Markdown quote prefixes is a forbidden legacy attribution candidate. This includes exact,
indented, quoted, and mixed-case lines, a `Spec:` line inside a fenced block, and a line with an
opening backtick/tilde fence immediately before the label.

Any candidate blocks before branch creation, commit, PR edit, or Linear mutation, even when a valid
Linear suffix is also present or PR updates are enabled. Do not strip Markdown wrappers, delete the
line, rebuild around it, translate it to a Linear trailer, or otherwise normalize the body. Report
the blocker for explicit migration.

## Select the authoritative drafting input

Resume admission selects exactly one content source before any draft is accepted:

- **Finalized commit absent:** use only the exact staged diff that will be committed. Draft and
  validate against its retained identity.
- **Exact finalized commit present:** stage nothing. Reconstruct solely from the independently
  verified committed base-to-head diff for that exact base/head pair:

  ```bash
  git diff --binary --full-index --no-ext-diff "$base_commit_sha" "$head_commit_sha"
  ```

  Ignore every current staged, unstaged, and untracked path/content, even when dirty state appeared
  after the commit. Do not mix it into changed paths, Goal, Summary, Test plan, title, or manual
  steps. A missing in-memory draft is not a blocker and a surviving draft is not authority; discard
  it unless its recorded base/head/diff identity exactly matches the selected committed diff, then
  still verify every claim from that diff and retained observations.

After the legacy-`Spec:` guard passes, existing PR text may provide accurate human context but never
replaces the selected diff. A stale or unattributed PR is rebuilt from the selected source, not
copied.

Prior hook output may appear under Automated only when a retained observation verifies the exact
command, result, and same committed base/head identity. If that observation is absent, write a
truthful entry such as `Not rerun on resume; prior pre_commit result unavailable` when the hook is
applicable. Never infer a prior result, rerun the hook, invoke the PASS helper, or stage files while
reconstructing a post-commit PR body.

Any fast-subagent prompt and returned draft must carry the selected input identity. Lost,
identity-less, stale, dirty-tree-derived, or mismatched draft text is discarded and reconstructed.

Compose the prose first with this structure:

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
```

Then append exactly one controller-owned suffix selected only from the verified resource role.
For a role-`increment` issue, the final two lines are adjacent and exactly:

```text
Linear-Project: <verified-project-uuid>
Linear-Issue: <TEAM-NUMBER>
```

For a role-`work-item` issue, the sole attribution line is exactly:

```text
Linear-Issue: <TEAM-NUMBER>
```

`<TEAM-NUMBER>` is the exact identifier returned by the independent read of the caller-supplied
issue. `<verified-project-uuid>` is the exact stable UUID returned by the independent read of the
caller-supplied role-`feature` project. Never derive either value from display text, a branch, an
existing PR body, or recent Linear activity.

## Exact suffix validation

Validate the complete proposed body against the selected diff: before commit on the commit-absent
path, or before any GitHub field mutation on a finalized-commit resume.

- There is exactly one raw `Linear-Issue: <TEAM-NUMBER>` line, and it is the final nonblank line.
- For role `increment`, there is exactly one raw `Linear-Project: <verified-project-uuid>` line
  immediately before the issue line, with no blank or intervening line.
- For role `work-item`, there is no `Linear-Project:` line anywhere. Do not fabricate a project.
- No Linear attribution label is wrapped in Markdown, quoted, bulleted, fenced, indented, split,
  or surrounded by extra whitespace. Labels, capitalization, one-space separators, values, order,
  and raw line form are exact.
- Reject missing, duplicate, partial, reordered, malformed, foreign, or mismatched attribution,
  including a project from another repository, an issue outside the verified project, and any
  suffix inconsistent with the verified issue role.
- Neither the proposed body nor an existing body contains a case-insensitive exact, indented,
  quoted, or fenced legacy `Spec:` candidate.

Never copy, repair, or normalize attribution from a fast-subagent draft or current PR. An existing
current-branch PR may be treated as unattributed only after the legacy-`Spec:` guard passes, its body
contains neither official Linear attribution label, and PR updates are enabled. A legacy candidate
or partial/conflicting Linear attribution blocks before branch creation, commit, GitHub, or Linear
mutation. With `--no-pr-update`, the existing body must contain no legacy candidate and already
pass the exact role-derived suffix validation.

## Prose rules

- State the **Goal** as intent or the problem solved in one or two sentences, not a change list. It
  is distinct from Summary, which lists what changed. Always present it.
- Keep Summary bullets concise and specific. Include only changes in the finalized commit.
- Under **Automated**, list commands/tests actually run from verified observations, plus the
  configured `commit.pre_commit` command and result only when its retained observation matches the
  selected input identity. On a finalized-commit resume with no such observation, report
  `Not rerun on resume; prior pre_commit result unavailable` when the hook applies. Never infer or
  rerun it. Show this group whenever an automated check could have run: list observed results, or
  `Not run` with the reason when one was expected but skipped. Omit `### Automated` when no
  automated check applies rather than emitting a placeholder.
- Under **Manual**, group human verification into **Before merge** and **After merge**.
  Before-merge steps are what a reviewer can inspect or exercise now. Include After merge only for
  checks that require a landed change, deployment, migration, or environment-specific state.
- Omit an empty `### Automated`, `### Manual`, Before merge, or After merge group instead of leaving
  placeholder bullets.
- Preserve important existing PR context only when it remains accurate. Replace stale generated
  summaries and test plans; never preserve stale attribution.
- Format test-plan items as unchecked Markdown checkboxes (`- [ ] ...`) so reviewers can mark
  verification complete.

Update the verified existing PR with:

```bash
gh pr edit <number> --title "<concise title>" --body-file <tmp-body-file>
```

Re-fetch with `gh pr view`; the exact intended title and body read-back is success. A missing,
partial, stale, or mismatched read-back is not success and permits no later Linear relation or
state mutation. Never report a title, body, or attribution suffix that was not observed in the
canonical GitHub read-back.
