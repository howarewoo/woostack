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

Use this argument-safe PTY launcher and bound-unit contract:

1. **Validate the assignment pins before staging.** Require `<engineer>` to be a
   case-sensitive ASCII full match for `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`, with no NUL
   or line break, and require it to equal both the unit's stable `ENGINEER_NAME` and the
   already preflighted omp profile. Resolve `<repo>` without a shell; require an existing
   canonical absolute directory whose resolved bytes exactly equal the allocated issue worktree
   recorded in the current authority/Git evidence. Reject normalization drift, a repository root
   or sibling, a missing worktree, and any value that cannot be represented as one OS argument.
2. **Use the installed per-unit static programs.** Resolve
   `${WOO_ENGINEER_LAUNCHER_ROOT:-$HOME/.local/libexec/woostack}/<ENGINEER_NAME>` with a
   host path API, not a shell. Require the root and per-unit directories to be canonical, owned by
   the controller account, no-follow, and mode `0700`. Require `launch-omp` and
   `bind-engineer-unit` to be owned regular no-follow files with mode `0500` and the shipped
   checksums. Pin their absolute paths. These are trusted installed programs; they are never
   copied into a dispatch directory or generated from task data.
3. **Bind one accepted unit after its worktree exists.** Only after the canonical
   `assignmentAccepted` read-back and worktree preflight, a trusted controller primitive creates a
   fresh mode-`0700` directory outside the repository and launcher root. It writes one owned
   regular no-follow mode-`0600` file named `unit.json`, with duplicate-free UTF-8 JSON and this
   exact secret-free schema:

   ```json
   {
     "schemaVersion": 1,
     "engineerName": "<ENGINEER_NAME>",
     "repository": "<canonical accepted issue worktree>",
     "omp": {
       "profile": "<exact omp profile>",
       "program": "<pinned absolute omp executable>",
       "environment": { "HOME": "<role-owned directory>", "PATH": "<safe absolute path list>" }
     },
     "hermes": {
       "profile": "<exact Hermes profile>",
       "program": "<pinned absolute Hermes executable>",
       "environment": { "HOME": "<role-owned directory>", "PATH": "<safe absolute path list>" }
     }
   }
   ```

   The binder requires exact `schemaVersion` 1 and rejects every unknown top-level or role field.

   `engineerName`, `omp.profile`, and `hermes.profile` use the fixed profile grammar;
   `omp.profile` equals `engineerName`, while the Hermes and omp profiles differ. `repository`
   equals the accepted canonical worktree. Each `program` is an existing canonical absolute
   no-follow regular executable, owned by root or the controller user and not group- or
   other-writable. Each environment uses only the documented role-specific, secret-free
   `HOME`/XDG/tool roots, config files or omp SSH socket, safe `PATH` components, and optional
   locale, terminal, color, or SSL values. Empty, relative, symlinked, repository-owned,
   group/other-writable, wrong-owner, duplicate, arbitrary, `TOKEN`, `SECRET`, or `PASSWORD`
   fields fail closed.

   Invoke only
   `terminal(command="<resolved-absolute-launcher-dir>/bind-engineer-unit", workdir=<host-generated-bind-directory>, pty=false)`.
   The static binder reads `unit.json` through no-follow ownership/mode and before/open/after
   identity checks, validates every exact pin, and atomically installs canonical JSON as the
   adjacent `unit-authority.json`, owned by the controller and mode `0400`. A missing, malformed,
   changed, symlinked, wrongly owned, wrongly mode-set, secret-bearing, or mismatched manifest or
   authority blocks launch.
4. **Stage each launch as data.** A trusted host primitive creates a fresh unpredictable dispatch
   directory outside the repository and launcher root with exclusive/no-follow creation and mode
   `0700`. It writes exactly three owned regular no-follow files named `profile`, `repo`, and
   `prompt`, each mode `0600` and containing validated raw bytes with no terminator or encoding
   wrapper. File contents are never shell, an environment file, or launcher source. Reject NUL,
   preserve every other prompt byte, and put no credential or token in this directory.
5. **Invoke one static launcher.** The only paired-coder call is
   `terminal(command="<resolved-absolute-launcher-dir>/launch-omp", workdir=<host-generated-dispatch-directory>, pty=true)`.
   The fully resolved launcher path is pinned trusted configuration and the `command` value is
   otherwise byte-for-byte static; the unpredictable dispatch directory is supplied only through
   Hermes' separate `workdir` field. The launcher revalidates itself, the adjacent authority, and
   the staged files without following links or accepting changed files. It reads the staged values
   without evaluation, requires `profile` and `repo` bytes to match the authority exactly, changes
   cwd through an OS API, and
   calls `os.execve` on the authority's pinned absolute executable with conceptual argv
   `["omp", "--profile", profile, "-p", "--cwd", repo, "--", prompt]`. The static `--`
   terminates option parsing so a prompt beginning with `-` remains the prompt. No bare executable
   lookup, `eval`, dynamically built `sh -c`, sourced data, command substitution, or
   string-to-command step is permitted.
6. **Build the child environment from authority, never controller state.** `omp --profile`
   relocates omp-native auth/session/settings/cache state only; it does not isolate Git, `gh`,
   Graphite, SSH, or other external CLIs. The authority therefore pins the coder-owned `HOME`,
   `OMP_HOME`/`OMP_CONFIG_HOME`, XDG roots such as `XDG_CONFIG_HOME`, `PATH`, `GH_CONFIG_DIR`,
   `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`, and optional role-owned `SSH_AUTH_SOCK`. The Hermes
   role separately pins `HOME`, `HERMES_HOME`/`HERMES_CONFIG_HOME`, XDG/PATH, and reviewer GitHub
   and Git config roots, without an SSH socket. The launcher starts from those pins and may add
   only harmless locale, terminal, color, and SSL metadata inherited from the controller when the
   authority did not pin it.

   It never inherits the controller's `HOME`, `HERMES_HOME`, `OMP_HOME`, XDG variables, `PATH`,
   `GH_TOKEN`, `GITHUB_TOKEN`, `LINEAR_API_KEY`, `LINEAR_ACCESS_TOKEN`,
   `LINEAR_OAUTH_TOKEN`, `WOO_HERMES_LINEAR_APP_ACCESS_TOKEN`,
   `WOO_OMP_LINEAR_APP_ACCESS_TOKEN`, Git/askpass/config injection, SSH agent, credential-helper/SSH
   context, Graphite state, or any other credential variable. Provider, GitHub, and official
   Linear MCP authentication are loaded only by the pinned program from its role-owned host secret
   boundary. No secret is staged, inherited from Hermes, or stored in `unit.json`,
   `unit-authority.json`, a repository, prompt, or log.
7. **Preserve PTY, status, evidence, and cleanup.** Direct exec replaces the launcher process, so
   omp inherits the PTY, terminal signals/resizes, stdout/stderr, and real process status without a
   pipeline or wrapper-status translation. The host records that exact result, then removes the
   three staged files and dispatch directory on success, failure, or interruption while preserving
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

- **woostack-review (selected Hermes + omp pair only):** An explicit user invocation of
  `/woostack-review` uses only that skill's host-native independent-reviewer dispatch and receipt
  manifest. Never launch review through the pair's unit authority or reuse its Hermes
  decision-maker profile, paired omp implementation profile, either session, either principal, or
  either credential context. Every reviewer must use a separately configured profile and fresh
  isolated session that the controller proves differs from both engineer roles before accepting
  its advisory receipt.

  The reviewer receives no engineer principal credential/token, coding session, implementation
  Git/GitHub/Graphite write credentials, or SSH agent. The review skill's read-only repository
  boundary and before/after mutation checks still apply. If the active Hermes host cannot prove
  the independent profile, session, principal, credential context, and read-only boundary,
  delegated review is unavailable and `/woostack-review` fails closed. Hermes independently reads
  valid advisory findings, posts the verdict comment, authors the typed `reviewResult` receipt,
  and retains every acceptance decision.

## Ordered operator setup and decision-maker prompt

This is an optional adapter for the generic [engineer-agent authority protocol](../engineer-agents.md),
not a default requirement for Hermes or omp. Complete these steps in order for each selected unit.
The detailed profile, launcher, credential, and source-control boundaries below remain mandatory;
this checklist does not replace them.

1. **Create both named profiles without live admission.** Install Hermes through its official
   installer, create a blank decision-maker profile, and configure its profile-scoped home:

   ```bash
   curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
   hermes profile create <hermes-profile>
   hermes -p <hermes-profile> config set terminal.home_mode profile
   ```

   Initialize the isolated `<ENGINEER_NAME>` omp profile outside the repository and configure its
   intended model role. Pin the two names to one unit, but do not start a live MCP session, claim
   identity proof, allocate an issue, or create a worktree yet. A profile isolates native state,
   not the filesystem.
2. **Create one Linear identity and prepare bounded credentials.** A long-running autonomous unit
   requires its own admin-installed OAuth app with `actor=app`, `app:assignable`, and
   `app:mentionable`; its type-aware issue owner is the native delegate. Enable the app's
   `client_credentials` grant and request the complete required scope set. Keep the client secret
   only in the operator-held client secret store. Never give it to either profile.
   Follow Linear's official
   [OAuth 2.0 authentication guide](https://linear.app/developers/oauth-2-0-authentication) for
   client-credentials issuance and expiry behavior.

   Exchange them with `grant_type=client_credentials` twice to mint two separate access tokens—one for Hermes and one for
   omp—with identical required scopes. Linear app access tokens expire after 30 days and have no
   refresh token. Before expiry, or immediately after suspected exposure, the operator must rotate
   both tokens in one bounded maintenance window, update the two separate profile secret stores,
   retire the old tokens, start fresh sessions, and repeat the complete live identity/capability
   preflight before redispatch. A human-operated unit may instead use personal `actor=user` OAuth
   and is the native assignee. Personal OAuth is not a fallback for app failure. Concurrent units
   never share an app, profile, token, session, run, issue, or worktree.
3. **Configure official Linear MCP in both profiles without treating configuration as proof.**
   Configure only `https://mcp.linear.app/mcp`. For `actor=user`, install/configure the reviewed
   Hermes catalog entry now, but defer interactive `mcp login linear` and identity read-back until
   the live preflight:

   ```bash
   hermes -p <hermes-profile> mcp install linear
   hermes -p <hermes-profile> mcp configure linear
   ```

   Configure the same endpoint independently in the selected omp profile. For `actor=app`, store
   the Hermes access token only as `WOO_HERMES_LINEAR_APP_ACCESS_TOKEN` in that profile's native
   secret `.env`; Hermes resolves `${ENV_VAR}` in HTTP headers from its profile environment:

   ```yaml
   mcp_servers:
     linear:
       url: "https://mcp.linear.app/mcp"
       headers:
         Authorization: "Bearer ${WOO_HERMES_LINEAR_APP_ACCESS_TOKEN}"
   ```

   Store the other access token only as `WOO_OMP_LINEAR_APP_ACCESS_TOKEN` in the omp
   profile-owned secret environment. Put only this non-secret definition in the named profile's
   user-scope `agent/mcp.json`:

   ```json
   {
     "mcpServers": {
       "linear": {
         "type": "http",
         "url": "https://mcp.linear.app/mcp",
         "headers": {
           "Authorization": "Bearer ${WOO_OMP_LINEAR_APP_ACCESS_TOKEN}"
         }
       }
     }
   }
   ```

   Never put this definition in project `.omp/mcp.json`, expose a token or client secret in JSON,
   a repository, prompt, log, generated file, or Linear record, or reuse one profile's token in the
   other. Configuration, a server label, and a successful OAuth page are not live admission.
   Do not start either profile or perform any live identity/capability read-back in this step.
4. **Prepare distinct repository principals and environment pins.** Give Hermes read-only source
   access and a separate GitHub principal limited to reading PRs/diffs and posting review comments
   or a verdict. Give only omp the implementation Git/Graphite/GitHub credentials for its eventual
   exact issue branch. Provision separate role-owned `HOME`, tool/XDG/config roots and safe
   `PATH`; resolve canonical absolute no-follow `omp` and `hermes` executables. Do not put secrets
   into the pins. Live GitHub actor and capability read-back remains deferred.
5. **Install and check the two static launchers.**

   ```bash
   pnpx skills add howarewoo/woostack
   ```

   From a trusted, already-installed woostack copy on the controller host, set the exact
   `ENGINEER_NAME` and run `skills/woostack-init/scripts/gen-omp-agents.sh`. When present, the
   installer validates the trusted `/usr/bin/python3` system shim and embeds the actual canonical
   interpreter reported by that process. When the shim is unavailable, the operator must set
   `WOO_ENGINEER_PYTHON` to a pinned absolute Python executable; that explicit value must exactly
   equal the running canonical interpreter and must be a no-follow regular file owned by root or
   the controller user and not group- or other-writable. Repository data and controller `PATH`
   never select that interpreter. Alternatively run `/woostack-doctor` from the trusted copy and
   explicitly approve `omp-agents` repair. Neither a project checkout
   nor issue text may select the installer source. The installer creates
   `${WOO_ENGINEER_LAUNCHER_ROOT:-$HOME/.local/libexec/woostack}/<ENGINEER_NAME>` and installs
   `launch-omp` and `bind-engineer-unit`. Run the trusted
   `skills/woostack-doctor/scripts/checks/omp-agents.sh` with that `ENGINEER_NAME`; require
   canonical no-follow ownership, mode-`0700` root/unit directories, mode-`0500` files, and clean
   shipped checksums. Project `/woostack-init`, including init from the coder home, does not
   install these host launchers.
6. **Only after the static launcher check passes, perform live identity/capability preflight.**
   Start fresh sessions in both named profiles. For personal OAuth, perform each profile's
   interactive login now. Discover the host-exposed tool set rather than requiring hard-coded MCP
   tool names. Independently read back the configured workspace/team, exact `actor`, identical
   required scopes, immutable native principal ID, and every required official-MCP capability:
   issue/project reads and writes, project updates and issue comments, native status/state and
   relations, assignee/delegate ownership, PR relations/evidence, and an independent read after
   each mutation. Both app sessions report `actor=app` and the same unit app ID; both personal
   sessions report `actor=user` and the same human ID.

   Also prove Hermes' PR-read/review-comment access, omp's exact profile/model role, both native
   GitHub actors, the installed launcher paths/modes/checksums, and isolated external-CLI
   boundaries. Equal GitHub actors permit only a `COMMENT` review and must not attempt `APPROVE`.
   This preflight allocates no issue and creates, resolves, or preflights no issue worktree.
7. **Paste and bind the decision-maker prompt below.** Replace every placeholder. Exactly one
   authority form is concrete: `PROJECT_ID` for a managed project or
   `STANDALONE_DISPATCHER_ENVELOPE` for one projectless issue.

   ```text
   ENGINEER_NAME=<ENGINEER_NAME>
   PROJECT_ID=<PROJECT_ID or NONE_FOR_STANDALONE>
   STANDALONE_DISPATCHER_ENVELOPE=<STANDALONE_DISPATCHER_ENVELOPE or NONE_FOR_PROJECT>
   REPOSITORY_PATH=<REPOSITORY_PATH>
   LINEAR_TEAM=<LINEAR_TEAM>
   OMP_PROFILE=<OMP_PROFILE>
   HUMAN_PRINCIPAL=<HUMAN_PRINCIPAL>

   You are the decision-making engineer for this exact authority envelope. Bind the named
   engineer, Linear principal, Hermes profile/session, isolated OMP profile/session, repository,
   team, human principal, and either the project ID or standalone dispatcher envelope before
   doing anything. Use only official Linear MCP at https://mcp.linear.app/mcp. Discover the
   actual host-exposed tool names and preflight every capability required by the selected
   woostack workflow. Follow the canonical engineer-agent, managed-event, and lifecycle
   references for exact payloads, relations, receipts, and state order; do not invent a parallel
   schema or local development record.

   You are the decision-making engineer. Do not edit source, run implementation/tests, commit,
   push, or open implementation PRs. Never use a generator, fixer, subagent, or your own coding
   ability to substitute for the isolated coder. Never self-claim work. Admit only an issue
   deliberately assigned by the pinned project lead or verified standalone dispatcher: an app
   engineer must match the native delegate, while a human engineer must match the native
   assignee. Independently read back ownership, state, relations, and the canonical
   assignmentAccepted receipt. Only after that read-back may you create or resolve the one
   canonical issue worktree and preflight its branch, parent, head, recovery evidence, and exact
   path.

   Delegate repository implementation and verification to the same isolated OMP coding profile,
   one accepted Linear issue at a time. The first bounded brief pins this engineer identity,
   authority, canonical worktree, team, OMP profile, human principal, exact issue and run, current
   receipt IDs, acceptance criteria, and allowed surface. It is the bounded paired-coder
   implementation task defined by `skills/woostack-execute/prompts/implementer.md` and the
   engineer-pair branch of `skills/woostack-execute/references/subagent-driver.md`, not an invented
   public `/woostack-*` command. Dispatch only through the preflighted argument-safe PTY launcher
   whose conceptual argv is:
   omp --profile <engineer> -p --cwd <repo> <prompt>
   Never interpolate profile, repository, issue, or prompt data into shell source. This first
   grant permits implementation and verification only: OMP returns the exact uncommitted diff,
   command exits, verification results, and official-MCP read-backs or a decision request. It may
   not allocate work, change a contract, relation or gate, commit, push, open or update a PR,
   review, accept itself, or claim terminal success.

   Directly inspect the uncommitted worktree diff and source through your own read-only context.
   Perform the task specification and quality review yourself. If it passes, author and
   independently read back the canonical verification and precommitReview receipts. Freshly
   re-read the issue, type-aware owner, state, relations, assignmentAccepted, worktree, branch,
   parent, expected diff, head, and both GitHub actors. Only while those facts still agree,
   redispatch the same OMP profile for the same issue and worktree with exactly one bounded
   /woostack-commit action. That grant permits no implementation edit or other command.

   Read back the coder's implementationEvidence receipt, exact native PR relation, and initial
   inReview state transition, plus its commit, remote-head, PR, and command-exit evidence. Only
   then independently read the submitted PR head and diff, post your own GitHub review comments
   or verdict, author and read back the canonical review receipt, and decide acceptance or a
   bounded same-issue correction. Do not ask OMP to review its own work. Only an explicit human
   invocation of /woostack-review permits configured independent reviewer profiles to provide
   advisory analysis; even then, validate their isolated receipts, post the review yourself, and
   remain acceptance authority.

   Stop at the last verified boundary when identity, ownership, assignment, MCP capability,
   relation, worktree, Git/PR actor, exit status, verification, precommit review, submission,
   independent PR review, or read-back evidence is missing, stale, shared, foreign, ambiguous, or
   conflicting. Do not change profiles or identities, fall back to another transport or local
   artifact, infer approval from silence, or continue after an incomplete mutation. Redispatch an
   in-contract fix to the same OMP profile; hand contract-changing or cross-issue decisions to the
   lead or standalone dispatcher; use the canonical typed handoff for transfer; and escalate
   anything outside the envelope to HUMAN_PRINCIPAL.
   ```

   The linked generic protocol,
   [managed-resource/event authority](../../../woostack-init/references/artifact-backends.md#versioned-managed-metadata),
   and [issue lifecycle](../../../woostack-status/references/conventions.md#issue-state-and-events)
   own exact schemas and receipt order; the prompt does not duplicate them.
8. **Assign and accept exactly one issue.** The lead or standalone dispatcher deliberately assigns
   the type-aware owner; Hermes independently reads the issue, owner, state, project membership,
   relations, current receipts, and Git recovery evidence, then authors and reads back
   `assignmentAccepted`. One unit admits at most one active issue.
9. **Create or resolve and preflight the canonical issue worktree.** Only after the
   `assignmentAccepted` read-back, create or resolve the one worktree recorded for that issue.
   Prove its canonical absolute path under `REPOSITORY_PATH`, branch, expected parent and head,
   clean recovery state, and exact match with current authority/Git evidence. Stop on a repository
   root, sibling, stale branch, or mismatched worktree.
10. **Bind the accepted unit.** Only now stage the exact `unit.json` pins and invoke the installed
    `bind-engineer-unit`. Independently require the adjacent `unit-authority.json` to be a canonical
    owned no-follow mode-`0400` file with the exact engineer, distinct profiles, worktree, programs,
    and role environments. Remove the bind staging directory. Any drift requires a new trusted
    bind after a fresh assignment/worktree read-back; the launchers accept no unbound substitution.
11. **Implement and verify without source-control submission.** Dispatch the same pinned omp
    profile through the installed static launcher with the exact conceptual command
    `omp --profile <engineer> -p --cwd <repo> <prompt>`. The first grant is the bounded paired-coder
    implementation task from `skills/woostack-execute/prompts/implementer.md` under
    `skills/woostack-execute/references/subagent-driver.md`; it carries one issue and one worktree
    and grants no commit/push/PR/review/acceptance authority. Omp returns an uncommitted diff and
    verification evidence or an explicit decision request.
12. **Review uncommitted work and authorize one source-control action.** Hermes directly performs
    the task specification and quality review, authors and reads back canonical verification and
    `precommitReview`, and freshly rechecks authority, worktree, diff, branch, parent, head, and
    actors. It may then redispatch the same omp profile with exactly one bounded
    `/woostack-commit` action. Omp may commit only the reviewed diff and must return independently
    read-back `implementationEvidence`, the exact native PR relation, and the initial `inReview`
    state transition plus commit, remote-head, PR, and exit evidence.
13. **Review the submitted PR, then accept, correct, hand off, or escalate.** Only after the
    submission read-backs does Hermes independently read the PR head/diff, post its own review
    comments or verdict, and author/read back the canonical review receipt. It retains review and
    issue-acceptance authority; the paired omp profile never reviews or accepts its own work.
    Project-final acceptance remains with the pinned lead. Otherwise Hermes redispatches a bounded
    same-issue correction to the same profile, performs the canonical typed handoff, asks the
    lead/dispatcher for a contract decision, or escalates outside-envelope questions to
    `HUMAN_PRINCIPAL`.

### Detailed profile, launcher, and source-control boundaries

Woostack does not generate or doctor these profiles. Set up and audit every pair manually outside
the repository:

1. **Pin the unit.** Record one stable `ENGINEER_NAME`, one Hermes decision-maker profile, one omp
   coding profile named by `<engineer>`, one Linear principal kind/native ID, and the repository and
   authority envelope. A concurrent unit must use a distinct `ENGINEER_NAME`, Linear principal,
   Hermes profile/session, omp profile/session, authentication context, token/session, run, issue,
   worktree, and per-unit launcher directory. Never clone, pool, multiplex, or reuse those across
   active units.
2. **Create blank profiles without admitting work.** Follow the official Hermes profile guide,
   use `hermes profile create <hermes-profile>`, and set `terminal.home_mode: profile`. Do not clone
   another engineer's configuration, `.env`, secrets, memory, or sessions. Initialize the exact
   omp profile and role outside the repository. Profile naming and `SOUL.md` are not sandboxes, and
   configuration is not identity or capability proof.
3. **Choose and configure the Linear identity deliberately.** For an autonomous unit, create and
   admin-install its distinct app with `actor=app`, `app:assignable`, `app:mentionable`, enabled
   `client_credentials`, and the complete required scopes; the native delegate is its owner.
   Keep the client secret in an operator-held store and mint two separate 30-day, no-refresh access
   tokens with identical required scopes. For a human-operated unit, personal OAuth uses
   `actor=user` and the native assignee. Personal OAuth is not a fallback after app failure.
4. **Configure official Linear MCP twice without sharing a secret.** Configure only
   `https://mcp.linear.app/mcp` in the named Hermes and omp profiles. Use catalog/login only for
   `actor=user`; for `actor=app`, use separate bearer references in each profile's native secret
   environment and only non-secret `${ENV_VAR}` references in config. Never use project
   `.omp/mcp.json`. The profiles resolve the same unit principal but own separate tokens, separate
   host secret stores, environments, and MCP sessions; they never copy or share a token/session.
   Keep credentials out of repository config, prompts, logs, generated files, and development
   records.
5. **Split repository credentials and external CLI state by role.** Give Hermes read-only
   repository/source access and a profile-isolated GitHub credential limited to reading PRs/diffs
   and posting review comments or a verdict. Hermes has no implementation source-write or push
   credential. Give only omp the implementation Git/Graphite/GitHub credentials needed for its
   exact issue branch, commits, push, and PR. Prepare distinct role-owned `HOME`, XDG/tool/config
   roots and safe `PATH`, plus canonical pinned executables. `omp --profile` alone is not proof of
   external CLI isolation, and inheriting controller `HOME`, `HERMES_HOME`, `OMP_HOME`, XDG,
   Git/GitHub/Graphite config, `PATH`, token variables, askpass, or SSH agent fails preflight.
6. **Install and check static launchers before live preflight.** From a pinned trusted woostack
   copy, run `skills/woostack-init/scripts/gen-omp-agents.sh` with the exact `ENGINEER_NAME`, or
   explicitly approve the trusted doctor repair. The installer validates the trusted system
   Python shim and embeds its resolved canonical interpreter. If the shim is unavailable, set
   `WOO_ENGINEER_PYTHON` to that same reviewed absolute interpreter for install and doctor; exact
   identity is mandatory, and controller `PATH` or repository data never selects it. Install the
   two mode-`0500` programs only
   under the controller-owned mode-`0700` per-unit directory. Run the doctor check and prove
   root/unit
   ownership, no-follow paths, and shipped checksums. Project `/woostack-init` never installs them.
7. **Perform live profile, identity, and capability preflight.** Only after the static launcher
   check passes, start fresh sessions and authenticate each profile independently. Discover actual
   host-exposed official MCP tools rather than hard-coding runtime tool names. Read back actor,
   identical required scopes/capabilities, workspace/team, immutable Linear native ID, omp role,
   and every workflow capability. Authenticate both GitHub credentials and read back each native
   GitHub login and immutable principal ID. Pin the omp identity as implementation author and the
   Hermes identity as reviewer. If both reads resolve to the same actor, Hermes uses a `COMMENT`
   review and must not attempt `APPROVE`. Do not allocate an issue or create a worktree yet.
   Rotation of app tokens requires two new tokens, fresh sessions, and this complete preflight
   again before use.
8. **Admit work, then establish the issue worktree.** Load the generic
   [engineer-agent authority protocol](../engineer-agents.md). The freshly resolved project lead or
   standalone dispatcher deliberately assigns the exact issue through its type-aware owner field;
   the engineer never self-claims. Hermes re-reads the issue, owner, state, project membership,
   native relations, current events, and Git/recovery evidence, completes and reads back
   `assignmentAccepted`, and only then creates or resolves and preflights the one canonical issue
   worktree. It proves the exact path, branch, parent, head, and recovery evidence.
9. **Bind that accepted worktree to the static launchers.** The trusted controller writes the exact
   secret-free `unit.json` in a fresh owned no-follow mode-`0700` staging directory and invokes
   `bind-engineer-unit` as the one static command. The binder validates every profile, program,
   repository, environment, owner, mode, path and before/open/after file identity, then atomically
   installs adjacent mode-`0400` `unit-authority.json`. The launchers require exact authority
   equality for the staged profile and repo. Unbound, missing, stale, malformed, changed,
   secret-bearing, symlinked, wrong-owner, wrong-mode, same-profile, unsafe-program, or unsafe-PATH
   state blocks before executable dispatch.
10. **Return implementation evidence, then conduct the task review.** Immediately before every
    redispatch or other controller side effect, Hermes re-reads the current issue, owner, state,
    relations, assignment receipt, and relevant Git facts. The first implementation prompt is the
    bounded paired-coder task from `skills/woostack-execute/prompts/implementer.md`, governed by
    `skills/woostack-execute/references/subagent-driver.md`. It carries one issue, one worktree,
    explicit acceptance criteria and allowed surface, pinned identities/run, and current receipt
    IDs. It grants no allocation, contract, gate, cross-issue, source-control, review, or acceptance
    authority. The omp brief requires omp to re-read those fields through its separate official
    MCP session immediately before each allowed edit, commit, push, PR, or Linear evidence mutation.
    Omp implements and self-checks only that task,
    returns the exact uncommitted diff, command exits, and verification evidence or a decision
    request. Hermes reads the current Linear contract and worktree through read-only access and
    directly performs the task-level specification and quality review. Only explicit
    `/woostack-review` may add advisory analysis; the paired omp profile is not the default
    independent reviewer and must never accept its own work.
11. **Delegate one bounded source-control boundary after review.** Hermes authors and independently
    reads back canonical verification and `precommitReview`, then freshly rechecks issue,
    type-aware owner, state, relations, `assignmentAccepted`, worktree, branch, parent, expected
    diff, head, and GitHub actors. It redispatches the same paired omp profile with exactly one
    bounded `/woostack-commit` action. Omp independently re-reads the same fields and, only if they
    agree, uses only its coder-owned credentials to commit the already reviewed diff, push, and
    submit or update that exact PR. Its only Linear mutations are to append and read back
    `implementationEvidence`, create or refresh and read back the exact native PR relation, and,
    on initial submission, transition `executing` to `inReview` and read it back. A later update
    must remain `inReview`. Failure consumes the grant. No implementation edit, force-push,
    restack, merge, other branch/PR/issue, other issue/project event or relation, other lifecycle
    or gate mutation, review, `reviewResult`, or acceptance is permitted; retry requires fresh
    review and authority.
12. **Review the submitted PR independently.** Only after all submission read-backs does Hermes
    independently read and review the PR head/diff, post its own comments or verdict, and author
    and read back the typed review receipt. Hermes decides acceptance only when freshly verified as
    responsible authority; project-final acceptance remains with the pinned lead. Omp self-checks
    are not independent review.

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
