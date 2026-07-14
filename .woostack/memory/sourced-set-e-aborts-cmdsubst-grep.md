---
name: sourced-set-e-aborts-cmdsubst-grep
type: gotcha
scope: skills/woostack-init/scripts/tests/**
tags: tdd, bash, set-e, grep, test-harness
hook: Sourcing a helper that runs `set -euo pipefail` turns `-e` on for the whole test script — a line-number `grep` inside `$()` that legitimately matches nothing exits 1 and silently aborts the script before its FAIL summary; guard each such grep with `|| true`.
updated: 2026-07-14
source: [[plans/2026-07-14-memory-tag-recall]]
---
`test-recall.sh` sets only `set -uo pipefail`, but its first line `source "$DIR/assert.sh"` — and `assert.sh` opens with `set -euo pipefail`. Sourcing runs in the caller's shell, so `-e` is now live for the **entire** test script, not just the helper.

Under `-e`, a command substitution that fails aborts the script: the assignment's exit status becomes the substitution's exit status. A line-number probe like

```bash
sc=$(printf '%s\n' "$out" | grep -n '## Scoped memory' | cut -d: -f1)
```

exits 1 whenever the pattern is **legitimately absent** (empty section, red state, a section that does not exist yet). The script then dies mid-run with no error and no FAIL summary — it just stops early and *looks* green-ish or hung. Pre-existing tests dodged this because their greps always match known-present fixture strings; new checks that probe for possibly-absent content are the ones that trip it.

Fix: make every such grep-in-`$()` tolerate no-match with `|| true`:

```bash
sc=$(printf '%s\n' "$out" | grep -n '## Scoped memory' | cut -d: -f1 || true)
```

The `[ -n "$x" ]` guards that follow already handle the empty result correctly; `|| true` just keeps `-e` from aborting first. `grep -c` similarly prints `0` and exits 1 on zero matches — same guard. This is invisible in green (patterns match, no abort) and only bites in red or edge fixtures, so trust the actual red→green run over the script shape.

Sibling: [[grep-assertion-single-physical-line]] (line-shaped grep-TDD traps). Same discipline — run the test for real, red before green.
