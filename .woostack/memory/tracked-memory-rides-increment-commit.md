---
name: tracked-memory-rides-increment-commit
type: convention
scope: skills/woostack-execute/**, skills/woostack-fix/**, skills/woostack-init/references/**
tags: memory, worktrees
hook: Tracked memory notes are written in the increment/fix worktree and committed with it — a skill doc that says the distill "targets the primary tree" strands the note.
updated: 2026-06-30
source: pr-306
---
When `.woostack/memory/` is tracked, distillation writes notes and rebuilds `MEMORY.md` in the active increment/fix worktree so they **ride that commit**. Only metrics, telemetry, and watermark sidecars resolve to the primary checkout via `WOOSTACK_ROOT` (see [[worktree-local-state-common-root]]).

**Gotcha:** a skill doc (e.g. `woostack-fix` step 6) that says the memory distill "targets the primary tree via `WOOSTACK_ROOT`, so it survives teardown" is wrong for notes — it directs the write outside the worktree, where the note lands uncommitted and never reaches the PR. Only the gitignored sidecars target the primary tree. Fixed in [[fixes/2026-06-30-memory-rides-fix-commit]].
