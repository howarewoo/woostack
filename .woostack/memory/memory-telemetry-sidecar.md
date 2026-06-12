---
name: memory-telemetry-sidecar
type: convention
scope: skills/woostack-init/scripts/**
tags: memory, telemetry
hook: Recall telemetry belongs in .telemetry.tsv, not note frontmatter.
updated: 2026-06-12
source: pr-305
---
Keep recall counters and last-recalled dates in `.woostack/memory/.telemetry.tsv`. Memory notes should not carry `recall_count` or `last_recalled` frontmatter because tracked notes must not churn on recall.
