# Role preferences and host-owned model selection

`fast | standard | deep` are optional preferences for task shape and verification depth:
`fast` suits mechanical, fully specified work; `standard` suits ordinary implementation; `deep`
suits difficult judgment or skeptical review. They do not specify a provider, model, agent,
permission set, or effort wire value. Choose an agent whose discovered capabilities fit the task;
the harness's configured agent/model and its fallback are the normal inheritance path. No repository
model setting, tier table, or degradation notice is needed to delegate.

For a simple task, weigh delegation and context/verification overhead against doing the work inline.
Do not assume a named model is faster, cheaper, or better from the preference alone.

An **explicit one-run native model or effort choice** is distinct from a role preference. Pass its
exact native field only when the active tool schema exposes it and the host authorizes its use.
If an optional request cannot be applied, report that limitation without claiming the override ran;
ordinary host inheritance is not itself a limitation. If a workflow *requires* an exact model or
effort identity, unsupported override or missing/mismatched host evidence blocks that operation:
inheriting a model cannot prove its identity. Never fabricate agent names, wire fields, or evidence.

Existing `models` values in `.woostack/config.json` and primary-checkout `config.local.json`
remain user-owned data. Configuration loading preserves them with unrelated settings, but Woostack
does not interpret those values as runtime routing or fallback policy. Configure models and recovery
through the native host instead. See [host mechanics](hosts/README.md) for conditional tool shapes.
