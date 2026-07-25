# Linear attribution

Load this reference only after the backend resolver selects Linear and step 2 has ruled out the verified `change/*` artifact-neutral path.

## Verify the owned project and issue

Linear attribution is blocking, not advisory. Validate the preflight-resolved `LINEAR_CONTEXT`, then extract `LINEAR_PROJECT_STATUSES="$(jq -c '.projectStatuses' <<<"$LINEAR_CONTEXT")"` and `LINEAR_ISSUE_STATES="$(jq -c '.issueStates' <<<"$LINEAR_CONTEXT")"`. Using the repository, project UUID, issue identifier, and those extracted UUID maps, fetch the managed project and issue set with `linear.sh feature-read`. Require successful API verification, require the returned `feature.id` equals the supplied project UUID, and select exactly one increment whose `identifier` equals the supplied `<TEAM-NUMBER>`. The selected issue must come from that verified feature issue set, be managed by woostack, be owned by the resolved repository, and be in the execution lifecycle expected by the driving flow.

Before commit or submission, validate the proposed PR body against that verified pair. It must end with exactly one `Linear-Project:` trailer containing `<uuid>` and exactly one `Linear-Issue:` trailer containing `<TEAM-NUMBER>`, in that order, whose rendered lines are:

```text
Linear-Project: <uuid>
Linear-Issue: <TEAM-NUMBER>
```

Both values must exactly equal the fetched project and issue. A mismatch, duplicate trailer, foreign project issue, missing issue, ambiguous issue, malformed identifier, missing credentials, missing or failed API verification, or adapter failure must block submission and PR update. Do not include a `Spec:` trailer in a Linear-backed PR. Existing PR bodies with any Linear attribution are subject to the same exact check; do not silently normalize or replace foreign, mismatched, partial, or duplicate attribution.

One recovery case is allowed when PR updates are enabled: the verified current branch's existing PR may have neither Linear trailer. Treat it as unattributed, validate the proposed body containing the exact pair, and add that pair through the post-submit `gh pr edit` path. `--no-pr-update` never permits this missing-pair recovery.

## Submit with Graphite

Graphite submission is mandatory because the verified issue owns one exact branch/PR attribution pair. Run `gt submit` and require success; do not use raw-git or `gh pr create` fallbacks when it fails or Graphite is unavailable. A failed submit leaves the issue unchanged and blocks PR update.

## Identify and verify the PR

For Linear, a PR must already exist from the successful Graphite submit. Require its head branch to equal `git branch --show-current`, its repository to equal the backend resolver's repository, and its URL to be the canonical PR URL for that repository. Unless `--no-pr-update` applies, apply the validated title/body with `gh pr edit`, then re-fetch its body with `gh pr view` and require the exact verified trailer pair. With `--no-pr-update`, require the submitted PR body already contains that exact pair. An edit failure, read failure, missing trailer, duplicate, or mismatch leaves the issue unchanged.

## Record and read back attribution

Only after `gt submit` succeeds and all PR identity/body checks pass, invoke the atomic state-plus-evidence transition exactly once through the adapter:

```bash
linear.sh issue-transition \
  --project "<verified-project-uuid>" \
  --repository "<owner/repo>" \
  --issue "<TEAM-NUMBER>" \
  --issue-state-map "$LINEAR_ISSUE_STATES" \
  --target inReview \
  --branch "<submitted-branch>" \
  --pull-request "<canonical-pr-url>"
```

Immediately call `linear.sh feature-read` with both captured UUID maps regardless of whether the mutation returned success, an error, or timed out; never infer mutation outcome from the transport result. Resolve the outcome only from the owned project/issue read-back:

- The exact intended read-back is success: one matching issue has the exact submitted branch and PR URL in managed metadata, `status: inReview`, and the verified project UUID. When a mutation receipt was returned, also require `verified: true` and an empty `pending` array.
- An unchanged issue still at `executing` with no branch/PR evidence is a safe stopped outcome. Do not retry in the same invocation; only a later explicit resume may retry after another fresh read confirms the same unchanged state.
- Any partial or mismatched evidence requires manual reconciliation. Do not retry, overwrite evidence, edit lifecycle state separately, or report success.
- A failed or ambiguous read-back is unresolved. Stop without retrying or changing the PR again.

Never write branch/PR evidence before successful submission and exact PR-body verification, and never write it directly through GraphQL or PR text; the adapter owns the atomic mutation and read-back.

## `--no-pr-update`

If the `--no-pr-update` flag is specified, do not run `gh pr edit`. This path requires the
existing PR body to carry the exact verified trailer pair, records attribution through
`linear.sh issue-transition`, and performs the mandatory `feature-read` read-back. The flag
skips only the field edit; it never skips attribution validation, adapter recording, or read-back.
