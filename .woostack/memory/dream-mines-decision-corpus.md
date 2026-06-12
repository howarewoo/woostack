---
name: dream-mines-decision-corpus
type: convention
scope: skills/woostack-dream/**
tags: dream, memory, corpus
hook: woostack-dream mines specs/plans/fixes for recurring design decisions.
updated: 2026-06-12
source: pr-307
---
`woostack-dream` treats `.woostack/{specs,plans,fixes}` as read-only decision-corpus input for surfacing recurring design trends. `.dream-watermark` limits repeat scans; approved trends update tracked notes through `woostack-commit`.
