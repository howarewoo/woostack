---
name: bash-source-empty-under-zsh-source
type: gotcha
scope: skills/woostack-review/scripts/**,skills/woostack-address-comments/scripts/**
tags: BASH_SOURCE, zsh, self-path, source, resolve-root, resolve-outdir, dirname, sourcing-shell
hook: ${BASH_SOURCE[0]} is empty when a script is SOURCED from zsh — use ${BASH_SOURCE[0]:-$0} for self-path resolution.
updated: 2026-06-12
source: .woostack/fixes/2026-06-12-resolve-outdir-zsh.md
---
`${BASH_SOURCE[0]}` is populated only by **bash**. When a host `source`s a script from a
non-bash shell — zsh, which is Claude Code's default Bash-tool shell on macOS — it is empty,
so `dirname "${BASH_SOURCE[0]}"` → `dirname ""` → `.`, and `source ./sibling.sh` resolves
relative to the **caller's cwd**, not the script's own dir. From any cwd that isn't the scripts
dir (e.g. a worktree) the source silently fails. This is how `resolve-outdir.sh` mis-resolved
`OUTDIR` to `sha1("")` = `/tmp/pr-review-da39a3ee5e6b` (issue #314): `resolve-root.sh` never ran,
`WOOSTACK_ROOT` stayed empty, downstream stages inherited the broken `OUTDIR`.

The fix is the repo's blessed idiom (already at `woostack-review/SKILL.md:223`):

```bash
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-root.sh"
```

zsh sets `$0` to the sourced file's path (default `FUNCTION_ARGZERO`), so `$0` supplies the dir
when `BASH_SOURCE` is empty; bash still uses `BASH_SOURCE`. It is plain POSIX parameter-expansion
syntax — parses in bash/zsh/sh — unlike the zsh-only `${(%):-%x}`, which a POSIX `sh` parse chokes on.

How to apply:

- Use `${BASH_SOURCE[0]:-$0}` for **every** self-path resolution (`source`, `cd "$(dirname …)"`,
  `bash "$(dirname …)/helper.sh"`, grep-self). Only `resolve-outdir.sh` actually *manifested* the
  bug — it is the sole host-**sourced** script; the rest are `bash`-executed where `BASH_SOURCE`
  is always set — but hardening the whole bug class pins the invariant against a future
  host-sourced refactor.
- **Exception — never `:-$0` the dual-mode execution guard** `if [ "${BASH_SOURCE[0]}" = "${0}" ]`
  (run `main` only on direct execution). There `:-$0` makes the comparison always-true under zsh,
  so it runs `main` on every `source` — the opposite of intent. The guard stays bare.
- Both `resolve-*.sh` are duplicated per skill-scripts dir (review + address-comments) — edit both,
  same as [[woostack-paths-anchor-to-repo-root]].
- Regression coverage: `skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh` sources
  under real `zsh` (skips if absent) and statically pins "no bare `dirname \"${BASH_SOURCE[0]}\"`".
