# PR title and body

Load this reference only when drafting or updating PR fields. The root workflow supplies the valid
artifact trailer, if any; this procedure does not select or validate backend attribution.

Use a validated fast-subagent draft for the PR title/body when available. The main agent must still preserve accurate existing context, remove stale generated content, and ensure the Goal, Summary, and Test plan mention only committed changes and real verification.

Compose the validated body with this structure:

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

<selected backend trailer, when required>
```

Rules:

- **Verified `change/*`:** omit `Spec:`, `Linear-Project:`, and `Linear-Issue:` trailers. The invocation is artifact-neutral even when the backend resolver reports Linear.
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

Re-fetch with `gh pr view`; the exact intended read-back is success. Never report a title or body that was not observed in the read-back.
