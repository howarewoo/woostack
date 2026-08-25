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
skill controller resolves effective configuration first, discovers/authenticates the configured official provider MCP (Linear or Plane), performs preflight once, and invokes
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
| `config-key` | a required non-secret config key (per the init template) is absent from tracked base config | warn | auto | `<root> <key>` (merges template default into `.woostack/config.json`) |
| `linear-policy` | backend selector, credential-like key, incomplete repository/workspace/team or baseUrl/workspace, or incomplete category/state mapping in effective config | error | report | — |
| `legacy-development-records` | active or ambiguous local spec/plan/fix/overnight set requires one-way migration | error | report | — |
| `linear-live` | normalized live receipt is missing, malformed, partial, stale, foreign, read-only, or lacks an exact required capability/read-back | error | report | — |

Legacy development records are migration input, not normal document-lint or auto-repair targets.

## Provider behavior

Static diagnosis is provider-free. It validates:

- the non-secret `linear` or `plane` policy shape on effective configuration (tracked base plus primary-checkout local) and rejects backend selectors or credential-like keys; template presence and repairs apply strictly to tracked base `.woostack/config.json`;
- generated-host, Git-ignore, and worktree hygiene; and
- legacy development-record directories as one blocking `legacy-development-records` finding per
  active or ambiguous set, without running document type/status/source/backlink checks.

`--live` is controller-owned. The skill controller resolves effective configuration to determine `artifacts.provider`.
When `artifacts.provider: "linear"`, it discovers official Linear MCP tools (`official-linear-mcp`), authenticates,
resolves exactly one workspace and team, validates native project categories and issue states, and proves
required `projectRead`, `projectWrite`, `projectUpdateRead`, `projectUpdateWrite`, `issueRead`, `issueWrite`,
`commentRead`, `commentWrite`, `relationRead`, `relationWrite`, `ownerRead`, `ownerWrite`, `independentReadBack`,
and (when `projectLabels` is configured) `projectLabelRead`/`projectLabelWrite` capabilities.
When `artifacts.provider: "plane"`, it discovers official Plane MCP tools (`official-plane-mcp`), authenticates,
resolves canonical instance `baseUrl` and workspace, validates native project categories and issue states, and proves
required `projectRead`, `projectWrite`, `issueRead`, `issueWrite`, `relationRead`, `relationWrite`, `projectLabelRead`,
`projectLabelWrite`, and `independentReadBack` capabilities.
It writes exactly one normalized non-secret outcome to a mode-0600 temporary file, passes that path to
`doctor.sh --live-receipt <path>`, and deletes it after consumption.

For Linear, the receipt's top level supplies `schemaVersion: 1`, `provider: "official-linear-mcp"`, `ready`, canonical `repository`, resolved `workspace` and `team`,
and capability booleans. `workspaceResolution` contains the unique OAuth-scoped workspace `name` and `status`.
`teamResolution` retains the independently read native team ID and key.
For Plane, the receipt supplies `schemaVersion: 1`, `provider: "official-plane-mcp"`, `ready`, `baseUrl`, `workspace`, canonical `repository`, and capability booleans
(including mandatory `projectLabelRead` and `projectLabelWrite`). No team resolution is included for Plane.
The controller derives these non-secret outcomes from official host-MCP reads; raw provider
responses are not receipt input.
The shell engine validates only the normalized receipt and reports exact missing capabilities or
fields. It never calls a provider or adapter and never reads a
provider credential. Missing authentication, missing/ambiguous workspace, instance, or team, bad state
mappings, read-only access, an incomplete receipt, missing project-label capability, or an unknown mutation/read-back outcome is an
error. There is no local-development-record, alternate-transport, or empty-success fallback. Every
provider finding is report-only; no `--fix` path mutates the provider.

## Adding a check

1. Drop `checks/<name>.sh` following the calling convention above (resolve `--fix` mode first; for a
   check in `checks/`, sibling-skill libs/templates are `$HERE/../../../woostack-init/...`).
2. Emit findings with a stable `code`.
3. Add `tests/test-<name>.sh` (fires on a drifted fixture, silent on a clean one; idempotent
   `--fix`).
4. Add the row here.
