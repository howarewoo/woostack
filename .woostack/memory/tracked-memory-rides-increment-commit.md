---
name: tracked-memory-rides-increment-commit
type: convention
scope: skills/woostack-execute/**, skills/woostack-init/references/**
tags: memory, worktrees
hook: Tracked memory notes are written in the increment worktree and committed with it.
updated: 2026-06-12
source: pr-306
---
When `.woostack/memory/` is tracked, distillation writes notes and rebuilds `MEMORY.md` in the active increment worktree. Only metrics, telemetry, and watermark sidecars resolve to the primary checkout.
