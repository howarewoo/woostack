---
name: woo-stack-address-comments
description: Use when addressing the unresolved review threads on a pull request — fix or push back on each finding, reply, resolve, and push. Delegates to the woo-stack-review address verb; never merges.
---

# woo-stack-address-comments

## Overview

Addresses the unresolved review threads on a PR autonomously: for each thread, verify the
concern against the code, then **FIX** / **ACCEPT** (push back, with reasoning) / **CLARIFY**,
reply without performative language, resolve, and push. Ends by offering a re-review.
**Never merges.**

This is a thin entry point. The engine is the `address` verb of the `woo-stack-review` skill
— there is no separate implementation here.

## Dependency preflight

This skill delegates to `woo-stack-review` (its sibling in the woo-stack collection). If it
is not installed, name it and **offer to install the collection inline**
(`npx skills add howarewoo/woo-stack`), then continue. There is no manual fallback — the
address engine lives in that skill.

## Procedure

1. **Preflight** `woo-stack-review` as above.
2. **Invoke** `woo-stack-review address <PR#>` (or the current branch's open PR when no number
   is given). It fetches unresolved threads into `/tmp/pr-review/address-threads.json`, reads
   `.woo-stack/memory.md` if present, and processes every thread per its own rubric.
3. **Offer re-review.** When all threads are handled and pushed, offer to run
   `woo-stack-review` again. Stop there — do not merge.

## Hard constraints

- **No merge.** Branch protection and the merge decision stay with the user.
- **No duplicate engine.** All thread-handling logic lives in `woo-stack-review`; this skill
  only routes to it.
- **No performative replies.** Reply with the technical reasoning or the fix itself.
