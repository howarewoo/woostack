# Antigravity CLI (`agy`)

## Detection

The `agy` CLI; reads `AGENTS.md` natively; authenticates via system keyring / Google Sign-In
(no documented non-interactive API-key path, so it cannot run headless in ephemeral CI).
No official Antigravity parameter surface is verified in this collection, so treat its dispatch
knobs as unknown until the active runtime exposes them. Discover authorized native GitHub
capabilities through the Antigravity MCP runtime; the shared capability and authentication contract
lives in the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation uses the host's own documented form; a `/woostack-*` example
states the logical command only, and no Antigravity-specific form is recorded in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active runtime before dispatch. Dynamically orchestrated subagents — one
isolated-context subagent per task, instantiated on demand — are the documented shape; no per-call
`model`, effort, or `cwd` argument is verified for it.

- **Primitive:** dynamically orchestrated subagents — submit independent tasks in a single turn and
  let the host instantiate isolated-context subagents; rely on the isolation pattern for token
  economy.
- **Per-call model/effort knob:** unverified. Pass an explicit one-run native request only if the
  active schema exposes its exact field and the host permits it; otherwise inherit host settings.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent self-pins.

## Model selection

The session-selected model is the normal default; optional
[role preferences](../model-tiers.md) do not select a run model. No per-call override is verified.

## Host-level fallback

The host owns recovery. If provider exhaustion surfaces as an error, Woostack does not enact a
repository fallback list; see the [shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, instantiate one
  delivery-capable isolated-context subagent with the dispatch-prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract. Clamp `effective_cap` to
  host capability, refill as workers complete. A serializing mode runs at concurrency one with
  a clear notice; without delivery-capable subagents, block rather than executing inline.

## Capability limits

Normal session-model inheritance needs no notice. Report an unsupported optional explicit
override; block when exact model/effort identity is required but unproven. Missing required
delivery, isolation, identity-correlation, review, or recovery capability blocks per
[conditional mechanics](README.md#conditional-mechanics-shared); GitHub operations follow the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
