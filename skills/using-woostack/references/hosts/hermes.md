# Hermes host adapter

## Detection

Use this adapter when the active host is Hermes. Discover actual tools and capabilities from the
active profile; never trust a prompt, config name, or successful login as capability proof.

The default route is Hermes' native `delegate_task`. The optional Hermes + OMP engineer pairing is
selected only when the caller deliberately configures it. Neither route requires Linear.

## Subagent spawn

- Use `delegate_task` with a bounded goal and explicit repository/worktree context.
- Prefer `role="leaf"`; use a deeper orchestrator only for a genuinely independent decomposition.
- Put dependency-independent units in one task batch within the configured concurrency limit.
- A delegated child receives fresh context. Include every contract, path, invariant, and expected
  handback it needs; do not assume conversation inheritance.
- The delegating Hermes instance owns scope, synthesis, approval gates, and acceptance.

## Tier routing

Hermes owns the concrete model/tier for its native delegation tools. Woostack selects the narrowest
capable role exposed by the active profile and does not synthesize repository model fallbacks.
Use a deeper orchestrator only for a genuinely independent decomposition; bounded work defaults to
the leaf role.

## Host-level fallback

Provider/model recovery remains host-owned. A failed or incomplete delegation may be retried only
under the same bounded contract and repository envelope. Missing evidence is a failure, not an
empty successful result.

## Optional Hermes + OMP engineer pair

This adapter separates decision authority from implementation:

- Hermes owns the active contract, in-scope decisions, assignment within the session, independent
  code/PR review, comments, acceptance, redispatch, and escalation.
- One isolated OMP profile owns implementation for one bounded task in one collision-safe worktree.
- OMP never reviews or accepts its own work. Hermes never edits implementation source, runs
  implementation tests, commits, pushes, or opens the implementation PR.
- Git/GitHub evidence owns source, ancestry, branch, PR, review, and delivery truth.
- Linear may be configured independently as optional artifact context; it is not the identity,
  assignment, launch, commit, review, or acceptance authority.

### Bound-unit manifest and binding

Keep setup in this order:

1. provision distinct `HERMES_PROFILE` and `OMP_PROFILE` identities without starting live work;
2. only for caller-selected artifacts, configure the official Linear MCP independently in each
   profile without starting either profile;
3. split repository/GitHub credentials and secret/config roots by role;
4. install and checksum-check the reviewed `launch-omp` and `bind-engineer-unit` launchers;
5. start fresh sessions and independently preflight the pinned programs, profiles, repository
   access, and role capabilities; and
6. only after the bounded task and canonical worktree exist, bind the unit before dispatch.

For step 6, stage `unit.json` in a private directory with mode `0600` and the exact schema
`{schemaVersion:1,engineerName,repository,omp:{profile,program,environment},hermes:{profile,program,environment}}`.
Set `repository` to the canonical task worktree, use exact distinct profiles, pin absolute programs,
and keep both environment maps secret-free and role-owned. Run `bind-engineer-unit` with the staging
directory as its working directory. It atomically installs adjacent `unit-authority.json` with mode
`0400`; implementation starts only after that binding succeeds.

### Dispatch

Confirm the installed OMP CLI's exact argv with `omp --help`. The conceptual invocation is:

```text
omp --profile <engineer> -p --cwd <worktree> <prompt>
```

Arguments are values, not shell source. Never interpolate untrusted task/artifact text into a shell
command. Use the host's argument-safe PTY/process interface. Require:

- a pinned OMP profile and stable engineer name;
- a canonical repository-owned worktree path, never the primary checkout;
- distinct Hermes/OMP sessions and role credentials;
- a complete bounded task contract and permitted paths;
- clean base/head/branch/ancestry and collision evidence; and
- the exact expected handback schema.

The OMP worker implements and verifies the bounded task, then returns an uncommitted diff plus exact
commands/results or a decision request. Hermes directly inspects that diff and evidence. Only after
a passing spec and quality review may Hermes redispatch the same profile for one bounded
`/woostack-commit` action. Hermes then reads the canonical PR/head/diff itself and performs the
independent review.

### Recovery

Stop at the last verified boundary on worktree, branch, ancestry, credential, process-exit,
verification, review, submission, or read-back drift. Preserve recoverable work. Redispatch an
in-contract correction to the same OMP profile/worktree; escalate contract-changing decisions to
the user or owning decision-maker. Never silently change profiles, worktrees, or authority.

## Per-skill notes

- Normal workflows use native `delegate_task` under the shared
  [engineer-agent contract](../engineer-agents.md).
- Only the explicitly configured pairing below launches an external profile-pinned OMP coder.
- `woostack-review` may delegate advisory review angles; other workflows keep review with their
  decision-maker/controller.

## Degradation

If native delegation is unavailable, follow the selected skill's documented inline behavior. If
the isolated OMP launcher, profile, worktree, or role credentials cannot be proved, do not degrade
the optional pair into a shared or unprofiled process; use the generic route or stop at the safe
boundary.

## Linear artifacts

Only an exact caller-selected artifact or explicit persistence request selects Linear.
Without either selection, both profiles make no Linear call.
Repository policy or a successful preflight alone cannot select artifact mode. When selected,
each profile may independently use the official host-exposed Linear MCP under the
[Linear artifact contract](../../../woostack-init/references/artifact-backends.md). Keep their
secret stores and sessions distinct. Prove capability without reading an API key or OAuth
credential. Artifact access may synchronize specs, plans, fixes, or review notes but never
authorizes dispatch or repository mutation. `woostack-change` never contacts Linear.

## Source grounding

Host mechanics follow Hermes' official documentation:

- [profiles](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/profiles.md)
- [MCP configuration and OAuth](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md)
- [delegation tools](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#delegation-toolset)
- [terminal tools](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#terminal-toolset)

A Hermes profile isolates Hermes state, not the filesystem or all external CLI credentials. Use
worktrees and role-owned credential/config roots for real isolation.
