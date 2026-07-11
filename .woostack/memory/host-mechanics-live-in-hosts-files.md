---
name: host-mechanics-live-in-hosts-files
type: convention
scope: skills/using-woostack/references/hosts/**, skills/using-woostack/references/model-tiers.md, skills/woostack-execute/references/subagent-driver.md, skills/woostack-review/SKILL.md, skills/woostack-commit/SKILL.md, skills/woostack-init/SKILL.md, skills/woostack-execute-overnight/SKILL.md
tags: hosts, dispatch, directive, lockstep
hook: adding a host or editing consumer dispatch text
source: [[plans/2026-07-10-host-references]]
updated: 2026-07-10
---

Per-host mechanics (spawn primitive, per-call model/effort knobs, tier-routing class,
host-level fallback posture, degradation) live ONLY in
`skills/using-woostack/references/hosts/<host>.md` — six files, one fixed six-section
contract (README states it). Consuming skills carry generic law + one canonical load
directive ("before any host-dependent step ... load `hosts/<current-host>.md`; no matching
file -> no per-call routing + say so (degraded)") as a single byte-identical physical line
per site. `test-host-references.sh` pins: the 6x6 section loop, directive uniformity at the
six sites, provider-table header + `WOO_MODEL_TIERS_TABLE` marker, and anti-duplication
greps (omp phrases absent from donors). Review's CI path (`prompts/`, `load-prompt.sh`,
`resolve-model.sh`) follows no links and never reads hosts/ — keep it diff-clean. Adding a
host = new `hosts/<host>.md` + review SKILL per-skill row; the test loop picks it up
automatically (see the `lockstep-edit-sites` wisdom).
