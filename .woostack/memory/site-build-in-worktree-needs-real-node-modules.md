---
name: site-build-in-worktree-needs-real-node-modules
type: gotcha
scope: site/**
tags: turbopack, next, worktree, node_modules, symlink, pnpm, build, fumadocs
hook: Building site/ in a woostack worktree needs a real `pnpm install` — Turbopack rejects a node_modules symlink that escapes the worktree root.
updated: 2026-06-15
source: [[plans/2026-06-15-core-concepts-context-economy]]
---
`site/node_modules` is gitignored, so a fresh woostack per-PR worktree (under
`.woostack/worktrees/`) has no `site/node_modules` and cannot build until deps exist. The fast
shortcut — symlinking the primary tree's `node_modules` into the worktree — fails under Next.js 16:

```
unexpected Turbopack error … Symlink [project]/node_modules is invalid, it points out of the filesystem root
```

Turbopack treats the worktree as the project root and refuses a `node_modules` symlink whose target
resolves outside that root (the primary tree). Webpack would follow it, but Next 16 `next build`
uses Turbopack by default with no easy opt-out.

How to apply:

- To verify a `site/` change inside a worktree, run a real install there:
  `pnpm -C <worktree>/site install --frozen-lockfile --prefer-offline`. It is fast — pnpm hardlinks
  from the global store (a few seconds), and `site/node_modules` is gitignored so it never gets
  committed.
- Then `pnpm -C <worktree>/site build` (production build + typecheck) and, for a visual check,
  `PORT=<free> pnpm -C <worktree>/site dev`.
- The editor LSP will flag `JSX element implicitly has type 'any' … no interface 'JSX.IntrinsicElements'`
  on a new `.tsx` until that install lands react types in the worktree — those are stale-LSP false
  positives, not real errors. The source of truth is `next build` / `tsc --noEmit` (the `types:check`
  script), which type-check the whole project.
