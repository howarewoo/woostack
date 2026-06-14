# woostack-doctor check catalog

Each check is a script under [`../scripts/checks/`](../scripts/checks/) that emits findings to
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

## Checks

| code | check | severity | fixable | `--fix` args |
|---|---|---|---|---|
| `memory-malformed` | memory note missing opening `---` fence | error | report | — |
| `memory-field` | memory note missing `name`/`type` or empty body | error | report | — |
| `memory-type` | memory note has an unknown `type:` | error | report | — |
| `memory-dup` | duplicate memory note `name:` | error | report | — |
| `memory-scope-stale` | `scope:` matches no tracked files | warn | report | — |
| `memory-provenance` | missing `source:`, or `source:` points at a missing spec/plan/fix (accepts the `[[specs\|plans\|fixes/<basename>]]` wikilink form and the legacy `.woostack/…` path) | warn | report | — |
| `memory-scope-trivia` | non-glob `scope:` (possible trivia) | warn | report | — |
| `memory-unresolved-link` | unresolved `[[wikilink]]` in a memory note (kept `warn` to not break consumer CI) | warn | report | — |
| `memory-no-updated` | memory note missing `updated:` (cannot be aged) | warn | report | — |
| `memory-dead` | old + never recalled (prune candidate) | warn | report | — |
| `memory-overlap` | notes with intersecting scope (review for contradiction) | warn | report | — |
| `spec-plan-backlink` | a plan's source spec lacks `[[plans/<plan-basename>]]` | warn | auto | `<root> <spec> <plan-basename>` |
| `doc-type` | spec/plan/fix `type:` missing or not matching its dir (owns the no-fence report for these docs) | warn | auto | `<root> <file>` |
| `orphan-worktree` (present) | unregistered dir under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose dir is gone | warn | auto | `<root>` (runs `git worktree prune`) |
| `gitignore-drift` | a shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` (appends missing lines) |
| `config-key` | a required `config.json` key (per the init template) is absent | warn | auto | `<root> <key>` (merges template default) |

Memory checks are all `report` — memory *content* repair is [`woostack-dream`](../../woostack-dream/SKILL.md)'s
job; doctor only surfaces the structural signals. The spec↔plan join reuses the
`**Source:**`-line contract defined in
[`../../woostack-status/references/conventions.md`](../../woostack-status/references/conventions.md).

## Adding a check

1. Drop `checks/<name>.sh` following the calling convention above (resolve `--fix` mode first; for a
   check in `checks/`, sibling-skill libs/templates are `$HERE/../../../woostack-init/...`).
2. Emit findings with a stable `code`.
3. Add `tests/test-<name>.sh` (fires on a drifted fixture, silent on a clean one; idempotent
   `--fix`).
4. Add the row here.
