# woostack-doctor check catalog

Each check under `../scripts/checks/` emits one tab-delimited finding:
`severity⇥code⇥fixable⇥path⇥message`.

- `severity` is `error` for structural breakage or `warn` for hygiene/retirement guidance.
- `fixable` is always `report`. No check owns a filesystem repair: a finding may name a proposed
  repair, and applying it is ordinary scoped editing through
  [`woostack-execute`](../../woostack-execute/SKILL.md).
- A check that cannot complete is an incomplete inspection, not a clean one: the runner emits a
  `check-failed` error naming the check and its exit status, so both invocation modes exit nonzero.
- CI (`--check`) exits nonzero only when an `error` finding exists.

## Calling convention

```text
bash checks/<name>.sh <WOO_ROOT>
```

Every check is static and read-only. A check never inspects credentials or invokes a provider,
adapter, HTTP, GraphQL, or hard-coded tool name. GitHub capability evidence comes from the host's
authorized native tools or host-authenticated `gh` at the calling workflow's own read boundary,
never from a Doctor receipt. A check writes nothing: a retired `--fix` invocation fails without
writing and is never treated as a target directory.

## Checks

| code | check | severity | fixable |
|---|---|---|---|
| `gitignore-drift` | shipped-template managed line missing from `.woostack/.gitignore` | warn | report |
| `config-policy` | malformed canonical policy or resolver failure | error | report |
| `check-failed` | check could not complete; emitted by the runner, naming the check and its exit status | error | report |
| `retired-provider` | legacy provider selector/profile is present as opaque inactive data | warn | report |
| `retained-data` | historical local draft/manifest directory is present | warn | report |
| `retired-status-config` | legacy top-level `status.staleDays` is present | warn | report |

OMP agent selection is host-owned. Doctor never inspects, creates, repairs, or removes project
agent definitions or host extensions, and it never inspects, prunes, or removes Git worktree
registrations: workspace lifecycle belongs to the host or repository under the
[init workspace guidance](../../woostack-init/references/worktrees.md).

A diagnostic that cannot complete is reported, not treated as healthy: a symlinked managed file
stops inspection without following the link, and an unreadable template or non-regular target is an
`error` finding rather than a clean result.

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
`artifacts.plane`, and older root provider settings remain opaque and inactive. The managed ignore
template is only ever read for comparison.

## Adding a check

1. Add `checks/<name>.sh` with the calling convention above.
2. Emit a stable code and keep every finding report-only.
3. Add a focused test using the existing shell assertion helpers.
4. Add the row here. Do not add a provider migration or test-only conversion engine.
