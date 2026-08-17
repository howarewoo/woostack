# woostack-doctor check catalog

Each check is a script under `../scripts/checks/` that emits findings to
stdout, one per line, tab-delimited: `severity⇥code⇥fixable⇥path⇥message`.

- **severity** — `error` (structural breakage; the orchestrator exits nonzero) or `warn`
  (hygiene/convention; exit stays 0). CI (`--check`) fails only on `error`.
- **fixable** — `auto` (the check ships a `--fix` apply path) or `report` (judgment; surfaced for a
  human, never auto-applied). An `auto` check's `--fix` path may additionally emit `manual` at
  runtime for a single instance it cannot safely repair (e.g. a doc with no frontmatter fence):
  surfaced for a human, never auto-applied.

## Calling convention

Every check is invoked two ways. Resolve the mode **before** deriving any path (`$1` is
overloaded):

- **diagnose:** `bash checks/<name>.sh <WOO_ROOT>` → emits findings.
- **repair:** `bash checks/<name>.sh --fix <WOO_ROOT> <extra-args...>` → applies the fix.

The orchestrator exports `WOOSTACK_DOCTOR_LIVE=0` for ordinary runs. On explicit `--live`, the
skill controller discovers/authenticates official Linear MCP, performs preflight once, and invokes
the engine with `--live-receipt <path>`. The receipt is normalized and non-secret. Static checks
never inspect credentials or invoke HTTP, GraphQL, provider adapters, or hard-coded MCP tools.

## Checks

| code | check | severity | fixable | `--fix` args |
|---|---|---|---|---|
| `orphan-worktree` (present) | unregistered dir under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose dir is gone | warn | auto | `<root>` (runs `git worktree prune`) |
| `gitignore-drift` | a shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` (appends missing lines) |
| `omp-agent` | a managed project OMP role definition is missing, malformed, drifted, or mapped to the wrong host role, or its scoped ignore rule is missing/drifted | warn | auto | `<root>` (reinstalls only the three managed definitions and their scoped ignore rule) |
| `omp-session-name` | a managed project OMP session-naming extension or local settings entry is missing, malformed, drifted, or unsafe, or its scoped ignore rule is missing/drifted | warn | auto | `<root>` (reinstalls only the managed extension, settings entry, and scoped ignore rules) |
| `config-key` | a required non-secret config key (per the init template) is absent | warn | auto | `<root> <key>` (merges template default) |
| `linear-policy` | backend selector, credential-like key, incomplete repository/workspace/team, or incomplete category/state mapping | error | report | — |
| `legacy-development-records` | active or ambiguous local spec/plan/fix/overnight set requires one-way migration | error | report | — |
| `linear-live` | normalized live receipt is missing, malformed, partial, stale, foreign, read-only, or lacks an exact required capability/read-back | error | report | — |

Legacy development records are migration input, not normal document-lint or auto-repair targets.

## Linear-only behavior

Static diagnosis is provider-free. It validates:

- the non-secret `linear` policy shape and rejects backend selectors or credential-like keys;
- generated-host, Git-ignore, and worktree hygiene; and
- legacy development-record directories as one blocking `legacy-development-records` finding per
  active or ambiguous set, without running document type/status/source/backlink checks.

`--live` is controller-owned. The skill controller discovers the official host MCP tools,
authenticates through the host connection, resolves exactly one workspace/team, validates native
project categories and issue states, and proves the required project, issue, update, comment,
relation, owner, mutation, and independent read-back capabilities. It writes exactly one normalized
non-secret outcome to a mode-0600 temporary file, passes that path to
`doctor.sh --live-receipt <path>`, and deletes it after consumption.

The receipt's top level supplies `ready`, canonical `repository`, resolved `workspace` and `team`,
and the capability booleans consumed by the shell engine. `workspaceResolution` contains exactly
the unique OAuth-scoped workspace `name` and `status`; it never invents a native workspace ID when
official MCP omits one. `teamResolution` retains the independently read native team ID and key.
The controller derives these non-secret outcomes from official host-MCP reads; raw provider
responses are not receipt input.

The shell engine validates only the normalized receipt and reports exact missing capabilities or
fields. It never calls a provider or adapter and never reads a
provider credential. Missing authentication, missing/ambiguous workspace or team, bad state
mappings, read-only access, an incomplete receipt, or an unknown mutation/read-back outcome is an
error. There is no local-development-record, alternate-transport, or empty-success fallback. Every
Linear finding is report-only; no `--fix` path mutates Linear.

## Adding a check

1. Drop `checks/<name>.sh` following the calling convention above (resolve `--fix` mode first; for a
   check in `checks/`, sibling-skill libs/templates are `$HERE/../../../woostack-init/...`).
2. Emit findings with a stable `code`.
3. Add `tests/test-<name>.sh` (fires on a drifted fixture, silent on a clean one; idempotent
   `--fix`).
4. Add the row here.
