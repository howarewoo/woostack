# Host references

One file per host, loaded **only when a skill runs under that host**. Consuming skills keep
their generic invariants (law) inline — never-silent degradation, gates, the capability
questions to answer — and reach the per-host mechanics here through one canonical directive:

**Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).

Host files hold *mechanics* (primitive names, knob forms, agent selectors, generator
invocations); consuming skills hold *law*. A mechanics sentence must live in exactly one
host file — never duplicated back into a skill.

## Section contract

Every host file carries these six sections, in order:

1. **Detection** — capability signals that identify the host.
2. **Subagent spawn** — primitive name; per-call `model`/`effort` knob (yes/no + form);
   per-call `cwd` (yes/no); parallel dispatch shape.
3. **Tier routing** — how `fast | standard | deep` resolves on this host, and the config it
   reads. The tier→model table and override precedence live in
   [`../model-tiers.md`](../model-tiers.md) — link, never restate.
4. **Host-level fallback** — what the host itself does on usage-limit/provider errors, and
   the boundary: woostack documents this layer, never manages host config.
5. **Per-skill notes** — host-specific steps consumed by named skills.
6. **Degradation** — the host-specific fallback path when a capability is absent (the
   say-so-on-degrade law itself stays inline in each consuming skill).

Review's CI path never reads these files: CI runners follow no links, so review-orchestration
host content stays self-contained in `skills/woostack-review/prompts/*.md`.
