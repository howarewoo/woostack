# Development guide

Use these workflows when changing a project created with woostack.

## The loop

Each skill owns its procedure:

| Phase | Skill |
|---|---|
| Elicit and reconcile a feature or proved defect for issue planning | `woostack-prepare` |
| Elicit a complete user-verified specification | `woostack-ideate` |
| Reconcile a supplied specification or candidate issue plan | `woostack-harden` |
| Publish an approved GitHub parent/child or Project issue graph | `woostack-plan` |
| Deliver a small enhancement or refactor in one PR | `woostack-change` |
| Check a running app in a browser | `woostack-qa` |
| Prove a root cause without applying a correction | `woostack-debug` |
| Evaluate approved behavior and trigger corpora for a skill without editing it | `woostack-eval` |
| Reflect on the fixed active-conversation snapshot for concrete durable instruction suggestions | `woostack-reflect` |

Follow the selected command's handoff rules. Only a human can merge a PR.


## Retained artifact records

Prepare and Plan exchange complete plain packets and publish only the verified GitHub issue graph;
they do not create `.woostack/tmp/runs/<run-id>/`, source branches, or implementation
workers. Existing run artifacts and retired managed-provider records are historical user data, remain
readable, and are never migrated, rewritten, or imported. A supplied retained record is evidence only
after exact identity, complete content, and freshness validation.

The [artifact contract](../../woostack-init/references/artifact-backends.md#retained-data-and-retirement)
defines retained-data handling and direct publication recovery. GitHub's
[profile](../../woostack-init/references/artifact-providers/github.md#configuration-and-scope) owns
resource identities and authentication requirements. Keep credentials in the host's authentication
store, not repository configuration. Plan's GitHub publication is direct and does not create a second
remote record.

[`woostack-bootstrap`](../SKILL.md) owns greenfield routing and complete-design approval; its
[filesystem procedure](bootstrap.md#filesystem-write-barrier-and-collision-check) owns bounded
target inspection and fresh collision-safe write admission. Optional project persistence remains
separate from write authority. Init persists only non-secret policy, never local specs or plans.


Implementation branches begin from verified repository base evidence and follow the
[canonical worktree contract](../../woostack-init/references/worktrees.md). Bootstrap's initial
new-repository scaffold is the one pre-base worktree exception. Later PRs require direct
Git/GitHub identity and may include an ordinary optional artifact link. Git and GitHub remain the
source of truth for commits, branches, PRs, reviews, and merges.

Every `/woostack-status` run derives rows from current Git/GitHub evidence, plus Graphite when selected.
Exact caller-supplied GitHub Project or issue context may enrich a row with linked specification,
plan, or fix notes; missing GitHub access affects only that enrichment. The
[feature-state conventions](../../woostack-status/references/conventions.md) define rendering,
reconciliation, and failure behavior.

Legacy local development records are retained data only. They are never adopted as authority,
automatically imported, or rewritten. Init reports actionable retirement guidance when an obsolete
provider or migration request reaches its boundary; no workflow selects or contacts that legacy
system.

## Branching model

The repository chooses its integration branch. Some projects use `main`; others test changes on
a branch such as `staging` before a human merges a release into `main`.

| Branch | Purpose | Parent and PR target |
| --- | --- | --- |
| Integration branch | Shared base for new work | Resolved from repository configuration and Git evidence |
| First feature branch | First PR in a plan | Verified integration branch |
| Dependent feature branch | Next PR in a stack | The approved predecessor's branch |

Use native Git with an authorized GitHub interface for delivery; host-authenticated `gh` remains
supported where appropriate. Graphite is optional for explicitly selected or verified already-managed
tasks/stacks. The [source-control contract](../../woostack-commit/references/graphite.md) owns backend
selection and delivery mechanics. Follow the
[worktree/base-branch contract](../../woostack-init/references/worktrees.md) to resolve the base
and verify each predecessor before starting dependent work. Never force-push.

## When to deviate

Use the selected skill's rules for small or urgent changes. Document any permitted deviation in
the PR description so reviewers understand it. Urgency does not waive approval or merge restrictions.
