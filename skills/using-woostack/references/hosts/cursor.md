# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`. No official Cursor
parameter surface is verified in this collection, so treat its dispatch knobs as unknown until the
active runtime exposes them. Discover authorized native GitHub capabilities exposed through Cursor
Composer / `.cursorrules` MCP configuration; the shared capability and authentication contract lives
in the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation uses the host's own documented form; a `/woostack-*` example
states the logical command only, and no Cursor-specific form is recorded in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active runtime before dispatch. A Composer parallel-subagent dispatch is the documented
shape; no per-call `model`, effort, or `cwd` argument is verified for it.

- **Primitive:** parallel subagent dispatch — submit independent tasks and let the host schedule or
  queue workers.
- **Per-call model/effort knob:** unverified. Pass an explicit one-run native request only if the
  active schema exposes the exact field and the host permits it; otherwise inherit host settings.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent self-pins.

## Model selection

The session-selected model is the normal default; optional
[role preferences](../model-tiers.md) do not change it. No per-call override is verified here.

## Host-level fallback

The host owns recovery. If provider exhaustion surfaces as an error, Woostack does not enact a
repository fallback list; see the [shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, submit one
  delivery-capable parallel-subagent worker with the dispatch-prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract; clamp `effective_cap` to
  host capability and refill as workers complete. Workers run on the host-selected model unless the
  active schema exposes a per-call field. A queue-only runtime runs at concurrency one with a clear
  notice; without delivery-capable subagents, block rather than executing inline.

## Capability limits

Normal session-model inheritance needs no notice. Report an unsupported optional explicit
override; block when an exact model/effort identity is required but unproven. Missing required
delivery, isolation, identity-correlation, review, or recovery capability blocks per
[conditional mechanics](README.md#conditional-mechanics-shared); GitHub operations follow the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
