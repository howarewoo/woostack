# Hermes Agent

## Detection

Use this adapter whenever the current host is Hermes. The default route is Hermes' native
`delegate_task` tool; it does not require omp, an engineer identity, or the paired authority
protocol. Discover the actual tools in the active profile rather than trusting a prompt or config
claim.

Activate the optional **Hermes + omp engineer pair** branch below only when the caller deliberately
selects that adapter and the exact named Hermes decision-maker profile, omp coding profile, separate
identities/environments, official Linear MCP sessions, authority receipts, and worktree all pass
their preflight. The presence of an `omp` executable or profile is not selection. A normal Hermes
session must never inherit the pair's coder command, credential rules, or fail-closed gates, and a
missing omp profile does not degrade the generic Hermes route. For any selected workflow, discover
and test the tools it actually requires; a configured server name, prompt, or successful OAuth page
does not prove that a required tool is available.

These setup claims are grounded in the official Hermes documentation:

- [profiles](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/profiles.md),
  including the warning that a profile isolates Hermes state but is not a filesystem sandbox;
- [MCP configuration and OAuth](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md),
  including the reviewed `linear` catalog entry and `https://mcp.linear.app/mcp`;
- the [built-in delegation reference](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#delegation-toolset),
  which defines `delegate_task` as isolated-context subagent dispatch;
- the [built-in terminal reference](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/tools-reference.md#terminal-toolset);
- the official [`terminal` PTY contract](https://github.com/NousResearch/hermes-agent/blob/main/tools/terminal_tool.py#L934-L944),
  which requires `pty=true` for an interactive CLI such as a coding agent;
- the official foreground [`LocalEnvironment._run_bash` implementation](https://github.com/NousResearch/hermes-agent/blob/main/tools/environments/local.py#L1318-L1375),
  which passes `cmd_string` to `bash -c` and the working directory separately as `Popen(cwd=...)`;
- the official PTY [`ProcessRegistry.spawn_local` implementation](https://github.com/NousResearch/hermes-agent/blob/main/tools/process_registry.py#L685-L780),
  which puts the `command` string inside a login-shell `-c` program while passing `cwd`
  separately to the process API.

## Subagent spawn

### Generic Hermes route (default)

- **Primitive:** `delegate_task`; use `role="leaf"` unless the task genuinely needs another
  bounded decomposition level and the active Hermes configuration proves it supports the
  orchestrator role. A child receives a fresh conversation and terminal session and returns only
  its final summary.
- **Per-call model/effort knob:** none in the model-facing tool. The active profile's
  `delegation` configuration owns the child model/provider and iteration/concurrency limits.
- **Per-call cwd:** none. Put the exact canonical worktree in every goal/context, require the child
  to self-pin before work, and stop on mismatch.
- **Parallel shape:** put dependency-independent units in one `tasks=[...]` batch so Hermes runs
  them concurrently within its configured limit. Do not serialize an inseparable comparison pair;
  split a larger fan-out into intact batches when capacity requires it.

### Optional Hermes + omp engineer-pair route

When and only when the pair branch passed Detection, call Hermes' `terminal` tool with `pty=true`
for the paired coder; never use `delegate_task` as a substitute for that implementation identity.
The pinned omp profile owns model-role resolution, so the dispatch adds no `--model`, changes no
role, and reads no model from repository configuration. Cwd is the required `--cwd <repo>` argv,
not Hermes' implicit cwd. Run one PTY-backed process per dependency-independent engineer unit;
every concurrent process has a different engineer identity, Hermes profile/session, omp
profile/session, Linear principal, run, issue, and worktree.

The only conceptual implementation dispatch for this pair is the command confirmed by
`omp --help`:

```text
omp --profile <engineer> -p --cwd <repo> <prompt>
```

That line specifies **argv semantics**, not shell source: `<engineer>`, `<repo>`, and `<prompt>`
each denote exactly one argument. They must never be pasted, quoted, escaped, expanded, or
concatenated into Hermes' `terminal.command`. Hermes officially passes that command string to a
login shell, so direct interpolation would let issue text become shell syntax even when the
surrounding prose calls it a prompt.

Use this argument-safe PTY launcher contract:

1. **Validate the pins before staging.** Require `<engineer>` to be a case-sensitive ASCII full
   match for `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`, with no NUL or line break, and require it to
   equal both the unit's stable `ENGINEER_NAME` and the already preflighted omp profile. Resolve
   `<repo>` without a shell; require an existing canonical absolute directory whose resolved bytes
   exactly equal the allocated issue worktree recorded in the current authority/Git evidence.
   Reject normalization drift, a repository root or sibling, a missing worktree, and any value that
   cannot be represented as one OS argument.
2. **Preflight the installed launchers.** Resolve
   `${WOO_ENGINEER_LAUNCHER_DIR:-$HOME/.local/libexec/woostack}` with a host path API, not a shell.
   Require a canonical absolute directory owned by the current profile, no symlink traversal, and
   mode `0700`; require `launch-omp` and `launch-hermes-review` to be owned regular no-follow files
   with mode `0500`. Pin their resolved absolute paths before allocation. The launchers are trusted
   installed programs, never copied into a dispatch directory or generated from task data.
3. **Stage data with host file APIs.** A trusted host primitive creates a fresh unpredictable
   dispatch directory outside the repository with exclusive/no-follow creation and mode `0700`.
   It writes exactly four owned regular no-follow files named `profile`, `repo`, `prompt`, and
   `session`, each mode `0600`, with no terminator or encoding wrapper. `session` is empty only for
   the initial coding dispatch; every redispatch contains the pinned OMP coding-session ID.
   File contents are never shell, an environment file, or launcher source. Reject NUL, preserve
   every other prompt byte, and put no credential or token in this directory.
4. **Invoke one static shell program.** The only Hermes call is
   `terminal(command="<resolved-absolute-launcher-dir>/launch-omp", workdir=<host-generated-dispatch-directory>, pty=true)`.
   The fully resolved launcher path is pinned trusted configuration and the `command` value is
   otherwise byte-for-byte static; the unpredictable dispatch directory is supplied only through
   Hermes' separate `workdir` field. The launcher revalidates the owned files, profile, session,
   and canonical worktree, reads the staged values without evaluation, changes cwd through an OS
   API, and calls `os.execvpe` or its host equivalent with argv
   `["omp", "--profile", profile, "-p", "--cwd", repo, "--", prompt]` for the initial dispatch or
   `["omp", "--profile", profile, "--resume", session, "-p", "--cwd", repo, "--", prompt]` for a
   redispatch. The static `--` terminates option parsing so a prompt beginning with `-` remains the
   prompt. No `eval`, dynamically built `sh -c`, sourced data, command substitution, or
   string-to-command step is permitted.
5. **Isolate the child environment.** `omp --profile` relocates omp-native
   auth/session/settings/cache state only; it does not isolate Git, `gh`, Graphite, SSH, or other
   external CLIs that consult inherited process state. The trusted launcher therefore starts from
   an audited minimal allowlist, ignores the invoking controller's HOME/XDG roots, and installs the
   exact profile-owned root at `<launcher-dir>/profiles/<profile>` as `HOME`, with dedicated XDG,
   temp/runtime, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`, SSH-home, and Graphite state below it. It
   scrubs the controller's `GH_TOKEN`, `GITHUB_TOKEN`, `LINEAR_API_KEY`, Git/askpass/config
   injection, SSH agent, Graphite, and other credential variables. Provider and official Linear
   MCP authentication remain owned by the selected OMP profile; no secret is inherited from
   Hermes or read from a repository/temp file.
6. **Preserve PTY, status, evidence, and cleanup.** Direct exec replaces the launcher process, so
   omp inherits the PTY, terminal signals/resizes, stdout/stderr, and real process status without a
   pipeline or wrapper-status translation. The host records that exact result, then removes the
   four staged files and dispatch directory on success, failure, or interruption while preserving
   the original status; it also removes abandoned dispatch directories after a crash. Process
   completion alone is not implementation, verification, review, or acceptance evidence, so
   Hermes still requires the complete stdout/evidence handback.

A prompt containing command substitutions (`$()`), backticks, single or double quotes,
semicolons, embedded newlines, or leading dashes therefore remains one literal prompt argument.
These bytes must reach omp unchanged and must never execute, split arguments, select options, or
alter cleanup. Do not replace the explicit profile with an environment default or alias.

## Tier routing

### Generic Hermes

`delegate_task` exposes no model-facing per-call model or effort selector. Resolve the effective
woostack tier for intent and reporting, then use the active Hermes profile's already configured
delegation model/provider. Where the calling skill requires an exact per-call tier, report the
inherited host choice as degraded; never rewrite Hermes profile configuration, translate repository
model settings into it, or claim an unobserved model match.

### Selected Hermes + omp pair

Hermes is the decision-maker, not a tier-routed coding worker. Pair implementation always enters
the single pinned omp profile above; omp's fixed built-in worker-to-role map remains defined in
[`omp.md`](omp.md). The generic tier and override contract remains in
[`../model-tiers.md`](../model-tiers.md), but Hermes must not translate it into a different profile,
pass a concrete model on the pair command, or silently substitute another omp model role.

Only an explicit user invocation of `/woostack-review` may ask the selected pair branch's
configured independent reviewers to perform review analysis. That exception does not turn the
paired omp implementation profile into a reviewer and does not transfer Hermes' decision,
PR-comment, `reviewResult`, or acceptance authority.

## Host-level fallback

For generic Hermes, provider recovery and credential rotation are host-owned inside the active
profile and its `delegation` configuration. Woostack does not synthesize a repository-model retry
chain. A failed `delegate_task` result is a failed or degraded spawn according to the calling
skill; it is never permission to invoke omp.

For an explicitly selected pair, Hermes recovery stays inside the already pinned decision-maker
profile/session, and omp recovery stays inside its already selected model role. Recovery must not
change `ENGINEER_NAME`, Linear principal, either profile, authority envelope, issue, or role.
A missing Hermes pair profile, unavailable official Linear MCP tool, failed OAuth identity
read-back, unsupported PTY backend, missing omp profile/role, unsafe launcher, or incomplete omp
handback fails closed before the next side effect. The selected pair must not respond by coding
inline, using generic `delegate_task` for the coder, using an unprofiled omp session, changing
identities, using a local/custom Linear transport, or treating a smaller tool surface as success.

## Per-skill notes

- **woostack-execute / woostack-execute-overnight / woostack-sweep (generic Hermes):** dispatch
  dependency-independent leaf units through one `delegate_task(tasks=[...])` batch within host
  capacity. Every context pins and self-checks its worktree; keep dependency and stack order in the
  controller.
- **woostack-commit (generic Hermes):** use one leaf `delegate_task` only for the optional drafting
  handoff. The parent Hermes session retains source-control authority. Because no per-call model
  selector exists, disclose when the configured delegation model cannot prove the requested
  `fast` tier.
- **woostack-review (generic Hermes):** on an explicit invocation, send all active review angles as
  independent leaf tasks in one `delegate_task` batch and keep the skeptical validator separate
  from the initial angles. Review workers are advisory; the parent owns synthesis and any verdict.
- **woostack-eval (generic Hermes):** put each candidate and baseline in two fresh leaf tasks in the
  same batch and keep every comparison pair intact. Both inherit the same configured delegation
  model; `session-default` is provable only when the returned host metadata establishes that match.

- **woostack-review (selected Hermes + omp pair only):** Only an explicit user invocation of
  `/woostack-review` may launch the skill's configured independent reviewer profiles. For each
  active angle, stage the validated reviewer profile, canonical read-only checkout, review
  prompt, and an empty reviewer session as raw mode-`0600` files named `profile`, `repo`,
  `prompt`, and `session`, then invoke
  `terminal(command="<resolved-absolute-launcher-dir>/launch-hermes-review", workdir=<host-generated-review-dispatch-directory>, pty=false)`.
  The preflighted installed launcher changes cwd through an OS API and directly execs argv
  `["hermes", "chat", "-p", reviewer, "-q", review_prompt]`; no reviewer value enters shell
  source. The host captures the real result and cleans the dispatch directory. Each configured
  reviewer profile must satisfy the same profile-name grammar, run as a new process with a fresh
  isolated session, and differ from the paired implementation profile and every other active
  reviewer.

  A reviewer may inherit only benign review/provider environment needed by its configured host:
  scrub the named decision-maker and engineer contexts, official Linear credentials/tokens, and
  implementation Git/GitHub/Graphite write credentials; provision only a reviewer-owned read-only
  source/PR principal when one is required. Reviewers return advisory analysis and a real
  exit/evidence handback only. Hermes independently reads the PR and evidence, posts the verdict
  comment, authors the typed `reviewResult` receipt, and retains every acceptance decision.

### Optional Hermes + omp manual pair setup

Woostack does not generate or doctor these profiles. Set up and audit every pair manually outside
the repository:

1. **Pin the unit.** Record one stable `ENGINEER_NAME`, one Hermes decision-maker profile, one omp
   coding profile named by `<engineer>`, one Linear principal kind/native ID, and the repository and
   authority envelope. A new assignment also gets one run ID and isolated worktree. A concurrent
   unit must use a distinct `ENGINEER_NAME`, Linear principal, Hermes profile/session, omp
   profile/session, authentication context, token/session, run, issue, and worktree. Never clone,
   pool, multiplex, or reuse any of those across active units.
2. **Create a blank Hermes profile.** Follow the official profile guide, for example
   `hermes profile create <hermes-profile>`, rather than cloning another engineer's configuration,
   `.env`, secrets, memory, or sessions. Set `terminal.home_mode: profile` for this adapter because
   its external CLI state must be isolated; Hermes documents that profiles otherwise keep the real
   OS `HOME`. Start a fresh controller session and verify its displayed profile. A Hermes profile
   is not a sandbox,
   so profile naming or `SOUL.md` cannot enforce the repository boundary.
3. **Choose the Linear identity deliberately.** For a long-running autonomous unit, create and
   admin-install a distinct Linear OAuth app for that unit with `actor=app`, `app:assignable`, and
   `app:mentionable`; the type-aware work owner is its native delegate. For a human-operated unit,
   personal OAuth uses `actor=user` and the type-aware owner is the native assignee. See Linear's
   official [OAuth actor documentation](https://linear.app/developers/oauth-2-0-authentication).
   Personal OAuth is not a fallback when an app identity or delegate capability fails, and the same
   personal principal cannot back two concurrently active units.
4. **Connect official Linear MCP twice, without sharing a secret.** Configure only
   `https://mcp.linear.app/mcp` in the selected Hermes profile and the selected omp profile. The two
   profiles in one pair resolve the same unit Linear principal, but each authenticates into its own
   host secret store and owns a separate token cache, OAuth session, environment, and MCP session.
   The principal is shared only by that pair; no token, cache, browser session, credential file, or
   environment is copied between the profiles or reused by another unit. Keep all credentials out
   of repository config, prompts, logs, generated files, and development records.
5. **Split repository credentials and external CLI state by role.** Give Hermes read-only
   repository/source access and a profile-isolated GitHub credential limited to reading PRs/diffs
   and posting review comments or a review verdict. Hermes must have no implementation source-write
   or push credential. Give only the paired omp execution context the implementation
   Git/Graphite/GitHub credentials needed for its exact issue branch, commits, push, and PR.
   Authenticate each credential and read back its native GitHub login and immutable principal ID;
   pin the omp identity as implementation author and the Hermes identity as reviewer, and verify
   both again from the submitted PR/review. If GitHub resolves them to the same actor, Hermes posts
   a `COMMENT` review and must not attempt `APPROVE`.

   Provision the coder context under a dedicated host-owned home/config/credential boundary and
   launch it through the isolated child environment above. `omp --profile` alone is not proof of
   external CLI isolation, and inheriting Hermes' `HOME`, XDG/Git/GitHub/Graphite config, token
   variables, askpass, or SSH agent fails the preflight.
6. **Create the omp profile and install/preflight the launchers manually.** Use `omp --help` as the
   command authority and initialize the isolated `<engineer>` profile outside the repository.
   Resolve the installed `woostack-init` skill directory, then install the reviewed launchers with
   `WOO_ENGINEER_LAUNCHER_DIR=<canonical-absolute-launcher-dir> bash <woostack-init-skill-dir>/scripts/gen-omp-agents.sh`;
   `/woostack-doctor` exposes the same installer as the `omp-agents` repair. With host file APIs,
   create `<launcher-dir>/profiles/<profile>`, its `runtime`, and its `tmp` directory as owned,
   canonical mode-`0700` directories for each OMP and Hermes reviewer profile. Provision that
   root's Git, GitHub, SSH, Graphite, provider, and official MCP contexts with the role's own
   credentials. Then prove the launcher paths/ownership/modes plus the profile, role, Linear
   principal, canonical worktree, Git identity, external CLI home/config paths, and credential
   principal before allocation. A global/default profile, inherited environment or token,
   generated project agent, repository model setting, dispatch-local launcher copy, or
   shell-interpolated wrapper is not a substitute.
7. **Admit work before dispatch.** Load the generic
   [engineer-agent authority protocol](../engineer-agents.md). The freshly resolved project lead or
   standalone dispatcher deliberately assigns the exact issue through its type-aware owner field;
   the engineer never self-claims. Hermes then re-reads the issue, owner, state, project membership,
   native relations, current events, and Git/recovery evidence, completes and reads back
   `assignmentAccepted`, and only then launches omp. Immediately before every redispatch or other
   controller side effect, Hermes re-reads the current issue, owner, state, relations, and
   assignment receipt. The omp brief requires omp to re-read those fields through its separate
   official MCP session immediately before each allowed edit, commit, push, PR, or Linear evidence
   mutation. Any drift stops the pair before that side effect.
8. **Return implementation evidence, then conduct the task review.** The implementation prompt
   carries one issue, one worktree, explicit acceptance criteria and allowed surface, the pinned
   identities/run, current receipt IDs, and one woostack command. It grants no allocation,
   contract, gate, cross-issue, source-control, review, or acceptance authority. Omp implements and
   verifies only that task, then returns the exact diff and verification evidence or an explicit
   decision request. The first successful OMP launch must also return its exact coding-session ID
   as host evidence; Hermes pins it as the unit's coding session and places it in every later
   dispatch's `session` file. By default Hermes reads the current Linear contract, returned
   evidence, and
   worktree source/diff through its own read-only access and performs the task-level spec and
   quality review itself. Only the explicit `/woostack-review` row above may add advisory
   independent reviewer analysis, and the paired omp profile is never a reviewer.
9. **Delegate one bounded source-control boundary after review.** Once the task review is clear,
   Hermes records and independently reads back the canonical `precommitReview` receipt, then
   freshly re-reads the issue, type-aware owner, state, relations, `assignmentAccepted`, worktree,
   branch, parent, expected diff, and head. It stages the already pinned coding-session ID and
   redispatches the paired OMP profile with `--resume <coding-session-id>` plus exactly one
   controller-authorized `/woostack-commit` or equivalent source-control action for that issue
   branch. Omp must independently re-read the same authority fields and receipts immediately
   before acting; if they still match, it alone may commit the already reviewed diff, push, submit
   or update that exact PR. The only Linear mutations in this grant are: append and read back
   `implementationEvidence`; create or refresh and read back the exact native PR relation; and, on
   initial submission only, transition `executing` to `inReview` and read it back. A later PR
   update must remain `inReview` and be read back without another transition. Omp returns those
   native event/relation/state receipts plus commit, remote head, PR, and command-exit evidence.
   Failure consumes the authorization; a retry requires a fresh review receipt, authority
   read-back, and controller grant. No new implementation edit, force-push, restack, merge, another
   branch/PR/issue, other issue/project event or relation, other lifecycle or gate mutation,
   review, `reviewResult`, or acceptance is permitted.
   Hermes then independently reads the submitted PR/head/diff, posts its own review
   comments or verdict, records the required typed review receipt through official MCP, and decides
   acceptance only when it is the freshly verified responsible authority. Omp self-checks are not
   independent review and omp must never accept its own work.

## Degradation

For the generic route, an unavailable or failed `delegate_task` follows the calling skill's normal
inline/degraded rule and is reported honestly. Do not invoke omp, demand engineer-pair receipts, or
fail a normal Hermes session merely because the optional pair is absent.

For a selected pair, stop at the last independently verified boundary if any pinned identity,
profile, credential boundary, official MCP capability, PTY execution, owner,
`assignmentAccepted`, state, relation, worktree, branch/PR, model role, exit status, or evidence
receipt is missing, stale, foreign, shared, ambiguous, or conflicting. Emit the canonical typed
failure, collision, handoff, or decision request only when the current verified authority permits
it, and escalate to the lead or human principal.

Never retry a selected pair without `--profile`, with another profile or model role, with personal
OAuth after an app failure, with shared credentials/sessions, or by letting Hermes implement or the
paired omp profile review or self-accept. No local artifact, custom Linear client, successful
mutation response, chat message, generic Hermes subagent, or silent host fallback can satisfy the
missing pair proof.
