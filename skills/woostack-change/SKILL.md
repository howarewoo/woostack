---
name: woostack-change
description: Use for a small bounded non-bug enhancement or refactor that can ship in one reviewable PR. Invoke via /woostack-change <goal>.
---

# woostack-change

Implement one small, bounded, non-bug enhancement or refactor from the user's request through
one isolated worktree and task branch, ending in at most one complete reviewable PR. Change
owns delivery through the shared [bounded-delivery contract](references/bounded-delivery.md).
It makes no provider call and invokes no other woostack workflow. The accepted scope is the
authority; Git and GitHub are the delivery evidence, with Graphite evidence only in selected Graphite mode.

## Command

```text
/woostack-change <goal>
```

## Admit the request before mutation

Clarify only what is needed to identify the target, outcome, allowed paths, non-goals, acceptance
criteria, and a focused verification plus changed-path smoke scenario. State the interpreted
bounded scope and derive one stable task identity. Do not create a branch, worktree, or file
change while classifying or clarifying.

Reject or reroute before any mutation:

- a bug, regression, incident, production fault, or root-cause investigation goes to
  [`woostack-fix`](../woostack-fix/SKILL.md);
- work that needs multiple PRs, dependency increments, or coordinated phases goes to
  [`woostack-build`](../woostack-build/SKILL.md); and
- genuinely greenfield creation goes to [`woostack-bootstrap`](../woostack-bootstrap/SKILL.md).

Proceed only when the complete safe scope is a non-bug change that fits one PR. If the request
expands later, stop and reroute rather than silently widening it.

## Deliver the accepted scope

Follow the shared [bounded-delivery contract](references/bounded-delivery.md) for the active task
contract, isolated worktree creation/resume, implementation, focused verification and smoke,
independent review, selected-backend submission, read-back, retention, and return evidence. Change adds
no approval gate or persisted plan. It remains a non-bug command; shared mechanics do not admit
Fix work through Change.
