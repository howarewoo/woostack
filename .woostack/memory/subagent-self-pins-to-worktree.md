---
name: subagent-self-pins-to-worktree
type: gotcha
scope: skills/woostack-execute/**, skills/woostack-init/references/**
tags: worktrees, subagent, dispatch
hook: Subagent isolation can't rely on a controller-set cwd; the dispatch prompt must make the implementer self-pin to $wt.
updated: 2026-06-12
source: .woostack/fixes/2026-06-12-subagent-cwd-pin.md
---
The worktree contract's "dispatch implementers with cwd = `$wt`" is unsatisfiable on a cwd-less spawn host: Claude Code's `Agent` tool has no `cwd` param, and `isolation:"worktree"` makes a fresh throwaway worktree, not the tracked per-PR branch `$wt`. Inheriting the parent cwd silently writes to the protected primary tree. Portable fix: the implementer prompt **self-pins** — first action `cd "$wt"`, then assert `git rev-parse --show-toplevel` equals `$wt` (normalize both sides via `pwd -P` so a symlinked path like macOS `/var`→`/private/var` doesn't false-abort) and abort before any write. Also set a per-call cwd where the host exposes one (belt-and-suspenders). A host that can't run the shell guard can't run TDD either ⇒ inline fallback. See [[tracked-memory-rides-increment-commit]].
