# woostack-review CI integration

## Architecture

```
detect ─► fan-out (parallel sub-agents, one per angle) ─► merge ─► skeptical validator ─► post
```

This mirrors the local skill exactly — the first-party composite action `action.yml` and the reusable workflow `.github/workflows/reusable-review.yml`, both shipped from this repo — just with GHA matrix jobs standing in for local sub-agents.

## Companion GitHub Action

For a fully-managed CI flow, create `.github/workflows/ai-review.yml` to call `reusable-review.yml@main`:

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
    # secrets are live, for ANY commenter — so restrict comment-triggered runs
    # to trusted actors. Without this, a fork contributor's comment can spend
    # your token (the GitHub "pwn-requests" pattern).
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
      linear_api_key: ${{ secrets.LINEAR_API_KEY }} # Required only for Linear-backed repositories.
```

The `if:` gate restricts comment-triggered runs to the repo owner / members / collaborators — the `issue_comment` trigger runs in the base-repo context with secrets available to *any* commenter, so dropping it lets a fork contributor's comment spend your token. Pin `@main` to a release tag once one is cut. Markdown-backed repositories need no additional setup; Linear-backed repositories must configure the `LINEAR_API_KEY` repository secret. The action ships its own prompts and scripts (`skills/woostack-review/`) and installs the `react-doctor` / `impeccable` CLIs via `npx` at run time.

## Provider and Linear secrets

Set `provider` to one of `anthropic`, `openai`, `google`, or `openrouter`, and pass only the credential for the chosen provider:

| Provider | Reusable-workflow secret |
|---|---|
| `anthropic` | `anthropic_token` |
| `openai` | `openai_api_key` |
| `google` | `gemini_api_key` |
| `openrouter` | `openrouter_api_key` |


Markdown-backed repositories need no additional setup. Linear-backed repositories must also pass `linear_api_key: ${{ secrets.LINEAR_API_KEY }}`. The reusable workflow exposes `LINEAR_API_KEY` only to exactly attributed Linear `feature-read` / attributed Linear reads. It is never serialized into `artifact-context.json` and no worker receives it.

## CI-only boundaries

The `detect` job and angle-worker matrix run with `contents: read` and `pull-requests: read`. The validator/posting job receives `contents: read` and `pull-requests: write`.

The reusable workflow uploads prefetched artifacts with one-day retention and removes each job's local `$OUTDIR` in an `if: always()` cleanup step. Per-angle metrics are uploaded as build artifacts; CI does not write cross-PR memory or fold the local metrics aggregate.
