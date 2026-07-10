---
name: shared-config-migrations-update-all-consumers
type: gotcha
scope: skills/**/scripts/**,skills/**/SKILL.md,site/content/docs/**,site/scripts/**
tags: config, migration, loaders, documentation, lockstep
hook: Shared config moves need a cross-consumer test; one stale loader can preserve an obsolete nested path.
updated: 2026-07-10
source: [[fixes/2026-07-10-audit-root-model-config-docs]]
---
Shared config moves need a cross-consumer test: stale loaders can preserve obsolete paths.
