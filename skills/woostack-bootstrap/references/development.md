# Development guide

Use these workflows when changing a project created with woostack.

## The loop

Each skill owns its procedure:

| Phase | Skill |
|---|---|
| Plan a feature that needs several PRs, then choose whether to execute | `woostack-build` |
| Diagnose a bug and obtain approval for its correction | `woostack-fix` |
| Deliver a small enhancement or refactor in one PR | `woostack-change` |
| Review an existing PR | `woostack-review` |
| Audit existing code | `woostack-audit` |
| Check a running app in a browser | `woostack-qa` |
| Production errors, Sentry issues, and monitoring defects | `woostack-fix` |
| Evaluate approved behavior and trigger corpora for a skill without editing it | `woostack-eval` |
| Reflect on the fixed active-conversation snapshot for concrete durable instruction suggestions | `woostack-reflect` |

Follow the selected command's handoff rules. Only a human can merge a PR.

Review configuration and diagnostic reports may remain under `.woostack/`.
Review metrics in `.woostack/metrics.json` are ignored by Git. These records do not authorize work
or determine its scope.

## Artifact provider records

Build and project-backed Fix save a local run under `.woostack/tmp/runs/<run-id>/`.
The run contains the manifest, `project-spec.md`, and `execution-plan.md`.
Linear, Plane, and GitHub can hold optional remote copies. A failed mirror operation is recorded
and does not block local planning.

The [artifact contract](../../woostack-init/references/artifact-backends.md) defines storage,
provider selection, synchronization, and recovery. Use the selected provider's linked profile
for its resource types and authentication requirements. Keep credentials in the host's
authentication store, not in repository configuration.

[`woostack-build`](../../woostack-build/SKILL.md) verifies requirements with the user, writes the
specification and plan, then offers `Stop here`, `Execute`, or `Abandon`. Follow its
current handoff procedure. Saved files and provider records do not grant permission to start work.
Small Fix and Change workflows do not contact an artifact provider.

[`woostack-bootstrap`](../SKILL.md) owns greenfield routing and complete-design approval;
its [filesystem procedure](bootstrap.md#filesystem-write-barrier-and-collision-check) owns bounded
target inspection and fresh collision-safe write admission. Optional project persistence remains
separate from write authority. Init persists only non-secret policy, never local specs, plans, or fixes.

Implementation branches begin from verified repository base evidence and follow the
[canonical worktree contract](../../woostack-init/references/worktrees.md). Bootstrap's initial
new-repository scaffold is the one pre-base worktree exception. Later PRs require direct
Git/GitHub identity and may include an ordinary optional artifact link. Git and GitHub remain the
source of truth for commits, branches, PRs, reviews, and merges.

Every `/woostack-status` run derives rows from current Git/GitHub evidence, plus Graphite when selected. Exact
caller-supplied provider context may enrich a row with linked specification, plan, or fix-artifact
notes; missing artifact access affects only that enrichment. The
[feature-state conventions](../../woostack-status/references/conventions.md) define rendering,
reconciliation, and failure behavior.

Legacy local development records are migration input only. They are never adopted as authority.
`/woostack-init --migrate-legacy` is the sole routed owner of the explicit one-way
[legacy migration procedure](../../woostack-init/references/legacy-migration.md) when a caller
chooses Linear persistence.

## Branching model

The repository chooses its integration branch. Some projects use `main`; others test changes on
a branch such as `staging` before a human merges a release into `main`.

| Branch | Purpose | Parent and PR target |
| --- | --- | --- |
| Integration branch | Shared base for new work | Resolved from repository configuration and Git evidence |
| First feature branch | First PR in a plan | Verified integration branch |
| Dependent feature branch | Next PR in a stack | The approved predecessor's branch |

Use Git + `gh` by default; Graphite is optional for explicitly selected or verified already-managed
tasks/stacks. The [source-control contract](../../woostack-commit/references/graphite.md) owns
backend selection and delivery mechanics. Follow the
[worktree/base-branch contract](../../woostack-init/references/worktrees.md) to resolve the base
and verify each predecessor before starting dependent work. Never force-push.

## When to deviate

Use the selected skill's rules for small or urgent changes. Document any permitted deviation in
the PR description so reviewers understand it. Urgency does not waive approval or merge restrictions.
