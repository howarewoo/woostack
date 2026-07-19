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

The orchestrator exports `WOOSTACK_DOCTOR_LIVE=0` for ordinary runs and `1` only for an explicit
`--live`. For a Linear live run it performs authenticated preflight exactly once before invoking
checks and exports `WOOSTACK_DOCTOR_LIVE_CONTEXT`, the path to a temporary non-secret normalized
receipt. Live-aware checks consume that receipt and must never repeat preflight. Static backend
checks resolve configuration without credentials; no check may inspect `LINEAR_API_KEY` or invoke
networked adapter commands when live mode is `0`.

## Checks

| code | check | severity | fixable | `--fix` args |
|---|---|---|---|---|
| `memory-malformed` | memory note missing opening `---` fence | error | report | — |
| `memory-field` | memory note missing `name`/`type` or empty body | error | report | — |
| `memory-type` | memory note has an unknown `type:` | error | report | — |
| `memory-dup` | duplicate memory note `name:` | error | report | — |
| `memory-scope-stale` | `scope:` matches no tracked files | warn | report | — |
| `memory-provenance` | missing `source:`; stale local spec/plan/fix source; or malformed `linear://project/<uuid>`, `linear://document/<uuid>`, or `linear://issue/<uuid>` (URI parsing is delegated to the normalized adapter) | warn | report | — |
| `memory-scope-trivia` | non-glob `scope:` (possible trivia) | warn | report | — |
| `memory-unresolved-link` | unresolved `[[wikilink]]` in a memory note (kept `warn` to not break consumer CI) | warn | report | — |
| `memory-no-updated` | memory note missing `updated:` (cannot be aged) | warn | report | — |
| `memory-dead` | old + never recalled (prune candidate) | warn | report | — |
| `memory-overlap` | notes with intersecting scope (review for contradiction) | warn | report | — |
| `spec-plan-backlink` | a plan's source spec lacks `[[plans/<plan-basename>]]` | warn | auto | `<root> <spec> <plan-basename>` |
| `doc-type` | spec/plan/fix `type:` missing or not matching its dir (owns the no-fence report for these docs) | warn | auto | `<root> <file>` |
| `status-enum` | `status:` value not in the conventions enum | error | auto (exact alias hit) / report (unknown) | `<root> <file>` |
| `status-band` | status value in the other artifact's band (spec↔plan); skips `fixes/` | warn | report | — |
| `plan-source` | plan missing the `**Source:**` join line | warn | auto (`source:` resolves) / report | `<root> <plan> source-line` |
| `plan-source-sync` | plan `source:` basename ≠ `**Source:**` line basename, or `source:` absent while the line is present | warn | auto | `<root> <plan> source-sync` |
| `plan-source-link` | plan's `**Source:**` line is a legacy bare-path, not the canonical `[[specs/<basename>]]` wikilink | warn | auto | `<root> <plan> source-link` |
| `orphan-worktree` (present) | unregistered dir under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose dir is gone | warn | auto | `<root>` (runs `git worktree prune`) |
| `gitignore-drift` | a shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` (appends missing lines) |
| `config-key` | a required `config.json` key (per the init template) is absent | warn | auto | `<root> <key>` (merges template default) |
| `artifact-config` | malformed/unsupported artifact selector or invalid backend config shape (credential-free resolver) | error | report | — |
| `artifact-legacy-local` | local spec/plan file exists while Linear is the active backend; file is inactive and left untouched | warn | report | — |
| `linear-live` | explicit authenticated read failed: viewer identity/active state, schema, workspace/team/resource visibility, status mapping, required capability, managed ownership/metadata, or native relation agreement | error | report | — |
| `linear-write-scope-unverifiable` | authenticated reads passed, but Linear provides no non-mutating effective write-scope introspection for a personal API key; future mutation authorization is not pre-proved | warn | report | — |
| `memory-provenance-live` | explicit authenticated provenance resolution found a missing/foreign project, document, or issue, or managed metadata/native relation drift | error | report | — |
| `respond-config` | invalid type, key, bound, or value in the optional `respond` namespace | warn | report | — |
| `respond-credentials` | credential-like key under `respond` | warn | report | — |
| `respond-stale-evidence` | response evidence run directory older than 24 hours | warn | report (manual deletion after failed-run review) | — |
| `omp-agents-missing` / `omp-agents-drift` | generated omp tier def missing or drifted from `.woostack/config.json` (gated on `.omp/` existing) | warn | auto | `<root>` (runs `gen-omp-agents.sh`) |

Memory checks are all `report` — memory *content* repair is [`woostack-dream`](../../woostack-dream/SKILL.md)'s
job; doctor only surfaces the structural signals. The spec↔plan join reuses the
`**Source:**`-line contract defined in
[`../../woostack-status/references/conventions.md`](../../woostack-status/references/conventions.md).

## Backend behavior

Markdown is the default. Its doc-type, status, source, backlink, memory, and repair behavior is
unchanged.

Linear static diagnosis is credential-free:

- `config-keys` invokes the shared backend resolver to validate `artifacts.specPlan`, repository
  identity, workspace/team strings, complete project-status and issue-state mapping shapes, and
  the absence of credential-like config keys;
- local `.woostack/specs/*.md` and `.woostack/plans/*.md` files are reported once each as inactive
  legacy artifacts;
- `doc-type`, `status-enum`, `status-band`, `plan-source`, and `spec-plan-backlink` skip those
  inactive local specs/plans (backend-neutral `.woostack/fixes/*.md` checks continue);
- memory provenance delegates strict `linear://project|document|issue/<uuid>` parsing to the
  normalized Linear adapter without authenticating.

`--live` is the only remote path. Before checks run, the controller invokes the adapter's
authenticated preflight exactly once and records the normalized result in a temporary non-secret
receipt. The config/resource and memory-provenance checks share that receipt rather than
reauthenticating. Preflight validates the viewer identity and active state, proves workspace/team
read visibility and required mutation fields in the current schema, then the checks validate every
managed repository feature and its resources through normalized feature models and resolve each
valid Linear provenance URI through the same model.
Those reads validate resource existence, repository/project ownership, managed schema/metadata,
and native blocked-by relation agreement. Missing credentials, transport/GraphQL failure,
identity/access failure, mapping/capability drift, inaccessible resources, or model drift are
errors. Linear does not expose a non-mutating query or response header for a personal API key's
effective write scope. Live doctor therefore emits `linear-write-scope-unverifiable`, does not
claim future mutation authorization was validated, and never probe-mutates; actual adapter
mutations remain fail-closed. Live diagnostics never fall back to local spec/plan files or report
an empty success. Every Linear finding is `report`; no check `--fix` command calls Linear or
performs remote repair.

## Doc-template & status drift (static vs computed)

The doc-template checks — `doc-type` and `status-enum` here, with `status-band`, `plan-source`,
`plan-source-sync`, and `plan-source-link` landing in later increments of this stack — repair specs/plans/fixes toward their
templates and the conventions enum using **only file content** — no `git`, no PR, no network. They cover **static,
authoring-time** drift; the **computed**, git/PR-derived execute→done band
(`executing`/`in-review`/`done`) is never written here. That band stays
[`woostack-status`](../../woostack-status/SKILL.md)'s **read-only computed truth** — doctor repairs
how a doc is *authored*, status derives what the artifacts *show*.

`status-enum` normalizes only **exact-match** alias values against a curated table owned by the
check (`aproved→approved`, `in_review→in-review`, `complete→done`, `wip→executing`, …); a value
that matches neither the enum nor an alias is genuinely unknown and stays `report` (no intent-guess,
no fuzzy match). The enum itself is canonical in
[`../../woostack-status/references/conventions.md`](../../woostack-status/references/conventions.md)
— linked, not restated.

**Consumer-CI migration:** `status-enum` is the one new `error` — any non-canonical `status:` value
newly fails `--check`, whether it's an alias (e.g. `wip`, `aproved`) or a genuinely unknown value.
Aliases are auto-repaired by `--fix`; unknowns need manual correction. The other doc-template checks
are `warn` (they surface and auto-fix on demand without failing CI).

## Adding a check

1. Drop `checks/<name>.sh` following the calling convention above (resolve `--fix` mode first; for a
   check in `checks/`, sibling-skill libs/templates are `$HERE/../../../woostack-init/...`).
2. Emit findings with a stable `code`.
3. Add `tests/test-<name>.sh` (fires on a drifted fixture, silent on a clean one; idempotent
   `--fix`).
4. Add the row here.
