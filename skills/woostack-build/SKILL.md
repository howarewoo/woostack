---
name: woostack-build
description: Drive a multi-increment feature from one canonical Linear project through two active-conversation approval receipts to normal Execute. Never merges.
---

# woostack-build

Build is a thin controller wrapper around the internal decision and planning phases. It owns one
canonical project, exactly two content approvals, and the transition into normal
[`woostack-execute`](../woostack-execute/SKILL.md). Linear is required product authority for the
build; Git, Graphite, and canonical GitHub reads remain the authority for repository delivery.
Build never merges.

## Commands

```text
/woostack-build <goal> [--project <exact Linear URL-or-UUID>]
/woostack-build --project <exact Linear URL-or-UUID>
```

Build always resolves the exact supplied project or creates exactly one project whose name starts
with `[Build] ` and otherwise derives from the accepted goal. Supplied projects retain their
existing names. Build uses validated repository/workspace/team defaults before starting the
conversation and has no artifact-free fallback. Before acting, load and apply the shared
[Linear artifact contract](../woostack-init/references/artifact-backends.md), the
[repository/project context procedure](references/linear-context.md), and the
[Linear synchronization procedure](references/linear-procedure.md). Those references own
repository association, provider capability, stable identities, canonical fingerprints,
independent read-back, and truthful blocker behavior; this wrapper does not restate them.

## Fixed chain

```text
resolve/create canonical project →
Ideate →
Harden →
project-spec approval in the active conversation, recorded and independently read back in Linear →
Plan →
Harden →
execution-plan approval in the active conversation, recorded and independently read back in Linear →
normal Execute
```

Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) for exhaustive user-verified decisions
and synchronization of the evolving project specification. Ideate has no approval gate. Invoke
[`woostack-harden`](../woostack-harden/SKILL.md) to reconcile bounded repository evidence with
that specification; hardening owns no approval gate.

After the first approval, invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the exact
approved project fingerprint and project identity. When delegated by Build, Plan returns only a
candidate strict sequential direct-issue chain and performs no provider read or mutation. Build
then invokes Harden again, admits that candidate, and uses the linked synchronization procedure
to write and independently read back the final direct issues and native dependencies.

## Exactly two approval stops

Build owns exactly these two stops, in this order, and no other approval or routing stop:

1. **Project specification.** Present the complete independently read project and its
   `canonicalProjectSpecFingerprint` in the active conversation. Continue only after the
   responsible user explicitly approves that exact content. Record the shared
   `projectSpecApprovalRecord` in Linear, then independently read back the record and the exact
   project before proceeding.
2. **Execution plan.** Present the complete independently read direct-issue set and native
   dependency set for the same project and approved specification in the active conversation.
   Continue only after the responsible user explicitly approves that exact content. Record the
   shared `executionPlanApprovalRecord` in Linear, then independently read back both approval
   records, the project, direct issues, and admitted dependencies.

The shared [approval-record contract](../woostack-init/references/artifact-backends.md#shared-approval-records)
defines record fields, active-conversation requirements, receipt identity, causal order, and
read-back evidence. Conversation approval without its Linear receipt, a receipt without the
matching active-conversation approval, status, assignment, labels, content, read-back alone, or an
agent-authored event never clears a stop.

Apply the shared [invalidation rules](../woostack-init/references/artifact-backends.md#shared-approval-records):
a material specification change invalidates both records and returns to specification hardening; a
material direct-issue or dependency change invalidates only `executionPlanApprovalRecord` and
returns to graph hardening. Reconcile the same canonical records, read them back, and obtain fresh
active-conversation approval before continuing.

## Execute transition

After the second approval has been recorded and independently read back, Build always invokes
normal [`woostack-execute`](../woostack-execute/SKILL.md) with the exact project identity,
`projectSpecApprovalRecord`, `executionPlanApprovalRecord`, canonical fingerprints, direct-issue
set, native dependencies, and frozen repository base. Execute owns implementation, focused
verification, Linear progress evidence, and repository delivery under its own contract. Build does
not select another execution mode, create a local authority, or merge.

Any required Linear read, relation pagination, mutation, approval receipt, or independent
read-back failure blocks at the last verified boundary with no local, conversational, cached, or
alternate-provider substitution. Artifact records never replace Git/Graphite/GitHub evidence or
grant repository permission. This wrapper creates no competing project, plan record, approval
procedure, or delivery path; the linked contracts are authoritative.
