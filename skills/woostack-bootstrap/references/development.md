# Development guide

Use these workflows when changing a project created with woostack.

## The loop

Each skill owns its procedure:

| Phase | Skill |
|---|---|
| Plan a feature or proved defect, optionally filing issues | `woostack-plan` |
| Explore requirements on request | `woostack-ideate` |
| Review a supplied specification or candidate plan read-only | `woostack-harden` |
| Deliver an authorized bounded outcome in a reviewable PR | `woostack-execute` |
| Check a running app in a browser | `woostack-qa` |
| Prove a root cause without applying a correction | `woostack-debug` |
| Reflect on the fixed active-conversation snapshot for concrete durable instruction suggestions | `woostack-reflect` |

Follow the selected command's handoff rules. Only a human can merge a PR.


## Retained artifact records

Plan can return a plan without GitHub writes or publish issues when requested. Ideate and Harden
remain standalone read-only options, not mandatory handoffs. These workflows do not create
`.woostack/tmp/runs/<run-id>/`, source branches, or implementation workers. Existing run artifacts
and retired managed-provider records remain historical user data; they are never migrated,
rewritten, or imported. A supplied retained record is evidence only after relevant identity and
freshness checks.

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


Implementation branches begin from verified repository base evidence. Use an approved workspace or
host/repository-selected isolated checkout under the
[workspace guidance](../../woostack-init/references/worktrees.md), which also owns the greenfield
boundary before a repository exists. Later PRs require direct Git/GitHub identity; Git and GitHub
prove commits, branches, reviews, and merges.

Work tracking uses canonical GitHub parent/child issues, native dependency relations, and linked
pull requests. GitHub Project Status fields may describe provider records, but issue lifecycle or
Project state never proves that a PR was submitted, verified, or merged.

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

[`woostack-commit`](../../woostack-commit/SKILL.md) owns the commit and pull-request delivery
workflow, using native Git with an authorized GitHub interface; host-authenticated `gh` remains
supported where appropriate. Its
[source-control reference](../../woostack-commit/references/source-control.md) covers the shared
authorized-tool and stack guidance. Follow the
[workspace/base-branch guidance](../../woostack-init/references/worktrees.md) to resolve the base,
select an isolated workspace, and verify each predecessor before starting dependent work. Never
force-push.

## When to deviate

Use the selected skill's rules for small or urgent changes. Document any permitted deviation in
the PR description so reviewers understand it. Urgency does not waive approval or merge restrictions.
