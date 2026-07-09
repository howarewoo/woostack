---
name: review-workers-avoid-skill-scope
type: gotcha
scope: skills/woostack-review/**,skills/woostack-execute/**
tags: review, execute, subagents, prompts, skill-scope, using-woostack, context-budget
hook: A spawned subagent can auto-load the full woostack-review orchestrator (~14.7K tok, wrong contract) two ways — skill-scoped propagation AND using-woostack routing of a non-self-contained brief. Guard both.
updated: 2026-07-09
source: [[fixes/2026-07-03-review-worker-skill-scope]]
---

A spawned subagent pulls the full `woostack-review` `SKILL.md` into its context two distinct ways:

1. **Skill-scoped propagation.** Some hosts inject the invoking skill into a worker spawned
   skill-scoped or through a skill-aware profile. Fix: spawn woostack-review angle workers as
   **plain/general/default** subagents, never `@woostack-review` / `skill://woostack-review` / the
   review `SKILL.md`. (fixes/2026-07-03-review-worker-skill-scope)

2. **using-woostack routing.** Even a plain general-purpose subagent boots inside the consumer
   repo, inherits its `AGENTS.md`, reads `skill://using-woostack`, and routes review/implement
   intent into the matching orchestrator. woostack-execute's dispatched subagents hit this: a
   "SPEC/CODE QUALITY review this task" brief routed into the full woostack-review skill (~14.7K
   tokens, the wrong contract for a task-scoped reviewer). Fix: each dispatched brief
   (implementer, spec-reviewer, quality-reviewer) and subagent-driver.md declares itself
   **self-contained** — do not load woostack-review or route via using-woostack; follow only the
   brief. (fixes/2026-07-09-execute-subagent-brief-skill-scope)

A worker-side "ignore injected skill" line is a fallback for (1), where a non-skill-scoped spawn
profile is the real fix; for (2) the self-contained brief IS the fix, because the profile is
already plain/general-purpose and still routes without it.
