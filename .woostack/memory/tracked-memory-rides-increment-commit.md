---
name: tracked-memory-rides-increment-commit
type: convention
scope: skills/woostack-execute/**, skills/woostack-init/references/**, skills/woostack-address-comments/**, skills/woostack-review/scripts/memory-record.sh, skills/woostack-sweep/**
tags: memory, worktrees
hook: Tracked memory notes are written in the active worktree and committed with it.
updated: 2026-07-04
source: [[fixes/2026-07-04-sweep-memory-commit]]
---
When `.woostack/memory/` is tracked, distillation and accepted-review memory write notes and rebuild `MEMORY.md` in the active increment or swept-PR worktree. Only metrics, telemetry, and watermark sidecars resolve to the primary checkout.
