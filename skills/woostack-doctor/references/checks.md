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
| `memory-malformed` | memory note missing opening `---` fence | error | report | — |
| `memory-field` | memory note missing `name`/`type` or empty body | error | report | — |
| `memory-type` | memory note has an unknown `type:` | error | report | — |
| `memory-dup` | duplicate memory note `name:` | error | report | — |
| `memory-scope-stale` | `scope:` matches no tracked files | warn | report | — |
| `memory-provenance` | missing `source:`; stale local spec/plan/fix source; or invalid Linear source (valid forms: `linear://project/<uuid>` and `linear://issue/<uuid>`; URI syntax is parsed locally without a provider or adapter) | warn | report | — |
| `memory-scope-trivia` | non-glob `scope:` (possible trivia) | warn | report | — |
| `memory-unresolved-link` | unresolved `[[wikilink]]` in a memory note (kept `warn` to not break consumer CI) | warn | report | — |
| `memory-no-updated` | memory note missing `updated:` (cannot be aged) | warn | report | — |
| `memory-dead` | old + never recalled (prune candidate) | warn | report | — |
| `memory-overlap` | notes with intersecting scope (review for contradiction) | warn | report | — |
| `orphan-worktree` (present) | unregistered dir under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose dir is gone | warn | auto | `<root>` (runs `git worktree prune`) |
| `gitignore-drift` | a shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` (appends missing lines) |
| `config-key` | a required non-secret config key (per the init template) is absent | warn | auto | `<root> <key>` (merges template default) |
| `linear-policy` | backend selector, credential-like key, incomplete repository/workspace/team, or incomplete category/state mapping | error | report | — |
| `legacy-development-records` | active or ambiguous local spec/plan/fix/overnight set requires one-way migration | error | report | — |
| `linear-live` | normalized live receipt is missing, malformed, partial, stale, foreign, read-only, or lacks an exact required capability/read-back | error | report | — |
| `memory-provenance-live` | normalized receipt lacks a complete verified managed identity/relation result for a valid Linear provenance URI, or reports missing/foreign/drifted identity | error | report | — |
| `respond-config` | invalid type, key, bound, or value in the optional `respond` namespace | warn | report | — |
| `respond-credentials` | credential-like key under `respond` | warn | report | — |
| `respond-stale-evidence` | response evidence run directory older than 24 hours | warn | report (manual deletion after failed-run review) | — |

Memory checks are all `report`: memory content repair belongs to
[`woostack-dream`](../../woostack-dream/SKILL.md). Legacy development records are migration input,
not normal document-lint or auto-repair targets.

## Linear-only behavior

Static diagnosis is provider-free. It validates:

- the non-secret `linear` policy shape and rejects backend selectors or credential-like keys;
- knowledge, response, generated-host, Git-ignore, and worktree hygiene; and
- legacy development-record directories as one blocking `legacy-development-records` finding per
  active or ambiguous set, without running document type/status/source/backlink checks.

`--live` is controller-owned. The skill controller discovers the official host MCP tools,
authenticates through the host connection, resolves exactly one workspace/team, validates native
project categories and issue states, and proves the required project, issue, update, comment,
relation, owner, mutation, and independent read-back capabilities. It writes exactly one normalized
non-secret outcome to a mode-0600 temporary file, passes that path to
`doctor.sh --live-receipt <path>`, and deletes it after consumption.

The receipt's top level supplies `ready`, canonical `repository`, resolved `workspace` and `team`,
and the capability booleans consumed by the shell engine. When memory notes contain valid Linear
provenance, the same receipt may contain a `provenance` object keyed by the lowercase canonical
`linear://project/<uuid>` or `linear://issue/<uuid>` URI. Each value is a normalized object with exact `kind`,
lowercase `id`, `repository`, `workspace`, and `team`, plus boolean `verified`,
`managedIdentityVerified`, and `relationsVerified` outcomes. The controller derives these
non-secret outcomes from official host-MCP reads; raw provider responses are not receipt input.
A live note whose canonical URI has no entry, a partial entry, false verification, or mismatched
identity is `memory-provenance-live`.

The shell engine parses URI syntax locally, validates only the normalized receipt, and reports exact
missing capabilities or provenance fields. It never calls a provider or adapter and never reads a
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
