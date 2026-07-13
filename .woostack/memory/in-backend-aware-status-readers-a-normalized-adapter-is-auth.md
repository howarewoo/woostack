---
name: in-backend-aware-status-readers-a-normalized-adapter-is-auth
type: convention
scope: skills/woostack-status/**
updated: 2026-07-15
source: pr-503
---
In backend-aware status readers, a normalized adapter is authoritative for canonical artifacts rather than optional enrichment; validate every referenced external PR before lifecycle-specific mutation gates, and strip control bytes from remote text before terminal or HTML rendering.
