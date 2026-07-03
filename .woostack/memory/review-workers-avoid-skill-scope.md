---
name: review-workers-avoid-skill-scope
type: gotcha
scope: skills/woostack-review/**
tags: review, subagents, prompts, skill-scope, context-budget
hook: Review angle workers must be spawned as plain/general/default subagents; skill-scoped workers can auto-load the full woostack-review orchestrator into every angle context.
updated: 2026-07-03
source: [[fixes/2026-07-03-review-worker-skill-scope]]
---

Some hosts propagate the invoking skill into spawned workers when the worker is skill-scoped or
spawned through a skill-aware profile. For `woostack-review`, that makes every angle worker read the
full orchestrator `SKILL.md` even though the worker only needs `_worker-header.md`, its angle prompt,
and `$OUTDIR` artifacts.

When editing review worker dispatch docs or provider prompts, preserve the explicit boundary:
workers are **plain/general/default** subagents, never `@woostack-review`, `skill://woostack-review`,
or the review `SKILL.md`. A worker-side "ignore injected skill" line is only a safety fallback; the
real token fix is choosing a non-skill-scoped spawn profile.
