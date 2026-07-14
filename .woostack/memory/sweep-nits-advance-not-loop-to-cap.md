---
name: sweep-nits-advance-not-loop-to-cap
type: decision
scope: skills/woostack-sweep/**
tags: sweep, nits, max_rounds, cap, review-loop, done-with-findings, overnight
hook: verdict before backstop; max_rounds and no-progress apply only after the fresh verdict remains blocking.
updated: 2026-07-14
source: [[fixes/2026-07-14-sweep-advance-nits-any-round]]
---
Verdict before backstop: classify each fresh receipt-backed STATUS_LINE; no-blocking always advances.
