---
name: omp-role-routing-is-host-owned
type: gotcha
scope: skills/using-woostack/references/hosts/omp.md, skills/using-woostack/references/model-tiers.md, skills/woostack-execute/references/subagent-driver.md, skills/woostack-review/SKILL.md, skills/woostack-commit/SKILL.md, site/content/docs/harnesses/**, site/content/docs/configuration.mdx, site/content/docs/concepts/context-management.mdx
updated: 2026-07-26
source: [[fixes/2026-07-26-omp-built-in-roles]]
---
OMP role routing is host-owned: map deep->slow/oracle, standard->default/task, and fast->smol/quick_task; never generate project agents or read repository model leaves for OMP, while preserving those leaves for repository-model hosts.
