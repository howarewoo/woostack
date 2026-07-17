# Graphite mechanics and fallbacks

Load this reference only when branch creation, commit, or submission needs Graphite command details or an allowed fallback decision.

## Create or track a branch

Use a short slug based on the change, such as `feature/review-model-defaults` or `feature/add-commit-skill`. Prefer Graphite for branch creation and tracking: switch to the resolved base, run `gt create feature/<short-slug>`, then ensure the parent is registered with `gt track feature/<short-slug> --parent "$base"`. If Graphite is unavailable or clearly not initialized, fall back to raw git only:

```bash
git switch -c feature/<short-slug> "$base"
```

This fallback is forbidden for a verified `change/*` invocation because its branch must already pass the canonical worktree and Graphite-registration guard.

## Commit

Use Graphite:

```bash
gt modify -m "<type>: <concise subject>"
```

For a verified `change/*` invocation this command is mandatory; its pre-existing tracked branch must not use `gt create` or raw git. For other invocations, prefer `gt modify`, use `gt create -m "<type>: <concise subject>"` only when creating the branch and committing in one Graphite flow is appropriate for the local stack state, and fall back to raw git only when Graphite is unavailable:

```bash
git commit -m "<type>: <concise subject>"
```

## Submit

Run:

```bash
gt submit
```

If a PR already exists, `gt submit` should update it. For a Markdown-backed invocation, if Graphite is unavailable, push the branch and use `gh pr create` or `gh pr edit` as appropriate.

A verified `change/*` invocation has no raw-git or `gh pr create` fallback. A Linear-backed invocation also requires successful Graphite submission because the verified issue owns one exact branch/PR attribution pair; do not use raw-git or `gh pr create` fallbacks when submission fails or Graphite is unavailable.

Never force-push. Do not merge.
