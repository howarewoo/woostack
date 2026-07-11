---
name: host-mechanics-live-in-hosts-files
type: convention
scope: skills/using-woostack/references/hosts/**, skills/using-woostack/references/model-tiers.md, skills/woostack-execute/references/subagent-driver.md, skills/woostack-review/SKILL.md, skills/woostack-commit/SKILL.md, skills/woostack-init/SKILL.md, skills/woostack-execute-overnight/SKILL.md, skills/woostack-init/scripts/tests/test-host-references.sh, site/content/docs/harnesses/**, site/content/docs/index.mdx
tags: hosts, dispatch, directive, docs, lockstep
hook: adding a host or editing host mechanics or authored harness docs
source: [[fixes/2026-07-10-document-supported-harnesses]]
updated: 2026-07-10
---

Per-host mechanics (spawn primitive, per-call model/effort knobs, tier-routing class,
host-level fallback posture, degradation) live ONLY in
`skills/using-woostack/references/hosts/<host>.md` — six files, one fixed six-section
contract (README states it). Consuming skills carry generic law + one canonical load
directive ("before any host-dependent step ... load `hosts/<current-host>.md`; no matching
file -> no per-call routing + say so (degraded)") as a single byte-identical physical line
per site. `test-host-references.sh` pins: the section loop, directive uniformity, provider-table
header, `WOO_MODEL_TIERS_TABLE` marker, anti-duplication greps, and the authored Harnesses docs
group derived from every host filename. Review's CI path (`prompts/`, `load-prompt.sh`,
`resolve-model.sh`) follows no links and never reads hosts/ — keep it diff-clean. Adding a host
requires its canonical `hosts/<host>.md`, the review SKILL per-skill row, and an authored harness
page; the filename-derived test prevents the docs navigation and supported-host claims from
silently drifting (see the `lockstep-edit-sites` wisdom).
