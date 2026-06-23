---
name: recall-reachable-via-pointer-not-tools
type: convention
scope: skills/using-woostack/**, skills/woostack-init/references/**
tags: memory, recall, using-woostack
hook: Memory reachability for no-command work is a read-only recall pointer in using-woostack, never freeform memory tools or duplicated mechanics
updated: 2026-06-22
source: [[fixes/2026-06-22-using-woostack-recall-pointer]]
---
Recall is owned per-skill (review/execute/ask/debug each load a working-set context). To make
the scoped `.woostack/memory/` store reachable from ad-hoc, no-command adoption work,
`using-woostack`'s Project Entry Check carries a read-only recall pointer (step 5) that
cross-links the memory contract and routes read-only questions to `/woostack-ask`. It is a
pointer, NOT a mechanics section and NOT generic write/retrieve memory tools: those bypass the
derived index, scope routing, the reject-by-default write gate, and doctor lints, reopening the
soft-discretion failure mode the autonomy-needs-structural-proof wisdom warns against. Recall reads; writes stay
owned by execute/address-comments/dream ([[memory-store-scoped-only]]). Shared cross-skill refs
still live under references/, reached by cross-link ([[using-woostack-references-home]]).
