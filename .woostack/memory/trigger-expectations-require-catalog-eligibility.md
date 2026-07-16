---
name: trigger-expectations-require-catalog-eligibility
type: gotcha
scope: skills/**/evals/trigger-evals.json
tags: evaluation, triggers, catalogs, routing
hook: Every expectedSkill must be selectable from that run's controlled catalog; supporting or unregistered skills are eligible only when the evaluator explicitly injects them as the target.
updated: 2026-07-16
source: [[plans/2026-07-15-skill-evaluation-optimization]]
---

A trigger case cannot expect a skill absent from its controlled catalog. Keep adjacent-command expectations on registered catalog entries; an unregistered supporting skill is selectable only in its own target evaluation, where preparation adds that external target explicitly.
