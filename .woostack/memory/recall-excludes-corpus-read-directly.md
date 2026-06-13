---
name: recall-excludes-corpus-read-directly
type: convention
scope: skills/woostack-init/scripts/**, skills/woostack-ask/**, skills/woostack-dream/**
tags: recall, memory, corpus, wisdom
hook: Scoped recall (recall.sh §6) never surfaces type spec/plan/wisdom — a skill needing the decision corpus or wisdom must read it directly or wholesale-load.
updated: 2026-06-13
source: .woostack/specs/2026-06-13-woostack-ask.md
---
`recall.sh` scope-routes only recall-eligible notes; it deliberately excludes `spec`,
`plan`, and `wisdom` types. So any skill that needs the decision corpus (specs/plans/fixes)
or wisdom cannot get it from recall — it must read those artifacts **directly** (woostack-dream,
woostack-ask) or **wholesale-load** them (the wisdom consumers build/ideate/plan/review).
woostack-ask exploits this: it uses recall as an entry point but reads the whole `.woostack/`
tree, enumerated dynamically. Don't assume recall covers the corpus. See
[[memory-store-scoped-only]] and [[memory-telemetry-sidecar]].
