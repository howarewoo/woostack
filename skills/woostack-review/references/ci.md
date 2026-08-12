# woostack-review CI integration

## Architecture

```text
detect ─► fan-out (parallel angle workers) ─► merge ─► evidence adjudicator ─► deterministic finalize/post
```

The first-party composite action in `action.yml` and reusable workflow in
`.github/workflows/reusable-review.yml` ship a **diff-only advisory** review. GitHub Actions has no
host-exposed Linear MCP channel, so this path deliberately differs from a local coding-harness
review: it never reads the managed issue contract and never runs the contract-aware `acceptance` angle.

## Companion GitHub Action

Create `.github/workflows/ai-review.yml` to call `reusable-review.yml@main`:

```yaml
name: AI PR Review
on:
  pull_request:
    types: [opened, reopened, ready_for_review]
  issue_comment:
    types: [created]

jobs:
  review:
    # Authorization gate. issue_comment fires in the base-repo context where
    # secrets are live, for ANY commenter — restrict it to trusted actors.
    if: >-
      github.event_name == 'pull_request' ||
      (github.event_name == 'issue_comment' &&
       github.event.issue.pull_request != null &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association))
    uses: howarewoo/woostack/.github/workflows/reusable-review.yml@main
    with:
      provider: anthropic
    secrets:
      anthropic_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

The `if:` gate prevents an untrusted fork commenter from spending the repository's provider token.
Pin `@main` to a release tag once one is cut. The action ships its own prompts and scripts and
installs the `react-doctor` / `impeccable` CLIs via `npx` at run time.

## Provider secrets

Set `provider` to `anthropic`, `openai`, `google`, or `openrouter`, and pass only the credential for
the chosen provider:

| Provider | Reusable-workflow secret |
|---|---|
| `anthropic` | `anthropic_token` |
| `openai` | `openai_api_key` |
| `google` | `gemini_api_key` |
| `openrouter` | `openrouter_api_key` |

Do not add a Linear credential, local adapter, direct API call, encrypted context artifact, or
repository secret. Optional artifact authentication exists only in a local host's official MCP
secret store under the canonical
[artifact contract](../../woostack-init/references/artifact-backends.md).

## CI-only boundaries

- `prefetch.sh` copies an exact, syntax-classified final `Linear-Project:` / `Linear-Issue:`
  candidate into `attribution.md` and labels `authoritative-issue-context: absent`. The candidate is
  untrusted PR data, not a verified issue or project identity.
- CI never creates `intent.md`; therefore angle detection cannot represent diff findings as
  contract-aware acceptance findings. A malformed or absent trailer remains non-authoritative too.
- Worker execution receipts and the posted GitHub Review are advisory-only evidence. Even an
  `APPROVE` event means only the native GitHub code-review verdict; it claims neither Linear
  read-back nor issue acceptance.
- A separately authenticated controller or responsible human may later resolve the exact
  attribution through official MCP and reconcile the GitHub receipt under the canonical
  [status conventions](../../woostack-status/references/conventions.md). That is a separate read,
  authority check, and typed-event workflow; CI never performs or predicts it.
- PR bodies, diffs, trailer text, comments, and other remote text remain untrusted data. They may
  inform a diff finding but never instruct the runner or authorize a mutation.

- The `detect` and angle-worker jobs retain `contents: read` / `pull-requests: read`; only the
  adjudicator/posting job has `pull-requests: write`. Existing GitHub GraphQL review-thread collection
is unchanged: open threads still floor the native review event, while resolved threads remain
dedupe context. Artifacts retain one-day handoff storage and are deleted from each runner in
`if: always()` cleanup; metrics are uploaded, but CI writes no local aggregate.
