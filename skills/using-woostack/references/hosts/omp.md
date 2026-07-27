# omp (Oh My Pi)

## Detection

The `task` tool exposes an `agent:` selector but no per-call `model`, `tier`, or `effort`
argument. omp ships dispatchable workers and resolves their model roles from omp-owned
configuration. woostack detects the `task` primitive and uses those bundled workers; it does not
expect a project agent definition.

For the Hermes + omp engineer adapter, `omp --help` is also the executable authority. It must
advertise `--profile` as isolated auth/session/settings/cache state, `-p` as print mode, and
`--cwd` as the launch directory, and the installed parser must accept the standard `--`
end-of-options barrier before the positional prompt. A working `task` tool alone does not prove
that the external profile-pinned implementation path is available.

## Subagent spawn

- **Primitive:** `task` tool, one subagent per task; dispatch independent tasks in one `tasks[]`
  call to run them in parallel.
- **Worker selector:** choose the bundled `oracle`, `task`, or `quick_task` worker from the
  effective tier mapping below.
- **Per-call model/effort knob:** none. Worker selection routes through omp's model roles.
- **Per-call cwd:** pass it when the spawn accepts one; always fill the dispatch-prompt worktree
  pin as the portable guard.

The worker names and spawn behavior are defined by omp's published
[Subagents & IRC](https://omp.sh/docs/subagents) contract.

### Optional Hermes-paired implementation process

This branch applies only after the exact Hermes + omp engineer pair is deliberately selected and
passes the preflight in [`hermes.md`](hermes.md); ordinary omp `task` dispatch does not inherit it.
Set up the coding profile manually; no project scaffold owns it. The command confirmed by
`omp --help` remains the conceptual dispatch:

```text
omp --profile <engineer> -p --cwd <repo> <prompt>
```

The placeholders are argv semantics, never raw shell concatenation. `<engineer>` is a
case-sensitive ASCII full match for `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` and exactly equals the
unit's stable `ENGINEER_NAME` and preflighted omp profile. `<repo>` is the existing canonical
absolute issue worktree and must exactly match current authority/Git evidence. `<prompt>` is one
bounded, credential-free argument.

Hermes must not place any of those values in its shell-parsed `terminal.command`. It preflights
the owned mode-`0700` installed launcher directory resolved from
`${WOO_ENGINEER_LAUNCHER_ROOT:-$HOME/.local/libexec/woostack}/<ENGINEER_NAME>` and its regular
no-follow mode-`0500` `launch-omp` file. It then stages the literal raw bytes, without a terminator
or encoding wrapper, as owned regular no-follow mode-`0600` files named exactly `profile`, `repo`,
and `prompt` in a fresh host-generated mode-`0700` dispatch directory. Its only PTY call is
`terminal(command="<resolved-absolute-launcher-dir>/launch-omp", workdir=<host-generated-dispatch-directory>, pty=true)`.
The installed launcher validates those files and directly calls the pinned absolute executable
with `os.execve` and argv
`["omp", "--profile", profile, "-p", "--cwd", repo, "--", prompt]`. Direct exec preserves the real
PTY, signal/resize behavior, exit status, and stdout/evidence handback; the host then removes the
staged files/directory without replacing that status. The `--` option barrier
keeps a leading-dash prompt positional. `$()`, backticks, single and double quotes, semicolons,
embedded newlines, and leading dashes remain literal prompt data; they are never evaluated, split,
or treated as options.

The explicit `--profile` is mandatory even if `OMP_PROFILE`, a shell alias, or a sticky default
exists, but it isolates only omp-native auth/session/settings/cache state. The launcher must also
replace Hermes' inherited external-CLI environment with the coder-owned `HOME`/XDG roots,
`GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`, credential-helper/SSH context, and Graphite state, while
scrubbing controller `GH_TOKEN`, `GITHUB_TOKEN`, `LINEAR_API_KEY`, askpass/config injection, SSH
agent, and other credentials. No secret is staged in the prompt, repository, or temp directory.
This external process pin does not change the built-in `task` worker mapping used by skills already
running inside omp.

Every concurrently active unit must use a distinct engineer name, Linear principal, omp profile,
auth/token context, environment, session, run, issue, and worktree. Within one unit, the Hermes and
omp profiles resolve the same unit Linear principal only through separate host secret stores,
token caches, OAuth/MCP sessions, and environments; they never copy or share a token/session. Use
only host-exposed tools for `https://mcp.linear.app/mcp`, never repository credentials or a custom
Linear transport. A long-running unit uses its distinct `actor=app` OAuth app identity; a
human-operated unit may use personal `actor=user` OAuth, but personal OAuth is not fallback for a
failed app identity and one personal principal cannot back concurrent units.

The paired omp execution environment alone holds the implementation Git/Graphite/GitHub
credentials for its issue branch, commits, push, and PR. Hermes retains read-only source access
plus its separate PR-read and review/comment credential and receives no implementation
source-write or push credential. Preflight and later re-read the native GitHub login and immutable
principal ID for both the omp implementation author and Hermes reviewer; if GitHub resolves both
credentials to the same actor, Hermes may post `COMMENT` but never `APPROVE`. `omp --profile`
alone is not proof that these external CLI credentials are isolated. Follow the complete manual
setup, argument-safe PTY launcher, and bounded source-control authority in
[`hermes.md`](hermes.md).

## Tier routing

**Host-owned role routing.** After the calling skill resolves the effective woostack tier, use
this fixed map:

| Effective tier | omp model role | Built-in worker selector |
|---|---|---|
| `deep -> slow` | `slow` | `agent: oracle` |
| `standard -> default` | `default` | `agent: task` |
| `fast -> smol` | `smol` | `agent: quick_task` |

These are **role-backed built-in workers** shipped by omp. Selecting them is a full,
non-degraded routing capability even though `task` has no model argument. The generic `tier:`
metadata and any skill-level tier override still determine the effective tier; after that,
woostack applies only the fixed role/worker map above.

Do not resolve a model for an omp dispatch, inspect model leaves in `.woostack/config.json`, or
pass a repository model identity through the worker brief. omp alone resolves `slow`, `default`,
and `smol` through its
[Model roles](https://omp.sh/docs/roles) configuration and owns the concrete model, provider,
thinking level, and role overrides.

**Cross-consumer coexistence.** The shared model schema, provider table, and model resolvers remain
available to non-omp hosts and the CI single-session path. omp dispatch bypasses that repository
model layer; this exception does not change another host's resolution or override precedence.

For the paired implementation command, the selected omp profile and expected model role are pinned
before allocation and are immutable for that dispatch. The exact command deliberately omits a
concrete `--model`: provider recovery may change a concrete model only inside the already selected
role, but missing or mismatched role resolution must fail closed rather than select another role,
profile, or repository model.

## Host-level fallback

Fallback is entirely host-owned. omp owns provider and credential selection, credential rotation,
cooldowns, retry policy, and any temporary model fallback behind the selected role. woostack
neither reads nor manages omp model-role, fallback, or credential configuration in user or project
host config, and it never translates repository model settings into an omp retry chain.

Request the mapped built-in worker and let omp perform its own recovery. Do not redispatch an omp
worker by resolving a later repository model entry or by synthesizing another project worker. If
host recovery ends without the receipt required by the calling skill, that skill's existing
receipt or preflight gate fails loudly; review in particular must not turn a missing receipt into
an empty successful angle.

Host recovery never authorizes removing `--profile`, switching profiles, changing the selected
model role, inheriting a global/default credential, or replaying work under a different identity.
Hermes must validate the returned profile/role and real exit/evidence receipt; an unprovable
identity or missing receipt is a stopped dispatch, not a retry with looser isolation.

## Per-skill notes

- **woostack-init (manual engineer setup):** no omp-specific scaffold runs. Do not create,
  regenerate, ignore, validate, or edit project `.omp/agents/*`; locally authored agents remain
  owned by the user. Create each isolated engineer profile and its host-only credentials manually
  under the [`hermes.md`](hermes.md) pair procedure.
- **Hermes-paired authority:** load the generic
  [engineer-agent authority protocol](../engineer-agents.md). The freshly resolved lead or
  standalone dispatcher deliberately assigns the exact type-aware owner before Hermes appends and
  reads back `assignmentAccepted`; omp never self-claims. Before every redispatch or controller
  side effect, Hermes re-reads the issue, owner, state, current assignment receipt, native
  relations, and Git/recovery evidence. The bounded prompt requires omp to re-read the current
  issue, type-aware owner, state, relations, and assignment receipt through its separate official
  MCP session immediately before each allowed edit, commit, push, PR, or Linear evidence mutation.
  Omp receives only its one issue, allowed worktree/surface, acceptance criteria, and run.
  It may not mutate allocation, contracts, dependencies, gates,
  another issue/project, or acceptance. It returns implementation/verification evidence or a
  decision request.
- **Hermes-paired post-review source control:** the implementation dispatch grants no commit,
  push, or PR authority. After Hermes performs the task-level review, writes and reads back the
  canonical `precommitReview` receipt, and freshly verifies the issue, type-aware owner,
  `assignmentAccepted`, state, relations, worktree, branch, parent, expected diff, and head, it may
  authorize exactly one `/woostack-commit` or equivalent source-control action. Omp re-reads the
  same fields/receipts through its separate official MCP session immediately before acting, then
  uses only its coder-owned credentials to commit the reviewed diff, push, and submit or update
  that exact issue PR. Its only Linear mutations are: append and read back
  `implementationEvidence`; create or refresh and read back the exact native PR relation; and, on
  initial submission only, transition `executing` to `inReview` and read it back. A later update
  must remain `inReview` and be read back without another transition. It returns those native
  receipts plus commit, remote-head, PR, and command-exit evidence. Failure consumes the grant;
  retry requires a fresh read-back and authorization. No implementation edit, force-push, restack,
  merge, other branch/PR/issue, other issue/project event or relation, other lifecycle/gate
  mutation, review, `reviewResult`, or acceptance authority is granted.
- **Hermes-paired review:** omp self-checks its implementation but is not the default independent reviewer and must never accept its own work. Hermes independently reads and reviews the PR,
  posts its own review comments/verdict, reconciles typed receipts, and decides acceptance when it
  is the freshly verified responsible authority. Only an explicit `/woostack-review` invocation
  may use that skill's configured independent reviewers; Hermes still owns the PR comment,
  `reviewResult`, and acceptance decision.
- **woostack-commit (fast drafting):** map the drafting spawn's effective `fast` tier to
  `agent: quick_task`. If that worker cannot run, draft inline under the normal commit rule.
- **woostack-review (local swarm only):** resolve each angle's effective tier, then select
  `agent: quick_task` for `fast`, `agent: task` for `standard`, and `agent: oracle` for `deep`;
  the deep validator therefore uses `oracle`. Do not run the repository model resolver for these
  dispatches. The CI single-session path is unchanged. omp owns in-worker recovery; if recovery
  leaves any expected worker without a valid receipt, the existing hard receipt gate aborts the
  run with no project-configured fallback redispatch and no silently thinner review.
- **woostack-eval (comparative dispatch):** map the candidate and baseline's common effective tier
  to the same bundled worker and start both siblings in the same `tasks[]` call. The selector is a
  role pin, not proof of a concrete model. Use omp-provided completion identity to prove both
  actions actually ran with the required identical model and effort; an unprovable identity,
  host fallback divergence, or model/effort divergence fails the mechanics proof. Do not consult
  repository model settings to manufacture that proof. A host mode unable to start both siblings
  in the same batch fails comparative preflight.
- **woostack-execute-overnight (preflight advisory):** rely on omp's configured roles,
  authenticated providers, and host-owned recovery. Advise the user to make that host capacity
  resilient before an unattended run, but do not inspect or mutate omp role, fallback, or
  credential config and do not require a repository model list. Exhausted host recovery halts the
  track through the normal blocker path; the advisory remains a recommendation, not a refusal
  condition.

## Degradation

- Missing `task` support or an unavailable mapped built-in worker is a host capability failure,
  not a reason to generate a project worker. Follow the calling skill's existing behavior:
  review stops at preflight or the receipt gate, commit drafts inline, and execution falls back
  inline only where its driver already permits that degradation.
- A concrete model change performed by omp's own retry policy is host recovery, not failed tier
  routing. Keep the effective tier and selected worker truthful, and preserve any actual model
  identity required by the worker receipt.
- A missing, ambiguous, shared, or mismatched engineer name, profile, principal, secret-store or
  external-CLI environment boundary, owner, `assignmentAccepted`, state, relation, worktree,
  argument-safe launcher, model role, exit status, or evidence receipt stops the paired unit at its
  last verified boundary. Never retry unprofiled, with shell-interpolated issue text, with another
  profile/model role, with personal OAuth after an app failure, by sharing a credential/session, or
  by letting Hermes code or the paired omp profile review/self-accept.
