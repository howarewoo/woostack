---
name: worktree-local-state-common-root
type: gotcha
scope: skills/woostack-review/scripts/**, skills/woostack-address-comments/scripts/**, skills/woostack-init/references/**
tags: worktrees, memory, metrics, roots
updated: 2026-06-17
source: [[fixes/2026-06-17-local-memory-common-root]]
---

Worktree helpers need two roots: active checkout for tracked edits, primary/common checkout for local-only memory, wisdom, metrics, and telemetry sidecars.
