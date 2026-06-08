---
name: review-angle-trigger-precision
type: gotcha
scope: skills/woostack-review/**
tags: detect-angles, angle, trigger, diff-gated, enrichment, tier, observability
hook: Enriching a diff-gated angle's prompt is dead unless detect-angles.sh also matches the new pattern — and never broaden a trigger on a common token.
updated: 2026-06-06
source: .woostack/plans/2026-06-06-review-self-contained.md
recall_count: 6
last_recalled: 2026-06-08
---
Most review angles are **diff-gated**: `detect-angles.sh` decides whether the angle
runs at all by grepping the diff for trigger tokens (`has_<angle>_diff_token()` /
`has_<angle>_file()`). Adding a new check to an angle **prompt** does NOTHING on a PR
unless that PR also trips the angle's existing trigger — so enriching a prompt usually
requires extending the matching trigger too. Skip this and the new guidance silently
never fires.

The inverse trap: do **not** broaden a trigger on a token that is common in normal code.
Firing `observability` on any added `?.`/`??` would run the angle on nearly every TS PR
(cost blowup + noise), and `observability` is now `standard`-tier and can block. The rule:
extend the trigger only for **high-signal** tokens (e.g. production `Mock|Fake|Stub`
fallback construction), and let a common-token check ride on the **prompt** — evaluated
only when the angle already fires for another reason. The `?.`/`??` suppressor co-occurs
with the `catch` / `.catch` / logging changes that already trigger the angle, so the
relevant PRs are in scope anyway; accept the rare miss (a lone common-token case with no
other trigger) over universal firing.

Tier follows reasoning load: when an angle gains design-judgment checks (silent-failure
depth, invariant design), bump `fast → standard` in **both** the prompt frontmatter and
the `SKILL.md` routing table — they are two separate sites. See
[[review-prompt-self-contained-blob]].
