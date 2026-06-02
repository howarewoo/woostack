---
name: woostack-address-comments
description: Use when addressing the unresolved review threads on a pull request — fix or push back on each finding, reply, resolve, and push. Delegates to the woostack-review address verb; never merges.
---

# woostack-address-comments

## Overview

Addresses the unresolved review threads on a PR. For each thread it verifies the concern
against the code and recommends **FIX** / **ACCEPT** (push back, with reasoning) /
**CLARIFY**. By **default** it presents the batched recommendations for your approval (or
per-thread override) before applying anything; with `--auto` it skips the gate and acts
autonomously. After the approved verdicts are applied it replies without performative
language, resolves, records accept-by-design learnings as scoped memory notes when
available, pushes, and offers a re-review. **Never merges.**

This is a thin entry point. The engine is the `address` verb of the `woostack-review` skill
— there is no separate implementation here.

## Dependency preflight

This skill delegates to `woostack-review` (its sibling in the woostack collection). If it
is not installed, name it and **offer to install the collection inline**
(`pnpx skills add howarewoo/woostack`), then continue. There is no manual fallback — the
address engine lives in that skill.

## Procedure

1. **Preflight** `woostack-review` as above.
2. **Invoke** `woostack-review address <PR#>` (or the current branch's open PR when no number
   is given), passing `--auto` straight through when the user asked for an autonomous run. It
   fetches unresolved threads into `/tmp/pr-review/address-threads.json`, reads the team's
   cross-PR memory, and processes every thread per its own rubric — the interactive verdict
   gate by default, or autonomously under `--auto`. When the repo has a `.woostack/memory/`
   store, that memory is **scope-routed** to the PR's changed files (composed by the review
   engine's `recall.sh`), so address applies the same matched conventions and accepted-issue
   dismissals as review — not the whole dump. Final **ACCEPT** verdicts write back
   through the same memory system: an individual scoped note under `.woostack/memory/`
   when that store exists, or a flat `.woostack/memory.md` bullet as the legacy fallback.
3. **Offer re-review.** When all threads are handled and pushed, offer to run
   `woostack-review` again. Stop there — do not merge.

## Hard constraints

- **No merge.** Branch protection and the merge decision stay with the user.
- **No duplicate engine.** All thread-handling logic lives in `woostack-review`; this skill
  only routes to it.
- **No performative replies.** Reply with the technical reasoning or the fix itself.
