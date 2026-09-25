# Host references

These known host files are mechanics recipes for hosts that expose the needed capabilities:

- [`claude-code`](claude-code.md)
- [`codex`](codex.md)
- [`cursor`](cursor.md)
- [`antigravity`](antigravity.md)
- [`opencode`](opencode.md)
- [`omp`](omp.md)

File presence and host identity do not prove support or add a routing registry. Before a
host-dependent step, verify from the active host that an authorized mechanism actually provides the
capability and operation shape the consuming skill requires. A known host without those capabilities
still fails; a compatible unlisted host may be used. Do not guess an adapter, construct a path from
host text, or read an arbitrary file. Record capability evidence separately from real execution.

Consuming skills keep their generic invariants (law) inline — never-silent degradation, gates,
and the capability questions to answer. Host files hold *mechanics* (primitive names, knob forms,
agent selectors, generator invocations); consuming skills hold *law*. A mechanics sentence must
live in exactly one host file — never duplicated back into a skill.

## Section contract

Every known host file carries these six sections, in order:

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
