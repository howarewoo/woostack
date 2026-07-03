---
name: review-rule-dedupe-by-document-identity
type: gotcha
scope: skills/woostack-review/scripts/**
tags: review, prefetch, rules, symlink
hook: Project-rule prefetch must dedupe by document identity, not just relative path.
updated: 2026-07-03
source: [[fixes/2026-07-03-prefetch-rule-dedupe]]
---
Rule files commonly alias one canonical policy through symlinks (`AGENTS.md`, `GEMINI.md`, `CLAUDE.md`) or config globs. When composing `rules.md`, dedupe across auto-discovery and `review.project_rules` by real path and content hash before path, or every review worker rereads duplicated policy text and the 100KB cap can evict unique rules.
