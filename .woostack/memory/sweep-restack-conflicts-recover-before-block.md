---
name: sweep-restack-conflicts-recover-before-block
type: gotcha
scope: skills/woostack-sweep/**
tags: sweep, restack, conflicts, graphite, rebase, gt-continue
hook: A restack conflict is not itself a blocker; inspect both PRs, verify, and continue before escalating.
updated: 2026-07-14
source: [[fixes/2026-07-14-sweep-auto-resolve-restack-conflicts]]
---
Restack conflicts: reconcile both PRs, verify, and `gt continue`; block only unresolved intent.
