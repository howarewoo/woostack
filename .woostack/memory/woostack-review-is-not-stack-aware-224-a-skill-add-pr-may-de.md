---
name: woostack-review-is-not-stack-aware-224-a-skill-add-pr-may-de
type: convention
scope: AGENTS.md, README.md, skills/using-woostack/**, skills/*/SKILL.md, .woostack/plans/**
updated: 2026-07-10
source: pr-268
---
woostack-review is not stack-aware (#224): a skill-add PR may defer command-surface registration (routing/AGENTS.md/README) to a stacked follow-up PR — accept the 'missing from routing/surface lists' finding when a later stacked PR does the wiring. Same for plan-artifact drift (e.g. a duplicated increment section) already resolved by a later increment PR in the same stack: accept, point at the stacked PR, don't re-fix downstack. The lockstep sites themselves are in [[woostack-command-surface-bookkeeping]]; example split: PR #268 (skill) + #269 (wiring); PR #480/#481 (plan section merge).
