---
name: omp-def-model-pattern-enacts-fallback
type: gotcha
scope: skills/woostack-init/scripts/gen-omp-agents.sh, skills/using-woostack/references/hosts/omp.md, skills/using-woostack/references/model-tiers.md
tags: omp, fallback, retry, agent-defs, model-tiers, config
hook: omp `retry.fallbackChains` is keyed by model ROLE, never model slug — a slug-keyed chain is dead config; per-tier fallback is enacted by a comma-separated selector list on the agent-def `model:` line, which omp auto-installs as that spawn's chain.
updated: 2026-07-10
source: [[plans/2026-07-10-tier-fallback-list]]
---
Two facts from the omp 16.4.1 V1 probe (settings schema + binary):

- **Chains are role-keyed.** `retry.fallbackChains` validation: "must be a mapping of role
  names to selector arrays". A record keyed by a model slug (e.g. `a/prime: [...]`) is
  never consulted — writing one into `<repo>/.omp/config.yml` is a silent no-op. Do not
  design around slug-keyed project chains.
- **The def `model:` line IS the per-tier chain.** An agent-def `model:` accepts a
  comma-separated selector list (`slug` or `slug:thinkingLevel`). At spawn, the first
  auth-usable entry becomes the session model and the remaining entries are installed
  in-memory as `retry.fallbackChains["subagent:<id>"]` — per-spawn, project-scoped (the
  defs are already generated + gitignored), self-reverting, with per-entry effort riding
  the `:level` suffix. `gen-omp-agents.sh` therefore emits `model: "primary,fb:low,fb2"`
  for array tier leaves; no host config file is ever written.

Layer kinship: [[omp-host-fallback-is-host-owned]] (the runtime ladder this feeds).
