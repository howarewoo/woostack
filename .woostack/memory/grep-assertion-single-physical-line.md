---
name: grep-assertion-single-physical-line
type: gotcha
scope: skills/**
tags: tdd, grep, markdown, plan-verification
hook: A grep plan-assertion only matches within one physical line; reflow inserted prose so each asserted phrase is unbroken, and write the test one-assertion-per-line (no backticks / `&&\` continuations).
updated: 2026-06-14
source: [[plans/2026-06-14-fix-subagent-debug-and-plan-pr]]
---
Grep-TDD over a markdown SKILL has two line-shaped traps that both silently break red→green.

1. **Test-script authoring.** A check written as `grep -q A && grep -q B \` (line-continued) inside a `cat <<'EOF'` heredoc that also contains backticks (e.g. `` `--inline` ``) can be truncated to its first line when written through a shell tool — the chain after the first `grep` is dropped, so the script runs one assertion then `echo PASS` and goes **green while still red**. Fix: write each assertion on its own line under `set -e` (any failure aborts before `PASS`), and keep backticked tokens out of the pattern — grep a backtick-free substring instead.

2. **Asserted phrase wrapping.** `grep` matches within a single physical line, but authored markdown soft-wraps prose. If the inserted text wraps mid-phrase (`is an error: stop and⏎ask which to use`, `**blocked⏎status`), a single-line assertion for that phrase **fails green** even though the words are all present. Fix: reflow the inserted prose so every asserted phrase sits on one physical line, or assert a shorter substring that can't straddle a wrap.

Rule of thumb when authoring a grep-TDD plan for this repo: pick assertion tokens that are short and unbroken, and after editing, run the test once for real (red before, green after) rather than trusting the script shape. See [[woostack-paths-anchor-to-repo-root]] for the sibling "verify the command actually runs" discipline.
