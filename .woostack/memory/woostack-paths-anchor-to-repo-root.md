---
name: woostack-paths-anchor-to-repo-root
type: gotcha
scope: skills/woostack-review/scripts/**,skills/woostack-address-comments/scripts/**
tags: woostack-root, cwd, monorepo, resolve-root, resolve-outdir, metrics-fold, load-config, memory-record, gitignore
hook: Anchor every default `.woostack/` path to the git repo root via resolve-root.sh — never `$(pwd)` or a bare relative path.
updated: 2026-06-09
source: .woostack/fixes/2026-06-09-woostack-root-anchoring.md
---
A woostack script that defaults a `.woostack/` path to `${GITHUB_WORKSPACE:-$(pwd)}`
or a bare relative path (`.woostack/memory`) silently anchors to the **current working
directory**. When the host agent's CWD drifts into a monorepo workspace package (a
`cd packages/foo` that persists across tool calls), the script then creates/reads
`.woostack/` *inside that package* and appends to the package's `.gitignore` — splitting
woostack state across the tree (issue #272).

The fix: source the shared `resolve-root.sh` and anchor on `$WOOSTACK_ROOT`. It resolves
ONE root with precedence **explicit `WOOSTACK_ROOT` override → `GITHUB_WORKSPACE` (the CI
checkout root) → `git rev-parse --show-toplevel` → `pwd`**, mirroring the long-correct
`resolve-outdir.sh`. Both `resolve-outdir.sh` copies now source it too, so the two
resolvers can't drift again — drift between them was the root cause.

Rules for any new script that touches `.woostack/`:

- `source "$(dirname "${BASH_SOURCE[0]}")/resolve-root.sh"` and use `$WOOSTACK_ROOT/.woostack/...`.
- Keep honoring explicit `MEMORY_DIR` / `MEMORY_FILE` / `OUTDIR` overrides — only the
  *default* base is root-anchored, never the override.
- `resolve-root.sh` is duplicated per skill-scripts dir (review + address-comments), the
  same way `resolve-outdir.sh` is — edit both copies together.
- `git rev-parse --show-toplevel 2>/dev/null || pwd` is the safe fallback: outside a git
  repo (e.g. a `mktemp -d` test dir) it degrades to `pwd`, so CWD-relative tests still pass.

Regression coverage lives in `skills/woostack-review/scripts/tests/test-*-root.sh`
(resolver precedence, metrics-fold, load-config, memory-record).
