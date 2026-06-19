---
name: spec-plan-quality-via-angle-preflight
type: convention
scope: skills/woostack-harden/**,skills/woostack-plan/**,skills/woostack-build/references/**
tags: build-loop, angles, harden, plan, self-review, gate, shift-left, review
hook: Strengthen spec/plan quality by enriching the shared angle pre-flight rubric (harden + plan self-review) — never by auto-running woostack-review on the docs PR or adding a gate.
updated: 2026-06-19
source: [[fixes/2026-06-19-angle-preflight]]
---
`woostack-review`'s angles are **post-diff lenses that path-gate on CODE** — on a docs-only
spec+plan PR they fire late and mostly misfire. So spec/plan quality is owned at **authoring**, not
at review: the angle vocabulary lives once in
`skills/woostack-harden/references/angle-preflight.md` (a **spec lens** → §6/§7, a **plan lens** →
decomposition, plus a YAGNI skip rule), cross-linking the canonical angle source
([[review-add-angle-sites]]'s `load-config.sh` `VALID_ANGLES` + `prompts/angles/`) rather than
restating it.

To strengthen spec/plan quality, **enrich that rubric and its consumers** — do not invent a new
mechanism:
- **Consumers (wiring sites):** `woostack-harden` SKILL (grill-loop bullet + terminal-state
  condition + a hard-constraint bullet — it walks the pre-flight on **both** the spec and the
  plan), `woostack-plan` SKILL `## Self-review` (the *Angle coverage* check), and the two
  templates `spec-template.md` §7 + `plan-template.md` `## Plan Checks` (bare-path refs, since
  templates land in consumer repos).
- **No new gate.** A post-write auto-review would be a new approval stop, breaking
  `woostack-build`'s "inherit two gates, add one" — never skip or infer an approval gate; harden
  stays gate-less and amends in place. The swarm review still runs on the **code** increment PRs.

This is the read-time/write-time split: **interview the docs (harden), swarm-review the code
(review).** Don't point `woostack-review` at a spec/plan as a quality gate.
