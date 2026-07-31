# Graphite mechanics

Load this reference only when branch, commit, or submission work needs Graphite command details.

## Select the exact issue branch path

The root workflow supplies the verified native issue identity, role, repository, owner/assignment,
start commit, Graphite parent, deterministic display branch, exact-ID registry claim, and canonical
`$WOOSTACK_ROOT/.woostack/worktrees/issues/<native-issue-id>` path. Branch display text is never
identity.

### Reuse an existing caller-created branch

When a driving workflow already created the issue branch, require its one exact claim, canonical
worktree, checked-out branch, `HEAD`, Graphite parent, repository, issue/project IDs, owner/run, and
assignment to match fresh authority reads. Verify:

```bash
gt branch info --branch "$branch" --quiet
```

Commit must reuse this branch in this worktree. It never runs `gt create`, attaches a duplicate
worktree, or reparents a `woostack-change`, `woostack-execute`, or other workflow-owned branch.
Missing, conflicting, partial, or unexplained identity returns to the owning workflow.

### Create for a direct invocation from the parent

A direct `/woostack-commit --issue …` may create once only when all preflight reads prove:

- the current checkout is the primary root on the exact retained Graphite parent and start commit;
- its complete dirty state is the exact reviewed session diff, with no unrelated path;
- the exact issue, role, project shape, repository, owner, assignment, verification, and
  `precommitReview` still match;
- the exact-ID claim and canonical issue path are absent and collision-free; and
- every local branch/checkout and Graphite/remote identity under the role-derived display name,
  plus every commit, canonical PR, and Linear PR relation for the issue, is absent.

Select `change/<lowercase-verified-issue-identifier>` for a direct role-`work-item` or
`feature/<lowercase-verified-issue-identifier>` for a direct role-`increment`. The verified native
issue ID in the claim and canonical path—not the display name or a title—binds the work.

Only after the hook, targeted staging, fresh authority/diff read, proposed-body validation, and
legacy-`Spec:` guard pass, repeat the preflight and atomically reserve the exact-ID claim. Then run:

```bash
gt create "$branch" --no-interactive -m "<type>: <concise subject>"
```

This command creates the branch and commits only the explicitly staged diff while stacking it on
the verified current parent. Never pass implicit-staging flags, run `gt modify` on the parent, or
follow with `gt track`. Independently verify the exact branch, commit contents, and Graphite parent.
Then return the primary checkout to the retained parent and attach the existing new branch:

```bash
git switch "$graphite_parent"
git worktree add "$wt" "$branch"
```

Verify the claim, canonical path, branch, `HEAD`, Graphite parent, repository, issue/project IDs,
owner, and assignment again. Continue every later operation with `cwd="$wt"`.

Any prior artifact forbids this path; never adopt, recreate, or create around it. After an error,
timeout, or unknown create/switch/attach result, re-read the exact surfaces, preserve every
observed claim/branch/commit/worktree boundary, and stop for explicit reconciliation. Never retry
`gt create` blindly.

## Commit on the reused branch

Use `gt modify` only on the verified existing issue branch:

```bash
gt modify -m "<type>: <concise subject>"
```

An error, timeout, or unknown result requires a fresh Git and Graphite read before deciding whether
the exact intended commit exists. Conflicting or ambiguous state blocks.

## Submit

Run:

```bash
gt submit
```

Graphite creates or updates the issue-owned PR. After every result, independently classify the
remote branch and canonical GitHub PR set before retrying or continuing. Raw Git and `gh pr create`
cannot substitute for Graphite submission; `gh pr edit` is allowed only for the independently
verified existing PR under the PR read-back procedure.

Never force-push. Do not merge.
