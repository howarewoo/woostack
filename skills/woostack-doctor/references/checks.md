# woostack-doctor check catalog

Each check under `../scripts/checks/` emits one tab-delimited finding:
`severity⇥code⇥fixable⇥path⇥message`.

- `severity` is `error` for structural breakage or `warn` for hygiene/retirement guidance.
- `fixable` is `auto` for an approved local repair or `report` for judgment-only evidence.
- A check that cannot complete is an incomplete inspection, not a clean one: the runner emits a
  `check-failed` error naming the check and its exit status, so both invocation modes exit nonzero.
- CI (`--check`) exits nonzero only when an `error` finding exists.

## Calling convention

Resolve the mode before deriving any path (`$1` is overloaded):

```text
bash checks/<name>.sh <WOO_ROOT>
bash checks/<name>.sh --fix <WOO_ROOT> <extra-args...>
```

Every check is static. A check never inspects credentials or invokes a provider, adapter, HTTP,
GraphQL, or hard-coded tool name. GitHub capability evidence comes from the host's authorized
native tools or host-authenticated `gh` at the calling workflow's own read boundary, never from a
Doctor receipt.


## Checks

| code | check | severity | fixable | `--fix` args |
|---|---|---|---|---|
| `orphan-worktree` (present) | unregistered directory under `.woostack/worktrees/` (may hold work) | warn | report | — |
| `orphan-worktree` (stale) | registered worktree whose directory is gone | warn | auto | `<root>` (`git worktree prune`) |
| `gitignore-drift` | shipped-template managed line missing from `.woostack/.gitignore` | warn | auto | `<root>` |
| `config-policy` | malformed canonical policy or resolver failure | error | report | — |
| `check-failed` | check could not complete; emitted by the runner, naming the check and its exit status | error | report | — |
| `retired-provider` | legacy provider selector/profile is present as opaque inactive data | warn | report | — |
| `retained-data` | historical local draft/manifest directory is present | warn | report | — |
| `retired-status-config` | legacy top-level `status.staleDays` is present | warn | report | — |

OMP agent selection is host-owned. Doctor never inspects, creates, repairs, or removes project
agent definitions or host extensions. A present unregistered worktree directory may hold work and
remains report-only; only a stale worktree registration whose directory is gone can be pruned.

Legacy provider settings and retained records are not active policy and are never migration input
for this engine. Their findings are actionable retirement guidance, not local-operation blockers.

## Runner failure handling

`doctor.sh` runs every check in `../scripts/checks/` and keeps going after a failure, so one broken
check never costs the findings of the others. A check that exits nonzero has its already-emitted
findings preserved, and the runner appends one `check-failed` error finding. That finding carries no
repair (`fixable` is `report`): a check that cannot complete is evidence to investigate, not
something Doctor fixes. The excerpt of the check's own stderr, when present, is bounded to one short
line. A check that emits an `error` finding and exits 0 is a completed inspection with an unhealthy
result, and keeps the same nonzero exit.

## Canonical policy

`config-policy` invokes the Init resolver and does not duplicate its schema. The resolver validates
only the optional top-level `github` object; `artifacts.provider`, `artifacts.linear`,
`artifacts.plane`, and older root provider settings remain opaque and inactive. Template presence
and repair apply only to the tracked base file.

## Adding a check

1. Add `checks/<name>.sh` with the calling convention above.
2. Emit a stable code and keep provider/retained findings report-only.
3. Add a focused test using the existing shell assertion helpers.
4. Add the row here. Do not add a provider migration or test-only conversion engine.
