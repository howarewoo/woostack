---
name: safe-traversal-revalidates-ancestors
type: gotcha
scope: tooling/evals/scripts/**
tags: evals, filesystem, safety
hook: Safe traversal revalidates every ancestor before classifying a path as missing
updated: 2026-07-16
source: [[plans/2026-07-15-skill-evaluation-optimization]]
---
Safe traversal: revalidate every ancestor before treating ENOENT as a missing path.
