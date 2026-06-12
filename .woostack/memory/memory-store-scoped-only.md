---
name: memory-store-scoped-only
type: convention
scope: skills/woostack-*/**, skills/woostack-init/**
tags: memory, scoped-store
hook: Memory tooling uses only the scoped store; absent store means skip/empty.
updated: 2026-06-12
source: pr-303
---
Memory recall and record paths use `.woostack/memory/` as the only live store. If the scoped store is absent, recall returns no memory context and record helpers skip with a `/woostack-init` notice.
