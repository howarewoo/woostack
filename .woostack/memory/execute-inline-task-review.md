---
name: execute-inline-task-review
type: gotcha
scope: skills/woostack-execute/**
tags: execute, inline, review, tokens, task-review
hook: Inline execute should reuse bounded task spec and quality checks instead of falling back to a broader PR review loop.
updated: 2026-06-09
source: [[fixes/2026-06-09-inline-execute-quality-checks]]
---
`woostack-execute` has two drivers, but inline mode is not a reason to swap the bounded task
review loop for a broad PR review. The token-efficient shape is shared criteria with different
execution mechanics:

- inline mode: the controller checks each task diff for spec compliance, then code quality.
- subagent mode: fresh reviewer subagents apply the same checks with tier routing.

Avoid routing inline mode through `woostack-review --fast` as the normal quality gate. It expands
the review surface beyond the task diff and, in this skills repo, can be a poor fit for
markdown-only skill-doc increments. Link inline/subagent wording back to the same spec and quality
criteria so future edits do not drift.
